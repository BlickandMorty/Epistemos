# V1 Ship Ledger — 2026-05-16

**Purpose:** single canonical enumeration of every feature surface in the Epistemos codebase + corpus with its V1/V1.1/V2/never-ships classification, per the 4-advisor synthesis directive: **the canon has coverage but not coherence; this ledger answers "what actually ships when?" without a 20-doc cross-read.**

**Audience:** anyone (Codex, Claude, the user, App Store reviewers, future maintainers) needing to know "does feature X ship in V1?" without digging through MASTER_FUSION §3 + MAS_COMPLETE_FUSION §10 + 4 separate audit registers.

**Discipline:** APPEND-ONLY for new features. Status transitions (V1.1 → V1, never → V2, etc.) update the row in place + log the transition in §6.

**Cross-refs:** this ledger is integration artifact 2 of 3 per the 4-advisor synthesis. Artifact 1 = `UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` (UAS-ACS coherence layer). Artifact 3 = `DAY_IN_THE_LIFE_POWER_USER_2026_05_16.md` (concrete user scenario; iter 78 candidate).

---

## 0. Legend

| Tier | Meaning | Build target |
|---|---|---|
| **V1** | Ships in first MAS submission. SHIPPED in main + verified. | `mas-build` Cargo feature, MAS entitlements |
| **V1.x** | Post-V1 MAS update. Substrate exists or scoped; needs scope-completion work. | `mas-build` later |
| **V2** | Pro-tier (Developer ID distribution). Feature-gated `#[cfg(feature = "pro-build")]` / `#if PRO_BUILD`. | `pro-build` |
| **NEVER** | Research-tier or PAID-TEAM-GATED or research-only. Documented but does not ship. | Lane 3 research crate only |

**Ship-blocker categories:**
- **SHIPPED** — code in main + tests passing + feature complete
- **SCOPE** — substrate exists; feature surface incomplete (needs design / wiring / UI)
- **DECISION** — user-decision-gated (V1 vs V1.1 routing pending user signoff)
- **RESEARCH** — research-tier (not actionable for ship)
- **PAID-TEAM** — requires paid-team-level infra (XPC Mastery, code-signing pipelines, etc.)

---

## 1. Cognitive substrate (the kernel)

| Feature | Tier | Status | Ship-blocker | Source row |
|---|---|---|---|---|
| Cognitive Kernel (Phases 1-7) | **V1** | SHIPPED | — | MASTER_FUSION §3.11 |
| Cognitive DAG (Phase 8.A-G: schema · storage · Merkle · resonance · macaroons · companions · mirrors · dispatch) | **V1** | SHIPPED | — | MASTER_FUSION §3.10; `agent_core/src/cognitive_dag/` |
| Provenance ledger (Phase 1) — `ClaimLedger` + `ReplayBundle` + `.epbundle` | **V1** | SHIPPED | — | MASTER_FUSION §3.18; `agent_core/src/provenance/` |
| `epistemos_trace` CLI (verify + verify-replay) | **V1** | SHIPPED | — | `agent_core/src/bin/epistemos_trace.rs` |
| `epistemos_doctrine_lint` CLI (cognitive DAG doctrine §5.1-§5.4 gates) | **V1** | SHIPPED | — | `agent_core/src/bin/epistemos_doctrine_lint.rs` |
| In-process LSP runtime (V2.3) — `LspKernel` + tree-sitter Rust/Swift | **V1** | SHIPPED | feature-gated behind `lsp-runtime` | `agent_core/src/lsp_runtime/mod.rs` |
| Run Ledger — per-token cryptographic attestation (B2-M14) | **NEVER** | NOT-STARTED | RESEARCH (V2 paid-team-gated for full implementation) | MASTER_FUSION §3.40 |
| Five-plane runtime formalism — `RuntimePlane` enum (State · Episodic · Assembly · Controller · Verification) | **V1** | SHIPPED at 308 LOC research-only | RESEARCH (Lane 3 research-tier) | `epistemos-research/src/five_planes.rs` |
| ACS (Anchored Cognitive Substrate / Autopoietic Cognitive Stack) | **NEVER** | SHIPPED at 190 LOC research-only; doctrine PARTIAL | RESEARCH (Lane 3 research-tier per `acs.rs:17` doctrine comment "NEVER ships in MAS") | MASTER_FUSION §3.8 |
| Foundational Seven theorems (E1-E7) | **NEVER** | doctrine + Lean proof skeleton at 35 sorries / ≤149 budget | RESEARCH | `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` |

