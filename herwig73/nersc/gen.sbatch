#!/bin/bash
#SBATCH --job-name=hw_gen
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=shared
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%A_%a.out
# Herwig 7.3 JetClass generation, ONE class per array job, JCH_NBATCHES sub-batches of JCH_NSUB
# events each (MadGraph->Herwig->Delphes->ntuple per sub-batch, transient on pscratch cleaned
# between batches). Runs inside an el9 shifter container (cmssw/el9) with cvmfs. Resumable:
# sub-batches whose output already exists are skipped. seed = unique per (class,task,batch).
set -eo pipefail
KIT="${JCH_KIT:?}"; cd "$KIT"
IMG="${JCH_IMG:-cmssw/el9:x86_64}"
CLASS="${JCH_CLASS:?}"; NSUB="${JCH_NSUB:-20000}"; NB="${JCH_NBATCHES:-5}"; BASE="${JCH_SEED_BASE:-1000000}"
TASK="${SLURM_ARRAY_TASK_ID:-1}"
mkdir -p "$KIT/.work" "$KIT/data/$CLASS" "$KIT/logs"
echo "== $CLASS task=$TASK : $NB x $NSUB evt  img=$IMG  $(hostname) =="
shifter --image="$IMG" --module=cvmfs -- bash -c '
  cd "'"$KIT"'" || exit 1
  export JCH_SCRATCH="'"$KIT"'/.work" JCH_MIN_FREE_MB=0
  for k in $(seq 1 '"$NB"'); do
    seed=$(( '"$BASE"' + ('"$TASK"'-1)*'"$NB"' + k ))
    out="data/'"$CLASS"'/'"$CLASS"'_${seed}.root"
    if [ -s "$out" ]; then echo "[batch $k] skip seed $seed (exists)"; continue; fi
    w="$JCH_SCRATCH/g_'"$CLASS"'_${seed}"
    bash gen_class.sh "'"$CLASS"'" "'"$NSUB"'" "$seed" "$w" || echo "WARN batch $k seed $seed failed"
    rm -rf "$w"
  done
'
echo "== $CLASS task=$TASK done: $(ls data/$CLASS/ | wc -l) files in class dir =="
