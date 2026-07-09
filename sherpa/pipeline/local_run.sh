#!/usr/bin/env bash
# No batch system? Run chunks locally in parallel (xargs). Each chunk uses a unique seed.
#   ./pipeline/local_run.sh ZToQQ 100000 20 8    # 20 chunks x 100k = 2M, 8 in parallel
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
CLASS="${1:?Usage: local_run.sh <CLASS> <per_job> <njobs> [parallel=4]}"
PER="${2:?}"; NJOBS="${3:?}"; PAR="${4:-4}"
seq 1 "$NJOBS" | xargs -P "$PAR" -I{} "$KIT/pipeline/one_job.sh" "$CLASS" "$PER" {}
