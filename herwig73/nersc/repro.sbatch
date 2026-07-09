#!/bin/bash
#SBATCH --job-name=hw_repro
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=debug
#SBATCH --nodes=1
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x_%j.out
# Reproduce the race on ONE node: NCONC concurrent HToCC sub-batches, ISO=0 shared HOME (race)
# or ISO=1 isolated HOME. Keep WORK of FAILED sub-batches. Small N so it's fast.
set -eo pipefail
KIT="${JCH_KIT:?}"; cd "$KIT"; NCONC="${NCONC:-40}"; N="${N:-3000}"; ISO="${ISO:-0}"
mkdir -p "$KIT/.work"
echo "== repro: $NCONC concurrent HToCC N=$N ISO=$ISO on $(hostname) =="
shifter --image=cmssw/el9:x86_64 --module=cvmfs -- bash -c '
  cd "'"$KIT"'"; export JCH_SCRATCH="'"$KIT"'/.work" JCH_MIN_FREE_MB=0 JCH_KEEP_INTERMEDIATE=1
  for i in $(seq 1 '"$NCONC"'); do
    ( s=$((4100000+i)); w="$JCH_SCRATCH/r_$s"; rm -rf "$w"
      if [ "'"$ISO"'" = 1 ]; then export HOME="$JCH_SCRATCH/h_$s"; mkdir -p "$HOME"; fi
      if bash gen_class.sh HToCC '"$N"' $s "$w" > "$w.log" 2>&1; then
        echo "OK $s"; rm -rf "$w" "$w.log"
      else echo "FAIL $s"; mv "$w.log" "$w/FAILLOG.txt" 2>/dev/null; fi ) &
  done; wait
'
echo "== done: $(grep -c "^OK" logs/hw_repro_${SLURM_JOB_ID}.out 2>/dev/null) OK / $(grep -c "^FAIL" logs/hw_repro_${SLURM_JOB_ID}.out 2>/dev/null) FAIL =="
