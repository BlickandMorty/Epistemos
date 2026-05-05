# Off-disk research index — 2026-05-04

Comprehensive index of every Epistemos-relevant research location on
the user's disk that lives outside the project repo. Built per the
"always look for missing docs or any research I don't have that is
somewhere on disk; always look for the best research" directive.

**Total off-disk material discovered**: ~46 MB across 14 locations.
The 9 highest-priority small docs have been lifted into this directory.
The Kimi 38 MB corpus stays out-of-tree (pointer only) to avoid bloating
the repo; future agents can read directly from the source path.

---

## §1. Lifted into this directory (9 files, ~155 KB)

| File | Source | Why lifted |
|---|---|---|
| `PLAN_V2.md` | `~/Library/Mobile Documents/com~apple~CloudDocs/epistemos_architecture_docs/` | Foundational spec — current docs already reference "PLAN_V2" but the doc itself wasn't in repo |
| `CODEX_CONTEXT_PACK.md` | iCloud `epistemos_architecture_docs/` | Codex cold-start context pack; complements `CODEX_PRE_V2_HANDOFF` |
| `COMPUTE_STEERING_SPEC_v1.md` | iCloud `epistemos_architecture_docs/` | Compute steering subsystem spec; references `agent_core/src/compute_steering.rs` (which we just committed work to in `3a46b0c6`) |
| `ADAPTATION_SUBSYSTEM_SPEC_v1.md` | iCloud `epistemos_architecture_docs/` | Adaptation subsystem spec; references `agent_core/src/adaptation.rs` |
| `OVERSEER_AND_AGENT_HIERARCHY.md` | iCloud `epistemos_architecture_docs/` | Agent hierarchy spec; informs the V2.x agent decomposition |
| `NEW_SESSION_PROMPT.md` | iCloud `epistemos_architecture_docs/` | Session-startup canonical prompt template |
| `FINAL_SYNTHESIS.md` | `~/Documents/Epistemos-QuickCapture/` | The canonical Wave 6+ corrections doc per memory; QUICK_CAPTURE_IMPLEMENTATION_PLAN §0 says it "wins all conflicts" |
| `EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_V2_SCOPE_REX_2026_05_01.md` | `~/Downloads/` | Top-level master plan with SCOPE-Rex; never referenced by anything in repo despite being "master plan" |
| `COMPASS_ARTIFACT_2026_04_26.md` | `~/Downloads/final v2/` | The 62K compass artifact the canonical audit log §D4 cites for the Hermes 36B faculty roster spec |

---

## §2. Pointed-at, not copied (large corpora)

These are too large to copy into the repo wholesale, but every future
session reading this index now knows where to find them.

### A. `~/Downloads/Kimi_Agent_Deterministic AI Deep Dive/` (38 MB, 376 markdown/docx files)

**The single largest off-repo research corpus.** Contents:
- `EPISTEMOS_MASTER_ARCHITECTURE.md` — superset of current doctrine docs
- `EPISTEMOS_GAP_ANALYSIS.md` — Kimi's own gap analysis
- `EPISTEMOS_NO_COMPROMISE_ARCHITECTURE.md` — the no-compromises framing the user adopted
- `uasa.agent.final.md` (325K) — UASA agent canonical
- `uasa_memory_breakthrough.md` — memory subsystem breakthrough research
- `uasa_sec00 .. uasa_sec12.md` — 13 sectioned research files

**Recommended action**: when V2.x work touches a subsystem with a
matching `uasa_secNN` doc, read the section first. Do NOT lift the
whole corpus — too much noise per byte; read on demand.

### B. `~/Library/Mobile Documents/com~apple~CloudDocs/Kimi_Agent_Deterministic AI Deep Dive/` (iCloud mirror)

Same shape as A. Includes a sub-folder `jordan's research/hermes.md`
that's user-authored and may have unique framing.

### C. `~/Documents/Epistemos-QuickCapture/` (4.7 MB)

- `FINAL_SYNTHESIS.md` ✅ lifted
- `CATCHUP_PROMPT.md` — older catch-up prompt; superseded by current `CODEX_PRE_V2_HANDOFF`
- `AUDIT_PROMPT.md` — audit framing; informs the 4-parallel-agent audit pattern we already use
- `LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md` — Live Files + substrate addendum
- `BUILDER_PROMPT.md` / `INDEX.md` / `PLAN.md` — older planning artifacts

### D. `~/Documents/EpistemosVault/` (live operational vault)

