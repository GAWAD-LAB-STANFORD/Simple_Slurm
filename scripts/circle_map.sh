#!/bin/bash

START_TIME=$(date +%s)
BAM_DIR=$1
RESULTS_DIR=$2
REF_FASTA=$3
BAM_SUFFIX=$4
SAMPLE_ARRAY=( $(echo $5 | sed 's/:/ /g') )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}

echo -e "START: $(date)\nWGS WES Pipeline\nSlurm ID: $SLURM_ARRAY_TASK_ID\nSample: $SAMPLE\nResults dir: $RESULTS_DIR"
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
samtools sort -o ${SAMPLE}_sorted${BAM_SUFFIX} ${SAMPLE}${BAM_SUFFIX}
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
 
rm ${SAMPLE}_qname${BAM_SUFFIX} ${SAMPLE}_sorted${BAM_SUFFIX}
rm ${SAMPLE}_circular_read_candidates${BAM_SUFFIX} ${SAMPLE}_sorted_circular_read_candidates${BAM_SUFFIX}
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"