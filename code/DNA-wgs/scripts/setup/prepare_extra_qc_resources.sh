#!/usr/bin/env bash
# One-off: reference-specific files for the extra QC (somalier sites, VerifyBamID2 markers), Ensembl-style contig names.
# Usage: bash prepare_qc_resources.sh [RESOURCE_DIR]    (default: resources/ensembl_grch38 in the project)
set -euo pipefail
source /dartfs/rc/lab/H/HongJ/Petra/explant-seq/code/DNA-wgs/config/project.env
export PATH="$HOME/.local/bin:$PATH"
set +u
eval "$(micromamba shell hook -s bash)"
micromamba activate "$ENV_QC"
set -u

RES=${1:-$PROJECT_ROOT/resources/ensembl_grch38}
mkdir -p "$RES"

# --- somalier sites file with Ensembl-style names (no 'chr') ---
if [[ ! -s "$RES/sites.hg38.nochr.vcf.gz" ]]; then
    wget -q -O "$RES/sites.hg38.vcf.gz" https://github.com/brentp/somalier/files/3412456/sites.hg38.vcf.gz \
        || { echo "Download failed: get the sites file from https://github.com/brentp/somalier/releases and put it in $RES" >&2; exit 1; }
    for c in {1..22} X Y; do printf 'chr%s\t%s\n' "$c" "$c"; done > "$RES/chr2ens.txt"
    bcftools annotate --rename-chrs "$RES/chr2ens.txt" -Oz -o "$RES/sites.hg38.nochr.vcf.gz" "$RES/sites.hg38.vcf.gz"
fi
echo "Sites contigs:"; bcftools query -f '%CHROM\n' "$RES/sites.hg38.nochr.vcf.gz" | sort -u | tr '\n' ' '; echo

# --- VerifyBamID2 resource: copy the bundled files, strip 'chr' from the marker files ---
BED=$(find "$CONDA_PREFIX" -name '1000g.phase3.100k.b38.vcf.gz.dat.bed' | head -1)
[[ -n "$BED" ]] || { echo "VerifyBamID2 resource not found in the environment" >&2; exit 1; }
SRC=${BED%.bed}
for ext in UD V; do cp "$SRC.$ext" "$RES/vb2.$ext"; done
for ext in bed mu; do sed 's/^chr//' "$SRC.$ext" > "$RES/vb2.$ext"; done
head -3 "$RES/vb2.bed"