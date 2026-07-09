#!/bin/bash
# merge.sh — hadd the per-chunk ntuples into one file per class, then print the yield.
#   ./slurm/merge.sh
set -uo pipefail
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; cd "$KIT_DIR"
set +u; source env.sh; set -u
for d in data/*/; do
  c=$(basename "$d")
  files=$(ls "$d"/${c}_*.root 2>/dev/null | grep -v "/${c}_merged.root" || true)
  [ -z "$files" ] && continue
  echo ">>> merging $c ($(echo "$files" | wc -w) chunks)"
  hadd -f "$d/${c}_merged.root" $files > "logs/merge_${c}.log" 2>&1 && echo "   -> $d/${c}_merged.root"
done
echo; bash tally.sh
