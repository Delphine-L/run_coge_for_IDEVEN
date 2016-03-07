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

#------------------Running genome comparison ----------------------------

if sys.argv[1] :
    specie=sys.argv[1]
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            code_spe_1=dic_spe_coge[spe_list[i]]
            code_spe_2=dic_spe_coge[spe_list[j]]
            if spe_list[i]==specie :
                os.popen("mkdir "+spe_list[i]+"_"+spe_list[j]+"/")
                os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
                print spe_list[i]+"_"+spe_list[j]
                cmd="qsub -V -q normal.q -N last -b y  '/home/lariviere/tool/coge/web/bin/last_wrapper/last.py -a 8 --dbpath=/bank/genfam/IDEVEN/  --path=/home/lariviere/tool/coge/web/bin/last_wrapper /bank/genfam/IDEVEN/"+spe_list[j]+"/"+code_spe_2+"-CDS.fasta /bank/genfam/IDEVEN/"+spe_list[i]+"/"+code_spe_1+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
                print cmd
                os.popen(cmd)
                os.chdir("/bank/genfam/IDEVEN/")
            j=j+1
        i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            code_spe_1=dic_spe_coge[spe_list[i]]
            code_spe_2=dic_spe_coge[spe_list[j]]
            os.popen("mkdir "+spe_list[i]+"_"+spe_list[j]+"/")
            os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
            print spe_list[i]+"_"+spe_list[j]
            cmd="qsub -V -q normal.q -N last -b y  '/home/lariviere/tool/coge/web/bin/last_wrapper/last.py -a 8 --dbpath=/bank/genfam/IDEVEN/  --path=/home/lariviere/tool/coge/web/bin/last_wrapper /bank/genfam/IDEVEN/"+spe_list[j]+"/"+code_spe_2+"-CDS.fasta /bank/genfam/IDEVEN/"+spe_list[i]+"/"+code_spe_1+"-CDS.fasta -o ./"+code_spe_1+"-"+code_spe_2+"_CDS.last'"
            print cmd
            os.popen(cmd)
            os.chdir("/bank/genfam/IDEVEN/")
            j=j+1
        i=i+1
    

#------------------Creating .bed files ----------------------------

# while(i<=len(spe_list)-1):
	# j=i
	# while(j<=len(spe_list)-1):
		# code_spe_1=dic_spe_coge[spe_list[i]]
		# code_spe_2=dic_spe_coge[spe_list[j]]
		# if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
			# os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
			# cmd="qsub -V -q normal.q -N  blast2bed -b y '/home/lariviere/tool/coge/web/bin/SynMap/blast2bed.pl -infile ./"+code_spe_1+"-"+code_spe_2+"_CDS.last -outfile1 ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.q.bed -outfile2 ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed'"
			# os.popen(cmd)
			# print cmd
			# os.chdir("/bank/genfam/IDEVEN/")
		# j=j+1
	# i=i+1

#------------------Filtering tandem dups ----------------------------

# while(i<=len(spe_list)-1):
	# j=i
	# while(j<=len(spe_list)-1):
		# code_spe_1=dic_spe_coge[spe_list[i]]
		# code_spe_2=dic_spe_coge[spe_list[j]]
		# if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
			# os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
			# cmd="qsub -V -q normal.q -N  blast_to_raw -b y '/home/lariviere/tool/coge/web/bin/quota-alignment/scripts/blast_to_raw.py ./"+code_spe_1+"-"+code_spe_2+"_CDS.last --localdups --qbed  ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.q.bed --sbed ./"+code_spe_1+"-"+code_spe_2+"_CDS.last.s.bed --tandem_Nmax 10 --cscore 0 > ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered'"
			# os.popen(cmd)
			# os.chdir("/bank/genfam/IDEVEN/")
		# j=j+1
	# i=i+1

#------------------Formatting for DagChainer ----------------------------

