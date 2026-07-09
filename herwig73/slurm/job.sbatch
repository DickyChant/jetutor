#!/bin/bash
#SBATCH --job-name=jclass-hw
#SBATCH --output=logs/slurm-%A_%a.out
#SBATCH --error=logs/slurm-%A_%a.out
#SBATCH --time=08:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#
# One array task = one chunk (CLASS NEVENTS SEED) read from tasks.txt by array index.
# Each task is fully independent and uses node-local scratch ($TMPDIR), so there is NO
# shared-disk / concurrency concern — the single-box disk-gate is irrelevant here.
#
# Submitted by submit.sh; do not run directly. Output: data/<CLASS>/<CLASS>_<SEED>.root
set -euo pipefail
KIT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$KIT_DIR"
source env.sh

TASK_FILE="${TASK_FILE:-tasks.txt}"
line=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$TASK_FILE")
read -r CLASS NEVENTS SEED <<< "$line"
echo "[task ${SLURM_ARRAY_TASK_ID}] $CLASS $NEVENTS evt seed $SEED on $(hostname)"

# node-local scratch; no disk gate needed (JCH_MIN_FREE_MB=0)
export JCH_MIN_FREE_MB=0
WORK="${TMPDIR:-/tmp}/jch_${CLASS}_${SEED}"
bash gen_class.sh "$CLASS" "$NEVENTS" "$SEED" "$WORK"
rm -rf "$WORK"