---

## 2. Memory hierarchy + storage

| Feature | Tier | Status | Ship-blocker | Source row |
|---|---|---|---|---|
| Six-tier memory hierarchy (L1 KV-cache · L2 vault index · L3 SSD oracle · L4 Engram · L5 Network cascade · L6 archive) | **V1** | SHIPPED (L1, L2 active); L3/L4/L5 PARTIAL | — | MASTER_FUSION §3.2 |
| KV-Direct gate (F-KV-Direct-Gate, memory-architecture floor) | **V1** | SHIPPED Tier-1 at 290 LOC Rust + 65 LOC Metal | — | `agent_core/src/scope_rex/kv/direct_gate.rs` + `Epistemos/Shaders/kv_direct_gate.metal` |
| Residency Governor + Rate-Distortion formalism (B2-4) | **V1** | doctrine + PARTIAL | SCOPE (information-bottleneck β tuning gates Wave 9+ routing) | MASTER_FUSION §3.2 preamble |
| Vault doctrine (vault layout · sync · GRDB · file-system semantics) | **V1** | SHIPPED | — | MASTER_FUSION §3.30; `agent_core/src/storage/vault.rs` |
| SDPage / SDBlock model + Tiptap editor bundle | **V1** | SHIPPED | — | `Epistemos/Models/SDPage*.swift` + `js-editor/` |
| RRF Cross-Index Fusion (Phases 0-7 — `RRFFusionQuery` + flag + observability) | **V1** | SHIPPED | flag-gated `EPISTEMOS_RRF_FUSION_V1` (V1 evaluates flip from off to on) | `Epistemos/Sync/RRFFusionQuery.swift` + `Epistemos/Sync/SearchIndexService.swift` |
| Halo Shadow index (W8.4/W8.7 — tantivy + usearch + RRF) | **V1** | SHIPPED | — | `epistemos-shadow/Cargo.toml` |
| Instant Recall — binary-HNSW + Mamba-2 state injection (Wave 9.33+ / Phase R+) | **V1.x → V2** | NOT-STARTED | SCOPE (4-phase plan Ω18-Ω21; Ω18 V1.x candidate, Ω19-Ω21 V2) | MASTER_FUSION §3.34 |
| Vault Organizer V1 known-limitation tooltip | **V1** | SHIPPED (tooltip + V1.1 deferral note) | — | `Epistemos/Views/.../moveToFolder` + RCA2-P2-005 |
| L4 Engram O(1) hash-recall layer (B2-M12) | **V1.x → V2** | NOT-STARTED | SCOPE | MASTER_FUSION §3.2 L4-Engram row |
| Mamba-2 runtime (save/load/resume/staleness) | **V1.x** | Phase 1A SHIPPED (local mlx-swift-lm fork) | SCOPE (benchmark harness ready; V1.x lands inference integration) | `project_mamba2_runtime` memory |

---

## 3. Agent runtime + tools

