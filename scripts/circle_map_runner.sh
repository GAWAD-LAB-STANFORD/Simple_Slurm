#!/bin/bash
#
#SBATCH --job-name=circle_map
#SBATCH --mem=64G
#SBATCH --time=3-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
BAM_SUFFIX=".bam"
REF_FASTA="/oak/stanford/groups/cgawad/Reference_Files/Homo_sapiens_assembly38.fasta"

while [ "$1" != "" ]; do
    case $1 in
        --script_dir )          shift
                                SCRIPT_DIR=$1
                                ;;
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

if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi

srun --time=3-00:00:00 --mem=64G --partition=cgawad --pty bash ${SCRIPT_DIR}/circle_map.sh $BAM_DIR $RESULTS_DIR $REF_FASTA $BAM_SUFFIX $SAMPLES_STRING