# while(i<=len(spe_list)-1):
# 	j=i
# 	while(j<=len(spe_list)-1):
# 		code_spe_1=dic_spe_coge[spe_list[i]]
# 		code_spe_2=dic_spe_coge[spe_list[j]]
# 		if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
# 			os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
# 			cmd="module load system/python/2.7.9; qsub -V -q normal.q -N  dag_tools -b y  '/home/lariviere/tool/coge/web/bin/SynMap/dag_tools.py -q a"+code_spe_1+" -s b"+code_spe_2+" -b ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered -c > ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all'"
# 			os.popen(cmd)
# 			os.chdir("/bank/genfam/IDEVEN/")
# 		j=j+1
# 	i=i+1

#------------------Converting to genomic order----------------------------

# while(i<=len(spe_list)-1):
#     j=i
#     while(j<=len(spe_list)-1):
#         code_spe_1=dic_spe_coge[spe_list[i]]
#         code_spe_2=dic_spe_coge[spe_list[j]]
#         if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
# 			os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
# 			cmd="module load system/python/2.7.9; qsub -V -q normal.q -N  gene_order -b y   '/home/lariviere/tool/coge/web/bin/SynMap/gene_order.py ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go --gid1 "+code_spe_1+" --gid2 "+code_spe_2+" --feature1 CDS --feature2 CDS'"
# 			os.popen(cmd)
# 			os.chdir("/bank/genfam/IDEVEN/")
#         j=j+1
#     i=i+1
     
#------------------Running DAGChainer----------------------------
# 
# while(i<=len(spe_list)-1):
# 	j=i
# 	while(j<=len(spe_list)-1):
# 		code_spe_1=dic_spe_coge[spe_list[i]]
# 		code_spe_2=dic_spe_coge[spe_list[j]]
# 		if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
# 			os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
# 			cmd=" qsub -V -q normal.q -N  dag_chainer -b y   '/usr/bin/python /home/lariviere/tool/coge/web/bin/dagchainer_bp/dag_chainer.py -E 0.05 -i ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go -D 20 -g 10 -A 5 > ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords'"
# 			print(cmd)
# 			os.popen(cmd)
# 			os.chdir("/bank/genfam/IDEVEN/")
# 		j=j+1
# 	i=i+1
     
#------------------Running quota align----------------------------


# while(i<=len(spe_list)-1):
   # j=i
   # while(j<=len(spe_list)-1):
       # code_spe_1=dic_spe_coge[spe_list[i]]
       # code_spe_2=dic_spe_coge[spe_list[j]]
	   # if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
		   # try:
			   # synt_depth_string=matrix[spe_list[i]][spe_list[j]]
			   # if synt_depth_string=="null":
				   # synt_depth_string="1:1"
			   # print synt_depth_string+"\n"
		   # except:
	   # j=j+1
   # i=i+1
     
# i=0
# j=0
# spe_list=dic_spe_coge.keys()
# while(i<=len(spe_list)-1):
# 	j=i
# 	while(j<=len(spe_list)-1):
# 		code_spe_1=dic_spe_coge[spe_list[i]]
# 		code_spe_2=dic_spe_coge[spe_list[j]]
# 		if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
# 			try:
# 				synt_depth_string=matrix[spe_list[i]][spe_list[j]]
# 				if synt_depth_string=="null":
# 					synt_depth_string="1:1"
# 				print synt_depth_string+"\n"
# 				synt_depth_list=synt_depth_string.split(":")
# 				os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
# 				cmd="module load compiler/gcc/4.9.2; module load bioinfo/scip/3.0.2; module load bioinfo/glpk/4.55; qsub -V -q normal.q -N  "+spe_list[i]+"_quota_align -b y   ' /home/lariviere/tool/coge/web/bin/SynMap/quota_align_coverage.pl --config /opt/apache2/coge/web/coge.conf --infile ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords --outfile ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40 --depth_ratio_org1 "+synt_depth_list[0]+" --depth_ratio_org2 "+synt_depth_list[1]+" --depth_overlap 40'"
# 				os.popen(cmd)
# 				os.chdir("/bank/genfam/IDEVEN/")
# 			except:
# 				print "ok"
# 		j=j+1
# 	i=i+1
    
#------------------Running DAGChainer----------------------------

