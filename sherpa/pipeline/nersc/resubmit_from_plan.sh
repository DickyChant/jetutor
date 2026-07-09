#!/usr/bin/env bash
# Submit the production arrays from an existing pipeline/nersc/plan.txt (written by the smoke
# planner: "CLASS smoke_events jets per_job" per line), WITHOUT re-running the smoke measurement.
#
# Batched scheme: ONE array task = JCS_NBATCHES sub-batches of JCS_SUB_N events, cleaned between
# batches (see 20_generate.sbatch / one_job_hqu.sh). So job_events = SUB_N*NBATCHES and the
# number of tasks per class is sized from the measured yield to hit JCS_TARGET_JETS kept jets:
#     yield_c   = jets_c / smoke_events_c
#     tasks_c   = ceil( (target_per_class / yield_c) / job_events )
#
#   ./pipeline/nersc/resubmit_from_plan.sh
set -euo pipefail
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
PLAN="${JCS_PLAN:-$KIT/pipeline/nersc/plan.txt}"
QOS_ARG=""; [ -n "${JCS_QOS:-}" ] && QOS_ARG="--qos=$JCS_QOS"   # e.g. shared_overrun when out of node-hours
SUB_N="${JCS_SUB_N:-20000}"
NBATCHES="${JCS_NBATCHES:-10}"
TARGET_JETS="${JCS_TARGET_JETS:-100000000}"
NCLASS=10
[ -s "$PLAN" ] || { echo "no plan.txt at $PLAN -- run the smoke planner first"; exit 1; }

JOB_EVENTS=$(( SUB_N * NBATCHES ))
target_per_class=$(( TARGET_JETS / NCLASS ))
# uniform walltime: slowest class (boosted Higgs / ttbar) measured ~18-22 min per 20k-event
# sub-batch, so ~30 min/batch with margin; jobs are resumable so a timeout just re-runs the
# unfinished sub-batches. Override with JCS_WALLTIME=HH:MM:SS.
if [ -n "${JCS_WALLTIME:-}" ]; then HMS="$JCS_WALLTIME"; else
  secs=$(python3 -c "print(min(172800, $NBATCHES*1800+1800))")
  HMS=$(printf '%02d:%02d:%02d' $((secs/3600)) $(((secs%3600)/60)) $((secs%60)))
fi

echo "== batched campaign: SUB_N=$SUB_N x NBATCHES=$NBATCHES = $JOB_EVENTS events/task, walltime $HMS =="
total=0
while read -r C smoke_ev jets _; do
  [ -z "${C:-}" ] && continue
  [ "${jets:-0}" -gt 0 ] || { echo "  $C: zero yield in plan -- skipping"; continue; }
  # tasks = ceil( (target_per_class * smoke_ev / jets) / JOB_EVENTS )
  tasks=$(python3 -c "import math;print(math.ceil(($target_per_class*$smoke_ev/$jets)/$JOB_EVENTS))")
  total=$(( total + tasks ))
  echo "  $C : $tasks tasks x $JOB_EVENTS events  (yield $(python3 -c "print(round($jets/$smoke_ev,3))"))"
  JCS_KIT="$KIT" sbatch --array=1-"$tasks" --time="$HMS" --job-name="jcs_$C" $QOS_ARG \
    --export="ALL,JCS_KIT=$KIT,JCS_CLASS=$C,JCS_SUB_N=$SUB_N,JCS_NBATCHES=$NBATCHES" \
    "$KIT/pipeline/nersc/20_generate.sbatch"
done < "$PLAN"
echo "== submitted $total tasks total (cap: shared QOS 5000/user) : $(date) =="
[ "$total" -ge 5000 ] && echo "WARNING: $total >= 5000 -- exceeds the shared submit cap; raise SUB_N/NBATCHES."  || true
