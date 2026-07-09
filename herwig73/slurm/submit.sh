#!/bin/bash
# submit.sh — build tasks.txt (CLASS NEVENTS SEED per line) and submit a SLURM array.
# Each class is split into chunks of CHUNK events so jobs are small and parallel; the
# per-class ntuples are merged afterwards with merge.sh.
#
#   ./slurm/submit.sh                       # ~10k jets/class, 5000 evt/chunk
#   TARGET=100000 CHUNK=20000 ./slurm/submit.sh
#   ONLY="ZToQQ HToBB" ./slurm/submit.sh
#
set -euo pipefail
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; cd "$KIT_DIR"
TARGET=${TARGET:-10000}     # jets per class
MARGIN=${MARGIN:-1.20}
CHUNK=${CHUNK:-5000}        # events per array task
SEED0=${SEED0:-1000}
CLASSES="${ONLY:-ZToQQ WToQQ HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep ZJetsToNuNu}"

# jets/event (from logs/cal_yield.txt if present, else these defaults)
declare -A R=( [ZToQQ]=0.45 [WToQQ]=0.47 [HToBB]=0.38 [HToCC]=0.43 [HToGG]=0.44
               [HToWW4Q]=0.35 [HToWW2Q1L]=0.22 [TTBar]=0.45 [TTBarLep]=0.23 [ZJetsToNuNu]=0.50 )
rate() { local c=$1 nev nj
  if [ -f logs/cal_yield.txt ]; then read -r nev nj < <(awk -v c="$c" '$1==c{print $2,$3}' logs/cal_yield.txt|tail -1)
    [ "${nj:-0}" -gt 0 ] 2>/dev/null && { awk -v a="$nj" -v b="$nev" 'BEGIN{printf "%.4f",a/b}'; return; }; fi
  echo "${R[$c]:-0.45}"; }

mkdir -p logs data
: > tasks.txt; seed=$SEED0
for c in $CLASSES; do
  nev=$(awk -v t="$TARGET" -v r="$(rate "$c")" -v m="$MARGIN" 'BEGIN{printf "%d", t/r*m}')
  nchunks=$(( (nev + CHUNK - 1) / CHUNK ))
  for i in $(seq 1 "$nchunks"); do seed=$((seed+1)); echo "$c $CHUNK $seed" >> tasks.txt; done
  echo "  $c: ~$nev evt -> $nchunks chunks of $CHUNK"
done
N=$(wc -l < tasks.txt)
echo "total array tasks: $N  (tasks.txt)"
echo "submitting: sbatch --array=1-$N slurm/job.sbatch"
sbatch --array=1-"$N" slurm/job.sbatch
echo "after it finishes:  ./slurm/merge.sh"
