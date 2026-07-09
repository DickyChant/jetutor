# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A cluster kit that produces a **SHERPA edition of the 10 JetClass hard-process classes**.
The original JetClass was MadGraph5 + Pythia8 + Delphes; here the matrix element + parton
shower + hadronisation come from **SHERPA 3** (with **OpenLoops** as the one-loop provider),
and the detector sim from **Delphes**. Everything installs as conda packages under this
folder using **NERSC's native conda** (`module load conda` → Miniforge3, conda + mamba) into
an in-tree **prefix env** — nothing in `$HOME`, no admin, no micromamba bootstrap.

End-to-end chain (one chunk = one `(CLASS, NEVENTS, SEED)`):
```
SHERPA (ME+PS+hadronisation+UE) -> HepMC3 -> Delphes (AK8 EFlow + IP smearing)
   -> makeNtuples (ROOT/ACLiC macro) -> JetClass jet-constituent ntuple (.root)
```
Only the final ntuple is kept; HepMC and the Delphes ROOT are transient scratch
(`JCS_KEEP_DELPHES=1` keeps the Delphes ROOT). ~2.9 KB/jet → ~280 GB for 100M jets.

## Setup and run

```bash
# One-time setup: module load conda + build openloops/sherpa3 conda pkgs + runtime env + PDF + card
./00_setup_env.sh                       # ~30-60 min, dominated by the sherpa3 C++ build
JCS_CHANNEL=<url> ./00_setup_env.sh      # skip the build; install prebuilt pkgs from a channel

# Activate the env in any new shell (module load conda + conda activate the prefix env):
source env.sh && jcs_activate

# Smoke test — one chunk, full chain:
./pipeline/one_job.sh ZToQQ 200 1        # -> data/ZToQQ/ZToQQ_000001.root

# SLURM, scale to 100M (10 classes x PER_CLASS):
PER_CLASS=10000000 PER_JOB=50000 ./pipeline/submit.sh

# No batch system:
./pipeline/local_run.sh ZToQQ 100000 20 8   # 20 chunks x 100k, 8 in parallel
```

`00_setup_env.sh` uses **NERSC native conda** (`module load conda`; see `env.sh` /
`jcs_activate`). It creates the runtime env as a **prefix env** at
`conda_sherpa_delphes_env/` and a transient rattler-build env at `.conda_build_env/`. It is
**idempotent-ish but not resumable** — it rebuilds packages unless `JCS_CHANNEL` is set or
`output/` already has the indexed conda packages. The heavy `sherpa3` C++ build should run on
a **compute node**, not a login node. All caches are redirected to pscratch (`env.sh` sets
`XDG_CACHE_HOME`/`RATTLER_CACHE_DIR`) because **NERSC global home has no flock** — otherwise
rattler-build dies with `Unknown error 524`.

## Environment is NERSC Perlmutter

- `NERSC_HOST=perlmutter`, CPU allocation account **`m2612`** (GPU: `m2612_g`).
- The shipped `pipeline/job.sbatch` is **generic** — it has no `-A/--account`, no
  `-C cpu` constraint, and no `-q` QOS, so it will be **rejected by Perlmutter's scheduler
  as written**. Any SLURM submission here must add NERSC directives (e.g.
  `-A m2612 -C cpu -q regular|shared`). Perlmutter CPU nodes are 128-core AMD EPYC (256
  hyperthreads); `one_job.sh` is single-core, so pack many array tasks per node or use the
  `shared` QOS.
- Heavy compiles (sherpa3, OpenLoops process libs, the ROOT/ACLiC ntuplizer) belong in a
  batch job, not on the login node.

## Architecture / where things live

- **`packaging/`** — `rattler-build` conda recipes. `openloops` (SCons build, Fortran)
  is built first; `sherpa3` (CMake, version 3.0.4) is built **on top of it** and also links
  lhapdf/hepmc3/rivet/pythia8/openmpi and SWIG-generated `pysherpa`. The build order in
  `00_setup_env.sh` matters: openloops → index → sherpa3.
- **`generation/<CLASS>/Sherpa.yaml`** — one self-contained runcard per class, all on PDF
  `NNPDF23_lo_as_0130_qed` (nn23lo1, 13 TeV). Decays are **forced** per class via
  `HARD_DECAYS.Channels`, so a run produces N events *of that class* and the xsec SHERPA
  prints is the **production** xsec (HToBB/CC/GG share one). Override per run with CLI
  key:value args, e.g. `Sherpa -f Sherpa.yaml "EVENTS: N" "RANDOM_SEED: S"`. The
  `[PT, <boson/jet>, 450.0, E_CMS]` selector is the boost cut. See `docs/MANUAL.md` for the
  full class→process map and the ME-vs-MadGraph validation (<1% for EW, ~1-2% for αs procs).
