#!/bin/bash
#
#SBATCH --job-name=variant_class_analysis
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"

GENOME_VERSION="hg38"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"

while [ "$1" != "" ]; do
    case $1 in
        --project )         shift
                            PROJECT=$1
                            ;;
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
        --script_dir )      shift
                            SCRIPT_DIR=$1
                            ;;   
        --bam_dir )         shift
                            BAM_DIR=$1
                            ;;
        --bam_regex )       shift
                            BAM_REGEX=$1
                            ;;
        --bam_suffix )      shift
                            BAM_SUFFIX=$1
                            ;;                
    esac
    shift
done

if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
SAMPLES_STRING=$( IFS=$':'; echo "${SAMPLE_ARRAY[*]}" )
echo -e "START: $(date)\nBam dir: $BAM_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX"
echo -e "Genome version: $GENOME_VERSION\nResults dir: $RESULTS_DIR\nSample: $SAMPLE"

cd $RESULTS_DIR
ml R/4.0.2
export R_LIBS="/home/groups/cgawad/R_LIBS"

echo "### Consolidating variant class counts - START: $(date) ###"
FILENAMES=()
for SAMPLE in ${SAMPLE_ARRAY[@]}; do
	FILENAMES+=( ${SAMPLE}_variant_class_count.txt )
done
echo -e "sample\tchrM_proportion" > ${PROJECT}.merged_variant_class_counts.txt
for i in ${FILENAMES[@]}; do
	>> ${PROJECT}.merged_variant_class_counts.txt
done 
rm ${FILENAMES[@]}
echo "### Consolidating variant class counts - END: $(date) ###"

echo "### Plotting variant class counts - START: $(date) ###"
Rscript ${SCRIPT_DIR}/variant_class_analysis.R ${PROJECT}.merged_variant_class_counts.txt $PROJECT
echo "### Plotting variant class counts - END: $(date) ###"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"