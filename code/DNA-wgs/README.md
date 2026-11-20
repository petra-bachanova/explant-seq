# Explant-seq WGS pipeline
Whole-genome sequencing of SOZ and contralateral electrode with matched blood.
Analysis: preprocessing (alignment, QC), somatic variant calling (including SNPs, indels and copy number variants).

## Layout
config/        project.env (project-level settings), cluster.config, envs/ (environment exports)
docs_reports/  documentation and exported reports
metadata/      master_samples.csv and samplesheets/ (including samplesheet_for_testing.csv)
resources/     reference-derived files, one folder per reference (ensembl_grch38/, gatk_grch38/)
runs/          one folder per run
scripts/       setup/  preprocessing/  extra_qc/  analysis/

A run folder (`runs/<genome_ref>_<description>/`) holds `params.yaml`, `results/`, `work/`,
the job log, `.nextflow*`, and copies of `cluster.config` and `project.env` made at launch.

## Overall set up
P=/dartfs/rc/lab/H/HongJ/Petra/explant-seq/code/DNA-wgs
1. Save config/project.env (software versions, environment names, container caches)
2. Save config/cluster.config
3. Record the environments: `bash $P/scripts/setup/export_envs.sh` (writes `$P/config/envs/*.yml`)
4. Extra-QC resources (somalier sites, VerifyBamID2 files, GC bin tables): [TODO]
5. Create `metadata/master_samples.csv` [TODO]

## Setting up a new run
1. Create run folder
2. Add the sample sheet into `$P/metadata/samplesheets/`
3. Copy over `params.yaml` to the run folder and edit absolute paths: `input`, `outdir`, `fasta`.
2. Validate the sample sheet `bash $P/scripts/setup/validate_samplesheet.sh $P/metadata/samplesheets/<sheet>.csv`.
3. Run preprocessing **from the run folder**: `sbatch $P/scripts/preprocessing/run_sarek_preprocessing.sh`
4. Extra QC: [TODO once extra QC is set up]
5. Review and clean up. Check `results/multiqc/multiqc_report.html`; check results files (`ls -l results/preprocessing/markduplicates/*/`); then delete `work/` by hand.

## Data
- Raw FASTQs (low-pass): /dartfs-hpc/rc/lab/G/GSR_Active/Labs/Hong/260923_DNAseq/
- Reference: 
  - Ensembl GRCh38 primary assembly: /dartfs-hpc/rc/lab/G/GMBSR_bioinfo/genomic_references/reference_index_generation/Homo_sapiens.GRCh38.dna.primary_assembly.fa
  - GATK GRCh38: N/A
- Sample metadata: metadata/master_samples.csv

## Software
Nextflow 26.10.5, nf-core/sarek 3.11.0, Apptainer 1.5.4. Environments are in
envs/*.yml; sarek records its own tool versions in each run's pipeline_info.
Extra-QC tool versions: [TODO]

## Decisions
- Ensembl GRCh38 first (no alt contigs, no "chr" prefix); GATK reference later.
- NextSeq 2000 is a sequencer with patterned flow cells -> set optical-duplicate pixel distance 2500
- Base recalibration skipped at low-pass depth.
- Parameters come from a params file (Nextflow 26.x passes CLI values as strings).

## Conventions
- Absolute paths only, defined in config/project.env.
- Run folders: runs/<reference>_<description>/ with copies of params, config and versions.
- Sample sheets are validated before every run.
- Work directories are deleted manually, after checking that results are real files.

