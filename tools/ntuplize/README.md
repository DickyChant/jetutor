# jet-gen

`makeNtuples.C` is Huilin Qu's JetClass ntuplizer, plus gen-level truth and the pion mass for charged hadrons.
`herwig73/makeNtuples.C` is the same file with Herwig's include path and its own exception fallback. Keep the
two in sync with each other and with `jetclass_generation`.

```
root -l -b -q 'makeNtuples.C("delphes.root","out.root","FatJet", genHistoryMode=1, chargedHadronPionMass=true)'
```

## Particle masses

- `chargedHadronPionMass` (default `true`) follows CMS particle flow. Every charged candidate that is not an e or μ
  gets the pion mass at fixed track momentum. Delphes otherwise gives it its true mass, and E² − p² then identifies
  kaons and protons.
- Neutral hadrons and photons are massless (E = |p|), as in both Delphes and CMS PF.
- `false` reproduces the official JetClass `part_*` exactly.
- Gen-level kinematics use the stored four-momentum, never `GenParticle::Mass`. The Delphes HepMC readers rescale
  a file written in MeV to GeV but copy the mass field unscaled.

## Gen-level truth

- `genjet_*`: the closest `GenFatJet` within ΔR < 0.4 of the reco jet (`genjet_matched=0`, `genjet_dr=-1` when
  none).
- `genjet_part_*`: its constituents, pT-sorted. `deta`/`dphi` are measured from the reco jet axis, like `part_*`.
- `genjet_hist_*`: the generator history of those constituents, a GEN-only port of the CMS MC-truth graph
  (cmssw `PhysicsTools/TruthInfo`). The nodes are the constituents and all their ancestors, ordered by the Delphes
  `Particle` index. Edges are `genjet_hist_edge_mother`/`_daughter` (local indices).
  - Per node: `statusflags` (reco::GenStatusFlags bits, as NanoAOD `GenPart_statusFlags`), `levelflags`
    (`truth::LevelFlag` bits), `vtx` (shared production vertex), `vtxreason` (`truth::VertexReason`:
    Decay=2, HardScatter=17, ShowerBranching=18, Hadronization=19).
  - `genHistoryMode`:

    | mode | what's kept | ttbar nodes/jet (Pythia / Herwig / Sherpa) |
    |---|---|---|
    | 0 | full record | 709 / 288 / 395 |
    | 1 (default) | CMS main-event default: 1→1 copy chains merged | 371 / 267 / 393 |
    | 2 | shower collapsed, as CMS does for pileup | 143 / 131 / 168 |

- Generator dependence. The CMS rules assume Pythia status codes.
  - HardProcess, PartonJets and the HardScatter reason need `isHardProcess`: Pythia status 21–29, or the status 3
    Sherpa gives its 2→2 legs (so Sherpa's HardProcess level is the tops, not their decay products). Herwig marks
    none, so these are empty for Herwig.
  - B/C hadrons, taus, the visible final state and the per-jet Signal level are generator-independent.
  - Herwig clusters (81) count as hadronization objects and ThePEG remnants (82) as beam pseudoparticles.
- Sherpa writes the parton shower as one vertex whose outputs include the incoming hard-process partons, so its
  record has cycles.
  - The graph drops the mother links that close them and reports the count at the end of the job.
  - Every Sherpa shower parton formally descends from all the hard partons at once, so ancestry through a Sherpa
    shower is coarse.
