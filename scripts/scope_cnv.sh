#!/bin/bash
#
#SBATCH --job-name=scope_cnv
#SBATCH --mem=32G
#SBATCH --time=3-00:00:00
#SBATCH --partition=cgawad
START_TIME=$(date +%s)
echo "START: $(date)"
EXPERIMENTAL_REGEX=".*.bam"
EXPERIMENTAL_SUFFIX=".bam"
GENOME_VERSION="hg38"
KB_BIN_SIZE="500"

while [ "$1" != "" ]; do
    case $1 in
        --script_dir )      shift
                            SCRIPT_DIR=$1
                            ;;
        --b37 )             shift
                            GENOME_VERSION="b37"
                            ;;
        --bam_dir )         shift
                            EXPERIMENTAL_DIR=$1
                            ;;
        --bam_regex )       shift
                            EXPERIMENTAL_REGEX=$1
                            ;;
        --bam_suffix )      shift
                            EXPERIMENTAL_SUFFIX=$1
                            ;;
        --project )         shift
                            PROJECT=$1
                            ;;
        --kb_bin_size )     shift
                            KB_BIN_SIZE=$1
                            ;;
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
    esac
    shift
done

ml R/4.0.2
export R_LIBS="/home/groups/cgawad/R_LIBS"
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$EXPERIMENTAL_DIR
fi
echo -e "START: $(date)\nScript dir: $SCRIPT_DIR\nBam dir: $BAM_DIR\nBam regex: $BAM_REGEX"
echo -e "Bam suffix: $BAM_SUFFIX\nProject: $PROJECT\nKb bin size: $KB_BIN_SIZE\nResults_dir: $RESULTS_DIR"
cd $RESULTS_DIR

if [ $GENOME_VERSION = "b37" ]; then
    HG38_MAPP_GC_DIR="not_made"
    CONTROL_DIR="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/R2D2_First_PTA_Paper/PTA_MDA_LIANTI_Comparison/PTA_Subsampled_BAMs/"
    CONTROL_REGEX="T1200-..25M.marked.bam"
    CONTROL_SUFFIX=".25M.marked.bam"
else
    HG38_MAPP_GC_DIR="/oak/stanford/groups/cgawad/Reference_Files/SCOPE_hg38_mapp_gc_info/"
    CONTROL_DIR="/oak/stanford/groups/cgawad/Reference_Files/T1200_hg38_10M_BAMs/"
    CONTROL_REGEX="T1200-..10M.bqsr.marked.bam"
    CONTROL_SUFFIX=".10M.bqsr.marked.bam"
fi

Rscript ${SCRIPT_DIR}/analyze_cnv.R $PROJECT $KB_BIN_SIZE $HG38_MAPP_GC_DIR $CONTROL_DIR $CONTROL_REGEX $CONTROL_SUFFIX $EXPERIMENTAL_DIR $EXPERIMENTAL_REGEX $EXPERIMENTAL_SUFFIX

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"