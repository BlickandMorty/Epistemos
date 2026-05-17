# Day in the Life — Epistemos V1 Power User Scenario (2026-05-16)

**Purpose:** concrete narrative grounding every V1-shipped UAS-ACS-touching surface in one user's actual day. Per the 4-advisor synthesis: **the canon has coverage + a coherence layer (UAS-ACS Canon) + a ship classification (V1 Ship Ledger); this artifact closes the trio by showing what it FEELS like to use.**

**Audience:** anyone who needs to understand "does the V1 substrate actually compose into a coherent product?" Designers, App Reviewers, future maintainers, the user themselves on a hard day, and any AI agent (Claude, Codex, Kimi) that needs to ground abstract architecture in lived experience.

**The user:** Jordan (the actual maintainer per `user_profile.md`). M2 Pro 16 GB Mac. Solo developer who also writes daily notes, reasons about complex systems, and refuses cloud lock-in.

**Cross-refs:** integration artifact 3 of 3. Artifact 1 = `UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md`. Artifact 2 = `V1_SHIP_LEDGER_2026_05_16.md`. Read those for the structural / classification layers; this is the experiential layer.

**Discipline:** narrative is grounded in actual V1-SHIPPED surfaces only. Every surface name in **bold** maps 1:1 to a row in the V1 Ship Ledger. Surfaces marked *(V1.x)* or *(V2)* are flagged in italics — they don't ship today but the narrative shows the seam where they'll land.

---

## 7:14 AM — Cold launch

