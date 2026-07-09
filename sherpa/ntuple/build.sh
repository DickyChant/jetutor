#!/usr/bin/env bash
# Pre-build the JetClass ntuplizer (makeNtuples.C -> makeNtuples_C.so) with the env's ROOT,
# so the generation jobs just load the .so (no per-job ACLiC compile / no parallel races).
# Run inside the activated 'jcs' env:  bash ntuple/build.sh
set -euo pipefail
cd "$(dirname "$0")"
: "${CONDA_PREFIX:?activate the runtime env first (source env.sh && jcs_activate)}"
export ROOT_INCLUDE_PATH="$CONDA_PREFIX/include${ROOT_INCLUDE_PATH:+:$ROOT_INCLUDE_PATH}"
# ROOT 6.38 returns a nonzero exit code even on success, so don't let `set -e` trust it --
# judge success by the .so actually being produced.
root -l -b -q -e 'gSystem->Load("libDelphes"); gSystem->CompileMacro("makeNtuples.C","k");' || true
[ -f makeNtuples_C.so ] || { echo "ERROR: makeNtuples_C.so not produced"; exit 1; }
echo "built: $(pwd)/makeNtuples_C.so"
