#!/bin/bash

# Get Arguments
#   - i = input fastq file
#   - o = output folder
while getopts i:o: flag
do
    case "${flag}" in
        i) input_fastq=${OPTARG};;
        o) output_folder=${OPTARG};;
    esac
done

mkdir -p $output_folder
./Scripts/TrimGalore-0.6.0/trim_galore --paired --small_rna --dont_gzip -j 4 --ouput_dir --fastqc $output_folder $i