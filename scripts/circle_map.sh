#!/bin/bash
#
#SBATCH --job-name=circle_map
#SBATCH --mem=64G
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
BAM_SUFFIX=".bam"
REF_FASTA="/oak/stanford/groups/cgawad/Reference_Files/Homo_sapiens_assembly38.fasta"

while [ "$1" != "" ]; do
    case $1 in
        --bam_dir )             shift
                                BAM_DIR=$1
                                ;;
        --samples_string )      shift
                                SAMPLES_STRING=$1
                                ;;
        --results_dir )         shift
                                RESULTS_DIR=$1
                                ;;
        --bam_suffix )          shift
                                BAM_SUFFIX=$1
                                ;;
        --ref_fasta )           shift
                                REF_FASTA=$1
                                ;;
    esac
    shift
done

SAMPLE_ARRAY=( $(echo $SAMPLES_STRING | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi

echo -e "START: $(date)\nSlurm ID: $SLURM_ARRAY_TASK_ID\nSample: $SAMPLE\nBam dir: $BAM_DIR\nResults dir: $RESULTS_DIR"
cd $RESULTS_DIR

ml biology samtools bwa bedtools
ml python/3.6.1
export PYTHONPATH=/home/groups/cgawad/python_libs/lib/python3.6/site-packages:$PYTHONPATH
export PATH=/home/groups/cgawad/python_libs/bin:$PATH
ml py-numpy/1.19.2_py36 py-biopython/1.70_py27 py-pandas/1.0.3_py36
ml python/3.6.1

echo "### Sort BAM by read name ### - START: $(date)"
samtools sort -n -o ${SAMPLE}_qname${BAM_SUFFIX} ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX}
echo "### Sort BAM by read name ### - END: $(date)"

echo "### Sort BAM by leftmost mapping coordinates ### - START: $(date)"
samtools sort -o ${SAMPLE}_sorted${BAM_SUFFIX} ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX}
samtools index ${SAMPLE}_sorted${BAM_SUFFIX}
echo "### Sort BAM by leftmost mapping coordinates ### - END: $(date)"

echo "### Extract circular DNA rearrangements ### - START: $(date)"
Circle-Map ReadExtractor -i ${SAMPLE}_qname${BAM_SUFFIX} -o ${SAMPLE}_circular_read_candidates${BAM_SUFFIX}
echo "### Extract circular DNA rearrangements ### - END: $(date)"

echo "### Sort read candidates by coordinates ### - START: $(date)"
samtools sort -o ${SAMPLE}_sorted_circular_read_candidates${BAM_SUFFIX} ${SAMPLE}_circular_read_candidates${BAM_SUFFIX}
samtools index ${SAMPLE}_sorted_circular_read_candidates${BAM_SUFFIX}
echo "### Sort read candidates by coordinates ### - END: $(date)"

echo "### Detect circular DNA ### - START: $(date)"
Circle-Map Realign -i ${SAMPLE}_sorted_circular_read_candidates${BAM_SUFFIX} \
    -qbam ${SAMPLE}_qname${BAM_SUFFIX} -sbam ${SAMPLE}_sorted${BAM_SUFFIX} \
    -fasta $REF_FASTA -o ${SAMPLE}_unknown_circle.bed
echo "### Detect circular DNA ### - END: $(date)"
 
rm ${SAMPLE}_circular_read_candidates${BAM_SUFFIX}
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"