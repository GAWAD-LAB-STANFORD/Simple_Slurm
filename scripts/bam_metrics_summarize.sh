#!/bin/bash
#
#SBATCH --job-name=bam_metrics_summarize
#SBATCH --cpus-per-task=2
#SBATCH --nodes=1
#SBATCH --time=1-00:00:00
#SBATCH --partition=cgawad

START_TIME=$(date +%s)

# File and directory paths (reference files available in /oak/stanford/groups/cgawad/Reference_Files/)
TOOLS_DIR="/oak/stanford/groups/cgawad/Sequencing_Analysis_Tools"
BAM_REGEX=".*.bam"
BAM_SUFFIX=".bam"
TARGETED=0

while [ "$1" != "" ]; do
    case $1 in
        --results_dir )     shift
                            RESULTS_DIR=$1
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


echo -e "START: $(date)\nResults dir: $RESULTS_DIR\nProject: $PROJECT"
cd $RESULTS_DIR
ml R/4.0.2 biology samtools
export R_LIBS="/home/groups/cgawad/R_LIBS"

echo "### Summarizing metrics ### - START: $(date)"
READ_COUNT_FILENAMES=( $(ls *.read_counts.tsv) )
head -n 1 ${READ_COUNT_FILENAMES[0]} > ${PROJECT}.merged_read_counts.tsv
for i in ${READ_COUNT_FILENAMES[@]}; do tail -n +2 $i; done >> ${PROJECT}.merged_read_counts.tsv
echo "Merged read counts"

ALIGNMENT_METRICS_FILENAMES=( $(ls *.multiple_metrics.alignment_summary_metrics.tsv) )
echo -e sample"\t"$(head -n 7 ${ALIGNMENT_METRICS_FILENAMES[0]} | tail -n 1) | sed 's/ /\t/g' > ${PROJECT}.merged_alignment_metrics.tsv
for i in ${ALIGNMENT_METRICS_FILENAMES[@]}; do 
    SAMPLE=$(echo $i | sed "s/.multiple_metrics.alignment_summary_metrics.tsv//")
    R1=$(head -n 8 $i | tail -n 1)
    R2=$(head -n 9 $i | tail -n 1)
    PAIR=$(head -n 10 $i | tail -n 1)
    echo -e "$SAMPLE\t$R1\n$SAMPLE\t$R2\n$SAMPLE\t$PAIR"
done | sed 's/ /\t/g' >> ${PROJECT}.merged_alignment_metrics.tsv
echo "Merged alignment metrics"

if [ $TARGETED -eq 1 ]; then
    WGS_METRICS_SUFFIX=".hs_metrics.tsv"
    WGS_METRICS_MERGED="${PROJECT}.merged_hs_metrics.tsv"
else
    WGS_METRICS_SUFFIX=".wgs_metrics.tsv"
    WGS_METRICS_MERGED="${PROJECT}.merged_wgs_metrics.tsv"
fi
WGS_METRICS_FILENAMES=( $(ls *${WGS_METRICS_SUFFIX}) )
echo -e sample"\t"$(head -n 7 ${WGS_METRICS_FILENAMES[0]} | tail -n 1) | sed 's/ /\t/g' > $WGS_METRICS_MERGED
for i in ${WGS_METRICS_FILENAMES[@]}; do echo -e $(echo $i | sed "s/$WGS_METRICS_SUFFIX//")"\t"$(head -n 8 $i | tail -n 1); done | sed 's/ /\t/g' >> $WGS_METRICS_MERGED
echo "Merged WGS metrics"

OXOG_METRICS_FILENAMES=( $(ls *.oxog_metrics.tsv) )
head -n 7 ${OXOG_METRICS_FILENAMES[0]} | tail -n 1 > ${PROJECT}.merged_oxog_metrics.tsv
for i in ${OXOG_METRICS_FILENAMES[@]}; do tail -n +8 $i | awk NF >> ${PROJECT}.merged_oxog_metrics.tsv; done
echo "Merged oxog metrics"

DUPLICATION_METRICS_FILENAMES=( $(ls *.duplication_metrics.tsv) )
head -n 7 ${DUPLICATION_METRICS_FILENAMES[0]} | tail -n 1 > ${PROJECT}.merged_duplication_metrics.tsv
for i in ${DUPLICATION_METRICS_FILENAMES[@]}; do head -n 8 $i | tail -n 1 >> ${PROJECT}.merged_duplication_metrics.tsv; done
echo "Merged duplication metrics"

