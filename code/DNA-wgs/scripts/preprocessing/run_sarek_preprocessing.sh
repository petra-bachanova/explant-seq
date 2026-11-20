#!/usr/bin/env bash
#SBATCH --job-name=sarek_preprocessing
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=72:00:00
#SBATCH --output=%x_%j.out
#SBATCH --mail-type=FAIL,END
#
# Usage: cd <run folder containing params.yaml>; sbatch /dartfs/.../scripts/preprocessing/run_sarek.sh
set -euo pipefail

source /dartfs/rc/lab/H/HongJ/Petra/explant-seq/code/DNA-wgs/config/project.env

export PATH="$HOME/.local/bin:$PATH"
set +u
eval "$(micromamba shell hook -s bash)"
micromamba activate "$ENV_NEXTFLOW"
set -u
export NXF_OPTS='-Xms512m -Xmx4g'
export NXF_ANSI_LOG=false

echo "=== $(date) | $(hostname) | $PWD ==="
echo "sarek -r $SAREK_VERSION"
nextflow -version | grep -i version || true
apptainer --version
cp "$CONFIG_DIR/cluster.config" "$CONFIG_DIR/project.env" .

nextflow run nf-core/sarek \
    -r "$SAREK_VERSION" \
    -profile apptainer \
    -c "$CONFIG_DIR/cluster.config" \
    -params-file params.yaml \
    -work-dir "$PWD/work" \
    -resume