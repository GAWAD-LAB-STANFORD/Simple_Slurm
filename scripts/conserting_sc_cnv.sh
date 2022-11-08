#!/bin/bash
#
#SBATCH --job-name=conserting_sc_cnv
#SBATCH --mem=32G
#SBATCH --time=6:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
echo "START: $(date)"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"
KB_BIN_SIZE="500"

while [ "$1" != "" ]; do
    case $1 in
        --bam_dir )         shift
                            BAM_DIR=$1
                            ;;
        --bam_regex )       shift
                            BAM_REGEX=$1
                            ;;
        --bam_suffix )      shift
                            BAM_SUFFIX=$1
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

ml perl R/4.2.0 biology samtools bedtools
export R_LIBS="/home/groups/cgawad/R_LIBS"
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
cd $RESULTS_DIR
SAMPLE=$(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | \
    sed "s/${BAM_SUFFIX}//" | sed -n ${SLURM_ARRAY_TASK_ID}p)
echo -e "START: $(date)\nSlurm ID: $SLURM_ARRAY_TASK_ID\nSample: $SAMPLE\nKb bin size: $KB_BIN_SIZE\nResults dir: $RESULTS_DIR"
echo -e "Bam dir: $BAM_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX"

N25CHR_BED="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38/Homo_sapiens_assembly38_n25chr.bed"
BEDGRAPH_TO_WIG_TOOL="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/bedgraph_to_wig.pl"
CONSERTING_SC_TOOL_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/Conserting_SC"

if [ ! -f ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX}.bai ]; then
    samtools index ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX}
fi
samtools view -b -L $N25CHR_BED ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} > ${SAMPLE}.n25chr.bam
bedtools genomecov -ibam ${SAMPLE}.n25chr.bam -bga > ${SAMPLE}.cnv_conserting.temp.bedGraph
awk '/^chr..?\t/' ${SAMPLE}.cnv_conserting.temp.bedGraph > ${SAMPLE}.cnv_conserting.bedGraph
echo "Bed graph file created"
perl $BEDGRAPH_TO_WIG_TOOL --bedgraph ${SAMPLE}.cnv_conserting.bedGraph --wig ${SAMPLE}.cnv_conserting.wig --step 1
echo "Wig file created"

${CONSERTING_SC_TOOL_DIR}/compiled_code/preppy ${SAMPLE}.cnv_conserting_${KB_BIN_SIZE}kb.temp.prep \
    ${CONSERTING_SC_TOOL_DIR}/n25chr_${KB_BIN_SIZE}kb_meta ${SAMPLE}.cnv_conserting.wig
awk '$3 != "NA"' ${SAMPLE}.cnv_conserting_${KB_BIN_SIZE}kb.temp.prep > ${SAMPLE}.cnv_conserting_${KB_BIN_SIZE}kb.prep
echo "CNV preparation file made for ${KB_BIN_SIZE}kb bin size"
Rscript ${CONSERTING_SC_TOOL_DIR}/source_code/conserting_xc_3_args.R ${SAMPLE}.cnv_conserting_${KB_BIN_SIZE}kb.prep \
    ${RESULTS_DIR}/${SAMPLE}.fig_cnv_conserting_${KB_BIN_SIZE}kb.png ${RESULTS_DIR}/${SAMPLE}.cnv_conserting_${KB_BIN_SIZE}kb.tsv
if [ ! -f ${SAMPLE}.fig_cnv_conserting_${KB_BIN_SIZE}kb.png ]; then
    echo "${SAMPLE}.fig_cnv_conserting_${KB_BIN_SIZE}kb.png file not found. CNV calculation failed"
else
    echo "CNV plot made for ${KB_BIN_SIZE}kb bin size"
    rm ${SAMPLE}.cnv_conserting_${KB_BIN_SIZE}kb.temp.prep ${SAMPLE}.cnv_conserting_${KB_BIN_SIZE}kb.prep
fi

rm ${SAMPLE}.n25chr.bam ${SAMPLE}.cnv_conserting.wig
rm ${SAMPLE}.cnv_conserting.temp.bedGraph ${SAMPLE}.cnv_conserting.bedGraph
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"