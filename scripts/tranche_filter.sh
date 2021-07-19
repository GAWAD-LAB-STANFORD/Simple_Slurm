#!/bin/bash
#
#SBATCH --job-name=tranche_filter
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --time=4-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
GENOME_VERSION="hg38"
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/"
ANNOVAR_DIR="/oak/stanford/groups/cgawad/Reference_Files/ANNOVAR"
GENOME_VERSION="hg38"
TARGETED=0

while [ "$1" != "" ]; do
    case $1 in
        --vcf )                 shift
                                VCF=$1
                                ;;
        --genome_version )      shift
                                GENOME_VERSION=$1
                                ;;
        --project )             shift
                                PROJECT=$1
                                ;;
        --tranche )             shift
                                TRANCHE=$1
                                ;;
        --script_dir )          shift
                                SCRIPT_DIR=$1
                                ;;
        --results_dir )         shift
                                RESULTS_DIR=$1
                                ;;
        --b37 )                 GENOME_VERSION="b37"
                                ;;
        --exome )               TARGETED=1
                                ;;
    esac
    shift
done

if [ -z $PROJECT ]; then
    PROJECT=$(echo $VCF | sed "s/.vcf.gz//" | sed "s/.merged//")
fi
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$(dirname $VCF)
fi
echo -e "START: $(date)\nVCF: $VCF\nProject: $PROJECT\nTranche: $TRANCHE\nResults dir: $RESULTS_DIR"
cd $RESULTS_DIR

ml R/4.0.2 java perl biology gatk bedtools samtools
export R_LIBS="/home/groups/cgawad/R_libs"

ml python/3.6.1
export PYTHONPATH=/home/groups/cgawad/python_libs/lib/python3.6/site-packages:$PYTHONPATH
export PATH=/home/groups/cgawad/python_libs/bin:$PATH

# File and directory paths (reference files available in /oak/stanford/groups/cgawag/Reference_Files/)
# hg38 reference files
ANNOVAR_GENOME_VERSION="hg38"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
DBSNP_VCF="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf.gz"
HAPMAP_VCF="${REFERENCE_DIR}/hapmap_3.3.hg38.vcf.gz"
MILLS_VCF="${REFERENCE_DIR}/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz"
ONEKG_VCF="${REFERENCE_DIR}/1000G_phase1.snps.high_confidence.hg38.vcf.gz"
OMNI_VCF="${REFERENCE_DIR}/1000G_omni2.5.hg38.vcf.gz"

# hg19 version b37 reference files
if [ "$GENOME_VERSION" = "b37" ]; then
    ANNOVAR_GENOME_VERSION="hg19"
    REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_b37"
    REF_FASTA="${REFERENCE_DIR}/human_g1k_v37.fasta"
    DBSNP_VCF="${REFERENCE_DIR}/dbsnp_138.b37.vcf.gz"
    HAPMAP_VCF="${REFERENCE_DIR}/hapmap_3.3.b37.vcf.gz"
    MILLS_VCF="${REFERENCE_DIR}/Mills_and_1000G_gold_standard.indels.b37.vcf.gz"
    ONEKG_VCF="${REFERENCE_DIR}/1000G_phase1.snps.high_confidence.b37.vcf.gz"
    OMNI_VCF="${REFERENCE_DIR}/1000G_omni2.5.b37.vcf.gz"
fi

if [ ! -f $VCF ]; then
    echo "$VCF does not exist. Exiting with code 1"
    exit 1