| Feature | Tier | Status | Ship-blocker | Source row |
|---|---|---|---|---|
| In-process Rust agent loop (`agent_core::agent_loop`) | **V1** | SHIPPED | — | `agent_core/src/agent_loop.rs` |
| Claude SSE streaming provider | **V1** | SHIPPED | — | `agent_core/src/providers/claude.rs` |
| Perplexity provider | **V1** | SHIPPED | — | `agent_core/src/providers/perplexity.rs` |
| OpenAI provider | **V1.x** | SCOPE | SCOPE (Terminal D Phase D.2 — async-openai 0.30 wrap as `Executor`) | Terminal D prompt §D.2 |
| Gemini provider | **V1.x** | SCOPE | SCOPE (Terminal D Phase D.2 — genai 0.5 OR hand-roll) | Terminal D prompt §D.2 |
| `Executor` trait formalization (D.0) | **V1.x** | NOT-STARTED | SCOPE (Terminal D Phase D.0; gates D.2 providers + B.0 AnswerPacket schema cross-dep) | Terminal D prompt §D.0 |
| Tool registry + 50+ tools | **V1** | SHIPPED | — | `agent_core/src/tools/registry.rs` |
| Local agent (LocalAgent prompt builder + grammar DSL + ConfidenceRouter) | **V1** | SHIPPED | — | `Epistemos/LocalAgent/*` |
| MCP bridge (in-process peer) | **V1** | SHIPPED | — | `Epistemos/Omega/MCPBridge.swift` |
| Specialties registry — 19 macOS-only capabilities (B2-1) | **V1** | SHIPPED doctrine | — | HERMES_AGENT_CORE_2_0_DESIGN §7.4 |
| ArtifactKind + ProvenanceBlock (B2-2) | **V1** | SHIPPED | — | `agent_core/src/artifacts/` |
| AgentExecutor wrapping + ephemeral capability tokens (B2-H20) | **V1.x → V2** | doctrine + macaroon substrate SHIPPED (930 LOC); `OneShot` caveat NOT-STARTED | SCOPE (V1.x adds `Caveat::OneShot` + AgentExecutor wrapping; Wave 9+ auto-research per-fetch consumer) | HERMES_AGENT_CORE_2_0_DESIGN §5.2 |
| Differential Privacy on auto-research (B2-M14) | **V1.x → V2** | doctrine + NOT-STARTED substrate | SCOPE | MASTER_FUSION §3.42 |
| Auto-research loops (Karpathy pattern, H-10) | **V1.x** | doctrine SHIPPED; auto-apply path NOT-STARTED | SCOPE (V1.x ships read-only daily reports; V2 ships full auto-apply once B-1 Live Files + B-3 Confidence Meter + M-2 Eidos Plus all land) | HERMES_AGENT_CORE_2_0_DESIGN §13.5.10 |
| Per-model Knowledge Vaults + cloud distillation (B2-H2) | **V1** | SHIPPED doctrine + PARTIAL substrate (NightBrain `cloud_knowledge_distillation` is NoOp placeholder per Atlas Drift Log) | SCOPE | HERMES_AGENT_CORE_2_0_DESIGN §13.5.7 |
| MLX Model Selection Matrix per memory tier (B2-H17) | **V1** | SHIPPED doctrine | — | HERMES_AGENT_CORE_2_0_DESIGN §13.5.9 |

---

## 4. UI / UX / View layer

