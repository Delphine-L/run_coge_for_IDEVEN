#!/usr/bin/env python

import sys, os, re, subprocess, csv, ConfigParser

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
pathSynCalc = ConfigSectionMap("SynCalc")['path']

#--------------------------------------------------------------------


fichier = open("coge_id.txt","r")
dic_spe_coge={}
for line in fichier:
     spec=line.split(";")[0].strip()
     code=line.split(";")[1].strip()
     dic_spe_coge[spec]=code
fichier.close()
spe_list= []


#------------------Calcul Ks----------------------------

spe_list.append(sys.argv[1])
spe_list.append(sys.argv[2])
i=0
j=1


try:
    os.chdir(pathFiles+spe_list[i]+"_"+spe_list[j]+"/")
    code_spe_1=dic_spe_coge[spe_list[i]]
    code_spe_2=dic_spe_coge[spe_list[j]]
    spe1_file= open(pathFiles+spe_list[i]+"/"+code_spe_1+"-CDS.fasta")
    spe1_string=spe1_file.read()
    spe1_array=spe1_string.split(">")
    spe2_file= open(pathFiles+spe_list[j]+"/"+code_spe_2+"-CDS.fasta")
    spe2_string=spe2_file.read()
    spe2_array=spe2_string.split(">")
    cds_file= open("./"+code_spe_1+"-"+code_spe_2+".cds", "w")
except:
    os.chdir(pathFiles+spe_list[j]+"_"+spe_list[i]+"/")
    code_spe_1=dic_spe_coge[spe_list[j]]
    code_spe_2=dic_spe_coge[spe_list[i]]
    spe1_file= open(pathFiles+spe_list[j]+"/"+code_spe_1+"-CDS.fasta")
    spe1_string=spe1_file.read()
    spe1_array=spe1_string.split(">")
    spe2_file= open(pathFiles+spe_list[i]+"/"+code_spe_2+"-CDS.fasta")
    spe2_string=spe2_file.read()
    spe2_array=spe2_string.split(">")
    cds_file= open("./"+code_spe_1+"-"+code_spe_2+".cds", "w")
#print code_spe_1+code_spe_2
#                 os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
pairs_file = open("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords")
#moveksfile= "mv "+code_spe_1+"-"+code_spe_2+".ks "+code_spe_1+"-"+code_spe_2+"_old2.ks"
#os.popen(moveksfile)
######### pairs_file = open("./"+code_spe_1+"-"+code_spe_2+"_CDS.last")
pair_list=[]

for line in pairs_file:
    if line[0]!="#":
        line_list=line.split("\t")
        pair= [line_list[1].split("||")[3], line_list[5].split("||")[3]]
        #########  pair= [line_list[0].split("||")[3], line_list[1].split("||")[3]]
        #print pair
        pair_list.append(pair)
#print pair_list

# if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+".cds") :
#     statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+".cds")
#     if  statinfo.st_size==0:
#         for pair in pair_list:
#             matching1 = [s for s in spe1_array if pair[0] in s]
#             matching2 = [s for s in spe2_array if pair[1] in s]
#             #print pair[0]
#             print matching1
#             print matching2
#             cds_file.write(">"+matching1[0]+">"+matching2[0])
# else :
for pair in pair_list:
    matching1 = [s for s in spe1_array if pair[0] in s]
    matching2 = [s for s in spe2_array if pair[1] in s]
    #print pair[0]
    print matching1
    print matching2
    cds_file.write(">"+matching1[0]+">"+matching2[0])


spe1_file.close()
spe2_file.close()
cds_file.close()
cmd="  module load system/python/2.7.9; module load compiler/gcc/4.9.2; module load bioinfo/clustalw/2.1; module load bioinfo/paml/4.4; module load bioinfo/pal2nal/v14; qsub -V -q normal.q -N  ks_calc -b y   'python "+pathSynCalc+"synonymous_calculation/synonymous_calc.py ./"+code_spe_1+"-"+code_spe_2+".cds > "+code_spe_1+"-"+code_spe_2+".ks '"
#print(cmd)
print spe_list[i]+"_"+spe_list[j]
if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+".ks") :
    statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+".ks")
    if  statinfo.st_size<10000 :
        print cmd
        os.popen(cmd)
else :
    os.popen(cmd)
os.chdir(pathFiles)
