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
    Optional: --results_dir <arg> (default bam_dir), --kb_bin_size <arg> (default 500), --bam_regex <arg> (default .*.bam), --bam_suffix <arg> (default .bam) --group_segmentation, --b37/--hg19 (default hg38) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --ginkgo_cnv --bam_dir /path/to/BAMs/ \n\n\
Demultiplexer: \n\t\
    Required: -r/--run_dir <arg> and -f/--fastq_dir <arg> \n\t\
    Optional: --sample_sheet <arg> (default SampleSheet.csv), -p/--project <arg> \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --demultiplex --fastq_dir /path/to/fastq/ --run_dir /path/to/runfolder/ \n\n\
VAF filter: \n\t\
    Required: --input_vcf <arg> and --output_tsv <arg> \n\t\
    Optional: --input_blacklist <arg>, --output_blacklist <arg>, --combine_blacklists, --vaf <arg> (default 0.1), --dp <arg> (default 5), --mq <arg> (default 30) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --vaf_filter --input_vcf /path/to/unfiltered_variants.vcf --output_tsv /path/to/filtered_variants.tsv \n\n\
Monovar variant caller: \n\t\
    Required: -b/--bam_dir <arg>, -p/--project <arg> \n\t\
    Optional: --results_dir <arg> (default bam_dir), --bam_suffix <arg> (default .bam) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --monovar --project Monovar --bam_dir /path/to/BAMs/ \n\n\
Lorenz curve: \n\t\
    Required: -b/--bam_dir <arg>, -p/--project <arg> \n\t\
    Optional: --results_dir <arg> (default bam_dir), --kb_bin_size <arg> (default 1000), --bam_regex <arg> (default .*.bam), --bam_suffix <arg> (default .bam) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --lorenz_curve --bam_dir /path/to/BAMs/ --project PTA_BAMs \n\n\
Circle map: \n\t\
    Required: -b/--bam_dir <arg> \n\t\
    Optional: --results_dir <arg> (default bam_dir), --b37/--hg19 (default hg38), --bam_suffix <arg> (default .bam), --bam_regex <arg> (default .*.bam), --final_snps <arg>, --final_indels <arg> \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --circle_map --bam_dir /path/to/BAMs/ \n\n\
SigProfiler: \n\t\
    Required: --project <arg> and either --vcf <arg> or --tsv <arg> \n\t\
    Optional: --results_dir (default is where --vcf or --tsv is located), --b37/--hg19 (default hg38) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --sig_profiler --project SigProfiler --vcf /path/to/my_variants.vcf.gz \n\n\
Tranche filter: \n\t\
    Required: --vcf <arg>, --tranche <arg> \n\t\
    Optional: --exome, --results_dir (default is where --vcf is located), --project <arg>, --b37 (default hg38) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --tranche_filter --vcf /path/to/my_variants.vcf.gz --tranche 99.0 \n\n\
Scan2: \n\t\
    Required: --bam_dir <arg>, --project <arg> \n\t\
    Optional: --results_dir (default bam_dir), --bulk (default T1200-1.bam), --bam_suffix <arg> (default .bam), --bam_regex <arg> (default .*.bam), --b37 (default b37 but will be hg38 in the future) \n\t\
    Run like: \n\t\t\
        sh ${PIPELINE_DIR}/submit_job.sh --scan2 --bam_dir /path/to/BAMs/ --project Scan2_Analysis \n\n\
Variant Class: \n\t\
	Required: --bam_dir <arg>, --project <arg> \n\t\
	Optional: --results_dir (default bam_dir), --bam_suffix <arg> (default .bam), --bam_regex <arg> (default .*.bam), --b37 (default hg38) \n\t\
	Run like: \n\t\t\
		sh ${PIPELINE_DIR}/submit_job.sh --variant_class --bam_dir /path/to/BAMs/ --project Variant_Class_Analysis \n\n\
mosdepth: \n\t\
	Required: --bam_dir <arg> \n\t\
	Optional: --results_dir (default bam_dir), --bam_suffix <arg> (default .bam), --bam_regex <arg> (default .*.bam) \n\t\
	Run like: \n\t\t\
		sh ${PIPELINE_DIR}/submit_job.sh --mosdepth --bam_dir /path/to/BAMs/ \n\n\