| Feature | Tier | Status | Ship-blocker | Source row |
|---|---|---|---|---|
| Epdoc Tiptap editor + slash/bubble/KaTeX/block panels | **V1** | SHIPPED | — | `Epistemos/Views/Epdoc/*` |
| Note browser + sidebar + mini-chat | **V1** | SHIPPED | — | `Epistemos/Views/*` |
| ProvenanceConsole (third leg of MAS feature trio, GenUI day-1) | **V1** | SHIPPED | — | `project_provenance_console_doctrine` 2026-05-04 |
| Halo button + Shadow panel | **V1** | SHIPPED | — | `Epistemos/Views/Halo/*` |
| Settings → Diagnostics (Editor bundle health · Search fusion health) | **V1** | SHIPPED | — | `Epistemos/Views/Settings/*HealthRow.swift` |
| AnswerPacket emission + per-bubble VRMLabelView chip (V6.2) | **V1** | SHIPPED PARTIAL state at `MessageBubble.swift:477` | SCOPE: FULL state (per-bubble binding) is L-2 USER-DECISION row | MASTER_FUSION §3.17 + §3.18 + Wave C9 |
| V6.2 per-bubble VRMLabelView FULL binding (L-2, Wave C9) | **V1.x** | DECISION-gated | DECISION: Option A side-table sink vs Option B `packetId` through `AgentStreamEvent.complete` (recommended) + 1-vs-2 commit decision | `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md` |
| Graph Toolbar — Cursor Force + Shape Bound buttons (L-3, Wave H6) | **V1.x** | DECISION-gated | DECISION: 1 PR vs 2 PR + shape inventory (hexagon/star approved or deferred) | `docs/audits/GRAPH_TOOLBAR_CURSOR_FORCE_SHAPE_BOUND_SPEC_2026_05_12.md` |
| Cognitive Weight slider (Wave H1) | **V1** | NOT-STARTED in UI; doctrine SHIPPED at §3.13 | SCOPE (W1 acceptance bar: 4-tier badge renders on every loaded resource) | MASTER_FUSION §3.13 + Wave H1 |
| 8-setting irreducible-minimum UX (Wave H3) | **V1** | NOT-STARTED | SCOPE | Wave H3 |
| NousResearch SVG art (Wave H4) | **V1** | NOT-STARTED | SCOPE + licensing fallback verified | Wave H4 |
| Inter + JetBrains Mono OFL fonts bundled (Wave H5) | **V1** | SHIPPED | — | Wave H5 |
| Graph Engine Phase A (42 locked architectural decisions, B2-H15) | **V1** | SHIPPED Phase A (2629 tests) | — | MASTER_FUSION §3.38 |
| Graph Engine Phase B GPU compute (8wk queued) | **V2** | NOT-STARTED | SCOPE | §3.38 |
| Graph Engine Phase C cluster 50k+ (4wk queued) | **V2** | NOT-STARTED | SCOPE | §3.38 |
| Pixel Mode vs Tactical Mode duality (B-4) | **V1.x** | DECISION-gated; sprite atlas LANDED | DECISION: toggle UX + sub-agent dispatch + accessory system all V1.1 | PASS-1 §B-4 |
| Simulation Mode v1.6 (Landing Farm · Graph Live · Sidebar Skin) | **V2** | NOT-STARTED in UI; doctrine SHIPPED | SCOPE (V2.5 per POST_RECOVERY_SUBSTRATE_V2_PLAN) | MASTER_FUSION §3.27 |
| Simulation Mode v1.7+ (Hermes Snake as Graph Faculty z+1 plane, Wave G4) | **V2** | doctrine + 5 character-DNA specs (541 LOC SHIPPED) | SCOPE (post-V2.5) | MASTER_FUSION §3.27 + Wave G4 |
| Hermes UI brand (font / color / sigil) — SUPERSEDED 2026-05-05 | **NEVER** | DELETED (HermesBrand, HermesShimmeringSigil, HermesExpertModeView, HermesGraphFacultyGlyph all gone via 2026-05-05 commits b4c583b0 + 80544415 + e07e6378) | — | `feedback_no_hermes_anywhere` memory |

---

## 5. Wave 7-11 user-product layer (the V1 BLOCKERS surfaced by gap audit)

These are the 4 user-decision-gated rows that drove the gap audit. All recorded in MAS_COMPLETE_FUSION §10 Compromises Recorded with recommended-path + 2 alternatives.

