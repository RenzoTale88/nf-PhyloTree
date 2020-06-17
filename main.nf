#!/usr/bin/env nextflow
 
/*
 * Defines some parameters in order to specify the refence genomes
 * and read pairs by using the command line options
 */
params.infile = "file.vcf.gz"
params.ftype = 'bed'
params.groups = "myfile.txt"
params.spp = 'cow'
params.bootstrap = 10
params.outfolder = "${baseDir}/OUTPUT"
params.dpi = 300
params.size = 10
params.mrkS = 1 
params.subset = 1000000
params.mrkR = '1.0'
params.allowExtrChr = '--allow-extra-chr'
params.setHHmiss = '--set-hh-missing'


/*
 * Step 1. Create file TPED/TMAP
 */

process transpose {
    tag "transp"

    errorStrategy { task.exitStatus == 0 ? 'finish' : 'retry' }
    maxRetries = 1
    
    output:
    tuple "transposed.tped", "transposed.tfam" into transposed_ch

    script:
    if( params.ftype == 'vcf' )
        """
        plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --vcf ${params.infile} --recode transpose --out transposed --threads ${task.cpus}
        """
    else if( params.ftype == 'bcf' )
        """
        plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --bcf ${params.infile} --recode transpose --out transposed --threads ${task.cpus}
        """
    else if( params.ftype == 'ped' )
        """
        plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --file ${params.infile} --recode transpose --out transposed --threads ${task.cpus}
        """
    else if( params.ftype == 'bed' )
        """
        plink --${params.spp} ${params.allowExtrChr} ${params.setHHmiss} --bfile ${params.infile} --recode transpose --out transposed --threads ${task.cpus}
        """
    else if ( params.ftype == "tped" )
        """
        ln -s ${params.infile}.tped transposed.tped
        ln -s ${params.infile}.tfam transposed.tfam
        """
    else
        error "Invalid file type: ${params.ftype}"

}

transposed_ch.into { tr1_ch; tr2_ch }

/*
 * Step 2. Create file lists of bootstrapped markers
 */

process makeBSlists {
    tag "makeBS"

    input:
    tuple tped, tfam from tr1_ch

    output:
    //Save output path to a channel
    path "LISTS" into workdir_ch

    script:
    """
    MakeBootstrapLists ${tped} ${params.bootstrap} ${params.subset}
    if [ ! -e LISTS ]; then mkdir LISTS; fi
    mv BS_*.txt ./LISTS
    """
}

process getBSlists {
    tag "getBS"

    input:
    //Collect the generated files
    path mypath from workdir_ch
    each x from 1..params.bootstrap

    output:
    // Save every file with it's index in a new channel
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
    FixGraphlanXml -i ${cns} -g ${params.groups} -f ${params.mrkS} -m ${params.mrkR} > final.xml
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
    file "my_plot.dpi${params.dpi}.size${params.size}.mrkS${params.mrkS}.mrkR${params.mrkR}.png"

    script:
    """
    graphlan.py ${fin} my_plot.dpi${params.dpi}.size${params.size}.mrkS${params.mrkS}.mrkR${params.mrkR}.png --dpi ${params.dpi} --size ${params.size}
    """
}