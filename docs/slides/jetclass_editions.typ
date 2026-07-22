// JetClass — five generator editions (Pythia / Sherpa / Herwig 7.3 / +DIRE / +VINCIA)
// Self-contained Typst slides (no external packages). Compile: typst compile jetclass_editions.typ
#set page(width: 25.4cm, height: 14.29cm, margin: (x: 1.4cm, y: 1.1cm), fill: white)
#set text(font: "DejaVu Sans", size: 15pt, fill: rgb("#1a1a1a"))
#set par(leading: 0.7em)
#show heading.where(level: 1): set text(size: 24pt, fill: rgb("#0b3d91"))
#let accent = rgb("#0b3d91")
#let good = rgb("#1a7f37")
#let warn = rgb("#b35900")

#let slide(title, body) = {
  pagebreak(weak: true)
  block(inset: (bottom: 0.3em), stroke: (bottom: 1.2pt + accent),
        text(size: 22pt, fill: accent, weight: "bold", title))
  v(0.4em)
  body
}
#let kv(k, v) = box[#text(fill: accent, weight: "bold")[#k] #v]
#let chip(c, t) = box(fill: c.lighten(80%), inset: (x: 5pt, y: 2pt), radius: 3pt, text(fill: c, size: 12pt, t))

#let plotslide(title, img, caption) = {
  pagebreak(weak: true)
  block(inset: (bottom: 0.25em), stroke: (bottom: 1.2pt + accent),
        text(size: 20pt, fill: accent, weight: "bold", title))
  v(0.25em)
  align(center, image(img, height: 80%))
  align(center, text(size: 11.5pt, fill: gray, caption))
}
#let plotslide2(title, imgA, imgB, caption) = {
  pagebreak(weak: true)
  block(inset: (bottom: 0.25em), stroke: (bottom: 1.2pt + accent),
        text(size: 20pt, fill: accent, weight: "bold", title))
  v(0.25em)
  grid(columns: 2, gutter: 10pt, align: center,
    image(imgA, width: 100%), image(imgB, width: 100%))
  align(center, text(size: 11.5pt, fill: gray, caption))
}

// ───────────────────────── TITLE ─────────────────────────
#align(center + horizon)[
  #text(size: 34pt, fill: accent, weight: "bold")[JetClass, five ways]
  #v(0.2em)
  #text(size: 18pt)[Pythia · Sherpa · Herwig 7.3 · +DIRE · +VINCIA — one format, five shower / hadronisation models]
  #v(1.2em)
  #grid(columns: 4, gutter: 10pt,
    chip(accent, "NERSC Perlmutter (m2612)"), chip(accent, "Delphes + AK8"),
    chip(accent, "exact JetClass ntuplization"), chip(accent, "125M jets / edition"))
  #v(1.6em)
  #text(size: 13pt, fill: gray)[Generator robustness datasets for jet tagging · June 2026]
]

// ───────────────────────── GOAL ─────────────────────────
#slide("Goal — two axes of generator variation", [
  The public *JetClass* (100M jets, 10 boosted classes) was made with *MadGraph5 + Pythia8 + Delphes*.
  Tagger robustness to the *shower / hadronisation model* is a known concern, so we rebuild it in
  *byte-compatible format* along two axes:
  #v(0.3em)
  #grid(columns: 2, gutter: 14pt,
    box(fill: good.lighten(85%), inset: 9pt, radius: 5pt)[
      *Full-generator swaps* #linebreak()
      *Sherpa 3* (own ME + CS-dipole shower + cluster hadr.) · *Herwig 7.3* (MG5 ME → angular-ordered
      shower + cluster hadr.)],
    box(fill: accent.lighten(88%), inset: 9pt, radius: 5pt)[
      *Shower-only swaps inside Pythia* #linebreak()
      same MG5 ME + string hadronisation, change *only the shower*: *DIRE* (dipole) and *VINCIA*
      (antenna) — clean isolation of the shower],
  )
  #v(0.4em)
  All six datasets (Pythia + 5 ours) share the *identical Delphes card, AK8 jets, and exact JetClass
  ntuplizer* (Huilin Qu's `makeNtuples`) — *125M jets* each, official layout (100k/file, train 100M +
  test 20M + val 5M), cross-comparable feature-by-feature.
])

