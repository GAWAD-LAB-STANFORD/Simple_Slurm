#!/bin/bash
#
#SBATCH --job-name=variant_class
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --time=3-00:00:00
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
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
        --b37 )             GENOME_VERSION="b37"
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

if [ $GENOME_VERSION = "b37" ]; then
    REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_b37"
    REF_FASTA="${REFERENCE_DIR}/human_g1k_v37.fasta"
fi
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nBam dir: $BAM_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX"
echo -e "Genome version: $GENOME_VERSION\nResults dir: $RESULTS_DIR\nSample: $SAMPLE"

cd $BAM_DIR
ml biology samtools bcftools

echo "### Basic bcftools variant calling - START: $(date) ###"
samtools mpileup -uf $REF_FASTA ${SAMPLE}${BAM_SUFFIX} | bcftools call -mv > ${RESULTS_DIR}/${SAMPLE}.pileup_calls.vcf
echo "samtools mpileup and bcftools variant calling done"
echo -e "count\tref\talt" > ${RESULTS_DIR}/${SAMPLE}.variant_class_counts.tsv
cat ${RESULTS_DIR}/${SAMPLE}.pileup_calls.vcf | cut -f 4,5 | sort | uniq -c | sort -k1n \
	sed 's/^[[:space:]]*//' | sed "s/ /$(printf '\t')/" >> ${RESULTS_DIR}/${SAMPLE}.variant_class_counts.tsv
rm ${RESULTS_DIR}/${SAMPLE}.pileup_calls.vcf
echo "variant class count done"
echo "### Basic bcftools variant calling - END: $(date) ###"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"