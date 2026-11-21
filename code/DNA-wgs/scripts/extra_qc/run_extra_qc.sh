#!/usr/bin/env bash
#SBATCH --job-name=extra_qc
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=06:00:00
#SBATCH --output=/dev/null
#SBATCH --mail-type=FAIL
#
# Per-sample extra QC: binned depth, GC bias + insert size, somalier sketch, preseq, VerifyBamID2.
# Usage, from the preprocessing run folder (it must contain params.yaml and results/csv/):
#   N=$(( $(grep -c . results/csv/markduplicates_no_table.csv) - 1 ))
#   sbatch --array=1-$N%7 /dartfs/rc/lab/H/HongJ/Petra/explant-seq/code/DNA-wgs/scripts/extra_qc/run_extra_qc.sh
# Optional environment variables: RES_DIR (resources for this reference), QC_TMP (fast scratch for temporary BAMs)
set -euo pipefail

mkdir -p results/extra_qc/logs
exec > "results/extra_qc/logs/${SLURM_JOB_NAME}_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out" 2>&1

source /dartfs/rc/lab/H/HongJ/Petra/explant-seq/code/DNA-wgs/config/project.env
export PATH="$HOME/.local/bin:$PATH"
set +u
eval "$(micromamba shell hook -s bash)"
micromamba activate "$ENV_QC"
set -u

RES=${RES_DIR:-$PROJECT_ROOT/resources/ensembl_grch38}
SHEET=results/csv/markduplicates_no_table.csv
OUT=$PWD/results/extra_qc

get_param() { sed -n "s/^$1:[[:space:]]*//p" params.yaml | sed 's/[[:space:]]*#.*//' | tr -d "'\""; }
REF=$(get_param fasta)

# columns of sarek's CSV: patient,sex,status,sample,cram,crai
IFS=, read -r PATIENT SEX STATUS SAMPLE CRAM CRAI < <(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$SHEET" | tr -d '\r"') || true
echo "=== $(date) | $(hostname) | $SAMPLE | $CRAM ==="
micromamba list -n "$ENV_QC" | grep -E '^\s*(somalier|verifybamid2|preseq|mosdepth|picard|samtools|multiqc)\s' || true

[[ -s "$CRAM" ]]                         || { echo "ERROR: CRAM not found: '$CRAM'" >&2; exit 1; }
[[ -s "$REF.fai" ]]                      || { echo "ERROR: no index $REF.fai" >&2; exit 1; }
[[ -s "$RES/sites.hg38.nochr.vcf.gz" && -s "$RES/vb2.bed" ]] || { echo "ERROR: resources missing in $RES (run scripts/setup/prepare_qc_resources.sh)" >&2; exit 1; }
command -v Rscript >/dev/null            || { echo "ERROR: Rscript missing (needed for Picard charts)" >&2; exit 1; }

mkdir -p "$OUT"/{somalier,mosdepth,picard,preseq,verifybamid2}
T=${QC_TMP:-$OUT/tmp}/$SAMPLE
mkdir -p "$T"
trap 'rm -rf "$T"' EXIT                  # temporary BAM is deleted even if a step fails
BAM=$T/$SAMPLE.bam

echo "=== STEP 1: temporary BAM (duplicates kept; unmapped/secondary/supplementary removed) ==="
samtools view -@ 4 -b -T "$REF" -F 0x904 -o "$BAM" "$CRAM"
samtools index -@ 4 "$BAM"

echo "=== STEP 2: binned depth ==="
for W in 100000 500000; do
    P=$OUT/mosdepth/$SAMPLE.q20.w$W
    mosdepth -t 4 -n --fast-mode --by $W --mapq 20 "$P" "$BAM"
    python "$SCRIPTS_DIR/extra_qc/bin_qc.py" "$P.regions.bed.gz" "$SAMPLE" "$P"
    awk -F'\t' 'NR==2 && ($3+0) < 0.5 {print "ERROR: median depth ~0, mosdepth could not read the BAM" > "/dev/stderr"; exit 1}' "$P.bin_qc.tsv"
done

echo "=== STEP 3: Picard GC bias and insert size ==="
picard -Xmx6g CollectGcBiasMetrics -I "$BAM" -R "$REF" \
    -O "$OUT/picard/$SAMPLE.gc_bias.detail_metrics.txt" \
    -S "$OUT/picard/$SAMPLE.gc_bias.summary_metrics.txt" \
    -CHART "$OUT/picard/$SAMPLE.gc_bias.pdf" --TMP_DIR "$T"
picard -Xmx6g CollectInsertSizeMetrics -I "$BAM" -R "$REF" \
    -O "$OUT/picard/$SAMPLE.insert_size_metrics.txt" \
    -H "$OUT/picard/$SAMPLE.insert_size_histogram.pdf" --TMP_DIR "$T"

echo "=== STEP 4: somalier ==="
somalier extract -d "$OUT/somalier" --sites "$RES/sites.hg38.nochr.vcf.gz" -f "$REF" "$BAM"

echo "=== STEP 5: preseq ==="
preseq lc_extrap -B -P -e 1e9 -s 1e7 -o "$OUT/preseq/$SAMPLE.lc_extrap.txt" "$BAM" \
    || preseq lc_extrap -B -P -D -e 5e8 -s 1e7 -o "$OUT/preseq/$SAMPLE.lc_extrap.txt" "$BAM"

echo "=== STEP 6: VerifyBamID2 ==="
verifybamid2 --SVDPrefix "$RES/vb2" --Reference "$REF" --BamFile "$BAM" \
    --NumThread 4 --Output "$OUT/verifybamid2/$SAMPLE"

echo "=== ALL DONE ==="