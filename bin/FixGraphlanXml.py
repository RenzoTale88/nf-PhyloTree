#!/usr/bin/env python

def getColours(annotation, groups):
    import random as rn
    colours = {}
    tmp = []
    for g in groups:
        palette = (rn.sample(0,255), rn.sample(0,255), rn.sample(0,255) ) 
        if palette not in tmp: 
            tmp.append(palette)
            colours[g] = [palette] 
    return { s: colours[annotation[s]] for s in annotation } 


def hasEmbeddedColours(myfile):
    for line in open(myfile):
        if "color" in line:
            return True
    return False



def parser():
    import argparse
    parse = argparse.ArgumentParser()
    parse.add_argument("-i", "--input", metavar = 'xml', type = str, help = 'Input phyloXml tree', \
                            default = None, dest = 'infile', required=True)
    parse.add_argument("-g", "--groups", metavar = "groupfile", type = str, help = 'Input grouping file', \
                            default = None, dest = 'ingroup', required=False)
    parse.add_argument("-f", "--font", metavar = "size", type = int, help = 'Font size to use', \
                            default = 10, dest = 'font_size', required=False)
    parse.add_argument("-m", "--scale", metavar = "ratio", type = float, help = 'Marker scale value', \
                            default = 1.0, dest = 'markerScale', required=False)
    return parse.parse_args()


def noColours(inxml, font_size, markerScale):
    import xml.etree.ElementTree as ET
    CIxml='''<property applies_to="clade" datatype="xsd:string" id_ref="clade_marker_size" ref="A:1">{}</property>'''
    CIshape = '''<property applies_to="clade" datatype="xsd:string" id_ref="clade_marker_shape" ref="A:1">{}</property> '''
    ANNOTxmlA= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation" ref="A:1">{}</property>'''
    ANNOTxmlB= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_background_color" ref="A:1">w</property>'''
    ANNOTxmlC= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_rotation" ref="A:1">90</property>'''
    ANNOTxmlD= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_font_size" ref="A:1">{}</property>'''.format(font_size)


    for line in open(inxml):
        line = line.replace('\n', '')
        if "confidence" in line:
            CIval = ET.fromstring(line).text
            CIval = int(float(CIval))
            print(line)
            if int(CIval) >= 90 and CIval <= 100:
                print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("h"))
            elif int(CIval) < 90 and CIval >= 75:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("*"))
            elif int(CIval) < 75 and CIval >= 50:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("s"))
            elif int(CIval) < 50:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("o"))
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIxml.format(CIval * markerScale))
            continue
        elif "<name>" in line and ET.fromstring(line).text != "tree1":
            cladeName = ET.fromstring(line).text
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlA.format(cladeName))
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlB)
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlC)
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlD)
            continue
        print(line.replace('\n', '')) 


def withoutColours(inxml, colours, font_size, markerScale):
    import xml.etree.ElementTree as ET
    from colormap import rgb2hex
    CIxml='''<property applies_to="clade" datatype="xsd:string" id_ref="clade_marker_size" ref="A:1">{}</property>'''
    CIshape = '''<property applies_to="clade" datatype="xsd:string" id_ref="clade_marker_shape" ref="A:1">{}</property> '''
    COLORxml = '''<property applies_to="clade" datatype="xsd:string" id_ref="clade_marker_color" ref="A:1">{}</property> '''
    ANNOTxmlA= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation" ref="A:1">{}</property>'''
    ANNOTxmlB= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_background_color" ref="A:1">w</property>'''
    ANNOTxmlC= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_rotation" ref="A:1">90</property>'''
    ANNOTxmlD= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_font_size" ref="A:1">{}</property>'''.format(font_size)
    



    for line in open(inxml):
        line = line.replace('\n', '')
        if "confidence" in line:
            CIval = ET.fromstring(line).text
            CIval = int(float(CIval))
            print(line)
            if int(CIval) >= 90 and CIval <= 100:
                print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("h"))
            elif int(CIval) < 90 and CIval >= 75:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("*"))
            elif int(CIval) < 75 and CIval >= 50:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("s"))
            elif int(CIval) < 50:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("o"))
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIxml.format(CIval * markerScale))
            continue
        elif "<name>" in line and ET.fromstring(line).text != "tree1":
            cladeName = ET.fromstring(line).text
            mycolour = colours[cladeName]
            mynewcolor = rgb2hex(mycolour[0], mycolour[1], mycolour[2])
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlA.format(cladeName))
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlB)
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlC)
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlD)
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + COLORxml.format(mynewcolor))
            continue
        print(line.replace('\n', '')) 



def withColours(inxml, font_size, markerScale):
    import xml.etree.ElementTree as ET
    from colormap import rgb2hex
    CIxml='''<property applies_to="clade" datatype="xsd:string" id_ref="clade_marker_size" ref="A:1">{}</property>'''
    CIshape = '''<property applies_to="clade" datatype="xsd:string" id_ref="clade_marker_shape" ref="A:1">{}</property> '''
    COLORxml = '''<property applies_to="clade" datatype="xsd:string" id_ref="clade_marker_color" ref="A:1">{}</property> '''
    ANNOTxmlA= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation" ref="A:1">{}</property>'''
    ANNOTxmlB= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_background_color" ref="A:1">w</property>'''
    ANNOTxmlC= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_rotation" ref="A:1">90</property>'''
    ANNOTxmlD= '''<property applies_to="clade" datatype="xsd:string" id_ref="annotation_font_size" ref="A:1">{}</property>'''.format(font_size)
    iscolor = False
    color = {"red":0, "green":0, "blue":0}




    for line in open(inxml):
        line = line.replace('\n', '')
        if "confidence" in line:
            CIval = ET.fromstring(line).text
            CIval = int(float(CIval))
            print(line)
            if int(CIval) >= 90 and CIval <= 100:
                print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("h"))
            elif int(CIval) < 90 and CIval >= 75:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("*"))
            elif int(CIval) < 75 and CIval >= 50:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("s"))
            elif int(CIval) < 50:
                    print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIshape.format("o"))
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + CIxml.format(CIval * markerScale))
            continue
        elif "<name>" in line and ET.fromstring(line).text != "tree1":
            cladeName = ET.fromstring(line).text
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlA.format(cladeName))
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlB)
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlC)
            print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + ANNOTxmlD)
            continue
        elif "color" in line and not iscolor:
            iscolor = True
            continue
        elif iscolor:
            if "color" in line:
                mynewcolor = rgb2hex(color["red"], color["green"], color["blue"])
                print("".join([' ' for i in line.split("<")[0] if i == ' ' ]) + COLORxml.format(mynewcolor))
                iscolor = False
                continue
            col = ET.fromstring(line).tag
            txt = ET.fromstring(line).text
            color[col] = int(txt)
            continue
        print(line.replace('\n', '')) 





def main():
    import sys
    args = parser()


    # Inputs
    inxml = args.infile
    font_size = int(args.font_size)
    markerScale = float(args.markerScale)
    if args.ingroup:
        assignments = { line.strip().split()[0] : line.strip().split()[1] for line in open(args.ingroup) }
        groups = list(set( assignments.values() ))
        colours = getColours(assignments, groups)

        if hasEmbeddedColours(inxml):
            withColours(inxml, font_size, markerScale)
        else:
            withoutColours(inxml, colours, font_size, markerScale)
    else:
        noColours(inxml, font_size, markerScale)


if __name__ == "__main__":
    main()
