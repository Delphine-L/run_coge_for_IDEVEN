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
                try:
                    os.chdir("/bank/genfam/IDEVENv3/"+spe_list[i]+"_"+spe_list[j]+"/")
                    code_spe_1=dic_spe_coge[spe_list[i]]
                    code_spe_2=dic_spe_coge[spe_list[j]]
                    spe1_file= open("/bank/genfam/IDEVENv3/"+spe_list[i]+"/"+code_spe_1+"-CDS.fasta")
                    spe1_string=spe1_file.read()
                    spe1_array=spe1_string.split(">")
                    spe2_file= open("/bank/genfam/IDEVENv3/"+spe_list[j]+"/"+code_spe_2+"-CDS.fasta")
                    spe2_string=spe2_file.read()
                    spe2_array=spe2_string.split(">")
                    cds_file= open("./"+code_spe_1+"-"+code_spe_2+".cds", "w")
                except:
                    os.chdir("/bank/genfam/IDEVENv3/"+spe_list[j]+"_"+spe_list[i]+"/")
                    code_spe_1=dic_spe_coge[spe_list[j]]
                    code_spe_2=dic_spe_coge[spe_list[i]]
                    spe1_file= open("/bank/genfam/IDEVENv3/"+spe_list[j]+"/"+code_spe_1+"-CDS.fasta")
                    spe1_string=spe1_file.read()
                    spe1_array=spe1_string.split(">")
                    spe2_file= open("/bank/genfam/IDEVENv3/"+spe_list[i]+"/"+code_spe_2+"-CDS.fasta")
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
                cmd="  module load system/python/2.7.9; module load compiler/gcc/4.9.2; module load bioinfo/clustalw/2.1; module load bioinfo/paml/4.4; module load bioinfo/pal2nal/v14; qsub -V -q normal.q -N  ks_calc -b y   'python /usr/local/bioinfo/genfam/v201512/bio-pipeline/synonymous_calculation/synonymous_calc.py ./"+code_spe_1+"-"+code_spe_2+".cds > "+code_spe_1+"-"+code_spe_2+".ks '"
                #print(cmd)
                os.popen(cmd)    
                os.chdir("/bank/genfam/IDEVENv3/")
            j=j+1
	    i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            try:
                os.chdir("/bank/genfam/IDEVENv3/"+spe_list[i]+"_"+spe_list[j]+"/")
                code_spe_1=dic_spe_coge[spe_list[i]]
                code_spe_2=dic_spe_coge[spe_list[j]]
                spe1_file= open("/bank/genfam/IDEVENv3/"+spe_list[i]+"/"+code_spe_1+"-CDS.fasta")
                spe1_string=spe1_file.read()
                spe1_array=spe1_string.split(">")
                spe2_file= open("/bank/genfam/IDEVENv3/"+spe_list[j]+"/"+code_spe_2+"-CDS.fasta")
                spe2_string=spe2_file.read()
                spe2_array=spe2_string.split(">")
                cds_file= open("./"+code_spe_1+"-"+code_spe_2+".cds", "w")
            except:
                os.chdir("/bank/genfam/IDEVENv3/"+spe_list[j]+"_"+spe_list[i]+"/")
                code_spe_1=dic_spe_coge[spe_list[j]]
                code_spe_2=dic_spe_coge[spe_list[i]]
                spe1_file= open("/bank/genfam/IDEVENv3/"+spe_list[j]+"/"+code_spe_1+"-CDS.fasta")
                spe1_string=spe1_file.read()
                spe1_array=spe1_string.split(">")
                spe2_file= open("/bank/genfam/IDEVENv3/"+spe_list[i]+"/"+code_spe_2+"-CDS.fasta")
                spe2_string=spe2_file.read()
                spe2_array=spe2_string.split(">")
                cds_file= open("./"+code_spe_1+"-"+code_spe_2+".cds", "w")
#             os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
            pairs_file = open("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords")
            #########moveksfile= "mv "+code_spe_1+"-"+code_spe_2+".ks "+code_spe_1+"-"+code_spe_2+"_old2.ks"
            #########os.popen(moveksfile)
            #########pairs_file = open("./"+code_spe_1+"-"+code_spe_2+"_CDS.last")
            pair_list=[]
            for line in pairs_file:
                if line[0]!="#":
                    line_list=line.split("\t")
                    pair= [line_list[1].split("||")[3], line_list[5].split("||")[3]]
                    #########  pair= [line_list[0].split("||")[3], line_list[1].split("||")[3]]
                    print pair
                    pair_list.append(pair)
            #print pair_list
            for pair in pair_list:
                matching1 = [s for s in spe1_array if pair[0] in s]
                matching2 = [s for s in spe2_array if pair[1] in s]
                #print pair[0]
                print matching1
                print matching2
                if matching1!=[] and matching2!=[]:
                    cds_file.write(">"+matching1[0]+">"+matching2[0])
            spe1_file.close()
            spe2_file.close()
            cds_file.close()
            cmd="  module load system/python/2.7.9; module load compiler/gcc/4.9.2; module load bioinfo/clustalw/2.1; module load bioinfo/paml/4.4; module load bioinfo/pal2nal/v14; qsub -V -q normal.q -N  ks_calc -b y   'python /usr/local/bioinfo/genfam/v201512/bio-pipeline/synonymous_calculation/synonymous_calc.py ./"+code_spe_1+"-"+code_spe_2+".cds > "+code_spe_1+"-"+code_spe_2+".ks '"
            print(cmd)
            os.popen(cmd)    
            os.chdir("/bank/genfam/IDEVENv3/")
            j=j+1
        i=i+1
