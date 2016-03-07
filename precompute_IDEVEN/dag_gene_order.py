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

input_file = csv.DictReader(open("species_matrix.csv"),delimiter='\t')
matrix={}
for row in input_file:
     #print row
     matrix[row["species"]]=row

i=0
j=0
spe_list=dic_spe_coge.keys()


#------------------Running DAGChainer----------------------------

if len(sys.argv)>1 :
    specie=sys.argv[1]
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            # code_spe_1=dic_spe_coge[spe_list[i]]
#             code_spe_2=dic_spe_coge[spe_list[j]]
            if spe_list[i]==specie or spe_list[j]==specie :
                try:
                    os.chdir("/bank/genfam/IDEVENv3/"+spe_list[i]+"_"+spe_list[j]+"/")
                    code_spe_1=dic_spe_coge[spe_list[i]]
                    code_spe_2=dic_spe_coge[spe_list[j]]
                    try :
                        if spe_list[j]=="ORYSI" :
                            spec1="ORYSJ"
    # 				        synt_depth_string=matrix[spe_list[j].replace("REF_","")]["ORYSJ"]
                        elif spe_list[j].replace("REF_","")=="EUCGR" :
                            spec1="THECC"
    # 				        synt_depth_string=matrix[spe_list[j].replace("REF_","")]["THECC"]
                        else :
                            spec1 = spe_list[j].replace("REF_","")
                        if spe_list[i]=="ORYSI" :
                            spec2="ORYSJ"
    # 				        synt_depth_string=matrix["ORYSJ"][spe_list[i].replace("REF_","")]
                        elif spe_list[i].replace("REF_","")=="EUCGR" :
                            spec2="THECC"
    # 				        synt_depth_string=matrix["THECC"][spe_list[i].replace("REF_","")]
                        else :
                            spec2 = spe_list[i].replace("REF_","")
                        synt_depth_string=matrix[spec2][spec1]
                    except :
                        print spe_list[i]+" "+spe_list[j]
                except:
                    os.chdir("/bank/genfam/IDEVENv3/"+spe_list[j]+"_"+spe_list[i]+"/")
                    code_spe_1=dic_spe_coge[spe_list[j]]
                    code_spe_2=dic_spe_coge[spe_list[i]]
                    try :
                        if spe_list[i]=="ORYSI" :
                            spec1="ORYSJ"
    # 				        synt_depth_string=matrix[spe_list[j].replace("REF_","")]["ORYSJ"]
                        elif spe_list[i].replace("REF_","")=="EUCGR" :
                            spec1="THECC"
    # 				        synt_depth_string=matrix[spe_list[j].replace("REF_","")]["THECC"]
                        else :
                            spec1 = spe_list[i].replace("REF_","")
                        if spe_list[j]=="ORYSI" :
                            spec2="ORYSJ"
    # 				        synt_depth_string=matrix["ORYSJ"][spe_list[i].replace("REF_","")]
                        elif spe_list[j].replace("REF_","")=="EUCGR" :
                            spec2="THECC"
    # 				        synt_depth_string=matrix["THECC"][spe_list[i].replace("REF_","")]
                        else :
                            spec2 = spe_list[j].replace("REF_","")
                        synt_depth_string=matrix[spec2][spec1]
                    except :
                        print spe_list[j]+" "+spe_list[i]
                try:
#                     synt_depth_string=matrix[spe_list[i]][spe_list[j]]
                    if synt_depth_string=="null":
                        synt_depth_string="1:1" 
                    print "test :"+synt_depth_string+"\n"
                    synt_depth_list=synt_depth_string.strip().split(":")
                    print synt_depth_list[0]
                    print synt_depth_list[1]
#                     synt_depth_list=synt_depth_string.split(":")
#                     os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
                    cmd="qsub -V -q normal.q -N  dag_chainer -b y   'python  /usr/local/bioinfo/genfam/v201512/coge/web/bin/SynMap/gene_order.py ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40 ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40.gcoords --positional '"
                    print spe_list[i]+"_"+spe_list[j]
                    if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40.gcoords") :
                        statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40.gcoords")
                        if  statinfo.st_size<1000 :
                            print cmd
                            os.popen(cmd)
                    else :
                        os.popen(cmd)
                    os.chdir("/bank/genfam/IDEVENv3/")
                except:
                    print "ok"
            j=j+1
        i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            # code_spe_1=dic_spe_coge[spe_list[i]]
