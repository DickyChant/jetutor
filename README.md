# jetutor

*JetClass, taught by different tutors.* Byte-compatible re-creations of the public
[JetClass](https://github.com/jet-universe/particle_transformer) dataset (10 boosted-jet classes,
100k jets/file, official one-hot schema) using **different shower / hadronisation models**, so jet
taggers can be stress-tested for generator robustness. Every edition shares the *same* Delphes
detector card and the *exact* JetClass ntuplization — **only the generator physics changes**.

## Editions

| dir | edition | generator chain |
|---|---|---|
| [`sherpa/`](sherpa/) | **Sherpa 3** | Sherpa ME + CS-dipole shower + cluster hadronisation (OpenLoops loop provider) |
| [`herwig73/`](herwig73/) | **Herwig 7.3** | MadGraph5 ME → Herwig angular-ordered shower + cluster hadronisation |
| [`pythia_showers/`](pythia_showers/) | **Pythia + VINCIA / DIRE** | MadGraph5 LHE → Pythia 8.3 antenna (VINCIA) or dipole (DIRE) shower + string hadronisation |

Together with the official **Pythia8** reference these span two axes of variation: full-generator
swaps (Sherpa, Herwig) and shower-only swaps holding the ME + hadronisation fixed (DIRE, VINCIA).

## Shared layer

- [`tools/`](tools/) — format + comparison tooling used by every edition: `rebin.C` (hqu ntuples →
  official 125-file JetClass layout), `compare.C` (feature-distribution KS), `verify.C` (integrity),
  and [`tools/ntuplize/`](tools/ntuplize/) — the canonical **exact-JetClass** Delphes card
  (`delphes_card.tcl`) + `makeNtuples.C` (Huilin Qu's ntuplizer). All editions produce identical
  detector-level jets; only the upstream physics differs. The ntuplizer (and its `herwig73/` copy)
  also writes gen-level truth and gives charged hadrons the pion mass, as CMS particle flow does;
  `chargedHadronPionMass=false` restores the official JetClass `part_*` features. See
  [`tools/ntuplize/README.md`](tools/ntuplize/README.md).

## Docs

- [`docs/MANUAL.md`](docs/MANUAL.md) — class → process map, ME validation.
- [`docs/sherpa_decay_fix.md`](docs/sherpa_decay_fix.md) — the Sherpa `HARD_DECAYS` bugs & validated fixes.
- [`docs/slides/`](docs/slides/) — the comparison deck (`jetclass_editions.typ`); rendered to a PDF and
  published to **GitHub Pages** by [`.github/workflows/slides.yml`](.github/workflows/slides.yml) on
  every push to `main`.

## Running

Each edition dir is self-describing (README/DEPLOY + NERSC decks). All were produced on **NERSC
Perlmutter**. Typical flow per edition: generate (SLURM arrays) → `tools/rebin` → `tools/verify` →
`tools/compare`. Big artifacts (datasets, conda envs, HepMC, logs) are intentionally *not* tracked —
this repo is code + configs only.
