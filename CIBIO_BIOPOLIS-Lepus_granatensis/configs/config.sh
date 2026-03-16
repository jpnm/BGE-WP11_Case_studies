
---

# 3️⃣ `configs/config.sh`

```bash
#!/usr/bin/env bash

# Paths
PROJECT_DIR=/path/to/myxohares
RAW_DATA_DIR=/path/to/fastq
RESULTS_DIR=${PROJECT_DIR}/results

# Reference genome
REF_GENOME=${PROJECT_DIR}/references/mLepGra1.hap1.cur.20240830.fa.gz
REF_GENOME_MASKED=${PROJECT_DIR}/references/mLepGra1.hap1.cur.20240830.masked.fa.gz

# Threads
THREADS=16

# Tools
BWA=bwa-mem2
SAMTOOLS=samtools
ANGSD=angsd
KRAKEN2=kraken2
BOWTIE2=bowtie2