The user's actual vault — `.epistemos` SQLite + Tantivy indices + 20+
2026-04 session transcripts (each with `trace.json` + `session.json` +
`summary.md` + `transcript.jsonl`). Not research, but a real corpus
useful for testing the route + skill_discovery pipelines once they're
wired to a real vault.

### E. `~/Downloads/old research/` (18+ files, March 2026)

Older research; spot-check before deleting. Notable files:
- TurboQuant research (2 variants)
- `epistemos-omega-final-claude-code-prompt.md`
- `epistemos-custom-mamba-model-blueprint*` (2 variants)
- `MLX Constrained Decoding Research.md` — directly relevant to
  Variant B GBNF wiring (follow-up #2)
- `1B Hybrid Mamba-2 Attention guide`
- `On-Device MoLoRA with MLX_Metal.md`

### F. `~/Downloads/Advice/` (AI model paper PDFs + advice notes)

Reference material; not Epistemos-specific doctrine. Contains:
`Claude paper.pdf`, `Gemini paper.pdf`, `GPT paper.md`, `Perplexity
paper.md`, plus user-authored `claude advice.md` (61K) + `claudy
research.md` (61K).

### G. `~/Downloads/final/` + `~/Downloads/final v2/`

Older iteration material — 6+ deep-research-report variants, hackathon
plans, app-moats analysis. Most superseded by current doctrine docs;
lift on demand.

### H. `~/Downloads/mass research folder/`

Partial duplicate of top-level Downloads files (cap3, cognitive-computing,
Mamba guides, epistemos-upgrade, epistemos-final-release). Skip.

### I. `~/Downloads/` top-level loose files

- `epistemos_computer_prompt.md`
- `epistemos-master-session-prompt.md`
- `epistemos-final-release-plan.md` (34K)
- `epistemos-upgrade-plan.md`
- `cap3_cognitive_friction.md`
- `agent-audit.md`
- `epistemos_resonance_gate.md`
- 3 Metal Mamba 2 research files

Spot-check; many candidates for Tier C archival.

### J. `~/Library/Application Support/Epistemos-Recovery/` (4+ snapshots)

App state DB backups (2026-04-22 → 2026-04-30) + `agent_authority.json`
files. Not research; useful for recovery scenarios.

### K. `~/Downloads/epistenos_os_scaffold.zip` (92K, May 3)

Packaged artifact; not yet extracted. May contain a recent OS-layer
scaffold the user generated; worth extracting to inspect.

---

## §3. Cross-reference: what current `docs/fusion/` already covers

These external paths are NOT additional research — they're already
folded into current docs:
- The hermes-agent v0.6.0 upstream tarball — already at
  `tmp/hermes-agent-upstream/` per memory; the parity audit is at
  `salvage/from-hermes-parity/`.
- The Lane A 92 architecture docs — already at `salvage/from-lane-a/`.
- The agent-a0550f9c CANONICAL_AUDIT_LOG — already at
  `salvage/from-agent-a0550f9c/`; reconciled at
  `CANONICAL_AUDIT_RECONCILIATION_2026_05_04.md`.

---

## §4. Recommendation for V2.x work

Read this index first when starting any V2.x or V3.x slice. The
specific recommendations:

1. **V2.1 Phase 8 follow-up**: read `FINAL_SYNTHESIS.md` first
   (it "wins all conflicts" per QuickCapture plan §0)
2. **MLX/GBNF classifier wiring (variant B host)**: read
   `~/Downloads/old research/MLX Constrained Decoding Research.md`
3. **Compute steering work**: read `COMPUTE_STEERING_SPEC_v1.md`
4. **Adaptation subsystem work**: read `ADAPTATION_SUBSYSTEM_SPEC_v1.md`
5. **Agent hierarchy refactor**: read `OVERSEER_AND_AGENT_HIERARCHY.md`
6. **D4 Helios + SCOPE-Rex (V3 ultimate goal)**: read
   `EPST_UNIFIED_SUBSTRATE_MASTER_PLAN_V2_SCOPE_REX_2026_05_01.md`
7. **Hermes 36B faculty roster decisions**: read
   `COMPASS_ARTIFACT_2026_04_26.md`
8. **General Epistemos architecture deep-dive**: scan
   `~/Downloads/Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_*.md`

When NEW research lands on disk between sessions, this index becomes
stale. The pattern: every 1-2 weeks, re-run the disk scan with the
same exhaustive search list and refresh this doc.
