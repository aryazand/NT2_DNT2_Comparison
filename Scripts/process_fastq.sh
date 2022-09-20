#!/bin/bash

# Get Arguments
#   - i = input fastq file
#   - o = output fasta file 
while getopts i:o: flag
do
    case "${flag}" in
        i) input_fastq=${OPTARG};;
        o) output_fasta=${OPTARG};;
    esac
done

mkdir -p ./Process_Data/Trimmed
./Scripts/TrimGalore-0.6.0/trim_galore --paired --small_rna --dont_gzip -j 4 --ouput_dir --fastqc ./Process_Data/Trimmed $i