COVERAGE_FILENAMES=( $(ls *.wgs_coverage.tsv) )
echo -e "sample\tchrM_proportion" > ${PROJECT}.merged_chrM_proportions.tsv
for i in ${COVERAGE_FILENAMES[@]}; do
    MAIN_CHR_COUNTS=$(tail -n +2 $i | cut -f 4 | paste -sd+ | bc)
    CHRM_COUNTS=$(grep -P "chrM\t" $i | cut -f 4)
    echo -e $(echo $i | sed "s/.wgs_coverage.tsv//")"\t"$(awk 'BEGIN {print('$CHRM_COUNTS'/'$MAIN_CHR_COUNTS')}')
done >> ${PROJECT}.merged_chrM_proportions.tsv
echo "Merged chrM proportions"

COVERAGE_FILENAMES=( $(ls *.wgs_coverage.tsv) )
for i in ${COVERAGE_FILENAMES[@]}; do
    SAMPLE=$(echo $i | sed "s/.wgs_coverage.tsv//")
    cut -f 4,7 $i | sed "s/covered_features/${SAMPLE}_depth/" | \
        sed "s/breadth_coverage_fraction/${SAMPLE}_breadth/" > ${SAMPLE}.temp_coverage.tsv
done
TEMP_COVERAGE_FILENAMES=( $(ls *.temp_coverage.tsv) )
cut -f 1,2,3,6 ${COVERAGE_FILENAMES[0]} | \
    paste - ${TEMP_COVERAGE_FILENAMES[@]} > ${PROJECT}.merged_wgs_coverage.tsv
rm ${TEMP_COVERAGE_FILENAMES[@]}
echo "Merged coverage"
Rscript ${SCRIPT_DIR}/graph_coverage.R ${PROJECT}.merged_wgs_coverage.tsv $PROJECT "wgs"

