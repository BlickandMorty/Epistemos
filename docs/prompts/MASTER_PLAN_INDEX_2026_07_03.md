# Epistemos — Master Plan Index (2026-07-03, Provenance Only)

> **SUPERSEDED FOR DAILY EXECUTION — 2026-07-08.** Do not use this file to
> assign execution state or build order. The authority is
> `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08/00_READ_FIRST.md`,
> `02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`, and
> `03_MINIMAL_PROMPT_PACK.md`. Current execution is
> `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`; subsequent keys are
> `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08`,
> `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08`, and
> `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08`. This file and its older prompt
> links are spec/source appendices only.

> 🔴 **OWNER OVERRIDE — 2026-07-07 (READ FIRST; SUPERSEDES 2026-07-06 TWO-SURFACE WORDING).**
> Current execution is **MAS-only**. Read
> `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` before any plan below. The only active
> product target is **MAS/June** (`Epistemos-AppStore`, `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`,
> in-process `agent_core`). **Experimental/1Code, Pro, Developer-ID, OpenChamber, and Kindred
> runtime work are parked** unless a later owner directive explicitly reopens them. Useful ideas
> from parked lanes may be salvaged only by rebuilding them through MAS-safe June/native/WKWebView
> architecture.

Historical map of the older per-plan corpus: what each source prompt described,
which research it referenced, and whether its ideas were later retained or
parked. Do not come back here to choose the next active prompt; use the July 8
five-prompt canon and `MAS_EXECUTION_STATUS_2026_07_10.md`.

**Do not kick off old parallel product agents.** `PROMPT_PLAN_1_PRO_OPENCHAMBER.md`,
`PROMPT_PLAN_10_EXPERIMENTAL.md`, 1Code V2 prompts, and Kindred runtime prompts are parked.
The live agent surface is MAS/June. KEELSTONE remains responsible for deleting old
OpenChamber/ProAgent residue and for proving parked lanes do not leak into App Store builds.

**Raw research corpora (provenance, DO-NOT-BUILD):** `../research/
{OPENCHAMBER,MAS,PLAN9}_RESEARCH_CORPUS_RAW_*.md` + `RESEARCHHUB_WORKFLOW_RAW_*` — every
research pass of this cycle is preserved verbatim on disk. Verification clones live in
`.research-clones/` (git-ignored): historical goose/openchamber donors plus current june,
ironcalc, univer, teable, baserow. Historical OpenChamber clone data is not a build directive.

**Cloud MAS pivot research packet:** [`MAS_PIVOT_CLOUD_RESEARCH_PROMPT_2026_07_07.md`](MAS_PIVOT_CLOUD_RESEARCH_PROMPT_2026_07_07.md)
is the attachment checklist and paste-ready prompt for online research agents that lack repo
access. Use it to re-research KEELSTONE, LUMENLENS, RECKONER, EMBERCATCH, LODESTAR, Sync, storage,
mini-chat, and safe MAS pruning as one integrated App Store release strategy.

## Build sequence (owner rule: MAS-only, strict-sequential, autonomous unless destructive)

```
NOW → MAS-only pivot lock + parked-lane leak checks
        ↓
      KEELSTONE App Store vault/release safety
        ↓
      MAS/June agent hardening + Epdoc MiniChat via June/agent_core
        ↓
      LUMENLENS editor/provenance + RECKONER data, both MAS-only
        ↓
      Plan 3/4/6/8 MAS-safe capabilities, icons, capture, ResearchHub
      Plan 5 companion/Kindred runtime stays parked; salvage mascot/provenance patterns only
```

## The plans

