#!/bin/bash
#
#SBATCH --job-name=bam_metrics
#SBATCH --cpus-per-task=4
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)

# File and directory paths (reference files available in /oak/stanford/groups/cgawad/Reference_Files/)
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"
GENOME_VERSION="hg38"
TARGETED=0
BEDGRAPH_TO_WIG_TOOL="${TOOLS_DIR}/bedgraph_to_wig.pl"
QUALIMAP_TOOL="${TOOLS_DIR}/qualimap_v2.2.1/qualimap"
PRESEQ_TOOL_DIR="${TOOLS_DIR}/preseq"
CONSERTING_SC_TOOL_DIR="${TOOLS_DIR}/Conserting_SC"

# hg38 reference files
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
REF_GENOME="${REFERENCE_DIR}/Homo_sapiens_assembly38_bedtools.genome" # .genome or .fai file produced from samtools faidx function
N25CHR_INTERVAL_LIST="${REFERENCE_DIR}/Homo_sapiens_assembly38_n25chr.interval_list"
N25CHR_BED="${REFERENCE_DIR}/Homo_sapiens_assembly38_n25chr.bed"
EXOME_INTERVAL_LIST="${REFERENCE_DIR}/xgen-exome-research-panel-targets_grch38_5col.interval_list"
if [ $TARGETED -eq 1 ]; then
    INTERVAL_LIST=$EXOME_INTERVAL_LIST
else
    INTERVAL_LIST=$N25CHR_INTERVAL_LIST
fi
KNOWN_SITES_VCFS=(
    "${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
    "${REFERENCE_DIR}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
    "${REFERENCE_DIR}/Homo_sapiens_assembly38.known_indels.vcf.gz"
)

while [ "$1" != "" ]; do
    case $1 in
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
        --b37 )             GENOME_VERSION="b37"
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
        --exome )           TARGETED=1
                            ;;             
    esac
    shift
done

cd $RESULTS_DIR
ml R/4.0.2 java gsl biology samtools bedtools gatk bcftools
export R_LIBS="/home/groups/cgawad/R_LIBS"

# hg19 version b37 reference files
if [ "$GENOME_VERSION" = "b37" ]; then
    REF_FASTA="${REFERENCE_DIR}/human_g1k_v37.fasta"
    REF_GENOME="${REFERENCE_DIR}/human_g1k_v37.genome"
    N25CHR_INTERVAL_LIST="${REFERENCE_DIR}/human_g1k_v37_n25chr.interval_list"
    N25CHR_BED="${REFERENCE_DIR}/human_g1k_v37_n25chr.bed"
    EXOME_INTERVAL_LIST="${REFERENCE_DIR}/xgen-exome-research-panel-v2-targets_b37_5col.interval_list"
    if [ $TARGETED -eq 1 ]; then
        INTERVAL_LIST=$EXOME_INTERVAL_LIST
    else
        INTERVAL_LIST=$N25CHR_INTERVAL_LIST
    fi
    KNOWN_SITES_VCFS=(
        "${REFERENCE_DIR}/dbsnp_138.b37.vcf.gz"
        "${REFERENCE_DIR}/Mills_and_1000G_gold_standard.indels.b37.vcf.gz"
        "${REFERENCE_DIR}/1000G_phase1.indels.b37.vcf.gz"
    )
fi

SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//") )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
echo -e "START: $(date)\nBam dir: $BAM_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX"
echo -e "Genome version: $GENOME_VERSION\nResults dir: $RESULTS_DIR\nSample: $SAMPLE"

echo "### Basic bcftools variant calling - START: $(date) ###"
samtools mpileup -uf $REF_FASTA ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} | bcftools call -mv > ${SAMPLE}.pileup_calls.vcf
echo -e "count\tref\talt" > ${SAMPLE}.variant_class_counts.tsv
cat ${SAMPLE}_pileup_calls.vcf | cut -f 4,5 | sort | uniq -c | sort -k1n | \
    sed 's/^[[:space:]]*//' | sed "s/ /$(printf '\t')/" >> ${SAMPLE}.variant_class_counts.tsv
