# jetclass-sherpa — cluster kit

End-to-end, conda-based pipeline to generate a **SHERPA edition of the 10 JetClass
hard-process classes** and push them through Delphes:

```
sherpa3 + openloops   (ME + parton shower + hadronisation + UE  ->  HepMC3)
   ->  Delphes (AK8 EFlow + track IP smearing)  ->  makeNtuples  ->  JetClass jet-constituent ntuple
```

Everything lives under this folder, installed with NERSC's native conda (`module load conda`)
into an in-tree prefix env; nothing in `$HOME`, no admin.
The whole chain — SHERPA→HepMC→Delphes→ntuple (the official jetclass2 ntuplizer) — has been verified locally.

## 1. Setup (once, on the cluster)
```bash
./00_setup_env.sh
```
`module load conda`, builds the `openloops` + `sherpa3` conda packages from `packaging/`,
makes the runtime prefix env `conda_sherpa_delphes_env/` with `sherpa3` + `delphes`, installs
the `nn23lo1` PDF, and drops a default Delphes card in `delphes/card.tcl`. (~30–60 min, mostly
the sherpa3 C++ build. If you publish the packages to a channel,
`JCS_CHANNEL=<url> ./00_setup_env.sh` skips the build.) On NERSC, run it in a batch job —
`pipeline/nersc/submit_all.sh` does.

## 2. Smoke test (one chunk, full chain)
```bash
source env.sh && jcs_activate                # module load conda + conda activate the prefix env
./pipeline/one_job_hqu.sh ZToQQ 200 1        # -> data/ZToQQ/ZToQQ_000001.root  (exact JetClass ntuple)
```

## 3. Scale to 100M
```bash
# SLURM (tune PER_CLASS / PER_JOB to your walltime):
PER_CLASS=10000000 PER_JOB=50000 ./pipeline/submit.sh     # 10 classes x 10M = 100M
# no batch system:
./pipeline/local_run.sh ZToQQ 100000 20 8                  # 20 chunks x 100k, 8 in parallel
```
Outputs: `data/<CLASS>/<CLASS>_<seed>.root` — **JetClass jet-constituent ntuples** (the
training format). HepMC + Delphes ROOT are transient (scratch); only the ntuple is kept
(`JCS_KEEP_DELPHES=1` to also keep the Delphes ROOT). ~2.9 KB/jet -> ~280 GB for 100M.

## What's inside
```
00_setup_env.sh   one-time setup (module load conda + build packages + prefix env + PDF + card)
packaging/        openloops + sherpa3 conda recipes (built by 00_setup_env.sh)
generation/       10 class runcards + run.sh (SHERPA -> HepMC3, self-contained on nn23lo1)
delphes/          JetClass Delphes card (AK8 EFlow + soft-drop/tau + grafted IP smearing)
ntuple/           official jetclass2 makeNtuples.C (v1-ported) + helpers + build.sh
pipeline/         one_job.sh (per chunk) | job.sbatch + submit.sh (SLURM) | local_run.sh
docs/MANUAL.md    full digest: class->process map, ME validation, ntuplizer, budgets, refs
```

**Read `docs/MANUAL.md` before a large campaign** — it has the 10-class process map, the
SHERPA-vs-MadGraph validation, the runcard knobs (incl. optional NLO via OpenLoops), and
the disk/CPU budget for 100M.