| # | Plan | File | Build | One-line | Key references |
|---|---|---|---|---|---|
| **1-OLD** | **ARCHIVED — deleted OpenChamber track** | [`PROMPT_PLAN_1_PRO_OPENCHAMBER.md`](PROMPT_PLAN_1_PRO_OPENCHAMBER.md) | **deleted** | Do not build. KEELSTONE deletes `Epistemos/ProAgent/*`, OpenChamber resources/scripts/tests, and all third-surface drift after neutralizing shared dependencies. | historical dossier `OPENCHAMBER_RESEARCH_CORPUS_RAW_2026_07_02.md` is provenance only |
| **1-MAS** | Agent surface — **vendored June + agent_core** | [`PROMPT_PLAN_1_MAS_JUNE.md`](PROMPT_PLAN_1_MAS_JUNE.md) | **MAS** (App Store) | June's real UI uses the vendored-web overlay discipline with backend swapped Hermes→`agent_core` in-process (**cloud + local**: proxy + Apple FM/embedded llama.cpp); native chrome wraps it; native wave landing stays. (Rewritten 2026-07-04 — native-SwiftUI-reimplementation rejected.) | dossier `MAS_RESEARCH_CORPUS_RAW_2026_07_03.md`; canon `GOOSE_MAS_BUILD_CANON_2026_06_30.md`; June clone `.research-clones/june` |
| **2** | Editor | [`PROMPT_PLAN_2_EDITOR.md`](PROMPT_PLAN_2_EDITOR.md) | **MAS** | Prose/Source/Note/Epdoc work only as App Store-safe editor infrastructure; MAS-June Epdoc MiniChat may consume the note context + suggestion/provenance seams | memory `project_editor_surface_decision_2026_06_27`; EDITOR_CANONICAL_PLAN |
| **3** | Capabilities | [`PROMPT_PLAN_3_CAPABILITIES.md`](PROMPT_PLAN_3_CAPABILITIES.md) | **MAS** | PDF→md · provenance moat · vault tools · arXiv · native/WKWebView Browser · STT/voice · landing buttons; browser-use/Chromium/Python lanes are parked | PLAN_3_*_CODEPACK docs; `EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md` |
| **4** | Icons / iconography | [`PROMPT_PLAN_4_ICONS.md`](PROMPT_PLAN_4_ICONS.md) | **MAS** | app + June + native/editor/Reckoner feature marks; no Experimental/1Code token target | memory `project_design_nativeness_canon_2026_06_30` |
| **5** | Companion / mascot | [`PROMPT_PLAN_5_COMPANION.md`](PROMPT_PLAN_5_COMPANION.md) | **parked** | Kindred/companion runtime is parked; salvage only MAS-safe mascot/provenance/status patterns through June and native overlays | memory `project_product_shape_agent_center_2026_07_02` |
| **6** | Quick Capture | [`PROMPT_PLAN_6_QUICKCAPTURE.md`](PROMPT_PLAN_6_QUICKCAPTURE.md) | **MAS** | fast capture → vault; capture→Epdoc/June seeding; no Pro git/subprocess lanes | memory `project_quick_capture_salvage_triage` |
| **7** | Sync + quality gate | [`PROMPT_PLAN_7_SYNC.md`](PROMPT_PLAN_7_SYNC.md) | **MAS** | vault sync + App Store release quality gate; Pro git-sync lane parked | — |
| **8** | **ResearchHub** (NEW) | [`PROMPT_PLAN_8_RESEARCHHUB.md`](PROMPT_PLAN_8_RESEARCHHUB.md) | **MAS** | multi-source research feed as native room + June capability; agent-facing phases use MAS/June only | **dossier `RESEARCHHUB_SOURCE_DOSSIER_2026_07_03.md`** (+ raw `RESEARCHHUB_WORKFLOW_RAW_*`); template `Epistemos/Arxiv/ArxivIngestService.swift`; generalizes Plan 3's arXiv |
| **9** | **RECKONER data layer** (reshaped) | [`PROMPT_PLAN_9_DATA_TABLES.md`](PROMPT_PLAN_9_DATA_TABLES.md) + [`RESEARCH_PROMPT_PLAN_9_RECKONER.md`](RESEARCH_PROMPT_PLAN_9_RECKONER.md) | **MAS** | agent-native data core: **silent-Univer renderer** × **IronCalc single calc authority**, **vault-artifact truth**; datasets open as existing note-workspace/Epdoc-notebook tabs, embed into notes, and are driven by June through one F2 tool surface with dry-run→confirm→undo | adjudication `PLAN9_ADJUDICATION_WORKING_2026_07_03.md`; raw corpus `PLAN9_RESEARCH_CORPUS_RAW_2026_07_03.md`; intent frame `PROMPT_PLAN_9_DATA_TABLES_RESEARCH.md`; reshape brief `RESEARCH_PROMPT_PLAN_9_RECKONER.md`; agent seam = Fabric F2 |

## Cross-cutting doctrines (read-first for the relevant plans)
- **Performance:** [`../research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`](../research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md)
  — the owner-loved "instant open" recipe for web-hosted agent surfaces and native shell
  optimization, made a per-phase shipping gate; budgets in `../perf-budgets.toml`
  `[agent_surface]`. OpenChamber-specific examples are historical only.
- **Hardening:** [`../research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`](../research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md)
  — the four audit lenses + the discovered robustness patterns (FFI truth boundary,
  supervision-not-polling, ring-buffer circuit breaker, thermal↔breaker, loopback-origin
  pinning, agent-destructive-op safety, untrusted-ingest, data-core integrity) made a
  per-phase gate. Tailored top-risks baked into current plans (MAS §13, Experimental/1Code,
  ResearchHub §12, Data §11). A hardening HIGH blocks a phase commit like a broken build.
- **Look/feel:** `../research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md` (all plans).

## Notes on relationships
- **Plan 1-PRO/OpenChamber is archived and deleted.** Do not paste its prompt or wrapper. The
  retired single Plan 1 remains a tombstone redirect at `PROMPT_PLAN_1_GOOSE.md`.
- **Plan 8 (ResearchHub) generalizes Plan 3's arXiv** capability and may salvage the
  Plan 5 mascot/status pattern only through MAS-June/native overlays. Its agent-facing
  phases require MAS/June.
- Every plan honors: MAS = no subprocess (App Store); Experimental/1Code is parked;
  keys in Keychain; agent status appears only when backed by real MAS-June state;
  integration is via shared vault files, App Store-safe bridges, and approval-gated tools.
- Standing build discipline (all plans): never `git add -A`; never commit
  `.research-clones/`; no git worktrees; Swift builds on isolated DerivedData with
  BUILD SUCCEEDED before commit; never two `xcodebuild`s at once on the 16GB machine.
