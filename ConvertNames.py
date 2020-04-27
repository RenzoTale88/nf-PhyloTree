import sys

for line in open(sys.argv[1]):
    line = line.replace("Cattle","")
    line2 = list(line.strip())
    newline = ""
    for n, i in enumerate(line2):
        if (i.isupper() and n > 0) or (i.isdigit() and not line[n-1].isdigit()):
            newline += " "
        newline += i        
    print('{}\t{}'.format(line.strip(), newline))

