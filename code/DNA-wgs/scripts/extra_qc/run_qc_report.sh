#!/usr/bin/env bash
#SBATCH --job-name=qc_report
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=results/extra_qc/logs/%x_%j.out
#
# Cohort step: somalier comparison, depth-noise summary, sample renaming, combined MultiQC report.
# Run after run_extra_qc.sh has finished for ALL samples. From the same run folder:
#   sbatch /dartfs/rc/lab/H/HongJ/Petra/explant-seq/code/DNA-wgs/scripts/extra_qc/run_qc_report.sh
# or chained:  sbatch --dependency=afterok:<array job id> .../run_qc_report.sh
set -euo pipefail

source /dartfs/rc/lab/H/HongJ/Petra/explant-seq/code/DNA-wgs/config/project.env
export PATH="$HOME/.local/bin:$PATH"
set +u
eval "$(micromamba shell hook -s bash)"
micromamba activate "$ENV_QC"
set -u

OUT=$PWD/results/extra_qc
get_param() { sed -n "s/^$1:[[:space:]]*//p" params.yaml | sed 's/[[:space:]]*#.*//' | tr -d "'\""; }
FASTQ_SHEET=$(get_param input)     # the preprocessing sample sheet (has the lane numbers used in sarek's names)

# 1. identity / relatedness across all samples (low depth threshold because of ~3-5x data)
export SOMALIER_REPORT_ALL_PAIRS=1
somalier relate --min-depth 3 -o "$OUT/somalier/relate" "$OUT"/somalier/*.somalier

# 2. one table of depth-noise numbers
awk 'FNR==1 && NR!=1 {next} 1' "$OUT"/mosdepth/*.bin_qc.tsv > "$OUT/bin_qc_summary.tsv"

# 3. rename table: old name <TAB> new name (longest names first)
tail -n +2 "$FASTQ_SHEET" | tr -d '\r' | while IFS=, read -r patient sample lane _ || [[ -n "${patient:-}" ]]; do
    [[ -n "$sample" ]] || continue
    printf '%s-%s_1\t%s_R1\n' "$sample" "$lane" "$sample"      # FastQC, read 1
    printf '%s-%s_2\t%s_R2\n' "$sample" "$lane" "$sample"      # FastQC, read 2
    printf '%s-%s\t%s\n'      "$sample" "$lane" "$sample"      # fastp (sample + lane)
    printf '%s.md\t%s\n'      "$sample"         "$sample"      # samtools stats, sarek mosdepth
    printf '%s_%s\t%s\n'      "$patient" "$sample" "$sample"   # somalier (read-group name patient_sample)
    printf '%s.lc_extrap\t%s\n' "$sample"       "$sample"      # preseq
    for n in $(seq -f '%04g' 1 24); do                          # Picard MarkDuplicates (named after a chunk BAM)
        printf '%s.%s\t%s\n' "$sample" "$n" "$sample"
    done
done | sort -u | awk -F'\t' '{print length($1) "\t" $0}' | sort -t$'\t' -k1,1nr | cut -f2- > "$OUT/multiqc_rename.tsv"

# 4. put into one report
multiqc results/reports "$OUT/somalier" "$OUT/verifybamid2" "$OUT/picard" "$OUT/preseq" \
    --replace-names "$OUT/multiqc_rename.tsv" \
    --title "Low-pass QC: sarek + extra QC" \
    -o "$OUT/multiqc" --force

echo "Report: $OUT/multiqc/Low-pass-QC-sarek--extra-QC_multiqc_report.html"