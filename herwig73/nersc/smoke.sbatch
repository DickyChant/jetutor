#!/bin/bash
#SBATCH --job-name=hw_smoke
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=debug
#SBATCH --nodes=1
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x_%j.out
# Herwig 7.3 JetClass smoke test on NERSC Perlmutter: ONE class, full chain, inside an el9
# shifter container with cvmfs (the LCG_109a el9 view: Herwig7.3 + MG5 + Delphes + ROOT).
# Transient (LHE/HepMC/Delphes ROOT) on pscratch, NOT /tmp (tmpfs->OOM).
# NOTE: do NOT `set -u` around the LCG setup.sh (unbound $COMPILER); gen_class.sh self-sources
# env.sh under its own `set +u` guard, so we invoke it directly without sourcing env.sh here.
set -eo pipefail
KIT="${JCH_KIT:?set JCH_KIT}"; cd "$KIT"
IMG="${JCH_IMG:-cmssw/el9:x86_64}"   # full el9 WN image (which/libGL/etc.); alma9-base is too minimal
CLASS="${JCH_CLASS:-ZToQQ}"; N="${JCH_N:-2000}"; SEED="${JCH_SEED:-700001}"
export JCH_SCRATCH="$KIT/.work"; mkdir -p "$JCH_SCRATCH"
echo "== host $(hostname)  img=$IMG  class=$CLASS N=$N seed=$SEED =="
shifter --image="$IMG" --module=cvmfs -- bash -c '
  cd "'"$KIT"'" || exit 1
  export JCH_SCRATCH="'"$KIT"'/.work" JCH_MIN_FREE_MB=0
  exec bash gen_class.sh "'"$CLASS"'" "'"$N"'" "'"$SEED"'" "$JCH_SCRATCH/smoke_'"$CLASS"'_'"$SEED"'"
'
OUT="$KIT/data/$CLASS/${CLASS}_${SEED}.root"
[ -s "$OUT" ] && echo "SMOKE OK: $OUT ($(du -h "$OUT"|cut -f1))" || { echo "SMOKE FAILED: no $OUT"; exit 1; }
