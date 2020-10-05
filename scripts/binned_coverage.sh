#!/bin/bash
#
#SBATCH --job-name=binned_coverage
#SBATCH --mem=15GB
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
REFERENCE_DIR=$1
BAM_DIR=$2
BAM_SUFFIX=$3
BAM_REGEX=$4
KB_BIN_SIZE=$5

export PYTHONPATH=/home/groups/cgawad/python_libs/lib/python3.6/site-packages:$PYTHONPATH
cd $BAM_DIR

ml biology samtools python/3.6.1

SAMPLE_ARRAY=( $(find ${BAM_DIR}/ -maxdepth 1 -regextype sed -regex ".*/${BAM_REGEX}" -exec basename {} \; | \
    grep -v ".temp_n22chr.bam" | sed "s/${BAM_SUFFIX}//") )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nSample: $SAMPLE"

if [ ! -f ${SAMPLE}${BAM_SUFFIX}.bai ]; then
    echo "Index bam - START: $(date)"
    samtools index ${SAMPLE}${BAM_SUFFIX}
    echo "Index bam - END: $(date)"
fi

echo "Bam to n22chr - START: $(date)"
samtools view -b -L ${REFERENCE_DIR}/Homo_sapiens_assembly38_n22chr.bed ${SAMPLE}${BAM_SUFFIX} > ${SAMPLE}.temp_n22chr.bam
echo "Bam to n22chr - END: $(date)"

echo "Index n22chr bam - START: $(date)"
samtools index ${SAMPLE}.temp_n22chr.bam
echo "Index n22chr bam - END: $(date)"

echo "Bam to bedgraph - START: $(date)"
/home/groups/cgawad/python_libs/bin/bamCoverage --bam ${SAMPLE}.temp_n22chr.bam \
    --outFileName ${SAMPLE}.temp_${KB_BIN_SIZE}kb_bins_coverage.bedgraph \
    --binSize ${KB_BIN_SIZE}000 --outFileFormat bedgraph
grep -P "^chr..?\t" ${SAMPLE}.temp_${KB_BIN_SIZE}kb_bins_coverage.bedgraph | \
    grep -Ev "chrX|chrY|chrM"> ${SAMPLE}.${KB_BIN_SIZE}kb_bins_coverage.bedgraph
echo "Bam to bedgraph - END: $(date)"

rm ${SAMPLE}.temp_n22chr.bam
rm ${SAMPLE}.temp_n22chr.bam.bai
rm ${SAMPLE}.temp_${KB_BIN_SIZE}kb_bins_coverage.bedgraph
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"