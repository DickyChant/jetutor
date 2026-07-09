#!/bin/bash
set -euxo pipefail

PYBIN="${PYTHON:-python3}"

# ----------------------------------------------------------------------
# Point OpenLoops at the conda compiler toolchain. OpenLoops reads the
# compilers from `openloops.cfg` (section [OpenLoops]) in the source root.
# ----------------------------------------------------------------------
cat > openloops.cfg <<EOF
[OpenLoops]
fortran_compiler = ${FC}
cc = ${CC}
cxx = ${CXX}
cpp = ${CPP:-cpp}
num_jobs = ${CPU_COUNT:-2}
compile = 2
generator = 2
shared_libraries = 1
EOF
echo "----- openloops.cfg -----"; cat openloops.cfg

# ----------------------------------------------------------------------
# Build the process-independent (generic) libraries:
#   libopenloops + bundled Collier / CutTools / OneLOop / rambo / trred / olcommon
# ----------------------------------------------------------------------
"${PYBIN}" ./scons -Q compile=2

echo "----- built libraries -----"; ls -la lib/

# ----------------------------------------------------------------------
# Install. OpenLoops has no `make install` and is designed to run from its
# own source tree. We keep that tree under $PREFIX/share/openloops (so the
# `openloops` driver and downloaded process libraries work), and expose the
# shared libraries + C header in the standard $PREFIX/lib and $PREFIX/include
# so that downstream packages (Sherpa) link against them normally.
# ----------------------------------------------------------------------
OLROOT="${PREFIX}/share/openloops"
mkdir -p "${OLROOT}" "${PREFIX}/lib" "${PREFIX}/include" "${PREFIX}/bin"

# runtime tree used by the `openloops` tool
cp -a openloops SConstruct openloops.cfg.tmpl pyol lib_src scons scons-local \
      authors.txt COPYING README "${OLROOT}/"
mkdir -p "${OLROOT}/proclib"

# Consumers such as Sherpa's FindOpenLoops.cmake locate OpenLoops by the presence
# of proclib/channels_public.rinfo. A fresh install (no process libraries) lacks
# it, so ship a harmless stub: the `openloops` downloader reads only its first
# whitespace token and overwrites the file on first `openloops libinstall`.
printf 'none  1970-01-01_00:00:00\n' > "${OLROOT}/proclib/channels_public.rinfo"

# real shared libraries -> $PREFIX/lib ; the tool finds them via BASEDIR/lib
cp -a lib/*.so* "${PREFIX}/lib/"
ln -s ../../lib "${OLROOT}/lib"

# C/C++ header -> $PREFIX/include ; the tool finds it via BASEDIR/include
cp -a include/openloops.h "${PREFIX}/include/"
ln -s ../../include "${OLROOT}/include"

# expose the driver on PATH (relative symlink -> relocation-safe)
ln -s ../share/openloops/openloops "${PREFIX}/bin/openloops"

echo "----- installed layout -----"
ls -la "${PREFIX}/lib/" | grep -i openloops || true
ls -la "${PREFIX}/bin/openloops" "${PREFIX}/include/openloops.h"
ls -la "${OLROOT}"