- **Two ntuplizers exist — pick deliberately:**
  - **`ntuple/`** is the kit's default: the official jetclass2 `makeNtuples.C` **minimally
    v1-ported**. Signature `makeNtuples(in,out,jetBranch="FatJet",genjetBranch="GenJet",
    labelIndex)`. It reads **EFlow `Track`/`Tower`** constituents (matches `delphes/card.tcl`)
    and **stamps the class via `labelIndex`** (0-9, mapped in `one_job.sh`), because the decay
    is forced per run. It does NOT gen-match. Pre-built to `makeNtuples_C.so` by `ntuple/build.sh`.
  - **`hqu_jet_gen/`** is the **exact original JetClass ntuplization** (the real upstream
    `makeNtuples.C` + its `delphes_card.tcl`). Signature `makeNtuples(in,out,jetBranch="FatJet")`.
    It reads **`ParticleFlowCandidate`** constituents (so it REQUIRES `hqu_jet_gen/delphes_card.tcl`,
    which emits a `ParticleFlowCandidate` branch + `GenFatJet` + `FatJet` + `TrackSmearing` —
    the kit's `delphes/card.tcl` does NOT produce `ParticleFlowCandidate`). It derives the
    label by **gen-matching** (`FatJetMatching::getLabel`) into enum codes (`gen_match`:
    Top_bqq=12, W_qq=21, Z_qq=33, H_bb=41, …) and writes an `is_signal` flag, applying its own
    jet selection **`PT≥500 && |η|≤2`** and **rejecting unmatched jets in signal samples**.
    Caveats when feeding it SHERPA events: (1) its includes use the `external/ExRootAnalysis/…`
    prefix (conda Delphes ships `ExRootAnalysis/…` directly under `$CONDA_PREFIX/include`, so
    the include path needs a shim); (2) `FatJetMatching` throws `std::logic_error` on
    gen-records it can't navigate, which would abort a chunk — validate on a small sample
    before scaling.
- **`delphes/card.tcl`** — the kit's JetClass-v1 card: standard CMS, no pileup, `FatJetFinder`
  = anti-kT R=0.8 (AK8) from EFlow with soft-drop + N-subjettiness, plus a grafted
  `TrackSmearing` for realistic CMS track-IP resolution (so `part_d0*/part_dz*` are real, not
  zero). `card.tcl.orig` is the pre-graft CMS card. Override per run with `DELPHES_CARD=...`.
- **`pipeline/`** — the orchestration. `one_job.sh` runs one chunk end-to-end (and maps
  class→`labelIndex`); `job.sbatch` + `submit.sh` fan it out as SLURM arrays (seed = array
  index, so chunks are statistically independent); `local_run.sh` does the same with `xargs`.

## Conventions that bite

- **One unique RANDOM_SEED per chunk** (the pipeline uses the SLURM array index). Reusing a
  seed reproduces identical events.
- The ntuplizer `_C.so` is **host/ROOT-version specific and git-ignored** — rebuild it on the
  target machine; never copy it across hosts. `00_setup_env.sh` pre-builds the `ntuple/` one.
- ROOT macros need `ROOT_INCLUDE_PATH=$CONDA_PREFIX/include` and `gSystem->Load("libDelphes")`
  before compiling/running `makeNtuples.C` (see `ntuple/build.sh` and `pipeline/one_job.sh`).
- The two ntuplizers produce **different output schemas and apply different jet cuts** — do not
  mix their `.so` or assume one's downstream code reads the other's tree.
- Generation pT cut (450 on the boson) vs the hqu ntuplizer's reco cut (jet pT≥500): with a
  450 boson cut a fraction of reco AK8 jets land below 500 and are dropped, so *events
  generated* > *jets kept*. Raise the `[PT,…,450,…]` knob toward 500 if you need yield.
- `.gitignore` excludes all build/run output (`conda_sherpa_delphes_env/`, `output/`,
  `data/`, `logs/`, `{ntuple,hqu_jet_gen}/*_C.*`, per-class
  `generation/*/{events,Process,Results*,*.log}`).
- The runtime conda **prefix env** is in-tree at **`conda_sherpa_delphes_env/`** (override
  with `JCS_ENV`); activate it directly (`conda activate "$JCS_ENV"`, via `jcs_activate`).
  `env.sh` is the single source of layout vars (`JCS_ENV`, `JCS_BUILD_ENV`, `JCS_CHANNEL_DIR`).

## NERSC Perlmutter campaign (`pipeline/nersc/`)

`pipeline/nersc/submit_all.sh` submits the whole gated chain on account `m2612`:
```
00_build.sbatch  --afterok-->  10_smoke_plan.sbatch  --(it sbatches)-->  20_generate.sbatch[] (per class)
```
- **`00_build.sbatch`** (regular QOS, 1 full CPU node): runs `00_setup_env.sh` + `ntuple/build_hqu.sh`.
- **`10_smoke_plan.sbatch`** is the validation gate + planner: runs `JCS_SMOKE_N` events/class
  through the hqu chain, aborts if any class yields 0 matched jets, else sizes each class's
  array (fixed `JCS_NTASKS=400` tasks/class, `per_job` computed from the measured jet yield to
  hit `JCS_TARGET_JETS=1e8` kept jets) and submits the production arrays itself.
- **`20_generate.sbatch`** (shared QOS, 1 task/chunk, seed = array index) runs `one_job_hqu.sh`.
- This chain uses the **hqu (exact JetClass) ntuplization**: `one_job_hqu.sh` →
  `hqu_jet_gen/delphes_card.tcl` + `hqu_jet_gen/makeNtuples.C`. The kit's own
  `pipeline/{one_job,job.sbatch,submit}.sh` use the v1-ported `ntuple/` chain instead.
- Submit caps: shared QOS allows ≤5000 jobs/user, so keep `10*JCS_NTASKS < 5000`.
- `makeNtuples.C` in `hqu_jet_gen/` carries one `[jcs]`-tagged try/catch around `getLabel`
  so a single un-navigable SHERPA gen-record skips that jet instead of aborting the chunk.

## Optional NLO (QCD) via OpenLoops

Per-process in a runcard: `NLO_Mode: MC@NLO`, `NLO_Order: {QCD: 1, EW: 0}`,
`ME_Generator: Amegic`, `RS_ME_Generator: Comix`, `Loop_Generator: OpenLoops`, then install
the loop library: `cd $CONDA_PREFIX/share/openloops && openloops libinstall ppllj`. The full
MC@NLO sample also needs SHERPA's Amegic Born libs compiled on first run in a persistent env.
