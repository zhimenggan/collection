import operator
import csv
import sys
import math
from Bio.Blast import NCBIXML
import datetime
import ast

inputOptions = sys.argv[1:]

# usage: out_xml sequence.fasta  

def main():


	sequences={}
	sequences2hsp={}
	#input_file = [n for n in open(inputOptions[1],'r').read().replace("\r","").split("\n") if len(n)>0]


	with open(inputOptions[1],'r') as f:
    		for line_raw in f:
			line=line_raw.replace("\r","").replace("\n","")

			if line[0:1]==">":
				name = line[1:]
				sequences2hsp[name]=list()
				sequences[name]=""
			else:
				sequences[name]+=line



	genus_path={}
	with open(inputOptions[0],'r') as f:
    		for line_raw in f:
			line=line_raw.replace("\r","").replace("\n","")
	
			hsp=Hsp()
			hsp.align_identdity=float(line.split("\t")[6])
			hsp.identities=int(line.split("\t")[7])
			hsp.query=line.split("\t")[0]	
			hsp.hit_def=" ".join(line.split("\t")[2].split(" ")[1:])
		
			hsp.align_length=int(line.split("\t")[5])	

			species_info=hsp.hit_def#.split(";")[len(hsp.hit_def.split(";"))-1]
			hsp.genus_path=species_info.rsplit(';',1)[0]+"|"+species_info.rsplit(';',1)[1].replace(" ",";")
			#hsp.species=species_info.rsplit(';',1)[1]

			
			if len(species_info.rsplit(';',1)[1].split(" "))>=2:
				hsp.species=species_info.rsplit(';',1)[1].split(" ")[0]+" "+species_info.rsplit(';',1)[1].split(" ")[1]
			

			genus_path[hsp.species]=hsp.genus_path
			
			if (hsp.align_identdity >=95) and (float(hsp.align_length)/float(len(sequences[hsp.query])) >= 0.5):
				sequences2hsp[hsp.query].append(hsp)


	f = open(inputOptions[2]+'_reads.tab', 'w')

	species_count={"['no-overlapping-species-of-hits']":0,"['below-cutoff']":0}
	genus_path["no-overlapping-species-of-hits"]="none"
	genus_path["below-cutoff"]="none"
	for sequence in sequences2hsp.keys():
		if sequence[len(sequence)-2:len(sequence)]=="/1":
		
			pair_name=sequence[0:len(sequence)-2]
			species2maxidentity_1=best_per_species(sequences2hsp[pair_name+"/1"])

			species2maxidentity_2=best_per_species(sequences2hsp[pair_name+"/2"])
			species2maxidentity_both_reads={}


			for species in species2maxidentity_1.keys():
				if species in species2maxidentity_2.keys():				
					species2maxidentity_both_reads[species]=species2maxidentity_1[species]+species2maxidentity_2[species]
			if len(species2maxidentity_1.keys())==0:
				for species in species2maxidentity_2.keys():
					species2maxidentity_both_reads[species]=species2maxidentity_2[species]
			elif len(species2maxidentity_2.keys())==0:
				for species in species2maxidentity_1.keys():
					species2maxidentity_both_reads[species]=species2maxidentity_1[species]
	
									
			if len(species2maxidentity_both_reads)>0:
				max_idendity= sorted(species2maxidentity_both_reads.items(), key=operator.itemgetter(1),reverse=True)[0][1]
				
				best_species = {}
				for species in species2maxidentity_both_reads.keys():
					if species2maxidentity_both_reads[species]==max_idendity:
						best_species[species]=species2maxidentity_both_reads[species]

				species=get_fusion_name(best_species)
		
				if (species in species_count.keys())==bool(0):
					species_count[species]=0
				species_count[species]+=1
				f.write(species+"\t"+sequences[pair_name+"/1"]+"\t"+sequences[pair_name+"/2"]+"\n")

			elif(len(species2maxidentity_1.keys())==0 and len(species2maxidentity_2.keys())==0):
				species_count["['below-cutoff']"]+=1
				f.write("['below-cutoff']"+"\t"+sequences[pair_name+"/1"]+"\t"+sequences[pair_name+"/2"]+"\n")

			else:
				#one could add a method to find the longest common path

				species_count["['no-overlapping-species-of-hits']"]+=1
				f.write("['no-overlapping-species-of-hits']"+"\t"+sequences[pair_name+"/1"]+"\t"+sequences[pair_name+"/2"]+"\t"+str(species2maxidentity_1.keys())+"\t"+str(species2maxidentity_2.keys())+"\n")			
				
			


	found_species=""
	for species in sorted(species_count.items(), key=operator.itemgetter(1), reverse=True):
	
		if len(species[0].split(","))==1 and len(species[0].split("-"))==1:
			found_species+=str(species[0])+"; "
	

		all_genus_path=[]
		
		for species_string in ast.literal_eval(species[0]):#species[0].replace("]","").replace("[","").split(","):
			all_genus_path.append(genus_path[species_string].split(";"))

		genus_path_string=""

		add_clade=bool(1)
		for clade in all_genus_path[0]:
			
			for path in all_genus_path:
				if (clade in path) == bool(0):
					add_clade=bool(0)
			if add_clade==bool(1):
				genus_path_string+=clade+";"
				
		if 	genus_path_string.find("|")!=-1:
			genus_path_string=genus_path_string.split("|")[0]+";"+genus_path_string.split("|")[1].replace(";"," ")
		print species[0]+"\t"+genus_path_string+"\t"+str(species[1])

	#print found_species
def get_fusion_name(best_species):

	short_names=[]
	for species in best_species.keys():
		short_names.append(species)		
		#short_names.append(species.split("|")[1])
		
	return str(sorted(short_names))


def best_per_species(hsps):

	species2maxidentity={}

	#max_idendities=0
	#for hsp in hsps:
	#	if hsp.identities > max_idendities:
	#		max_idendities=hsp.identities

	for hsp in hsps:
	#	if hsp.identities >= max_idendities:
		#species = hsp.genus_path+"|"+hsp.species#+hsp.subspecies
		species = hsp.species
		if (species in species2maxidentity.keys())==bool(0):
			species2maxidentity[species]=0
		if hsp.identities > species2maxidentity[species]:
			species2maxidentity[species]=hsp.identities

	return species2maxidentity


class Hsp:
	def __init__(self):
		self.species=""
		self.genus_path=""
		#self.subspecies=""
		self.identities=0
		self.align_identdity=0
		self.align_length=0
		self.query=""
		self.hit_def=""
	

	
main()		
