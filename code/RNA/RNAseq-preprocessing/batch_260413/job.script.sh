#!/bin/bash

#SBATCH --job-name=RNAseq.preprocess
#SBATCH --nodes=1
#SBATCH --cpus-per-task=5
#SBATCH --partition=standard
#SBATCH --time=60:00:00
#SBATCH --mail-user=petra.bachanova.gr@dartmouth.edu
#SBATCH --mail-type=END,FAIL
#SBATCH --output=RNAseq.preprocess_%j.out

#----- Source conda environment
source /optnfs/common/miniconda3/etc/profile.d/conda.sh
conda activate /dartfs/rc/nosnapshots/G/GMBSR_refs/envs/snakemake

#----- Make slurm logs folder
mkdir -p slurm_logs

#----- Call Snakemake
snakemake -s ../Snakefile  \
	--conda-frontend conda \
	--configfile config.yaml \
	--use-conda -j 6 \
	--profile ../cluster_profile \
	--rerun-incomplete \
	--keep-going
