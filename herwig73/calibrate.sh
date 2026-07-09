#!/bin/bash
# calibrate.sh — measure jets/event per class (so submit.sh / run_all.sh size chunks well).
# Writes logs/cal_yield.txt (CLASS NEVENTS JETS). Optional: defaults in submit.sh are fine too.
#   NCAL=1500 NPAR=3 ./calibrate.sh
set -uo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export KIT_DIR
set +u; source "$KIT_DIR/env.sh"; set -u
NCAL=${NCAL:-1500}; NPAR=${NPAR:-3}; SEED=7001
export JCH_MIN_FREE_MB="${JCH_MIN_FREE_MB:-14000}"
mkdir -p logs; : > "$KIT_DIR/logs/cal_yield.txt"
run1(){ local c="$1"
  if bash "$KIT_DIR/gen_class.sh" "$c" "$NCAL" "$SEED" >"$KIT_DIR/logs/cal_${c}.log" 2>&1; then
    nj=$(awk -v c="$c" '$1==c{print $4}' "$KIT_DIR/logs/yield.txt" | tail -1)
    echo "$c $NCAL ${nj:-0}" >> "$KIT_DIR/logs/cal_yield.txt"; echo "[cal] $c -> ${nj:-0}/$NCAL"
  else echo "[cal] $c FAILED"; fi; }
export -f run1; export KIT_DIR NCAL SEED JCH_MIN_FREE_MB
echo "ZToQQ WToQQ HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep ZJetsToNuNu" | tr ' ' '\n' | \
  xargs -P "$NPAR" -I{} bash -c 'run1 "$@"' _ {}
echo "=== cal_yield.txt ==="; cat "$KIT_DIR/logs/cal_yield.txt"
