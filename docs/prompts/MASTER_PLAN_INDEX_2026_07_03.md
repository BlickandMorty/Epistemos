# Epistemos — Master Plan Index (2026-07-03)

The single map of every build plan: what it is, its canonical prompt file, the research
it references, which build (MAS/Pro/both) it targets, and where it sits in the sequence.
Come back here to pick up any plan. Each `PROMPT_PLAN_*.md` file **is** the paste-to-agent
prompt for that plan.

**Kicking off the two Plan-1 agents:** paste the matching wrapper from
[`PLAN_1_AGENT_KICKOFF_WRAPPERS.md`](PLAN_1_AGENT_KICKOFF_WRAPPERS.md) above the plan
(territory split, shared-repo rules, never-concurrent-xcodebuild). Precondition already
done: dead goose surface excised (`0b10f728b`, recovery tag `pre-agent-rebuild-2026-07-03`).

**Raw research corpora (provenance, DO-NOT-BUILD):** `../research/
{OPENCHAMBER,MAS,PLAN9}_RESEARCH_CORPUS_RAW_*.md` + `RESEARCHHUB_WORKFLOW_RAW_*` — every
research pass of this cycle is preserved verbatim on disk. Verification clones live in
`.research-clones/` (git-ignored): goose, openchamber, june, ironcalc, univer, teable,
baserow.

## Build sequence (owner rule: strict-sequential, one at a time, owner-verified — never concurrent)

```
NOW → Plan 1-PRO (OpenChamber)  ─┐  the two agent surfaces (run in parallel as
      Plan 1-MAS (June/goose)   ─┘  SEPARATE agents/repos; never two xcodebuilds at once)
        ↓ (agents owner-verified)
      Plan 2 (Editor) · Plan 3 (Capabilities)      ← finish the rooms
        ↓
      Plan 4 (Icons) → Plan 5 (Companion) → Plan 6 (Quick Capture) → Plan 7 (Sync/QG)
        ↓
      Plan 8 (ResearchHub)   ← needs the agents (mascot + agent-read) to exist
      Plan 9 (RECKONER data) ← needs the agents for its F2 tools/notebook-chat
                                stages; its data-core + engine-spike foundation
                                may start earlier
```

## The plans

