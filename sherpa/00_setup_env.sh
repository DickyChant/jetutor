#!/usr/bin/env bash
# One-time setup on NERSC Perlmutter using the LAB's native conda (module load conda ->
# Miniforge3: conda + mamba). No micromamba bootstrap. Builds the sherpa3/openloops conda
# packages from packaging/ and creates the runtime env as an in-tree PREFIX env.
#
#   ./00_setup_env.sh                      # build the packages from packaging/ recipes
#   JCS_CHANNEL=<url> ./00_setup_env.sh    # skip building; install sherpa3 from a channel
#
# Heavy step (sherpa3 C++ build) -> run in a batch job, not the login node
# (pipeline/nersc/00_build.sbatch does exactly that).
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
source "$KIT/env.sh"
mkdir -p "$RATTLER_CACHE_DIR"

echo "==> [1/6] NERSC conda (module load conda)"
jcs_load_conda
conda --version; mamba --version | head -1

# conda create -p refuses a non-empty existing prefix; clear a stale one.
[ -e "$JCS_ENV" ] && [ -z "$(ls -A "$JCS_ENV" 2>/dev/null)" ] && rmdir "$JCS_ENV"

if [ -n "${JCS_CHANNEL:-}" ]; then
  echo "==> [2-4/6] install sherpa3 + delphes from $JCS_CHANNEL -> $JCS_ENV"
  conda create -y -p "$JCS_ENV" -c "$JCS_CHANNEL" -c conda-forge sherpa3 delphes gxx gfortran
else
  echo "==> [2/6] build env (rattler-build) -> $JCS_BUILD_ENV"
  [ -d "$JCS_BUILD_ENV/conda-meta" ] || \
    conda create -y -p "$JCS_BUILD_ENV" -c conda-forge rattler-build conda-index
  echo "==> [3/6] build openloops, then sherpa3 ON TOP of it -> $JCS_CHANNEL_DIR"
  conda run -p "$JCS_BUILD_ENV" rattler-build build --recipe "$KIT/packaging/openloops" \
        -c conda-forge --output-dir "$JCS_CHANNEL_DIR"
  conda run -p "$JCS_BUILD_ENV" rattler-build build --recipe "$KIT/packaging/sherpa3" \
        -c "$JCS_CHANNEL_DIR" -c conda-forge --output-dir "$JCS_CHANNEL_DIR"
  conda run -p "$JCS_BUILD_ENV" python -m conda_index "$JCS_CHANNEL_DIR"
  echo "==> [4/6] runtime env: sherpa3 + delphes (+ compilers for OpenLoops/Amegic) -> $JCS_ENV"
  conda create -y -p "$JCS_ENV" -c "$JCS_CHANNEL_DIR" -c conda-forge sherpa3 delphes gxx gfortran
fi

echo "==> [5/6] PDF (nn23lo1)"
conda run -p "$JCS_ENV" lhapdf install NNPDF23_lo_as_0130_qed
if [ -f "$KIT/delphes/card.tcl" ]; then
  echo "  using shipped JetClass Delphes card (AK8 EFlow + soft-drop/tau + track IP smearing)"
else
  echo "  WARNING: delphes/card.tcl missing -- copying a PLAIN CMS card WITHOUT track IP smearing"
  CARD="$(conda run -p "$JCS_ENV" bash -c 'find "$CONDA_PREFIX" -name delphes_card_CMS.tcl 2>/dev/null | head -1')"
  [ -n "$CARD" ] && cp "$CARD" "$KIT/delphes/card.tcl"
fi

echo "==> [6/6] ntuplizers: pre-build the v1 .so; validate the exact hqu macro (runs interpreted)"
conda run -p "$JCS_ENV" bash "$KIT/ntuple/build.sh"        # -> ntuple/makeNtuples_C.so
conda run -p "$JCS_ENV" bash "$KIT/ntuple/build_hqu.sh"    # parse-check only (no .so; hqu is interpreted)

cat <<EOF

Setup complete. In a shell:
  source "$KIT/env.sh" && jcs_activate     # module load conda + conda activate $JCS_ENV

Smoke test (one chunk, full chain SHERPA -> HepMC -> Delphes -> JetClass ntuple):
  ./pipeline/one_job_hqu.sh ZToQQ 200 1    # exact JetClass ntuplization (hqu card + macro)
EOF