// ───────────────────────── PIPELINE ─────────────────────────
#slide("Pipelines", [
  #v(0.2em)
  #align(center, box(fill: luma(245), inset: 11pt, radius: 6pt, text(size: 13.5pt)[
    *ME + parton shower + hadronisation* #h(0.4em) → #h(0.4em) *HepMC* #h(0.4em) → #h(0.4em)
    *Delphes* (AK8 EFlow, soft-drop, $tau_N$, track-IP smearing) #linebreak()
    → #h(0.4em) *makeNtuples* (gen-matched label) #h(0.4em) → #h(0.4em)
    *rebin* → 100k-jet files, train / test / val
  ]))
  #v(0.4em)
  #grid(columns: 3, gutter: 12pt,
    [ *Sherpa* #linebreak() #text(size: 12.5pt)[NERSC native conda (OpenLoops + Sherpa 3 pkgs); ME+PS+hadr.
       all from Sherpa → HepMC3 → Delphes.] ],
    [ *Herwig 7.3* #linebreak() #text(size: 12.5pt)[el9 shifter container + CVMFS LCG_109a; MadGraph 3.6.4 →
       Herwig 7.3 → DelphesHepMC2.] ],
    [ *DIRE / VINCIA* #linebreak() #text(size: 12.5pt)[reuse the *same MG5 LHE* (container) → Pythia 8.3
       shower (`model`=dire/vincia, conda) → HepMC2 → Delphes.] ],
  )
  #v(0.3em)
  #text(size: 12.5pt, fill: gray)[Reusing the Herwig MG5 LHE for DIRE/VINCIA means *only the shower differs* —
   and it sidesteps Sherpa's decay-forcing entirely (MG5+MadSpin make the decays).]
])

// ───────────────────────── DATASETS ─────────────────────────
#slide("The datasets", [
  #v(0.2em)
  #table(columns: (auto, auto, auto, 1fr), inset: 6pt, align: (left, center, right, left),
    stroke: 0.5pt + luma(200),
    table.header([*Edition*], [*Status*], [*Jets*], [*Generation*]),
    [Pythia (official)], [#text(fill: good)[ref]], [125 M], [MG5 + Pythia8 simple shower],
    [*Sherpa* (ours)], [#text(fill: good)[done]], [125 M], [Sherpa 3 + OpenLoops (decay fixes, see next)],
    [*Herwig 7.3* (ours)], [#text(fill: good)[done]], [125 M], [MG5 + Herwig 7.3 angular-ordered],
    [Herwig (orig.)], [#text(fill: good)[ref]], [125 M], [MG5 + older Herwig (JetClass authors)],
    [*Pythia+VINCIA* (ours)], [#text(fill: good)[done]], [125 M], [MG5 LHE + Pythia VINCIA antenna shower],
    [*Pythia+DIRE* (ours)], [#text(fill: good)[done]], [125 M], [MG5 LHE + Pythia DIRE dipole shower],
  )
  #v(0.4em)
  Each: *10 classes × 12.5M jets*, batched SLURM arrays (transient HepMC on pscratch, cleaned per
  sub-batch). Pythia/Sherpa/Herwig integrity-*verified* (#text(fill: good)[ALL GOOD]): file/entry counts,
  41 branches, one-hot labels & particle types. All six editions now complete and verified.
])

// ───────────────────────── SHERPA DECAY BUG ─────────────────────────
#slide("Sherpa caveat — forced decays that silently fail", [
  #set text(size: 13.5pt)
  Sherpa's `HARD_DECAYS` *silently drops a forced channel it cannot build* and falls back to the
  default decay — so *6/10 classes initially collapsed* (HToBB≡CC≡GG, HToWW4Q≡2Q1L, TTBar≡TTBarLep).
  Root causes + fixes:
  #v(0.2em)
  #grid(columns: 2, gutter: 14pt,
    [
      - *h→bb / cc* — quark Yukawa = 0 by default → inject `PARTICLE\_DATA … Yukawa`.
      - *h→gg* — loop-induced → `MODEL: HEFT` (like h→γγ).
      - *h→WW\** — off-shell, 2-body invalid → force the *3-body* `25,∓24,q,q'` channels.
      - *Leptonic W* — order must be (W, ν, ℓ); reversed → silently hadronic.
    ],
    [
      - *Verify the label, not that it ran:* gen-match every class.
      - All fixes validated end-to-end (`gen\_match` 100% correct), regenerated, re-rebinned →
        *all 10 classes now distinct & verified.*
      #v(0.2em)
      #text(fill: warn)[The semileptonic HToWW2Q1L needed one more fix → next slide.]
    ],
  )
])

#plotslide("HToWW2Q1L — the soft-drop mass you flagged", "figs/ww2q1l_fix.png",
  [Forcing the exclusive decay pinned the hadronic quark pair to the *off-shell* W\* (~45 GeV) every
   event; the escaping ν means the jet mass tracks only the hadronic W, so m#sub[SD] peaked ~25 GeV LOW
   (red, peak 73). Fix: force only h→WW\* (BR-weighted) and let each W decay *naturally* → physical
   on/off-shell mix (green, peak 102, matching Pythia 98). Now generated, rebinned & swapped in.])

