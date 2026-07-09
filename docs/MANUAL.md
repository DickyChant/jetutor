# JetClass-SHERPA — manual / digest

A SHERPA reimplementation of the 10 JetClass hard-process classes. JetClass was
originally MadGraph5 + Pythia8 + Delphes; here the matrix element + parton shower +
hadronisation come from **SHERPA 3** (with **OpenLoops** as the one-loop provider), and
the detector simulation from **Delphes** — all installed as conda packages.

Pipeline:  `SHERPA -> HepMC3 -> Delphes (AK8 EFlow + IP smearing) -> makeNtuples -> JetClass ntuple`.

## The 10 classes (hard process -> SHERPA)
| Class | Hard process | Boost | Decay |
|---|---|---|---|
| HToBB / HToCC / HToGG | pp -> nu nu~ H  (ZH, Z->vv) | pT(H) > 450, abs(eta) < 2.5 | H -> bb / cc / gg |
| HToWW4Q / HToWW2Q1L | pp -> nu nu~ H | pT(H) > 450 | H -> WW -> 4q / qq lv |
| TTBar / TTBarLep | pp -> t t~ | pT(t) > 450 | t -> b qq' / t -> b l v |
| WToQQ | pp -> nu nu~ W  (WZ) | MET > 450 | W -> qq' |
| ZToQQ | pp -> nu nu~ Z  (ZZ) | MET > 450 | Z -> qq |
| ZJetsToNuNu (= q/g) | pp -> nu nu~ + jet | MET > 450 | — (light quark/gluon jet) |

- 13 TeV, PDF **NNPDF23_lo** (`nn23lo1`, lhaid 230000).
- The **MET > 450** cut is implemented as `PT > 450` on the recoiling boson/jet (= the
  missing-ET for these 2->2-like topologies).
- The boson/top decays are **forced** into each class's channel via `HARD_DECAYS`. So you
  generate *N events per class* (the JetClass convention) and the cross-section that SHERPA
  prints is the **production** xsec (which is why HToBB/CC/GG share a value).

## Matrix-element validation vs MadGraph (LO parton level, matched PDF / scale / masses)
| Production ME | σ(SHERPA) | σ(MadGraph) | agreement |
|---|---|---|---|
| ZH (5 Higgs classes) | 1.221e-4 pb | 1.221e-4 pb | **0.03%** |
| ZZ (ZToQQ) | 9.905e-4 pb | 9.969e-4 pb | **0.6%** |
| WZ (WToQQ) | 9.169e-4 pb | 9.194e-4 pb | **0.3%** |
| Z+j (q/g) | 0.1855 pb | 0.1826 pb | **1.6%** |
| tt~ (TTBar/Lep) | 561 pb | 554 pb | **1.3%** |

Pure-EW processes agree to **< 1%**; the alpha_s-dependent ones to ~1–2% (a pure
alpha_s-running *convention* — the tt~ kinematic distributions are identical). In short,
the SHERPA matrix element reproduces the MadGraph hard scattering.

## Runcard knobs  (`generation/<CLASS>/Sherpa.yaml`)
- `EVENTS` — override per run with `'EVENTS: N'`. `RANDOM_SEED` — **use a unique seed per
  chunk** (the pipeline sets it to the SLURM array index).
- `[PT, <boson/jet>, 450.0, E_CMS]` — the boost cut (raise/lower the pT window here).
- `PDF_SET` and `MPI_PDF_SET` — both `nn23lo1` (so a chunk needs only that one PDF set).
- `HARD_DECAYS: { Channels: ... }` — the per-class decay channels.
- Parton shower / hadronisation / underlying event are SHERPA defaults (on).
- **Optional NLO (QCD) via OpenLoops:** add to a process
  `NLO_Mode: MC@NLO`, `NLO_Order: {QCD: 1, EW: 0}`, `ME_Generator: Amegic`,
  `RS_ME_Generator: Comix`, `Loop_Generator: OpenLoops`, then install the loop library:
  `cd $CONDA_PREFIX/share/openloops && openloops libinstall ppllj`.
  (OpenLoops is verified working with sherpa3 — it compiles + loads the W one-loop library.
  The full MC@NLO *event* sample additionally needs SHERPA's Amegic Born libraries
  compiled on the first run in a persistent env.)

