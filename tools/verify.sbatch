#!/usr/bin/env bash
#SBATCH --job-name=jcs_verify
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=shared
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --array=1-10
#SBATCH --output=logs/%x_%A_%a.out
# Branch/integrity check of the rebinned Sherpa dataset, ONE class per array task.
set -euo pipefail
JCS_KIT="${JCS_KIT:?}"; cd "$JCS_KIT"
source "$JCS_KIT/env.sh"; jcs_activate
CLASSES=(HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep WToQQ ZToQQ ZJetsToNuNu)
C="${CLASSES[$((SLURM_ARRAY_TASK_ID-1))]}"
OUTROOT="${JCS_OUTROOT:-/pscratch/sd/s/sqian/part_datasets/JetClass/Sherpa}"
echo "== verify $C in $OUTROOT =="
root -l -b -q "tools/verify.C(\"$C\",\"$OUTROOT\")" 2>/dev/null | grep -a '^VERIFY' | tee "logs/verify_${C}.txt"
grep -q "FAIL" "logs/verify_${C}.txt" && { echo "VERIFY PROBLEMS for $C"; exit 1; } || echo "VERIFY OK for $C"
