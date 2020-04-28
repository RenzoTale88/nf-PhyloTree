#!/usr/bin/env nextflow
 
/*
 * Defines some parameters in order to specify the refence genomes
 * and read pairs by using the command line options
 */
params.infile = "file.vcf.gz"
params.bootstrap = '100'
 

/*
 * Step 1. Builds the genome index required by the mapping process and
 * the intervals for the analyses
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

process makeBSlists {
    publishDir "./LISTS"

    input:
    path transposed from tr1_ch

    output:
    file "BS_*" into BootstrapLists
}


 process bootstrapReplicateTrees {
    publishDir "$results_path/$datasetID/bootstrapsReplicateTrees"

    input:

    output:
    file "bootstrapTree_${x}.nwk" into bootstrapReplicateTrees

    script:
    // Generate Bootstrap Trees

    """
    raxmlHPC -m PROTGAMMAJTT -n tmpPhylip${x} -s tmpPhylip${x}
    mv "RAxML_bestTree.tmpPhylip${x}" bootstrapTree_${x}.nwk
    """
}

process ibs { 
    tag "ibs.${chrom}"

    input: 
        each x from 1..bootstrapReplicates
        path transposed from transposed_ch
 
    output: 
        file "infile_${x}" into bootstrapReplicateTrees
  
    script:
    """
    set +u; source activate xpclr
    if [ ! -e ${params.outdir} ]; then mkdir ${params.outdir}; fi
    if [ ! -e ${params.outdir}/${br1}_${br2} ]; then mkdir ${params.outdir}/${br1}_${br2}; fi

    echo "xpclr -F vcf -I ${params.vcf} -Sa ${params.lists}/${br1}.txt -Sb ${params.lists}/${br2}.txt -O ${params.outdir}/${br1}_${br2}/${br1}_${br2}.${chrom}.xpclr -C ${chrom} --size ${params.winsize} --maxsnps ${maxsnp}"
    xpclr -F vcf -I ${params.vcf} -Sa ${params.lists}/${br1}.txt -Sb ${params.lists}/${br2}.txt -O ${params.outdir}/${br1}_${br2}/${br1}_${br2}.${chrom}.xpclr -C ${chrom} --size ${params.winsize} --maxsnps ${params.maxsnp}

    """
}

process combine {
    tag "combine"
 
    input: 
        path outf from params.outdir 
 
    output: 
        path "${params.outdir}" into xpclr_path_ch  
  
    script:
    """
    
    for f in `ls ${params.outdir}`; do 
        if [ -e ${outf}/${f}/${f}.xpclr ]; then
            rm ${outf}/${f}/${f}.xpclr
        fi
        for w in `ls ${outf}/${f}`; do 
            cat ${outf}/${f}/${w} >> ${outf}/${f}/${f}.xpclr
        done

        echo "Done ${i}"
    done
    """
}