| Feature | Tier (recommended) | Status | Ship-blocker | Source row |
|---|---|---|---|---|
| **B-1 Live Files** (Wave 7 substrate primitive) | **V1.x defer (recommended)** | substrate doctrine LANDED at MASTER_FUSION §3.14; feature surface <30% complete; 10-state machine NOT-STARTED | DECISION: V1 placeholder vs V1.1 defer (recommended) vs V1.1 + V2.x split | PASS-1 §B-1 |
| **B-2 Brain Export** (Wave 11 — the YC pitch / Sovereign-AI moat) | **V1.x defer (recommended)** | schemas LANDED via `33e1a5dcb`; no export tool / format / distribution doctrine; no V1 placeholder | DECISION: V1 placeholder vs V1.1 defer (recommended) vs V2 Pro-only | PASS-1 §B-2 |
| **B-3 Confidence Meter + 70%-Triggered Re-Learn** | **V1 SIMPLE + V1.1 FULL (recommended)** | `ConfidenceBadge` (simple form) is V1; biometric + auto-re-learn + SovereignGate (full form) is V1.1 | DECISION: split (recommended) vs V1 full vs V1.1 defer entirely | PASS-1 §B-3 |
| **B-4 Pixel Mode vs Tactical Mode duality** | **V1.x defer (recommended)** | sprite atlas LANDED; toggle UX + sub-agent dispatch + accessory system all V1.1 | DECISION: V1 sprite-as-accent only (recommended) vs V1.1 full toggle vs V1.x duality with accessory | PASS-1 §B-4 |
| **B-5 BrowserEngine MAS/Pro architecture** | **V1 RESOLVED** | DECISION: MAS = Rust `reqwest` HTTP + WKWebView only; Pro = `deno_core` / `rusty_v8` / `boa_engine` / Obscura | RESOLVED 2026-05-16 — landed as §0 immutable rule 6 in MAS_COMPLETE_FUSION | PASS-1 §B-5 |
| **B-6 Hermes-parity salvage** (error classifier · Keychain rotation · session persistence) | **V1 VERIFIED — not a V1 BLOCKER** | error_classifier compiles + 7 tests pass but ZERO production call-sites (orphan); credential_pool + session_persistence NOT in lib.rs (uncompiled / dead) | VERIFIED 2026-05-16 — three salvage modules are scaffolds, not active code; demoted from V1 BLOCKER | PASS-1 §B-6 |

---

## 6. Hermes (positioning — NOT the purged agent)

Critical disambiguation per `project_hermes_removal_2026_05_05` memory. Three distinct Hermes-named concepts exist; only TWO ship.

| Hermes concept | Tier | Status | Ship-blocker | Source row |
|---|---|---|---|---|
| **Hermes Agent** (subprocess + UI overlay + namespace) | **NEVER** | DELETED 2026-05-05 (3 commits: b4c583b0 + 80544415 + e07e6378) — Swift `LocalAgent*` prefix + Rust `Runtime*` prefix replace it | — | `project_hermes_removal_2026_05_05` |
| **Hermes Parity** (Hermes-Function-Calling prompt format, atropos RL trajectory pattern, Hermes-agent-self-evolution) | **V1** | SHIPPED in `agent_core::agent_runtime/` (skills · procedural memory · self-evolution · tool-call parsing) | — | `reference_nousresearch` memory + `agent_core/src/agent_runtime/` |
| **Hermes Snake** (Simulation character, Graph Faculty z+1 plane) | **V2** | doctrine + character-DNA spec LANDED at `docs/fusion/simulation/character-dna/hermes_snake.md` (116 LOC) | SCOPE (Wave G4 / Simulation v1.7+) | MASTER_FUSION §3.27 + Wave G4 |
| **HERMES_AGENT_CORE_2_0_DESIGN** doctrine doc (uses "Hermes" as positioning lineage, not branding) | **V1** | SHIPPED at ~1400 LOC | — | `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` |

---

## 7. Distribution + release

| Feature | Tier | Status | Ship-blocker | Source row |
|---|---|---|---|---|
| MAS bundle (`mas-build` Cargo feature, MAS entitlements) | **V1** | SHIPPED | — | MAS_COMPLETE_FUSION Phase E |
| Pro DMG (Developer ID distribution) | **V2** | NOT-STARTED in pipeline | PAID-TEAM (notarization-log.md skeleton SHIPPED via Terminal A iter 21) | `docs/release/notarization-log.md` |
| Privacy Policy + Licenses + Privacy Manifest | **V1** | SHIPPED (4 artifacts at canonical paths; B2-L4 Phase E.5 cross-link landed iter 66) | — | `docs/legal/*.md` + `Epistemos/Resources/PrivacyInfo.xcprivacy` |
| App Store Connect submission checklist | **V1** | SHIPPED doctrine (MAS_COMPLETE_FUSION §E.5) | DECISION: actual first submission pending (user authority) | §E.5 |
| XPC Mastery — 5-service decomposition (VaultXPC + AgentXPC + ProviderXPC + WASMExecXPC + Main) | **V2** | doctrine + Wave F (PAID-TEAM-GATED) | PAID-TEAM (XPC service entitlements + trust attestation + capability-token IPC + sandbox-within-sandbox for WASM) | MASTER_FUSION §3.19 + Wave F |
| WASMExecJIT entitlement (`cs.allow-jit + cs.disable-library-validation`) | **V2** | doctrine | DECISION (Terminal A iter 18 §10.4 — pending user direction) | `docs/release/MAS_APP_REVIEW_NOTES.md §10.4` |
| Channel Relay (7 channel types: iMessage · Telegram · Slack · Discord · WhatsApp · Signal · Email) | **V2** | doctrine SHIPPED at `docs/channels/relay-ops.md` (80 LOC); ChannelIdentity 7 cases SHIPPED in Swift; iMessageDriver SHIPPED (3 files); other 6 workers Pro-only | — | MAS_COMPLETE_FUSION §B2-L3 |

