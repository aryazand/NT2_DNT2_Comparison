#!/bin/bash

PROCESSED_FASTQ_DESTINATION_FOLDER = Processed_Data/Trimmed/
FASTQ = $(shell find Raw_Data -type f -name '*.fastq.gz')
FASTQ_TRIMMED = $(addprefix $(PROCESSED_FASTQ_DESTINATION_FOLDER), $(notdir $(FASTQ)))
PROCESSED_FASTA = $(FASTQ:fastq=fasta)
ALIGNED_READS_BAM = $(PROCESSED_FASTA:fasta=bam)
BED = $(ALIGNED_READS_SAM:sam=bed)

.PHONY: all clean

all: $(FASTQ_TRIMMED)

# Step 1: use fastx to do the following:  
#   - convert fastq to fasta
#   - remove adapter sequences 
#   - remove PCR duplicates
#   - remove barcode 

$(FASTQ_TRIMMED): Processed_Data/Trimmed/%.fastq.gz: $(filter %.fastq.gz, $(FASTQ)) Scripts/process_fastq.sh
	Scripts/process_fastq.sh -i $< -o $(PROCESSED_FASTQ_DESTINATION_FOLDER)
	 
# Step 2: Align reads to genome and outputs a bam file
#   - use bowtie2 to align to genome and spike-in genome
#   - remove unaligned reads, remove multi-aligned reads 
#   - use samtools to convert alignment to a bam file 
#   - combine reads from multiple lanes (but same sample) into a single bam 


# Step 3: Convert bam to bed files
#   - use bedtools 


# Step 4: Differential Gene Analysis 
#   - use bedtools  

clean: