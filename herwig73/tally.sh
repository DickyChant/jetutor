#!/bin/bash
# tally.sh — count FatJet entries per class. Uses <CLASS>_merged.root if present, else
# sums all chunk files <CLASS>_*.root.
set -uo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v root >/dev/null 2>&1 || { set +u; source "$KIT_DIR/env.sh"; set -u; }
count() { root -l -b -q -e "TFile f(\"$1\");TTree*t=(TTree*)f.Get(\"tree\");printf(\"%lld\",t?t->GetEntries():0);" 2>/dev/null | tail -1; }
echo "==================== JETCLASS-HERWIG YIELD ===================="
printf "%-14s %10s\n" CLASS JETS; total=0
for c in ZJetsToNuNu HToBB HToCC HToGG HToWW4Q HToWW2Q1L ZToQQ WToQQ TTBar TTBarLep; do
  n=0
  if [ -e "$KIT_DIR/data/$c/${c}_merged.root" ]; then
    n=$(count "$KIT_DIR/data/$c/${c}_merged.root")
  else
    for f in "$KIT_DIR"/data/"$c"/"$c"_*.root; do [ -e "$f" ] || continue; e=$(count "$f"); n=$((n + ${e:-0})); done
  fi
  printf "%-14s %10s\n" "$c" "${n:-0}"; total=$((total + ${n:-0}))
done
echo "--------------------------------------------------------------"
printf "%-14s %10s\n" TOTAL "$total"
