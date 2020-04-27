

def parser():
    import argparse
    parse = argparse.ArgumentParser()
    parse.add_argument("-i", "--input", meta = "infile", required = True, dest = "intree", type = str)
    parse.add_argument("-o", "--output", meta = "outfile", required = True, dest = "outtree", type = str)
    parse.add_argument("-f", "--infmt", meta = "nexus/newick/phyloxml", required = True, dest = "infmt", type = str)
    parse.add_argument("-F", "--outfmt", meta = "nexus/newick/phyloxml", required = True, dest = "outfmt", type = str)
    return parse.parse_args()


def main():
    from Bio import Phylo
    args = parser()
    Phylo.convert(args.infile, args.infmt, args.outfile, args.outfmt)


if __name__ == "__main__":
    main()
