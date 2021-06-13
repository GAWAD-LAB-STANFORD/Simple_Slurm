#!/bin/bash
#
#SBATCH --job-name=lorenz_curve
#SBATCH --mem=15G
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"
KB_BIN_SIZE="1000"

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
        --project )             shift
                                PROJECT=$1
                                ;;
        --err_out_dir )         shift
                                STD_ERR_OUT_DIR=$1
                                ;;
        --pipeline_dir )        shift
                                PIPELINE_DIR=$1
                                ;;
    esac
    shift
done

echo -e "START: $(date)\nProject: ${PROJECT}\nBam dir: ${BAM_DIR}\nBam regex: ${BAM_REGEX}"
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
echo -e "Bam suffix: ${BAM_SUFFIX}\nKb bin size: $KB_BIN_SIZE\nResults dir: ${RESULTS_DIR}"
cd $BAM_DIR

ml R/4.0.2
export R_LIBS="/home/groups/cgawad/R_libs"

SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | \
    grep -v ".temp_n22chr.bam" | sed "s/${BAM_SUFFIX}//") )
echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}"

echo "Binning coverage for BAMs - START: $(date)"
sbatch --wait -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
    --array=1-${#SAMPLE_ARRAY[@]} ${PIPELINE_DIR}/scripts/binned_coverage.sh \
    $REFERENCE_DIR $BAM_DIR $BAM_SUFFIX $BAM_REGEX $KB_BIN_SIZE
echo "Binning coverage for BAMs - END: $(date)"

echo "Consolidating coverages - START: $(date)"
echo -e "sample\tchr\tstart\tend\tcoverage" > ${PROJECT}.${KB_BIN_SIZE}kb_bins_coverage.tsv
BEDGRAPH_FILES=( $(ls *.${KB_BIN_SIZE}kb_bins_coverage.bedgraph) )
for BEDGRAPH in ${BEDGRAPH_FILES[@]}; do
    SAMPLE=$(echo $BEDGRAPH | sed "s/.${KB_BIN_SIZE}kb_bins_coverage.bedgraph//")
    awk -v var=$SAMPLE '{print var"\t"$0 }' $BEDGRAPH >> ${PROJECT}.${KB_BIN_SIZE}kb_bins_coverage.tsv
done
rm ${BEDGRAPH_FILES[@]}
mv ${PROJECT}.${KB_BIN_SIZE}kb_bins_coverage.tsv ${RESULTS_DIR}/${PROJECT}.${KB_BIN_SIZE}kb_bins_coverage.tsv
cd $RESULTS_DIR
echo "Consolidating coverages - END: $(date)"

echo "Consolidating coverages - START: $(date)"
Rscript ${PIPELINE_DIR}/scripts/lorenz_curve.R $PROJECT $KB_BIN_SIZE
echo "Consolidating coverages - END: $(date)"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"