#!/usr/bin/env bash
# Validate the EXACT JetClass ntuplizer (hqu_jet_gen/makeNtuples.C).
#
# Unlike the v1 ntuple/ macro, the hqu macro is written to be RUN INTERPRETED by cling: its
# `#ifdef __CLING__` block does R__LOAD_LIBRARY(libDelphes) and includes DelphesClasses.h +
# external/ExRootAnalysis/ExRootTreeReader.h, while the *compiled* path only forward-declares
# them (so ACLiC can't build it). pipeline/one_job_hqu.sh therefore runs it interpreted -- there
# is no .so to pre-build. This script just parse-loads the macro so a syntax/include error is
# caught at setup time, not at generation time.
#
# Why the shim: the macro's "external/ExRootAnalysis/..." include prefix is satisfied by a temp
# dir whose "external" symlinks to $CONDA_PREFIX/include (conda Delphes ships ExRootAnalysis/
# directly under include/). "classes/..." resolves against $CONDA_PREFIX/include.
#
# Run inside the runtime env (source env.sh && jcs_activate):  bash ntuple/build_hqu.sh
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$KIT/hqu_jet_gen"
: "${CONDA_PREFIX:?activate the runtime env first (source env.sh && jcs_activate)}"

SHIM="$(mktemp -d "${TMPDIR:-/tmp}/jcs_hqushim.XXXXXX")"
trap 'rm -rf "$SHIM"' EXIT
ln -s "$CONDA_PREFIX/include" "$SHIM/external"
export ROOT_INCLUDE_PATH="$CONDA_PREFIX/include:$SHIM${ROOT_INCLUDE_PATH:+:$ROOT_INCLUDE_PATH}"

cd "$SRC"
# .L loads/parses the macro (defines makeNtuples) without calling it. ROOT 6.38 returns a
# nonzero exit even on success, so judge by our explicit OK marker, not root's exit code.
out="$(root -l -b -q -e 'if(gROOT->LoadMacro("makeNtuples.C")){gSystem->Exit(1);} printf("JCS_HQU_MACRO_OK\n");' 2>&1 || true)"
if grep -q "JCS_HQU_MACRO_OK" <<<"$out"; then
  echo "ok: hqu_jet_gen/makeNtuples.C parses/loads (interpreted) against conda Delphes"
else
  echo "ERROR: hqu macro failed to parse/load:"; echo "$out" | tail -20; exit 1
fi
