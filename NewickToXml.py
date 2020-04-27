

def parser():
    import argparse
    parse = argparse.ArgumentParser()
    parse.add_argument("-i", "--input", metavar = 'file', type = str, help = 'Input tree', \
                            default = None, dest = 'infile', required=True)
    parse.add_argument("-o", "--output", metavar = 'file', type = str, help = 'Output tree (default = outfile)', \
                            default = "outtree", dest = 'outfile', required=False)
    parse.add_argument("-f", "--infmt", metavar = "nexus/newick/phyloxml", type = str, help = 'Input tree format', \
                            default = None, dest = 'infmt', required=True)
    parse.add_argument("-F", "--outfmt", metavar = "nexus/newick/phyloxml", type = str, help = 'Output tree format', \
                            default = "phyloxml", dest = 'outfmt', required=False)
    return parse.parse_args()


def main():
    from Bio import Phylo
    args = parser()
    Phylo.convert(args.infile, args.infmt, args.outfile, args.outfmt)


if __name__ == "__main__":
    main()
