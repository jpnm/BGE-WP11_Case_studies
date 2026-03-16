#!/usr/bin/env bash
set -euo pipefail

# 03_angsd_gl.sh
# Compute genotype likelihoods and generate BEAGLE output for PCAngsd.
# Works well for low-coverage WGS.

source configs/config.sh

ANGSD=${ANGSD:-angsd}
SAMTOOLS=${SAMTOOLS:-samtools}
THREADS=${THREADS:-16}

OUTDIR="${RESULTS_DIR}/angsd"
LOG_DIR="${RESULTS_DIR}/logs"
mkdir -p "${OUTDIR}" "${LOG_DIR}"

REF="${REF_GENOME_MASKED:-${REF_GENOME}}"
if [[ ! -f "${REF}" ]]; then
  echo "[03_angsd_gl] ERROR: Reference genome not found: ${REF}" >&2
  exit 1
fi

# Build bamlist
BAMLIST="${OUTDIR}/bamlist.txt"
ls "${RESULTS_DIR}/bam/"*.bam > "${BAMLIST}" || true
if [[ ! -s "${BAMLIST}" ]]; then
  echo "[03_angsd_gl] ERROR: No BAMs found in ${RESULTS_DIR}/bam/" >&2
  exit 1
fi

PREFIX="${OUTDIR}/myxohares"
LOG="${LOG_DIR}/angsd_gl.log"

# Filters (tune if needed)
MIN_MAPQ=${MIN_MAPQ:-30}
MIN_BASEQ=${MIN_BASEQ:-20}
MIN_IND=${MIN_IND:-10}         # minimum number of individuals with data at a site
MIN_MAF=${MIN_MAF:-0.05}
SNP_PVAL=${SNP_PVAL:-1e-6}

echo "[03_angsd_gl] Running ANGSD genotype likelihood workflow..."
echo "[03_angsd_gl] BAMLIST: ${BAMLIST}"
echo "[03_angsd_gl] Output prefix: ${PREFIX}"

(
  set -x
  "${ANGSD}" \
    -bam "${BAMLIST}" \
    -ref "${REF}" \
    -out "${PREFIX}" \
    -GL 2 \
    -doMajorMinor 1 \
    -doMaf 2 \
    -doGlf 2 \
    -doCounts 1 \
    -SNP_pval "${SNP_PVAL}" \
    -minMapQ "${MIN_MAPQ}" \
    -minQ "${MIN_BASEQ}" \
    -minInd "${MIN_IND}" \
    -minMaf "${MIN_MAF}" \
    -uniqueOnly 1 \
    -remove_bads 1 \
    -only_proper_pairs 1 \
    -baq 1 \
    -nThreads "${THREADS}"
) &> "${LOG}"

# Expected key outputs:
# ${PREFIX}.beagle.gz (for PCAngsd)
# ${PREFIX}.mafs.gz, ${PREFIX}.arg, etc.
if [[ ! -f "${PREFIX}.beagle.gz" ]]; then
  echo "[03_angsd_gl] ERROR: Expected output not found: ${PREFIX}.beagle.gz" >&2
  exit 1
fi

echo "[03_angsd_gl] Done."
echo "Key output: ${PREFIX}.beagle.gz"

