#!/bin/bash
# gen_class.sh CLASS NEVENTS SEED [WORKDIR]
# One JetClass class end-to-end on the CVMFS LCG / Herwig-7.3 stack:
#   MadGraph 3.6.4 (regenerated from the JetClass proc cards; MadSpin for tt~) -> LHE
#     -> Herwig 7.3 (LHE.in: shower + cluster hadronisation) -> HepMC
#     -> DelphesHepMC2 (delphes_card.tcl) -> Delphes ROOT
#     -> makeNtuples.C (FatJet) -> JetClass jet ntuple in data/<CLASS>/<CLASS>_<seed>.root
#
# All 10 classes run on pure CVMFS: HToCC uses model sm-full (charm Yukawa), HToGG uses the
# bundled HEFT model (models/heft) — no writable MadGraph needed.
set -euo pipefail

CLASS="${1:?usage: gen_class.sh CLASS NEVENTS SEED [WORKDIR]}"
NEVENTS="${2:?need NEVENTS}"
SEED="${3:?need SEED}"
KIT_DIR="${KIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
WORK="${4:-${JCH_SCRATCH:-${TMPDIR:-/tmp}}/jch_${CLASS}_${SEED}}"

if ! command -v Herwig >/dev/null 2>&1; then set +u; source "$KIT_DIR/env.sh"; set -u; fi

# ---- per-class config ----------------------------------------------------------
# Default model preamble (8 sm classes). HToCC/HToGG override MODEL_PRE below.
SM_PRE='import model sm
define p = g u c d s u~ c~ d~ s~
define j = g u c d s u~ c~ d~ s~
define l+ = e+ mu+
define l- = e- mu-
define vl = ve vm vt
define vl~ = ve~ vm~ vt~
import model sm-ckm
define p = p b b~
define j = j b b~'
MODEL_PRE="$SM_PRE"
EXTRA_DEF=""
MADSPIN=""
MISSET='set misset 450
set ptj 0.1'    # default boost: MET (invisible ve ve~) recoil = resonance pT > 450
case "$CLASS" in
  HToBB)      GEN='generate p p > ve ve~ h, h > b b~';                 BOOST="$MISSET";;
  HToWW4Q)    GEN='generate p p > ve ve~ h, h > w+ w- > j j j j';      BOOST="$MISSET";;
  HToWW2Q1L)  EXTRA_DEF='define lep = l+ l-
define nu = vl vl~'
              GEN='generate p p > ve ve~ h, h > w+ w- > j j lep nu';   BOOST="$MISSET";;
  TTBar)      GEN='generate p p > t t~';   MADSPIN='TTBar'
              BOOST='set pt_min_pdg {6: 450.0}
set eta_max_pdg {6: 2.5}';;
  TTBarLep)   GEN='generate p p > t t~';   MADSPIN='TTBarLep'
              BOOST='set pt_min_pdg {6: 450.0}
set eta_max_pdg {6: 2.5}';;
  WToQQ)      EXTRA_DEF='define wpm = w+ w-'
              GEN='generate p p > ve ve~ wpm, wpm > j j';              BOOST="$MISSET";;
  ZToQQ)      GEN='generate p p > ve ve~ z, z > j j';                  BOOST="$MISSET";;
  ZJetsToNuNu) # original is MLM-merged @0/@1 (merging card absent upstream); LO single jet here
              GEN='generate p p > ve ve~ j';                           BOOST="$MISSET";;
  HToCC)      MODEL_PRE='import model sm-full
define p = g u c d s u~ c~ d~ s~ b b~
define vl = ve vm vt
define vl~ = ve~ vm~ vt~'
              GEN='generate p p > ve ve~ h, h > c c~';                 BOOST="$MISSET";;
  HToGG)      MODEL_PRE="import model $KIT_DIR/models/heft
define p = g u c d s u~ c~ d~ s~ b b~
define vl = ve vm vt
define vl~ = ve~ vm~ vt~"
              GEN='generate p p > ve ve~ h, h > g g';                  BOOST="$MISSET";;
  *) echo "Unknown class: $CLASS" >&2; exit 1;;
esac

OUTD="${CLASS}gen"
mkdir -p "$WORK"; cd "$WORK"
echo "[$CLASS] >>> stage 1/5  MadGraph output ($WORK)"
cat > proc.mg5 <<EOF
set automatic_html_opening False
set run_mode 0
$MODEL_PRE
$EXTRA_DEF
$GEN
output $OUTD
EOF
mg5_aMC proc.mg5 > mg5_output.log 2>&1

if [ -n "$MADSPIN" ]; then
  cp "$KIT_DIR/madspin/${MADSPIN}.dat" "$OUTD/Cards/madspin_card.dat"
  MS_SWITCH="madspin=ON"
else
  MS_SWITCH="madspin=OFF"
fi

