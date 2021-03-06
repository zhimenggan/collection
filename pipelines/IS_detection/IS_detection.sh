#!/bin/bash

export working_dir=$PWD
export gff_file=$4
export cores=$6
export reads=$5
export reference=$3
export reference_name=$2
export sample_id=$1
export IS_finder_location=$(dirname $0)


echo
echo "Input:"
echo

echo number_of_cores:$cores
echo sample_id:$sample_id
echo reference_name:$reference_name
echo reference_fasta_file:$reference
echo reference_gff_file:$gff_file
echo read_file:$reads


echo
echo "Checking software ..."
echo

is_command_installed () {
if which $1 &>/dev/null; then
    echo "$1 is installed in:" $(which $1)
else
    echo
    echo "ERROR: $1 not found."
    echo
    exit
fi
}

if ! $(python -c "import networkx" &> /dev/null); then
    echo
    echo "ERROR: The python package networkx can not be loaded. Please install it." 
    echo
else
    echo "The python package networkx is installed." 
fi


is_command_installed blastn
is_command_installed python
is_command_installed blasr
is_command_installed samtools



if [ -r "$gff_file" ]&&[ -r "$reference" ]&&[ -n "$sample_id" ]&&[ -n "$reference_name" ]&&[ "$cores" -eq "$cores" ] &&[ -n "$reads" ]

then

#actual analysis---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

echo
echo ---- initional mapping of all PacBio reads ----
echo

mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments

blasr $reads "$reference" --out "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".bam --bestn 1 --bam --nproc "$cores" --minAlnLength 3000
samtools sort -@ "$cores" -T "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/"$sample_id"_on_"$reference_name"_temp -o "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".sorted.bam "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".bam

samtools index "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".sorted.bam
samtools view -h "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".sorted.bam | python "$IS_finder_location"/script/python/extract_read_information.py > "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".read_info.tab

echo
echo ---- searching reads with insertions and deletions ----
echo

mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/2_parse_cigars/results

python "$IS_finder_location"/script/python/analyse_cigar_read_coordinate.py "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".read_info.tab > "$working_dir"/result/"$sample_id"_on_"$reference_name"/2_parse_cigars/results/"$sample_id"_on_"$reference_name"_long_indels_reads.tab

echo
echo ---- extracting reads with insertions and deletions ----
echo

mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/3_extract_indel_sequencs/result

python "$IS_finder_location"/script/python/prepare_data.py "$working_dir"/result/"$sample_id"_on_"$reference_name"/2_parse_cigars/results/"$sample_id"_on_"$reference_name"_long_indels_reads.tab "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".read_info.tab "$sample_id"_on_"$reference_name" "$working_dir"/result/"$sample_id"_on_"$reference_name"/3_extract_indel_sequencs/result

echo
echo ---- remapping reads with insertions and deletions ----
echo

mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/4_remapping_elements/result

export mapping_path="$working_dir"/result/"$sample_id"_on_"$reference_name"/4_remapping_elements/result

for read_type in reads_with_insertions reads_with_deletions #  insertions

do

blasr "$working_dir"/result/"$sample_id"_on_"$reference_name"/3_extract_indel_sequencs/result/"$sample_id"_on_"$reference_name"_"$read_type".fasta "$reference" --bam --bestn 1 --out "$mapping_path"/"$sample_id"_on_"$reference_name"_"$read_type".bam --nproc $NSLOTS #--minAlnLength 600 --minPctSimilarity 80 
samtools sort -T "$mapping_path"/"$sample_id"_on_"$reference_name" -o "$mapping_path"/"$sample_id"_on_"$reference_name"_"$read_type".sorted.bam "$mapping_path"/"$sample_id"_on_"$reference_name"_"$read_type".bam
samtools index "$mapping_path"/"$sample_id"_on_"$reference_name"_"$read_type".sorted.bam
samtools depth -aa "$mapping_path"/"$sample_id"_on_"$reference_name"_"$read_type".sorted.bam > "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage_"$read_type".tab

done

samtools depth -aa "$working_dir"/result/"$sample_id"_on_"$reference_name"/1_initial_mapping/alignments/"$sample_id"_on_"$reference_name".sorted.bam > "$mapping_path"/"$sample_id"_on_"$reference_name"_raw_coverage.tab

echo "Location	contig	type	Read-depth" > "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage.tab
#was replaced by non redudant for coverage
#python "$IS_finder_location"/script/python/coverage_visualisation.py "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage_insertions.tab insertions >> "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage.tab
python "$IS_finder_location"/script/python/coverage_visualisation.py "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage_reads_with_insertions.tab reads_with_insertions >> "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage.tab
python "$IS_finder_location"/script/python/coverage_visualisation.py "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage_reads_with_deletions.tab reads_with_deletions >> "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage.tab
python "$IS_finder_location"/script/python/coverage_visualisation.py "$mapping_path"/"$sample_id"_on_"$reference_name"_raw_coverage.tab raw_coverage >> "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage.tab

echo
echo ---- preparing circos input data ----
echo

mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference

