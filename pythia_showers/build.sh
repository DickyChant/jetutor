#!/usr/bin/env bash
# Build the Pythia-shower driver (shower_lhe). Needs the jetclass-sherpa conda env (Pythia 8.3 +
# HepMC3). Run once on the target host; the binary is host/ROOT-agnostic C++ but rebuild if the
# conda env changes.  Usage:  ./build.sh
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
SHERPA_KIT="${SHERPA_KIT:-/pscratch/sd/s/sqian/jetclass-sherpa}"
set +u; source "$SHERPA_KIT/env.sh"; jcs_activate; set -u
cd "$KIT"
g++ shower_lhe.cc -o shower_lhe $(pythia8-config --cxxflags --libs) \
    -I"$CONDA_PREFIX/include" -L"$CONDA_PREFIX/lib" -lHepMC3 -Wl,-rpath,"$CONDA_PREFIX/lib"
echo "built: $KIT/shower_lhe"
