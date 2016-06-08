# Precomputing of syntenic data for IDEVEN using coge custom install

In config.ini, configure the path for the installs and for the repository containing the data.

For each species of interest :
  - Create a folder in the main repository named with the 5 letter specie code (eg: ARATH)
  - If you have the CDS file of the specie, place it in this file with a name like CODE-CDS.fasta (eg : 25869-CDS.fasta)
  - In the coge_id.txt file : for each species, enter the line SPECIE_CODE:CODE (eg: ARATH:25869). If you don't have the CDS file for your genome of interest, you can get one available in CoGe. In that case uncomment the dedicated line in the genome_comp.py file, and in coge_id.txt, chooses the code corresponding to the CoGe ID of your genome of interest.


Run the scipts in that order, wait before the end of all calculations to run the next one.

If you are running the calculation for all species

  python2.7 genom_comp.py
  python2.7 bed_crea.py
  python2.7 filt_tandem.py
  python2.7 dagC_format.py
  python2.7 genomic_order.py
  python2.7 dagChainer.py
  python2.7 quota_align.py
  python2.7 dag_gene_order.py
  python2.7 ks_fast.py


If you just wan to add a species, use the SPECIE_CODE (eg:  ARATH)
  python2.7 genom_comp.py ARATH
  python2.7 bed_crea.py ARATH
  python2.7 filt_tandem.py ARATH
  python2.7 dagC_format.py ARATH
  python2.7 genomic_order.py ARATH
  python2.7  dagChainer.py ARATH
  python2.7 quota_align.py ARATH
  python2.7 dag_gene_order.py ARATH
  python2.7  ks_fast.py ARATH
