#!/bin/bash
#
#SBATCH --job-name=Scan2
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --time=3-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools/"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"

GENOME_VERSION="hg38"
REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_hg38"
REF_FASTA="${REFERENCE_DIR}/Homo_sapiens_assembly38.fasta"
DBSNP_VCF="${REFERENCE_DIR}/Homo_sapiens_assembly38.dbsnp138.vcf"
SHAPEIT_DIR="${REFERENCE_DIR}/1000GP_Phase3"
REGIONS_BED="${REFERENCE_DIR}/hg38_chr24_10M_regions.bed"
GOLD_STANDARD="/oak/stanford/groups/cgawad/Reference_Files/T1200_hg38_BAMs/T1200-1.bam"

while [ "$1" != "" ]; do
    case $1 in
        --project )         shift
                            PROJECT=$1
                            ;;
        --results_dir )     shift
                            RESULTS_DIR=$1
                            ;;
        --b37 )             GENOME_VERSION="b37"
                            ;;
        --script_dir )      shift
                            SCRIPT_DIR=$1
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
        --bulk )            shift
                            BULK=$1
                            ;;                 
    esac
    shift
done

OPTIONS=()
if [ $GENOME_VERSION = "b37" ]; then
    REFERENCE_DIR="/oak/stanford/groups/cgawad/Reference_Files/GATK_Resource_Bundle_b37"
    REF_FASTA="${REFERENCE_DIR}/human_g1k_v37.fasta"
    DBSNP_VCF="${REFERENCE_DIR}/Scan2/dbsnp_138.b37.vcf"
    SHAPEIT_DIR="${REFERENCE_DIR}/Scan2/1000GP_Phase3"
    REGIONS_BED="${REFERENCE_DIR}/Scan2/gatk_regions_example.txt"
    GOLD_STANDARD="/oak/stanford/groups/cgawad/Wet_Lab_Tech_Development/R2D2_First_PTA_Paper/PTA_MDA_LIANTI_Comparison/PTA_WGA_WGS_BAMS/T1200-1.bam"
    OPTIONS+=( "--b37" )
else
    echo "hg38 not currently supported. Try running with --b37. Use -h/--help options for assistance. Exiting with code 1"
    exit 1
fi
if [ -z $RESULTS_DIR ]; then
    RESULTS_DIR=$BAM_DIR
fi
if [ -z $BULK ]; then
    BULK=$GOLD_STANDARD
fi
BULK_SAMPLE=$(basename $BULK | sed "s/${BAM_SUFFIX}//" | sed 's/.bqsr.marked.bam//' | sed 's/.bam//')
SAMPLE_ARRAY=( $(find ${BAM_DIR} -maxdepth 1 -regextype sed -regex ".*${BAM_REGEX}" -exec basename {} \; | sed "s/${BAM_SUFFIX}//" | grep -v "$BULK_SAMPLE") )
SAMPLE=${SAMPLE_ARRAY[$(( $SLURM_ARRAY_TASK_ID - 1 ))]}
SAMPLE_DIR="${RESULTS_DIR}/Scan2_Results_${SAMPLE}"
echo -e "START: $(date)\nBam dir: $BAM_DIR\nBam regex: $BAM_REGEX\nBam suffix: $BAM_SUFFIX"
echo -e "Genome version: $GENOME_VERSION\nResults dir: $RESULTS_DIR\nSample: $SAMPLE\nBulk: $BULK"

source /home/groups/cgawad/miniconda3/etc/profile.d/conda.sh
conda activate scan2

cd $RESULTS_DIR
scan2 -d Scan2_Results_${SAMPLE} init
cd Scan2_Results_${SAMPLE}

echo "### Running Scan2 ### - START: $(date)"
scan2 config \
	--verbose \
	--ref $REF_FASTA \
	--dbsnp $DBSNP_VCF \
	--shapeit-refpanel $SHAPEIT_DIR \
	--abmodel-chunks=4 \
	--abmodel-samples-per-chunk=5000 \
	--abmodel-steps=4 \
	--callable-regions True \
	--score-all-sites \
	--regions-file $REGIONS_BED \
	--bulk-bam $BULK \
	--sc-bam ${SAMPLE}${BAM_SUFFIX}
echo "Scan2 configured"
scan2 validate
echo "Scan2 validated"
scan2 run --joblimit 300 --cluster 'sbatch -p cgawad --mem={resources.mem} -t 24:00:00 -o %logdir/slurm-%A.log' --snakemake-args ' --keep-going --max-status-checks-per-second 0.1'
echo "Scan2 ran"
echo "### Running Scan2 ### - END: $(date)"

echo "### Analyzing Scan2 mutational rates and true positives ### - START: $(date)"
SET=$(echo $SAMPLE | sed "s/PGT_23366_/E/" | sed 's/Biopsy//' | sed 's/_S.*//')
RDA="${SAMPLE_DIR}/snv/${SAMPLE}/somatic_genotypes.rda"
Rscript germline_control.R $RDA somatic_${SAMPLE}.csv germline_${SAMPLE}.csv
echo "True positive germline and somatic variants obtained"
REGIONS="${SAMPLE_DIR}/callable_regions/${SAMPLE}/summary.chunk*.bulk_intersect.rda"
Rscript get_callable_bases.R callable_${SAMPLE}.csv $REGIONS
echo "Callable bases obtained"
Rscript mutburden.R somatic_${SAMPLE}.csv germline_${SAMPLE}.csv callable_${SAMPLE}.csv burden_${SAMPLE}.csv
echo "Mutation burden analyzed"
head -n 1 germline_${SAMPLE}.csv | sed "s/chr/CHROM/" | sed "s/pos/POS/" | sed "s/refnt/REF/" | sed "s/altnt/ALT/" | tr ',' '\t' > ${RESULTS_DIR}/germline_${SAMPLE}.tsv
tail -n +2 germline_${SAMPLE}.csv | tr ',' '\t' >> ${RESULTS_DIR}/germline_${SAMPLE}.tsv
echo "Germline true positives formatted for SigProfiler script"
head -n 1 somatic_${SAMPLE}.csv | sed "s/chr/CHROM/" | sed "s/pos/POS/" | sed "s/refnt/REF/" | sed "s/altnt/ALT/" | tr ',' '\t' > ${RESULTS_DIR}/somatic_${SAMPLE}.tsv
tail -n +2 somatic_${SAMPLE}.csv | tr ',' '\t' >> ${RESULTS_DIR}/somatic_${SAMPLE}.tsv
echo "Somatic true positives formatted for SigProfiler script"
# cd $RESULTS_DIR
# rm -r Scan2_Results_${SAMPLE}
echo "### Analyzing Scan2 mutational rates and true positives ### - END: $(date)"

echo "### Computing mutational signature with SigProfiler ### - START: $(date)"
srun ${SCRIPT_DIR}/SigProfiler.sh --project $PROJECT \
    --script_dir $SCRIPT_DIR --results_dir $RESULTS_DIR \
    --tsv germline_${SAMPLE}.tsv \
    ${OPTIONS[@]}
echo "Germline true positives mutational signatures done"
srun ${SCRIPT_DIR}/SigProfiler.sh --project $PROJECT \
    --script_dir $SCRIPT_DIR --results_dir $RESULTS_DIR \
    --tsv somatic_${SAMPLE}.tsv \
    ${OPTIONS[@]}
echo "Somatic true positives mutational signatures done"
echo "### Computing mutational signature with SigProfiler ### - END: $(date)"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"