#             code_spe_2=dic_spe_coge[spe_list[j]]
            try:
				os.chdir("/bank/genfam/IDEVENv3/"+spe_list[i]+"_"+spe_list[j]+"/")
				code_spe_1=dic_spe_coge[spe_list[i]]
				code_spe_2=dic_spe_coge[spe_list[j]]
				try :
				    if spe_list[j]=="ORYSI" :
				        spec1="ORYSJ"
# 				        synt_depth_string=matrix[spe_list[j].replace("REF_","")]["ORYSJ"]
				    elif spe_list[j].replace("REF_","")=="EUCGR" :
				        spec1="THECC"
# 				        synt_depth_string=matrix[spe_list[j].replace("REF_","")]["THECC"]
				    else :
				        spec1 = spe_list[j].replace("REF_","")
				    if spe_list[i]=="ORYSI" :
				        spec2="ORYSJ"
# 				        synt_depth_string=matrix["ORYSJ"][spe_list[i].replace("REF_","")]
				    elif spe_list[i].replace("REF_","")=="EUCGR" :
				        spec2="THECC"
# 				        synt_depth_string=matrix["THECC"][spe_list[i].replace("REF_","")]
				    else :
				        spec2 = spe_list[i].replace("REF_","")
				    synt_depth_string=matrix[spec2][spec1]
				except :
				    print spe_list[i]+" "+spe_list[j]
            except:
				os.chdir("/bank/genfam/IDEVENv3/"+spe_list[j]+"_"+spe_list[i]+"/")
				code_spe_1=dic_spe_coge[spe_list[j]]
				code_spe_2=dic_spe_coge[spe_list[i]]
				try :
				    if spe_list[i]=="ORYSI" :
				        spec1="ORYSJ"
# 				        synt_depth_string=matrix[spe_list[j].replace("REF_","")]["ORYSJ"]
				    elif spe_list[i].replace("REF_","")=="EUCGR" :
				        spec1="THECC"
# 				        synt_depth_string=matrix[spe_list[j].replace("REF_","")]["THECC"]
				    else :
				        spec1 = spe_list[i].replace("REF_","")
				    if spe_list[j]=="ORYSI" :
				        spec2="ORYSJ"
# 				        synt_depth_string=matrix["ORYSJ"][spe_list[i].replace("REF_","")]
				    elif spe_list[j].replace("REF_","")=="EUCGR" :
				        spec2="THECC"
# 				        synt_depth_string=matrix["THECC"][spe_list[i].replace("REF_","")]
				    else :
				        spec2 = spe_list[j].replace("REF_","")
				    synt_depth_string=matrix[spec2][spec1]
				except :
				    print spe_list[j]+" "+spe_list[i]
            try:
#                 synt_depth_string=matrix[spe_list[i]][spe_list[j]]
                if synt_depth_string=="null":
                    synt_depth_string="1:1" 
                print "test :"+synt_depth_string+"\n"
                synt_depth_list=synt_depth_string.strip().split(":")
                print synt_depth_list[0]
                print synt_depth_list[1]
#                 os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
                cmd="qsub -V -q normal.q -N  dag_chainer -b y   'python  /usr/local/bioinfo/genfam/v201512/coge/web/bin/SynMap/gene_order.py ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40 ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40.gcoords --positional '"
                print spe_list[i]+"_"+spe_list[j]
                if  os.path.exists("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40.gcoords") :
                    statinfo = os.stat("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40.gcoords")
                    if  statinfo.st_size<1000 :
                        print cmd
                        os.popen(cmd)
                else :
                    os.popen(cmd)
                os.chdir("/bank/genfam/IDEVENv3/")
            except:
                print "ok"
            j=j+1
        i=i+1
    



