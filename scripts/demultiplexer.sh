#!/bin/bash
#
#SBATCH --job-name=demultiplexer
#SBATCH --mem=32G
#SBATCH --time=6:00:00
#SBATCH --partition=cgawad

while [ "$1" != "" ]; do
    case $1 in
        --run_dir )         shift
                            RUN_DIR=$1
                            ;;
        --sample_sheet )    shift
                            SAMPLE_SHEET=$1
                            ;;
        --fastq_dir )       shift
                            FASTQ_DIR=$1
                            ;;
        --project )         shift
                            PROJECT=$1
                            ;;
        --script_dir )      shift
                            SCRIPT_DIR=$1
                            ;;
    esac
    shift
done
R1_SUFFIX="_L001_R1_001.fastq.gz"
R2_SUFFIX="_L001_R2_001.fastq.gz"

if [ -z $RUN_DIR ] || [ -z $FASTQ_DIR ]; then
    echo "Variables not supplied correctly. Use -h/--help options for assistance. Exiting with code 1"
    exit 1
fi
if [ -z $SAMPLE_SHEET ]; then
    SAMPLE_SHEET="${RUN_DIR}/SampleSheet.csv"
fi
if [ ! -f $SAMPLE_SHEET ]; then
    echo "Sample sheet $SAMPLE_SHEET not found. Exiting with code 1"
    exit 1
fi

echo -e "Run dir: $RUN_DIR\nSample sheet: $SAMPLE_SHEET\nFastq dir: $FASTQ_DIR"

ml biology bcl2fastq
bcl2fastq --runfolder-dir $RUN_DIR --sample-sheet $SAMPLE_SHEET --output-dir $FASTQ_DIR

find $FASTQ_DIR -name "*.fastq.gz" -exec mv {} ${FASTQ_DIR}/ \;
BCL_SIZE=$(du -sh $RUN_DIR | cut -f 1)
UND_SIZE=$(du -shc ${FASTQ_DIR}/Undetermined*.fastq.gz | tail -n 1 | cut -f 1)
FASTQ_SIZE=$(ls ${FASTQ_DIR}/*.fastq.gz | grep -v "Undetermined\|extracted" | xargs du -shc | tail -n 1 | cut -f 1)
echo -e "$BCL_SIZE run dir produced $UND_SIZE of undetermined fastq.gz and $FASTQ_SIZE of determined fastq.gz"


SAMPLE_ARRAY=( $(find ${FASTQ_DIR}/ -maxdepth 1 -name "*${R1_SUFFIX}" -exec basename {} \; | \
    grep -v "Undetermined" | sed "s/${R1_SUFFIX}//") )
if [ ${#SAMPLE_ARRAY[@]} -eq 0 ]; then
    echo "No fastq.gz files matching default R1/R2 suffix found in the sample directory. Exiting with code 0"
    exit 0
else
    echo -e "Number of samples: ${#SAMPLE_ARRAY[@]}\nSamples: ${SAMPLE_ARRAY[@]}"
fi

SAMPLE_READ_COUNTS="${PROJECT}.sample_read_counts.tsv"
echo -e "sample\tread_count" > $SAMPLE_READ_COUNTS
for SAMPLE in ${SAMPLE_ARRAY[@]}; do
    echo "counting $SAMPLE reads"
    echo -e $SAMPLE"\t"$(echo $(zcat $R1_FASTQ | wc -l ) $(zcat $R2_FASTQ | wc -l) | \
        awk '{ print ($1 + $2) / 4 }' ) >> $SAMPLE_READ_COUNTS
done

DESIRED_CLUSTER_DENSITY=$(sed -n $(grep -n "Lane" $SAMPLE_SHEET | sed "s/:Lane.*//" | \
    awk '{print $1 + 1}')p $SAMPLE_SHEET | cut -d , -f $(grep "Lane" $SAMPLE_SHEET | \
    sed "s/,/\n/g" | nl | grep "Desired_Cluster_Density" | cut -f 1))
INITAL_CONCENTRATION_COLUMN=$(grep "Initial_Concentration" $SAMPLE_SHEET | tr , "\n" | nl | grep "Initial_Concentration" | cut -f 1)
LIBRARY_GROUP_COLUMN=$(grep "Library_Group" $SAMPLE_SHEET | tr , "\n" | nl | grep "Library_Group" | cut -f 1)
if [ ! -z $INITAL_CONCENTRATION_COLUMN ] && [ ! -z $DESIRED_CLUSTER_DENSITY ] && [ ! -z $PROJECT ]; then
    echo "### Calculating library concentration corrections ### - START: $(date)"
    cat $SAMPLE_READ_COUNTS > ${SAMPLE_READ_COUNTS}.temp
    tail -n +$(cat -n $SAMPLE_SHEET | grep "Initial_Concentration" | cut -f 1 | tr -d '[:blank:]') $SAMPLE_SHEET | \
        cut -d , -f $INITAL_CONCENTRATION_COLUMN | awk '{print tolower($0)}' | \
        paste ${SAMPLE_READ_COUNTS}.temp - > $SAMPLE_READ_COUNTS
    if [ ! -z $LIBRARY_GROUP_COLUMN ]; then
        cat $SAMPLE_READ_COUNTS > ${SAMPLE_READ_COUNTS}.temp
        tail -n +$(cat -n $SAMPLE_SHEET | grep "Library_Group" | cut -f 1 | tr -d '[:blank:]') $SAMPLE_SHEET | \
            cut -d , -f $LIBRARY_GROUP_COLUMN | awk '{print tolower($0)}' | \
            paste ${SAMPLE_READ_COUNTS}.temp - > $SAMPLE_READ_COUNTS
    fi
    rm ${SAMPLE_READ_COUNTS}.temp
    Rscript ${SCRIPT_DIR}/correct_library_concentrations.R \
        "${RUN_DIR}/RunCompletionStatus.xml" $DESIRED_CLUSTER_DENSITY $SAMPLE_READ_COUNTS $PROJECT
    echo "### Calculating library concentration corrections ### - END: $(date)"
fi