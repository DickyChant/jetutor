# JetClass — Pythia shower editions (DIRE & VINCIA)

Two more JetClass editions that **isolate the parton shower**: same MadGraph5 matrix element +
decays as the Herwig edition, same Delphes card + ntuplizer as all editions — only the Pythia 8.3
shower changes (`PartonShowers:model` = 2 VINCIA / 3 DIRE; 1 = simple/default for reference).

```
MadGraph5 LHE  (el9 container + CVMFS LCG_109a, reuses the Herwig kit)
  → Pythia 8.3 shower  (conda env; HepMC2 out — Delphes silently drops Pythia's HepMC3!)
  → DelphesHepMC2 (hqu card) → makeNtuples (FatJet, gen-matched)
  → data_<shower>/<CLASS>/<CLASS>_<seed>.root
  → rebin → official 125-file JetClass format
```

## Where things live
| path | what |
|---|---|
| `shower_lhe.cc` / `shower_lhe` | Pythia driver: LHE → shower → HepMC2. Build with `./build.sh`. |
| `cmnd/{simple,vincia,dire}.cmnd` | shower selection (+ `base`/diagnostics). |
| `gen_class_pythia.sh` | one chunk end-to-end (MG→shower→Delphes→ntuple). |
| `nersc/gen.sbatch` | production array: one class+shower per array job. |
| `nersc/submit_all.sh` | sizes + submits all 10 classes for the given shower(s). |
| `nersc/smoke.sbatch` | validation gate (resonance class through the full chain). |
| `data_vincia/`, `data_dire/` | per-chunk ntuples (before rebin). |

## Dependencies (all on Perlmutter, all in-tree)
- **`jetclass-sherpa/`** — conda env (`env.sh` + `jcs_activate`), `hqu_jet_gen/` Delphes card +
  `makeNtuples.C`, and `tools/rebin.C` + `tools/rebin.sbatch`.
- **`jetclass_herwig73_cluster/`** — MadGraph LHE producer. `gen_class_pythia.sh` calls its
  `gen_class.sh` in `JCH_LHE_ONLY=1` mode inside the el9 shifter container.
- el9 shifter image `cmssw/el9:x86_64` (already pulled) + CVMFS `/cvmfs/sft.cern.ch`.

---

## One-liners

**Build the driver** (once per host):
```bash
cd /pscratch/sd/s/sqian/jetclass_pythia_showers && ./build.sh
```

**Smoke test** (validate the full chain on a resonance class before scaling — W/Z mass must peak at 80/91):
```bash
sbatch nersc/smoke.sbatch          # -> smoke_out/{WToQQ,ZToQQ}/... for simple,vincia,dire
```

**One chunk, interactively** (debug; runs MG in-container then shower in conda):
```bash
JCP_OUT=$PWD/_test ./gen_class_pythia.sh ZToQQ 2000 999 vincia   # CLASS NEVENTS SEED SHOWER
```

**Launch full production** (both editions, or one). Sizes each class's array from the measured
reco yield to hit ~13.75M jets/class (12.5M + margin):
```bash
./nersc/submit_all.sh vincia dire      # or: ./nersc/submit_all.sh vincia
# knobs: JCP_NSUB=20000 JCP_NBATCHES=10 JCP_TARGET_JETS=13750000 JCP_QOS=shared_overrun
```

**Check status** (queue + produced chunks; full target ≈ 17860 chunks/edition):
```bash
squeue -u $USER -h -r -o "%j %t" | awk '{k=($1~/vincia/)?"VINCIA":($1~/dire/)?"DIRE":"o";t[k]++;if($2=="R")r[k]++}END{for(x in t)printf "%-7s queued=%-5d running=%d\n",x,t[x],r[x]+0}'
for s in vincia dire; do echo "$s: $(find data_$s -name '*.root'|wc -l) chunks"; done
```

**Resume / fill gaps** (jobs are resumable — existing chunks are skipped, so just resubmit;
optionally cancel stale pending arrays first):
```bash
scancel -u $USER -n jcp_vincia_ZToQQ            # (optional) drop a stale pending array
./nersc/submit_all.sh vincia dire               # re-submits 1..N; completed seeds skip instantly
```

**Rebin one edition → official format** (per-class array; identical settings to the Herwig edition:
glob `_*`, drop single-particle jets and pt>1000; no gen-match filter — MadGraph decays are exclusive):
```bash
JCS_KIT=/pscratch/sd/s/sqian/jetclass-sherpa \
JCS_INDIR=/pscratch/sd/s/sqian/jetclass_pythia_showers/data_vincia \
JCS_OUTROOT=/pscratch/sd/s/sqian/part_datasets/JetClass/PythiaVincia \
JCS_PAT="_*" JCS_MINPARTS=2 JCS_PTMAX=1000 \
sbatch --qos=shared_overrun /pscratch/sd/s/sqian/jetclass-sherpa/tools/rebin.sbatch   # array 1-10 = the 10 classes
# repeat with data_dire -> .../PythiaDire
```

**Verify + compare** (reuse the Sherpa kit's tooling once rebinned):
```bash
# counts/schema: expect 100 train + 20 test + 5 val, 100k jets/file, 41 branches per class
# feature KS vs Pythia: tools/compare.C  (see jetclass-sherpa/tools/)
```

---

## Status snapshot (2026-07, hand-off)
- **VINCIA ~53%**, **DIRE ~4%** of target; both generating on `shared_overrun` (free/preemptible).
- **m2612 (CPU) allocation is drained (0 node-hours)** → only `shared_overrun` runs, and it *starves
  when Perlmutter is busy* (multi-day stalls happen). This is the bottleneck, not the pipeline.
- **m2612_g (GPU) has balance.** To finish predictably, run the (CPU-only) pipeline on GPU nodes —
  they have 64 CPU cores; GPUs sit idle. Change `gen.sbatch` to `-C gpu -q regular --gpus=N` and pack
  ~64 tasks/node (see "GPU fallback" below). Costs GPU node-hours (~40 for VINCIA, ~100–150 for both).

## Gotchas (bit us; keep in mind)
- **Write HepMC2, not HepMC3** — Delphes silently reads Pythia's HepMC3 as 0 events. The driver uses
  `Pythia8ToHepMC::ascii2`.
- **DIRE is under-tuned for QCD jets** in Pythia 8.3 (CERN dropped it from the newer LCG view). It is
  *sound on resonances* (W/Z/H/top peaks correct) but gives softer QCD (ZJetsToNuNu) jets. Validate on
  a resonance before trusting QCD.
- **`gen.sbatch` runs on the bare node**, NOT inside shifter — `gen_class_pythia.sh` self-shifters only
  the MadGraph step, then showers/Delphes/ntuples in conda.
- **Herwig `gen_class.sh` prints the LHE path relative to WORK** — the orchestrator resolves it as
  `$WORK/$LHE`.
- One task = `JCP_NBATCHES` sub-batches of `JCP_NSUB` events; seed = `JCP_SEED_BASE + (task-1)*NB + k`.
  Keep `10*tasks_per_edition < 5000` (shared submit cap).

## GPU fallback (if CPU stays drained)
Copy `nersc/gen.sbatch` → `nersc/gen_gpu.sbatch`, swap the header to:
```
#SBATCH -A m2612_g -C gpu -q regular --gpus=4 -N1 -c 64 -t 12:00:00
```
and wrap the per-seed loop with `xargs -P 60` (or GNU parallel) so ~60 single-core chunks run
concurrently on the node's CPUs. Point `submit_all.sh` at it via a `JCP_SBATCH=nersc/gen_gpu.sbatch`
override (add one line to submit_all.sh) and submit as usual.
