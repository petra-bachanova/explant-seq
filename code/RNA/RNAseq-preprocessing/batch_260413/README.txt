Date of run: 2026-04-13
Patients: EXP001, EXP002, EXP003, EXP005, EXP006, EXP007
Issues: 
- used reference_fa: "sample_ref/hg38_chr567_100k.fa", rather than the full genome fasta
- this resulted in a very low % of mapped reads
- created a new directory for a fresh run (batch_260601) with the correct fasta
- also used wrong name of sample EXP006_RTHB (instead of the correct EXP006_LTHB) - this was renamed to the correct version in the subsequent R analysis. In the 260601 run, I will correct this in sample.csv.