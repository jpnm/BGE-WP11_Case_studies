# BGE-MyxoHares-case-study

# MyxoHares – Genomic analysis pipelines

This repository contains reproducible **bash-based analysis pipelines**
used in the BGE *MyxoHares* case study to analyse whole-genome sequencing
data from Iberian hares (*Lepus granatensis*) and to detect *Myxoma virus*
and other co-infectants directly from host WGS libraries.

## Scope

The pipelines reproduce the following analytical steps:

- Read QC and filtering  
- Mapping to the *Lepus granatensis* reference genome  
- Low-coverage genotype likelihood estimation with ANGSD  
- Population structure analysis (PCA via PCAngsd)  
- Genome-wide differentiation and FST outlier scans  
- PoolSeq-style allele frequency analyses with PoPoolation2  
- Detection of *Myxoma virus* and other co-infectants (Kraken2 + Bowtie2)

## Data availability

### Raw sequencing data (controlled access)
Raw FASTQ files are publicly archived at ENA under:
https://www.ebi.ac.uk/ena/browser/view/PRJEB105583

Precise geographic metadata are available through COPO:
Manifest ID: `9920bfa5-1abc-4b2a-8162-76ab372819b0`

### Reference genome
The *Lepus granatensis* reference genome is not yet formally released,
but is available for review at:

- Unmasked:  
  https://ln5.sync.com/dl/bfe858d00/mLepGra1.hap1.cur.20240830.fa.gz
- Masked:  
  https://ln5.sync.com/dl/bfe858d00/mLepGra1.hap1.cur.20240830.masked.fa.gz

### Viral references
Viral reference genomes (including *Myxoma virus*) are downloaded from NCBI.

## Requirements

- bash
- bwa-mem2
- samtools
- fastp
- ANGSD
- PCAngsd
- PoPoolation2
- Kraken2
- Bowtie2
- R (for plotting)

Exact versions used are documented in the scripts.

## How to run

1. Edit `configs/config.sh` to define paths.
2. Populate `configs/samples.tsv`.
3. Run scripts sequentially from `scripts/`.

Example:
```bash
bash scripts/02_mapping.sh
