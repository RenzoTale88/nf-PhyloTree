

def main():
    from Bio import Phylo
    from Bio.Phylo.Consensus import majority_consensus
    import sys
    trees = list(Phylo.parse(sys.argv[1], 'newick'))
    majority_tree = majority_consensus(trees, 0)
    Phylo.write(majority_tree, 'consensus.xml', 'phyloxml')    


if __name__ == "__main__":
    main()