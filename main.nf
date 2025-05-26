#!/usr/bin/env nextflow
nextflow.enable.dsl=2
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_graphseq_pipeline'
/*
 * Defines some parameters in order to specify the refence genomes
 * and read pairs by using the command line options
 */

/*
 * Step 1. Create path TPED/TMAP
 */

process transpose_inputs {
    label "large"
    cpus params.plink_cpus
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
        if (params.spp == 'human'){
            karyo = ""
        } else {
            karyo = "--${params.spp}"
        }
    } else {
        karyo = ""
    }
    def input = ""
    def half_calls_cfg = ""
    if( mode == 'vcf' || mode == 'bcf'){
        input = "--${mode} ${inputs[0]}"
        half_calls_cfg = "--vcf-half-call ${params.halfcalls}"
    } else if (mode == 'bed'){
        input = "--bed ${inputs[0]} --bim ${inputs[1]} --fam ${inputs[2]}"
    } else if (mode == 'ped'){
        input = "--ped ${inputs[0]} --map ${inputs[1]}"
    } else if (mode == 'tped'){
        input = "--tped ${inputs[0]} --tfam ${inputs[1]}"
    } else {
        error "Invalid file type: ${params.ftype}"
    }
    def extrachr = params.allowExtrChr ? "--allow-extra-chr" : ""
    def sethhmis = params.setHHmiss ? "--set-hh-missing" : ""
    if (params.ftype != 'tped')
    """
    plink ${karyo} ${extrachr} ${sethhmis} ${input} ${half_calls_cfg} --recode transpose --out transposed --threads ${task.cpus}
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
    label "medium"

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
    label "medium"
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
    label "large"
    cpus params.plink_cpus

    input: 
        tuple val(x), path(tped), path(tfam)
        
    output: 
        tuple path("${x}.mdist"), path("${x}.mdist.id"), emit: dists
        path "outtree_${x}.nwk", emit: bootstrapReplicateTrees, optional: true
        
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
    def make_tree = params.tool == "biopython" ? "MakeTree ${x} ${params.method}" : ""
    """
    plink ${karyo} ${extrachr} ${sethhmis} --threads ${task.cpus} --allow-no-sex --nonfounders --tfile ${tped.baseName} --distance 1-ibs flat-missing square --out ${x}
    ${make_tree}
    """
}

process prepare_phylip {
    label "medium"

    input: 
        tuple path(mdist), path(id)
        
    output: 
        path("${mdist}.infile"), emit: infiles
        path("${mdist}.conv.txt"), emit: conversion
        path("${mdist}.ogroups.txt"), emit: ogroups
        
    script:
    def outgroup = params.outgroup && params.method == 'nj' ? "${params.outgroup}" : ""
    """
    MakePhylipInput ${mdist} ${outgroup}
    """
}


/*
 * Step 4. Get consensus tree from the different 
 * phylogenetic trees. Then, fix the xml annotation to 
 * make it compliant with graphlan
 */

process neighbor {
    publishDir "${params.outdir}/", mode: 'copy', overwrite: true

    input:
    path "infiles/*"
    path "conversion.txt"
    val outgroup

    output:
    path "multitree.nwk", emit: multi
    path "consensus/consensus.nwk", emit: nwk
    path "consensus/consensus.xml", emit: xml

    script:
    def instring = params.method == 'upgma' ? "N\\nO\\n$outgroup\\nM\\n${params.bootstrap}\\n135\\nY\\n" : "O\\n$outgroup\\nM\\n${params.bootstrap}\\n135\\nY\\n"
    """
    cat infiles/* > infile
    echo -e "${instring}" | neighbor
    cp outtree multitree.nwk
    mv outtree intree
    mkdir consensus/
    echo -e "R\\nY\\n" | consense && mv outtree tmp.nwk
    Newick2Xml tmp.nwk conversion.txt && mv consensus.* consensus/
    """
}

process consensus {
    tag "consensusTree"
    publishDir "${params.outdir}/consensus", mode: 'copy', overwrite: true

    input:
    path "intree"

    output:
    path "consensus.xml", emit: xml
    path "consensus.nwk", emit: nwk

    script:
    """
    ConsensusTree "intree"
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
    // Log stuff
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir
    )

    // Notify if asking upgma and outgroup
    if (params.method == 'upgma' && params.outgroup) {
        log.warn "You are using the UPGMA method with an outgroup, which is ignored by the algorithm."
    }
    if (params.tool == 'biopython' && params.outgroup) {
        log.warn "The biopython methods currently only works without outgroup."
    }

    // Prepare the inputs
    groups_ch = Channel.fromPath(params.groups, checkIfExists: true)
    if( params.ftype == 'vcf' || params.ftype == 'bcf' ){
        input_ch = Channel.from([
            params.ftype,
            file(params.input),
            null,
            null,
        ])
    } else if (params.ftype == 'bed'){
        input_ch = Channel.from([
            params.ftype,
            file("${params.input}.bed"),
            file("${params.input}.bim"),
            file("${params.input}.fam"),
        ])
    } else if (params.ftype == 'ped'){
        input_ch = Channel.from([
            params.ftype,
            file("${params.input}.ped"),
            file("${params.input}.map"),
            null,
        ])
    } else if (params.ftype == 'tped'){
        input_ch = Channel.from([
            params.ftype,
            file("${params.input}.tped"),
            file("${params.input}.tfam"),
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
    bootstraps_ch = tpedBS(tped, tfam, bootstraps)
    | ibs

    if (params.tool == "phylip") {
        dists_ch = bootstraps_ch.dists 
        | prepare_phylip
        // Neioghbour joining tree
        consensus_tree_ch = neighbor(
            dists_ch.infiles | collect,
            dists_ch.conversion | first | collect,
            dists_ch.ogroups | first | splitCsv | first | flatten
        )

    } else {
        consensus_tree_ch = bootstraps_ch.bootstrapReplicateTrees 
        | collectFile( name: "${params.outdir}/intree" )
        | consensus
    }

    // Make plot
    groups_ch = Channel.fromPath(params.groups, checkIfExists: true)
    fixTree(consensus_tree_ch.xml, groups_ch)
    | graphlan

}