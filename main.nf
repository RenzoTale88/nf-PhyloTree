#!/usr/bin/env nextflow
 
/*
 * Defines some parameters in order to specify the refence genomes
 * and read pairs by using the command line options
 */
params.infile = "file.vcf.gz"
params.groups = "myfile.txt"
params.bootstrap = 10
params.listfolder = "${baseDir}/LISTS"
params.outfolder = "${baseDir}/OUTPUT"
params.spp = 'cow'
params.allowExtrChr='--allow-extra-chr'
params.setHHmiss='--set-hh-missing'

/*
 * Step 1. Create file TPED/TMAP
 */
process getType {

    tag "getF"

    output:
    stdout ftype_ch

    script:
    """
    python -c "import sys; filename=sys.argv[1].strip().split('/')[-1]; filesep=filename.split('.'); filesep = [ i for i in filesep if i != 'gz' and i!='bz' and i != 'bz2' and i!='zip' ]; print(filesep[-1]) " ${params.inputfile}
    """
}

ftype_ch.set {ftype_ch_2}

process getName {

    tag "getN"

    input:
    val ftype from ftype_ch_2

    output:
    stdout bname_ch

    script:
    """
    if [ "${ftype}" == "ped" ]
    then    
        python -c "import sys; print( sys.argv[1].replace('.ped', '') )" ${params.inputfile}
    elif [ "${ftype}" == "bed" ]
    then
        python -c "import sys; print( sys.argv[1].replace('.bed', '') )" ${params.inputfile}
    elif [ "${ftype}" != "${params.inputfile}" ]
    then
        python -c "import sys; print( sys.argv[1].replace('.{}'.format(sys.argv[2]), '') )" ${params.inputfile} ${ftype}
    else
        echo ${params.inputfile}
    fi
    """
}

process transpose {
    tag "transp"

    errorStrategy { task.exitStatus == 0 ? 'finish' : 'retry' }
    maxRetries = 1
    
    

    input:
    val ftype from ftype_ch
    val bname from bname_ch

    output:
    tuple "transposed.tped", "transposed.tfam" into transposed_ch

    script:
    """
    if [ "${ftype}" == "vcf" ]; then
        plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --vcf ${params.inputfile} --recode transpose --out transposed --threads ${task.cpus}
    elif [ "${ftype}" == "bcf" ]; then
        plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --bcf ${params.inputfile} --recode transpose --out transposed --threads ${task.cpus}
    elif [ "${ftype}" == "ped" ]; then
        plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --file ${bname} --recode transpose --out transposed --threads ${task.cpus}
    elif [ "${ftype}" == "bed" ]; then
        plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --bfile ${bname} --recode transpose --out transposed --threads ${task.cpus}
    else
        if [ -e "${params.inputfile}.bed" ]; then
            plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --bfile ${params.inputfile} --recode transpose --out transposed --threads ${task.cpus}
        elif [ -e "${params.inputfile}.ped" ]; then
            plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --file ${params.inputfile} --recode transpose --out transposed --threads ${task.cpus}
        elif [ -e "${params.inputfile}.vcf" ]; then
            plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --vcf ${params.inputfile}.vcf --recode transpose --out transposed --threads ${task.cpus}
        elif [ -e "${params.inputfile}.vcf.gz" ]; then
            plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --vcf ${params.inputfile}.vcf.gz --recode transpose --out transposed --threads ${task.cpus}
        elif [ -e "${params.inputfile}.bcf" ]; then
            plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --bcf ${params.inputfile}.bcf --recode transpose --out transposed --threads ${task.cpus}
        else
            echo "No file"
        fi
    fi
    """
}

transposed_ch.into { tr1_ch; tr2_ch }

/*
 * Step 2. Create file lists of bootstrapped markers
 */

process makeBSlists {
    tag "makeBS"

    input:
    //each x from 1..params.bootstrap
    tuple tped, tfam from tr1_ch

    output:
    // tuple x, "BS_${x}.txt" into BootstrapLists
    path "LISTS" into workdir_ch

    script:
    """
    MakeBootstrapLists ${tped} ${params.bootstrap}
    if [ ! -e LISTS ]; then mkdir LISTS; fi
    mv BS_*.txt ./LISTS
    """
}

process getBSlists {
    tag "getBS"

    input:
    path mypath from workdir_ch
    each x from 1..params.bootstrap

    output:
    tuple x, "${mypath}/BS_${x}.txt" into BootstrapLists

    script:
    """
    echo ${mypath}
    """
}


/*
 * Step 3. Perform parallel IBS tree definition and 
 * concatenate them
 */

process ibs { 
    tag "ibs.${x}"

    input: 
        tuple x, "BS_${x}.txt" from BootstrapLists
        tuple tped, tfam from transposed_ch
 
    output: 
        file "outtree_${x}.nwk" into bootstrapReplicateTrees
  
    script:
    """
    BsTpedTmap ${tped} ${tfam} BS_${x}.txt ${x}
    arrange ${x}
    plink --${params.spp} ${params.allowExtrChr} --threads ${task.cpus} --allow-no-sex --nonfounders --tfile BS_${x} --distance 1-ibs flat-missing square --out BS_${x}
    rm BS_${x}.tped BS_${x}.tfam
    MakeTree ${x} && rm BS_${x}.mdist*
    """
}

process concatenateBootstrapReplicates {
    tag "combine"
    publishDir "${params.outfolder}/combined", mode: 'copy'

    input:
    file bootstrapTreeList from bootstrapReplicateTrees.collect()

    output:
    file "concatenatedBootstrapTrees.nwk" into concat_ch

    // Concatenate Bootstrap Trees
    script:
    """
    for treeFile in ${bootstrapTreeList}
    do
        cat \$treeFile >> concatenatedBootstrapTrees.nwk
    done

    """
}


/*
 * Step 4. Get consensus tree from the different 
 * phylogenetic trees. Then, fix the xml annotation to 
 * make it compliant with graphlan
 */

process consensus {
    tag "consensusTree"
    publishDir "${params.outfolder}/consensus", mode: 'copy'

    input:
    file bstree from concat_ch

    output:
    file "consensus.xml" into consense_ch

    script:
    """
    ConsensusTree ${bstree}
    """
}

process fixTree {
    tag "fixTree"
    publishDir "${params.outfolder}/fixed", mode: 'copy'

    input:
    file cns from consense_ch

    output:
    file "final.xml" into final_ch

    script:
    """
    FixGraphlanXml -i ${cns} -g ${params.groups} > final.xml
    """
}


/*
 * Step 5. Run graphlan on the final tree
 */

process graphlan {
    tag "graphlan"
    publishDir "${params.outfolder}/picture", mode: 'copy'

    input:
    file fin from final_ch

    output:
    file "my_plot.png"

    script:
    """
    graphlan ${fin} my_plot.png --dpi 300 --size 15
    """
}