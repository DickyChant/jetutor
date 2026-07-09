#!/usr/bin/env bash
# Submit the whole gated chain on NERSC Perlmutter (account m2612):
#
#   build  --afterok-->  smoke+plan  --(plan submits)-->  100M production arrays
#
# Everything is submitted now; SLURM enforces order. The 100M arrays are submitted BY the
# smoke job only if every class validates (matched jets, no FatJetMatching abort), so a broken
# build or a broken hqu-ntuplizer integration cancels the campaign instead of wasting nodes.
#
#   ./pipeline/nersc/submit_all.sh
# Tunables (env): JCS_TARGET_JETS (1e8), JCS_NTASKS (400/class), JCS_SMOKE_N (2000),
#                 JCS_MIN_PER_JOB / JCS_MAX_PER_JOB.
set -euo pipefail
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$KIT/logs"
cd "$KIT"

EXP="JCS_KIT=$KIT"
[ -n "${JCS_TARGET_JETS:-}" ] && EXP="$EXP,JCS_TARGET_JETS=$JCS_TARGET_JETS"
[ -n "${JCS_NTASKS:-}" ]      && EXP="$EXP,JCS_NTASKS=$JCS_NTASKS"
[ -n "${JCS_SMOKE_N:-}" ]     && EXP="$EXP,JCS_SMOKE_N=$JCS_SMOKE_N"
[ -n "${JCS_MIN_PER_JOB:-}" ] && EXP="$EXP,JCS_MIN_PER_JOB=$JCS_MIN_PER_JOB"
[ -n "${JCS_MAX_PER_JOB:-}" ] && EXP="$EXP,JCS_MAX_PER_JOB=$JCS_MAX_PER_JOB"

echo "== [1/2] submit build =="
BUILD_ID=$(sbatch --parsable --export="ALL,$EXP" "$KIT/pipeline/nersc/00_build.sbatch")
echo "   build job: $BUILD_ID"

echo "== [2/2] submit smoke+plan (afterok:$BUILD_ID) -- it submits the 100M arrays on success =="
SMOKE_ID=$(sbatch --parsable --dependency=afterok:"$BUILD_ID" \
                  --export="ALL,$EXP" "$KIT/pipeline/nersc/10_smoke_plan.sbatch")
echo "   smoke job: $SMOKE_ID"

cat <<EOF

Chain submitted:
  build   $BUILD_ID   (openloops + sherpa3 + jcs env + PDF + both ntuplizers)
  smoke   $SMOKE_ID   (afterok:$BUILD_ID; validates hqu chain, sizes & submits 100M arrays)

Watch:   squeue --me
Logs:    $KIT/logs/   (build: jcs_build_*.out  smoke: jcs_smoke_*.out + logs/smoke/<CLASS>.log)
Plan:    $KIT/pipeline/nersc/plan.txt  (written by the smoke job: CLASS events jets per_job)
Output:  $KIT/data/<CLASS>/<CLASS>_<seed>.root   (JetClass ntuples)
EOF