For more information, read the README.md"

# Reads in command line option arguments and assigns them to variables
GROUP_SEGMENTATION=0
GENOME_VERSION="hg38"
PROGRAM="none"
COMBINE_BLACKLISTS=0
KB_BIN_SIZE="500"
EXOME=0
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
        --vaf_filter )          PROGRAM="VAF_filter"
                                ;;
        --monovar )             PROGRAM="monovar"
                                ;;
        --lorenz_curve )        PROGRAM="lorenz_curve"
                                ;;
        --circle_map )          PROGRAM="circle_map"
                                ;;
        --sig_profiler )        PROGRAM="sig_profiler"
                                ;;
        --tranche_filter )      PROGRAM="tranche_filter"
                                ;;
        --scan2 )               PROGRAM="scan2"
                                ;;
        --variant_class )       PROGRAM="variant_class"
                                ;;
        --mosdepth )            PROGRAM="mosdepth"
                                ;;
        --kb_bin_size )         shift
                                KB_BIN_SIZE=$1
                                ;;
        --hg19 )                GENOME_VERSION="hg19"
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
        --group_segmentation )  GROUP_SEGMENTATION=1
                                ;;
        --input_vcf )           shift
                                INPUT_VCF=$1
                                ;;
        --output_tsv )          shift
                                OUTPUT_TSV=$1
                                ;;
        --input_blacklist )     shift
                                INPUT_BLACKLIST=$1
                                ;;
        --output_blacklist )    shift
                                OUTPUT_BLACKLIST=$1
                                ;;
        --combine_blacklists )  COMBINE_BLACKLISTS=1
                                ;;
        --vaf )                 shift
                                VAF=$1
                                ;;
        --dp )                  shift
                                DP=$1
                                ;;
        --mq )                  shift
                                MQ=$1
                                ;;
        --final_snps )          shift
                                FINAL_SNPS=$1
                                ;;
        --final_indels )        shift
                                FINAL_INDELS=$1
                                ;;
        --vcf )                 shift
                                VCF=$1
                                ;;
        --tsv )                 shift
                                TSV=$1
                                ;;
        --tranche )             shift
                                TRANCHE=$1
                                ;;
        --exome )               EXOME=1
                                ;;
        --bulk )                shift
                                BULK=$1
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
    else
        RESULTS_DIR=$BAM_DIR
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $RESULTS_DIR ]; then
        mkdir $RESULTS_DIR
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
elif [ $PROGRAM = "conserting_sc_cnv" ] || [ $PROGRAM = "ginkgo_cnv" ] || [ $PROGRAM = "lorenz_curve" ]; then
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
    if [ ! -d $RESULTS_DIR ]; then
        mkdir $RESULTS_DIR
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
    elif [ $PROGRAM = "ginkgo_cnv" ]; then
        if [ $GROUP_SEGMENTATION -eq 1 ]; then
            OPTIONS+=( "--group_segmentation" )
        fi
        if [ $GENOME_VERSION = "hg19" ]; then
            OPTIONS+=( "--hg19" )
        elif [ $GENOME_VERSION = "b37" ]; then
            OPTIONS+=( "--b37" )
        fi
        REFERENCE_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/ginkgo/genomes/${GENOME_VERSION}"
        if [ ! -f "${REFERENCE_DIR}/variable_${KB_BIN_SIZE}000_76_bwa" ]; then
            echo "The reference files for that kb bin size have not been created. Exiting with code 1"
            exit 1
        fi
        sbatch ${SLURM_OPTIONS[@]} -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
            ${PIPELINE_DIR}/scripts/ginkgo_cnv.sh --bam_dir $BAM_DIR ${OPTIONS[@]}
    else
        KB_BIN_SIZE="1000"
        if [ -z $PROJECT ]; then
            echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
            exit 1
        fi
        sbatch ${SLURM_OPTIONS[@]} -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
            ${PIPELINE_DIR}/scripts/lorenz_curve.sh --bam_dir $BAM_DIR --pipeline_dir $PIPELINE_DIR \
            --err_out_dir $STD_ERR_OUT_DIR --project $PROJECT ${OPTIONS[@]}
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
elif [ $PROGRAM = "VAF_filter" ]; then
    if [ -z $INPUT_VCF ] || [ ! -f $INPUT_VCF ] || [ -z $OUTPUT_TSV ]; then
        echo "Variables not supplied correctly or input VCF doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $INPUT_BLACKLIST ]; then
        if [ ! -f $INPUT_BLACKLIST ]; then
            echo "Input blacklist specified but doesn't exist. Exiting with code 1"
            exit 1
        fi
    fi
    RESULTS_DIR=$(dirname $OUTPUT_TSV)
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    if [ ! -z $INPUT_BLACKLIST ]; then
        OPTIONS+=( "--input_blacklist $INPUT_BLACKLIST" )
    fi
    if [ ! -z $OUTPUT_BLACKLIST ]; then
        OPTIONS+=( "--output_blacklist $OUTPUT_BLACKLIST" )
    fi
    if [ ! -z $COMBINE_BLACKLISTS ]; then
        OPTIONS+=( "--combine_blacklists" )
    fi
    if [ ! -z $VAF ]; then
        OPTIONS+=( "--vaf $VAF" )
    fi
    if [ ! -z $DP ]; then
        OPTIONS+=( "--dp $DP" )
    fi
    if [ ! -z $MQ ]; then
        OPTIONS+=( "--mq $MQ" )
    fi
    sbatch ${SLURM_OPTIONS[@]} -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${PIPELINE_DIR}/scripts/VAF_filter.sh \
        --script_dir ${PIPELINE_DIR}/scripts --input_vcf $INPUT_VCF --output_tsv $OUTPUT_TSV ${OPTIONS[@]}
elif [ $PROGRAM = "monovar" ]; then
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
    if [ ! -d $RESULTS_DIR ]; then
        mkdir $RESULTS_DIR
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    if [ ! -z $BAM_SUFFIX ]; then
        OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
    else BAM_SUFFIX=".bam"
    fi
    NUM_SAMPLES=$(find ${BAM_DIR}/ -maxdepth 1 -name "*${BAM_SUFFIX}" | wc -l)
    if [ $NUM_SAMPLES -eq 0 ]; then
        echo "No BAM files found in the bam directory. Exiting with code 1"
        exit 1
    fi
    sbatch ${SLURM_OPTIONS[@]} -e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${PIPELINE_DIR}/scripts/monovar.sh --project $PROJECT --bam_dir $BAM_DIR ${OPTIONS[@]}
elif [ $PROGRAM = "circle_map" ]; then
    if [ -z $BAM_DIR ]; then
        echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $BAM_SUFFIX ]; then
        OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
    else
        BAM_SUFFIX=".bam"
    fi
    if [ -z $BAM_REGEX ]; then
        BAM_REGEX=".*.bam"
    fi
    if [ $GENOME_VERSION = "hg19" ]; then
        OPTIONS+=( "--hg19" )
    elif [ $GENOME_VERSION = "b37" ]; then
        OPTIONS+=( "--b37" )
    fi
    if [ ! -z $RESULTS_DIR ]; then
        OPTIONS+=( "--results_dir $RESULTS_DIR" )
    fi
    if [ -z $RESULTS_DIR ]; then
        RESULTS_DIR=$BAM_DIR
    fi
    if [ ! -d $RESULTS_DIR ]; then
        mkdir $RESULTS_DIR
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    if [ ! -z $FINAL_SNPS ]; then
        OPTIONS+=( "--final_snps $FINAL_SNPS" )
    fi
    if [ ! -z $FINAL_INDELS ]; then
        OPTIONS+=( "--final_indels $FINAL_INDELS" )
    fi
    SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
    SAMPLES_STRING=$( IFS=$':'; echo "${SAMPLE_ARRAY[*]}" )
    JOB_COUNT=${#SAMPLE_ARRAY[@]}
    if [ $JOB_COUNT -eq 0 ]; then
        echo "No BAM files found in the bam directory. Exiting with code 1"
        exit 1
    fi
    sbatch ${SLURM_OPTIONS[@]} -e ${STD_ERR_OUT_DIR}/%A_%a_%x.err -o ${STD_ERR_OUT_DIR}/%A_%a_%x.out \
        --array=1-${JOB_COUNT} ${PIPELINE_DIR}/scripts/circle_map_runner.sh \
        --script_dir ${PIPELINE_DIR}/scripts --bam_dir $BAM_DIR --samples_string $SAMPLES_STRING ${OPTIONS[@]}
elif [ $PROGRAM = "sig_profiler" ]; then
    if [ -z $PROJECT ] || ([ -z $VCF ] && [ -z $TSV ]); then
        echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $RESULTS_DIR ]; then
        OPTIONS+=( "--results_dir $RESULTS_DIR" )
        if [ ! -d $RESULTS_DIR ]; then
            mkdir $RESULTS_DIR
        fi
    fi
    if [ ! -z $VCF ]; then
        OPTIONS+=( "--vcf $VCF" )
        if [ -z $RESULTS_DIR ]; then
            RESULTS_DIR=$(dirname $VCF)
        fi
    fi
    if [ ! -z $TSV ]; then
        OPTIONS+=( "--tsv $TSV" )
        if [ -z $RESULTS_DIR ]; then
            RESULTS_DIR=$(dirname $TSV)
        fi
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    if [ $GENOME_VERSION = "hg19" ]; then
        OPTIONS+=( "--hg19" )
    elif [ $GENOME_VERSION = "b37" ]; then
        OPTIONS+=( "--b37" )
    fi
    sbatch ${SLURM_OPTIONS[@]} -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${PIPELINE_DIR}/scripts/SigProfiler.sh --project $PROJECT \
        --script_dir ${PIPELINE_DIR}/scripts/ ${OPTIONS[@]}
