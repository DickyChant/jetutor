#!/usr/bin/env bash
# Submit the full Pythia-shower campaign(s). Usage:  ./submit_all.sh vincia [dire ...]
# Sizes each class's array from the measured reco yield (jets per 20000 events, from the Herwig
# kit's yield.txt — same MG+boost+Delphes, so shower-independent) to hit JCP_TARGET_JETS kept jets.
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
SHOWERS=("${@:-vincia}")
NSUB="${JCP_NSUB:-20000}"; NB="${JCP_NBATCHES:-10}"
TARGET="${JCP_TARGET_JETS:-13750000}"          # 12.5M + 10% margin per class
QOS="${JCP_QOS:-shared_overrun}"
JOB_EVENTS=$(( NSUB * NB ))
# jets per 20000 events per class (Herwig yield.txt medians)
declare -A Y=(
  [HToBB]=7140 [HToCC]=7140 [HToGG]=8600 [HToWW4Q]=7650 [HToWW2Q1L]=9700
  [TTBar]=9326 [TTBarLep]=4619 [WToQQ]=9200 [ZToQQ]=8600 [ZJetsToNuNu]=8500 )
echo "== Pythia campaign: showers='${SHOWERS[*]}'  $JOB_EVENTS evt/task  target $TARGET jets/class  qos=$QOS =="
grand=0
for SH in "${SHOWERS[@]}"; do
  [ -f "$KIT/cmnd/$SH.cmnd" ] || { echo "no cmnd for '$SH' -- skipping"; continue; }
  total=0
  for C in "${!Y[@]}"; do
    jets_per_task=$(( Y[$C] * JOB_EVENTS / 20000 ))
    tasks=$(python3 -c "import math;print(math.ceil($TARGET/$jets_per_task))")
    total=$(( total + tasks ))
    sbatch --array=1-"$tasks" --qos="$QOS" --job-name="jcp_${SH}_${C}" \
      --export="ALL,JCP_KIT=$KIT,JCP_CLASS=$C,JCP_SHOWER=$SH,JCP_NSUB=$NSUB,JCP_NBATCHES=$NB" \
      "${JCP_SBATCH:-$KIT/nersc/gen.sbatch}" >/dev/null
    printf "  %-7s %-12s %4d tasks x %d evt\n" "$SH" "$C" "$tasks" "$JOB_EVENTS"
  done
  echo "  -> $SH: $total tasks"
  grand=$(( grand + total ))
done
echo "== submitted $grand tasks across ${#SHOWERS[@]} shower(s) : $(date) =="
[ "$grand" -ge 5000 ] && echo "WARNING: $grand >= 5000 (shared submit cap) -- submit showers separately." || true
