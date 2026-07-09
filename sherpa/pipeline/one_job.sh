#!/usr/bin/env bash
# One generation chunk through the full JetClass chain, for one (CLASS, NEVENTS, SEED):
#   SHERPA (sherpa3 + OpenLoops) -> HepMC3 -> Delphes (AK8 EFlow + IP smearing)
#     -> makeNtuples (official jetclass2 ntuplizer, v1-ported) -> JetClass ntuple
# HepMC + Delphes ROOT are transient (scratch); only the small JetClass ntuple is kept
# (set JCS_KEEP_DELPHES=1 to also keep the per-chunk Delphes ROOT).
# Requires the 'jcs' env active (Sherpa, DelphesHepMC3, root on PATH; nn23lo1 installed;
# the ntuplizer pre-built by 00_setup_env.sh).
set -euo pipefail
CLASS="${1:?Usage: one_job.sh <CLASS> [nevents=50000] [seed=1]}"
N="${2:-50000}"; SEED="${3:-1}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$KIT/generation/$CLASS/Sherpa.yaml" ] || { echo "Unknown class: $CLASS"; exit 1; }

# v1 JetClass class -> jet_label index (see docs/MANUAL.md)
case "$CLASS" in
  ZJetsToNuNu) IDX=0 ;;  HToBB) IDX=1 ;;  HToCC) IDX=2 ;;  HToGG) IDX=3 ;;
  HToWW4Q)     IDX=4 ;;  HToWW2Q1L) IDX=5 ;;  ZToQQ) IDX=6 ;;  WToQQ) IDX=7 ;;
  TTBar)       IDX=8 ;;  TTBarLep)  IDX=9 ;;
  *) echo "No label index defined for class $CLASS"; exit 1 ;;
esac

CARD="${DELPHES_CARD:-$KIT/delphes/card.tcl}"
[ -f "$CARD" ] || { echo "Delphes card not found: $CARD  (run 00_setup_env.sh)"; exit 1; }
OUT="${JCS_OUT:-$KIT/data}/$CLASS"; mkdir -p "$OUT"
TAG="${CLASS}_$(printf '%06d' "$SEED")"
NTUPLE="$OUT/${TAG}.root"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/jcs.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT

echo ">> [$CLASS seed=$SEED] SHERPA: $N events -> HepMC3"
cp "$KIT/generation/$CLASS/Sherpa.yaml" "$WORK/"
( cd "$WORK" && Sherpa -f Sherpa.yaml "EVENTS: $N" "RANDOM_SEED: $SEED" )

echo ">> [$CLASS seed=$SEED] Delphes -> detector ROOT"
DROOT="$WORK/delphes.root"
DelphesHepMC3 "$CARD" "$DROOT" "$WORK/events"

echo ">> [$CLASS seed=$SEED] ntuplize (AK8 FatJet, label=$IDX) -> JetClass ntuple"
rm -f "$NTUPLE"
export ROOT_INCLUDE_PATH="${CONDA_PREFIX:-}/include${ROOT_INCLUDE_PATH:+:$ROOT_INCLUDE_PATH}"
# ROOT 6.38 exits nonzero even on success -> tolerate it and verify the output ntuple instead.
root -l -b -q -e 'gSystem->Load("libDelphes");' \
  "$KIT/ntuple/makeNtuples.C+(\"$DROOT\",\"$NTUPLE\",\"FatJet\",\"GenJet\",$IDX)" || true
[ -s "$NTUPLE" ] || { echo "ERROR: ntuplize produced no output ($NTUPLE)"; exit 1; }

[ "${JCS_KEEP_DELPHES:-0}" = "1" ] && cp "$DROOT" "$OUT/${TAG}_delphes.root"
echo ">> done: $NTUPLE  ($(du -h "$NTUPLE" | cut -f1))"
