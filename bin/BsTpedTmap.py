#!/usr/bin/env python

import sys
import subprocess as sbp
import random as rn

tfile = sys.argv[1]             # Input tped/tfam suffix.
bsfile=sys.argv[2]
nboot=sys.argv[3]


# Lists
inds = []
markers = []

# Store input tfam.
for line in open(tfile + '.tfam'):
	inds.append(line)

# Read input tped.
for line in open(tfile + '.tped'):
	markers.append(line)

# Number of SNP to choose.
nsnp = len(markers)

# Perform bootstrap.
mrklist = [int(i) for i in open(bsfile)]
otfam = open("BS_" + str(nboot) + '.tfam', 'w')
[otfam.write('%s' % i) for i in inds]
otfam.close()
otped = open("BS_" + str(nboot) + '.tped', 'w')
[otped.write("%s" % markers[mrk]) for mrk in mrklist]
otped.close()