DOWN_SAMPLE_COV_FILENAMES=( $(ls *.wgs_5M_read_coverage.tsv) )
if [ ${#DOWN_SAMPLE_COV_FILENAMES[@]} -ne 0 ]; then
    for i in ${DOWN_SAMPLE_COV_FILENAMES[@]}; do
        SAMPLE=$(echo $i | sed "s/.wgs_5M_read_coverage.tsv//")
        cut -f 4,7 $i | sed "s/covered_features/${SAMPLE}_depth/" | \
            sed "s/breadth_coverage_fraction/${SAMPLE}_breadth/" > ${SAMPLE}.temp_coverage.tsv
    done
    TEMP_COVERAGE_FILENAMES=( $(ls *.temp_coverage.tsv) )
    cut -f 1,2,3,6 ${DOWN_SAMPLE_COV_FILENAMES[0]} | \
        paste - ${TEMP_COVERAGE_FILENAMES[@]} > ${PROJECT}.merged_wgs_coverage_5M_reads.tsv
    rm ${TEMP_COVERAGE_FILENAMES[@]}
    echo "Merged 5M coverage"
    Rscript ${SCRIPT_DIR}/graph_coverage.R ${PROJECT}.merged_wgs_coverage_5M_reads.tsv $PROJECT "5M_reads_wgs"
    
    DOWN_SAMPLE_PRESEQ_FILENAMES=( $(ls *.gc_extrap.future_coverage_5M.tsv) )
    head -n 1 ${DOWN_SAMPLE_PRESEQ_FILENAMES[0]} | sed "s/^/SAMPLE\t/" > ${PROJECT}.merged_preseq_future_coverage_5M.tsv
    for i in ${DOWN_SAMPLE_PRESEQ_FILENAMES[@]}; do
        SAMPLE=$(echo $i | sed "s/.gc_extrap.future_coverage_5M.tsv//")
        tail -n +2 $i | sed "s/^/${SAMPLE}\t/" >> ${PROJECT}.merged_preseq_future_coverage_5M.tsv
    done
    echo "Merged preseq future coverage"
    Rscript ${SCRIPT_DIR}/graph_preseq.R ${PROJECT}.merged_preseq_future_coverage_5M.tsv $PROJECT "5M_reads"
fi

PRESEQ_FILENAMES=( $(ls *.gc_extrap.future_coverage.tsv) )
head -n 1 ${PRESEQ_FILENAMES[0]} | sed "s/^/SAMPLE\t/" > ${PROJECT}.merged_preseq_future_coverage.tsv
for i in ${PRESEQ_FILENAMES[@]}; do
    SAMPLE=$(echo $i | sed "s/.gc_extrap.future_coverage.tsv//")
    tail -n +2 $i | sed "s/^/${SAMPLE}\t/" >> ${PROJECT}.merged_preseq_future_coverage.tsv
done
echo "Merged preseq future coverage"
Rscript ${SCRIPT_DIR}/graph_preseq.R ${PROJECT}.merged_preseq_future_coverage.tsv $PROJECT

VARIANT_CLASS_COUNTS_FILENAMES=( $(ls *.variant_class_counts.tsv) )
head -n 1 ${VARIANT_CLASS_COUNTS_FILENAMES[0]} | sed "s/^/sample\t/" > ${PROJECT}.merged_variant_class_counts.tsv
for i in ${VARIANT_CLASS_COUNTS_FILENAMES[@]}; do
	SAMPLE=$(echo $i | sed "s/.variant_class_counts.tsv//")
	tail -n +2 $i | sed "s/^/${SAMPLE}\t/" >> ${PROJECT}.merged_variant_class_counts.tsv
done 
Rscript ${SCRIPT_DIR}/variant_class_analysis.R ${PROJECT}.merged_variant_class_counts.tsv $PROJECT

if [ $TARGETED -eq 1 ]; then
    TARGETED_COVERAGE_FILENAMES=( $(ls *.targeted_coverage.tsv) )
    for i in ${TARGETED_COVERAGE_FILENAMES[@]}; do
        SAMPLE=$(echo $i | sed "s/.targeted_coverage.tsv//")
        cut -f 4,7 $i | sed "s/covered_features/${SAMPLE}_depth/" | \
            sed "s/breadth_coverage_fraction/${SAMPLE}_breadth/" > ${SAMPLE}.temp_coverage.tsv
    done
    TEMP_COVERAGE_FILENAMES=( $(ls *.temp_coverage.tsv) )
    cut -f 1,2,3,6 ${TARGETED_COVERAGE_FILENAMES[0]} | \
        paste - ${TEMP_COVERAGE_FILENAMES[@]} > ${PROJECT}.merged_targeted_coverage.tsv
    rm ${TEMP_COVERAGE_FILENAMES[@]}
    echo "Merged targeted coverage"
    Rscript ${SCRIPT_DIR}/graph_coverage.R ${PROJECT}.merged_targeted_coverage.tsv $PROJECT "targeted"
    
    TARGETED_DOWN_SAMPLE_COV_FILENAMES=( $(ls *.targeted_5M_read_coverage.tsv) )
    if [ ${#TARGETED_DOWN_SAMPLE_COV_FILENAMES[@]} -ne 0 ]; then
        for i in ${TARGETED_DOWN_SAMPLE_COV_FILENAMES[@]}; do
            SAMPLE=$(echo $i | sed "s/.targeted_5M_read_coverage.tsv//")
            cut -f 4,7 $i | sed "s/covered_features/${SAMPLE}_depth/" | \
                sed "s/breadth_coverage_fraction/${SAMPLE}_breadth/" > ${SAMPLE}.temp_coverage.tsv
        done
        TEMP_COVERAGE_FILENAMES=( $(ls *.temp_coverage.tsv) )
        cut -f 1,2,3,6 ${TARGETED_DOWN_SAMPLE_COV_FILENAMES[0]} | \
            paste - ${TEMP_COVERAGE_FILENAMES[@]} > ${PROJECT}.merged_targeted_coverage_5M_reads.tsv
        rm ${TEMP_COVERAGE_FILENAMES[@]}
        echo "Merged 5M targeted coverage"
        Rscript ${SCRIPT_DIR}/graph_coverage.R ${PROJECT}.merged_targeted_coverage_5M_reads.tsv $PROJECT "5M_reads_targeted"
    fi    
fi
echo "### Summarizing metrics ### - END: $(date)"

echo "### Deleting intermediate files ### - START: $(date)"
rm ${READ_COUNT_FILENAMES[@]} ${ALIGNMENT_METRICS_FILENAMES[@]} ${WGS_METRICS_FILENAMES[@]} ${OXOG_METRICS_FILENAMES[@]}
rm ${CHRM_PROP_FILENAMES[@]} ${COVERAGE_FILENAMES[@]} ${DOWN_SAMPLE_COV_FILENAMES[@]} ${DUPLICATION_METRICS_FILENAMES[@]}
rm ${PRESEQ_FILENAMES[@]} ${DOWN_SAMPLE_PRESEQ_FILENAMES[@]} ${VARIANT_CLASS_COUNTS_FILENAMES[@]}
mkdir -p ${PROJECT}_Multiple_Metric_Files
mv *multiple_metrics* ${PROJECT}_Multiple_Metric_Files/
mkdir -p ${PROJECT}_5M_Read_BAM_Files
mv *.5M.bam ${PROJECT}_5M_Read_BAM_Files/
if [ -f ${PROJECT}.temporary_3_column_bed_interval_file ]; then
    rm ${PROJECT}.temporary_3_column_bed_interval_file
fi
if [ $TARGETED -eq 1 ]; then
    rm ${TARGETED_COVERAGE_FILENAMES[@]} ${TARGETED_DOWN_SAMPLE_COV_FILENAMES[@]}
fi
echo "### Deleting intermediate files ### - END: $(date)"
echo -e "END: $(date)\nRuntime: $(($(date +%s)-$START_TIME)) seconds"