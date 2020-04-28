#!/usr/bin/env python

def main():
    import Bio.Phylo.TreeConstruction as TC
    from Bio import Phylo

    import sys
    nbs = sys.argv[1]
    samples = [line.strip().split()[1] for line in open( "BS_{}.mdist.id".format( nbs ) )]
    vals = []
    for v in open( "BS_{}.mdist".format( nbs ) ):
        v = list(map( float, v.strip().split() ))
        tmp = []
        for i in v:
            if i != 0: tmp.append(i)
            else: 
                tmp.append(i)
                break
        vals.append(tmp)
    DistMat = TC._DistanceMatrix(samples, vals)
    constructor = TC.DistanceTreeConstructor()
    tree = constructor.nj(DistMat)
    Phylo.write(tree, 'outtree_{}.nwk'.format(nbs), 'newick')
    print("Saved to outtree_{}.nwk".format(nbs))


if __name__ == "__main__":
    main()