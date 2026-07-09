# Delphes card

`card.tcl` is the **shipped JetClass-v1 detector card**: the standard Delphes CMS card
(no pileup, particle-flow / EFlow) with two things that matter for JetClass —

- the `FatJetFinder` clusters **anti-kT R=0.8 (AK8)** from `EFlowMerger/eflow` with
  **N-subjettiness + soft-drop** computed (→ `jet_sdmass`, `jet_tau1..4`), and
- a **`TrackSmearing`** module grafted in from the JetClass-II card, giving realistic CMS
  **track impact-parameter resolution** (`D0/DZ` + `ErrorD0/ErrorDZ`). Without it the
  `part_d0*/part_dz*` displacement features (the b/c-lifetime discriminants for Hbb/Hcc/Tbqq)
  would be identically zero.

`card.tcl.orig` is the unmodified CMS card (before the `TrackSmearing` graft), kept for
reference. The ntuplizer reads the `FatJet` collection from this card's output.

## Using a different card
The pipeline reads `delphes/card.tcl` by default; override per run without touching it:
```bash
DELPHES_CARD=/path/to/your_card.tcl ./pipeline/one_job.sh ZToQQ 50000 1
```
If you swap in another card, make sure it still emits an AK8 jet branch named `FatJet`
(or pass a different `jetBranch` to `makeNtuples.C`) with soft-drop + N-subjettiness, and a
`TrackSmearing` step for the impact-parameter features.

The pipeline invokes `DelphesHepMC3 <card> <delphes.root> <hepmc>` (in scratch); the Delphes
ROOT is transient — only the JetClass ntuple is kept.
