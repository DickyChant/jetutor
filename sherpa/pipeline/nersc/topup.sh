#!/usr/bin/env bash
# Generate the RESIDUAL jets so each class reaches >= JCS_TARGET_PER_CLASS kept jets (default
# 13.0M, i.e. >=12.5M with margin so the exact-100k repacking has a full set + spare).
# Recounts what's already on disk, sizes the extra batched tasks from the measured yield, and
# submits them with a seed offset (1000+) so the new chunks NEVER duplicate existing events.
#   ./pipeline/nersc/topup.sh
set -euo pipefail
KIT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$KIT"
PLAN="$KIT/pipeline/nersc/plan.txt"
SUB_N="${JCS_SUB_N:-20000}"; NBATCHES="${JCS_NBATCHES:-10}"; JOB_EVENTS=$((SUB_N*NBATCHES))
TARGET="${JCS_TARGET_PER_CLASS:-13000000}"
SEED_OFFSET="${JCS_SEED_OFFSET:-1000}"      # residual array indices start here (no event collision)
WALL="${JCS_WALLTIME:-05:30:00}"
CLASSES=(HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep WToQQ ZToQQ ZJetsToNuNu)

echo "== counting jets already on disk (TChain) =="
source "$KIT/env.sh" >/dev/null 2>&1; jcs_activate >/dev/null 2>&1
cat > /tmp/jcs_count.C <<'EOF'
void jcs_count(){
  const char* C[10]={"HToBB","HToCC","HToGG","HToWW4Q","HToWW2Q1L","TTBar","TTBarLep","WToQQ","ZToQQ","ZJetsToNuNu"};
  for(int i=0;i<10;i++){TChain ch("tree");ch.Add(Form("data/%s/%s_*_b*.root",C[i],C[i]));
    std::cout<<"CNT "<<C[i]<<" "<<ch.GetEntries()<<std::endl;}
}
EOF
root -l -b -q /tmp/jcs_count.C >/tmp/jcs_count.out 2>/dev/null || true
declare -A CUR
while read -r tag C n; do [ "$tag" = "CNT" ] && CUR[$C]=$n; done < <(grep '^CNT' /tmp/jcs_count.out)

echo "== sizing & submitting residual (target >= $TARGET jets/class) =="
total=0
while read -r C smoke_ev jets _; do
  [ -z "${C:-}" ] && continue
  cur=${CUR[$C]:-0}; yield=$(python3 -c "print($jets/$smoke_ev)")
  need=$(python3 -c "print(max(0,$TARGET-$cur))")
  if [ "$need" -le 0 ]; then echo "  $C: have $cur >= $TARGET, skip"; continue; fi
  tasks=$(python3 -c "import math;print(math.ceil(($need/$yield)/$JOB_EVENTS))")
  total=$((total+tasks))
  lo=$((SEED_OFFSET+1)); hi=$((SEED_OFFSET+tasks))
  echo "  $C: have $cur, need +$need -> $tasks tasks (seeds $lo-$hi)"
  JCS_KIT="$KIT" sbatch --array="$lo-$hi" --time="$WALL" --job-name="jcs_$C" \
    --export="ALL,JCS_KIT=$KIT,JCS_CLASS=$C,JCS_SUB_N=$SUB_N,JCS_NBATCHES=$NBATCHES" \
    "$KIT/pipeline/nersc/20_generate.sbatch" >/dev/null
done < "$PLAN"
echo "== submitted $total residual tasks : $(date) =="