rm ${SAMPLE}.pileup_calls.vcf
echo "### Basic bcftools variant calling - END: $(date) ###"

echo "### Counting BAM reads ### - START: $(date)"
TOTAL_READS=$(samtools view -c ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX})
MAPPED_READS=$(samtools view -c -F 260 ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX})
echo -e "sample\ttotal_reads\tmapped_reads" > ${SAMPLE}.read_counts.tsv
echo -e "$SAMPLE\t$TOTAL_READS\t$MAPPED_READS" >> ${SAMPLE}.read_counts.tsv
echo "### Counting BAM reads ### - END: $(date)"

echo "### Calculating QC metrics ### - START: $(date)"
if [ $TARGETED -eq 1 ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" CollectHsMetrics \
        -I ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}.hs_metrics.tsv -R $REF_FASTA \
        -BI $INTERVAL_LIST -TI $INTERVAL_LIST --VALIDATION_STRINGENCY LENIENT
    echo "CollectHsMetrics done"
else
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" CollectWgsMetrics \
        -I ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}.wgs_metrics.tsv \
        -R $REF_FASTA --VALIDATION_STRINGENCY LENIENT --INTERVALS $INTERVAL_LIST
    echo "CollectWgsMetrics done"
fi

gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" CollectMultipleMetrics \
    -I ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}.multiple_metrics --INTERVALS $INTERVAL_LIST \
    -R $REF_FASTA --VALIDATION_STRINGENCY LENIENT --PROGRAM CollectAlignmentSummaryMetrics \
    --PROGRAM CollectBaseDistributionByCycle --PROGRAM CollectInsertSizeMetrics --PROGRAM MeanQualityByCycle \
    --PROGRAM QualityScoreDistribution --PROGRAM CollectGcBiasMetrics --FILE_EXTENSION .tsv
echo "CollectMultipleMetrics done"

gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" CollectOxoGMetrics \
    -I ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}.oxog_metrics.tsv -R $REF_FASTA \
    --VALIDATION_STRINGENCY LENIENT --INTERVALS $INTERVAL_LIST
echo "CollectOxoGMetrics done"

gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" CollectDuplicateMetrics \
    -I ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}.duplication_metrics.tsv -R $REF_FASTA \
    --VALIDATION_STRINGENCY SILENT --MAX_RECORDS_IN_RAM 1000
echo "CollectDuplicateMetrics done"

# cat <(samtools view -SH ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX}) <(samtools view -S ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} | shuf -n 5000000) | samtools view -b - > ${SAMPLE}${BAM_5M_SUFFIX}
BAM_5M_SUFFIX=$(echo $BAM_SUFFIX | sed "s/.bam/.5M.bam/")
TOTAL_READS=$(samtools view -c ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX})
FRACTION=$(awk -v y="$TOTAL_READS" 'BEGIN {printf "%3f", 5000000 / y}')
if [ $TOTAL_READS -ge 5000000 ] && [ ! -z $FRACTION ]; then
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" DownsampleSam \
        -I ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} -O ${SAMPLE}${BAM_5M_SUFFIX} \
        --PROBABILITY $FRACTION --VALIDATION_STRINGENCY SILENT
    echo "5M downsample done"
    samtools index ${SAMPLE}${BAM_5M_SUFFIX}
    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.wgs_5M_read_coverage.tsv
    bedtools coverage -g $REF_GENOME -sorted -a $N25CHR_BED -b ${SAMPLE}${BAM_5M_SUFFIX} >> ${SAMPLE}.wgs_5M_read_coverage.tsv
    echo "5 million read coverage done"

    samtools view -b -L $N25CHR_BED ${SAMPLE}${BAM_5M_SUFFIX} > ${SAMPLE}${BAM_5M_SUFFIX}.n25chr.bam
    $PRESEQ_TOOL_DIR/bam2mr -o ${SAMPLE}${BAM_5M_SUFFIX}.n25chr.mr ${SAMPLE}${BAM_5M_SUFFIX}.n25chr.bam
    $PRESEQ_TOOL_DIR/preseq gc_extrap -o ${SAMPLE}.gc_extrap.future_coverage_5M.tsv ${SAMPLE}${BAM_5M_SUFFIX}.n25chr.mr
    rm ${SAMPLE}${BAM_5M_SUFFIX}.n25chr.bam* ${SAMPLE}${BAM_5M_SUFFIX}.n25chr.mr
    if [ ! -f ${SAMPLE}.gc_extrap.future_coverage_5M.tsv ]; then
        echo "PreSeq for 5M encountered a problem and did not complete"
    else
        echo "PreSeq for 5M done"
    fi
