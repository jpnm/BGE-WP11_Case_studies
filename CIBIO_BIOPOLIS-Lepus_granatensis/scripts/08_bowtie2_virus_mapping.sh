#!/usr/bin/env bash
set -euo pipefail

# 08_bowtie2_virus_mapping.sh
# Map WGS reads to Myxoma virus reference with Bowtie2 and generate per-sample mapping summaries.

source configs/config.sh

BOWTIE2=${BOWTIE2:-bowtie2}
SAMTOOLS=${SAMTOOLS:-samtools}
THREADS=${THREADS:-16}

OUTDIR="${RESULTS_DIR}/virus_mapping"
LOG_DIR="${RESULTS_DIR}/logs"
mkdir -p "${OUTDIR}/bam" "${OUTDIR}/stats" "${LOG_DIR}"

# Viral reference FASTA (downloaded by references/download_references.sh)
VIRUS_FASTA=${VIRUS_FASTA:-${PROJECT_DIR}/references/virus/myxoma_virus.fa}
if [[ ! -f "${VIRUS_FASTA}" ]]; then
  echo "[08_virus_map] ERROR: Viral FASTA not found: ${VIRUS_FASTA}" >&2
  exit 1
fi

# Bowtie2 index prefix
IDX_PREFIX="${PROJECT_DIR}/references/virus/myxoma_virus.idx"
if [[ ! -f "${IDX_PREFIX}.1.bt2" && ! -f "${IDX_PREFIX}.1.bt2l" ]]; then
  echo "[08_virus_map] Bowtie2 index not found. Building index..."
  bowtie2-build "${VIRUS_FASTA}" "${IDX_PREFIX}"
fi

while read -r SAMPLE POP STATUS R1 R2; do
  [[ -z "${SAMPLE}" ]] && continue
  [[ "${SAMPLE}" == "SampleID" ]] && continue

  [[ -f "${R1}" && -f "${R2}" ]] || { echo "[08_virus_map] ERROR: Missing FASTQs for ${SAMPLE}" >&2; exit 1; }

  BAM="${OUTDIR}/bam/${SAMPLE}.myxoma.bam"
  BAI="${BAM}.bai"
  FLAGSTAT="${OUTDIR}/stats/${SAMPLE}.myxoma.flagstat.txt"
  DEPTH="${OUTDIR}/stats/${SAMPLE}.myxoma.depth.tsv"
  LOG="${LOG_DIR}/${SAMPLE}.bowtie2_myxoma.log"

  if [[ -f "${BAM}" && -f "${BAI}" ]]; then
    echo "[08_virus_map] ${SAMPLE}: BAM exists, skipping."
    continue
  fi

  echo "[08_virus_map] ${SAMPLE}: mapping reads to Myxoma virus..."
  (
    set -x
    "${BOWTIE2}" \
      -x "${IDX_PREFIX}" \
      -1 "${R1}" -2 "${R2}" \
      -p "${THREADS}" \
      --very-sensitive \
    | "${SAMTOOLS}" sort -@ "${THREADS}" -o "${BAM}" -

    "${SAMTOOLS}" index "${BAM}"
    "${SAMTOOLS}" flagstat "${BAM}" > "${FLAGSTAT}"

    # Depth across viral genome (positions with coverage)
    "${SAMTOOLS}" depth -a "${BAM}" > "${DEPTH}"
  ) &> "${LOG}"

done < configs/samples.tsv

echo "[08_virus_map] Done."
