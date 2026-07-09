#!/bin/bash
#SBATCH -A m2612
#SBATCH -C cpu
#SBATCH -q shared_overrun
#SBATCH -n 1 -c 2
#SBATCH --mem=8G
#SBATCH -t 12:00:00
#SBATCH --image=cmssw/el9:x86_64
#SBATCH -J jcp_gen
#SBATCH -o logs/%x_%A_%a.out
# JetClass Pythia-shower generation: ONE class+shower per array job, JCP_NBATCHES sub-batches of
# JCP_NSUB events. gen_class_pythia.sh self-shifters for MadGraph (el9+cvmfs) then showers in conda.
# seed = unique per (class,task,batch). Resumable: existing sub-batch outputs are skipped.
set -eo pipefail
KIT="${JCP_KIT:?}"; cd "$KIT"
CLASS="${JCP_CLASS:?}"; SHOWER="${JCP_SHOWER:?}"
NSUB="${JCP_NSUB:-20000}"; NB="${JCP_NBATCHES:-10}"; BASE="${JCP_SEED_BASE:-1000000}"
TASK="${SLURM_ARRAY_TASK_ID:-1}"
export JCP_SCRATCH="${SCRATCH:-/pscratch/sd/s/sqian}/jcp_work"
export JCP_OUT="$KIT/data_$SHOWER"
export JCP_MG_MARGIN="${JCP_MG_MARGIN:-1.05}"
mkdir -p logs "$JCP_OUT/$CLASS" "$JCP_SCRATCH"
echo "== $CLASS/$SHOWER task=$TASK : $NB x $NSUB evt  $(hostname) $(date) =="
for k in $(seq 1 "$NB"); do
  seed=$(( BASE + (TASK-1)*NB + k ))
  out="$JCP_OUT/$CLASS/${CLASS}_$(printf '%06d' "$seed").root"
  if [ -s "$out" ]; then echo "[batch $k] skip seed $seed (exists)"; continue; fi
  w="$JCP_SCRATCH/g_${SHOWER}_${CLASS}_${seed}"
  bash "$KIT/gen_class_pythia.sh" "$CLASS" "$NSUB" "$seed" "$SHOWER" "$w" || echo "WARN batch $k seed $seed failed"
  rm -rf "$w"
done
echo "== $CLASS/$SHOWER task=$TASK done: $(ls "$JCP_OUT/$CLASS"/ 2>/dev/null | wc -l) files =="
