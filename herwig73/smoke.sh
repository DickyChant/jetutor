#!/bin/bash
# smoke.sh — end-to-end check: every class, N events (default 10), sequential.
# Proves MadGraph -> Herwig 7.3 -> Delphes -> makeNtuples runs for all 10 classes on this host.
#   ./smoke.sh            # 10 events each
#   N=50 ./smoke.sh
set -uo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export KIT_DIR
export JCH_MIN_FREE_MB=200
N=${N:-10}; SEED=99
: > "$KIT_DIR/logs/smoke.txt"; mkdir -p "$KIT_DIR/logs"
echo "=== SMOKE TEST: all 10 classes x $N events ==="
for c in ZToQQ WToQQ HToBB HToCC HToGG HToWW4Q HToWW2Q1L TTBar TTBarLep ZJetsToNuNu; do
  echo ">>> $c"
  bash "$KIT_DIR/gen_class.sh" "$c" "$N" "$SEED" > "$KIT_DIR/logs/smk_$c.log" 2>&1 || true
  res=$(grep -hoE 'DONE  jets=[-0-9]+|ERROR' "$KIT_DIR/logs/smk_$c.log" | tail -1)
  echo "$c : ${res:-FAILED}" | tee -a "$KIT_DIR/logs/smoke.txt"
done
echo; echo "==================== SMOKE RESULT ===================="
cat "$KIT_DIR/logs/smoke.txt"
echo "ran end-to-end: $(grep -c 'jets=' "$KIT_DIR/logs/smoke.txt") / 10"
