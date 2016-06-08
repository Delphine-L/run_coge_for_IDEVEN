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
pathPrecompute = ConfigSectionMap("RunFiles")['path']

#--------------------------------------------------------------------


fichier = open("coge_id.txt","r")
dic_spe_coge={}
for line in fichier:
     spec=line.split(";")[0].strip()
     code=line.split(";")[1].strip()
     dic_spe_coge[spec]=code
fichier.close()

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
                cmd="  module load system/python/2.7.9; qsub -V -q normal.q -N  "+spe_list[i]+"-"+spe_list[j]+"-ks_calc -b y   'python2.7 "+pathPrecompute+"ks_single.py "+spe_list[i]+" "+spe_list[j]+" '"
                os.popen(cmd)
            j=j+1
	    i=i+1
else:
    while(i<=len(spe_list)-1):
        j=i
        while(j<=len(spe_list)-1):
            cmd="  module load system/python/2.7.9; qsub -V -q normal.q -N  "+spe_list[i]+"-"+spe_list[j]+"-ks_calc -b y   'python2.7 "+pathPrecompute+"ks_single.py "+spe_list[i]+" "+spe_list[j]+" '"
            print(cmd)
            os.popen(cmd)
            j=j+1
        i=i+1
