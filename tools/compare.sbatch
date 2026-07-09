#!/usr/bin/env bash
#SBATCH --job-name=jcs_compare
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=shared
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:30:00
#SBATCH --array=1-10
#SBATCH --output=logs/%x_%A_%a.out
# SHERPA-vs-Pythia feature-distribution diagnosis, ONE class per array task.
# Writes tools/plots/compare_<CLASS>.png + .txt (KS distance + mean/rms ratios per feature).
set -euo pipefail
JCS_KIT="${JCS_KIT:?}"; cd "$JCS_KIT"
source "$JCS_KIT/env.sh"; jcs_activate
CLASSES=(HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep WToQQ ZToQQ ZJetsToNuNu)
C="${CLASSES[$((SLURM_ARRAY_TASK_ID-1))]}"
SHERPA="${JCS_SHERPA_DIR:-/pscratch/sd/s/sqian/part_datasets/JetClass/Sherpa}"
PYTHIA="${JCS_PYTHIA_DIR:-/pscratch/sd/s/sqian/part_datasets/JetClass/Pythia}"
CAP="${JCS_CAP:-500000}"
echo "== compare $C : SHERPA=$SHERPA vs PYTHIA=$PYTHIA (cap $CAP) =="
LABA="${JCS_LABA:-SHERPA}"; LABB="${JCS_LABB:-Pythia}"; PLOTS="${JCS_PLOTS:-tools/plots}"
root -l -b -q "tools/compare.C(\"$C\",\"$SHERPA\",\"$PYTHIA\",\"$PLOTS\",$CAP,\"$LABA\",\"$LABB\")" || true
[ -f "$PLOTS/compare_${C}.png" ] && echo "OK $C" || { echo "FAILED $C"; exit 1; }
