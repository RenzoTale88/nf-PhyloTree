import sys

lines = ''.join(open(sys.argv[1]).readlines())
for line in open(sys.argv[2]):
    oid, nid = line.strip().split("\t")
    lines = lines.replace(oid, nid)

print(lines)
