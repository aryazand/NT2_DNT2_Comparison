#!/bin/bash

PROCESSED_FASTQ_DESTINATION_FOLDER = Processed_Data/FASTQ

FASTQ_FILES_R1 = $(shell find Raw_Data -type f -name '*_R1_*.fastq.gz')
FASTQ_FILES_R2 = $(shell find Raw_Data -type f -name '*_R2_*.fastq.gz')
FASTQ_FILES = $(FASTQ_FILES_R1) $(FASTQ_FILES_R2)

FASTQ_TRIMMED_R1 = $(patsubst Raw_Data/%.fastq.gz, $(PROCESSED_FASTQ_DESTINATION_FOLDER)/%_val_1.fq, $(FASTQ_FILES_R1))
FASTQ_TRIMMED_R2 = $(patsubst Raw_Data/%.fastq.gz, $(PROCESSED_FASTQ_DESTINATION_FOLDER)/%_val_2.fq, $(FASTQ_FILES_R2))
FASTQ_TRIMMED = $(FASTQ_TRIMMED_R1) $(FASTQ_TRIMMED_R2)

FASTQ_PROCESSED = $(patsubst Raw_Data/%.fastq.gz, $(PROCESSED_FASTQ_DESTINATION_FOLDER)/%_processed.fastq, $(FASTQ_FILES))
FASTQC = $(FASTQ_PROCESSED:%.fastq=%_fastqc.html)
FASTQ_LANE_NAMES = $(sort $(patsubst Raw_Data/%/, %, $(dir $(FASTQ_FILES))))


ALIGNED_READS_BAM = $(PROCESSED_FASTA:fasta=bam)
BED = $(ALIGNED_READS_SAM:sam=bed)

.PHONY: all clean

all: $(FASTQ_PROCESSED) $(FASTQC) clean
	
# Step 1: 
#		- remove adaptor_sequences using trim_galore  

.SECONDEXPANSION:
$(FASTQ_TRIMMED): $(PROCESSED_FASTQ_DESTINATION_FOLDER)/%.fq: $$(wildcard ./Raw_Data/$$(dir %)/*.fastq.gz)
	@#Scripts/process_fastq.sh -i $(word 1, $^) -i $(word 2, $^) -o $(dir $@)
	mkdir -p $(PROCESSED_FASTQ_DESTINATION_FOLDER)
	trim_galore --paired --dont_gzip -j 4 --output_dir $(dir $@) $(wordlist 1,2, $^)

# Step 2 
#		- deduplicate using seqkit 

$(FASTQ_PROCESSED): $(PROCESSED_FASTQ_DESTINATION_FOLDER)/%_processed.fastq: $$(wildcard $(PROCESSED_FASTQ_DESTINATION_FOLDER)/%_val_*.fq)
	seqkit rmdup -s -o $@ $<
	
# Step 3
#		- run quality analysis on processed fastq files using fastqc 

$(FASTQC): $(PROCESSED_FASTQ_DESTINATION_FOLDER)/%_processed_fastqc.html: $(PROCESSED_FASTQ_DESTINATION_FOLDER)/%_processed.fastq
	fastqc $< -o $(dir $@)
	
# Step 4: Align reads to genome and outputs a bam file
#   - use bowtie2 to align to genome and spike-in genome
#   - remove unaligned reads, remove multi-aligned reads 
#   - use samtools to convert alignment to a bam file 
#   - combine reads from multiple lanes (but same sample) into a single bam 


# Step 3: Convert bam to bed files
#   - use bedtools 


# Step 4: Differential Gene Analysis 
#   - use bedtools  

clean:
	rm $(FASTQ_TRIMMED)