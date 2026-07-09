#!/bin/bash
set -euxo pipefail

# --- work around SHERPA's compiler-flag re-validation -------------------------
# CMakeLists.txt (lines ~203 and ~222) rebuilds CMAKE_C_FLAGS / CMAKE_Fortran_FLAGS
# by splitting the existing flags on EVERY space and re-testing each token. That
# orphans conda's `-isystem <dir>` pairs into a bare `<dir>` token, which poisons
# the flags so that every test-compile fails -> find_package(Threads) dies and the
# real build breaks. Rewrite the space-separated `-isystem <dir>` to the attached
# `-I<dir>` form, which survives the naive split intact. (CXXFLAGS splits on " -",
# so it is unaffected, but we normalise it too for consistency.)
set +u
export CFLAGS="${CFLAGS//-isystem /-I}"
export CXXFLAGS="${CXXFLAGS//-isystem /-I}"
export FFLAGS="${FFLAGS//-isystem /-I}"
export FCFLAGS="${FCFLAGS//-isystem /-I}"
set -u

# Out-of-source CMake build (Ninja). SHERPA 3 is C++11; INTERNAL_PDFS pulls in
# Fortran. All external interfaces are located via -D<Pkg>_DIR hints pointing at
# the conda host prefix; OpenLoops via its install tree under share/openloops.
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH="${PREFIX}" \
  -DSHERPA_ENABLE_LHAPDF=ON       -DLHAPDF_DIR="${PREFIX}" \
  -DLibZip_DIR="${PREFIX}" \
  -DSHERPA_ENABLE_HEPMC3=ON       -DHepMC3_DIR="${PREFIX}" \
  -DSHERPA_ENABLE_RIVET=ON        -DRIVET_DIR="${PREFIX}" -DYODA_DIR="${PREFIX}" \
  -DSHERPA_ENABLE_PYTHIA8=ON      -DPYTHIA8_DIR="${PREFIX}" \
  -DSHERPA_ENABLE_OPENLOOPS=ON    -DOPENLOOPS_DIR="${PREFIX}/share/openloops" \
  -DSHERPA_ENABLE_PYTHON=ON \
  -DSHERPA_ENABLE_MPI=ON \
  -DMPI_C_COMPILER="${PREFIX}/bin/mpicc" \
  -DMPI_CXX_COMPILER="${PREFIX}/bin/mpicxx" \
  -DMPI_Fortran_COMPILER="${PREFIX}/bin/mpifort" \
  -DSHERPA_ENABLE_ANALYSIS=ON \
  -DSHERPA_ENABLE_THREADING=ON \
  -DSHERPA_ENABLE_INTERNAL_PDFS=ON \
  -DSHERPA_ENABLE_EXAMPLES=ON

cmake --build build -j"${CPU_COUNT:-2}"
cmake --install build
