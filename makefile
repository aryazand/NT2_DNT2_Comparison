#!/bin/bash

FASTQ = $(shell find Raw_Data -type f -name '*.fastq.gz')
PROCESSED_FASTA = $(FASTQ:fastq=fasta)
ALIGNED_READS_BAM = $(PROCESSED_FASTA:fasta=bam)
BED = $(ALIGNED_READS_SAM:sam=bed)

@echo $(FASTQ)

.PHONY: all clean

all: #Insert dependency hear

# Step 1: use fastx to do the following:  
#   - convert fastq to fasta
#   - remove adapter sequences 
#   - remove PCR duplicates
#   - remove barcode 

# $(PROCESSED_FASTA) = Processed_Data/%.fasta: Raw_Data/%.fastq Scripts/process_fastq.sh
#   Scripts/process_fastq.sh -i $< -o $@

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