elif [ $PROGRAM = "tranche_filter" ]; then
    if [ -z $VCF ] || [ -z $TRANCHE ]; then
        echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $RESULTS_DIR ]; then
        OPTIONS+=( "--results_dir $RESULTS_DIR" )
        if [ ! -d $RESULTS_DIR ]; then
            mkdir $RESULTS_DIR
        fi
    fi
    if [ ! -z $VCF ]; then
        OPTIONS+=( "--vcf $VCF" )
        if [ -z $RESULTS_DIR ]; then
            RESULTS_DIR=$(dirname $VCF)
        fi
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    if [ $GENOME_VERSION = "b37" ]; then
        OPTIONS+=( "--b37" )
    fi
    if [ $EXOME -eq 1 ]; then
        OPTIONS+=( "--exome" )
    fi
    sbatch ${SLURM_OPTIONS[@]} -e ${STD_ERR_OUT_DIR}/%A_%x.err -o ${STD_ERR_OUT_DIR}/%A_%x.out \
        ${PIPELINE_DIR}/scripts/tranche_filter.sh --vcf $VCF --tranche $TRANCHE \
        --script_dir ${PIPELINE_DIR}/scripts/ ${OPTIONS[@]}
elif [ $PROGRAM = "scan2" ]; then
    if [ -z $BAM_DIR ] || [ -z $PROJECT ]; then
        echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $BAM_SUFFIX ]; then
        OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
    else
        BAM_SUFFIX=".bam"
    fi
    if [ ! -z $BAM_REGEX ]; then
        OPTIONS+=( "--bam_regex $BAM_REGEX" )
    else
        BAM_REGEX=".*.bam"
    fi
    GENOME_VERSION="b37"
    if [ $GENOME_VERSION = "b37" ]; then
        OPTIONS+=( "--b37" )
    fi
    if [ ! -z $RESULTS_DIR ]; then
        OPTIONS+=( "--results_dir $RESULTS_DIR" )
    else
        RESULTS_DIR=$BAM_DIR
    fi
    if [ ! -d $RESULTS_DIR ]; then
        mkdir $RESULTS_DIR
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    if [ ! -z $BULK ]; then
        OPTIONS+=( "--bulk $BULK" )
    fi
    SCAN2_ARRAY=()
    SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
    if [ ! -z $BULK ]; then
        SCAN2_OPTIONS=( "--bulk $BULK" )
        BULK_SAMPLE=$(basename $BULK | sed "s/${BAM_SUFFIX}//" | sed 's/.bqsr.marked.bam//' | sed 's/.bam//')
        for SAMPLE in ${SAMPLE_ARRAY[@]}; do
            if [ "$SAMPLE" != "$BULK_SAMPLE" ]; then
                SCAN2_ARRAY+=( "$SAMPLE" )
            fi
        done
    else
        SCAN2_ARRAY=("${SAMPLE_ARRAY[@]}")
    fi
    JOB_COUNT=${#SCAN2_ARRAY[@]}
    sbatch -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${JOB_COUNT} ${PIPELINE_DIR}/scripts/Scan2.sh \
        --b37 --script_dir ${PIPELINE_DIR}/scripts/ --bam_dir $BAM_DIR \
        --bam_suffix $BAM_SUFFIX --project $PROJECT ${OPTIONS[@]}
elif [ $PROGRAM = "variant_class" ]; then
	if [ -z $BAM_DIR ] || [ -z $PROJECT ]; then
        echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $BAM_SUFFIX ]; then
        OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
    else
        BAM_SUFFIX=".bam"
    fi
    if [ ! -z $BAM_REGEX ]; then
        OPTIONS+=( "--bam_regex $BAM_REGEX" )
    else
        BAM_REGEX=".*.bam"
    fi
    if [ $GENOME_VERSION = "b37" ]; then
        OPTIONS+=( "--b37" )
    fi
    if [ ! -z $RESULTS_DIR ]; then
        OPTIONS+=( "--results_dir $RESULTS_DIR" )
    else
        RESULTS_DIR=$BAM_DIR
    fi
    if [ ! -d $RESULTS_DIR ]; then
        mkdir $RESULTS_DIR
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
    JOB_COUNT=${#SAMPLE_ARRAY[@]}
    DEPENDENCY=$(sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${JOB_COUNT} ${PIPELINE_DIR}/scripts/variant_class.sh \
        --script_dir ${PIPELINE_DIR}/scripts/ --bam_dir $RESULTS_DIR ${OPTIONS[@]})
	sbatch --dependency=afterany:$DEPENDENCY \
		-e $STD_ERR_OUT_DIR/%A_%x.err -o $STD_ERR_OUT_DIR/%A_%x.out \
        ${PIPELINE_DIR}/scripts/variant_class_analysis.sh \
        --script_dir ${PIPELINE_DIR}/scripts/ --bam_dir $BAM_DIR \
		--project $PROJECT ${OPTIONS[@]}
elif [ $PROGRAM = "mosdepth" ]; then
	if [ -z $BAM_DIR ]; then
        echo "Variables not supplied correctly or bam_dir doesn't exist. Use -h/--help options for assistance. Exiting with code 1"
        exit 1
    fi
    if [ ! -z $BAM_SUFFIX ]; then
        OPTIONS+=( "--bam_suffix $BAM_SUFFIX" )
    else
        BAM_SUFFIX=".bam"
    fi
    if [ ! -z $BAM_REGEX ]; then
        OPTIONS+=( "--bam_regex $BAM_REGEX" )
    else
        BAM_REGEX=".*.bam"
    fi
    if [ ! -z $RESULTS_DIR ]; then
        OPTIONS+=( "--results_dir $RESULTS_DIR" )
    else
        RESULTS_DIR=$BAM_DIR
    fi
    if [ ! -d $RESULTS_DIR ]; then
        mkdir $RESULTS_DIR
    fi
    if [ -z $STD_ERR_OUT_DIR ]; then
        STD_ERR_OUT_DIR="${RESULTS_DIR}/std_err_out_files"
    fi
    if [ ! -d $STD_ERR_OUT_DIR ]; then
        mkdir $STD_ERR_OUT_DIR
    fi
    SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
    JOB_COUNT=${#SAMPLE_ARRAY[@]}
    sbatch --parsable -e $STD_ERR_OUT_DIR/%A_%a_%x.err -o $STD_ERR_OUT_DIR/%A_%a_%x.out \
        --array=1-${JOB_COUNT} ${PIPELINE_DIR}/scripts/mosdepth.sh \
        --bam_dir $BAM_DIR ${OPTIONS[@]}
else
    echo "No program specified. Exiting with code 0"
    exit 0
fi