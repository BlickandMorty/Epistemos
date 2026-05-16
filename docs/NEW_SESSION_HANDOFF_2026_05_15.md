# New-Session Handoff — 2026-05-15
**For:** any new Claude / Codex / agent session continuing the Epistemos MAS-first work.
**Source-of-truth bundle:** read the docs in §1 in order. They cover the current MAS-first state, the research corpus, the agent vision, and the gap audits without nuance loss.

---

## 1. Read these 9 docs first (in order)

1. **`AGENTS.md`** — cross-agent engineering bible: research-first, test-first, minimal fixes, forbidden paths, Swift/Rust patterns, and release-audit rules.
2. **`CLAUDE.md`** — Claude-specific project rules. If it conflicts with `AGENTS.md`, follow the stricter / more safety-preserving instruction and surface the conflict.
3. **`docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`** — the research entry point. Search here before selecting work; follow the canonical local source it names before coding or doc-routing.
4. **`docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`** — Atlas of every primitive + V1 status matrix + App Store checklist (rank 2 of the authority chain).
5. **`docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`** — the 54-item Master Fusion plan (Phase A V1 ship gates + Phase B no-compromise + Phase C audit PARTIAL closure + Phase D XPC mastery + Phase E submission). **§8 Implementation Log is the live ledger of what's shipped — read this every session start to see state.**
6. **`docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`** — native agent architecture doctrine (post-V1 sequencing). §13.5 distills the latest second-wave research; §11 maps every commit shipped 2026-05-13/14/15 into the new architecture.
7. **`docs/VARIANT_LADDER_TOOL_REGISTRY_2026_05_15.md`** — every MAS-allowed tool's Variant Ladder tier profile (the B.1 retrofit contract).
8. **`docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md`** — PASS 1: 4-agent corpus sweep that surfaced 31 gaps across `docs/fusion/` + `docs/` + `~/Documents/Epistemos-QuickCapture/`. **6 BLOCKERS need V1 triage before MAS submission** (BrowserEngine MAS/Pro decision · Hermes-parity salvage verification · Wave 7-11 user-product layer V1/V1.1 decisions). Every gap routed to a canonical doc with a destination column.
9. **`docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md`** — PASS 2: 6 parallel agents swept the regions PASS 1 undersampled (`docs/_consolidated/` 531 files · `docs/audits/` 74 files · personal-research deep dive · `docs/fusion/salvage/` 138 files · long-tail plans / handoffs / architecture · older research packs + `_archive/` spot-check). **5 NEW BLOCKERS** (Specialties registry · ArtifactKind + ProvenanceBlock · vault import stall · Residency Governor rate-distortion · Hermes XPC vs in-process decision) + 17 HIGH + 11 MEDIUM + 4 LOW = 37 confirmed new gaps. PASS 2 explicitly rejects 4 stale candidates with transparency receipts.

**Combined: 68 actionable items across the full research corpus.** Most are decisions or doc-updates; only ~6 require code work.

---

## 2. Active branch

```bash
git checkout codex/research-snapshot-2026-05-08
```

All work since 2026-05-14 lives on this branch. Push target is the same.

---

## 3. Scope rules (the things that override default behavior)

