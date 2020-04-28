#!/usr/bin/env nextflow
 
/*
 * Defines some parameters in order to specify the refence genomes
 * and read pairs by using the command line options
 */
params.infile = "file.vcf.gz"
params.bootstrap = '100'
params.listfolder = 'LISTS'
params.outfolder = 'OUTPUT'
 

/*
 * Step 1. Create file TPED/TMAP
 */

process transpose {
    tag "transp"

    input:
    path file from params.inputfile

    output:
    file "transposed" into transposed_ch

    script:
    """
    ftype=`python -c "import sys; filename=sys.argv[1].strip().split('/'); filesep=filename.split('.'); filesep = [ i for i in filesep if i != 'gz' and i!='bz' and i != 'bz2' and i!='zip' ]; print(filesep[-1]) " ${file}`
    if [ $ftype == "vcf" ]; then
        plink --allow-extra-chrs --vcf ${file} --recode transpose --out transposed --threads $cpus
    elif [ $ftype == "bcf" ]; then
        plink --allow-extra-chrs --bcf ${file} --recode transpose --out transposed --threads $cpus
    elif [ $ftype == "ped" ]; then
        bname=` python -c "import sys; print( sys.argv[1].replace('.ped', '') )" ` 
        plink --allow-extra-chrs --file ${bname} --recode transpose --out transposed --threads $cpus
    elif [ $ftype == "bed" ]; then
        bname=` python -c "import sys; print( sys.argv[1].replace('.bed', '') )" ` 
        plink --allow-extra-chrs --bfile ${bname} --recode transpose --out transposed --threads $cpus
    else
        if [ -e ${file}.bed ]; then
            plink --allow-extra-chrs --bfile ${file} --recode transpose --out transposed --threads $cpus
        elif [ -e ${file}.ped ]; then
            plink --allow-extra-chrs --file ${file} --recode transpose --out transposed --threads $cpus
        elif [ -e ${file}.vcf ]; then
            plink --allow-extra-chrs --vcf ${file}.vcf --recode transpose --out transposed --threads $cpus
        elif [ -e ${file}.vcf.gz ]; then
            plink --allow-extra-chrs --vcf ${file}.vcf.gz --recode transpose --out transposed --threads $cpus
        elif [ -e ${file}.bcf ]; then
            plink --allow-extra-chrs --bcf ${file}.bcf --recode transpose --out transposed --threads $cpus
        fi
    fi
    """
}

transposed_ch.into { tr1_ch, tr2_ch }

/*
 * Step 2. Create file lists of bootstrapped markers
 */

process makeBSlists {
    tag "makeBS"
    publishDir "${params.listfolder}"

    input:
    path transposed from tr1_ch

    output:
    file "${params.listfolder}/BS_*" into BootstrapLists

    script:
    """
    MakeBootstrapLists.py ${transposed} ${params.bootstrap}
    """
}


/*
 * Step 3. Perform parallel IBS tree definition and 
 * concatenate them
 */

process ibs { 
    tag "ibs.${x}"

    input: 
        each x from 1..bootstrapReplicates
        path transposed from transposed_ch
 
    output: 
        file "outtree_${x}" into bootstrapReplicateTrees
  
    script:
    """
    BsTpedTmap.py ${transposed} ${params.listfolder}/BS_${x}.txt ${x}
    arrange.R ${x}
    plink --allow-extra-chrs --threads ${cores} --allow-no-sex --nonfounders --tfile BS_${x} --distance 1-ibs flat-missing square --out BS_${x}
    rm BS_{0}.tped BS_{0}.tfam
    MakeTree.py ${x} && rm BS_${x}.mdist* ${params.listfolder}/BS_${x}.txt
    """
}

process concatenateBootstrapReplicates {
    tag "combine"
    publishDir "$params.outfolder"

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
    publishDir ${params.outfolder}

    input:
    file bstree from concat_ch

    output:
    file "consensus.xml" into consense_ch

    script:
    """
    ConsensusTree.py ${bstree}
    """
}

process fixTree {
    tag "fixTree"
    publishDir ${params.outfolder}

    input:
    file cns from consense_ch
    path tfile from tr2_ch

    output:
    file "final.xml" into final_ch

    script:
    """
    awk 'BEGIN{OFS="\t"}; {print $1,$2}' ${tfile}.tfam > groups.txt
    FixGraphlanXml.py -i ${cnd} -g groups.txt > final.xml
    """
}


/*
 * Step 5. Run graphlan on the final tree
 */

process graphlan {
    tag "graphlan"
    publishDir ${params.outfolder}

    input:
    file final from final_ch

    output:
    file "my_plot.png"

    script:
    """
    graphlan.py ${final} my_plot.png --dpi 300 --size 15
    """
}