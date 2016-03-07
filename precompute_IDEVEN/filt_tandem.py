#!/usr/bin/env python

import sys, os, re, subprocess, csv
fichier = open("coge_id.txt","r")
dic_spe_coge={}
for line in fichier:
     spec=line.split(";")[0].strip()
     code=line.split(";")[1].strip()
#     os.popen("mkdir "+spec+"/")
#     os.chdir("/bank/genfam/IDEVEN/"+spec+"/")
     #cmd="wget -p /bank/genfam/IDEVEN/"+spec+"/ http://genomevolution.org/CoGe//data/fasta//"+code+"-CDS.fasta"
#     cmd="wget http://genomevolution.org/CoGe//data/fasta//"+code+"-CDS.fasta"
#     os.popen("qsub -V -q normal.q -N wget -b y  '"+cmd+"'")
     dic_spe_coge[spec]=code
#     os.chdir("/bank/genfam/IDEVEN/")
fichier.close()

i=0
j=0
spe_list=dic_spe_coge.keys()

#------------------Filtering tandem dups ----------------------------

if len(sys.argv)>1 :
    specie=sys.argv[1]
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            # code_spe_1=dic_spe_coge[spe_list[i]]
            # code_spe_2=dic_spe_coge[spe_list[j]]
            if spe_list[i]==specie or spe_list[j]==specie :
                # os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
                try:
					os.chdir("/bank/genfam/IDEVENv3/"+spe_list[i]+"_"+spe_list[j]+"/")
					code_spe_1=dic_spe_coge[spe_list[i]]
					code_spe_2=dic_spe_coge[spe_list[j]]
                except:
					os.chdir("/bank/genfam/IDEVENv3/"+spe_list[j]+"_"+spe_list[i]+"/")
					code_spe_1=dic_spe_coge[spe_list[j]]
					code_spe_2=dic_spe_coge[spe_list[i]]
                cmd="qsub -V -q normal.q -N  blast_to_raw -b y '/usr/local/bioinfo/genfam/v201512/coge/web/bin/quota-alignment/scripts/blast_to_raw.py ./"+code_spe_1+"-"+code_spe_2+"_CDS.last --localdups --qbed  ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.q.bed --sbed ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed --tandem_Nmax 10 --cscore 0 > ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered'"
                print spe_list[i]+"_"+spe_list[j]
                if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered") :
                    statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered")
                    if  statinfo.st_size<1000 :
                        print cmd
                        os.popen(cmd)
                else :
                    os.popen(cmd)
                os.chdir("/bank/genfam/IDEVENv3/")
            j=j+1
        i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            # code_spe_1=dic_spe_coge[spe_list[i]]
            # code_spe_2=dic_spe_coge[spe_list[j]]
            # os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
            try:
				os.chdir("/bank/genfam/IDEVENv3/"+spe_list[i]+"_"+spe_list[j]+"/")
				code_spe_1=dic_spe_coge[spe_list[i]]
				code_spe_2=dic_spe_coge[spe_list[j]]
            except:
				os.chdir("/bank/genfam/IDEVENv3/"+spe_list[j]+"_"+spe_list[i]+"/")
				code_spe_1=dic_spe_coge[spe_list[j]]
				code_spe_2=dic_spe_coge[spe_list[i]]
            cmd="qsub -V -q normal.q -N  blast_to_raw -b y '/usr/local/bioinfo/genfam/v201512/coge/web/bin/quota-alignment/scripts/blast_to_raw.py ./"+code_spe_1+"-"+code_spe_2+"_CDS.last --localdups --qbed  ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.q.bed --sbed ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed --tandem_Nmax 10 --cscore 0 > ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered'"
            print spe_list[i]+"_"+spe_list[j]
            if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered") :
                statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered")
                if  statinfo.st_size<1000 :
                    print cmd
                    os.popen(cmd)
            else :
                os.popen(cmd)
            os.chdir("/bank/genfam/IDEVENv3/")
            j=j+1
        i=i+1
