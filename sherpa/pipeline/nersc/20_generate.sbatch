#!/usr/bin/env bash
#SBATCH --job-name=jcs_gen
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=shared
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --output=logs/%x_%A_%a.out
# One SLURM array task = one chunk of JCS_PER_JOB events through the EXACT JetClass chain
# (one_job_hqu.sh). seed = array index => every task is statistically independent.
# --time is set on the sbatch command line by the planner (sized from JCS_PER_JOB). shared
# QOS so single-core tasks pack onto nodes. Driven by 10_smoke_plan.sbatch.
set -euo pipefail
: "${JCS_KIT:?}" "${JCS_CLASS:?}"
# One long job = JCS_NBATCHES sub-batches of JCS_SUB_N events, each cleaned before the next
# (one_job_hqu.sh), so only one small transient is staged at a time. seed = array index.
export JCS_SUB_N="${JCS_SUB_N:-20000}"
export JCS_NBATCHES="${JCS_NBATCHES:-10}"
source "$JCS_KIT/env.sh"
jcs_activate
# transient HepMC3 + Delphes ROOT go on pscratch (Lustre, disk), NOT /tmp: Perlmutter compute
# /tmp is RAM-backed tmpfs (namespace/tmpfs), so a HepMC there counts against --mem and OOMs.
# one_job_hqu.sh mktemp's each sub-batch's WORK under TMPDIR and rm's it right after the batch.
export TMPDIR="$JCS_KIT/.work"; mkdir -p "$TMPDIR"
exec "$JCS_KIT/pipeline/one_job_hqu.sh" "$JCS_CLASS" "$JCS_SUB_N" "${SLURM_ARRAY_TASK_ID:-1}"
