# JetClass ntuplizer (Delphes ROOT -> JetClass jet-constituent ntuple)

This is the **official JetClass-II ntuplizer** — `makeNtuples.C` + helpers from
[jet-universe/jetclass2_generation](https://github.com/jet-universe/jetclass2_generation)
(`delphes_analyzers/`) — **vendored and minimally ported for the v1 (no-pileup) classes**
this kit produces. It runs with the conda `delphes` env's ROOT (verified): it `#include`s
`classes/DelphesClasses.h` + `ExRootAnalysis/ExRootTreeReader.h` (shipped by the conda
`delphes` package) and compiles via ROOT's ACLiC with the env's `gxx`.

## What it does
Reads the AK8 `FatJet` collection from a Delphes file and writes one entry per jet in the
JetClass layout: per-constituent `part_{px,py,pz,energy,deta,dphi, d0val,d0err,dzval,dzerr,
charge,isChargedHadron,isNeutralHadron,isPhoton,isElectron,isMuon}`, jet-level
`jet_{pt,eta,phi,energy,sdmass,tau1..4,nparticles}`, gen-jet branches, and `jet_label`.

## v1 port (vs the upstream II macro)
Everything — feature formulas, `EventData`, output tree — is upstream and unchanged except
three minimal edits (all commented in-source):
1. **Constituents**: upstream reads `ParticleFlowCandidate` (PUPPI). The plain CMS card emits
   EFlow constituents as `Track`/`Tower`, so `ParticleInfo` gained `Track`/`Tower`
   constructors and the constituent loop accepts them. The EFlow collections are loaded
   (`UseBranch EFlowTrack/EFlowPhoton/EFlowNeutralHadron`) so the jet's constituent `TRef`s
   resolve (else 0 constituents).
2. **Label**: a `labelIndex` argument stamps the class directly (the decay is forced per
   run). Upstream's `FatJetMatching` is II-specific and would mark our top / multi-prong jets
   "Invalid" and drop them.
3. **Defaults**: `jetBranch=FatJet`, `genjetBranch=GenJet`.

## class -> jet_label (v1)
| 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| QCD | Hbb | Hcc | Hgg | H4q | Hqql | Zqq | Wqq | Tbqq | Tbl |

(ZJetsToNuNu=0, HToBB=1, ... TTBar=8, TTBarLep=9; `pipeline/one_job.sh` maps class->index.)

## Build / run
`00_setup_env.sh` pre-builds it (`ntuple/build.sh` -> `makeNtuples_C.so`); the pipeline then
loads that `.so`. Manually, inside the jcs env:
```bash
bash ntuple/build.sh        # compile once
ROOT_INCLUDE_PATH=$CONDA_PREFIX/include \
  root -l -b -q -e 'gSystem->Load("libDelphes");' \
       'ntuple/makeNtuples.C+("delphes.root","ntuple.root","FatJet","GenJet",6)'   # 6=Zqq
```
The `_C.so` is host/ROOT-version specific (git-ignored); rebuild it on the target machine.

## Provenance / license
`makeNtuples.C`, `FatJetMatching.h`, `EventData.h`, `ParticleID.h` are taken verbatim from
jet-universe/jetclass2_generation; `ParticleInfo.h` is that file plus the Track/Tower
constructors. Check that repo's license before redistributing this folder publicly.