else
    echo "Bam is less than 5 million reads, cannot downsample"
fi

if [ $TOTAL_READS -le 200000000 ]; then
    samtools view -b -L $N25CHR_BED ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} > ${SAMPLE}.bqsr.marked.n25chr.bam
    $PRESEQ_TOOL_DIR/bam2mr -o ${SAMPLE}.bqsr.marked.n25chr.mr ${SAMPLE}.bqsr.marked.n25chr.bam
    $PRESEQ_TOOL_DIR/preseq gc_extrap -o ${SAMPLE}.gc_extrap.future_coverage.tsv ${SAMPLE}.bqsr.marked.n25chr.mr
    rm ${SAMPLE}.bqsr.marked.n25chr.mr
    if [ ! -f ${SAMPLE}.gc_extrap.future_coverage.tsv ]; then
        echo "PreSeq encountered a problem and did not complete"
    else
        echo "PreSeq done"
    fi
else
    echo "BAM is larger than 200M reads. Will not compute PreSeq"
fi

samtools view -b -L $N25CHR_BED ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} > ${SAMPLE}.bqsr.marked.n25chr.bam
echo "Bam restriction to canonical 25 chr region done"
bedtools bamtobed -i ${SAMPLE}.bqsr.marked.n25chr.bam | cut -f 1-3 > ${SAMPLE}.bqsr.marked.n25chr.bed
echo "Bam to bed conversion done"
echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.wgs_coverage.tsv
bedtools coverage -g $REF_GENOME -sorted -a $N25CHR_BED -b ${SAMPLE}.bqsr.marked.n25chr.bed >> ${SAMPLE}.wgs_coverage.tsv
echo "Coverage done"

mkdir ${SAMPLE}_temp_qualimap_output
$QUALIMAP_TOOL bamqc -nt 4 -nw 3000 --java-mem-size=60G -bam ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} \
    -c -hm 3 -outdir ${SAMPLE}_temp_qualimap_output -outformat PDF
if [ ! -f ${SAMPLE}_temp_qualimap_output/report.pdf ]; then
    echo "QualiMap encountered a problem and did not complete"
else
    mv ${SAMPLE}_temp_qualimap_output/report.pdf ${SAMPLE}.multiple_metrics.qualimap_report.pdf
    mv ${SAMPLE}_temp_qualimap_output/genome_results.txt ${SAMPLE}.multiple_metrics.qualimap_genome_results.txt
    echo "QualiMap done"
fi
rm -r ${SAMPLE}_temp_qualimap_output
if [ $TARGETED -eq 1 ]; then
    if [ -f ${SAMPLE}${BAM_5M_SUFFIX} ]; then
        echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.targeted_5M_read_coverage.tsv
        bedtools coverage -sorted -a $TARGETS_BED -b ${SAMPLE}${BAM_5M_SUFFIX} >> ${SAMPLE}.targeted_5M_read_coverage.tsv
        echo "5 million read targeted coverage done"
    fi

    echo -e "chr\tstart\tend\tcovered_features\tcovered_bases\tbed_length\tbreadth_coverage_fraction" > ${SAMPLE}.targeted_coverage.tsv
    bedtools coverage -sorted -a $TARGETS_BED -b ${BAM_DIR}/${SAMPLE}${BAM_SUFFIX} >> ${SAMPLE}.targeted_coverage.tsv
    echo "Exome coverage done"
fi
echo "### Calculating QC metrics ### - END: $(date)"