## Budgets for 100M (10M / class) — MEASURED on a 12-core box (full chain incl. Delphes)
Benchmark: all 10 classes x 10k events (100k total) ran in **14 min** (10 jobs in parallel).
Rates are **uniform** across classes — ~1.3-1.7M events/day/core — so array jobs balance
evenly; tt~ is the slowest (1.29M/day), and the boosted EW-Higgs classes are *not* a
bottleneck (1.73M/day, same as the rest).

- **CPU:** ~0.075 core-s/event -> **~2,400 CPU-hours for 100M** (SHERPA dominates; the Delphes
  + ntuplize passes add only ~seconds/chunk; drops toward ~1,700-2,000 with 50k-event jobs).
  Wall clock: ~2.4 h on 1000 cores - ~5 h on 500 cores - ~12 h on 200 cores
  (~8-10 days on a single 12-core box -> use the cluster).
- **Disk:** the kept output is the **JetClass ntuple, ~2.9 KB/jet** -> ~**280 GB for 100M
  jets** (≈ the published JetClass scale). The HepMC *and* the Delphes ROOT are transient
  (scratch) -- only the ntuple is stored. (`JCS_KEEP_DELPHES=1` also keeps the ~0.09 MB/event
  Delphes ROOT -- ~9 TB for 100M -- if you want detector-level too.)
- **SLURM sizing:** `PER_JOB=50000` -> ~60-70 min/job (fits an 8 h walltime with margin) ->
  200 jobs/class, 2000 total. One unique seed per chunk (the pipeline uses the array index).

## Delphes (detector) + ntuplizer
- **Card** (`delphes/card.tcl`): standard CMS, **no pileup**, with the `FatJetFinder`
  clustering **AK8** from EFlow (soft-drop mass + N-subjettiness computed) and a **grafted
  `TrackSmearing`** giving realistic CMS **track impact-parameter resolution** (so the
  `part_d0*/part_dz*` flavour-lifetime features are real, not zero). See `delphes/README.md`.
- **Ntuplizer** (`ntuple/makeNtuples.C`): the **official jetclass2_generation macro**,
  vendored and minimally ported for these v1 classes (reads EFlow `Track`/`Tower`
  constituents; stamps the class via `labelIndex` since the decay is forced per run). Runs
  with the conda `delphes` env's ROOT (libDelphes + ACLiC); `00_setup_env.sh` pre-builds it.
  Output = the JetClass feature layout (`part_*`, `jet_*`, `jet_label`). See `ntuple/README.md`.

class -> `jet_label`: QCD(ZJetsToNuNu)=0, Hbb=1, Hcc=2, Hgg=3, H4q(HToWW4Q)=4,
Hqql(HToWW2Q1L)=5, Zqq=6, Wqq=7, Tbqq(TTBar)=8, Tbl(TTBarLep)=9.

**Selection for training:** the ntuplizer keeps every AK8 jet with pT>120, |η|<2.5, each
stamped with the run's class. Apply the standard JetClass jet cut (pT ∈ [500,1000] GeV,
|η|<2) downstream to isolate the boosted probe jet -- and consider boosting the generation to
pT>500 (the `[PT,...,450,...]` knob) so reco jets land cleanly in that window.

## References (the actual manuals)
- **SHERPA 3** — https://sherpa-team.gitlab.io/  (run cards, NLO, hard decays, MEPS)
- **OpenLoops** — https://openloops.hepforge.org/  (process libraries, `libinstall`)
- **Delphes** — https://cp3.irmp.ucl.ac.be/projects/delphes  (cards, DelphesHepMC3, TreeWriter)
- **LHAPDF** — https://lhapdf.hepforge.org/  (`lhapdf install <set>`)
- **JetClass** (reference dataset) — https://github.com/jet-universe/particle_transformer
