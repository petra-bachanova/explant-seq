#!/usr/bin/env bash
# Records the exact package versions of each environment and the system tools.
set -euo pipefail
source /dartfs/rc/lab/H/HongJ/Petra/explant-seq/code/DNA-wgs/config/project.env
export PATH="$HOME/.local/bin:$PATH"

mkdir -p "$CONFIG_DIR/envs"
for e in nextflow wgs wgs_qc; do
    micromamba env export -n "$e" > "$CONFIG_DIR/envs/$e.yml"
done

{
    date
    echo "micromamba $(micromamba --version)"
    apptainer --version
    echo "kernel $(uname -r)"
} > "$CONFIG_DIR/envs/system_versions.txt"

ls -l "$CONFIG_DIR/envs"