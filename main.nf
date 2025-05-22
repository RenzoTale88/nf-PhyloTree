#!/usr/bin/env nextflow
nextflow.enable.dsl=2
 
/*
 * Defines some parameters in order to specify the refence genomes
 * and read pairs by using the command line options
 */

/*
 * Step 1. Create path TPED/TMAP
 */

process transpose_inputs {
    label "large"
    tag "transpose"

    input:
    tuple val(mode),
        path(inputs)

    output:
    path "transposed.tped", emit: tped
    path "transposed.tfam", emit: tfam
    
    script:
    def karyo = ""
    if (params.karyo){
        karyo = "--chr-set ${params.karyo}"
    } else if (params.spp) {
        karyo = "--${params.spp}"
    } else {
        karyo = ""
    }
    def infile = ""
    def half_calls_cfg = ""
    if( mode == 'vcf' || mode == 'bcf'){
        infile = "--${mode} ${inputs[0]}"
        half_calls_cfg = "--vcf-half-call ${params.halfcalls}"
    } else if (mode == 'bed'){
        infile = "--bed ${inputs[0]} --bim ${inputs[1]} --fam ${inputs[2]}"
    } else if (mode == 'ped'){
        infile = "--ped ${inputs[0]} --map ${inputs[1]}"
    } else if (mode == 'tped'){
        infile = "--tped ${inputs[0]} --tfam ${inputs[1]}"
    } else {
        error "Invalid file type: ${params.ftype}"
    }
    def extrachr = params.allowExtrChr ? "--allow-extra-chr" : ""
    def sethhmis = params.setHHmiss ? "--set-hh-missing" : ""
    if (params.ftype != 'tped')
    """
    plink ${karyo} ${extrachr} ${sethhmis} ${infile} ${half_calls_cfg} --recode transpose --out transposed --threads ${task.cpus}
    """
}

/*
 * Step 2. Create path lists of bootstrapped markers
 */

process makeBSlists {
    tag "makeBS"
    label "medium"

    input:
    path tped 
    path tfam 

    output:
    path "BS_*.txt"

    script:
    """
    nvar=`python -c "import sys; nrows=sum([1 for line in open(sys.argv[1])]); sys.stdout.write(str(nrows)) if nrows<int(sys.argv[2]) else sys.stdout.write(sys.argv[2])" ${tped} ${params.subset} `
    MakeBootstrapLists ${tped} ${params.bootstrap} \$nvar
    """
}


process getBSlists {
    tag "getBS"
    label "small"

    input:
    //Collect the generated files
    path mypath 
    val x 
    val k 

    output:
    // Save every file with it's index in a new channel
    tuple val(k), val(x), path("BS_${x}.txt") 

    script:
    """
    cp ${mypath}/BS_${x}.txt ./
    """
}


process tpedBS {
    tag "tpedBS"
    label "small"
    conda "python=3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pysam:0.22.1--py39hcada746_0' :
        'quay.io/biocontainers/pysam:0.22.1--py39hcada746_0' }"

    //Collect the generated files
    input:
    path tped 
    path tfam 
    path BS

    // Save every file with it's index in a new channel
    output:
    tuple val("${BS.simpleName}"), path("${BS.simpleName}.tped"), path("${BS.simpleName}.tfam") 

    script:
    """
    BsTpedTmap ${tped} ${tfam} ${BS} ${BS.simpleName}
    """
}

/*
 * Step 3. Perform parallel IBS tree definition and 
 * concatenate them
 */

process ibs {     
    tag "ibs.${x}"
    label "medium"

    input: 
        tuple val(x), path(tped), path(tfam)
        
    output: 
        path "outtree_${x}.nwk", emit: bootstrapReplicateTrees
        
    script:
    def karyo = ""
    if (params.karyo){
        karyo = "--chr-set ${params.karyo}"
    } else if (params.spp) {
        karyo = "--${params.spp}"
    } else {
        karyo = ""
    }
    def extrachr = params.allowExtrChr ? "--allow-extra-chr" : ""
    def sethhmis = params.setHHmiss ? "--set-hh-missing" : ""
    """
    plink ${karyo} ${extrachr} ${sethhmis} --threads ${task.cpus} --allow-no-sex --nonfounders --tfile ${tped.baseName} --distance 1-ibs flat-missing square --out ${x}
    MakeTree ${x} && rm ${x}.mdist*
    """
}


/*
 * Step 4. Get consensus tree from the different 
 * phylogenetic trees. Then, fix the xml annotation to 
 * make it compliant with graphlan
 */

process consensus {
    tag "consensusTree"
    publishDir "${params.outdir}/consensus", mode: 'copy', overwrite: true

    input:
    path bstree

    output:
    path "consensus.xml", emit: consense_ch

    script:
    """
    ConsensusTree ${bstree}
    """
}

process fixTree {
    publishDir "${params.outdir}/fixed", mode: 'copy', overwrite: true

    input:
        path cns
        path groups

    output:
        path "final.xml", emit: final_ch

    script:
    """
    FixGraphlanXml -i ${cns} -g ${groups} -f ${params.mrkS} -m ${params.mrkR} > final.xml
    """
}


/*
 * Step 5. Run graphlan on the final tree
 */

process graphlan {
    tag "graphlan"
    publishDir "${params.outdir}/picture", mode: 'copy', overwrite: true

    input:
    path fin

    output:
    path "my_plot.dpi${params.dpi}.size${params.size}.mrkS${params.mrkS}.mrkR${params.mrkR}.png"

    script:
    """
    graphlan.py ${fin} my_plot.dpi${params.dpi}.size${params.size}.mrkS${params.mrkS}.mrkR${params.mrkR}.png --dpi ${params.dpi} --size ${params.size}
    """
}

workflow {
    groups_ch = Channel.fromPath(params.groups, checkIfExists: true)
    if( params.ftype == 'vcf' || params.ftype == 'bcf' ){
        input_ch = Channel.from([
            params.ftype,
            file(params.infile),
            null,
            null,
        ])
    } else if (params.ftype == 'bed'){
        input_ch = Channel.from([
            params.ftype,
            file("${params.infile}.bed"),
            file("${params.infile}.bim"),
            file("${params.infile}.fam"),
        ])
    } else if (params.ftype == 'ped'){
        input_ch = Channel.from([
            params.ftype,
            file("${params.infile}.ped"),
            file("${params.infile}.map"),
            null,
        ])
    } else if (params.ftype == 'tped'){
        input_ch = Channel.from([
            params.ftype,
            file("${params.infile}.tped"),
            file("${params.infile}.tfam"),
            null,
        ])
    } else {
        error "Invalid file type: ${params.ftype}"
    }
    input_ch = input_ch | collect | map{ ftype, in1, in2, in3 -> [ftype, [in1, in2, in3] - null] }
    transposed_ch = input_ch | transpose_inputs
    tped = transposed_ch.tped | collect
    tfam = transposed_ch.tfam | collect

    // Create bootstrap lists
    makeBSlists(tped, tfam)
    bootstraps = makeBSlists.out | flatten

    // Run analysis
    consensus_tree_ch = tpedBS(tped, tfam, bootstraps)
    | ibs
    | collectFile( name: "${params.outdir}/multitree.tre" )
    | consensus

    // Make plot
    fixTree(consensus_tree_ch, groups_ch)
    | graphlan

}