// ───────────────────────── SHERPA vs PYTHIA ─────────────────────────
#slide("Validation — Sherpa vs Pythia", [
  Feature-distribution KS distance (averaged over 10 classes). *Close everywhere* — the small,
  expected signature of a different ME + shower + hadronisation:
  #v(0.3em)
  #grid(columns: 2, gutter: 18pt,
    [
      *Differ most (substructure):*
      #table(columns: (1fr, auto), inset: 5pt, stroke: 0.4pt + luma(220),
        [jet\_sdmass], [0.113], [jet\_tau2], [0.085], [jet\_tau3], [0.081],
        [jet\_nparticles], [0.080], [tau21], [0.037])
    ],
    [
      *Agree closely (kinematics, detector):*
      #table(columns: (1fr, auto), inset: 5pt, stroke: 0.4pt + luma(220),
        [jet\_pt], [0.016], [jet\_eta], [0.003], [part\_deta], [0.016],
        [part\_d0val], [0.008], [isElectron/Muon], [0.004])
    ],
  )
  #v(0.3em)
  Per-class mean KS *0.022–0.073*. Jet *kinematics, IP, and particle composition* match tightly; the
  residual — small (≤0.11) — lives in *substructure*, led by soft-drop mass.
])

// ───────────────────────── MASS STUDY ─────────────────────────
#plotslide("Soft-drop mass, all 10 classes × 4 generators", "figs/sdmass_all10.png",
  [Every class peaks at the *right resonance* (Higgs ~123, top 169, W 81, Z 90; QCD falls off).
   Pythia, Herwig 7.3 and original Herwig sit almost on top of each other; *Sherpa* (red) grooms to a
   *slightly harder, narrower* peak across all classes — a coherent ~0.1-KS shower signature, not a bug.])

#slide("Why Sherpa grooms harder — it's the recoil, not the emissions", [
  #set text(size: 13.5pt)
  A natural guess: Sherpa's *dipole shower* emits less. The data says otherwise —
  #v(0.2em)
  #grid(columns: (1fr, 1fr), gutter: 16pt,
    [
      - Constituent *multiplicity is comparable* to Pythia (Herwig 7.3 is actually the lowest); Sherpa
        constituents are if anything slightly *softer*.
      - The *ungroomed* jet mass is identical across generators; the difference appears *only after
        soft-drop* (Sherpa loses ~2.5 GeV less to grooming).
    ],
    [
      - Groomed jet mass is the textbook probe of the *shower recoil scheme*. Sherpa's *CS-dipole local
        recoil* redistributes emission momentum differently from Pythia's pT-ordered and Herwig's
        angular-ordered showers → a harder groomed peak.
      - Not a generic "dipole" effect: Pythia is *also* dipole-based yet clusters with Herwig. It's
        *Sherpa's specific CS-recoil + tune*.
    ],
  )
  #v(0.2em)
  #text(fill: accent)[This is exactly the question the DIRE / VINCIA editions are built to answer
   cleanly — swap the shower, hold everything else fixed.]
])