---

## 8. Forward-staged primitives (6, all NOT-STARTED in code)

Substrate spec frozen; code lands when implementation slice fires. Each carries audit-row gate.

| Primitive | Source | Predicted-absent location | Implementation slice |
|---|---|---|---|
| B2-H19 per-Live-File network egress allowlist | FINAL_SYNTHESIS §5.3 | `agent_core/src/security/egress.rs` | Wave 9+ post-Live-Files-V1 |
| B2-H20 ephemeral capability tokens (`Caveat::OneShot`) | FINAL_SYNTHESIS §5.2 | `agent_core/src/cognitive_dag/macaroons.rs` (`OneShot` caveat) | V1.x AgentExecutor wrapping |
| B2-M14 differential privacy on auto-research | FINAL_SYNTHESIS §5.4 | `agent_core/src/auto_research/dp.rs` | Wave 9+ post-auto-research-V1.x |
| B2-L1 heal event log + TTL | iter-62 doctrine | `agent_core/src/heal/` (directory) | V1.x post-V1-ship |
| B2-L2 nightbrain eligibility widening (4 missing conditions) | iter-64 §5.0 correction | `agent_core/src/nightbrain/eligibility.rs` | V1.x widening slice |
| B2-M11 JIT entitlement defense | iter-30 audit-of-audit #3 | `docs/release/MAS_APP_REVIEW_NOTES.md §1` (already SHIPPED) + binary scrub at link-time | MAS submission |

---

## 9. Code-side hardening floor (V1 SHIPPED — the existing infrastructure)

These shipped pre-loop-run + need to be retained through V1+ submissions.

| Feature | Tier | Status | Source |
|---|---|---|---|
| Subprocess hardening (`harden_cli_subprocess` + 10-var allowlist + 24-vector denylist) | **V1** | SHIPPED | `agent_core/src/security.rs` |
| Memory-pressure response (`respond_to_memory_pressure` FFI; `evict_stale` + `prune_finished` + `cleanup_all`) | **V1** | SHIPPED | `agent_core/src/bridge.rs` + `Epistemos/App/EpistemosApp.swift` |
| Swift Memory + Energy hardening (200 fetch cap on chats · TimelineView · WKProcessPool sharing · WKWebView dismantle · MLX idle-unload TTLs · KaTeX nonPersistent store) | **V1** | SHIPPED | `Epistemos/Views/.../*` + `Epistemos/Engine/MLXInferenceService.swift` |
| Honest Handle FFI doctrine (opaque handles + versioned envelopes + cross-runtime parity tests) | **V1** | SHIPPED | MASTER_FUSION §3.15 |
| MAS Hardened Runtime entitlements (6 keys + `cs.allow-jit` for MLX shader compilation only) | **V1** | SHIPPED | `Epistemos-AppStore.entitlements` + MAS_APP_REVIEW_NOTES §1 |

---

## 10. Status-transition log

Append-only. Each row = one ship-tier transition.

