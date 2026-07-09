#!/bin/bash
#SBATCH --job-name=hwdbg
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=shared
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%A_%a.out
# DEBUG variant of gen.sbatch: KEEPS the per-sub-batch WORK dir (herwig_read.log / herwig_run.log
# / mg logs) whenever a sub-batch FAILS, so we can inspect why Herwig stage 3 dies under
# concurrency. Successful sub-batches' WORK is cleaned. Writes to data/<CLASS>/ like production.
# ISO=1 also gives each sub-batch an isolated $HOME (test the home-contention hypothesis).
set -eo pipefail
KIT="${JCH_KIT:?}"; cd "$KIT"
IMG="${JCH_IMG:-cmssw/el9:x86_64}"
CLASS="${JCH_CLASS:?}"; NSUB="${JCH_NSUB:-20000}"; NB="${JCH_NBATCHES:-5}"; BASE="${JCH_SEED_BASE:-3000000}"
ISO="${ISO:-0}"; TASK="${SLURM_ARRAY_TASK_ID:-1}"
mkdir -p "$KIT/.work" "$KIT/data/$CLASS" "$KIT/logs/dbgwork"
echo "== DBG $CLASS task=$TASK : $NB x $NSUB evt  ISO=$ISO  $(hostname) =="
shifter --image="$IMG" --module=cvmfs -- bash -c '
  cd "'"$KIT"'"; export JCH_SCRATCH="'"$KIT"'/.work" JCH_MIN_FREE_MB=0 JCH_KEEP_INTERMEDIATE=1
  for k in $(seq 1 '"$NB"'); do
    seed=$(( '"$BASE"' + ('"$TASK"'-1)*'"$NB"' + k ))
    out="data/'"$CLASS"'/'"$CLASS"'_${seed}.root"
    [ -s "$out" ] && { echo "[b$k] skip $seed"; continue; }
    w="$JCH_SCRATCH/dbg_'"$CLASS"'_${seed}"; rm -rf "$w"
    if [ "'"$ISO"'" = "1" ]; then export HOME="$JCH_SCRATCH/home_${seed}"; mkdir -p "$HOME"; fi
    if bash gen_class.sh "'"$CLASS"'" "'"$NSUB"'" "$seed" "$w" > "$w.genlog" 2>&1; then
      echo "[b$k] OK $seed"; rm -rf "$w" "$w.genlog" "$JCH_SCRATCH/home_${seed}"
    else
      echo "[b$k] FAIL $seed -> kept $w"; mv "$w.genlog" "$w/genlog.txt" 2>/dev/null || true
    fi
  done
'
echo "== DBG $CLASS task=$TASK done =="
