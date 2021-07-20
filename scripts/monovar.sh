#!/bin/bash
#
#SBATCH --job-name=monovar
#SBATCH --mem=64G
#SBATCH --time=6-00:00:00
#SBATCH --partition=cgawad
START_TIME=$(date +%s)

while [ "$1" != "" ]; do
    case $1 in
        --bam_dir )         shift
                            BAM_DIR=$1
                            ;;
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
        --bam_suffix )      shift
                            BAM_SUFFIX=$1
                            ;;
        --project )         shift
                            PROJECT=$1
                            ;;
    esac
    shift
done

TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
ANNOVAR_DIR="/oak/stanford/groups/cgawad/Reference_Files/ANNOVAR"

echo -e "START: $(date)\nResults dir: $RESULTS_DIR\nProject: $PROJECT\nFilelist: ${PROJECT}.monovar_bam_full_filenames.txt"
cd $RESULTS_DIR

ml perl biology samtools bcftools
ml python/2.7.13 biology py-pysam/0.14.1_py27 py-scipy/1.1.0_py27

ls -d ${BAM_DIR}/*${BAM_SUFFIX} > ${PROJECT}.monovar_bam_full_filenames.txt

samtools mpileup -BQ0 -d10000 -f $REF_FASTA -q 40 -b ${PROJECT}.monovar_bam_full_filenames.txt | \
    ${TOOLS_DIR}/MonoVar/src/monovar.py -p 0.002 -a 0.2 -t 0.05 -m 4 -f $REF_FASTA \
    -b ${PROJECT}.monovar_bam_full_filenames.txt -o ${PROJECT}.monovar_variant_calls.ill_formatted.vcf

NUM_ROWS_TO_KEEP=$(cat ${PROJECT}.monovar_bam_full_filenames.txt | wc -l | awk '{print $1 + 9}')
cut -f 1-${NUM_ROWS_TO_KEEP} ${PROJECT}.monovar_variant_calls.ill_formatted.vcf > ${PROJECT}.monovar_variant_calls.vcf
bgzip ${PROJECT}.monovar_variant_calls.vcf
tabix ${PROJECT}.monovar_variant_calls.vcf.gz

perl ${ANNOVAR_DIR}/table_annovar.pl ${PROJECT}.monovar_variant_calls.vcf.gz -vcfinput -operation g,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver hg38 -out ${PROJECT}.monovar_variant_calls -nastring . -remove \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad30_genome

rm ${PROJECT}.monovar_variant_calls.ill_formatted.vcf
if [ ! -f ${PROJECT}.monovar_variant_calls.vcf.gz ]; then
    echo "Final file ${PROJECT}.monovar_variant_calls.vcf.gz not found. Exiting with code 1"
    exit 1
fi
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"