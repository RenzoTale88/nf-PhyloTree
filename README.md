
# nf-PhyloTree
## Generate IBS-based, bootstrapped phylogenetic trees 
This workflow accepts a set of genomic variants in multiple PLINK (BED+BIM+FAM, PED+MAP or TPED+TFAM) or VCF/BCF and generates a phylogenetic tree based on the identity-by-state (IBS) distance between samples. The workflow includes bootstrapping to assess the stability of each node throughout repeated runs, and generate high-resolution plots using [GraphLan](https://bitbucket.org/nsegata/graphlan/wiki/Home).

## Dependencies
To run the pipeline, you need to have installed:

 1. [Graphlan](https://bitbucket.org/nsegata/graphlan/wiki/Home)
 2. Python 2.7 with the packages colormap, xml and [biopython](https://biopython.org/)
 3. [plink v1.90](https://www.cog-genomics.org/plink)
 5. [phylip](http://evolution.genetics.washington.edu/phylip.html)

## Running the pipeline
The pipeline can be run as a regular nextflow workflow:
```
nextflow run RenzoTale88/nf-PhyloTree --infile $PWD/mybedfile --ftype bed --spp cow --outfolder $PWD/ibstree --bootstrap 100
```
The workflow will run using Docker by default, but it can be run also using Singularity (`-profile singularity`) or Conda/Mamba (`-profile mamba` or `profile conda`).

## Citing
To cite the software, please use the following reference:
```
Talenti et al., ‘Continent-Wide Genomic Analysis of the African Buffalo (Syncerus Caffer)’.
```

## References
- Felsenstein, ‘PHYLIP - Phylogeny Inference Package (Version 3.2)’.
- Asnicar et al., ‘Compact Graphical Representation of Phylogenetic Data and Metadata with GraPhlAn’.
- Chang et al., ‘Second-Generation PLINK: Rising to the Challenge of Larger and Richer Datasets’.