fi
if [ $TARGETED -eq 1 ]; then
    echo "### Running VQSR on SNPs and Indels ### - START: $(date)"
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" VariantRecalibrator \
        -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal \
        --tranches-file ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal.tranches \
        --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
        --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
        --resource:1000G,known=false,training=true,truth=false,prior=10.0 $ONEKG_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
        -an QD -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 \
        -tranche 99.6 -tranche 99.5 -tranche 99.4 -tranche 99.3 \
        -tranche 99.0 -tranche 98.0 -tranche 97.0 -tranche 90.0 -tranche $TRANCHE \
        --max-gaussians 4 -R $REF_FASTA --rscript-file ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal_plots.R
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" VariantRecalibrator \
        -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal \
        --tranches-file ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal.tranches \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
        --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
        -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 \
        -tranche 99.6 -tranche 99.5 -tranche 99.4 -tranche 99.3 \
        -tranche 99.0 -tranche 98.0 -tranche 97.0 -tranche 90.0 -tranche $TRANCHE \
        --max-gaussians 4 -R $REF_FASTA \
        --rscript-file ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal_plots.R
    echo "### Running VQSR on SNPs and Indels ### - END: $(date)"
else
    echo "### Running VQSR on SNPs and Indels ### - START: $(date)"
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" VariantRecalibrator \
        -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal \
        --tranches-file ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal.tranches \
        --resource:hapmap,known=false,training=true,truth=true,prior=15.0 $HAPMAP_VCF \
        --resource:omni,known=false,training=true,truth=true,prior=12.0 $OMNI_VCF \
        --resource:1000G,known=false,training=true,truth=false,prior=10.0 $ONEKG_VCF \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
        -an QD -an DP -an FS -an SOR -an MQ -an MQRankSum -an ReadPosRankSum --mode SNP \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 \
        -tranche 99.6 -tranche 99.5 -tranche 99.4 -tranche 99.3 \
        -tranche 99.0 -tranche 98.0 -tranche 97.0 -tranche 90.0 -tranche $TRANCHE \
        --max-gaussians 4 -R $REF_FASTA --rscript-file ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal_plots.RR
    gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" VariantRecalibrator \
        -V ${PROJECT}.merged.vcf.gz -O ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal \
        --tranches-file ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal.tranches \
        --resource:dbsnp,known=true,training=false,truth=false,prior=2.0 $DBSNP_VCF \
        --resource:mills,known=false,training=true,truth=true,prior=12.0 $MILLS_VCF \
        -an QD -an DP -an FS -an SOR -an ReadPosRankSum -an MQRankSum --mode INDEL \
        -tranche 100.0 -tranche 99.95 -tranche 99.9 -tranche 99.8 \
        -tranche 99.6 -tranche 99.5 -tranche 99.4 -tranche 99.3 \
        -tranche 99.0 -tranche 98.0 -tranche 97.0 -tranche 90.0 -tranche $TRANCHE \
        --max-gaussians 4 -R $REF_FASTA \
        --rscript-file ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal_plots.R
    echo "### Running VQSR on SNPs and Indels ### - END: $(date)"
fi

echo "### Applying VQSR to SNPs and Indels ### - START: $(date)"
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" ApplyVQSR \
    -R $REF_FASTA -V $VCF -O ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.vcf.gz \
    --ts-filter-level $TRANCHE --tranches-file ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal.tranches \
    --recal-file ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal -mode SNP
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" ApplyVQSR \
    -R $REF_FASTA -V $VCF -O ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.vcf.gz \
    --ts-filter-level $TRANCHE --tranches-file ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal.tranches \
    --recal-file ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal -mode INDEL
echo "### Applying VQSR to SNPs and Indels ### - END: $(date)"

echo "### Extracting SNPs and Indels ### - START: $(date)"
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" SelectVariants \
    -R $REF_FASTA -V ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.vcf.gz \
    -O ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.vcf.gz -select-type SNP
gatk --java-options "-XX:+UseParallelGC -XX:ParallelGCThreads=4 -Xmx63g" SelectVariants \
    -R $REF_FASTA -V ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.vcf.gz \
    -O ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.vcf.gz -select-type INDEL
echo "### Extracting SNPs and Indels ### - END: $(date)"

