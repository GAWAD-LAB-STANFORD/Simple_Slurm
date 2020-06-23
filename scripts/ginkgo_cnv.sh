#!/bin/bash
#
#SBATCH --job-name=ginkgo_cnv
#SBATCH --mem=15GB
#SBATCH --cpus-per-task=1
#SBATCH --time=6:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
GINKGO_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/ginkgo/"
FULL_WORK_DIR="${GINKGO_DIR}/uploads/$(date '+%Y-%m-%d_%H-%M-%S')"
WORK_DIR="$(basename $FULL_WORK_DIR)"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"
KB_BIN_SIZE="500"
GROUP_SEGMENTATION=0

while [ "$1" != "" ]; do
    case $1 in
        --bam_dir )             shift
                                BAM_DIR=$1
                                ;;
        --bam_regex )           shift
                                BAM_REGEX=$1
                                ;;
        --bam_suffix )          shift
                                BAM_SUFFIX=$1
                                ;;
        --kb_bin_size )         shift
                                KB_BIN_SIZE=$1
                                ;;
        --results_dir )         shift
                                RESULTS_DIR=$1
                                ;;
        --group_segmentation )  GROUP_SEGMENTATION=1
                                ;;
    esac
    shift
done

echo -e "START: $(date)\nBam dir: ${BAM_DIR}\nBam regex: ${BAM_REGEX}\nBam suffix: ${BAM_SUFFIX}\nKb bin size: $KB_BIN_SIZE"

ml php R/3.6.1 biology bedtools samtools

SAMPLE_ARRAY=( $(find ${BAM_DIR}/ -maxdepth 1 -regextype sed -regex ".*/${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}"
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
if [ ! -d $FULL_WORK_DIR ]; then
    mkdir $FULL_WORK_DIR
fi
cd $GINKGO_DIR

> ${FULL_WORK_DIR}/list
for SAMPLE in ${SAMPLE_ARRAY[@]}; do
    echo "Preparing $SAMPLE"
    bedtools bamtobed -i ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} > ${FULL_WORK_DIR}/${SAMPLE}.bed
    gzip ${FULL_WORK_DIR}/${SAMPLE}.bed
    echo "${SAMPLE}.bed.gz" >> ${FULL_WORK_DIR}/list
    echo "Done preparing $SAMPLE"
done

cp ${GINKGO_DIR}/config.txt ${FULL_WORK_DIR}/config
sed -i "s/variable_500000_76_bwa/variable_${KB_BIN_SIZE}000_76_bwa/" ${FULL_WORK_DIR}/config
if [ $GROUP_SEGMENTATION -eq 1 ]; then
    sed -i "s/segMeth=0/segMeth=1/" ${FULL_WORK_DIR}/config
fi
bash scripts/analyze.sh $WORK_DIR

for SAMPLE in ${SAMPLE_ARRAY[@]}; do
    rm ${FULL_WORK_DIR}/${SAMPLE}.bed.gz
done

mv ${FULL_WORK_DIR}/* ${RESULTS_DIR}/

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"