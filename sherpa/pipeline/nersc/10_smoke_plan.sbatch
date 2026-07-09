#!/usr/bin/env bash
#SBATCH --job-name=jcs_smoke
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x_%j.out
# Validation + planner (runs afterok:build). For each class, run a small SHERPA->Delphes(hqu
# card)->hqu-ntuplizer chain, confirm it produces matched jets WITHOUT the FatJetMatching
# throw aborting things, and MEASURE the per-class jet yield (jets_kept / event). Then size
# each class's production array to hit JCS_TARGET_JETS total kept jets and submit them.
# If any class yields 0 jets (integration broken), abort -> the 100M campaign never starts.
set -euo pipefail
KIT="${JCS_KIT:?}"
cd "$KIT"
source "$KIT/env.sh"
jcs_activate
# transient HepMC/Delphes ROOT on pscratch (disk), NOT /tmp (RAM-backed tmpfs -> OOM). See 20_generate.
export TMPDIR="$KIT/.work"; mkdir -p "$TMPDIR"

CLASSES=(HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep WToQQ ZToQQ ZJetsToNuNu)
SMOKE_N="${JCS_SMOKE_N:-2000}"          # events/class for the yield measurement
SMOKE_SEED=900001                        # high seed -> never collides with production seeds 1..NTASKS
TARGET_JETS="${JCS_TARGET_JETS:-100000000}"
NTASKS="${JCS_NTASKS:-400}"              # array tasks per class (10*400=4000 < 5000 submit cap)
MIN_PJ="${JCS_MIN_PER_JOB:-2000}"; MAX_PJ="${JCS_MAX_PER_JOB:-400000}"
PLAN="$KIT/pipeline/nersc/plan.txt"; : > "$PLAN"

echo "== smoke: $SMOKE_N events/class through the hqu chain (parallel) =="
mkdir -p "$KIT/logs/smoke"
run_one() { "$KIT/pipeline/one_job_hqu.sh" "$1" "$SMOKE_N" "$SMOKE_SEED" \
              > "$KIT/logs/smoke/$1.log" 2>&1 || echo "FAILED $1"; }
export -f run_one; export KIT SMOKE_N SMOKE_SEED
printf '%s\n' "${CLASSES[@]}" | xargs -P 10 -I{} bash -c 'run_one "$@"' _ {}

echo "== yields =="
target_per_class=$(( TARGET_JETS / ${#CLASSES[@]} ))
fail=0
for C in "${CLASSES[@]}"; do
  line="$(grep -h '^JCS_YIELD' "$KIT/logs/smoke/$C.log" 2>/dev/null | tail -1 || true)"
  ev="$(awk '{print $3}' <<<"$line")"; jets="$(awk '{print $4}' <<<"$line")"
  if [ -z "${jets:-}" ] || [ "${jets:-0}" -le 0 ]; then
    echo "  $C : NO JETS (smoke failed -- see logs/smoke/$C.log)"; fail=1; continue
  fi
  # per_job = ceil( (target_per_class * ev / jets) / NTASKS ), clamped
  pj=$(python -c "import math;print(max($MIN_PJ,min($MAX_PJ,math.ceil(($target_per_class*$ev/$jets)/$NTASKS))))")
  printf '%s %s %s %s\n' "$C" "$ev" "$jets" "$pj" | tee -a "$PLAN"
done
[ "$fail" = 0 ] || { echo "ABORT: a class produced no matched jets; not submitting the campaign."; exit 1; }

echo "== submit production arrays (shared QOS, $NTASKS tasks/class, seed=array index) =="
while read -r C ev jets pj; do
  # walltime ~ pj * 0.12 s/event + 30 min margin, capped at shared QOS max (2 days)
  secs=$(python -c "print(min(172800,int($pj*0.12)+1800))")
  hms=$(printf '%02d:%02d:%02d' $((secs/3600)) $(((secs%3600)/60)) $((secs%60)))
  echo "  $C : array 1-$NTASKS x $pj events  (walltime $hms)"
  JCS_KIT="$KIT" JCS_CLASS="$C" JCS_PER_JOB="$pj" \
    sbatch --array=1-"$NTASKS" --time="$hms" --job-name="jcs_$C" \
           "$KIT/pipeline/nersc/20_generate.sbatch"
done < "$PLAN"
echo "== campaign submitted: $(date) =="
