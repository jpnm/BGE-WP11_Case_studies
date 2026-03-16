#!/usr/bin/env bash
set -euo pipefail

# 06_poolseq_popoolation2.sh
# Treat low-coverage individual data as pooled samples for allele-frequency based scans with PoPoolation2.
# Steps:
# 1) Create group BAM lists (resistant/susceptible)
# 2) mpileup per pool, convert to sync
# 3) Compute FST per window between pools

source configs/config.sh

SAMTOOLS=${SAMTOOLS:-samtools}
REF="${REF_GENOME_MASKED:-${REF_GENOME}}"
THREADS=${THREADS:-16}

POPOOL_JAR=${POPOOL_JAR:-/path/to/poPoolation2/mpileup2sync.jar}
POPOOL_FST_JAR=${POPOOL_FST_JAR:-/path/to/poPoolation2/fst-sliding.pl}

OUTDIR="${RESULTS_DIR}/popoolation2"
LOG_DIR="${RESULTS_DIR}/logs"
mkdir -p "${OUTDIR}" "${OUTDIR}/bamlists" "${OUTDIR}/mpileup" "${OUTDIR}/sync" "${OUTDIR}/fst" "${LOG_DIR}"

if [[ ! -f "${REF}" ]]; then
  echo "[06_poolseq] ERROR: Reference genome not found: ${REF}" >&2
  exit 1
fi
if [[ ! -f "${POPOOL_JAR}" ]]; then
  echo "[06_poolseq] ERROR: PoPoolation2 mpileup2sync.jar not found: ${POPOOL_JAR}" >&2
  exit 1
fi

# Build BAM lists by status
RES_BAMLIST="${OUTDIR}/bamlists/pool_resistant.bamlist"
SUS_BAMLIST="${OUTDIR}/bamlists/pool_susceptible.bamlist"
: > "${RES_BAMLIST}"
: > "${SUS_BAMLIST}"

while read -r SAMPLE POP STATUS R1 R2; do
  [[ -z "${SAMPLE}" ]] && continue
  [[ "${SAMPLE}" == "SampleID" ]] && continue

  BAM="${RESULTS_DIR}/bam/${SAMPLE}.bam"
  [[ -f "${BAM}" ]] || { echo "[06_poolseq] ERROR: Missing BAM: ${BAM}" >&2; exit 1; }

  STATUS_LC=$(echo "${STATUS}" | tr '[:upper:]' '[:lower:]')

  if [[ "${STATUS_LC}" == "resistant" ]]; then
    echo "${BAM}" >> "${RES_BAMLIST}"
  elif [[ "${STATUS_LC}" == "susceptible" ]]; then
    echo "${BAM}" >> "${SUS_BAMLIST}"
  fi
done < configs/samples.tsv

# mpileup settings
MIN_MAPQ=${MIN_MAPQ:-30}
MIN_BASEQ=${MIN_BASEQ:-20}

RES_MPI="${OUTDIR}/mpileup/pool_resistant.mpileup"
SUS_MPI="${OUTDIR}/mpileup/pool_susceptible.mpileup"

echo "[06_poolseq] Building mpileup for resistant pool..."
"${SAMTOOLS}" mpileup -B -q "${MIN_MAPQ}" -Q "${MIN_BASEQ}" -f "${REF}" -b "${RES_BAMLIST}" > "${RES_MPI}"

echo "[06_poolseq] Building mpileup for susceptible pool..."
"${SAMTOOLS}" mpileup -B -q "${MIN_MAPQ}" -Q "${MIN_BASEQ}" -f "${REF}" -b "${SUS_BAMLIST}" > "${SUS_MPI}"

# Convert to sync (one sync per pool)
RES_SYNC="${OUTDIR}/sync/pool_resistant.sync"
SUS_SYNC="${OUTDIR}/sync/pool_susceptible.sync"

echo "[06_poolseq] Converting mpileup -> sync..."
java -jar "${POPOOL_JAR}" --input "${RES_MPI}" --output "${RES_SYNC}" --fastq-type sanger --min-qual "${MIN_BASEQ}"
java -jar "${POPOOL_JAR}" --input "${SUS_MPI}" --output "${SUS_SYNC}" --fastq-type sanger --min-qual "${MIN_BASEQ}"

# Merge sync files into one multi-pop sync expected by PoPoolation2 fst scripts
# PoPoolation2 expects a single sync where each population is a column block.
# Easiest practical approach: paste population columns.
MERGED_SYNC="${OUTDIR}/sync/res_vs_sus.merged.sync"
echo "[06_poolseq] Merging sync files..."
paste "${RES_SYNC}" "${SUS_SYNC}" | \
  awk 'BEGIN{OFS="\t"}{print $1,$2,$3,$4,$5,$6,$7,$14}' > "${MERGED_SYNC}"

# Windowed FST
# NOTE: fst-sliding.pl expects populations indexed; here pop1=1 pop2=2
WIN=${POOL_WIN:-50000}
STEP=${POOL_STEP:-10000}
MIN_COUNT=${POOL_MIN_COUNT:-4}
MIN_COV=${POOL_MIN_COV:-10}
MAX_COV=${POOL_MAX_COV:-200}

echo "[06_poolseq] Computing sliding-window FST..."
perl "${POPOOL_FST_JAR}" \
  --input "${MERGED_SYNC}" \
  --output "${OUTDIR}/fst/res_vs_sus.fst" \
  --suppress-noninformative \
  --min-count "${MIN_COUNT}" \
  --min-coverage "${MIN_COV}" \
  --max-coverage "${MAX_COV}" \
  --window-size "${WIN}" \
  --step-size "${STEP}" \
  --pool-size 100 \
  --pop1 1 --pop2 2

echo "[06_poolseq] Done."
echo "Key outputs:"
echo "  ${OUTDIR}/fst/res_vs_sus.fst"

