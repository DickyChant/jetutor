#!/usr/bin/env bash
#SBATCH --job-name=jcs
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --time=08:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
# One SLURM array task = one chunk of JCS_PER_JOB events (seed = the array index, so
# every task is statistically independent). Driven by submit.sh, which exports
# JCS_KIT / JCS_CLASS / JCS_PER_JOB. Tune the #SBATCH lines to your cluster.
set -euo pipefail
: "${JCS_KIT:?}" "${JCS_CLASS:?}"
PER_JOB="${JCS_PER_JOB:-50000}"
source "$JCS_KIT/env.sh"
jcs_activate
exec "$JCS_KIT/pipeline/one_job.sh" "$JCS_CLASS" "$PER_JOB" "${SLURM_ARRAY_TASK_ID:-1}"
