#!/usr/bin/env bash
# Generation job through the full JetClass chain using the EXACT JetClass ntuplization
# (hqu_jet_gen/), for one (CLASS, SUB_N, SEED). To keep the pscratch staging small, ONE job
# runs JCS_NBATCHES sub-batches of SUB_N events each, processing them ONE AT A TIME and
# DELETING that sub-batch's transient HepMC3 + Delphes ROOT before starting the next:
#   for each sub-batch k:
#     SHERPA (SUB_N events) -> HepMC3
#       -> Delphes (hqu_jet_gen/delphes_card.tcl: ParticleFlowCandidate + GenFatJet/FatJet
#          + AK8 softdrop/Nsubjettiness + TrackSmearing)
#       -> hqu_jet_gen/makeNtuples.C (interpreted; gen-matched labels; reco cut PT>=500,|eta|<=2)
#       -> data/<CLASS>/<CLASS>_<seed>_b<k>.root   (kept)
#     rm the HepMC + Delphes ROOT immediately (only one small transient exists at a time)
# So a long job stages little on pscratch and cleans as it goes. Each sub-batch ntuple is a
# valid standalone output, so a killed job keeps the sub-batches it already finished (and a
# rerun resumes -- existing sub-batch outputs are skipped).
#
# Requires the runtime env active (source env.sh && jcs_activate).
# Env knobs: JCS_NBATCHES (default 1), JCS_KEEP_DELPHES=1 to keep each Delphes ROOT.
# Prints "JCS_YIELD <CLASS> <total_events> <total_jets>" at the end (used by the planner).
set -euo pipefail
CLASS="${1:?Usage: one_job_hqu.sh <CLASS> [sub_n=20000] [seed=1]}"
SUB_N="${2:-20000}"; SEED="${3:-1}"
NBATCHES="${JCS_NBATCHES:-1}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$KIT/generation/$CLASS/Sherpa.yaml" ] || { echo "Unknown class: $CLASS"; exit 1; }

CARD="${DELPHES_CARD:-$KIT/hqu_jet_gen/delphes_card.tcl}"
[ -f "$CARD" ] || { echo "Delphes card not found: $CARD"; exit 1; }
MACRO="$KIT/hqu_jet_gen/makeNtuples.C"
OUT="${JCS_OUT:-$KIT/data}/$CLASS"; mkdir -p "$OUT"

# The hqu macro is interpreted (cling) and uses the external/ExRootAnalysis include prefix ->
# one shim dir (external -> $CONDA_PREFIX/include) reused for every sub-batch.
SHIM="$(mktemp -d "${TMPDIR:-/tmp}/jcs_hqushim.XXXXXX")"; ln -s "$CONDA_PREFIX/include" "$SHIM/external"
export ROOT_INCLUDE_PATH="$CONDA_PREFIX/include:$SHIM${ROOT_INCLUDE_PATH:+:$ROOT_INCLUDE_PATH}"
trap 'rm -rf "$SHIM"' EXIT

tot_ev=0; tot_jets=0
for k in $(seq 1 "$NBATCHES"); do
  SUBSEED=$(( SEED * 1000 + k ))                 # unique per (job, sub-batch)
  if [ "$NBATCHES" -eq 1 ]; then BTAG="$(printf '%06d' "$SEED")"; SUBSEED="$SEED";
  else BTAG="$(printf '%06d' "$SEED")_b$(printf '%02d' "$k")"; fi
  NTUPLE="$OUT/${CLASS}_${BTAG}.root"

  # resume: a non-empty, readable output for this sub-batch is already done -> skip
  if [ -s "$NTUPLE" ]; then
    echo ">> [$CLASS seed=$SEED b$k] exists, skipping: $(basename "$NTUPLE")"
    continue
  fi

  WORK="$(mktemp -d "${TMPDIR:-/tmp}/jcs.XXXXXX")"
  echo ">> [$CLASS seed=$SEED b$k/$NBATCHES subseed=$SUBSEED] SHERPA $SUB_N -> HepMC3 -> Delphes -> ntuple"
  cp "$KIT/generation/$CLASS/Sherpa.yaml" "$WORK/"
  ( cd "$WORK" && Sherpa -f Sherpa.yaml "EVENTS: $SUB_N" "RANDOM_SEED: $SUBSEED" )
  DROOT="$WORK/delphes.root"
  DelphesHepMC3 "$CARD" "$DROOT" "$WORK/events"
  rm -f "$NTUPLE"
  # ROOT 6.38 exits nonzero even on success -> tolerate, judge by the output tree.
  root -l -b -q "$MACRO(\"$DROOT\",\"$NTUPLE\",\"FatJet\")" || true
  [ "${JCS_KEEP_DELPHES:-0}" = "1" ] && cp "$DROOT" "$OUT/${CLASS}_${BTAG}_delphes.root"

  JETS="$(root -l -b -q -e "TFile f(\"$NTUPLE\"); TTree*t=f.IsZombie()?0:(TTree*)f.Get(\"tree\"); printf(\"JCSJETS %lld\\n\", t?t->GetEntries():-1LL);" 2>/dev/null | sed -n 's/^JCSJETS //p' | tail -1)" || true
  if [ -s "$NTUPLE" ] && [ "${JETS:--1}" -ge 0 ] 2>/dev/null; then
    tot_ev=$(( tot_ev + SUB_N )); tot_jets=$(( tot_jets + JETS ))
    echo ">> [$CLASS seed=$SEED b$k] done: $(basename "$NTUPLE") ($(du -h "$NTUPLE" | cut -f1), $JETS jets)"
  else
    echo "ERROR: sub-batch $k produced no readable tree ($NTUPLE)"; rm -rf "$WORK"; exit 1
  fi
  # IN-JOB CLEANUP: drop this sub-batch's transient HepMC + Delphes ROOT before the next batch
  rm -rf "$WORK"
done

echo "JCS_YIELD $CLASS $tot_ev $tot_jets"