| # | Plan | File | Build | One-line | Key references |
|---|---|---|---|---|---|
| **1-PRO** | Agent surface — **OpenChamber** | [`PROMPT_PLAN_1_PRO_OPENCHAMBER.md`](PROMPT_PLAN_1_PRO_OPENCHAMBER.md) | **Pro** (Developer ID) | OpenChamber UI base + dual engine (OpenCode native + goose adapter) in WKWebView; June = message bar + gradient only | dossier `OPENCHAMBER_RESEARCH_CORPUS_RAW_2026_07_02.md`; verified vs clones openchamber@0ee55a1 / goose@8b1d500 |
| **1-MAS** | Agent surface — **vendored June + agent_core** | [`PROMPT_PLAN_1_MAS_JUNE.md`](PROMPT_PLAN_1_MAS_JUNE.md) | **MAS** (App Store) | **June's real UI CLONED like OpenChamber** (fork+overlay, Vite build → WKWebView) w/ backend swapped Hermes→`agent_core` in-process (**cloud + local**: proxy + Apple FM/embedded llama.cpp); native chrome wraps it; native wave landing stays. (Rewritten 2026-07-04 — native-SwiftUI-reimplementation rejected.) | dossier `MAS_RESEARCH_CORPUS_RAW_2026_07_03.md`; canon `GOOSE_MAS_BUILD_CANON_2026_06_30.md`; June clone `.research-clones/june` |
| **2** | Editor | [`PROMPT_PLAN_2_EDITOR.md`](PROMPT_PLAN_2_EDITOR.md) | both | Prose/Source/Note lens model (one markdown truth, 3 synced lenses); PDFKit viewer lives here | memory `project_editor_surface_decision_2026_06_27`; EDITOR_CANONICAL_PLAN |
| **3** | Capabilities | [`PROMPT_PLAN_3_CAPABILITIES.md`](PROMPT_PLAN_3_CAPABILITIES.md) | both | PDF→md · provenance moat · vault-MCP · **arXiv (dedicated room + agent capability + mascot)** · Browser (lite WKWebView MAS / browser-use Pro) · STT/voice · landing buttons | PLAN_3_*_CODEPACK docs; `EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md` |
| **4** | Icons / iconography | [`PROMPT_PLAN_4_ICONS.md`](PROMPT_PLAN_4_ICONS.md) | both | app + per-engine + per-feature marks; feeds pill/mascot/model icons | memory `project_design_nativeness_canon_2026_06_30` |
| **5** | Companion / mascot | [`PROMPT_PLAN_5_COMPANION.md`](PROMPT_PLAN_5_COMPANION.md) | both | static+emotive mascot w/ identity+obligation profile; seen 3 places + on any button an agent works; note-edit provenance + two-surface presence | memory `project_product_shape_agent_center_2026_07_02` |
| **6** | Quick Capture | [`PROMPT_PLAN_6_QUICKCAPTURE.md`](PROMPT_PLAN_6_QUICKCAPTURE.md) | both | fast capture → vault; capture→Epdoc seeding | memory `project_quick_capture_salvage_triage` |
| **7** | Sync + quality gate | [`PROMPT_PLAN_7_SYNC.md`](PROMPT_PLAN_7_SYNC.md) | both | vault sync + the v1 release quality gate | — |
| **8** | **ResearchHub** (NEW) | [`PROMPT_PLAN_8_RESEARCHHUB.md`](PROMPT_PLAN_8_RESEARCHHUB.md) | both | multi-source research feed (papers/X/Reddit/HN/GitHub/HF/journals/…) as a dedicated room + agent capability; adaptive-card native timeline; deep Notes + Agent + graph integration | **dossier `RESEARCHHUB_SOURCE_DOSSIER_2026_07_03.md`** (+ raw `RESEARCHHUB_WORKFLOW_RAW_*`); template `Epistemos/Arxiv/ArxivIngestService.swift`; generalizes Plan 3's arXiv |
| **9** | **RECKONER data layer** (reshaped) | [`PROMPT_PLAN_9_DATA_TABLES.md`](PROMPT_PLAN_9_DATA_TABLES.md) + [`RESEARCH_PROMPT_PLAN_9_RECKONER.md`](RESEARCH_PROMPT_PLAN_9_RECKONER.md) | both | agent-native data core: **silent-Univer renderer** (formula engine off) × **IronCalc single calc authority** (WASM in-webview + native UniFFI), SQLite/GRDB truth, dual-zone formula freedom w/ named-range durable refs; **standalone room cut** — datasets open as existing note-workspace/Epdoc-notebook tabs, embed into notes, and are driven by June/KINDRED through one F2 tool surface with dry-run→confirm→undo | adjudication `PLAN9_ADJUDICATION_WORKING_2026_07_03.md` (clone-verified: ironcalc/univer/teable/baserow in `.research-clones/work/`); raw corpus `PLAN9_RESEARCH_CORPUS_RAW_2026_07_03.md`; intent frame `PROMPT_PLAN_9_DATA_TABLES_RESEARCH.md`; reshape brief `RESEARCH_PROMPT_PLAN_9_RECKONER.md`; agent seam = Fabric F2 |

## Cross-cutting doctrines (read-first for the relevant plans)
- **Performance:** [`../research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`](../research/AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md)
  — the owner-loved "instant open" recipe + **web-side** (OpenChamber SPA) and **app-side**
  (native) optimization, made a per-phase shipping gate; budgets in `../perf-budgets.toml`
  `[agent_surface]`. (Pro §13, MAS §12.)
- **Hardening:** [`../research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md`](../research/AGENT_SURFACE_HARDENING_DOCTRINE_2026_07_03.md)
  — the four audit lenses + the discovered robustness patterns (FFI truth boundary,
  supervision-not-polling, ring-buffer circuit breaker, thermal↔breaker, loopback-origin
  pinning, agent-destructive-op safety, untrusted-ingest, data-core integrity) made a
  per-phase gate. Tailored top-risks baked into each new plan (Pro §14, MAS §13, ResearchHub
  §12, Data §11). A hardening HIGH blocks a phase commit like a broken build.
- **Look/feel:** `../research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md` (all plans).

## Notes on relationships
- **Plan 1 is two tracks now** (Pro/MAS) — the retired single Plan 1 is a tombstone
  redirect at `PROMPT_PLAN_1_GOOSE.md`.
- **Plan 8 (ResearchHub) generalizes Plan 3's arXiv** capability + the Plan 5 mascot
  pattern; it does not replace them. Its agent-facing phases require the Plan 1 agents.
- Every plan honors: MAS = no subprocess (App Store); Pro = Developer ID (subprocess OK);
  keys in Keychain; the mascot appears wherever an agent is working; integration is via
  shared vault files, not agent-UI-everywhere.
- Standing build discipline (all plans): never `git add -A`; never commit
  `.research-clones/`; no git worktrees; Swift builds on isolated DerivedData with
  BUILD SUCCEEDED before commit; never two `xcodebuild`s at once on the 16GB machine.
