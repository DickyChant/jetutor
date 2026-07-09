#!/usr/bin/env bash
#SBATCH --job-name=jcs_rebin
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=shared
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=03:00:00
#SBATCH --array=1-10
#SBATCH --output=logs/%x_%A_%a.out
# Convert the hqu SHERPA ntuples -> official JetClass format, ONE class per array task.
# Output drops in as the Sherpa/ sibling of Pythia/:
#   $JCS_OUTROOT/{train_100M,test_20M,val_5M}/CLASS_NNN.root  (100k jets/file)
# ROOT 6.38 exits nonzero on success -> judge by the produced files, not root's exit.
set -euo pipefail
JCS_KIT="${JCS_KIT:?}"
cd "$JCS_KIT"
source "$JCS_KIT/env.sh"; jcs_activate
CLASSES=(HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep WToQQ ZToQQ ZJetsToNuNu)
C="${CLASSES[$((SLURM_ARRAY_TASK_ID-1))]}"
INDIR="${JCS_INDIR:-$JCS_KIT/data}"
OUTROOT="${JCS_OUTROOT:-/pscratch/sd/s/sqian/part_datasets/JetClass/Sherpa}"
PAT="${JCS_PAT:-_*_b*}"   # input glob: Sherpa "_*_b*", Herwig "_*"
echo "== rebin $C : $INDIR -> $OUTROOT  (pat ${C}${PAT}.root) =="
MINP="${JCS_MINPARTS:-0}"; PTMAX="${JCS_PTMAX:-0}"
# JCS_GENMATCH: keep only jets with gen_match==N (for the unified HToWW sample: 46->2q1l, 45->4q); 0=off
GM="${JCS_GENMATCH:-0}"
root -l -b -q "tools/rebin.C(\"$C\",\"$INDIR\",\"$OUTROOT\",100,20,5,100000,\"$PAT\",$MINP,$PTMAX,$GM)" || true
# success = the official 125 files exist (100 train + 20 test + 5 val)
ntr=$(ls "$OUTROOT"/train_100M/${C}_*.root 2>/dev/null | wc -l)
nte=$(ls "$OUTROOT"/test_20M/${C}_*.root 2>/dev/null | wc -l)
nva=$(ls "$OUTROOT"/val_5M/${C}_*.root 2>/dev/null | wc -l)
echo "== $C produced: train=$ntr test=$nte val=$nva =="
[ "$ntr" -ge 100 ] && [ "$nte" -ge 20 ] && [ "$nva" -ge 5 ] || { echo "INCOMPLETE for $C (need 100/20/5)"; exit 1; }