# Generate a MARGIN of extra LHE events: Herwig is asked for exactly -N=$NEVENTS showered
# events, but its LesHouchesReader needs slightly MORE input events than it outputs (a small
# fraction is skipped/rejected, esp. with the IDWTUP=-4 weighted events). If MadGraph produces
# exactly $NEVENTS, Herwig hits EOF and throws "More events requested than available" *after*
# showering ~all of them -> set -e kills the chunk. Generating ${JCH_MG_MARGIN:-1.3}x covers it.
MG_NEVENTS=$(awk -v n="$NEVENTS" -v m="${JCH_MG_MARGIN:-1.3}" 'BEGIN{printf "%d", n*m + 100}')
echo "[$CLASS] >>> stage 2/5  MadGraph launch ($MG_NEVENTS evt LHE -> shower $NEVENTS, seed $SEED)"
cat > launch.mg5 <<EOF
set automatic_html_opening False
set run_mode 0
launch $OUTD
shower=OFF
detector=OFF
analysis=OFF
$MS_SWITCH
set use_syst False
$BOOST
set nevents $MG_NEVENTS
set iseed $SEED
EOF
mg5_aMC launch.mg5 > mg5_launch.log 2>&1

if [ -d "$OUTD/Events/run_01_decayed_1" ]; then INDIR="$OUTD/Events/run_01_decayed_1"; else INDIR="$OUTD/Events/run_01"; fi
LHE="$INDIR/unweighted_events.lhe.gz"
[ -f "$LHE" ] || { echo "[$CLASS] ERROR: no LHE produced"; tail -20 mg5_launch.log; exit 2; }
echo "[$CLASS]     LHE: $(zcat "$LHE" | grep -c '<event>') events"

# LHE-only mode (used by the jetclass_pythia_showers kit): stop here, the caller takes the LHE
# and showers it with Pythia 8 (Vincia/Dire). Stages 3-5 (Herwig/Delphes/ntuple) are skipped.
if [ -n "${JCH_LHE_ONLY:-}" ]; then echo "JCH_LHE_PATH $LHE"; exit 0; fi

echo "[$CLASS] >>> stage 3/5  Herwig 7.3 shower+hadronise"
sed -e "s@_INPUTDIR_/unweighted_events.lhe.gz@$LHE@" \
    -e "s@_INPUTDIR_/events.hepmc@$WORK/events.hepmc@" \
    -e "s@_NEVENTS_@$NEVENTS@" "$KIT_DIR/LHE.in.tmpl" > LHE.in
Herwig read LHE.in --repo="$HERWIG_REPO" -I "$HERWIG_SHARE" -L "$HERWIG_SHARE" > herwig_read.log 2>&1
# disk gate (single-box only): wait until scratch can hold another HepMC. df -P avoids the
# wrapped-long-device-name pitfall; on a SLURM node with private $TMPDIR this is a no-op.
freemb() { df -Pm "$WORK" 2>/dev/null | awk 'END{print $4+0}'; }
gate_free=$(freemb)
while [ "${gate_free:-999999}" -lt "${JCH_MIN_FREE_MB:-0}" ]; do
  echo "[$CLASS] disk-gate: waiting (${gate_free}MB free)"; sleep 30; gate_free=$(freemb)
done
Herwig run LHE.run --seed="$SEED" -N "$NEVENTS" > herwig_run.log 2>&1
echo "[$CLASS]     HepMC: $(grep -c '^E ' "$WORK/events.hepmc") events"

echo "[$CLASS] >>> stage 4/5  Delphes (HepMC2)"
DelphesHepMC2 "$KIT_DIR/delphes_card.tcl" "$WORK/delphes.root" "$WORK/events.hepmc" > delphes.log 2>&1
rm -f "$WORK/events.hepmc"   # Delphes consumed it; free the multi-GB HepMC before the ntuple step

echo "[$CLASS] >>> stage 5/5  makeNtuples (FatJet)"
mkdir -p "$KIT_DIR/data/$CLASS"
OUT="$KIT_DIR/data/$CLASS/${CLASS}_${SEED}.root"
cp "$KIT_DIR/makeNtuples.C" .
root -l -b -q "makeNtuples.C(\"$WORK/delphes.root\",\"$OUT\",\"FatJet\")" > ntuple.log 2>&1 || true
NJ=$(root -l -b -q -e "TFile f(\"$OUT\");TTree*t=(TTree*)f.Get(\"tree\");printf(\"%lld\",t?t->GetEntries():-1);" 2>/dev/null | tail -1 || true)
[ -z "$NJ" ] && NJ=-1
echo "[$CLASS] DONE  jets=$NJ  -> $OUT"
echo "$CLASS $SEED $NEVENTS $NJ" >> "$KIT_DIR/logs/yield.txt"

if [ -z "${JCH_KEEP_INTERMEDIATE:-}" ]; then
  rm -f "$WORK/delphes.root" "$WORK/LHE.run"
  rm -rf "$WORK/$OUTD/SubProcesses" "$WORK/$OUTD/Events"
fi
