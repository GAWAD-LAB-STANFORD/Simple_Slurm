#!/bin/bash
#
#SBATCH --job-name=VAF_filter
#SBATCH --mem=32G
#SBATCH --time=10:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
COMBINE_BLACKLISTS=0

while [ "$1" != "" ]; do
    case $1 in
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
        --script_dir )          shift
                                SCRIPT_DIR=$1
                                ;;
    esac
    shift
done

TEMP_VCF2TSV="${INPUT_VCF}_$(date '+%Y-%m-%d_%H-%M-%S')_temp.tsv"
echo -e "START: $(date)\nInput VCF: $INPUT_VCF\nOutput TSV: $OUTPUT_TSV"
echo -e "VAF max: $VAF_MAX\nDepth min: $DP_MIN\nMap quality min: $MQ_MIN"
echo -e "Temporary vcf2tsv: $TEMP_VCF2TSV"
OPTIONS=()
if [ ! -z $INPUT_BLACKLIST ]; then
    OPTIONS+=( "--input_blacklist $INPUT_BLACKLIST" )
    echo "Input blacklist: $INPUT_BLACKLIST"
fi
if [ ! -z $OUTPUT_BLACKLIST ]; then
    OPTIONS+=( "--output_blacklist $OUTPUT_BLACKLIST" )
    echo "Output blacklist: $OUTPUT_BLACKLIST"
fi
if [ $COMBINE_BLACKLISTS -eq 1 ]; then
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

ml R/4.0.2 python/3.6.1
export PYTHONPATH=/home/groups/cgawad/python_libs/lib/python3.6/site-packages:$PYTHONPATH
export R_LIBS="/home/groups/cgawad/R_LIBS"

echo "Converting VCF to TSV - $(date)"
python3 /oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/vcf2tsv/vcf2tsv.py \
    $INPUT_VCF $TEMP_VCF2TSV
sed -i 1d $TEMP_VCF2TSV

echo "Filtering TSV - $(date)"
Rscript ${SCRIPT_DIR}/filter_by_VAF.R --input_tsv $TEMP_VCF2TSV --output_tsv $OUTPUT_TSV ${OPTIONS[@]}

rm $TEMP_VCF2TSV
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"