echo "### Annotating SNPs and Indels ### - START: $(date)"
perl ${ANNOVAR_DIR}/table_annovar.pl ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.vcf.gz -vcfinput -operation g,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad211_exome
perl ${ANNOVAR_DIR}/table_annovar.pl ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.vcf.gz -vcfinput -operation g,f,f,f,f,f,f \
    ${ANNOVAR_DIR}/humandb -buildver $ANNOVAR_GENOME_VERSION \
    -out ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only -nastring . -remove -otherinfo \
    -protocol refGene,avsnp150,dbnsfp35c,clinvar_20190305,cosmic91_coding,cosmic91_noncoding,gnomad211_exome
bgzip ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.vcf
tabix ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz
bgzip ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.vcf
tabix ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz
echo "### Annotating SNPs and Indels ### - END: $(date)"

echo "### Convert annotated VCF to TSV ### - START: $(date)"
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
sed -i "s/#CHROM/CHROM/" ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
${TOOLS_DIR}/vcflib/bin/vcf2tsv \
    -g ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.vcf.gz > \
    ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
sed -i "s/#CHROM/CHROM/" ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
echo "### Convert annotated VCF to TSV ### - END: $(date)"

echo "### Recalculate VAF ### - START: $(date)"
python3 ${SCRIPT_DIR}/split_add_VAF.py \
    -i ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv \
    -o ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
python3 ${SCRIPT_DIR}/split_add_VAF.py \
    -i ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv \
    -o ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv
rm ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
rm ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.${ANNOVAR_GENOME_VERSION}_multianno.temp.tsv
echo "### Recalculate VAF ### - END: $(date)"

echo "### Computing mutational signature with SigProfiler ### - START: $(date)"
cut -f 1,2,4,5 ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv \
    | uniq > ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_reformat.tsv
Rscript ${SCRIPT_DIR}/SigProfiler_1_Bedtools_Reformat.R ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_reformat.tsv \
    ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_before_input.tsv ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_after_input.tsv
bedtools getfasta -fi $REF_FASTA -bed ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_before_input.tsv \
    -bedOut > ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_before_output.tsv
bedtools getfasta -fi $REF_FASTA -bed ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_after_input.tsv \
    -bedOut > ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_after_output.tsv
Rscript ${SCRIPT_DIR}/SigProfiler_2_Trinucleotide_Reformat.R ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_reformat.tsv \
    ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_before_output.tsv ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_after_output.tsv \
    ${PROJECT}.tranche_${TRANCHE}.temp_trinucleotide.tsv ${SCRIPT_DIR}/Mutation_Types.tsv
python3 -u ${SCRIPT_DIR}/SigProfiler_3_Extractor.py ${PROJECT}.tranche_${TRANCHE}.temp_trinucleotide.tsv \
    ${PROJECT}.tranche_${TRANCHE}_SigProfiler_Results $RESULTS_DIR
rm ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_reformat.tsv 
rm ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_before_input.tsv ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_after_input.tsv 
rm ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_before_output.tsv ${PROJECT}.tranche_${TRANCHE}.temp_bedtools_after_output.tsv
rm ${PROJECT}.tranche_${TRANCHE}.temp_trinucleotide.tsv
echo "### Computing mutational signature with SigProfiler ### - END: $(date)"

echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"
if [ ! -f ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv ]; then
    echo "Final file ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.${ANNOVAR_GENOME_VERSION}_multianno.final.tsv not found. Exiting with code 1"
    exit 1
fi
rm ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal ${PROJECT}.tranche_${TRANCHE}.merged.snp.recal.idx 
rm ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal ${PROJECT}.tranche_${TRANCHE}.merged.indel.recal.idx
rm ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.vcf.gz* ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.vcf.gz*
rm ${PROJECT}.tranche_${TRANCHE}.merged.snp_vqsr.snp_only.avinput ${PROJECT}.tranche_${TRANCHE}.merged.indel_vqsr.indel_only.avinput