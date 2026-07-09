#!/bin/bash
#SBATCH -A m2612
#SBATCH -C cpu
#SBATCH -q shared_overrun
#SBATCH -t 03:00:00
#SBATCH -n 1 -c 8
#SBATCH --image=cmssw/el9:x86_64
#SBATCH -J jcp_smoke
#SBATCH -o %x_%j.log
# Validation gate for the Pythia-shower editions: run a RESONANCE class (WToQQ, ZToQQ) through
# the full MG -> {simple,vincia,dire} -> Delphes -> ntuple chain at small N, so the W/Z mass peak
# tells us whether each shower is sane before launching the 125M campaigns.
set -euo pipefail
KIT=/pscratch/sd/s/sqian/jetclass_pythia_showers
export JCP_SCRATCH="${SCRATCH:-/pscratch/sd/s/sqian}/jcp_smoke_$SLURM_JOB_ID"
export JCP_OUT="$KIT/smoke_out"
N="${JCP_SMOKE_N:-4000}"
mkdir -p "$JCP_OUT"
for CLS in WToQQ ZToQQ; do
  for SH in simple vincia dire; do
    echo "===== $CLS / $SH ($(date +%T)) ====="
    bash "$KIT/gen_class_pythia.sh" "$CLS" "$N" 1 "$SH" || echo "FAILED: $CLS/$SH"
  done
done
echo "ALL SMOKE DONE $(date +%T)"