cp "$reference" "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name".fna

makeblastdb -in "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name".fna -dbtype nucl > "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name".db.info

blastn -db "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name".fna -num_threads "$cores" -query "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name".fna -out "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name"_blast_result.tab -outfmt 6
python "$IS_finder_location"/script/python/mask_sequences.py "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name".fna "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name"_blast_result.tab > "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name"_masked.fasta


mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/mapping

export second_mapping_path="$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/mapping

blasr "$working_dir"/result/"$sample_id"_on_"$reference_name"/3_extract_indel_sequencs/result/"$sample_id"_on_"$reference_name"_insertions.fasta "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/prepare_reference/"$reference_name"_masked.fasta --bam --bestn 1 --out "$second_mapping_path"/"$sample_id"_on_"$reference_name"_insertions.bam --nproc $NSLOTS --minAlnLength 600 --minPctSimilarity 80 
samtools sort -T "$second_mapping_path"/"$sample_id"_on_"$reference_name" -o "$second_mapping_path"/"$sample_id"_on_"$reference_name"_insertions.sorted.bam "$second_mapping_path"/"$sample_id"_on_"$reference_name"_insertions.bam
samtools index "$second_mapping_path"/"$sample_id"_on_"$reference_name"_insertions.sorted.bam
samtools view -h "$second_mapping_path"/"$sample_id"_on_"$reference_name"_insertions.sorted.bam | python "$IS_finder_location"/script/python/extract_read_information.py > "$second_mapping_path"/"$sample_id"_on_"$reference_name"_insertions.read_info.tab

#use non redudant for coverage
read_type=insertions
samtools depth -aa "$second_mapping_path"/"$sample_id"_on_"$reference_name"_insertions.sorted.bam > "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage_"$read_type".tab
python "$IS_finder_location"/script/python/coverage_visualisation.py "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage_"$read_type".tab insertions >> "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage.tab
#

mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/circos_input/circos
python "$IS_finder_location"/script/python/make_arrows.py "$second_mapping_path"/"$sample_id"_on_"$reference_name"_insertions.read_info.tab $gff_file "$working_dir"/result/"$sample_id"_on_"$reference_name"/3_extract_indel_sequencs/result/"$sample_id"_on_"$reference_name"_deletions.fasta "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/circos_input/circos > "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/circos_input/"$sample_id"_on_"$reference_name"_affected_genes.tab

echo
echo ---- arranging final results ----
echo

export mapping_path="$working_dir"/result/"$sample_id"_on_"$reference_name"/4_remapping_elements/result
mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/6_final_results/circos/tab_files

cp "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/circos_input/circos/* "$working_dir"/result/"$sample_id"_on_"$reference_name"/6_final_results/circos/tab_files
cp "$IS_finder_location"/script/visualisation/circos/circos.conf "$working_dir"/result/"$sample_id"_on_"$reference_name"/6_final_results/circos/

mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/6_final_results/coverage

cp "$mapping_path"/"$sample_id"_on_"$reference_name"_coverage.tab "$working_dir"/result/"$sample_id"_on_"$reference_name"/6_final_results/coverage/coverage.tab
cp "$IS_finder_location"/script/visualisation/coverage/hist.r "$working_dir"/result/"$sample_id"_on_"$reference_name"/6_final_results/coverage/

mkdir -p "$working_dir"/result/"$sample_id"_on_"$reference_name"/6_final_results/affected_genes

cp "$working_dir"/result/"$sample_id"_on_"$reference_name"/5_circos_figure/circos_input/"$sample_id"_on_"$reference_name"_affected_genes.tab "$working_dir"/result/"$sample_id"_on_"$reference_name"/6_final_results/affected_genes/

#actual analysis---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

else

echo " "
echo "ERROR: Incorrect input!"
echo "pfastGO version 0.1 by Daniel Wüthrich (danielwue@hotmail.com)"
echo " "
echo "Usage: "
echo "  sh IS_detection.sh <Sample_ID> <Reference_ID> <Reference_fasta> <Reference_gff> '<Pacbio_reads>' <Number_of_cores>"
echo " "
echo "  <Sample_ID>               Unique identifier for the sample"
echo "  <Reference_ID>            Unique identifier for the reference"
echo "  <Reference_fasta>         Fasta file of the reference genome"
echo "  <Reference_gff>           gff annotation file of the reference genome"
echo "  '<Pacbio_reads>'    	    list if Pacbio read files"
echo "  <Number_of_cores>         number of parallel threads to run (int)"
echo " "
if ! [ -r "$gff_file" ];then
echo File not found: "$gff_file"
fi
if ! [ -r "$reference" ];then
echo File not found: "$reference"
fi
if ! [ -n "$sample_id" ];then
echo Incorrect input: "$sample_id"
fi
if ! [ -n "$reference_name" ];then
echo Incorrect input: "$reference_name" 
fi
if ! [ "$cores" -eq "$cores" ] ;then
echo Incorrect input: "$cores"
fi
if ! [ -n "$reads" ];then
echo File not found: "$reads"
fi

fi



