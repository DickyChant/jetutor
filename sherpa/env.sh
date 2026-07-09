# Shared environment for jetclass-sherpa on NERSC Perlmutter.
# Source from a host shell or from inside an sbatch script. Safe to re-source.
#   source env.sh && jcs_activate     # load NERSC conda + activate the runtime env

# --- NERSC ---
export NERSC_ACCOUNT="${NERSC_ACCOUNT:-m2612}"

# --- Layout (all in-tree, on pscratch) ---
_JCS_HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export JCS_KIT="${JCS_KIT:-$_JCS_HERE}"
# The runtime env IS this prefix dir (sherpa3 + delphes + compilers). Activate it directly.
export JCS_ENV="${JCS_ENV:-$JCS_KIT/conda_sherpa_delphes_env}"
# Transient env that only carries rattler-build (used once to build the packages).
export JCS_BUILD_ENV="${JCS_BUILD_ENV:-$JCS_KIT/.conda_build_env}"
# Local conda channel where the built openloops/sherpa3 packages land.
export JCS_CHANNEL_DIR="${JCS_CHANNEL_DIR:-$JCS_KIT/output}"

# NERSC global home ($HOME/.cache) does NOT support file locking (flock) -> rattler-build /
# huggingface / pip die with "Unknown error 524". Keep all caches on pscratch (Lustre w/ flock).
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$JCS_KIT/.cache}"
export RATTLER_CACHE_DIR="${RATTLER_CACHE_DIR:-$JCS_KIT/.cache/rattler}"

# Load NERSC's native conda (module load conda -> Miniforge3: conda + mamba).
jcs_load_conda() {
  set +u
  if ! command -v module >/dev/null 2>&1; then
    if [ -f /etc/profile.d/modules.sh ]; then source /etc/profile.d/modules.sh; else source /etc/profile; fi
  fi
  module load conda
  set -u
}

# Load conda and activate the runtime env.
jcs_activate() {
  jcs_load_conda
  set +u
  conda activate "$JCS_ENV"
  set -u
}
