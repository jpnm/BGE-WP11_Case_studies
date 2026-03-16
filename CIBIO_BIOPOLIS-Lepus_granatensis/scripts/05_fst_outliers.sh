#!/usr/bin/env bash
set -euo pipefail

# 05_fst_outliers.sh
# Compute FST between "resistant" and "susceptible" groups using ANGSD + realSFS.
# Requires mapped BAMs and reference genome.
# Outputs: 2D SFS, fst index, windowed fst, and top outlier windows.

source configs/config.sh

OUTDIR="${RESULTS_DIR}/fst"
mkdir -p "${OUTDIR}" "${OUTDIR}/bamlists"

# Create bam lists from samples.tsv based on Status column
RES_BAMLIST="${OUTDIR}/bamlists/resistant.bamlist"
SUS_BAMLIST="${OUTDIR}/bamlists/susceptible.bamlist"

: > "${RES_BAMLIST}"
: > "${SUS_BAMLIST}"

while read -r SAMPLE POP STATUS R1 R2; do
  [[ -z "${SAMPLE}" ]] && continue
  [[ "${SAMPLE}" == "SampleID" ]] && continue

  BAM="${RESULTS_DIR}/bam/${SAMPLE}.bam"
  if [[ ! -f "${BAM}" ]]; then
    echo "[05_fst_outliers] ERROR: BAM not found for ${SAMPLE}: ${BAM}" >&2
    exit 1
  fi

  # Normalise status (allow resistant/susceptible or other spellings)
  STATUS_LC=$(echo "${STATUS}" | tr '[:upper:]' '[:lower:]')

  if [[ "${STATUS_LC}" == "resistant" ]]; then
    echo "${BAM}" >> "${RES_BAMLIST}"
  elif [[ "${STATUS_LC}" == "susceptible" ]]; then
    echo "${BAM}" >> "${SUS_BAMLIST}"
  fi
done < configs/samples.tsv

NRES=$(wc -l < "${RES_BAMLIST}" | tr -d ' ')
NSUS=$(wc -l < "${SUS_BAMLIST}" | tr -d ' ')
echo "[05_fst_outliers] Resistant BAMs: ${NRES}"
echo "[05_fst_outliers] Susceptible BAMs: ${NSUS}"

if [[ "${NRES}" -lt 2 || "${NSUS}" -lt 2 ]]; then
  echo "[05_fst_outliers] ERROR: Need at least 2 samples per group to compute FST robustly." >&2
  exit 1
fi

PREFIX="${OUTDIR}/res_vs_sus"

# SAF creation (site allele frequency likelihoods)
# You can adjust filters to match your ANGSD defaults.
echo "[05_fst_outliers] Computing SAF (resistant)"
${ANGSD} \
  -bam "${RES_BAMLIST}" \
  -ref "${REF_GENOME_MASKED}" \
  -out "${PREFIX}.res" \
  -GL 2 \
  -doSaf 1 \
  -anc "${REF_GENOME_MASKED}" \
  -minMapQ 30 \
  -minQ 20 \
  -uniqueOnly 1 \
  -remove_bads 1 \
  -only_proper_pairs 1 \
  -baq 1 \
  -minInd 2 \
  -nThreads "${THREADS}"

echo "[05_fst_outliers] Computing SAF (susceptible)"
${ANGSD} \
  -bam "${SUS_BAMLIST}" \
  -ref "${REF_GENOME_MASKED}" \
  -out "${PREFIX}.sus" \
  -GL 2 \
  -doSaf 1 \
  -anc "${REF_GENOME_MASKED}" \
  -minMapQ 30 \
  -minQ 20 \
  -uniqueOnly 1 \
  -remove_bads 1 \
  -only_proper_pairs 1 \
  -baq 1 \
  -minInd 2 \
  -nThreads "${THREADS}"

# 2D SFS estimation
echo "[05_fst_outliers] Estimating 2D-SFS"
realSFS "${PREFIX}.res.saf.idx" "${PREFIX}.sus.saf.idx" > "${PREFIX}.2dsfs"

# Prepare FST index
echo "[05_fst_outliers] Building FST index"
realSFS fst index \
  "${PREFIX}.res.saf.idx" "${PREFIX}.sus.saf.idx" \
  -sfs "${PREFIX}.2dsfs" \
  -fstout "${PREFIX}.fst" \
  -whichFst 1

# Windowed FST
# You can tune window/step sizes depending on your analysis
WIN=50000
STEP=10000

echo "[05_fst_outliers] Computing windowed FST (win=${WIN}, step=${STEP})"
realSFS fst stats2 "${PREFIX}.fst.fst.idx" \
  -win "${WIN}" -step "${STEP}" \
  > "${PREFIX}.window.fst.tsv"

# Extract top outlier windows (highest FST)
# Format of stats2 output: chrom  midPos  nSites  fst
# We'll keep top 1% by default (change TOPP if you want)
TOPP=1
echo "[05_fst_outliers] Extracting top ${TOPP}% windows by FST"
TOTAL=$(awk 'NF>=4 && $4!="nan"' "${PREFIX}.window.fst.tsv" | wc -l | tr -d ' ')
TOPN=$(( (TOTAL * TOPP + 99) / 100 ))  # ceil
awk 'NF>=4 && $4!="nan"' "${PREFIX}.window.fst.tsv" \
  | sort -k4,4gr \
  | head -n "${TOPN}" \
  > "${PREFIX}.outliers.top.tsv"

echo "[05_fst_outliers] Done."
echo "Outputs:"
echo "  2D-SFS: ${PREFIX}.2dsfs"
echo "  FST idx: ${PREFIX}.fst.fst.idx"
echo "  Windowed: ${PREFIX}.window.fst.tsv"
echo "  Outliers: ${PREFIX}.outliers.top.tsv"
