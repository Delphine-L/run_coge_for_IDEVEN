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
pathCoge = ConfigSectionMap("CoGeInstall")['path']
print pathFiles;
print pathCoge;
#--------------------------------------------------------------------


fichier = open("coge_id.txt","r")
dic_spe_coge={}
for line in fichier:
	spec=line.split(";")[0].strip()
	code=line.split(";")[1].strip()
	dic_spe_coge[spec]=code
    # --------- uncomment the following lines to get a CDS from CoGe ------
    #cmd="wget -p "+pathFiles+spec+"/ http://genomevolution.org/CoGe//data/fasta//"+code+"-CDS.fasta"
    #os.popen("qsub -V -q normal.q -N wget -b y  '"+cmd+"'")
    # -------------------------------------------------------------
fichier.close()
i=0
j=0
spe_list=dic_spe_coge.keys()




#------------------Running genome comparison ----------------------------

if len(sys.argv)>1 :
    specie=sys.argv[1]
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            if spe_list[i]==specie or spe_list[j]==specie :
                #os.popen("mkdir "+spe_list[i]+"_"+spe_list[j]+"/") #comment if this is not a first run
                try:
                    os.chdir(pathFiles+spe_list[i]+"_"+spe_list[j]+"/")
                    code_spe_1=dic_spe_coge[spe_list[i]]
                    code_spe_2=dic_spe_coge[spe_list[j]]
                    cmd="qsub -V -q normal.q -N last -b y  '"+pathCoge+"web/bin/last_wrapper/last.py -a 8 --dbpath="+pathFiles+"  --path="+pathCoge+"web/bin/last_wrapper "+pathFiles+spe_list[i]+"/"+code_spe_1+"-CDS.fasta "+pathFiles+spe_list[j]+"/"+code_spe_2+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
                except:
                    os.chdir(pathFiles+spe_list[j]+"_"+spe_list[i]+"/")
                    code_spe_1=dic_spe_coge[spe_list[j]]
                    code_spe_2=dic_spe_coge[spe_list[i]]
                    cmd="qsub -V -q normal.q -N last -b y  '"+pathCoge+"web/bin/last_wrapper/last.py -a 8 --dbpath="+pathFiles+"  --path="+pathCoge+"web/bin/last_wrapper "+pathFiles+spe_list[j]+"/"+code_spe_1+"-CDS.fasta "+pathFiles+spe_list[i]+"/"+code_spe_2+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
                print cmd
                os.popen(cmd)
                os.chdir(pathFiles)
            j=j+1
        i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            #os.popen("mkdir "+spe_list[i]+"_"+spe_list[j]+"/") #comment if this is not a first run
            try:
				os.chdir(pathFiles+spe_list[i]+"_"+spe_list[j]+"/")
				code_spe_1=dic_spe_coge[spe_list[i]]
				code_spe_2=dic_spe_coge[spe_list[j]]
				cmd="qsub -V -q normal.q -N last -b y  '"+pathCoge+"web/bin/last_wrapper/last.py -a 8 --dbpath="+pathFiles+"  --path=/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper "+pathFiles+spe_list[i]+"/"+code_spe_1+"-CDS.fasta "+pathFiles+spe_list[j]+"/"+code_spe_2+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
            except:
				os.chdir(pathFiles+spe_list[j]+"_"+spe_list[i]+"/")
				code_spe_1=dic_spe_coge[spe_list[j]]
				code_spe_2=dic_spe_coge[spe_list[i]]
				cmd="qsub -V -q normal.q -N last -b y  '"+pathCoge+"web/bin/last_wrapper/last.py -a 8 --dbpath="+pathFiles+"  --path="+pathCoge+"web/bin/last_wrapper "+pathFiles+spe_list[j]+"/"+code_spe_1+"-CDS.fasta "+pathFiles+spe_list[i]+"/"+code_spe_2+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
            print spe_list[i]+"_"+spe_list[j]
            if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+"_CDS.last") :
                statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+"_CDS.last")
                if  statinfo.st_size==0 :
                    os.popen(cmd)
            else :
                os.popen(cmd)
                print cmd
            os.chdir(pathFiles)
            j=j+1
        i=i+1
