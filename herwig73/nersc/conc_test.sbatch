#!/bin/bash
#SBATCH --job-name=hw_conc
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=debug
#SBATCH --nodes=1
#SBATCH --time=00:30:00
#SBATCH --output=logs/%x_%j.out
set -eo pipefail
KIT="${JCH_KIT:?}"; cd "$KIT"
ISO="${ISO:-1}"   # 1 = isolated HOME per sub-batch (the fix), 0 = shared HOME (reproduce bug)
mkdir -p "$KIT/.work"
echo "== concurrency test: 8 concurrent HToCC N=2000, ISO=$ISO =="
shifter --image=cmssw/el9:x86_64 --module=cvmfs -- bash -c '
  cd "'"$KIT"'"; export JCH_SCRATCH="'"$KIT"'/.work" JCH_MIN_FREE_MB=0
  pids=()
  for s in $(seq 7000001 7000008); do
    (
      if [ "'"$ISO"'" = "1" ]; then export HOME="'"$KIT"'/.work/home_$s"; mkdir -p "$HOME"; fi
      bash gen_class.sh HToCC 2000 $s "'"$KIT"'/.work/c_$s" >/dev/null 2>&1 \
        && echo "OK $s" || echo "FAIL $s"
      rm -rf "'"$KIT"'/.work/c_$s" "'"$KIT"'/.work/home_$s"
    ) &
    pids+=($!)
  done
  wait
'
echo "== results =="; ls data/HToCC/HToCC_70000{0}*.root 2>/dev/null | wc -l | xargs echo "  HToCC files 7000001-8:"
