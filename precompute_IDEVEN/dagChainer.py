#!/usr/bin/env python

import sys, os, re, subprocess, csv, ConfigParser
fichier = open("coge_id.txt","r")
dic_spe_coge={}


#------Parsing of the config file https://wiki.python.org/moin/ConfigParserExamples
config = ConfigParser.ConfigParser()
config.read("config.ini")

def ConfigSectionMap(section):
    dict1 = {}
    options = config.options(section)
    for option in options:
        try:
            dict1[option] = config.get(section, option)
            if dict1[option] == -1:
                DebugPrint("skip: %s" % option)
        except:
            print("exception on %s!" % option)
            dict1[option] = None
    return dict1

pathFiles = ConfigSectionMap("Repository")['path']
pathCoge = ConfigSectionMap("CoGeInstall")['path']
print pathFiles;
print pathCoge;
#--------------------------------------------------------------------


for line in fichier:
     spec=line.split(";")[0].strip()
     code=line.split(";")[1].strip()
     dic_spe_coge[spec]=code
fichier.close()

i=0
j=0
spe_list=dic_spe_coge.keys()


#------------------Running DAGChainer----------------------------

if len(sys.argv)>1 :
    specie=sys.argv[1]
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            if spe_list[i]==specie or spe_list[j]==specie :
                try:
                    os.chdir(pathFiles+spe_list[i]+"_"+spe_list[j]+"/")
                    code_spe_1=dic_spe_coge[spe_list[i]]
                    code_spe_2=dic_spe_coge[spe_list[j]]
                except:
                    os.chdir(pathFiles+spe_list[j]+"_"+spe_list[i]+"/")
                    code_spe_1=dic_spe_coge[spe_list[j]]
                    code_spe_2=dic_spe_coge[spe_list[i]]
                cmd=" qsub -V -q normal.q -N  dag_chainer -b y   '/usr/bin/python "+pathCoge+"web/bin/dagchainer_bp/dag_chainer.py -E 0.05 -i ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go -D 20 -g 10 -A 5 > ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords'"
                print spe_list[i]+"_"+spe_list[j]
                if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords") :
                    statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords")
                    if  statinfo.st_size<1000 :
                        print cmd
                        os.popen(cmd)
                else :
                    os.popen(cmd)
                os.chdir(pathFiles)
            j=j+1
        i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            try:
				os.chdir(pathFiles+spe_list[i]+"_"+spe_list[j]+"/")
				code_spe_1=dic_spe_coge[spe_list[i]]
				code_spe_2=dic_spe_coge[spe_list[j]]
            except:
				os.chdir(pathFiles+spe_list[j]+"_"+spe_list[i]+"/")
				code_spe_1=dic_spe_coge[spe_list[j]]
				code_spe_2=dic_spe_coge[spe_list[i]]
#             os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
            cmd=" qsub -V -q normal.q -N  dag_chainer -b y   '"+pathCoge+"web/bin/dagchainer_bp/dag_chainer.py -E 0.05 -i ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go -D 20 -g 10 -A 5 > ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords'"
            print spe_list[i]+"_"+spe_list[j]
            if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords") :
                statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords")
                if  statinfo.st_size<1000 :
                    print cmd
                    os.popen(cmd)
            else :
                os.popen(cmd)
            os.chdir(pathFiles)
            j=j+1
        i=i+1
