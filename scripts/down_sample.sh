#!/bin/bash
#
#SBATCH --job-name=down_sample
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"

while [ "$1" != "" ]; do
    case $1 in
        --results_dir )     shift
                            RESULTS_DIR=$1
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
        --mb_size )         shift
                            MB_SIZE=$1
                            ;;        
    esac
    shift
done

cd $RESULTS_DIR
ml java/11.0.11 gsl biology samtools gatk

SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nBam dir: $BAM_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX"
echo -e "Results dir: $RESULTS_DIR\nSample: $SAMPLE"

BAM_5M_SUFFIX=$(echo $BAM_SUFFIX | sed "s/.bam/.${MB_SIZE}M.bam/")
TOTAL_READS=$(samtools view -c ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX})
FULL_SIZE=${MB_SIZE}000000
FRACTION=$(awk -v x="$FULL_SIZE" y="$TOTAL_READS" 'BEGIN {printf "%3f", x / y}')
if [ $TOTAL_READS -ge ${MB_SIZE}000000 ] && [ ! -z $FRACTION ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=1 -Xmx16g" DownsampleSam \
        -I ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}${BAM_5M_SUFFIX} \
        --PROBABILITY $FRACTION --VALIDATION_STRINGENCY SILENT
    echo "${MB_SIZE}M downsample done"
    samtools index ${SAMPLE}${BAM_5M_SUFFIX}
else
    echo "Bam is less than ${MB_SIZE} million reads, cannot downsample"
fi
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"