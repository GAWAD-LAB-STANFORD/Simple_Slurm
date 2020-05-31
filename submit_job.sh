#!/bin/bash

PIPELINE_DIR="$( cd "$( dirname "$0" )" && pwd )"
HELP="\
Purpose: \n\t\
    This directory allows you to submit simple slurm jobs easily \n\n\
SCOPE CNV analysis: \n\t\
    Required: -b/--bam_dir <arg>, -p/--project <arg> \n\t\
    Optional: --results_dir <arg> (default bam_dir), --kb_bin_size <arg> (default 500), --bam_regex <arg> (default .*.bam), --bam_suffix <arg> (default .bam), --b37 (default hg38) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --scope_cnv --bam_dir /path/to/BAMs/ --project PTA_CNV \n\n\
Conserting SC CNV analysis: \n\t\
    Required: -b/--bam_dir <arg> \n\t\
    Optional: --results_dir <arg> (default bam_dir), --kb_bin_size <arg> (default 500), --bam_regex <arg> (default .*.bam), --bam_suffix <arg> (default .bam) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --conserting_sc_cnv --bam_dir /path/to/BAMs/ \n\n\
Ginkgo CNV analysis: \n\t\
    Required: -b/--bam_dir <arg> \n\t\
    Optional: --results_dir <arg> (default bam_dir), --kb_bin_size <arg> (default 500), --bam_regex <arg> (default .*.bam), --bam_suffix <arg> (default .bam) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --ginkgo_cnv --bam_dir /path/to/BAMs/ \n\n\
Demultiplexer: \n\t\
    Required: -r/--run_dir <arg> and -f/--fastq_dir <arg> \n\t\
    Optional: --sample_sheet <arg> (default SampleSheet.csv), -p/--project <arg> \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --demultiplex --fastq_dir /path/to/fastq/ --run_dir /path/to/runfolder/ \n\n\
For more information, read the README.md"

# Reads in command line option arguments and assigns them to variables
GENOME_VERSION="hg38"
PROGRAM="none"
while [ "$1" != "" ]; do
    case $1 in
        -h | --help )           echo -e $HELP
                                exit 0
                                ;;
        --scope_cnv )           PROGRAM="scope_cnv"
                                ;;
        --conserting_sc_cnv )   PROGRAM="conserting_sc_cnv"
                                ;;
        --ginkgo_cnv )          PROGRAM="ginkgo_cnv"
                                ;;
        --demultiplex )         PROGRAM="demultiplex"
                                ;;
        --kb_bin_size )         shift
                                KB_BIN_SIZE=$1
                                ;;
        --b37 )                 GENOME_VERSION="b37"
                                ;;
        -r | --run_dir )        shift
                                RUN_DIR=$1
                                ;;
        --sample_sheet )        shift
                                SAMPLE_SHEET=$1
                                ;;
        --err_out_dir )         shift
                                STD_ERR_OUT_DIR=$1
                                ;;
        -f | --fastq_dir )      shift
                                FASTQ_DIR=$1
                                ;;
        -b | --bam_dir )        shift
                                BAM_DIR=$1
                                ;;
        --results_dir )         shift
                                RESULTS_DIR=$1
                                ;;
        -p | --project )        shift
                                PROJECT=$1
                                ;;
        --bam_regex )           shift
                                BAM_REGEX=$1
                                ;;
        --bam_suffix )          shift
                                BAM_SUFFIX=$1
                                ;;
        --slurm )               shift
                                SLURM_OPTIONS=${@:1}
                                ;;
    esac
    shift
done