// ───────────────────────── HERWIG ─────────────────────────
#slide("Validation — Herwig 7.3 vs everything", [
  #v(0.1em)
  #table(columns: (auto, auto, 1fr), inset: 6pt, stroke: 0.5pt + luma(200), align: (left, center, left),
    table.header([*Comparison*], [*top-feature KS*], [*Reading*]),
    [Herwig73 *vs Pythia*], [nparts 0.095, $tau_4$ 0.081],
      [#text(fill: good)[Very close] — both mature general-purpose showers; kinematics KS\<0.02],
    [Herwig73 *vs Sherpa*], [nparts 0.129, $tau_4$ 0.124],
      [#text(fill: warn)[Slightly more] — distinct ME + shower + hadronisation],
    [Herwig73 *vs orig. Herwig*], [nparts 0.107, $tau_4$ 0.094],
      [#text(fill: good)[Reproduces] the JetClass authors' (older) Herwig],
  )
  #v(0.4em)
  Per-class mean KS: *vs Pythia 0.008–0.046*, *vs origHerwig 0.016–0.036*, *vs Sherpa 0.029–0.071* —
  all tight. *Herwig 7.3 ≈ Pythia* at jet level and faithfully reproduces the original JetClass Herwig;
  *Sherpa* sits a little further out but still close. Residuals live in *multiplicity & N-subjettiness*,
  never in kinematics/IP (KS\<0.02).
])

// ───────────────────────── DIRE / VINCIA ─────────────────────────
#slide("Shower isolation — the DIRE & VINCIA editions", [
  #set text(size: 13.5pt)
  Same MG5 matrix element, same string hadronisation, same Delphes — *change only the Pythia 8.3
  shower*. This isolates the shower the way full-generator swaps cannot:
  #v(0.2em)
  #grid(columns: 2, gutter: 14pt,
    [
      - *VINCIA* — antenna shower. *Indistinguishable from Pythia* at jet level: per-class KS
        *0.004–0.037*, every jet-level feature KS\<0.024.
      - *DIRE* — dipole shower (like Sherpa's CS). Matches Pythia on *quark* jets (Higgs/W/Z ~0.01) but
        *softer on gluon-rich jets* — a genuine shower difference, *not* a bug.
    ],
    [
      *DIRE vs Pythia — where it splits (KS):*
      #v(0.15em)
      #table(columns: (1.4fr, auto, auto), inset: 4.5pt, stroke: 0.4pt + luma(220), align: (left, center, center),
        table.header([class], [nparts], [m#sub[SD]]),
        [ZJetsToNuNu (QCD)], [#text(fill: warn)[0.36]], [#text(fill: warn)[0.29]],
        [TTBarLep], [#text(fill: warn)[0.32]], [0.03],
        [TTBar], [0.16], [0.02],
        [HToBB / WToQQ], [\<0.05], [\<0.01])
    ],
  )
  #v(0.2em)
  Both editions reproduce the W/Z/top/Higgs mass peaks exactly (see next); DIRE's difference lives
  purely in *constituent multiplicity of gluon-radiation-rich jets*. Build gotcha: Delphes silently
  drops Pythia's HepMC3 → write *HepMC2*.
])

#plotslide2("Shower isolation — agree on resonances, split on gluon jets",
  "figs/shower_resonance.png", "figs/shower_qcd.png",
  [Left: W/Z soft-drop mass — Pythia (black), VINCIA (green), DIRE (blue, dashed) all peak on the boson
   mass. Right: constituent multiplicity for the gluon-rich classes — VINCIA sits on Pythia, while DIRE
   peaks lower with a shorter tail (fewer particles). Same MG5 events + string hadronisation throughout.])

// ───────────────────────── SYNTHESIS ─────────────────────────
#slide("Where the editions agree — and where they split", [
  #set text(size: 13pt)
  Mean KS over 10 classes — the spread is *small and structured*:
  #v(0.2em)
  #grid(columns: (1.05fr, 0.95fr), gutter: 16pt,
    table(columns: (1.5fr, auto, auto, auto), inset: 5.5pt, stroke: 0.5pt + luma(210),
      align: (left, center, center, center),
      table.header([*feature*], [Sherpa#linebreak()–Pythia], [Herwig#linebreak()–Pythia], [Herwig#linebreak()–Sherpa]),
      table.cell(colspan: 4, fill: accent.lighten(90%))[*Kinematics / detector — universal*],
      [jet\_pt], [0.016], [0.016], [0.016],
      [jet\_eta], [0.003], [0.005], [0.004],
      [part\_deta], [0.016], [0.006], [0.012],
      [part\_d0val], [0.008], [0.004], [0.008],
      table.cell(colspan: 4, fill: warn.lighten(83%))[*Jet substructure — small residual, no outlier*],
      [jet\_sdmass], [0.113], [0.027], [0.112],
      [tau21], [0.037], [0.030], [0.055],
      [jet\_tau2], [0.085], [0.052], [0.120],
      [jet\_nparticles], [0.080], [0.095], [#text(fill: warn)[0.129]],
    ),
    [
      *Two regimes, all close:*
      - *Kinematics* (pt, η, IP, particle ID) are fixed by the *matrix element + boost cut* → all
        editions essentially identical (KS\<0.02).
      - *Substructure* carries the only real spread, and even that is *modest* (≤0.13): *Pythia roughly
        central*, Herwig closest, Sherpa a touch out via its CS-dipole recoil.

      #v(0.3em)
      No single generator is an outlier — the family clusters tightly, with substructure the lone axis
      of (small) disagreement. The shower-only DIRE / VINCIA editions extend this along a clean shower
      axis: VINCIA ≈ Pythia, DIRE splits only in gluon-jet multiplicity.
    ],
  )
])

