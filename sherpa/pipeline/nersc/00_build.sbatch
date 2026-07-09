#!/usr/bin/env bash
#SBATCH --job-name=jcs_build
#SBATCH --account=m2612
#SBATCH --constraint=cpu
#SBATCH --qos=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --time=02:30:00
#SBATCH --output=logs/%x_%j.out
# Build step (NERSC Perlmutter, native conda via `module load conda`): build openloops +
# sherpa3 conda packages, create the runtime prefix env (+ delphes + compilers), install the
# nn23lo1 PDF, pre-build both ntuplizers. DOWNLOADS source tarballs + PDF, so it runs on the
# *shared* QOS (login-class network) -- the proven sherpack deck puts all network steps there.
# Caches are redirected to pscratch by env.sh (NERSC $HOME has no flock -> rattler error 524).
set -euo pipefail
KIT="${JCS_KIT:?set JCS_KIT to the kit root}"
cd "$KIT"
echo "== host: $(hostname)   cores: $(nproc)   $(date) =="
./00_setup_env.sh
echo "== build complete: $(date) =="
ls -l "$KIT/ntuple/makeNtuples_C.so"   # v1 .so; the exact hqu macro runs interpreted (no .so)
