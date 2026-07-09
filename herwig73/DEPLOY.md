# jetclass_herwig73_cluster — deploy guide

Self-contained kit to generate the **10 JetClass classes with Herwig 7.3**, running entirely
from a **CERN LCG view on CVMFS** — no conda, no local builds, no writable MadGraph. A port of
Huilin Qu's canonical JetClass generation (`hqu_jet_gen`) to Herwig 7.3.

```
MadGraph 3.6.4 (from CVMFS, regenerated from the JetClass proc cards; MadSpin for tt̄)  -> LHE
  -> Herwig 7.3 (LHE.in: angular-ordered shower + cluster hadronisation)                -> HepMC
  -> DelphesHepMC2 (delphes_card.tcl: AK8 EFlow + soft-drop/τ + track IP smearing)
  -> makeNtuples.C (FatJet)                                                              -> ntuple
```

## Requirements
- `/cvmfs/sft.cern.ch` mounted, **x86_64 EL9** worker nodes.
- The kit pins `LCG_109a / x86_64-el9-gcc13-opt` (Herwig 7.3.0, MG5 3.6.4, Delphes 3.5.1pre14,
  ROOT 6.38). Override with `LCG_VIEW=...` if your site uses a different path/arch.
- Nothing else. **Do not** copy this folder to a path containing a `-` hyphen if you keep the
  bundled HEFT model under it — MG5 parses `-` in a model path as a restriction tag. Underscores
  are fine (hence `jetclass_herwig73_cluster`).

## 1. Smoke test (do this first, ~10 min on one node)
```bash
source env.sh
./smoke.sh                     # all 10 classes x 10 events, sequential
```
Expect `ran end-to-end: 10 / 10` and a `data/<CLASS>/<CLASS>_99.root` per class.

## 2a. Generate on SLURM (recommended)
```bash
# optional but recommended: measure jets/event so chunking is sized well
NCAL=1500 ./calibrate.sh                      # -> logs/cal_yield.txt

# build tasks.txt and submit a job array (one chunk per task, node-local scratch)
TARGET=10000 CHUNK=5000 ./slurm/submit.sh     # ~10k jets/class
# ... wait for the array to finish ...
./slurm/merge.sh                              # hadd chunks -> data/<CLASS>/<CLASS>_merged.root + yield
```
Edit the `#SBATCH` lines in `slurm/job.sbatch` (time/mem/partition/account) for your site.
Each task is independent and writes only the small ntuple to shared disk; the multi-GB HepMC +
Delphes ROOT stay in `$TMPDIR` and are deleted per task — **no shared-disk pressure**.

For the full **100k jets/class**: `TARGET=100000 CHUNK=20000 ./slurm/submit.sh`.

## 2b. Generate on a single box (no batch system)
```bash
source env.sh
TARGET=10000 NPAR=3 ./run_all.sh
```
⚠️ Single-box only: the HepMC is transient but large (~190 KB/event). `run_all.sh` sets a
**disk gate** (`JCH_MIN_FREE_MB`, default 14 GB) so a class won't start showering unless scratch
can hold another HepMC, and deletes each HepMC right after Delphes. Keep `NPAR` small (2–3) unless
you have lots of `$JCH_SCRATCH`. (On SLURM this is irrelevant — set `JCH_MIN_FREE_MB=0`.)

## The 10 classes
All boosted via `misset 450` (the resonance recoils against the invisible `ve ve~`, so MET>450 ⇔
pT>450; MadGraph's `pt_min_pdg` is ignored on the *intermediate* Higgs, so we cut on MET instead).

| Class | MadGraph | Model | Notes |
|---|---|---|---|
| HToBB / HToWW4Q / HToWW2Q1L | `p p > ve ve~ h, h>…` | sm | decay chain inline |
| HToCC | `p p > ve ve~ h, h>cc` | **sm-full** | charm Yukawa (zeroed in plain sm) |
| HToGG | `p p > ve ve~ h, h>gg` | **HEFT** (bundled `models/heft`) | effective ggH |
| TTBar / TTBarLep | `p p > t t~` | sm | **MadSpin** `t>bjj` / `t>blν` |
| WToQQ / ZToQQ | `p p > ve ve~ w/z, →jj` | sm | MET>450 |
| ZJetsToNuNu | `p p > ve ve~ j` † | sm | light q/g jet |

† Original JetClass uses MLM-merged `@0/@1`; the merging card is absent upstream, so this kit uses
the LO single-jet recoil. Swap in a merged setup if you need the exact ZJetsToNuNu spectrum.

## Output
`data/<CLASS>/<CLASS>_<seed>.root` — JetClass `FatJet` ntuple, one entry per AK8 jet (pT>500,
|η|<2): per-constituent `part_*` (incl. d0/dz impact parameters), `jet_*`, soft-drop mass,
N-subjettiness, plus the matched `gen_match` label. `tally.sh` reports per-class jet counts.

## Files
```
env.sh           source the LCG view (LCG_VIEW), Herwig repo, ROOT includes, scratch
gen_class.sh     one class, all 5 stages (the only generator script — all 10 classes)
run_all.sh       single-box parallel runner (auto-sized, disk-gated)
calibrate.sh     measure jets/event -> logs/cal_yield.txt
smoke.sh         10-event end-to-end check for all 10 classes
tally.sh         count jets per class from the ntuples
slurm/job.sbatch one array task = one chunk (node-local scratch)
slurm/submit.sh  build tasks.txt + sbatch the array
slurm/merge.sh   hadd per-class chunks + tally
LHE.in.tmpl      Herwig LHE steering   delphes_card.tcl  JetClass Delphes card
makeNtuples.C    FatJet ntuplizer (W→τν crash guarded)   madspin/  tt̄ decay cards
models/heft/     bundled HEFT model for HToGG
```

## Notes / gotchas baked in
- Herwig's compiled-in `.rpo` path is stale → `env.sh` points `--repo` at the view's real tree.
- Herwig writes HepMC2-style `GenEvent` → read with `DelphesHepMC2` (not `…3`).
- `makeNtuples.C` runs interpreted; `FatJetMatching` would `throw` on W→τν / stray heavy partons,
  so the per-jet label call is wrapped in try/catch (falls back to QCD). Don't remove that.
- Single-box `df` free-space check uses `df -P` (long device names wrap plain `df`).
