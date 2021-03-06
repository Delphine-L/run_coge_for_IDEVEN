                                                                                                                                                                                                                  #!/usr/bin/env python

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
     # --------- uncomment the following lines to get a CDS from CoGe ------
     #cmd="wget -p "+pathFiles+spec+"/ http://genomevolution.org/CoGe//data/fasta//"+code+"-CDS.fasta"
     #os.popen("qsub -V -q normal.q -N wget -b y  '"+cmd+"'")
     # -------------------------------------------------------------
     dic_spe_coge[spec]=code
     dic_spe_coge[spec]=code
fichier.close()
i=0
j=0
spe_list=dic_spe_coge.keys()

#------------------Creating .bed files ----------------------------

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
				cmd="qsub -V -q normal.q -N  blast2bed -b y '"+pathCoge+"web/bin/SynMap/blast2bed.pl -infile ./"+code_spe_1+"-"+code_spe_2+"_CDS.last -outfile1 ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.q.bed -outfile2 ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed'"
				print spe_list[i]+"_"+spe_list[j]
				# if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed") :
# 				    statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed")
# 				    if  statinfo.st_size<1000 :
# 				        print cmd
# 				        os.popen(cmd)
# 				else :
# 				    os.popen(cmd)
				print cmd
				os.popen(cmd)
				os.chdir(pathFiles)
            j=j+1
        i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            print spe_list[i]+"_"+spe_list[j]
            try:
				os.chdir(pathFiles+spe_list[i]+"_"+spe_list[j]+"/")
				code_spe_1=dic_spe_coge[spe_list[i]]
				code_spe_2=dic_spe_coge[spe_list[j]]
            except:
				os.chdir(pathFiles+spe_list[j]+"_"+spe_list[i]+"/")
				code_spe_1=dic_spe_coge[spe_list[j]]
				code_spe_2=dic_spe_coge[spe_list[i]]
            cmd="qsub -V -q normal.q -N  blast2bed -b y '"+pathCoge+"web/bin/SynMap/blast2bed.pl -infile ./"+code_spe_1+"-"+code_spe_2+"_CDS.last -outfile1 ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.q.bed -outfile2 ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed'"
            print spe_list[i]+"_"+spe_list[j]
            if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed") :
                statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed")
                if  statinfo.st_size<1000 :
                    print cmd
                    os.popen(cmd)
            else :
                os.popen(cmd)
            os.chdir(pathFiles)
            j=j+1
        i=i+1
