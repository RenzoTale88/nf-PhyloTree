
# nf-PhyloTree
## Generate IBS-based, bootstrapped phylogenetic trees 

## Dependencies
To run the pipeline, you need to have installed:

 1. [Graphlan](https://bitbucket.org/nsegata/graphlan/wiki/Home)
 2. Python 2.7 with the packages colormap, xml and [biopython](https://biopython.org/)
 3. [plink v1.90](https://www.cog-genomics.org/plink)
 4. [R](https://www.r-project.org/) with [tidyverse](https://www.tidyverse.org/) 
 5. [phylip](http://evolution.genetics.washington.edu/phylip.html)


## Running the pipeline
The pipeline can be run as a regular nextflow workflow:
```
nextflow run --infile $PWD/mybedfile --ftype bed --spp cow --outfolder $PWD/ibstree --bootstrap 100
```