| Date | Feature | From | To | Trigger |
|---|---|---|---|---|
| 2026-05-08 | KV-Direct gate Rust + Metal | absent | V1 SHIPPED (290+65 LOC) | Phase B.0-KV close |
| 2026-05-13 | MASTER_FUSION §3.34 Instant Recall (Wave 9.33+ / Phase R+) | absent | V1.x → V2 doctrine | B2-H3 close |
| 2026-05-15 | RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL | absent | doctrine pointer | B2-H9 close (iter 21) |
| 2026-05-16 | MAS_COMPLETE_FUSION §0 immutable rule 6 (BrowserEngine) | absent | V1 doctrine | B-5 close |
| 2026-05-16 | B-1/B-2/B-3/B-4 decisions in §10 Compromises | absent | DECISION rows with default + alternatives | PASS-1 B-1..B-4 close |
| 2026-05-16 | B-6 Hermes-parity salvage | V1 BLOCKER (suspected) | V1 VERIFIED — not a blocker (3 salvage modules are scaffolds) | iter-X verification |
| 2026-05-16 | This ledger (`V1_SHIP_LEDGER_2026_05_16.md`) | absent | integration artifact 2 of 3 at ~280 LOC | iter 77 (this commit) |
| 2026-05-16 | F-VaultRecall-50 vault retrieval bug | OPEN (highest-priority V1.x product fix per 4-advisor synthesis) | ✅ Fix B SHIPPED at `agent_core/src/storage/vault.rs` (cargo 1190 → 1194; 2 of 3 defects fixed; defect 3 V1.x-deferred) | iter 81 commit `2281c73f0` |

---

## 11. Open user-decisions (V1 vs V1.x routing pending answer)

These are surfaced for explicit user direction. Cannot be auto-implemented.

1. **B-1 Live Files** — V1 placeholder vs V1.1 defer (recommended) vs V1.1 + V2.x split
2. **B-2 Brain Export** — V1 placeholder vs V1.1 defer (recommended) vs V2 Pro-only
3. **B-3 Confidence Meter** — V1 SIMPLE + V1.1 FULL (recommended) vs V1 full vs V1.1 defer
4. **B-4 Pixel/Tactical** — V1.1 defer (recommended) vs V1 full toggle
5. **H-3 / B2-H6 EditPage macaroon** — V1.1 defer (recommended) vs V1 read-only attach
6. **B2-M5 HardwareProfile budget divergence** — V1 keep divergence (9.6 GB) vs V1.x align (10.5 GB)
7. **L-2 V6.2 per-bubble VRMLabelView FULL binding** — Option A vs Option B (recommended) + 1 vs 2 commit
8. **L-3 Graph Toolbar buttons** — 1 PR vs 2 PR + hexagon/star approved vs deferred
9. **§10.4 WASMExecJIT entitlement** — Pro V1 vs V2 deferred
10. **B-3 Undo (V1.1 Reversal/Undo scope)** — Confidence Meter re-learn (a) vs per-edit Undo (b) vs both (c)
11. **B2-H16 Chatterbox voice** — V1 Pro vs V1.x Pro vs post-V1 Pro
12. **ORPHAN-HERMES-SALVAGE-001** — wire vs scaffold vs delete (3 salvage modules)
13. **RCA13-P0-001 vault lifecycle** — design pending user direction
14. **F-VaultRecall-50 vault retrieval bug** — ✅ **RESOLVED iter 81 commit `2281c73f0`** — Fix B SHIPPED (stop-word filter + AND-for-short-queries at `agent_core/src/storage/vault.rs:495-548`; cargo 1190 → 1194 with 4 new tests passing; addresses 2 of 3 diagnosed defects from `docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md`; defect 3 score-clamp normalization deferred to V1.x).

---

## 12. What this ledger ISN'T

- **NOT a replacement** for MAS_COMPLETE_FUSION §10 Compromises Recorded. §10 carries decision rationale + alternatives + V1.x triggers per row; this ledger is a flat view that summarizes everything.
- **NOT a research roadmap.** Doesn't include items that aren't in current canon.
- **NOT a feature design doc.** Each row points to its canonical design doc; doesn't reproduce the design.
- **NOT a code map.** CLAUDE.md FILE MAP carries the per-file inventory; this ledger summarizes ship status.

---

*— End of V1 Ship Ledger. ~85 feature rows · 13 open user-decisions · 11 status transitions logged · cross-refs to MASTER_FUSION §3 + §6 + MAS_COMPLETE_FUSION §10 throughout. Integration artifact 2 of 3 per 4-advisor synthesis.*
