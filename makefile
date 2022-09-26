
##################### ANALYSIS PARAMETERS ##################### 
PROCESSED_FASTQ_FOLDER = Processed_Data/FASTQ
ALIGNMENT_FOLDER = Processed_Data/Aligned_Reads/
RAW_DATA_FOLDER = Raw_Data
BOWTIE_INDEX = ~/bioinformatics_tools/genomes/townecombined
HUMAN_GENOME_GTF = /home/arya/bioinformatics_tools/genomes/alias/hg38/ensembl_gtf/default/hg38.gtf.gz
UMI_SIZE = 8

###############################################################

#################### VARIABLES ################################

# Original Fastq files
FASTQ_FILES_R1 := $(shell find $(RAW_DATA_FOLDER) -type f -name '*_R1_*.fastq.gz')
FASTQ_FILES_R2 := $(shell find $(RAW_DATA_FOLDER) -type f -name '*_R2_*.fastq.gz')
FASTQ_FILES := $(FASTQ_FILES_R1) $(FASTQ_FILES_R2)
FASTQ_LANE_NAMES := $(sort $(patsubst $(RAW_DATA_FOLDER)/%/, %, $(dir $(FASTQ_FILES))))

# Trimmed Fastq 
FASTQ_TRIMMED_R1 := $(patsubst Raw_Data/%.fastq.gz, $(PROCESSED_FASTQ_FOLDER)/%_trimmed.fq, $(FASTQ_FILES_R1))
FASTQ_TRIMMED_R2 := $(patsubst Raw_Data/%.fastq.gz, $(PROCESSED_FASTQ_FOLDER)/%_trimmed.fq, $(FASTQ_FILES_R2))
FASTQ_TRIMMED := $(FASTQ_TRIMMED_R1) $(FASTQ_TRIMMED_R2)

# Processed Fastq 
FASTQ_DEDUP_R1 := $(FASTQ_TRIMMED_R1:%_trimmed.fq=%_dedup.fastq)
FASTQ_DEDUP_R2 := $(FASTQ_TRIMMED_R2:%_trimmed.fq=%_dedup.fastq)
FASTQ_DEDUP := $(FASTQ_DEDUP_R1) $(FASTQ_DEDUP_R2)
FASTQ_PAIRED_R1 := $(addsuffix .paired.fq, $(FASTQ_DEDUP_R1))
FASTQ_PAIRED_R2 := $(addsuffix .paired.fq, $(FASTQ_DEDUP_R2))
FASTQ_PAIRED := $(FASTQ_PAIRED_R1) $(FASTQ_PAIRED_R2)

# Quality Analysis 
FASTQC := $(FASTQ_PAIRED:%.paired.fq=%.paired_fastqc.html)
LENGTH_DISTRIBUTION := $(PROCESSED_FASTQ_FOLDER)/$(FASTQ_LANE_NAMES)/$(FASTQ_LANE_NAMES)_lengthDistribution.tsv

# Aligned Reads 
ALIGNED_READS_NO_EXT := $(addprefix $(ALIGNMENT_FOLDER), $(FASTQ_LANE_NAMES))
ALIGNED_READS_SAM := $(addsuffix .sam, $(ALIGNED_READS_NO_EXT))
ALIGNED_READS_BAM := $(ALIGNED_READS_SAM:sam=bam)
BED := $(ALIGNED_READS_SAM:sam=bed)
FEATURESCOUNTS := $(ALIGNED_READS_BAM:bam=fc.txt)
##############################################################

.PHONY: all clean reset make_directories variables
.INTERMEDIATE: $(FASTQ_TRIMMED) $(FASTQ_DEDUP) $(ALIGNED_READS_SAM)

all: make_directories $(FASTQ_PAIRED) quality_analysis $(ALIGNED_READS_BAM) $(FEATURESCOUNTS) clean

quality_analysis: $(FASTQC) $(LENGTH_DISTRIBUTION) 

variables: 
	@echo $(FASTQ_QUALITY_ANALYSIS)

# make necessary directories
make_directories:
	@mkdir -p $(PROCESSED_FASTQ_FOLDER)
	@mkdir -p $(ALIGNMENT_FOLDER)


################################################################################################################
#                                                                                                              #
#                                          PROCESSING OF RAW READS                                             #
#                                                                                                              #
################################################################################################################

