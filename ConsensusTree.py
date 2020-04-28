

def main():
    from Bio import Phylo
    from Bio.Phylo.Consensus import *
    trees = list(Phylo.parse('Tests/TreeConstruction/trees.tre', 'newick'))
    majority_tree = majority_consensus(trees, 0)
    Phylo.write(majority_tree, 'consensus.xml', 'phyloxml')    


if __name__ == "__main__":
    main()