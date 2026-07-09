#!/usr/bin/env bash
# Generate a JetClass-SHERPA sample (full chain -> HepMC3).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${1:-}" ]; then
  echo "Usage: run.sh <CLASS> [nevents=1000] [seed=1]"
  echo "Classes: $(ls -d "$HERE"/*/ 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
  exit 1
fi
CLASS="$1"; N="${2:-1000}"; SEED="${3:-1}"
[ -f "$HERE/$CLASS/Sherpa.yaml" ] || { echo "Unknown class: $CLASS"; exit 1; }
cd "$HERE/$CLASS"
echo ">> Generating $N '$CLASS' events (seed $SEED) -> HepMC3 ..."
Sherpa -f Sherpa.yaml "EVENTS: $N" "RANDOM_SEED: $SEED"
echo ">> Output: $HERE/$CLASS/events  (HepMC3 GenEvent ASCII)"
