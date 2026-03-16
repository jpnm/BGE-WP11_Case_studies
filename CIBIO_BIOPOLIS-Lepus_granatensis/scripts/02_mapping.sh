#!/usr/bin/env bash
set -euo pipefail

# 02_mapping.sh
# Map paired-end reads to the reference genome, sort/index BAM, and generate basic mapping stats.

source configs/config.sh

MAP_DIR="${RESULTS_DIR}/bam"
STATS_DIR="${RESULTS_DIR}/bam_stats"
LOG_DIR="${RESULTS_DIR}/logs"
mkdir -p "${MAP_DIR}" "${STATS_DIR}" "${LOG_DIR}"

# Optional config variables (safe defaults)
BWA=${BWA:-bwa-mem2}
SAMTOOLS=${SAMTOOLS:-samtools}
THREADS=${THREADS:-16}
REF=${REF_GENOME_MASKED:-${REF_GENOME}}   # prefer masked if set
PLATFORM=${PLATFORM:-ILLUMINA}
LIBRARY=${LIBRARY:-WGS}
CENTER=${CENTER:-BIOPOLIS-CIBIO}

if [[ ! -f "${REF}" ]]; then
  echo "[02_mapping] ERROR: Reference genome not found: ${REF}" >&2
  exit 1
fi

# Index reference if needed (bwa-mem2 uses .0123/.bwt.2bit etc; accept either style)
if [[ ! -f "${REF}.bwt.2bit.64" && ! -f "${REF}.0123" && ! -f "${REF}.bwt.2bit.32" ]]; then
  echo "[02_mapping] Reference appears unindexed. Indexing with ${BWA} index ..."
  "${BWA}" index "${REF}"
fi

echo "[02_mapping] Mapping using reference: ${REF}"
echo "[02_mapping] Output BAMs: ${MAP_DIR}"

while read -r SAMPLE POP STATUS R1 R2; do
  [[ -z "${SAMPLE}" ]] && continue
  [[ "${SAMPLE}" == "SampleID" ]] && continue

  if [[ ! -f "${R1}" || ! -f "${R2}" ]]; then
    echo "[02_mapping] ERROR: FASTQ missing for ${SAMPLE}" >&2
    echo "  R1=${R1}" >&2
    echo "  R2=${R2}" >&2
    exit 1
  fi

  OUT_BAM="${MAP_DIR}/${SAMPLE}.bam"
  OUT_LOG="${LOG_DIR}/${SAMPLE}.mapping.log"
  FLAGSTAT="${STATS_DIR}/${SAMPLE}.flagstat.txt"
  STATS="${STATS_DIR}/${SAMPLE}.stats.txt"

  # Skip if BAM exists and indexed
  if [[ -f "${OUT_BAM}" && -f "${OUT_BAM}.bai" ]]; then
    echo "[02_mapping] ${SAMPLE}: BAM exists, skipping."
    continue
  fi

  echo "[02_mapping] ${SAMPLE}: mapping..."
  # Read group (important for downstream merging and provenance)
  RG="@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:${PLATFORM}\tLB:${LIBRARY}\tCN:${CENTER}"

  # Map -> sort -> output BAM
  (
    set -x
    "${BWA}" mem -t "${THREADS}" -R "${RG}" "${REF}" "${R1}" "${R2}" \
      | "${SAMTOOLS}" sort -@ "${THREADS}" -o "${OUT_BAM}" -
    "${SAMTOOLS}" index "${OUT_BAM}"
    "${SAMTOOLS}" flagstat "${OUT_BAM}" > "${FLAGSTAT}"
    "${SAMTOOLS}" stats "${OUT_BAM}" > "${STATS}"
  ) &> "${OUT_LOG}"

done < configs/samples.tsv

echo "[02_mapping] Done."

