# !/usr/bin/env python
# -*- coding: utf8 -*-

from multiprocessing import Process, Manager
import os, sys, random, datetime,re, json
print "beginning"

fasta_path = sys.argv[1]
output_path=sys.argv[2]

pat_ARATH=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|AT[0-9]*G[0-9]*[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_bradi_transc=r'(Bd[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Bradi[0-9]+[g][0-9]+[.][0-9]+\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_bradi=r'(Bd[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Bradi[0-9]+[g][0-9]+\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_glyma=r'(Gm[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Glyma[0-9]+[g][0-9]+\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_glyma_transc=r'(Gm[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Glyma[0-9]+[g][0-9]+[.][0-9]+\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_maize=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|GRMZM[0-9]+[G][0-9]+\_T[0-9]+.v6a\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_manes=r'([a-z]*[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|cassava[0-9]*[.]*[0-9]*_[0-9]+[a-z]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_medtr=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Medtr[0-9]*g[0-9]+\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_medtr_transcr=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Medtr[0-9]*g[0-9]+[.]+[0-9]+\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_musa=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|GSMUA_Achr[0-9]*G[0-9]+_[0-9]+\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_orysj=r'([A-z]+[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|LOC_Os[0-9]*g[0-9]+[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_ricco=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|[0-9]*.m[0-9]+[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_sollc=r'(SL[0-9]+.[0-9]+ch[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Solyc[0-9]*g[0-9]+[.]*[0-9]*[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_soltu=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|PGSC[0-9]*DMG[0-9]+[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_sorbi=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Sb[0-9]*g[0-9]+[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'

pat_cucsa=r'([A-z]+[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|Cucsa[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_citsi=r'([A-z]+[0-9]+\|\|[0-9]+\|\|[0-9]+\|\|orange[0-9]*[.]*[0-9]*g[0-9]+[.]*[0-9]*m\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_horvu=r'([A-z]*[0-9]*\|\|[0-9]+\|\|[0-9]+\|\|CDS:MLOC_[0-9]+[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_CAJCA=r'([A-z]*[0-9]*\|\|[0-9]+\|\|[0-9]+\|\|YP_[0-9]+[.]*[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_MUSBA=r'([A-z]*[0-9]*\|\|[0-9]+\|\|[0-9]+\|\|ITC[0-9]+_Bchr[0-9]+_T[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_POPTR=r'(Potri.[0-9]*[GT][0-9]{6}\.[0-9]+\.v3\.0)'


pat_MALDO=r'MDC[0-9]+[.]*[0-9]*\|\|[0-9]+\|\|[0-9]+\|\|(PAC:[0-9]*)\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+'
pat_PHODC=r'([A-z]*[_]*[0-9]*\|\|[0-9]+\|\|[0-9]+\|\|PDK_[0-9]+s[0-9]+L[0-9]*\|\|[-]*[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'


pat_VITVI=r'([0-9]+\|\|[0-9]+\|\|[0-9]+\|\|LOC[0-9]{9}\|\|[-]?[0-9]+\|\|[A-z]+\|\|[0-9]+\|\|[0-9]+)'
pat_vitvibis=r'(GSVIV[TG][0-9]{11})'
pat_THECC=r'(Tc[0-9]{2}\_g[0-9]{6})'
pat_COFCA=r'(GSCOCT[0-9]+)'

cofca_file=open("/bank/genfam/genome_data_v2/COFCA/COFCA-GENOSCOPE1-locus_tag.json",'r')
cofca_dic=json.loads(cofca_file.read())
cofca_file.close()

fasta_file=open(fasta_path,'r')
fasta=fasta_file.read()

if re.search(pat_MALDO, fasta, flags=0):
	maldo_file=open("/bank/genfam/genome_data_v3/MALDO/MALDO-JGI1-locus_tag-genfam.json",'r')
	maldo_dic=json.loads(maldo_file.read())
	maldo_file.close()

fasta_file.close()
print "regex registered"

fasta_file=open(fasta_path,'r')
output_file=open(output_path,'w') 


fasta=fasta_file.readlines()


for line in fasta:
	print line[0]
	if line[0]==">":
		print re.search(pat_VITVI, line, flags=0)
		if re.search(pat_VITVI, line, flags=0):
			arathres=re.search(pat_VITVI, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_VITVI"
			line = line.replace(name,newname)
		elif re.search(pat_vitvibis, line, flags=0):
			vitvihres=re.search(pat_vitvibis, line, flags=0)
			name= vitvihres.group(0)
			newname=name+"_VITVI"
			line = line.replace(name,newname)
		elif re.search(pat_PHODC, line, flags=0):
			arathres=re.search(pat_PHODC, line, flags=0)
			old1= arathres.group(0) 
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_PHODC"
			line = line.replace(name,newname)
		elif re.search(pat_THECC, line, flags=0):
			arathres=re.search(pat_THECC, line, flags=0)
			name= arathres.group(0)[:-1]
			newname=name+"_THECC"
			print name
			print newname
			line = line.replace(name,newname)
		elif re.search(pat_MALDO, line, flags=0):
			arathres=re.search(pat_MALDO, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			print name
			newname=maldo_dic[name]["gene_name"]
			newname=newname+"_MALDO"
			line = line.replace(name,newname)
		elif re.search(pat_cucsa, line, flags=0):
			arathres=re.search(pat_cucsa, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_CUCSA"
			line = line.replace(name,newname)
		elif re.search(pat_POPTR, line, flags=0):
			arathres=re.search(pat_POPTR, line, flags=0)
			name= arathres.group(0)
			newname=name.replace(".v3.0","")
			newname=newname+"_POPTR"
			line = line.replace(name,newname)
		elif re.search(pat_COFCA, line, flags=0): 
			cofcares=re.search(pat_COFCA, line, flags=0)
			name = cofcares.group(0)
			newname=cofca_dic[name]["gene_name"]+"_COFCA"
			line = line.replace(name,newname)
		elif re.search(pat_MUSBA, line, flags=0):
			arathres=re.search(pat_MUSBA, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_MUSBA"
			line = line.replace(name,newname)
		elif re.search(pat_CAJCA, line, flags=0):
			arathres=re.search(pat_CAJCA, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_CAJCA"
			line = line.replace(name,newname)
		elif re.search(pat_horvu, line, flags=0):
			arathres=re.search(pat_horvu, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name[4:]+"_HORVU"
			line = line.replace(name,newname)
		elif re.search(pat_citsi, line, flags=0):
			arathres=re.search(pat_citsi, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_CITSI"
			line = line.replace(name,newname)
		elif re.search(pat_sorbi, line, flags=0):
			arathres=re.search(pat_sorbi, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_SORBI"
			line = line.replace(name,newname)
		elif re.search(pat_soltu, line, flags=0):
			arathres=re.search(pat_soltu, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_SOLTU"
			line = line.replace(name,newname)
		elif re.search(pat_sollc, line, flags=0):
			arathres=re.search(pat_sollc, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_SOLLC"
			line = line.replace(name,newname)
		elif re.search(pat_ricco, line, flags=0):
			arathres=re.search(pat_ricco, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_RICCO"
			line = line.replace(name,newname)
		elif re.search(pat_orysj, line, flags=0):
			arathres=re.search(pat_orysj, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			name=name.replace("LOC_","")
			newname=name+"_ORYSJ"
			line = line.replace(name,newname)
		elif re.search(pat_ARATH, line, flags=0):
			arathres=re.search(pat_ARATH, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_ARATH"
			line = line.replace(name,newname)
		elif re.search(pat_musa, line, flags=0):
			arathres=re.search(pat_musa, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_MUSAC"
			line = line.replace(name,newname)
		elif re.search(pat_medtr, line, flags=0):
			arathres=re.search(pat_medtr, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+".1_MEDTR"
			line = line.replace(name,newname)
		elif re.search(pat_medtr_transcr, line, flags=0):
			arathres=re.search(pat_medtr_transcr, line, flags=0)
			old1= arathres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_MEDTR"
			line = line.replace(name,newname)
		elif re.search(pat_manes, line, flags=0):
			manesres=re.search(pat_manes, line, flags=0)
			old1= manesres.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_MANES"
			line = line.replace(name,newname)
		elif re.search(pat_maize, line, flags=0):
			bradires=re.search(pat_maize, line, flags=0)
			old1= bradires.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name.replace(".v6a","_MAIZE")
			line = line.replace(name,newname)
		elif re.search(pat_glyma, line, flags=0):
			bradires=re.search(pat_glyma, line, flags=0)
			old1= bradires.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+".1_GLYMA"
			line = line.replace(name,newname)
		elif re.search(pat_glyma_transc, line, flags=0):
			bradires=re.search(pat_glyma_transc, line, flags=0)
			old1= bradires.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_GLYMA"
			line = line.replace(name,newname)
		elif re.search(pat_bradi_transc, line, flags=0):
			bradires=re.search(pat_bradi_transc, line, flags=0)
			old1= bradires.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+"_BRADI"
			line = line.replace(name,newname)
		elif re.search(pat_bradi, line, flags=0):
			bradires=re.search(pat_bradi, line, flags=0)
			old1= bradires.group(0)
			splitold=re.split("\|\|",old1)
			name=splitold[3]
			newname=name+".1_BRADI"
			line = line.replace(name,newname)
		output_file.write(line)
	else : 
		output_file.write(line)
    
fasta_file.close()
output_file.close()

