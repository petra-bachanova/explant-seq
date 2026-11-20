#!/usr/bin/env bash
# Usage: validate_samplesheet.sh SHEET.csv
# Checks a sarek FASTQ sample sheet (patient,sample,lane,fastq_1,fastq_2).
# Exits 1 on errors; warnings do not fail.
# Changes it makes to the sheet: removing a byte-order mark (BOM), removing Windows line endings (CR),
# and adding a missing final newline.
set -o pipefail
sheet=${1:?Usage: validate_samplesheet.sh SHEET.csv}
errors=0
warns=0
err()  { echo "ERROR: $*" >&2; errors=$((errors + 1)); }
warn() { echo "WARN:  $*" >&2; warns=$((warns + 1)); }

[[ -s "$sheet" ]] || { echo "ERROR: $sheet is missing or empty" >&2; exit 1; }

# --- file-level checks ---
if [[ "$(head -c3 "$sheet" | od -An -tx1 | tr -d ' \n')" == "efbbbf" ]]; then
    if sed -i '1s/^\xEF\xBB\xBF//' "$sheet"; then
        echo "FIXED: removed byte-order mark (BOM) from the start of $sheet"
    else
        err "byte-order mark (BOM) found at the start of the file, and it could not be removed"
    fi
fi
if grep -q $'\r' "$sheet"; then
    if sed -i 's/\r$//' "$sheet"; then
        echo "FIXED: removed Windows line endings (CR) from $sheet"
    else
        err "Windows line endings (CR) found, and they could not be removed (check write permission)"
    fi
fi
grep -q '"'   "$sheet" && err "quote characters found"
grep -q $'\t' "$sheet" && err "tab characters found (file must be comma-separated)"
if [[ $(tail -c1 "$sheet" | wc -l) -eq 0 ]]; then
    if printf '\n' >> "$sheet"; then
        echo "FIXED: added missing newline at the end of $sheet"
    else
        err "no newline at the end of the file, and it could not be added (check write permission)"
    fi
fi
header=$(head -n1 "$sheet" | tr -d '\r')
[[ "$header" == "patient,sample,lane,fastq_1,fastq_2" ]] || err "header must be exactly: patient,sample,lane,fastq_1,fastq_2 (found, with hidden characters shown: $(printf '%s\n' "$header" | cat -A))"

# --- row-level checks ---
declare -A seen_key seen_sample seen_patient
n=0
line=1
while IFS=, read -r patient sample lane f1 f2 extra || [[ -n "${patient:-}" ]]; do
    line=$((line + 1))
    n=$((n + 1))
    if [[ -z "$patient" || -z "$sample" || -z "$lane" || -z "$f1" || -z "$f2" ]]; then
        err "line $line: empty field"; continue
    fi
    [[ -z "${extra:-}" ]] || err "line $line: more than 5 columns"
    key="$sample|$lane"
    [[ -z "${seen_key[$key]:-}" ]] || err "line $line: duplicate sample+lane ($sample, lane $lane)"
    seen_key[$key]=1; seen_sample[$sample]=1; seen_patient[$patient]=1
    for f in "$f1" "$f2"; do
        [[ "$f" == /* ]] || err "line $line: path is not absolute: $f"
        [[ -s "$f" ]]    || err "line $line: file not found or empty: $f"
        [[ "$f" == *.fastq.gz || "$f" == *.fq.gz ]] || warn "line $line: unusual FASTQ name: $f"
    done
    [[ "$f1" != "$f2" ]] || err "line $line: fastq_1 and fastq_2 are the same file"
    [[ "$sample" =~ ^EXP[0-9]{3}(re)?_[A-Z]+$ ]] || warn "line $line: sample name '$sample' does not look like EXPnnn_TISSUE (typo?)"
    [[ "$sample" == "${patient}_"* ]] || warn "line $line: sample '$sample' does not start with patient '$patient'"
done < <(tail -n +2 "$sheet" | tr -d '\r"')

echo "Checked $sheet: $n rows, ${#seen_sample[@]} samples, ${#seen_patient[@]} patients, $errors errors, $warns warnings"
[[ $errors -eq 0 ]]