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

# input_file = csv.DictReader(open("species_matrix.csv"),delimiter='\t')
# matrix={}
# for row in input_file:
#      #print row
#      matrix[row["species"]]=row

i=0
j=0
spe_list=dic_spe_coge.keys()


#------------------Calcul Ks----------------------------

if len(sys.argv)>1 :
    specie=sys.argv[1]
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            if spe_list[i]==specie or spe_list[j]==specie :
                cmd="  module load system/python/2.7.9; qsub -V -q normal.q -N  "+spe_list[i]+"-"+spe_list[j]+"-ks_calc -b y   'python2.7 /usr/local/bioinfo/genfam/v201512/precompute_IDEVEN/ks_single.py "+spe_list[i]+" "+spe_list[j]+" '"
                #print(cmd)
                os.popen(cmd)    
            j=j+1
	    i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            cmd="  module load system/python/2.7.9; qsub -V -q normal.q -N  "+spe_list[i]+"-"+spe_list[j]+"-ks_calc -b y   'python2.7 /usr/local/bioinfo/genfam/v201512/precompute_IDEVEN/ks_single.py "+spe_list[i]+" "+spe_list[j]+" '"
            print(cmd)
            os.popen(cmd)    
            j=j+1
        i=i+1
