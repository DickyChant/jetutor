#!/bin/bash
# jetclass_herwig73_cluster — environment. The ENTIRE chain (MadGraph 3.6.4 + Herwig 7.3 +
# Delphes 3.5.1 + ROOT) comes from one CERN LCG view on CVMFS. No conda, no local builds,
# no writable MadGraph. Just needs /cvmfs/sft.cern.ch mounted.
#
#   source env.sh
#
LCG_VIEW=${LCG_VIEW:-/cvmfs/sft.cern.ch/lcg/views/LCG_109a/x86_64-el9-gcc13-opt}
if [ ! -e "$LCG_VIEW/setup.sh" ]; then
  echo "ERROR: LCG view not found: $LCG_VIEW" >&2
  echo "  Set LCG_VIEW to an x86_64-el9 LCG_109a (or newer) view with Herwig 7.3 + Delphes." >&2
  return 1 2>/dev/null || exit 1
fi
source "$LCG_VIEW/setup.sh"

# Herwig's compiled-in repository path is a stale build dir; point at the view's real tree.
export HERWIG_SHARE="$(dirname "$(readlink -f "$(command -v Herwig)")")/../share/Herwig"
export HERWIG_REPO="$HERWIG_SHARE/HerwigDefaults.rpo"
# Delphes headers for makeNtuples.C (cling)
export ROOT_INCLUDE_PATH="$LCG_VIEW/include:${ROOT_INCLUDE_PATH:-}"
export KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# node-local scratch for transients (override on the cluster, e.g. JCH_SCRATCH=$TMPDIR)
export JCH_SCRATCH="${JCH_SCRATCH:-${TMPDIR:-/tmp}}"

echo "[jetclass_herwig] view=$LCG_VIEW"
echo "[jetclass_herwig] Herwig=$(Herwig --version 2>/dev/null | head -1)  ROOT=$(root-config --version 2>/dev/null)  MG5=$(command -v mg5_aMC | xargs basename 2>/dev/null)"
echo "[jetclass_herwig] scratch=$JCH_SCRATCH  KIT_DIR=$KIT_DIR"
