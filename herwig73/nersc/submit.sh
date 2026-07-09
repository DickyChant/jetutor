#!/bin/bash
# submit.sh -- size & submit the Herwig 7.3 JetClass campaign on NERSC (el9 container).
# One array task = JCH_NBATCHES x JCH_NSUB events; tasks/class sized from yield to hit
# JCH_TARGET_PER_CLASS kept jets (default 13M, i.e. >=12.5M for the exact-100k repack + margin).
#   ./nersc/submit.sh
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$KIT"
NSUB="${JCH_NSUB:-20000}"; NB="${JCH_NBATCHES:-5}"; JOB_EV=$((NSUB*NB))
TARGET="${JCH_TARGET_PER_CLASS:-13000000}"; MARGIN="${JCH_MARGIN:-1.15}"
SEED_BASE="${JCH_SEED_BASE:-1000000}"; WALL="${JCH_WALLTIME:-08:00:00}"
CLASSES="${ONLY:-ZToQQ WToQQ HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep ZJetsToNuNu}"
# yields jets/event (kit calibration defaults; ZToQQ smoke gave 0.43)
declare -A R=( [ZToQQ]=0.45 [WToQQ]=0.47 [HToBB]=0.38 [HToCC]=0.43 [HToGG]=0.44
               [HToWW4Q]=0.35 [HToWW2Q1L]=0.22 [TTBar]=0.45 [TTBarLep]=0.23 [ZJetsToNuNu]=0.50 )
mkdir -p logs data
echo "== Herwig73 campaign: $NB x $NSUB = $JOB_EV evt/task, target>=$TARGET jets/class, walltime $WALL =="
tot=0
for C in $CLASSES; do
  y="${R[$C]:-0.4}"
  tasks=$(python3 -c "import math;print(math.ceil(($TARGET/$y*$MARGIN)/$JOB_EV))")
  tot=$((tot+tasks))
  echo "  $C: yield=$y -> $tasks tasks ($((tasks*JOB_EV/1000000))M evt)"
  JCH_KIT="$KIT" sbatch --array=1-"$tasks" --time="$WALL" --job-name="hw_$C" \
    --export="ALL,JCH_KIT=$KIT,JCH_CLASS=$C,JCH_NSUB=$NSUB,JCH_NBATCHES=$NB,JCH_SEED_BASE=$SEED_BASE" \
    "$KIT/nersc/gen.sbatch" >/dev/null
done
echo "== submitted $tot tasks total ($((tot*JOB_EV/1000000))M events) : $(date) =="
[ "$tot" -ge 5000 ] && echo "WARNING: $tot >= 5000 shared submit cap -- raise JCH_NSUB/NBATCHES or use ONLY= in waves." || true