1. **MAS-first.** Every change must be App-Store-safe. CI gates: `strings` + `nm -gU` on the MAS bundle must return ZERO matches for the Pro-only allowlist.
2. **No Helios architecture changes.** V6.1 / SCOPE-Rex / 5-plane formalism / scope_rex kernels / resonance daemon — don't touch. Toggles default OFF; substrate stays as doctrine target.
3. **Graph is protected.** No camera / renderer / layout / edges / physics / hologram changes WITHOUT scoped user approval. (Exception that already shipped: hide `metalView` on note route, keep `blurView` + `darkenLayer` visible so the note panel inherits the graph's blur ontology — commit `916e4f2e6`.)
4. **Vault is sensitive.** Vault fixes start with evidence + minimal rationale + rollback-safe plan. No reset/delete/casual migration.
5. **8-question PR discipline** per `MAS_FINAL_STRETCH_NO_NUANCE_LOST` §6 — apply to every PR.
6. **No silent deferrals.** Every deferred item gets a row in the Master Fusion Plan §8 Implementation Log AND/OR an audit row.
7. **Substrate refactoring follows the Five Laws.** Any post-V1 substrate / `substrate-core` / identity-unification / entity-store / UniFFI-hotpath / Python-isolation work obeys all five binding principles from `docs/_consolidated/60_deferred_research/UNIFIED_SUBSTRATE_RESEARCH.md` §"THE FIVE LAWS":
   - **L1 Measure before you cut.** No architectural refactoring without Instruments profiling data justifying it. Every architecture PR must cite a concrete measurement (allocation count · frame time · call frequency · binary size delta).
   - **L2 Entity store is a new crate, not a refactor.** Build `substrate-core` as a fresh Rust crate with `slotmap` generational keys. Wire alongside existing code. Migrate one entity type at a time. Old + new coexist until old can be deleted.
   - **L3 Identity unification is Sprint 1; everything else waits.** Define `EntityID` as a `SlotKey` in Rust, expose via C ABI as `u64`, replace Swift UUIDs one model at a time. Don't touch rendering, action grammar, or Python until identity is unified for notes, links, and tags.
   - **L4 UniFFI stays until profiling proves otherwise.** All 3 substrate-research dossiers recommend graduated FFI — UniFFI for cold paths, custom C ABI for hot paths. Don't pre-optimize. Keep UniFFI everywhere; replace top-3 measured hotspots only.
   - **L5 Python goes out-of-process immediately.** All Python moves to a subprocess daemon behind Unix domain socket. Saves 15-25 MB bundle, eliminates GIL contention, crash-isolates Python. Fastest no-regret change.

   The source doc tags these as "Add to CLAUDE.md — binding." Promoting them into `CLAUDE.md` itself is user-approval-gated per loop prompt §16 ("user has explicitly opted OUT of editing CLAUDE.md without his approval"); they live here as the binding constraint until that promotion lands.

---

## 4. What shipped on 2026-05-14/15 (this session window)

22 commits between `8e371de91` (earlier session) and `ca12083b3` (latest). Highlights:

**Urgent user-reported bug fixes:**
- `f7f3c273a` — Tantivy LockBusy retry + read-only fallback (vault writer reliability)
- `930b86989` — Gemma 3/4 + Mistral excluded from `canActAsAgent` (they don't honor Hermes `<tool_call>` grammar)
- `41be78202` — `list_notes` auto-routes to `vault.search` on `query` param (fixes "Qwen listed only 7 irrelevant notes")
- `916e4f2e6` — Graph blur wallpaper preserved when navigating to note (regression fix on prior `8e371de91`)

**Master Fusion Plan Phase B shipped:**
- `9b7629752` — B.5: `epistemos.{soul,skill,episode,semantic}.v1` schemas
- `c2b7eaab5` — B.2: Variant Ladder tool registry (30 MAS tools profiled)
- `7cb1ed426` — B.3: `EscalationPolicy::Never` default on VariantLadder + 5 source-guard tests
- `c3a84f9e9` — B.4: `LocalTextModelID.reasoningTokenCap` per-model table + 6 source-guard tests

**Master Fusion Plan Phase C shipped/closed:**
- `06819a33a` — C.15: 3 orphan surfaces marked SCAFFOLD-ONLY (KaTeXSnippets, KIVIQuantization, variant_ladder)
- `8547c0aa9` — C.6: Vault Organizer V1 known-limitation tooltip (folder-name match)
- `504c2696d` — C.10: CodeFileService canonical first-fix-pass collapse
- `4cf6a691b` — C.3 (Brotli off main) + C.9 (AgentGrep off main) audit closures
- `868511ed9` — C.11: `/image` hide three-layer gating verified
- `ca12083b3` — C.4: Prose reparse debounce machinery on `ProseTextView2`
- `bb80399e0` — Audit sweep: RCA5-P2-002 + RCA-P0-004 + RCA11-P1-007 closed

**Design / doctrine:**
- `98ee8c9bc` — `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` (16 sections, ~600 lines)
- `0244d85b0` — Hermes 2.0 §13.5: distilled the second research wave (Phi-4 / Mistral Small / Nemotron lineup, 4-layer brain, Aider PageRank, RAG via Halo Shadow, new acceptance test #7 pinning the "Qwen 7 notes" bug)
- `eb5dd1e3e` — Codex next-session kickoff doc (earlier session)

All commits visible via:
```bash
git log --oneline codex/research-snapshot-2026-05-08 ^main | head -30
```

---

## 5. What's queued — pick from these next

Before picking anything, reconcile the row against current truth: `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN` §8, the recursive audit register, recent commits, and live code symbols. Some rows below are partially shipped; next sessions should close the missing proof / wiring, not reimplement landed substrate.

### Phase A.0 (current-app proof before more architecture)
- **RCA13-P0-001** — Vault reset/add/remove/select runtime proof. Disposable vault A/B smoke: connect A with `VAULT_A_ONLY`, Reset Everything, verify Notes/Graph/Search/Halo/Settings have no stale A state, then connect B with `VAULT_B_ONLY` and verify only B appears. Patch only if the proof fails.
- **B2-2** — ArtifactKind + ProvenanceBlock truth reconciliation. `agent_core/src/artifacts/{kind,header,provenance}.rs` already exist on current heads that include Claude's PASS 2 work; verify tests/callers and reconcile the gap audit instead of rebuilding the taxonomy.

### From the Master Fusion Plan Phase B (no-compromise quality)
- **B.1** — Variant Ladder remaining work: T2 real embedding-only if a real vector path exists + Swift Provenance Console consumer for `vault_search.ladder_walk`.
- **B.2** — Optional source-embedded `## Variant Ladder` doc blocks only after confirming the registry doc is insufficient.
- **B.4** — reasoning <=256 tokens at grammar compile, gated on verified MLXStructured bounded-string / `maxLength` API.
- **B.6** — Cognitive Weight W1 remaining wiring: composer attachments + Provenance Console + sidecar-derived metadata.
- **B.7** — Knowledge Sieve live integration: pass ClaimLedger tier boosts into the Shadow query/fusion caller.
- **B.8** — `clarify` remaining wiring: route GenUICardPresenter payloads through ChatCoordinator transcript + agent-loop response history.
- **B.9** — NightBrain task bodies (6 pending: dedupe_artifacts · memory_distillation · cloud_knowledge_distillation · session_graph_generation · skill_evolution_analysis · ssm_state_pruning).

### From Phase C (audit PARTIAL closure)
- **C.1** — Hidden-capture metadata existing-note migration (Settings → Privacy utility)
- **C.5** — NotesSidebar cache invalidation + epdoc manifest I/O off the sidebar rebuild path
- **C.7** — Scoped credential delivery → FFI-only delivery (no env-var across FFI)
- **C.8** — Verified-write coverage closure (5 named paths)
- **C.13** — DB fallback fault-injection runtime matrix
- **C.14** — Launch path deeper audit (Instruments trace)
- **C.16** / **C.17** — Operator smokes (mic temp-file + Current Access proof)
- **C.18-22** — UIX verifications (theme picker / .epdoc routing / sidebar performance)

### Phase A (V1 ship gates — user-action items)
Per Plan §A.1-A.6: MAS Release build verification + provider credential live smoke + MAS simple-rewrite smoke + graph framing decision + App Store Connect metadata + TestFlight soak.

### Phase D (XPC Mastery — gated on Phase A.1 green + paid Developer signed builds)
13 items D.1-D.13 per Plan §D.

---

## 6. Audit register state (top-of-tree truth)

`docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` is the master audit ledger. Status terms:
- **CONFIRMED** — issue verified but no fix yet
- **PATCHED** — code-level fix landed + tests green
- **PATCHED PARTIAL** — structural fix in place, manual smoke / deeper profiling pending
- **PATCHED PARTIAL → PATCHED** rows updated 2026-05-15: RCA-P0-004, RCA5-P2-002, RCA9-P0-001, RCA10-P1-006, RCA11-P1-007, RCA-P1-001, RCA4-P1-002, RCA2-P1-014, RCA12-P1-003, RCA-P2-010

Remaining `PATCHED PARTIAL` rows (~16) listed in Master Fusion Plan §2 cross-reference table.

---

## 7. The Hermes Agent Core 2.0 design (the agent architecture)

Two key sentences:

> **Architecture sentence:** *Epistemos agents are Hermes-governed native agents whose executor can be local, cloud, MCP, or Pro CLI, but whose memory, permissions, schemas, artifacts, and audit trail always belong to Epistemos.*

> **Routing sentence:** *Don't train one custom MoE — route between off-the-shelf specialists (Controller / Reasoning / Coding / Tiny / Chat) that already exist on HuggingFace + MLX-community.*

Sequencing: lands AFTER V1 MAS submission per Plan §B + §D acceptance bars (Phase A complete + Phase B core merged + Phase C core merged + Phase D Stage 1 merged + V1 submitted). 6-week implementation timeline in §12 of the design doc.

V2.x catalog additions doctrine-targeted: Phi-4 14B (reasoning), Phi-4-mini 3.8B (quick tasks), Nemotron Nano 4B (tiny QA), Qwen 3.5 7B (76/100 HumanEval coding primary).

---

## 8. Local development hygiene

```bash
# Always run at session start:
git status --short
git log --oneline -10

# Build:
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# Rust tests:
cargo test --manifest-path agent_core/Cargo.toml --lib

# Lint:
swiftlint

# Push:
git push origin codex/research-snapshot-2026-05-08
```

---

## 9. Single-sentence summary for the new-session prompt

> *"Continue the MAS-first work on `codex/research-snapshot-2026-05-08`. Read `docs/NEW_SESSION_HANDOFF_2026_05_15.md` for the full handoff, then pick the next item from §5. No Helios architecture changes. Graph is protected. 8-question PR discipline. Every shipped item gets an Implementation Log row in `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8."*

That sentence is enough for a cold-start session to pick up exactly where this one left off without losing any nuance.

---

## 10. Recursive backlog landscape — the FULL research / audit / progress universe

The §1 list is the **read-in-order top 5** docs. The list below is the full landscape — open these as you need them; don't try to read all at once.

### 10.1 Recursive audit register family (the source-of-truth for "what's broken")

| Doc | Role |
|---|---|
| `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` | **Master audit register** — ~216 items across RCA2-RCA13 + UIX-2026-05-09 + Research Drops 1-13. Every item has Status: CONFIRMED / PATCHED / PATCHED PARTIAL / TODO. **Read this every session start.** |
| `docs/audits/CODEX_RECURSIVE_FIX_PROMPT_2026_05_09.md` | **The recursive-pass protocol Codex follows** — 10 absolute rules including "test-first for each fix", "minimal fixes only", "never revert user changes", "update the audit log after every closed item". Adopt these rules for any session continuing the work. |
| `docs/audits/MASTER_HARDENING_WIRING_AUDIT.md` | Wiring audit of hardening surfaces |
| `docs/audits/2026-03-11-recursive-dead-code-audit.md` | Older recursive dead-code audit (historical context) |

### 10.2 Research index family (the "look here before coding" docs)

| Doc | Role |
|---|---|
| `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` | **The research entry point per CLAUDE.md.** Every concept / mini-task / term maps to (a) canonical source on disk, (b) supporting docs, (c) code anchors, (d) tier classification, (e) one load-bearing claim verbatim. Search by name first. |
| `docs/VISION_BACKLOG.md` | Complete vision backlog tiers (Tier 0 moat: iMessage / OpenClaw / Model Council / GTD Quick Capture / Personas / Pause Screen) — most are Pro/post-V1 |
| `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` | Rank-2 authority chain; sits above `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` |
| `docs/MASTER_BUILD_PLAN.md` | Original full build spec |
| `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` | Hardening + test harness plan |
| `docs/MASTER_MODEL_STACK_PLAN.md` | Local model catalog policy (pinned commit SHAs, Honesty Ledger §6) |

### 10.3 Codex V1 audit family (latest pre-V1 closure work)

| Doc | Role |
|---|---|
| `docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` | Codex's master 36-commit recursive audit pass with Phase 0 snapshot + protected-surface log |
| `docs/CODEX_V1_CLOSURE_VERIFICATION_2026_05_14.md` | Claude's verification of Codex's closure claims |
| `docs/CODEX_NEXT_SESSION_KICKOFF_2026_05_14.md` | Earlier session's kickoff doc; superseded by this handoff |
| `docs/CODEX_MAS_READINESS_ASSESSMENT_2026_05_13.md` | MAS readiness assessment |
| `docs/CODEX_HANDOFF_2026_05_13_CHAT_TOOL_PARITY.md` | Chat + tool parity handoff |
| `docs/CODEX_FULL_HANDOFF_2026_05_05.md` | 2026-05-05 full handoff (Hermes-removal context) |
| `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` | Per-tool truth table (visibility / executability / capability) |

### 10.4 Recursive-pass discipline (per Master Fusion Plan §E.1)

To click "Submit for Review" on the App Store, the plan requires:
> **5 consecutive Codex recursive passes find zero new V1 blockers.**

Each pass = 1 session that:
1. Pulls latest main
2. Reads `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` **cover-to-cover**
3. Scans for new issues introduced by recent commits
4. Verifies no new V1 blockers
5. Appends a pass record to `docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` Recursive Pass Log
6. **If pass adds a NEW blocker, the counter resets.** Estimated 5-7 days (1 pass per day, sometimes 2 if light).

### 10.5 Per-session startup protocol (from CLAUDE.md)

Run these checks at the START of every new session:
1. Read `docs/APP_ISSUES_AUTO_FIX.md` — fix any `Status: Open` runtime issues opportunistically (non-destructive)
2. Read `docs/AGENT_PROGRESS.md` — see what's done + what's next
3. Read the current sprint file from `docs/sprint-sessions/` (e.g. `sprint-omega-1-foundation.md`)
4. Run `git status --short` + `git log --oneline -10` (catch uncommitted work)
5. Then read the §1 top-5 of THIS handoff doc
6. **After completing each task**, run its verification command before moving to the next
7. **After completing all sprint tasks**, update `docs/AGENT_PROGRESS.md` with ✅ and today's date

### 10.6 Fusion doctrine corpus (every PR in Phase B/C/D checks against these)

Most important (cited from Master Fusion Plan §7 doctrines section):
- `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` — Phase D primary source
- `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` — B.1-B.4 source (Variant Ladder tier discipline)
- `docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` — B.6 source (W1 weight class)
- `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` — B.8 source (GenUI dispatcher pattern)
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` — D.12 source (in-process MCP)
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — Phase 8.A-G LANDED; 8.H deferred
- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` — all FFI work
- `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` — Pro/MAS gating discipline
- `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` — NightBrain integration (B.9)
- `docs/fusion/LOCAL_CANON_FIRST_SPECIFICITY_PROTOCOL_2026_05_04.md` — all PRs (research-first protocol)

Helios research source (DO NOT IMPLEMENT — substrate landed, toggles OFF):
- `docs/fusion/helios v5 first.md` (754L)
- `docs/fusion/helios v5 updated.md` (625L) — v5.2 truly final

V6.1 + V6.2 lock (canonical target only, not implemented this slice):
- `docs/audits/V6_1_LEAN_REALITY_MATRIX_2026_05_06.md` — V6.1 5-plane formalism + interrupt-score eq + 5 M2 Max kernels GREEN_FOR_THIS_SLICE_NOT_RELEASE_READY

### 10.7 Implementation prompts + chain docs (historical Codex bootstraps)

If you need to understand *how* Codex was prompted at various stages:
- `docs/CODEX_PROMPT_CHAIN.md` — original prompt chain
- `docs/CODEX_MASTER_PROMPT.md` — master prompt
- `docs/CODEX_MANIFESTO.md` — Codex manifesto
- `docs/CODEX_SESSION_PROMPT.md` — session prompt template
- `docs/MASTER_SESSION_PROMPT_v2.md` — current master session prompt
- `docs/AGENT_FUSION_RESEARCH_PROMPT.md` — agent fusion research prompt

### 10.8 Research deep-dives (read when working on the specific subsystem)

- `docs/GOOSE_AGENT_RESEARCH.md` + `GOOSE_AGENT_RESEARCH_2.md` — Goose Rust agent core
- `docs/CONTROL_PLANE_RESEARCH.md` — control plane research
- `docs/CODE_EDITOR_STACK_RESEARCH.md` — code editor stack
- `docs/CUSTOM_TEXT_ENGINE_RESEARCH.md` — text engine
- `docs/CLI_CONFIG_COMPILATION_RESEARCH.md` — CLI passthrough
- `docs/GRAPH_SDF_LABEL_RESEARCH_PROMPT.md` — graph SDF labels (graph-protected!)
- `docs/HELIOS_V5_SESSION_START_PROMPT_2026_05_05.md` — Helios V5 context (don't implement; just understand)

### 10.9 Substrate Track Register (Phase / Track / Lane vocabulary)

`docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md` — the canonical 16-track feature register T0-T15 across 4 zones.

**Vocabulary discipline:** "Track" T0-T15 = features; "Lane A/B/..." = git branches (existing convention). NEVER conflate. Memory entry `project_substrate_track_register` carries this rule.

---

## 11. The "make sure all the research is satisfied" checklist

Before claiming any work is "done", run this 7-item check:

1. ☑️ **Research-first**: searched `MASTER_RESEARCH_INDEX_2026_05_02.md` for the concept BEFORE coding (per CLAUDE.md "RESEARCH-FIRST FOR EVERY TASK")
2. ☑️ **Audit row updated**: closed item has the audit row in `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` updated to PATCHED with evidence + commands + remaining risk
3. ☑️ **Implementation Log row appended**: row in `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8 with commit SHA + acceptance evidence + WRV status (Wired+Reachable+Visible+Verified)
4. ☑️ **Build green**: xcodebuild + cargo test both clean
5. ☑️ **Source-guard test**: a test pins the new invariant so future refactors can't silently erode it
6. ☑️ **8-question PR discipline**: per `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §6 — Stage/Wave + GenUI route + Sovereign + Pro impact + App Group + Variant Ladder + Atlas update + Disambiguation
7. ☑️ **Push to `codex/research-snapshot-2026-05-08`** — never just commit locally

If any of these are missing, the work isn't actually done — flag it as a deferred row.

---

## 12. The "what's recursively still TODO" snapshot (2026-05-15)

From `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` strict status counts (read for live numbers; this is just a snapshot):

| Status | ~Count (snapshot) | Action |
|---|---|---|
| **CONFIRMED** | ~30 | next-up; needs structural fix |
| **PATCHED** | ~140 (after today's pass) | done; keep regression tests green |
| **PATCHED PARTIAL** | ~16 (after today's pass) | manual smoke / deeper profiling deferred |
| **TODO** | ~121 | most are P2/P3 future work (Research Drops 2-13) |

**Active P1s remaining** (per audit register row 25):
- P1-002 (.epdoc save heaviness — needs profiling)
- P1-006 (chat streaming main-actor pressure — large refactor)
- P1-007 (capture work off main actor)
- P1-024 (Apple Intelligence main-actor profile — needs M-series hardware)
- RCA13-P1-002 (CLI discovery — user-facing feature work)

Plus a long tail of P2 items.

---

## 13. Branch + main + worktree state

```bash
# Active work:
git checkout codex/research-snapshot-2026-05-08
git log --oneline -25  # last 25 commits — todays's work

# Compare against main:
git log --oneline codex/research-snapshot-2026-05-08 ^main | head -25

# DO NOT TOUCH (per CLAUDE.md):
# ~/Epistemos-RETRO/, src-tauri/, ~/meta-analytical-pfc/

# Worktree inventory:
# docs/fusion/WORKTREE_INVENTORY_2026_04_30.md
# docs/fusion/WORKTREE_INSIGHT_SALVAGE_2026_05_02.md
```

---

## 14. Deferred Windows research (post-V1, do not integrate into V1 work)

The Windows port research is **explicitly post-V1**. V1 ships MAS macOS only. The research bundle exists so the eventual port has a starting position, not because anything in V1 depends on it. Do NOT pull these docs into a V1 slice; pointer only.

**Location (10-doc bundle):** `docs/_consolidated/60_deferred_research/windows_research/` (mirror at `docs/windows_research_handoff/` for the final decision matrix).

| # | File | Purpose |
|---|---|---|
| 00 | `00_README.md` | Handoff overview — read this first when the port becomes active |
| 01 | `01_master_google_research_prompt.md` | The research-collection prompt that produced the rest of the bundle |
| 02 | `02_hardware_target_and_windows_constraints.md` | Dell XPS 16 + Intel Core Ultra + NPU scheduling targets; non-negotiables |
| 03 | `03_app_architecture_and_bootstrap.md` | Native shell choice (Swift-WinUI / Swift-WinRT / Direct3D + WinRT) + app lifecycle |
| 04 | `04_ai_routing_and_local_inference.md` | OpenVINO + ONNX Runtime + DirectML routing; how local-tier inference maps off Apple Silicon |
| 05 | `05_persistence_models_and_vault.md` | SQLite + GRDB-equivalent on Windows; vault file watching with `ReadDirectoryChangesW` |
| 06 | `06_notes_editor_and_textkit_patterns.md` | TextKit 2 → RichEdit / TextServices Framework equivalent; preserving the editor invariants |
| 07 | `07_chat_surfaces_and_session_patterns.md` | NoteChatState / streaming UI parity |
| 08 | `08_graph_engine_and_rust_ffi.md` | Rust-FFI surface that already exists carries over; Metal → DirectX 12 compute |
| 09 | `09_performance_rules_and_antipatterns.md` | Windows-specific perf rules + Apple-only antipatterns that map differently |
| 10 | `10_windows_port_decision_matrix.md` | Final Swift-WinUI vs Swift-WinRT vs Direct3D+WinRT comparison; recommended path |

**Non-negotiables (from `00_README.md` + `02_hardware_target_and_windows_constraints.md`):**

1. **No Tauri, no Electron, no WebView.** The port keeps the native split — Swift app shell (or native equivalent) + Rust agent_core + DirectML/OpenVINO for local inference.
2. **Preserve the native split.** Rust `agent_core` + `epistemos-shadow` carry over unchanged. The OS adapter layer (AX → UIA on Windows · ScreenCaptureKit → Graphics.Capture API · MLX → DirectML/OpenVINO) is the only port surface.
3. **Preserve local AI.** No cloud fallback added during the port. Local-tier inference must work on the Windows hardware target before submission.
4. **Preserve perf.** Apple Silicon perf rules apply: pre-allocate buffers, debounce hot paths, zero per-frame allocations in render loops, no `repeatForever` animations.

**When to look at this bundle:** AFTER V1 macOS ships + ANY Pro tier ships + a concrete distribution decision routes Windows ahead of Linux. Until then, treat as deferred reference material — do NOT optimize the macOS codebase for "easier Windows port" speculatively.

Source: `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` B2-H4 (resolved 2026-05-16).

---

*— End of New-Session Handoff. 14 sections. Read §1 in order; rest are reference. The §11 7-item check is your "did I satisfy ALL the research" gate. §14 is post-V1 reference only.*