OPTIONS=()
if [ $PROGRAM = "scope_cnv" ]; then
    if [ -z $PROJECT ] || [ -z $BAM_DIR ] || [ ! -d $BAM_DIR ] || [ -z $PIPELINE_DIR ]; then
        echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $RESULTS_DIR ]; then
        OPTIONS+=( "--results_dir $RESULTS_DIR" )
        if [ ! -d $RESULTS_DIR ]; then
            mkdir $RESULTS_DIR
        fi
    else
        RESULTS_DIR=$BAM_DIR
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    if [ ! -z $BAM_REGEX ]; then
        OPTIONS+=( "--bam_regex $BAM_REGEX" )
    fi
    if [ ! -z $BAM_SUFFIX ]; then
        OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
    fi
    if [ ! -z $KB_BIN_SIZE ]; then
        OPTIONS+=( "--kb_bin_size $KB_BIN_SIZE" )
    fi
    if [ $GENOME_VERSION = "b37" ]; then
        OPTIONS+=( "--b37" )
    fi
    sbatch ${SLURM_OPTIONS[@]} -J $PROJECT -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${PIPELINE_DIR}/scripts/scope_cnv.sh \
        --script_dir ${PIPELINE_DIR}/scripts --bam_dir $BAM_DIR --project $PROJECT ${OPTIONS[@]}
elif [ $PROGRAM = "conserting_sc_cnv" ] || [ $PROGRAM = "ginkgo_cnv" ]; then
    if [ -z $BAM_DIR ] || [ ! -d $BAM_DIR ] || [ -z $PIPELINE_DIR ]; then
        echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $RESULTS_DIR ]; then
        OPTIONS+=( "--results_dir $RESULTS_DIR" )
        if [ ! -d $RESULTS_DIR ]; then
            mkdir $RESULTS_DIR
        fi
    else
        RESULTS_DIR=$BAM_DIR
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    if [ ! -z $BAM_REGEX ]; then
        OPTIONS+=( "--bam_regex $BAM_REGEX" )
    else
        BAM_REGEX=".*.bam"
    fi
    if [ ! -z $BAM_SUFFIX ]; then
        OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
    fi
    if [ ! -z $KB_BIN_SIZE ]; then
        OPTIONS+=( "--kb_bin_size $KB_BIN_SIZE" )
    fi
    NUM_SAMPLES=$(find ${BAM_DIR}/ -maxdepth 1 -regextype sed -regex ".*/${BAM_REGEX}" | wc -l)
    if [ $NUM_SAMPLES -eq 0 ]; then
        echo "No BAM files found in the bam directory. Exiting with code 1"
        exit 1
    fi
    if [ $PROGRAM = "conserting_sc_cnv" ]; then
        REFERENCE_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/Conserting_SC"
        if [ ! -f "${REFERENCE_DIR}/n25chr_${KB_BIN_SIZE}kb_meta" ]; then
            echo "The reference files for that kb bin size have not been created. Exiting with code 1"
            exit 1
        fi
        sbatch ${SLURM_OPTIONS[@]} -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            --array=1-$NUM_SAMPLES ${PIPELINE_DIR}/scripts/conserting_sc_cnv.sh --bam_dir $BAM_DIR ${OPTIONS[@]}
    else
        REFERENCE_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/ginkgo/genomes/hg38"
        if [ ! -f "${REFERENCE_DIR}/variable_${KB_BIN_SIZE}000_76_bwa" ]; then
            echo "The reference files for that kb bin size have not been created. Exiting with code 1"
            exit 1
        fi
        sbatch ${SLURM_OPTIONS[@]} -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
            ${PIPELINE_DIR}/scripts/ginkgo_cnv.sh --bam_dir $BAM_DIR ${OPTIONS[@]}
    fi
elif [ $PROGRAM = "demultiplex" ]; then
    if [ -z $SAMPLE_SHEET ]; then
        SAMPLE_SHEET="${RUN_DIR}/SampleSheet.csv"
    fi
    if [ -z $RUN_DIR ] || [ ! -d $RUN_DIR ] || [ -z $FASTQ_DIR ] || [ ! -f $SAMPLE_SHEET ] || [ -z $PIPELINE_DIR ]; then
        echo "Variables not supplied correctly, run_dir doesn't exist, or sample sheet doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -d $FASTQ_DIR ]; then
        mkdir $FASTQ_DIR
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${FASTQ_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    sbatch ${SLURM_OPTIONS[@]} -J $PROJECT -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${PIPELINE_DIR}/scripts/demultiplexer.sh \
        --run_dir $RUN_DIR --sample_sheet $SAMPLE_SHEET --fastq_dir $FASTQ_DIR \
        --project $PROJECT --script_dir ${PIPELINE_DIR}/scripts
else
    echo "No program specified. Exiting with code 0"
    exit 0
fi