#!/usr/bin/env bash
set -euo pipefail

# 07_kraken2_detection.sh
# Run Kraken2 classification to detect Myxoma virus and other co-infectants from WGS FASTQs.
# Produces per-sample Kraken report and (optional) classified/unclassified reads.

source configs/config.sh

KRAKEN2=${KRAKEN2:-kraken2}
THREADS=${THREADS:-16}

OUTDIR="${RESULTS_DIR}/kraken2"
LOG_DIR="${RESULTS_DIR}/logs"
mkdir -p "${OUTDIR}/reports" "${OUTDIR}/outputs" "${LOG_DIR}"

# You must set this in config.sh
KRAKEN_DB=${KRAKEN_DB:-}
if [[ -z "${KRAKEN_DB}" || ! -d "${KRAKEN_DB}" ]]; then
  echo "[07_kraken2] ERROR: KRAKEN_DB not set or not found. Set KRAKEN_DB in configs/config.sh" >&2
  exit 1
fi

# Optional: store reads (can be large)
STORE_READS=${STORE_KRAKEN_READS:-0}

while read -r SAMPLE POP STATUS R1 R2; do
  [[ -z "${SAMPLE}" ]] && continue
  [[ "${SAMPLE}" == "SampleID" ]] && continue

  [[ -f "${R1}" && -f "${R2}" ]] || { echo "[07_kraken2] ERROR: Missing FASTQs for ${SAMPLE}" >&2; exit 1; }

  REPORT="${OUTDIR}/reports/${SAMPLE}.kraken.report"
  OUT="${OUTDIR}/outputs/${SAMPLE}.kraken.out"
  LOG="${LOG_DIR}/${SAMPLE}.kraken2.log"

  if [[ -f "${REPORT}" ]]; then
    echo "[07_kraken2] ${SAMPLE}: report exists, skipping."
    continue
  fi

  echo "[07_kraken2] ${SAMPLE}: running Kraken2..."
  if [[ "${STORE_READS}" -eq 1 ]]; then
    CLASSIFIED="${OUTDIR}/outputs/${SAMPLE}.classified#.fastq"
    UNCLASSIFIED="${OUTDIR}/outputs/${SAMPLE}.unclassified#.fastq"
    (
      set -x
      "${KRAKEN2}" \
        --db "${KRAKEN_DB}" \
        --threads "${THREADS}" \
        --paired "${R1}" "${R2}" \
        --report "${REPORT}" \
        --output "${OUT}" \
        --classified-out "${CLASSIFIED}" \
        --unclassified-out "${UNCLASSIFIED}"
    ) &> "${LOG}"
  else
    (
      set -x
      "${KRAKEN2}" \
        --db "${KRAKEN_DB}" \
        --threads "${THREADS}" \
        --paired "${R1}" "${R2}" \
        --report "${REPORT}" \
        --output "${OUT}"
    ) &> "${LOG}"
  fi

done < configs/samples.tsv

echo "[07_kraken2] Done."

