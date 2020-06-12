#!/bin/bash
#
#SBATCH --job-name=frequency_filter
#SBATCH --mem=32GB
#SBATCH --cpus-per-task=2
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
        --vaf_max )             shift
                                VAF_MAX=$1
                                ;;
        --dp_min )              shift
                                DP_MIN=$1
                                ;;
        --mq_min )              shift
                                MQ_MIN=$1
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
if [ $VAF_MAX -eq 1 ]; then
    OPTIONS+=( "--vaf_max $VAF_MAX" )
fi
if [ $DP_MIN -eq 1 ]; then
    OPTIONS+=( "--dp_min $DP_MIN" )
fi
if [ $MQ_MIN -eq 1 ]; then
    OPTIONS+=( "--mq_min $MQ_MIN" )
fi

ml R/3.6.1 python/3.6.1
export PYTHONPATH=/home/groups/cgawad/python_libs/lib/python3.6/site-packages:$PYTHONPATH

echo "Converting VCF to TSV - $(date)"
python3 /oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/vcf2tsv/vcf2tsv.py \
    $INPUT_VCF $TEMP_VCF2TSV
sed -i 1d $TEMP_VCF2TSV

echo "Filtering TSV - $(date)"
Rscript ${SCRIPT_DIR}/filter_by_VAF.R --input_tsv $TEMP_VCF2TSV --output_tsv $OUTPUT_TSV ${OPTIONS[@]}

rm $TEMP_VCF2TSV
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"