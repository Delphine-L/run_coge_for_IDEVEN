#!/usr/bin/env python

import sys, os, re, subprocess, csv
fichier = open("coge_id.txt","r")
dic_spe_coge={}
for line in fichier:
	spec=line.split(";")[0].strip()
	code=line.split(";")[1].strip()
# 	os.popen("mkdir "+spec+"/")
#     os.chdir("/bank/genfam/IDEVEN/"+spec+"/")
    #cmd="wget -p /bank/genfam/IDEVEN/"+spec+"/ http://genomevolution.org/CoGe//data/fasta//"+code+"-CDS.fasta"
#     cmd="wget http://genomevolution.org/CoGe//data/fasta//"+code+"-CDS.fasta"
#     os.popen("qsub -V -q normal.q -N wget -b y  '"+cmd+"'")
	dic_spe_coge[spec]=code
#     os.chdir("/bank/genfam/IDEVEN/")
fichier.close()

# input_file = csv.DictReader(open("species_matrix.csv"),delimiter='\t')
# matrix={}
# for row in input_file:
     # print row
     # matrix[row["species"]]=row

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
#                 os.popen("mkdir "+spe_list[i]+"_"+spe_list[j]+"/")
                try:
                    os.chdir("/bank/genfam/IDEVENv3/"+spe_list[i]+"_"+spe_list[j]+"/")
                    code_spe_1=dic_spe_coge[spe_list[i]]
                    code_spe_2=dic_spe_coge[spe_list[j]]
                    cmd="qsub -V -q normal.q -N last -b y  '/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper/last.py -a 8 --dbpath=/bank/genfam/IDEVENv3/  --path=/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper /bank/genfam/IDEVENv3/"+spe_list[i]+"/"+code_spe_1+"-CDS.fasta /bank/genfam/IDEVENv3/"+spe_list[j]+"/"+code_spe_2+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
                except:
                    os.chdir("/bank/genfam/IDEVENv3/"+spe_list[j]+"_"+spe_list[i]+"/")
                    code_spe_1=dic_spe_coge[spe_list[j]]
                    code_spe_2=dic_spe_coge[spe_list[i]]
                    cmd="qsub -V -q normal.q -N last -b y  '/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper/last.py -a 8 --dbpath=/bank/genfam/IDEVENv3c/  --path=/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper /bank/genfam/IDEVENv3/"+spe_list[j]+"/"+code_spe_1+"-CDS.fasta /bank/genfam/IDEVENv3/"+spe_list[i]+"/"+code_spe_2+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
#                 os.popen("mkdir "+spe_list[i]+"_"+spe_list[j]+"/")
#                 os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
                print spe_list[i]+"_"+spe_list[j]
                # if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+"_CDS.last") :
#                     statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+"_CDS.last")
#                     if  statinfo.st_size<1000 :
#                         print cmd
#                         os.popen(cmd)
#                 else :
#                     os.popen(cmd)
                print cmd
                os.popen(cmd)
                os.chdir("/bank/genfam/IDEVENv3/")
            j=j+1
        i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
#             os.popen("mkdir "+spe_list[i]+"_"+spe_list[j]+"/")
            try:
				os.chdir("/bank/genfam/IDEVENv3/"+spe_list[i]+"_"+spe_list[j]+"/")
				code_spe_1=dic_spe_coge[spe_list[i]]
				code_spe_2=dic_spe_coge[spe_list[j]]
				cmd="qsub -V -q normal.q -N last -b y  '/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper/last.py -a 8 --dbpath=/bank/genfam/IDEVENv3/  --path=/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper /bank/genfam/IDEVENv3/"+spe_list[i]+"/"+code_spe_1+"-CDS.fasta /bank/genfam/IDEVENv3/"+spe_list[j]+"/"+code_spe_2+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
            except:
				os.chdir("/bank/genfam/IDEVENv3/"+spe_list[j]+"_"+spe_list[i]+"/")
				code_spe_1=dic_spe_coge[spe_list[j]]
				code_spe_2=dic_spe_coge[spe_list[i]]
				cmd="qsub -V -q normal.q -N last -b y  '/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper/last.py -a 8 --dbpath=/bank/genfam/IDEVENv3/  --path=/usr/local/bioinfo/genfam/v201512/coge/web/bin/last_wrapper /bank/genfam/IDEVENv3/"+spe_list[j]+"/"+code_spe_1+"-CDS.fasta /bank/genfam/IDEVENv3/"+spe_list[i]+"/"+code_spe_2+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
#             code_spe_1=dic_spe_coge[spe_list[i]]
#             code_spe_2=dic_spe_coge[spe_list[j]]
            # os.popen("mkdir "+spe_list[i]+"_"+spe_list[j]+"/")
#             os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
            print spe_list[i]+"_"+spe_list[j]
            if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+"_CDS.last") :
                statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+"_CDS.last")
                if  statinfo.st_size==0 :
                    print cmd
                    os.popen(cmd)
            else :
                os.popen(cmd)
            os.chdir("/bank/genfam/IDEVENv3/")
            j=j+1
        i=i+1
    
