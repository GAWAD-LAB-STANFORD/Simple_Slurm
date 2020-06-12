# Guide to Simple_Slurm

- [Purpose](#purpose)
- [How To Run](#how-to-run)
- [What It Does Exactly](#what-it-does-exactly)
- [TODO and Notes](#todo-and-notes)

## Purpose
- This is a collection of simple slurm scripts for specific tasks, not fully fledged pipelines

## How To Run
- Submit all jobs by using the submit_all.sh script
    - For help, use the *-h* or *--help* option like:

    ```bash
    sh submit_all.sh --help
    ```

- You can use ~ if your file or folder is in your home directory, and you can exclude a path if your file or folder is in the results directory, but otherwise use absolute paths
- You can have '/' or nothing at the end of a directory path, either is fine:
    - -r /home/groups/cgawad/results/
    - -r /home/groups/cgawad/results

## What It Does Exactly
- Currently supported jobs
    - SCOPE CNV analysis
    - Conserting SC CNV analysis
    - Ginkgo CNV analysis
    - Demultiplexer
        - Includes initial library concentration correction if Sample Sheet has
            - Desired_Cluster_Density column with at least one entry
            - Initial_Concentration column with as many entries as samples
    - Variant Allele Frequency filter