# Step 1: remove adaptor_sequences using trim_galore  
.SECONDEXPANSION:
$(FASTQ_TRIMMED_R1): $(PROCESSED_FASTQ_FOLDER)/%_R1_001_trimmed.fq: $(RAW_DATA_FOLDER)/$$(dir %)/%_R1_001.fastq.gz $(RAW_DATA_FOLDER)/$$(dir %)/%_R2_001.fastq.gz
	trim_galore --paired --dont_gzip -j 4 --output_dir $(dir $@) $^
	mv $(PROCESSED_FASTQ_FOLDER)/$*_R1_001_val_1.fq $(PROCESSED_FASTQ_FOLDER)/$*_R1_001_trimmed.fq
	mv $(PROCESSED_FASTQ_FOLDER)/$*_R2_001_val_2.fq $(PROCESSED_FASTQ_FOLDER)/$*_R2_001_trimmed.fq

$(FASTQ_TRIMMED_R2): $(PROCESSED_FASTQ_FOLDER)/%_R2_001_trimmed.fq: $(RAW_DATA_FOLDER)/$$(dir %)/%_R1_001.fastq.gz $(RAW_DATA_FOLDER)/$$(dir %)/%_R2_001.fastq.gz
	trim_galore --paired --dont_gzip -j 4 --output_dir $(dir $@) $^
	mv $(PROCESSED_FASTQ_FOLDER)/$*_R1_001_val_1.fq $(PROCESSED_FASTQ_FOLDER)/$*_R1_001_trimmed.fq
	mv $(PROCESSED_FASTQ_FOLDER)/$*_R2_001_val_2.fq $(PROCESSED_FASTQ_FOLDER)/$*_R2_001_trimmed.fq

# Step 2: deduplicate using seqkit 
$(FASTQ_DEDUP): %_dedup.fastq: %_trimmed.fq
	seqkit rmdup -s -o $@ $<

# Step 3: re-pair reads with fastq_pair 
$(FASTQ_PAIRED_R1): %_R1_001_dedup.fastq.paired.fq: %_R1_001_dedup.fastq %_R2_001_dedup.fastq
	fastq_pair $^

$(FASTQ_PAIRED_R2): %_R2_001_dedup.fastq.paired.fq: %_R1_001_dedup.fastq %_R2_001_dedup.fastq
	fastq_pair $^


################################################################################################################
#                                                                                                              #
#                                      QUALITY ANALYSIS OF READS                                               #
#                                                                                                              #
################################################################################################################

# Assess "Degradation Ratio" (per PMID: 33992117) 
$(LENGTH_DISTRIBUTION): $(PROCESSED_FASTQ_FOLDER)/%_lengthDistribution.tsv: $(RAW_DATA_FOLDER)/$$(dir %)/%_R1_001.fastq.gz $(RAW_DATA_FOLDER)/$$(dir %)/%_R2_001.fastq.gz
	flash -d $(dir $@) $^ 
	@mv $(dir $@)/out.hist $@
	@rm $(dir $@)/out*

# Quality analysis on processed fastq files using fastqc 
$(FASTQC): %.paired_fastqc.html: %.paired.fq
	fastqc $< -o $(dir $@)

################################################################################################################
#                                                                                                              #
#                                   ALIGNMENT TO GENOME & READ SUMMARIZATION                                   #
#                                                                                                              #
################################################################################################################

# Step 1: Align reads to genome using bowtie with the following settings
#		- trim UMIs from 5' and 3' end 
#		- paired alignment, first fastq is forward and second fastq is reverse   
$(ALIGNED_READS_SAM): %.sam: $$(wildcard $(PROCESSED_FASTQ_FOLDER)/$$(notdir %)/*_dedup.fastq.paired.fq)
	bowtie -x $(BOWTIE_INDEX) --trim5 $(UMI_SIZE) --trim3 $(UMI_SIZE) --fr --best --allow-contain --sam --fullref --threads 4 -1 $(word 1, $^) -2 $(word 2, $^) $@

# Step 2: Convert sam to sorted bam files
$(ALIGNED_READS_BAM): %.bam: %.sam 
	samtools view -u $< | samtools sort -o $@

# Step 4: Assign to genomic features 
$(FEATURESCOUNTS): %.fc.txt: %.bam 
	featureCounts -p --countReadPairs -a $(HUMAN_GENOME_GTF) -t exon -g gene_id -o $@ $<

clean: 
	@rm -f $(FASTQ_TRIMMED)
	@rm -f $(FASTQ_DEDUP)

reset:
	rm -f $(FASTQ_TRIMMED)
	rm -f $(FASTQ_DEDUP)
	rm -f $(FASTQ_PAIRED)
	rm -f $(FASTQC) 