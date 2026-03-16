#!/usr/bin/env bash
set -euo pipefail

# 04_pca_angsd.sh
# Run PCAngsd on ANGSD BEAGLE genotype likelihood file.

source configs/config.sh

THREADS=${THREADS:-16}
OUTDIR="${RESULTS_DIR}/pca"
LOG_DIR="${RESULTS_DIR}/logs"
mkdir -p "${OUTDIR}" "${LOG_DIR}"

BEAGLE="${RESULTS_DIR}/angsd/myxohares.beagle.gz"
if [[ ! -f "${BEAGLE}" ]]; then
  echo "[04_pca_angsd] ERROR: BEAGLE file not found: ${BEAGLE}" >&2
  echo "Run scripts/03_angsd_gl.sh first." >&2
  exit 1
fi

PCANGSD=${PCANGSD:-pcangsd.py}
PREFIX="${OUTDIR}/myxohares"
LOG="${LOG_DIR}/pcangsd.log"

echo "[04_pca_angsd] Running PCAngsd..."
(
  set -x
  "${PCANGSD}" \
    -beagle "${BEAGLE}" \
    -o "${PREFIX}" \
    -threads "${THREADS}"
) &> "${LOG}"

# Outputs typically include:
# ${PREFIX}.cov, ${PREFIX}.eigenvec, ${PREFIX}.eigenval (depends on PCAngsd version)
echo "[04_pca_angsd] Done."
echo "Outputs written with prefix: ${PREFIX}"
echo "Tip: join eigenvectors with configs/samples.tsv for plotting by status/population."