// ───────────────────────── LESSONS ─────────────────────────
#slide("Engineering lessons (NERSC Perlmutter)", [
  #set text(size: 13pt)
  #grid(columns: 2, gutter: 16pt,
    [
      - *Native conda*, not home-grown micromamba (`module load conda`).
      - *`$HOME` has no flock* → rattler/pip die with error 524; redirect caches to pscratch.
      - *`/tmp` is RAM (tmpfs)* → multi-GB HepMC there OOM-kills; stage transient on *pscratch*.
      - *ROOT 6.38 exits nonzero on success* → judge by the output file.
      - *Herwig / MG need an el9 container* (cmssw/el9 + cvmfs) — Perlmutter nodes aren't el9.
    ],
    [
      - *Sherpa silently drops forced decay channels* → verify the gen-matched label, not just that it ran.
      - *Forcing an exclusive decay biases kinematics:* HToWW2Q1L pinned the hadronic W off-shell →
        mass 25 GeV low. #text(fill: warn)[Force the boson, let sub-decays run naturally.]
      - *Delphes silently drops Pythia's HepMC3* (0 events) → write *HepMC2*.
      - *DIRE is under-tuned for QCD jets* in 8.3 (CERN dropped it from newer LCG) — sound on resonances,
        softer on QCD. *Validate on a resonance before scaling.*
    ],
  )
])

// ───────────────────────── SUMMARY ─────────────────────────
#slide("Summary", [
  #v(0.3em)
  #grid(columns: (1.1fr, 1fr), gutter: 20pt,
    [
      *Delivered:* byte-compatible JetClass editions —
      #linebreak() #chip(accent, "Pythia") #chip(good, "Sherpa") #chip(warn, "Herwig 7.3")
      #chip(good, "+VINCIA") #chip(good, "+DIRE")
      #linebreak() each *125M jets*, official layout, side-by-side in `part_datasets/JetClass/`.

      *Validated:* integrity ALL GOOD; Sherpa decay bugs found & fixed (incl. the HToWW2Q1L soft-drop
      mass); feature distributions cross-compared — physically sensible, kinematics consistent,
      *substructure carries the differences*.
    ],
    [
      *Model spread (mean per-class KS):*
      #v(0.3em)
      #box(fill: luma(245), inset: 9pt, radius: 5pt, text(size: 12.5pt)[
        VINCIA ↔ Pythia: #text(fill: good, weight: "bold")[0.015]#h(0.6em)#text(size: 10.5pt, fill: gray)[shower-only] #linebreak()
        Herwig73 ↔ Pythia: #text(fill: good, weight: "bold")[0.023] #linebreak()
        Herwig73 ↔ origHerwig: #text(fill: good, weight: "bold")[0.025] #linebreak()
        Sherpa ↔ Pythia: #text(fill: good, weight: "bold")[0.034] #linebreak()
        Herwig73 ↔ Sherpa: #text(fill: warn, weight: "bold")[0.043] #linebreak()
        DIRE ↔ Pythia: #text(fill: warn, weight: "bold")[0.052]#h(0.6em)#text(size: 10.5pt, fill: gray)[gluon jets] #linebreak()
      ])
      #v(0.3em)
      *Delivered:* a *6-way* shower / hadronisation matrix — full-generator (Sherpa, Herwig) and
      shower-only (VINCIA, DIRE) axes — for robustness & domain-adaptation studies in jet tagging.
    ],
  )
  #v(0.6em)
  #align(center, text(fill: gray, size: 12pt)[
    `jetclass-sherpa/` (Sherpa) · `jetclass_herwig73_cluster/` (Herwig) · `jetclass_pythia_showers/` (DIRE/VINCIA)
  ])
])
