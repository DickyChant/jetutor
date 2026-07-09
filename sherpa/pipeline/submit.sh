#!/usr/bin/env bash
# Submit SLURM array jobs to produce ~100M events (10 classes x PER_CLASS).
# Tune PER_CLASS / PER_JOB to your cluster's walltime, then:  ./pipeline/submit.sh
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
CLASSES=(HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep WToQQ ZToQQ ZJetsToNuNu)
PER_CLASS="${PER_CLASS:-10000000}"     # 10M each -> 100M total
PER_JOB="${PER_JOB:-50000}"            # events per array task
mkdir -p "$KIT/logs"
for C in "${CLASSES[@]}"; do
  NJOBS=$(( (PER_CLASS + PER_JOB - 1) / PER_JOB ))
  echo "submit $C : $NJOBS tasks x $PER_JOB events"
  JCS_KIT="$KIT" JCS_CLASS="$C" JCS_PER_JOB="$PER_JOB" \
    sbatch --array=1-"$NJOBS" --job-name="jcs_$C" "$KIT/pipeline/job.sbatch"
done
echo "submitted. outputs -> $KIT/data/<CLASS>/<CLASS>_<seed>.root"
