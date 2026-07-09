#!/bin/bash
# gen_class_pythia.sh CLASS NEVENTS SEED SHOWER [WORKDIR]
#
# One JetClass class end-to-end, swapping ONLY the parton shower for Pythia 8.3:
#   MadGraph 3.6.4 LHE  (reuse the Herwig kit's gen_class.sh in JCH_LHE_ONLY mode, el9 container)
#     -> Pythia 8.312 shower+hadronise  (conda env; SHOWER = simple|vincia|dire)
#     -> HepMC2 -> DelphesHepMC2 (hqu card) -> makeNtuples (FatJet) -> data_<SHOWER>/<CLASS>/<CLASS>_<seed>.root
#
# Identical MG ME + decays + Delphes card as the Herwig/Sherpa editions, so ONLY the shower differs.
set -euo pipefail
CLASS="${1:?usage: gen_class_pythia.sh CLASS NEVENTS SEED SHOWER [WORKDIR]}"
NEVENTS="${2:?need NEVENTS}"
SEED="${3:?need SEED}"
SHOWER="${4:?need SHOWER (simple|vincia|dire)}"

PYTHIA_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERWIG_KIT="${HERWIG_KIT:-/pscratch/sd/s/sqian/jetclass_herwig73_cluster}"
SHERPA_KIT="${SHERPA_KIT:-/pscratch/sd/s/sqian/jetclass-sherpa}"
IMG="${JCH_IMAGE:-cmssw/el9:x86_64}"
CMND="$PYTHIA_KIT/cmnd/$SHOWER.cmnd"
[ -f "$CMND" ] || { echo "no cmnd for shower '$SHOWER': $CMND"; exit 1; }
[ -x "$PYTHIA_KIT/shower_lhe" ] || { echo "build shower_lhe first (build.sh)"; exit 1; }

WORK="${5:-${JCP_SCRATCH:-${TMPDIR:-/tmp}}/jcp_${SHOWER}_${CLASS}_${SEED}}"
mkdir -p "$WORK"
OUTD="${JCP_OUT:-$PYTHIA_KIT/data_$SHOWER}/$CLASS"; mkdir -p "$OUTD"
OUT="$OUTD/${CLASS}_$(printf '%06d' "$SEED").root"
if [ -s "$OUT" ]; then echo ">> [$CLASS/$SHOWER seed=$SEED] exists, skipping"; exit 0; fi

# ---- stage 1: MadGraph LHE in the el9 + CVMFS container (Pythia rarely rejects LHE events, so
#      a small margin suffices; Herwig's gen_class.sh reads JCH_MG_MARGIN). -------------------
echo ">> [$CLASS/$SHOWER seed=$SEED] stage 1/4  MadGraph LHE (container)"
shifter --image="$IMG" --module=cvmfs -- bash -c \
  "export JCH_LHE_ONLY=1 JCH_MG_MARGIN='${JCP_MG_MARGIN:-1.05}'; \
   bash '$HERWIG_KIT/gen_class.sh' '$CLASS' '$NEVENTS' '$SEED' '$WORK'" 2>&1 | tee "$WORK/mg.log"
LHE="$(awk '/^JCH_LHE_PATH /{print $2}' "$WORK/mg.log" | tail -1)"
case "$LHE" in /*) ;; *) LHE="$WORK/$LHE";; esac   # gen_class.sh prints the path relative to WORK
[ -f "$LHE" ] || { echo "[$CLASS/$SHOWER] ERROR: no LHE (mg.log tail below)"; tail -25 "$WORK/mg.log"; exit 2; }

# ---- stage 2-4: shower (conda Pythia) -> Delphes -> ntuple ---------------------------------
set +u; source "$SHERPA_KIT/env.sh"; jcs_activate; set -u
SHIM="$(mktemp -d "${TMPDIR:-/tmp}/jcp_shim.XXXXXX")"; ln -s "$CONDA_PREFIX/include" "$SHIM/external"
export ROOT_INCLUDE_PATH="$CONDA_PREFIX/include:$SHIM"
trap 'rm -rf "$SHIM"' EXIT
CARD="$SHERPA_KIT/hqu_jet_gen/delphes_card.tcl"; MACRO="$SHERPA_KIT/hqu_jet_gen/makeNtuples.C"

echo ">> [$CLASS/$SHOWER seed=$SEED] stage 2/4  Pythia 8 shower ($SHOWER)"
"$PYTHIA_KIT/shower_lhe" "$CMND" "$LHE" "$WORK/events.hepmc" "$NEVENTS" "$SEED" 2> "$WORK/shower.log"
tail -1 "$WORK/shower.log"

echo ">> [$CLASS/$SHOWER seed=$SEED] stage 3/4  Delphes (HepMC2)"
DelphesHepMC2 "$CARD" "$WORK/delphes.root" "$WORK/events.hepmc" > "$WORK/delphes.log" 2>&1
rm -f "$WORK/events.hepmc"

echo ">> [$CLASS/$SHOWER seed=$SEED] stage 4/4  makeNtuples (FatJet)"
rm -f "$OUT"
root -l -b -q "$MACRO(\"$WORK/delphes.root\",\"$OUT\",\"FatJet\")" > "$WORK/ntuple.log" 2>&1 || true
NJ="$(root -l -b -q -e "TFile f(\"$OUT\");TTree*t=f.IsZombie()?0:(TTree*)f.Get(\"tree\");printf(\"%lld\",t?t->GetEntries():-1LL);" 2>/dev/null | tail -1 || true)"
[ -z "$NJ" ] && NJ=-1
echo ">> [$CLASS/$SHOWER seed=$SEED] DONE jets=$NJ -> $OUT"

if [ -z "${JCP_KEEP:-}" ]; then rm -rf "$WORK"; fi