# while(i<=len(spe_list)-1):
# 	j=i
# 	while(j<=len(spe_list)-1):
# 		code_spe_1=dic_spe_coge[spe_list[i]]
# 		code_spe_2=dic_spe_coge[spe_list[j]]
# 		if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
# 			try:
# 				synt_depth_string=matrix[spe_list[i]][spe_list[j]]
# 				if synt_depth_string=="null":
# 					synt_depth_string="1:1" 
# 				print synt_depth_string+"\n"
# 				synt_depth_list=synt_depth_string.split(":")
# 				os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
# 				cmd="qsub -V -q normal.q -N  dag_chainer -b y   'python  /home/lariviere/tool/coge/web/bin/SynMap/gene_order.py ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40 ./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords.qac"+synt_depth_list[0]+"."+synt_depth_list[1]+".40.gcoords --positional '"
# 				print(cmd)
# 				os.popen(cmd)
# 				os.chdir("/bank/genfam/IDEVEN/")
# 			except:
# 				print "ok"
# 		j=j+1
# 	i=i+1

#------------------Calcul Ks----------------------------

# i=0
# j=0
# spe_list=dic_spe_coge.keys()
# while(i<=len(spe_list)-1):
# 	j=i
# 	while(j<=len(spe_list)-1):
# 		code_spe_1=dic_spe_coge[spe_list[i]]
# 		code_spe_2=dic_spe_coge[spe_list[j]]
# 		if spe_list[i]=="VITVI" or spe_list[i]=="POPTR" or spe_list[i]=="COFCA" or spe_list[i]=="THECC" or spe_list[j]=="VITVI" or spe_list[j]=="POPTR" or spe_list[j]=="COFCA" or spe_list[j]=="THECC" :
# 			os.chdir("/bank/genfam/IDEVEN/"+spe_list[i]+"_"+spe_list[j]+"/")
# 			######### pairs_file = open("./"+code_spe_1+"-"+code_spe_2+".CDS-CDS.last.tdd10.cs0.filtered.dag.all.go_D20_g10_A5.aligncoords")
# 			moveksfile= "mv "+code_spe_1+"-"+code_spe_2+".ks "+code_spe_1+"-"+code_spe_2+"_old2.ks"
# 			os.popen(moveksfile)
# 			pairs_file = open("./"+code_spe_1+"-"+code_spe_2+"_CDS.last")
# 			pair_list=[]
# 			spe1_file= open("/bank/genfam/IDEVEN/"+spe_list[i]+"/"+code_spe_1+"-CDS.fasta")
# 			spe1_string=spe1_file.read()
# 			spe1_array=spe1_string.split(">")
# 			spe2_file= open("/bank/genfam/IDEVEN/"+spe_list[j]+"/"+code_spe_2+"-CDS.fasta")
# 			spe2_string=spe2_file.read()
# 			spe2_array=spe2_string.split(">")
# 			cds_file= open("./"+code_spe_1+"-"+code_spe_2+".cds", "w")
# 			for line in pairs_file:
# 				if line[0]!="#":
# 					line_list=line.split("\t")
# 					#########  pair= [line_list[1].split("||")[3], line_list[5].split("||")[3]]
# 					pair= [line_list[0].split("||")[3], line_list[1].split("||")[3]]
# 					print pair
# 					pair_list.append(pair)
# 			print pair_list
# 			for pair in pair_list:
# 				matching1 = [s for s in spe1_array if pair[0] in s]
# 				matching2 = [s for s in spe2_array if pair[1] in s]
# 				print pair[0]
# 				print matching1
# 				print matching2
# 				cds_file.write(">"+matching1[0]+">"+matching2[0])
# 			spe1_file.close()
# 			spe2_file.close()
# 			cds_file.close()
# 			cmd="  module load system/python/2.7.9; module load compiler/gcc/4.9.2; module load bioinfo/clustalw/2.1; module load bioinfo/paml/4.4; module load bioinfo/pal2nal/v14; qsub -V -q normal.q -N  ks_calc -b y   'python /home/lariviere/tool/bio-pipeline/synonymous_calculation/synonymous_calc.py ./"+code_spe_1+"-"+code_spe_2+".cds > "+code_spe_1+"-"+code_spe_2+".ks '"
# 			print(cmd)
# 			os.popen(cmd)    
# 			os.chdir("/bank/genfam/IDEVEN/")
# 		j=j+1
# 	i=i+1