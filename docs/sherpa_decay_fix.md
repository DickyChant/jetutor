# Sherpa edition — decay-forcing bug & fix (June 2026)

## Symptom
External validation (`sqian.web.cern.ch/jetclass_summary/diagnosis.txt`) found the Sherpa
dataset has 10 labels but only **6 physically distinct classes** — the classes that differ
*only by a forced decay* collapsed into 3 groups:

| group | classes | what they actually are |
|---|---|---|
| 1 | HToBB ≡ HToCC ≡ HToGG | all h→WW\* (gen_match 45), sdmass≈107, nparts≈47 |
| 2 | HToWW4Q ≡ HToWW2Q1L | h→WW\* (gen_match 45), sdmass≈110 |
| 3 | TTBar ≡ TTBarLep | hadronic top (gen_match 12), sdmass≈169 |

WToQQ / ZToQQ / ZJetsToNuNu are fine (distinct).

## Root causes (Sherpa silently drops decay channels it can't build)
1. **Higgs bb/cc/gg (group 1):** Sherpa's LO `HARD_DECAYS` computes the Higgs partial widths
   from the model couplings, and the **quark Yukawa couplings are zero by default** (5-flavour
   massless-quark scheme) → the decay table shows `Flavour width: 0 GeV` and **no** `25,5,-5`
   (h→bb), `25,4,-4` (h→cc). Our `Channels: {25,5,-5: {Status: 2}}` forced a channel that
   *did not exist* → silently ignored → fallback to the default gauge decays h→WW\*.
2. **Higgs WW (group 2):** the configs force `25,24,-24` (h→WW as a **2-body** decay). With
   m_H=125 < 2·m_W, the Higgs WW is off-shell, so the 2-body channel does **not exist** → again
   ignored → fallback to default → collapse with group 1.
3. **ttbar (group 3):** the W-from-top sub-decay forcing did not differentiate hadronic vs
   leptonic (both ended up hadronic) — needs the top channel (`6,5,24`) handled together with
   the W channels. (Under investigation.)
4. **`Use_HO_SM_Widths: true`** is *not* a workaround — it fatals ("masses not in SM range")
   because of our `PARTICLE_DATA` overrides.

## VALIDATED fix — quark Yukawa (Higgs bb/cc)
Add the quark Yukawa coupling + `Apply_Branching_Ratios: false` (per the official
`$SHERPA/Examples/H_in_TTBar/LHC_TTH_MCatNLO/Sherpa.yaml`):

**HToBB:**
```yaml
PARTICLE_DATA: {25: {Mass: 125.0, Width: 0}, 6: {Width: 0}, 5: {Yukawa: 4.92}}
HARD_DECAYS:
  Enabled: true
  Use_HO_SM_Widths: false
  Apply_Branching_Ratios: false
  Channels: {25,5,-5: {Status: 2}}
```
→ decay table now shows `25,5,-5  h0 --> b bb  BR= 67.6%` (was ABSENT); Status:2 forces it to 100%.

**HToCC:** same with `4: {Yukawa: 1.42}` and `Channels: {25,4,-4: {Status: 2}}`
→ `25,4,-4  h0 --> c cb  BR= 7.5%` (was ABSENT), forced to 100%.

## VALIDATED fix — HToGG (loop-induced, like h→γγ)
h→gg has no tree-level coupling; use the effective theory `MODEL: HEFT` (same as the official
`H_in_GluonFusion` h→γγ example, which forces `25,22,22`):
```yaml
MODEL: HEFT
PARTICLE_DATA: {25: {Mass: 125, Width: 0}, 6: {Width: 0}}
HARD_DECAYS: {Enabled: true, Apply_Branching_Ratios: false, Channels: {25,21,21: {Status: 2}}}
```
→ `25,21,21  h0 --> G G  BR= 42.0%` (was ABSENT), forced to 100%.

## VALIDATED fix — HToWW4Q / HToWW2Q1L (off-shell, use 3-body channels)
Drop the invalid 2-body `25,24,-24`; force the *existing* 3-body h→W\*+ff channels + the
on-shell W decay. For **4Q** force the hadronic ones on both sides:
```yaml
HARD_DECAYS:
  Enabled: true
  Apply_Branching_Ratios: false
  Channels:
    25,-24,2,-1: {Status: 2}   # h -> W-(on) + u db (W+* hadronic)
    25,-24,4,-3: {Status: 2}
    25,24,-2,1: {Status: 2}     # h -> W+(on) + ub d
    25,24,-4,3: {Status: 2}
    24,2,-1: {Status: 2}        # on-shell W -> qq
    24,4,-3: {Status: 2}
    -24,-2,1: {Status: 2}
    -24,-4,3: {Status: 2}
```
→ the 3-body h→W\*+qq channels are now forced (leptonic ones auto-disabled). For **2Q1L**, mix:
keep the h→W\*+qq (off-shell hadronic) and force the on-shell W→ℓν (`24,-11,12`, `24,-13,14`, …).

## ALSO: leptonic channel ORDER bug (was wrong in the originals too)
Sherpa orders a leptonic W channel as **(W, nu, lepton)**: `24,12,-11` = W+ -> ve e+.
The original configs (and the first fix attempt) wrote `24,-11,12` (lepton first) -> the
channel did not match -> silently dropped -> fell back to hadronic W. Hadronic channels
`24,2,-1` happened to be in the right order, which is why only the leptonic classes broke.
Correct leptonic channels: `24,12,-11`, `24,14,-13`, `-24,-12,11`, `-24,-14,13`.

## FULL-CHAIN VALIDATION (Sherpa -> Delphes -> hqu ntuple, gen_match mode)
All 6 corrected `generation/<CLASS>/Sherpa.yaml` produce the correct label (originals saved
as `Sherpa.yaml.broken`):

| class | gen_match | result |
|---|---|---|
| HToBB | 41 H_bb | 100% |
| HToCC | 42 H_cc | 100% |
| HToGG | 44 H_gg | 100% |
| HToWW4Q | 45 H_ww4q | 100% |
| HToWW2Q1L | 46 H_ww2q1l | 100% |
| TTBarLep | 15/16 Top_bℓν | 100% leptonic (e/μ split) |

TTBar, WToQQ, ZToQQ, ZJetsToNuNu were already correct. **All 10 classes now distinct.**
Next: regenerate the 6 fixed classes (m2612 at 0 node-hours -> `shared_overrun`) and re-run
the rebin/verify/compare. Configs are committed and ready.

## Summary of the fix per class
| class | fix (added to the working yaml) |
|---|---|
| HToBB | `PARTICLE_DATA … 5: {Yukawa: 4.92}` + `Apply_Branching_Ratios: false` |
| HToCC | `4: {Yukawa: 1.42}` + `Apply_Branching_Ratios: false` |
| HToGG | `MODEL: HEFT` + `Apply_Branching_Ratios: false` |
| HToWW4Q | replace `25,24,-24` with 3-body h→W\*+qq + on-shell W→qq |
| HToWW2Q1L | 3-body h→W\*+qq + on-shell W→ℓν (mixed) |
| TTBarLep | force **only** W→ℓν (remove the W→qq channels) |
All keep `Channels … {Status: 2}` and `Apply_Branching_Ratios: false`.

## Note
Sherpa cannot ingest MadGraph LHE, so the fix must be pure-Sherpa (above). Regeneration of the
6 affected classes is needed once the decay configs are validated — but the m2612 allocation is
at 0 node-hours (use `shared_overrun` or a fresh allocation).