Jordan opens the laptop, double-clicks `Epistemos.app`. The icon bounces; the launch sequence runs through **`AppBootstrap.swift`** (~3861 LOC). Behind the dock badge: GRDB opens the vault database, the **Tantivy writer** initializes at 15 MB heap (the post-perf-hardening floor), the **MLX inference service** stays cold (idle-unload TTL 4 s on 16 GB — won't load Qwen3.5-9B until first agent call), **Halo Shadow index** opens at `<vault>/.epcache/shadow` via **`RustShadowFFIClient.openAt`**, and the **Cognitive DAG** mirror catches up its Merkle root from disk.

Jordan sees the editor window. First note opens in ~0.4 s (the **MRU BlockMirror prewarm** that Terminal A iter 3 wired in `Epistemos/App/AppBootstrap+Prewarm.swift`). No spinner. No "Press any key" purgatory.

**Substrate underneath:**
- UAS (Unified Address Space): the prewarm runs on a `Task.detached` off-main thread; the 5 MRU notes' bodies land in BlockMirror SwiftData context which is the same address space that Tiptap's WKWebView reads via `EpdocEditorChromeView` shared `WKProcessPool` (50 MB saved across all editors via single pool).
- ACS (governance): **NightBrain scheduler** (`agent_core::nightbrain`) is in `should_admit() = false` state — Jordan just woke the machine, the 3-of-7 conditions (thermal · power · idle) aren't all green yet. No background tasks fire. Jordan gets the cold-start CPU.

---

## 7:38 AM — First Halo invocation

Jordan starts writing about a half-remembered conversation with a collaborator: *"Was that point about local-first storage in the Tuesday call or the email thread?"*

He hits **⌘K** — the **Halo button** activates. The **HaloController** state machine ticks: `dormant → watching → encoding → searching`. The text in-cursor passes through **Model2Vec** (the small embedder pre-warmed by **`ShadowVaultBootstrapper`**), the embedding lands in **usearch HNSW** + the **Tantivy BM25** lexical query fires in parallel, **RRF fusion at k=60** combines them (`epistemos-shadow/src/backend/rrf.rs:22 RRF_K_DEFAULT`), and the **ShadowPanel** opens with 5 ranked hits in <250 ms.

Top hit: "Tuesday call notes — 2026-05-12" — exactly the conversation. Second hit is the email thread Jordan was second-guessing about. Both correct.

**Substrate underneath:**
- KV-Direct gate (F-KV-Direct-Gate): Jordan's query string → tokens → MLX → embedding is one zero-copy path. No tensor copies. The Metal shader at `Epistemos/Shaders/kv_direct_gate.metal` runs the Hamming-distance scan on the binary HNSW index at ~350 GB/s on ARM NEON (the 1 M-note bound is 128 MB resident, full scan ~0.37 ms).
- 5-plane formalism: the Halo query is an `Episodic` plane action; the cross-index fusion result is registered in the `Verification` plane via `SearchFusionMetrics.shared.record(latencyMs:results:)`.
- Variant Ladder (doctrine §3.7): the query bypasses the LLM tier entirely — pure deterministic retrieval, no escalation to Tier 4+.

---

## 9:02 AM — Chat with the agent

Jordan opens the chat panel. Asks: *"What's the contract our V6.1 §1.3 says we need for the MissionPacket schema?"*

The **ConfidenceRouter** evaluates: this is a research-tier intent (cites a specific doctrine §). Routing budget says: **local first**. **Qwen3.5-9B-MLX-4bit** loads (~3.2 s first-load on cold MLX — within the 4 s TTL window so the model stays warm for subsequent turns). The local agent runs **`vault.search`** internally via **`LocalAgentPromptBuilder`** + **`LocalToolGrammar`** grammar-constrained generation. Tool call returns 3 hits.

Local agent assembles the answer with confidence 0.78. Below the **ConfidenceRouter** floor of 0.75 for research-tier — barely passes local. Final response renders in the chat with a **VRMLabelView chip** (the AnswerPacket emission per V6.2 §S3.5) attached to the message bubble showing `local · Qwen3.5-9B · 0.78 conf`. PARTIAL state — the per-bubble FULL binding is L-2 *(V1.x)*, but the simple chip is shipped.

Jordan reads it. Looks right but is uncertain about the "AnswerPacket schema gate" claim. Clicks the chip.

The chip expands into a **Provenance Console** drawer (shipped 2026-05-04 at `ad6280cf`). Shows: query → vault hits used (3 notes + line numbers) → tool calls in order → time-of-day → memory residency → token counts. Jordan sees one of the vault hits is `HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md §1.3` directly. Clicks the line, jumps to the note. Confirms: the answer is grounded.

**Substrate underneath:**
- AnswerPacket emission ladder (§3.17): the chip carries the audit-trail anchor; the Provenance Console renders it via the **GenUIDispatcher** (T0 sub-track 4) using a typed `AnswerPacketPayload` schema.
- Confidence floor (§3.7): the routing decision was made BY DOCTRINE, not by ad-hoc rules — the 0.75 floor is `epistemos.routing.confidence_floor.research` and is canonical in `MASTER_FUSION §3.2 Residency Governor` + Compression-Governance objective.
- Macaroon capability (§3.6 Sovereign Gate): the `vault.search` tool was permitted by a TTL-bound macaroon issued at chat-session start; if Jordan had asked the agent to MUTATE a vault note instead of read, the Sovereign Gate would have asked for biometric reauth.
- Cognitive DAG: every tool call and provenance hit is a `Claim` node + edges; the answer Jordan reads is reachable from the root by `DerivesFrom` walks.

---

## 10:24 AM — A genuine "needs cloud" moment

Jordan asks: *"Draft a 600-word LinkedIn post in my voice about the F-ULP-Oracle research."*

This is HIGH stakes for tone + voice. **ConfidenceRouter** scores: creative-writing tier, voice-match required, single-shot output expected, complexity index 0.83. **Route → Claude Opus 4.6** (cloud, via `agent_core/src/providers/claude.rs` raw URLSession-via-reqwest, NO Swift SDK because Anthropic doesn't have one).

Before the cloud request fires, the **Sovereign Gate** asks: *"This request will send 850 tokens to api.anthropic.com. Approve?"* Jordan approves (he's set the policy to "ask once per session for cloud"). The macaroon issuer chains a TTL-bound capability for `network: api.anthropic.com:443` and `model: claude-opus-4.6`.

Streaming response arrives. Each token forwards immediately to the chat delegate (no buffering — per the NON-NEGOTIABLE CONSTRAINTS in `CLAUDE.md`). **Thinking blocks are preserved** in the stream (also a NON-NEGOTIABLE per the post-2025 Claude agent contract). The 600-word draft renders. Voice is good. Jordan tweaks two sentences, copies, posts.

**Substrate underneath:**
- Three-plane handoff: routing decision → `Controller` plane → cloud call → `Episodic` plane (the response itself) → audit anchor in `Verification` plane.
- Prompt caching (§3.18 sibling): the system prompt + Jordan's voice-sample prefix is cached at Anthropic (Jordan's prior LinkedIn posts already in the cache from earlier this week); only the new query bills tokens.
- *(V1.x)* Ephemeral capability token (B2-H20): today the macaroon is TTL-bound (5 min). V1.x will add `Caveat::OneShot` so this specific cloud call expires AS the response arrives, preventing reuse. The substrate is forward-staged in `agent_core/src/cognitive_dag/macaroons.rs` (930 LOC) — the `OneShot` variant lands in the V1.x AgentExecutor wrapping slice.

---

## 11:47 AM — Memory pressure

Jordan has three editor windows open (KaTeX preview + Tiptap main + sidebar). Plus the agent is mid-response. Plus he just imported a 200 MB research paper PDF. Memory pressure: macOS fires `.warning`.

The `RuntimeDiagnosticsMonitor`'s **`DispatchSourceMemoryPressure`** handler catches it. Calls Rust FFI `respondToMemoryPressure(level: 1)`. Rust runs:
- `ShmPool::evict_stale(60s)` → frees 32 MB of shared-memory segments
- `GlobalSessions::prune_finished(5min)` → drops 3 completed agent sessions, frees 18 MB
- Swift side: `SearchIndexService.releaseMemoryPressureCaches()` → `PRAGMA optimize` + `shrink_memory` + `dbPool.releaseMemory()` frees another 40 MB
- `MetalRuntimeManager.deepUnload()` not called yet (warning level only — would fire on `.critical`)
- KV cache of persistent MLX SSM session NOT dropped yet (warning only — critical would drop)
- `EpdocWebViewShared.resetPoolIfIdle()` swaps the shared `WKProcessPool` since no live WebView counter — frees 30-40 MB

Total: ~120 MB returned. Memory pressure subsides without Jordan noticing.

Provenance Console (if Jordan looks) shows a `MemoryPressureRelief` row: `level=1 · segments_evicted=7 · bytes_freed=120MB · sessions_pruned=3 · timestamp=11:47:23`.

**Substrate underneath:**
- ACS homeostatic loop (Reactive): this is exactly the Reactive loop from MASTER_FUSION §3.8 four-homeostatic-loops table. The Markov-blanket boundary of the OS pressure signal hits Epistemos; the ViableSystem trait (forward-staged in `acs.rs` research-tier) doesn't run today, BUT the equivalent functional behavior (`respondToMemoryPressure` ladder) ships in V1.
- MAS Hardened Runtime: all of this happens inside the sandbox. No subprocess hop. No XPC. No JIT compilation of user code. Just in-process memory triage.

---

## 1:15 PM — The vault-recall bug (the open product wound)

Jordan asks Qwen3.5-9B: *"Pull my notes on residency governance."*

Qwen returns 7 notes. The first 7 in the list are about UI design, Hermes branding, character-DNA specs for Simulation Mode, and the user_hardware.md memory record. **None of them are about residency governance.**

The actual notes (~30 of them at MASTER_FUSION §3.2 referenced in vault) are *not in the top 7*.

This is **F-VaultRecall-50** — the highest-priority product bug per the 4-advisor synthesis from earlier this session. Real. Reproducible. User-visible. Trust-eroding.

Today Jordan works around it: he uses Halo Shadow (⌘K) instead — which DOES return the right notes because Halo uses RRF cross-index fusion (BM25 + binary-HNSW) not the agent's `vault.search` tool which routes through a different retrieval path.

*(V1.x — open work):* the vault retrieval bug is the next product slice this terminal could pivot to if user redirects. Audit doc surfaces: the agent's `vault.search` tool probably hits a stale or mismatched index, OR the embedding model used for the agent path is different from Halo's Model2Vec, OR there's a stop-word filter that's destroying signal-bearing tokens. Diagnosis is 2-4 hours of focused product work — NOT loop-shaped, but the most leverage available.

**Substrate underneath:**
- The bug exists in the seam between **agent runtime** (`agent_core::tools::vault::search`) and **Halo Shadow** (`epistemos-shadow` via FFI). Both touch UAS but through different retrieval ladders. The integration artifact UAS-ACS Canon doesn't fix the bug; it just makes the seam visible.
- This is a real argument for the V1 Ship Ledger §11 listing F-VaultRecall-50 as an open decision item — it should likely block V1 ship until fixed OR be explicitly accepted as a V1 known limitation.

---

## 3:00 PM — NightBrain wakes (the autopoietic loop in action)

Jordan is on a call. Laptop sits idle. CPU thermal nominal. Battery on AC. No active agent session.

**NightBrain** `should_admit()` returns `true` for the first time today. **`maintenance_log` task body** runs (the one real body, per B.9 1/10 row in MAS_COMPLETE_FUSION §8 line 1085). Appends a 1-row entry to `MAINTENANCE_LOG` ring buffer (capacity 256, ~96 bytes/entry). 9 other canonical tasks (`event_store_checkpoint_vacuum` · `search_index_passive_checkpoint` · `dedupe_artifacts` · `workspace_snapshot_compaction` · `memory_distillation` · `cloud_knowledge_distillation` · `session_graph_generation` · `skill_evolution_analysis` · `ssm_state_pruning`) are still `NoOpTask` placeholders — they report `skipped(1)` to ObservationLogEntry.

Total work this admit window: 1 real row appended, 9 placeholders logged. ~3 ms compute. ~0 user-perceptible cost.

Jordan never sees it happen. The Provenance Console will show it later if asked: `idle_admit · 2026-05-16 15:00:11 · thermal_ok=true · power=ac · idle_min=8 · ran=maintenance_log · skipped_9_placeholders`.

**Substrate underneath:**
- ACS homeostatic loop (Adaptive / plastic): the maintenance log is the visible tip of the Adaptive loop. The 6 NoOpTask placeholders are the substrate spec for V1.x bodies that will plug in (`dedupe_artifacts` is the proposed first; `memory_distillation` is the second).
- *(V1.x)*: per the L-4 inventory cross-link, the 4 missing eligibility conditions (flagged-notes · 1-5 AM window · 12h cooldown · no-active-agent) live in `agent_core/src/nightbrain/eligibility.rs` — forward-staged as B2-L2. They land in a V1.x widening slice.
- Golden-ratio scheduling (§3.35) — the 10 tasks SHOULD fire at φ-spaced offsets to avoid resonance pressure. NOT-STARTED today (NightBrain runs at fixed cadence). Lands when φ-spacing slice fires (V1.x or Wave 9+).

---

## 5:42 PM — Skills + procedural memory + self-evolution

Jordan has done this same workflow 3 times this week: select a chat response → ⌘+Shift+S → "save as skill". The third invocation triggers **skill-evolution analysis** (`agent_core::agent_runtime::skills`).

The system suggests: *"This pattern repeats — should I auto-detect it as the 'Daily Standup Draft' skill and offer one-click invocation in the chat dock?"*

Jordan accepts. A new skill row appears in Settings → Skills. The procedural-memory schema (`epistemos.skill.v1`) is validated via `MutationEnvelope` (schema-validated writes only, never raw — per MASTER_FUSION §6 Wave A5). The skill carries a confidence sample (3 prior invocations) + a re-learn trigger (if it fires < 70% success rate, the Confidence Meter will surface re-learn).

*(V1.1)* B-3 Confidence Meter FULL form will land biometric gate + auto-re-learn. Today's V1 ships SIMPLE form (just the `ConfidenceBadge`); auto-detect skill-suggestion already works via in-process `agent_runtime::skills::evolution`.

**Substrate underneath:**
- Hermes parity (NOT the purged agent): this is `agent_core::agent_runtime::*` — the in-process Rust replacement for the legacy subprocess. Skills + procedural memory + self-evolution + tool-call parsing all live here per `feedback_hermes_is_real_agent` memory.
- ClaimGraph + RunEventLog (SCOPE-Rex): the skill suggestion is recorded as a `Claim` node ("recurring pattern detected"); user acceptance is a `MutationEnvelope` operation; both are in the DAG with provenance.

---

## 8:30 PM — Brain export *(V1.1 — currently deferred)*

Jordan wants to back up his vault + skill memory + procedural traces for an off-Mac scenario (he's thinking about the road trip in two weeks).

**B-2 Brain Export is V1.1-deferred** per MAS_COMPLETE_FUSION §10. Schemas LANDED via `33e1a5dcb` but no export tool / format / distribution doctrine. Today Jordan uses standard macOS Time Machine backup of `~/Library/Application Support/Epistemos/` which captures vault + GRDB + Shadow index + skills. Not the curated "Sovereign-AI moat" pitch experience but functional.

V1.1 will bundle this into a single `.epbundle` (the format already exists for ReplayBundle per `agent_core/src/provenance/replay.rs`) including: vault notes · model-vault folders · skill registry · provenance ledger snapshot · Mamba-2 SSM state checkpoints if any.

---

## 11:15 PM — Closing the day

Jordan closes the laptop. macOS sleeps. Epistemos's NightBrain detects sleep transition — sets `should_admit() = false` permanently until next wake. KV cache holds. WKWebView pools idle but resident. Vault GRDB connection is in WAL mode so the sleep doesn't corrupt.

Total session: 16 hours active, ~4 hours actual usage, ~50 chat turns (35 local · 15 cloud), 23 Halo invocations, 7 skill triggers, 1 memory-pressure relief event, 4 NightBrain admit windows (only 1 user-visible — the rest were `.warning` cleanups).

Provenance Console end-of-day summary (if Jordan opens it before closing):
- 1 LinkedIn post drafted (cloud Claude Opus 4.6) — 850 tokens billed
- 7 skill invocations · 1 new skill auto-detected
- 23 Halo searches · all returned 5 hits · p95 latency 247 ms
- 12 vault note edits · all rolled through MutationEnvelope · 0 schema violations
- 1 vault-recall bug encounter at 1:15 PM — workaround used (Halo) — logged for F-VaultRecall-50 follow-up
- 0 cargo test regressions · cargo baseline still 1190/1190
- 0 cloud requests without explicit Sovereign Gate approval

---

## What this scenario shows

1. **The UAS-ACS substrate is invisible to Jordan in good moments.** Halo just works. The agent just routes. NightBrain just runs. The substrate is felt only when something goes wrong (the 1:15 PM vault-recall bug).

2. **The V1 surface is coherent enough to live in.** The substrate doesn't get in Jordan's way. He doesn't have to think about it. He gets work done — writes a LinkedIn post, drafts notes, searches efficiently, never hits a wall except for the one open product bug.

3. **The seams are honest.** When something is V1.x (like full per-bubble VRMLabelView binding, or the `OneShot` macaroon caveat), the seam is visible — the simple version ships, the full version is forward-staged with substrate already present, and the user-decision rows in MAS_COMPLETE_FUSION §10 are surfaced when activation requires user direction.

4. **The 6 product terminals are the actual ship work.** Terminal A landed iter 29 self-audit clean during this scenario's writing; the others run on their own branches. This terminal (the one writing this doc) is the integration layer that helps Jordan SEE the system as one thing.

5. **F-VaultRecall-50 is the load-bearing open product fix.** Every other surface in this scenario works as advertised. Vault recall does not. The 4-advisor synthesis was right to call it the highest-priority product work — Jordan literally cannot trust the agent to find his own notes today.

---

## Cross-references

- **Substrate / structural view:** `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` — every UAS-ACS surface with status + cross-link map.
- **Ship classification view:** `docs/fusion/V1_SHIP_LEDGER_2026_05_16.md` — every feature in this scenario classified V1/V1.x/V2/never with ship-blocker per row.
- **Doctrine spine:** `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §3 (Atlas) + §6 (Wave plans).
- **User-decision queue:** `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §10 Compromises Recorded — 13 open rows pending Jordan's direction.
- **The open bug:** F-VaultRecall-50 (not yet a formal audit row — surfaced in this session's earlier 4-advisor synthesis as the highest-priority product work).

---

## What this scenario ISN'T

- **NOT a feature roadmap.** Doesn't propose new V1.1 / V2 features; describes what V1 ships TODAY.
- **NOT a marketing piece.** No "magical experience" framing. Honest about the rough edges (vault-recall bug, V1.1 deferrals, memory pressure).
- **NOT a benchmark.** Latency numbers (247 ms Halo p95 · 0.4 s first-note-open · 3.2 s cold MLX load) are realistic estimates based on hardware-perf-hardening commits; they aren't measured today's-session numbers.
- **NOT comprehensive.** Doesn't touch every V1 surface (Apple Foundation Models, full chat UI features, advanced Tiptap blocks). Focuses on the UAS-ACS-touching surfaces that prove substrate coherence.

---

*— End of Day-in-the-Life. Integration artifact 3 of 3 per 4-advisor synthesis. 9 scenes from 7:14 AM to 11:15 PM grounding every V1-shipped UAS-ACS surface in lived experience. F-VaultRecall-50 surfaces as the load-bearing open product fix.*

---

## T9 Iter 20 Scenario Delta - 2026-05-17

The scenario above remains an honest main-shipped view, but the active branches changed the future-state read:

- **1:15 PM vault recall failure:** still accurate for main, but T4 branch now has the broader Vault Context Contract patch through `93ad1953a`: candidate-pool validation, MMR traces, recency/user/graph signals, UI provenance, weak fallback rejection, and prompt evidence thresholds. In the next scenario revision after merge, this scene should become "agent refuses or broadens when evidence is weak" instead of "workaround used through Halo."
- **Agent setup:** T2 `79cb183ee` adds an AgentBlueprint Settings mission runner. The day-in-life should eventually include Jordan creating a per-model mission with explicit tool/scope/approval choices, but only after runtime proof and capability badges are verified.
- **Epdoc structured edits:** T1 branch now has an Epdoc receiver gate and JSON corpus coverage. A post-merge scenario should show model-authored Epdoc blocks landing as structured mutations, not full-document replacement.
- **Accessibility and visual audit:** T6 pass-1 coverage is branch-complete across `Epistemos/Views/**`. The lived scenario is not accessibility-complete until the T6 pass-2 a11y fixes land, especially MetalGraphView, onboarding, Epdoc chrome, and AgentBlueprint UI.

Until those branches merge, the original day-in-life remains the shipped truth; this delta is the branch-synthesis overlay for the next revision.
