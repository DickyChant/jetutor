#!/bin/bash
# run_all.sh — generate all 10 classes on ONE machine, auto-sized to TARGET jets/class.
# For a cluster, prefer slurm/submit.sh (one job per chunk). This is the single-box driver.
#
#   ./calibrate.sh                              # measure jets/event -> logs/cal_yield.txt (optional)
#   TARGET=10000 NPAR=3 ./run_all.sh            # generate
#   ONLY="ZToQQ HToBB" ./run_all.sh             # subset
#
# Disk: each class makes a transient HepMC (~190 KB/event). On a single box keep NPAR small and
# set JCH_MIN_FREE_MB so a class won't start showering unless scratch can hold another HepMC.
set -uo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export KIT_DIR
set +u; source "$KIT_DIR/env.sh"; set -u

TARGET=${TARGET:-10000}; MARGIN=${MARGIN:-1.20}; NPAR=${NPAR:-3}; SEED=${SEED:-1001}
export JCH_MIN_FREE_MB="${JCH_MIN_FREE_MB:-14000}"
# big (low-yield) classes first so the long poles start early
CLASSES="${ONLY:-TTBarLep HToWW2Q1L HToWW4Q HToBB HToGG HToCC ZJetsToNuNu ZToQQ WToQQ TTBar}"

declare -A FALLBACK=(
  [ZToQQ]=0.45 [WToQQ]=0.47 [HToBB]=0.38 [HToCC]=0.43 [HToGG]=0.44
  [HToWW4Q]=0.35 [HToWW2Q1L]=0.22 [TTBar]=0.45 [TTBarLep]=0.23 [ZJetsToNuNu]=0.50 )
rate_for() { local c="$1" nev nj
  if [ -f "$KIT_DIR/logs/cal_yield.txt" ]; then
    read -r nev nj < <(awk -v c="$c" '$1==c{print $2,$3}' "$KIT_DIR/logs/cal_yield.txt" | tail -1)
    if [ -n "${nj:-}" ] && [ "${nj:-0}" -gt 0 ] 2>/dev/null; then awk -v a="$nj" -v b="$nev" 'BEGIN{printf "%.4f",a/b}'; return; fi
  fi
  echo "${FALLBACK[$c]:-0.45}"; }
nevents_for() { local r; r=$(rate_for "$1"); awk -v t="$TARGET" -v r="$r" -v m="$MARGIN" 'BEGIN{n=t/r*m; printf "%d",(n<2000?2000:n)}'; }

mkdir -p "$KIT_DIR/logs"; touch "$KIT_DIR/logs/yield.txt"
echo "[run_all] TARGET=$TARGET NPAR=$NPAR JCH_MIN_FREE_MB=$JCH_MIN_FREE_MB"
for c in $CLASSES; do printf "   %-13s rate=%-7s nevents=%s\n" "$c" "$(rate_for "$c")" "$(nevents_for "$c")"; done

run_one() { local c="$1"; local n; n=$(nevents_for "$c")
  echo "[run_all] START $c nevents=$n"
  if bash "$KIT_DIR/gen_class.sh" "$c" "$n" "$SEED" > "$KIT_DIR/logs/${c}.log" 2>&1; then
    echo "[run_all] OK   $c -> $(tail -1 "$KIT_DIR/logs/${c}.log")"
  else echo "[run_all] FAIL $c (logs/${c}.log)"; tail -3 "$KIT_DIR/logs/${c}.log"; fi; }
export -f run_one nevents_for rate_for; export KIT_DIR TARGET MARGIN SEED JCH_MIN_FREE_MB
FB_SER="$(declare -p FALLBACK)"; export FB_SER

echo "$CLASSES" | tr ' ' '\n' | xargs -P "$NPAR" -I{} bash -c 'eval "$FB_SER"; run_one "$@"' _ {}
echo; bash "$KIT_DIR/tally.sh"
