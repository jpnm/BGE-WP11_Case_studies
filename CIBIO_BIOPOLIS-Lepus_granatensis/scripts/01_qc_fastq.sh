#!/usr/bin/env bash
set -euo pipefail

# 01_qc_fastq.sh
# Run fastp on paired-end FASTQs listed in configs/samples.tsv
# Outputs cleaned FASTQs + fastp HTML/JSON reports.

source configs/config.sh

FASTP=${FASTP:-fastp}

QC_DIR="${RESULTS_DIR}/qc_fastp"
mkdir -p "${QC_DIR}/clean" "${QC_DIR}/reports"

echo "[01_qc_fastq] Writing outputs to: ${QC_DIR}"

# Expect header or not; tolerate both
# Columns: SampleID Population Status R1 R2
tail -n +1 configs/samples.tsv | while read -r SAMPLE POP STATUS R1 R2; do
  # Skip empty lines and header
  [[ -z "${SAMPLE}" ]] && continue
  [[ "${SAMPLE}" == "SampleID" ]] && continue

  OUT1="${QC_DIR}/clean/${SAMPLE}_R1.clean.fastq.gz"
  OUT2="${QC_DIR}/clean/${SAMPLE}_R2.clean.fastq.gz"
  HTML="${QC_DIR}/reports/${SAMPLE}.fastp.html"
  JSON="${QC_DIR}/reports/${SAMPLE}.fastp.json"

  echo "[01_qc_fastq] ${SAMPLE}"

  "${FASTP}" \
    --in1 "${R1}" --in2 "${R2}" \
    --out1 "${OUT1}" --out2 "${OUT2}" \
    --thread "${THREADS}" \
    --length_required 50 \
    --detect_adapter_for_pe \
    --qualified_quality_phred 20 \
    --unqualified_percent_limit 40 \
    --n_base_limit 5 \
    --html "${HTML}" \
    --json "${JSON}"

done

echo "[01_qc_fastq] Done."
echo "If you want downstream scripts to use cleaned FASTQs, update configs/samples.tsv to point to:"
echo "  ${QC_DIR}/clean/*_R1.clean.fastq.gz and *_R2.clean.fastq.gz"
