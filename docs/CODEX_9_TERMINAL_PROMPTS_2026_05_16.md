# Codex 9-Terminal Paste-Ready Prompts — Epistemos 2026-05-16

**Purpose**: spin up 9 parallel Codex CLI terminals, each owning ONE sub-mission of the deep-investigation prompt. Branches cut from `main`. PRs back to `main` when each slice's acceptance bar is met.

**Pre-flight (run once before starting any terminal)**:

```bash
cd /Users/jojo/Downloads/Epistemos
git checkout main
git pull origin main
# Verify baselines hold
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet | tail -3
# Optional: xcodebuild verify
# xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
```

**Terminal map (at a glance)**:

| Term | Mission | Branch | Worktree | Priority |
|---|---|---|---|---|
| **T1** | §4.A Tri-Fusion MD⇄JSON⇄HTML | `codex/t1-trifusion-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t1-trifusion` | P1 |
| **T2** | §4.E + §4.F Model Gating + Local Agent (HEART) | `codex/t2-agent-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t2-agent` | **P0** |
| **T3** | §4.G UAS-ACS Canon + falsifier ladder | `codex/t3-uasacs-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t3-uasacs` | P1 |
| **T4** | §4.H F-VaultRecall-50 (vault repair) | `codex/t4-vault-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t4-vault` | **P0 — most urgent UX** |
| **T5** | §4.I EML-IR Primitive Stack (6 IRs) | `codex/t5-emlir-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t5-emlir` | P2 |
| **T6** | §4.C UI/UX recursive audit | `codex/t6-uiux-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t6-uiux` | P1 |
| **T7** | §4.B Deep EML MVP | `codex/t7-eml-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t7-eml` | P2 |
| **T8** | §4.D Biometric Lock (gated) | `codex/t8-biometric-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t8-biometric` | P3 (gated on T1+T2+T6) |
| **T9** | Coordinator + drift-catch + cross-PR review | `codex/t9-coord-2026-05-16` | `/Users/jojo/Downloads/Epistemos-t9-coord` | continuous |

**Recommended startup order** (don't launch all 9 at once — context + thermals):

1. **T4 first** (vault repair, most urgent UX). Let it run a few iters.
2. **T2 second** (agent + gating — the HEART). Big mission, takes longest.
3. **T3 third** (UAS-ACS canon — doctrine work that T2/T1/T5 will reference).
4. **T6 fourth** (UI/UX audit on recent additions, runs continuously).
5. **T1, T7, T5** can come online when you have bandwidth.
6. **T9** anytime (it's a watcher, low resource).
7. **T8** only after T1 + T2 + T6 ship.

---

## T1 — §4.A Tri-Fusion MD ⇄ JSON ⇄ HTML

### Bootstrap

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t1-trifusion -b codex/t1-trifusion-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t1-trifusion
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T1 at /Users/jojo/Downloads/Epistemos-t1-trifusion
on branch codex/t1-trifusion-2026-05-16 (cut from main).

You own §4.A Tri-Fusion content fabric from docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md.

ITERATION: continuous. After each commit, immediately start the next iter. NO PAUSE.

READ FIRST (iter 1):
1. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §0 Manifesto + §4.A
2. docs/CODEX_HANDOFF_2026_05_16.md
3. CLAUDE.md
4. agent_core/src/research/hyperdynamic_schemas/ (every file)
5. agent_core/src/research/eml/ (every file)
6. Epistemos/Engine/EpdocPasteClassifier.swift + EpdocBlockTemplateStore.swift
7. js-editor/src/ (Tiptap config + paste handler)
8. Epistemos/LocalAgent/LocalAgentPromptBuilder.swift + LocalToolGrammar.swift

SCOPE LOCK — touch only:
- agent_core/src/tri_fusion/ (new module — create it)
- agent_core/src/research/hyperdynamic_schemas/ (extend, do not break)
- agent_core/src/bridge.rs (FFI for TriFusionDocument opaque handle)
- Epistemos/LocalAgent/LocalToolGrammar.swift (add Tri-Fusion mutation grammar)
- Epistemos/Engine/Epdoc*.swift (add structured-mutation receiver)
- docs/audits/HYPERDYNAMIC_SCHEMAS_AUDIT_<date>.md
- docs/fusion/TRI_FUSION_HYPERDYNAMIC_SCHEMAS_<date>.md
- tests/tri_fusion_*.rs (property test corpus ≥ 200 docs)

DON'T TOUCH (reserved for other terminals):
- agent_core/src/storage/vault.rs (T4 owns retrieval)
- Epistemos/State/InferenceState.swift gating (T2 owns)
- Epistemos/Engine/AmbientFrequency*.swift (T6 owns)
- Anything biometric (T8 owns)

PER-ITER RITUAL:
1. git status / git log --oneline -5
2. cargo test --manifest-path agent_core/Cargo.toml --lib (baseline ≥ 1671)
3. §5.0 reconciliation: verify substrate state on disk before writing doctrine
4. Pick ONE slice: audit pass · doctrine doc · type definition · round-trip lemma · FFI · grammar · property test
5. Implement + test
6. Commit: <type>(<scope>): <one-line> · HEREDOC body · Co-Authored-By: Codex (T1) <noreply@anthropic.com>
7. Push to origin/codex/t1-trifusion-2026-05-16 every 5-10 commits
8. Open draft PR back to main with the §4.A acceptance bar checklist when ready
9. Go to 1. NO PAUSE.

PHASE ORDER:
A. Investigation (iters 1-10): audit hyperdynamic_schemas + eml. Output audit doc.
B. Doctrine (iters 11-20): write TRI_FUSION_HYPERDYNAMIC_SCHEMAS doctrine doc with 7 sections.
C. Implementation (iters 21+):
   - agent_core/src/tri_fusion/mod.rs (TriFusionDocument · TriFusionMutation · TriFusionWitness)
   - Round-trip lemmas: MD↔JSON byte-equal · HTML↔JSON tree-equal · JSON identity
   - FFI: TriFusionDocument opaque handle via UniFFI
   - LocalToolGrammar extension for Tri-Fusion mutations
   - Epdoc receiver: surface model edits as structured ops (insert-block, mutate-block, link-block, transclude-block)
   - Provenance: every mutation gets a ClaimGraph node + Cognitive DAG edge

ACCEPTANCE BAR (open PR when ALL pass):
- ≥ 200-doc round-trip property test corpus passes byte-equal MD↔JSON↔MD
- ≥ 200-doc HTML↔JSON↔HTML preserves semantic tree
- Cargo test count grows by ≥ 50
- xcodebuild green
- TriFusionDocument handle FFI round-trips on a Swift integration test
- LocalAgentPromptBuilder emits at least one Tri-Fusion mutation in a real chat turn
- Epdoc visibly highlights model-authored blocks (per Cognitive Weight Class doctrine)

COORDINATION:
- T7 also touches eml/. Read T7's PRs first; integrate, don't conflict.
- T5 owns EML-IR primitive (Phase I of §4.I). Use their API surface if landed.

STOP CONDITIONS:
- User says "stop T1" → graceful wind-down · final commit · final SESSION_SUMMARY.md · push · end
- main build broken → STOP, commit BLOCKER:, do NOT push, surface
- Acceptance bar met → final commit, draft PR open, summary written, end loop

START NOW:
1. Read iter 1 docs
2. cargo + xcodebuild baseline
3. Iter 1 commit: docs/audits/HYPERDYNAMIC_SCHEMAS_AUDIT_<today>.md
4. Push, immediately start iter 2

Go.
```

---

## T2 — §4.E + §4.F Model Gating + Local Agent Excellence (THE HEART)

### Bootstrap

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t2-agent -b codex/t2-agent-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t2-agent
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T2 at /Users/jojo/Downloads/Epistemos-t2-agent
on branch codex/t2-agent-2026-05-16 (cut from main).

You own §4.E (Model Gating Liberation) + §4.F (Local Agent Excellence) — combined
because they overlap heavily. This is THE HEART MISSION. Read the Manifesto +
the 2026-05-16-evening local-agent obsession reinforcement EVERY phase.

ITERATION: continuous. After each commit, immediately start the next iter. NO PAUSE.

READ FIRST (iter 1):
1. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md (Manifesto + §0 + §4.E + §4.F + §11 vision)
2. docs/CODEX_HANDOFF_2026_05_16.md
3. docs/APP_ISSUES_AUTO_FIX.md ISSUE-2026-05-16-015 (model gating root-cause)
4. CLAUDE.md (NON-NEGOTIABLE CONSTRAINTS — local first, no subprocess, honest gating)
5. agent_core/src/agent_runtime/ (every file — this is THE runtime)
6. agent_core/src/agent_loop.rs + bridge.rs + session.rs
7. agent_core/src/providers/ (claude, openai, perplexity)
8. Epistemos/LocalAgent/* (LocalAgentPromptBuilder, LocalToolGrammar, LocalAgentLoop, ConfidenceRouter)
9. Epistemos/State/InferenceState.swift (gating: lines 420, 475, 4479, 4634, 5130, 5138)
10. Epistemos/Engine/LocalModelInfrastructure.swift (RAM gate — already patched 15cc2ced4)
11. Epistemos/App/AppBootstrap.swift (probe — already added 15cc2ced4)
12. Epistemos/Bridge/StreamingDelegate.swift
13. Epistemos/ViewModels/AgentViewModel.swift

SCOPE LOCK — touch only:
- agent_core/src/agent_runtime/ (extend; THIS IS YOUR HOME)
- agent_core/src/providers/ (add per-model native grammars)
- Epistemos/LocalAgent/ (extend; per-model grammar wiring; constellation routing)
- Epistemos/State/InferenceState.swift (gating fixes only)
- Epistemos/Engine/LocalModelInfrastructure.swift (extend power-user mode UI)
- Epistemos/Views/Settings/* (new model-picker badges + diagnostic rows + AgentBlueprint UI)
- Epistemos/Bridge/StreamingDelegate.swift (AnswerPacket runtime emission)
- Epistemos/ViewModels/AgentViewModel.swift (run timeline)
- docs/audits/AGENT_RUNTIME_AUDIT_<date>.md
- docs/fusion/LOCAL_AGENT_EXCELLENCE_DOCTRINE_<date>.md
- docs/audits/MODEL_GATING_MATRIX_<date>.md
- docs/agent-system/MODEL_GRAMMAR_MATRIX_<date>.md
- tests/agent_runtime_*.rs

DON'T TOUCH:
- agent_core/src/tri_fusion/ (T1 owns)
- agent_core/src/storage/vault.rs (T4 owns)
- agent_core/src/research/eml/ (T7 owns)
- agent_core/src/uas/ + acs anchor work (T3 owns)
- Anything biometric (T8)
- Anything AmbientFrequency (T6)

NAMING HYGIENE (NON-NEGOTIABLE):
- Hermes subprocess: PURGED forever. Never resurrect agent_core::hermes.
- Hermes format-parity: keep grammar pattern, rename internally NousPromptParity if confusion creeps in.
- Hermes Snake: simulation only; do not touch.
- Hermes Agent Core 2.0: DESIGN NAME ONLY. Code stays at agent_core::agent_runtime::*

PER-ITER RITUAL:
1. git status / git log
2. cargo test --lib (≥ 1671)
3. xcodebuild green
4. §5.0 reconciliation
5. ONE slice
6. Commit · HEREDOC · Co-Authored-By: Codex (T2)
7. Push every 5-10
8. Draft PR when acceptance bar met
9. NO PAUSE. Go to 1.

PHASE ORDER:
A (iters 1-15): Investigation. AUDIT_AGENT_RUNTIME doc + MODEL_GATING_MATRIX doc + runtime probe analysis (read system log after running app to see what the probe prints — adapt strategy based on whether strict-tool-grammar=ACTIVE or FALLBACK).
B (iters 16-80): Implementation.
  B1. AnswerPacket runtime emission (highest priority — current state per analyst is "schema implemented, runtime emission not wired"). Verify by inspecting persisted SDChat messages for packet IDs + VRM labels.
  B2. Settings → Inference → "Active constellation" UI row (per-model cold/warm/hot · schema=STRICT/SOFT · role=Code/Reasoning/Quick/ToolCaller).
  B3. Per-model native grammars in LocalToolGrammar: Qwen XML · Hermes JSON · DeepSeek-Coder · Llama 3.3 · Mistral Small · Phi-4 · Phi-4-mini.
  B4. ConfidenceRouter extension: task-class → model selection table. Idle unload 30 s after role inactivity.
  B5. Diagnostic surfaces: "Strict-grammar status" · "Schema-drift detector" · "Constellation health" rows.
  B6. AgentBlueprint UI: name · role · model picker (with per-model badges from §4.E gating fix) · tool selection · scope · approval mode.
  B7. Run timeline UI + replay from RunEventLog.
  B8. Power-user mode Settings toggle (already wired via UserDefaults at 15cc2ced4 — just expose UI).
C (iters 80+): Research-tier.
  C1. RL trajectory collection (atropos pattern) → bundle format for future LoRA training. Consent-gated.
  C2. Per-model LoRA adapter loading via MLX-Swift adapters API. Drop adapter in vault/adapters/ → picker shows it.
  C3. Self-evolution skill discovery (hermes-agent-self-evolution pattern). Proposed skills written to vault/.epistemos/proposed_skills/ for user review.

ACCEPTANCE BAR (V1 ship — open PR when ALL pass):
- A user opens AgentBlueprint → picks "Research Assistant" → selects model "Auto (constellation)" → picks tools (vault.search + note.create + graph.expand + web.fetch) → picks "Approve once per session" → runs a research task.
- ENTIRELY LOCAL (zero cloud round-trips unless user explicitly enabled cloud escalation).
- Router activates Quick Chat for planning → switches to Reasoning Brain for synthesis → calls vault.search → drafts note → asks approval → saves → emits AnswerPacket with claim_kind=synthesis · citations=searched notes · confidence=high.
- User sees timeline. User clicks replay. Same sequence reconstructs from RunEventLog.
- Every step has a trace; every claim has a citation; every mutation has an approval; every event has a Cognitive DAG node.
- NO fake step. NO hidden cloud call. NO silent fallback. NO dropped thinking block. NO buffered stream.

COORDINATION:
- T1 (Tri-Fusion) emits TriFusionMutations — wire them into agent_runtime tool-call surface.
- T3 (UAS-ACS) emits typed addresses + anchors — use them in RunEventLog event identity.
- T4 (Vault) emits prepared retrieval results — call them, never bypass.
- T5 (EML-IR) emits Info-IR confidence values — use them in AnswerPacket.confidence field.
- T6 (UI/UX) will audit your UI work; respond to their issues.

STOP CONDITIONS:
- User says "stop T2" → wind-down · SESSION_SUMMARY · PR open · end
- main build broken → BLOCKER commit, no push, surface
- Acceptance bar met → final commit, PR, summary, end loop

START NOW:
1. Read iter 1 docs cover-to-cover
2. Build app + run with the probe — capture probe output
3. Iter 1 commit: docs/audits/AGENT_RUNTIME_AUDIT_<today>.md + probe-output capture
4. Push, iter 2 begins

Go. The user has said this is the HEART. Earn it.
```

---

## T3 — §4.G UAS-ACS Canonical Architecture (the deep dynamic kernel)

### Bootstrap

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t3-uasacs -b codex/t3-uasacs-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t3-uasacs
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T3 at /Users/jojo/Downloads/Epistemos-t3-uasacs
on branch codex/t3-uasacs-2026-05-16 (cut from main).

You own §4.G UAS-ACS Canonical Architecture — the deep dynamic kernel work.
Read the §4.G hierarchy + 3 residency tiers + 12-step falsifier ladder EVERY phase.

ITERATION: continuous. NO PAUSE between iters.

READ FIRST (iter 1):
1. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.G (8-layer hierarchy, 3 tiers, 12 falsifiers)
2. docs/fusion/helios v5 first.md + helios v5 updated.md + helios v6.2.md
3. docs/HELIOS_V5_DOC_*.md + docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md
4. docs/audits/HELIOS_SUBSTRATE_INVENTORY_2026_05_12.md
5. agent_core/src/research/acs/ (autopoiesis · governance · kuramoto · mod)
6. agent_core/src/research/ternary/ (11 files, 3,385 LOC)
7. agent_core/src/research/sherry_lattice/
8. agent_core/src/research/continual_learning/
9. agent_core/src/research/cognition_observatory/
10. agent_core/src/research/hyperdynamic_schemas/ (cross-link with T1)
11. agent_core/src/cognitive_dag/ + agent_core/src/scope_rex/
12. epistemos-research/src/ (acs.rs · five_planes.rs · etc.)
13. epistemos-shadow/src/ (Halo backend — already shipped)

SCOPE LOCK — touch only:
- agent_core/src/uas/ (NEW MODULE — create it; this is your home)
- agent_core/src/research/acs/ (extend; never break existing surface)
- agent_core/src/research/active_assembly/ (NEW; create alongside acs/)
- agent_core/src/research/page_gather/ (NEW; Metal kernel + Swift driver)
- agent_core/src/research/local_recall_island/ (NEW)
- agent_core/src/research/scan_ir/ (overlap with T5 — coordinate)
- docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md (THE MAIN OUTPUT — no-loss register)
- docs/falsifiers/F-UAS-ZeroCopy-Spine_<date>.md
- docs/falsifiers/F-ACS-Anchor-Addressing_<date>.md
- docs/falsifiers/F-ShadowFirst-PageEscalation_<date>.md
- docs/falsifiers/F-PageGather-M2Pro_<date>.md
- docs/falsifiers/F-ActiveAssembly-Minimal_<date>.md
- docs/falsifiers/F-KV-Direct-Gate_<date>.md
- docs/falsifiers/F-SemiseparableBlockScan-Correctness_<date>.md
- docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_<date>.md
- tests/uas_*.rs · tests/acs_*.rs · tests/page_gather_*.rs

DON'T TOUCH:
- agent_core/src/tri_fusion/ (T1)
- agent_core/src/agent_runtime/ (T2)
- agent_core/src/storage/vault.rs (T4)
- agent_core/src/research/eml/ (T7)
- Any UI work (T6)
- Anything biometric (T8)

PER-ITER RITUAL:
1. git status / git log
2. cargo test (≥ 1671) — research-tier crates are gated behind --features research; you may add new gated modules
3. §5.0 reconciliation — verify every doctrine claim on disk first
4. ONE slice
5. Commit · HEREDOC · Co-Authored-By: Codex (T3)
6. Push every 5-10
7. NO PAUSE. Go to 1.

PHASE ORDER:
A (iters 1-20): Investigation + no-loss consolidation.
  A1. Walk every research crate. Map LOC + pub API + cited papers + test count.
  A2. Output docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_<date>.md (one row per concept: name · layer · residency tier · current file · falsifier dependency · status).
  A3. Reconcile scattered names: Shadow Memory · Page Oracle · Active-Support Atlas · L3 SSD Oracle · KV-Direct · 70B Local Cocktail · ternary lane · PacketRouter1bit · ControllerKernelPack · Morph — each gets ONE classification row.
  A4. Write docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md as the no-loss register. NEVER delete a prior name; mark superseded with cross-link.

B (iters 21-80): Falsifier docs + first implementations.
  B1. One docs/falsifiers/<gate-name>_<date>.md per gate (12 total). Each with: pass/fail recipe, M2 Pro budget, measurement methodology, fallback if fails.
  B2. Implement UasAddress + ResidencyLease + UasKind in agent_core/src/uas/. Map vault notes · graph nodes · KV pages · model components · agent traces · tool results onto UasAddress.
  B3. F-UAS-ZeroCopy-Spine: harness measuring copy count for canonical hot paths. #[test] that fails if copy count > 0.
  B4. F-ACS-Anchor-Addressing: typed ACS anchor object (theorem tag · plane coord · residency tier · source hash · active packet id). Round-trip test.
  B5. F-ShadowFirst-PageEscalation: HeliosPage sketch/residual/exact escalation pipeline. KL drift target ≤ 0.06.
  B6. F-PageGather-M2Pro: Metal kernel + Swift driver + budget against MEASURED M2 Pro streaming bandwidth (not theoretical 200 GB/s spec). 256/512/1024 MB buffers · 1 s+ windows · target ≥ 70% measured baseline.
  B7. F-ActiveAssembly-Minimal: synthetic packet graph + active-pull selector + correctness check. First runtime proof that "the brain does not ping every neuron."

C (iters 80+): Capability ceiling research.
  C1. F-KV-Direct-Gate harness: Qwen 3 8B at 128k, cold-spill to SSD, peak RAM ≤ 13 GB on 16 GB rig, D_KL/token under threshold, decode ≥ 10 tok/s.
  C2. F-SemiseparableBlockScan-Correctness: Mamba-2 / SSD scan kernel matches reference. Two-track harness: Qwen transformer vs Mamba-2 on same long-context tasks.
  C3. F-LocalRecallIsland-32K: exact-recall island for passkeys/pinned/recent preserves ≥ 95% recall under sketch-heavy routing.
  C4. F-PacketRouter1bit-Dispatch: ternary fire/suppress/defer router p99 dispatch on M2 Pro.
  C5. F-ControllerKernelPack: small-state inference kernel pack correctness + performance.
  C6. F-70B-Local-Cocktail-Composition: research-only doc + harness. Prove cocktail composes (memory under budget, generation doesn't collapse, bottleneck identified). Tagged C/Vault, NOT product.

ACCEPTANCE BAR (V1 — open PR when):
- UAS_ACS_CANONICAL_ARCHITECTURE doc exists as single no-loss register.
- Every previously-scattered concept reconciled to ONE layer + ONE residency tier + ONE falsifier.
- F-UAS-ZeroCopy-Spine + F-ACS-Anchor-Addressing + F-VaultRecall-50 (coord with T4) PASS on M2 Pro.
- F-ShadowFirst-PageEscalation + F-PageGather-M2Pro + F-ActiveAssembly-Minimal have running harnesses (PASS preferred; measurement is itself progress).
- Doctrine explicit per concept: ship-claimed / gated / research-only.
- NO silent gap between doctrine and code.

COORDINATION:
- T1 (Tri-Fusion) types are part of UAS — coordinate UasKind enum.
- T4 (Vault) drives F-VaultRecall-50 — your shadow-paging primitives serve them.
- T5 (EML-IR Scan-IR) overlaps F-SemiseparableBlockScan-Correctness — agree on Scan-IR API first.
- T7 (EML MVP) may want active-assembly primitives — coordinate.

STOP CONDITIONS:
- User says "stop T3" → wind-down · summary · PR · end
- main build broken → BLOCKER, no push, surface
- Acceptance bar met → final commit · PR · summary · end loop

START NOW:
1. Read iter 1 docs
2. cargo + xcodebuild baseline
3. Iter 1 commit: docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_<today>.md (audit walking every research crate)
4. Push · iter 2

Go. The deep dynamic kernel is your charge.
```

---

## T4 — §4.H F-VaultRecall-50 (HIGHEST USER-FACING PRIORITY)

### Bootstrap

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t4-vault -b codex/t4-vault-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t4-vault
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T4 at /Users/jojo/Downloads/Epistemos-t4-vault
on branch codex/t4-vault-2026-05-16 (cut from main).

You own §4.H Vault Retrieval Repair — F-VaultRecall-50. This is the MOST URGENT
USER-FACING FIX. Without honest retrieval, every other substrate claim is
hand-waving. PASS this first; the rest of the kernel work has more credibility.

ITERATION: continuous. NO PAUSE.

READ FIRST (iter 1):
1. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.H (Vault Context Contract + F-VaultRecall-50 dataset spec + pass conditions)
2. agent_core/src/storage/vault.rs (already has Fix B at lines 495-548 — query chatter strip + AND-for-short-queries; this is a starting point)
3. Epistemos/Sync/SearchIndexService.swift (fusedSearch · RRFFusionQuery)
4. Epistemos/Sync/RRFFusionQuery.swift
5. Epistemos/Engine/HaloController.swift + ShadowSearchService.swift
6. Epistemos/Engine/ShadowVaultBootstrapper.swift
7. epistemos-shadow/src/ (BM25 + HNSW + RRF backend)
8. Epistemos/App/ChatCoordinator.swift (where prepared retrieval feeds the model)
9. Epistemos/LocalAgent/LocalAgentPromptBuilder.swift (where vault context goes into prompt)

SCOPE LOCK — touch only:
- agent_core/src/storage/vault.rs (extend Fix B → full Vault Context Contract)
- agent_core/src/retrieval/ (NEW MODULE — Vault Search 2.0 home; create alongside storage/)
- Epistemos/Sync/SearchIndexService.swift (extend fused search)
- Epistemos/Sync/RRFFusionQuery.swift (add MMR diversity · graph proximity · recency tunables · user-priority)
- Epistemos/Views/Notes/* (provenance card UI surface — render the "why this note" badge per result)
- Epistemos/App/ChatCoordinator.swift (Vault Context Contract enforcement at the prompt-build seam)
- Epistemos/LocalAgent/LocalAgentPromptBuilder.swift (emit the "I sampled top-K by relevance" framing)
- docs/fusion/VAULT_CONTEXT_CONTRACT_<date>.md
- docs/falsifiers/F-VaultRecall-50_<date>.md (baseline + iteration reports)
- tests/vault_recall_*.rs
- EpistemosTests/F_VaultRecall_50_*.swift (Swift integration tests)

DON'T TOUCH:
- agent_core/src/tri_fusion/ (T1)
- agent_core/src/agent_runtime/ (T2)
- agent_core/src/uas/ (T3) — but DO use UasAddress for vault notes when T3 lands
- agent_core/src/research/eml/ (T7)
- AmbientFrequency anything (T6)

PER-ITER RITUAL:
1. git status / git log
2. cargo test (≥ 1671)
3. §5.0 reconciliation — never enumerate first N notes anywhere in your code
4. ONE slice
5. Commit · HEREDOC · Co-Authored-By: Codex (T4)
6. Push every 5-10
7. NO PAUSE. Go to 1.

PHASE ORDER:
A (iters 1-8): Investigation.
  A1. Audit current retrieval: every grep for "limit 7" / "first N notes" / "LIMIT" / unbounded for-loops over note arrays.
  A2. Output docs/audits/VAULT_RETRIEVAL_AUDIT_<date>.md.
  A3. Build the F-VaultRecall-50 dataset by sampling 50 notes from the user's vault (deterministic seed, record manifest hash for reproducibility). 5 categories × 10 queries:
     - Exact-title (10): query is the literal note title or near-paraphrase
     - Paraphrase (10): semantic ask without title
     - Recent (10): "the note I wrote a few weeks ago about X"
     - Synthesis (10): query requires combining 2-3 notes
     - Adversarial (10): recently-created similarly-titled distractor
  A4. Output docs/falsifiers/F-VaultRecall-50_baseline_<date>.md — run current retrieval, capture per-query result, baseline score.

B (iters 9-40): Implementation.
  B1. Vault Context Contract (10 rules) — implement at the prompt-build seam in ChatCoordinator + LocalAgentPromptBuilder.
  B2. MMR diversity rerank — if absent, add.
  B3. Graph-proximity signal in RRF fusion — graph neighbor distance as a third source.
  B4. Recency exp() decay — tunable per task class.
  B5. User-attached priority — pinned/recently-edited notes get a boost.
  B6. Confidence threshold + "ask the user / broaden search" path when ambiguous.
  B7. Trace emission — "searched N notes, top K selected, reasons per note" to RunEventLog.
  B8. UI provenance cards per result — render lexical/semantic/graph/recency badges.
  B9. Re-run F-VaultRecall-50. Iterate until pass conditions met.

C (substrate-aligned, iters 40+):
  Apply "shadow-first" to vault retrieval (parallels T3 §4.G). Notes get sketch (Model2Vec embed) + residual (compressed summary) + exact (full body). Rank on sketches; decode residual for top-K; pull exact only for final context pack. "Shadow Search 1.0."

ACCEPTANCE BAR (V1):
- ≥ 95% top-1 exact-title recall
- ≥ 90% top-5 paraphrase recall
- ≥ 90% agent context includes correct note
- ZERO "first 7 notes only" failures (forbidden by construction)
- UI shows why each note was selected (lexical/semantic/graph/recency badges)
- Synthesis queries cite ≥ 2 distinct notes
- Adversarial queries reject distractor ≥ 85%

COORDINATION:
- T2 (Agent) consumes your retrieval output — agree on Tri-Fusion-compatible result shape.
- T3 (UAS-ACS) will mark each note with a UasAddress — adopt their type when it lands.
- T6 (UI/UX) will audit your provenance-card UI — respond to feedback.

STOP CONDITIONS:
- User says "stop T4" → wind-down · summary · PR · end
- main broken → BLOCKER, no push, surface
- Acceptance bar met → final commit, PR, summary, end loop

START NOW:
1. Read docs
2. cargo + xcodebuild baseline
3. Iter 1: audit retrieval paths, build the 50-note dataset, run baseline.
4. Iter 1 commit: docs/audits/VAULT_RETRIEVAL_AUDIT + docs/falsifiers/F-VaultRecall-50_baseline_<today>.md
5. Push · iter 2

Go. The user's biggest frustration is "first 7 irrelevant notes." Fix it.
```

---

## T5 — §4.I EML-IR Primitive Stack (6 IRs)

### Bootstrap

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t5-emlir -b codex/t5-emlir-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t5-emlir
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T5 at /Users/jojo/Downloads/Epistemos-t5-emlir
on branch codex/t5-emlir-2026-05-16 (cut from main).

You own §4.I EML-IR Primitive Stack: 6 IRs (EML · Tropical · Scan · Operator · Info · Geometry).
Each IR has typed AST, normal form, property tests, executable lowering, Lean schema authority.

ITERATION: continuous. NO PAUSE.

READ FIRST (iter 1):
1. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.I (6 IRs · primitive signatures · cross-IR composition · Lean authority)
2. agent_core/src/research/eml/ (1,232 LOC — already exists, audit it)
3. Any prior OxiEML scaffolding in agent_core/src/research/ or epistemos-research/
4. agent_core/src/research/hyperdynamic_schemas/ (cross-link target with T1)
5. Mamba-2 / SSD paper notes (for Scan-IR)
6. DeepONet / FNO paper notes (for Operator-IR)

SCOPE LOCK:
- agent_core/src/research/eml/ (extend; never break)
- agent_core/src/research/tropical_ir/ (NEW)
- agent_core/src/research/scan_ir/ (NEW — coordinate with T3 F-SemiseparableBlockScan)
- agent_core/src/research/operator_ir/ (NEW)
- agent_core/src/research/info_ir/ (NEW)
- agent_core/src/research/geometry_ir/ (NEW)
- docs/audits/EML_IR_AUDIT_<date>.md
- docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_<date>.md
- research_custody/eml/ · research_custody/tropical/ · research_custody/scan/ · research_custody/operator/ · research_custody/info/ · research_custody/geometry/ (one folder per IR · claims.yaml · sources/ · hashes/SHA256SUMS · verification_status.md)
- tests/eml_ir_*.rs · tropical_ir_*.rs · scan_ir_*.rs · operator_ir_*.rs · info_ir_*.rs · geometry_ir_*.rs

DON'T TOUCH:
- Other research crates outside your IRs
- Anything not in agent_core/src/research/

PER-ITER RITUAL:
1. git status / git log
2. cargo test (≥ 1671)
3. §5.0 reconciliation — every IR claim cited to primary source (paper + line)
4. ONE slice
5. Commit · HEREDOC · Co-Authored-By: Codex (T5)
6. Push every 5-10
7. NO PAUSE. Go to 1.

PHASE ORDER:
A (iters 1-8): Audit EML state + write primitive doctrine.
  A1. Read every file in agent_core/src/research/eml/. Output docs/audits/EML_IR_AUDIT_<date>.md.
  A2. Write docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_<date>.md with 6 IR specs + cross-IR composition + Lean schema authority + lowering targets + per-IR acceptance.

B (iters 9-60): MVPs.
  B1. EML-IR — extend with branch-safe typing + Lean certificate emission. 100-fn elementary-function corpus round-trips through EML-IR → normal form → Rust eval (float tolerance). Cite Odrzywołek arXiv + Stachowiak follow-up + Carney inexpressibility.
  B2. Tropical-IR — compile a small ReLU network into (max,+) tropical rational form. Property test: tropical form == ReLU output on fixture corpus. Cite Zhang/Naitzat/Lim + Charisopoulos/Maragos.
  B3. Scan-IR — typed AST for scan(⊕, …) with Mamba-2 SSD lowering. Property test: Mamba-2 reference scan == Scan-IR on fixture sequence. Coordinate with T3 F-SemiseparableBlockScan-Correctness.
  B4. Info-IR — typed (log_partition · dual_map · kl_projection) triple. Property test: logistic regression converges identically through Info-IR mirror descent vs raw mirror descent. Cite information-geometry / Bregman literature.
  B5. Operator-IR — branch/trunk + Fourier transform lowering. Property test: small FNO == Operator-IR forward pass. Cite DeepONet + FNO universality.
  B6. Geometry-IR — geometric product + rotor sandwich for 3D rotations. Property test: identity rotation + composition law.

C (iters 60+): research-tier.
  C1. Per-IR Lean proofs of major identities.
  C2. Integration with agent_core/src/research/hyperdynamic_schemas/ — Tri-Fusion (T1) can carry IR-typed expressions natively.
  C3. Source custody folders fully populated (PDFs · screenshots · hashes).

ACCEPTANCE BAR (V1):
- All 6 IRs have MVP · audit doc · doctrine doc · property tests
- EML-IR closes ≥ 80% elementary-function corpus by round-trip
- Tropical-IR compiles small ReLU networks exactly
- Scan-IR drives F-SemiseparableBlockScan-Correctness (coord T3)
- Info-IR wired into AnswerPacket confidence labeling (coord T2)
- Source custody folders exist for all 6 IRs

COORDINATION:
- T1 (Tri-Fusion) carries IR-typed expressions natively — agree on type encoding.
- T2 (Agent) uses Info-IR for AnswerPacket.confidence — expose API.
- T3 (UAS-ACS) F-SemiseparableBlockScan-Correctness consumes Scan-IR — coordinate API.

STOP CONDITIONS:
- User says "stop T5" → wind-down · summary · PR · end
- main broken → BLOCKER · no push · surface
- Acceptance bar met → final commit · PR · summary · end loop

START NOW:
1. Read iter 1 docs
2. cargo baseline
3. Iter 1: audit EML state · output EML_IR_AUDIT doc
4. Push · iter 2

Go. Kernel-grade IR is the moat under the moat.
```

---

## T6 — §4.C UI/UX Recursive Audit + ongoing fixes

### Bootstrap

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t6-uiux -b codex/t6-uiux-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t6-uiux
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T6 at /Users/jojo/Downloads/Epistemos-t6-uiux
on branch codex/t6-uiux-2026-05-16 (cut from main).

You own §4.C UI/UX recursive audit. Your job is continuous — audit every UI
surface added in the last 14 days (and ongoing), use computer-use MCP to
verify visually, file audit docs per feature, fix P0/P1 in place (additive only).

ITERATION: continuous. NO PAUSE.

READ FIRST (iter 1):
1. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.C (8-step audit protocol per feature)
2. CLAUDE.md — UI standards (@Observable, Swift Testing, no force-unwraps, no print)
3. Run: git log --since=2026-05-02 --name-only --pretty=format:"%h %s" — compile the list of files touched in the last 14 days
4. Each Settings pane, each Diagnostic row, each new visualizer

SCOPE LOCK:
- ANY UI file (Epistemos/Views/**) — fix only additive (never delete a feature)
- Epistemos/Engine/AmbientFrequencyAudioGenerator.swift + AmbientFrequencyLivePlayer.swift (the main recent additions — audit these first)
- Epistemos/Views/Settings/* (diagnostic rows · model picker · constellation row)
- Epistemos/Views/Notes/* (provenance cards from T4)
- Epistemos/Views/Omega/* (agent UI from T2)
- docs/audits/UI_UX_<feature>_<date>.md (one per feature audited)
- docs/verification/screenshots/<feature>-<date>.png (computer-use screenshots)
- tests/EpistemosTests/UIUX_*.swift

DON'T TOUCH:
- Backend code (research crates · agent_runtime · vault.rs · uas · tri_fusion)
  EXCEPT if a P0 UI bug requires a one-line viewmodel fix (then ask T9 coordinator first via docs/coordination/T6_to_<other>.md)

PER-ITER RITUAL:
1. git status / git log
2. xcodebuild green (Swift surface focus)
3. ONE feature to audit per iter
4. computer-use: request_access for Epistemos · build app · launch · navigate · screenshot
5. Verify: render · audio (if audio surface) · accessibility · contrast · persistence
6. Write docs/audits/UI_UX_<feature>_<date>.md with findings
7. Fix P0/P1 in place · save screenshot · commit
8. Push every 5-10
9. NO PAUSE. Go to 1.

8-STEP UI/UX AUDIT PROTOCOL (per feature):
1. Use computer-use to actually open the feature. Don't trust the code; RUN the app.
2. Render: every preset card · every retro-era badge · every slider visually correct
3. Audio (if audio surface): every preset (a) doesn't click on enable/disable, (b) per-layer pan smooth across -1→+1, (c) bit-crush at 1-bit still audible, (d) sample-rate-reduce at 8x produces expected lo-fi without crash
4. Live player (if applicable): click-free under fast scrub (one-pole IIR holds), bit-crush + SRR compose without DC drift
5. Accessibility: VoiceOver labels on every preset card · every badge · every slider · Tab + Space navigation reaches every interactive element
6. Visual layer: pixel-art retro badges render crisply (no anti-aliasing on axis-aligned Path fills) · WCAG AA contrast in light + dark mode
7. Data layer: presets persisted across app restart · per-layer pan + bit-crush + SRR state survives relaunch
8. Output: audit doc with screenshots, findings, severity, repro steps. Fix P0/P1 in place additively.

FEATURES TO AUDIT FIRST (in this order — most recent first):
1. AmbientFrequencyAudioGenerator (39 presets, 15 synthesis primitives, retro-era presets) + AmbientFrequencyLivePlayer (real-time AVAudioEngine synth) — these are the freshest additions
2. F-VaultRecall-50 surface (when T4 lands the provenance card UI)
3. Agent UI / AgentBlueprint (when T2 lands)
4. Per-model badges (HONEST / EXPERIMENTAL / OFF) — when T2 lands
5. UAS-ACS visualizer (if T3 surfaces one)
6. EML-IR diagnostic row (if T5 surfaces one)
7. Tri-Fusion structured-mutation surface in Epdoc (when T1 lands)
8. Settings → Diagnostics rows added in the wave
9. Halo / shadow search panel (already shipped)
10. Provenance Console rows (already shipped)

ACCEPTANCE BAR:
- Every UI added in the recent wave has a screenshot-verified audit doc
- Every P0/P1 issue is fixed in place additively (never delete a feature)
- Accessibility passes on every audited surface
- Data persistence verified across app relaunch

COORDINATION:
- T1/T2/T3/T4/T5 will land new UI surfaces — audit them within a few iters of landing
- T9 coordinator handles cross-terminal disputes

STOP CONDITIONS:
- User says "stop T6" → wind-down · summary · PR · end
- main broken → BLOCKER · no push · surface
- All recent features audited + all P0/P1 fixed → can pause for a few hours, then resume next audit cycle

START NOW:
1. Read iter 1 docs
2. git log --since=2026-05-02 --name-only — compile feature list
3. Iter 1: audit AmbientFrequencyAudioGenerator. Run app via computer-use. Screenshot. File docs/audits/UI_UX_AmbientFrequencies_<today>.md.
4. Push · iter 2 (audit AmbientFrequencyLivePlayer)

Go. The user wants every surface museum-grade.
```

---

## T7 — §4.B Deep EML MVP integration

### Bootstrap

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t7-eml -b codex/t7-eml-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t7-eml
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T7 at /Users/jojo/Downloads/Epistemos-t7-eml
on branch codex/t7-eml-2026-05-16 (cut from main).

You own §4.B Deep EML integration — make agent_core/src/research/eml/ a substrate
PRIMITIVE that 2-3 other modules call into, not a research island.

ITERATION: continuous. NO PAUSE.

READ FIRST (iter 1):
1. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.B (5 candidate sites + MVP order)
2. agent_core/src/research/eml/ — every file. Identify implemented surface (energy functions · sampling · gradient routines · typed distributions). Cite original papers (LeCun energy-based models · diffusion/EBM hybrids · Hinton/Welling RBM line).
3. agent_core/src/storage/vault.rs (potential energy-weighted reranking site — coord with T4)
4. Epistemos/LocalAgent/ConfidenceRouter.swift (potential energy-as-confidence-proxy site — coord with T2)
5. agent_core/src/research/cognition_observatory/ (potential energy-as-anomaly-signal site)
6. agent_core/src/research/acs/kuramoto.rs (potential energy-gradient damp site — coord with T3)

SCOPE LOCK:
- agent_core/src/research/eml/ (extend; never break)
- agent_core/src/research/eml_integration/ (NEW — the MVP integration sites)
- docs/audits/EML_AUDIT_<date>.md
- docs/fusion/EML_INTEGRATION_DOCTRINE_<date>.md
- Settings → Diagnostics → "EML energy live readout" row (in Epistemos/Views/Settings/)
- tests/eml_*.rs

DON'T TOUCH:
- agent_core/src/tri_fusion/ (T1)
- agent_core/src/agent_runtime/ (T2)
- agent_core/src/uas/ (T3)
- agent_core/src/storage/vault.rs (T4) — but DO propose integration via coordination doc
- agent_core/src/research/scan_ir/ etc (T5)
- AmbientFrequency UI (T6)

PER-ITER RITUAL:
1. git status / git log
2. cargo test (≥ 1671)
3. §5.0 — every EML claim backed by paper line citation OR property test (no hand-waving)
4. ONE slice
5. Commit · HEREDOC · Co-Authored-By: Codex (T7)
6. Push every 5-10
7. NO PAUSE.

PHASE ORDER:
A (iters 1-6): Audit + doctrine.
  A1. docs/audits/EML_AUDIT_<date>.md — every file in eml/. LOC · pub API · test count · cited sources.
  A2. docs/fusion/EML_INTEGRATION_DOCTRINE_<date>.md — sections:
     §1 What EML provides today (typed surface)
     §2 5 candidate integration sites:
        (a) Tri-Fusion ambiguity resolution (lowest-energy parse pick) — COORD WITH T1
        (b) ConfidenceRouter scoring (energy as confidence proxy) — COORD WITH T2
        (c) ACS Kuramoto coupling tempering (energy gradient damps over-synchronization) — COORD WITH T3
        (d) F-VaultRecall-50 ranking (energy-weighted result re-ranking) — COORD WITH T4
        (e) SAE cognition observatory (energy as anomaly signal)
     §3 The MVP: pick ONE site (default = Tri-Fusion ambiguity, but T1 must be far enough along; otherwise default to SAE observatory)
     §4 Forward-staged integrations (the other 4 as candidate §3.X rows in MASTER_FUSION)

B (iters 7-30): MVP implementation.
  Pick MVP site based on which terminal has advanced enough. Default = SAE observatory (no coordination dependency). Implement: wire eml/ functions into the chosen site cleanly. +30 cargo tests target. Diagnostic surface in Settings → Diagnostics → "EML energy live readout" row.

C (iters 30+): Forward-staged candidates (only after MVP ships).

ACCEPTANCE BAR (V1):
- EML stops being a research island; becomes substrate primitive called by ≥ 2 other modules.
- Property-test-backed; no hand-waving. Every behavioral claim has a paper line citation OR a tests/eml_*.rs property test.
- Diagnostic row visible in Settings.

COORDINATION:
- Coordinate MVP choice with T1/T2/T3/T4 — pick the one where coordination is easiest.
- T5 (EML-IR) is the IR-level work; you are the RUNTIME-level integration. Different layers; don't conflict.

STOP CONDITIONS:
- User says "stop T7" → wind-down · summary · PR · end
- main broken → BLOCKER · no push · surface
- MVP shipped + V1 acceptance met → final commit · PR · summary · end loop

START NOW:
1. Read docs
2. cargo baseline
3. Iter 1: docs/audits/EML_AUDIT
4. Push · iter 2

Go.
```

---

## T8 — §4.D Biometric Lock (GATED on T1+T2+T6 landing)

### Bootstrap (DELAY until T1+T2+T6 each have at least one PR landed)

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t8-biometric -b codex/t8-biometric-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t8-biometric
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T8 at /Users/jojo/Downloads/Epistemos-t8-biometric
on branch codex/t8-biometric-2026-05-16 (cut from main).

You own §4.D Biometric Privacy + Lockable Surfaces. THIS IS GATED: do NOT start
implementation until §4.A (T1) + §4.E/F (T2) + §4.C (T6 audit pass) all land
at least one PR each. Until then, you may ONLY write the doctrine doc.

ITERATION: continuous, but bounded scope. NO PAUSE.

READ FIRST (iter 1):
1. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.D
2. ~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md (44 KB — THE canonical user doc; READ EVERY WORD)
3. Apple LocalAuthentication framework docs (LAContext · LAPolicy · evaluatePolicy)
4. Apple Secure Enclave + Keychain integration docs
5. CLAUDE.md (Keychain-only credentials, never UserDefaults for secrets)

SCOPE LOCK:
- Phase 0 (always allowed): docs/fusion/BIOMETRIC_LOCK_DOCTRINE_<date>.md — the doctrine doc
- Phase B (GATED): Epistemos/Engine/BiometricLockService.swift (NEW · wraps LocalAuthentication + Keychain + Secure Enclave)
- Phase B (GATED): agent_core/src/cognitive_dag/macaroons.rs (extend with LockedContentGate constraint)
- Phase B (GATED): Epistemos/Sync/SearchIndexService.swift (filter locked content)
- Phase B (GATED): Epistemos/Engine/ShadowSearchService.swift (filter locked content)
- Phase B (GATED): Epistemos/Engine/SpotlightIndexer.swift (exclude locked)
- Phase B (GATED): Epistemos/Views/* (lock badge · unlock sheet · locked-items placeholder)
- tests/biometric_lock_*.rs · EpistemosTests/BiometricLock_*.swift

DON'T TOUCH:
- ANY non-biometric code path until gate opens
- Anything in scope of T1/T2/T3/T4/T5/T6/T7

GATE CHECK (run every iter until gate opens):
  cd /Users/jojo/Downloads/Epistemos
  git log main --oneline | grep -E "T1|t1-trifusion|§4.A" | head -3
  git log main --oneline | grep -E "T2|t2-agent|§4.E|§4.F" | head -3
  git log main --oneline | grep -E "T6|t6-uiux|§4.C" | head -3
  IF all 3 have a landed PR → gate is OPEN; proceed to Phase B
  IF not → stay in Phase 0 (doctrine doc only)

PER-ITER RITUAL:
1. Gate check
2. git status / git log
3. cargo + xcodebuild
4. §5.0 reconciliation
5. ONE slice (Phase 0 doctrine refinement OR Phase B implementation if gate open)
6. Commit · HEREDOC · Co-Authored-By: Codex (T8)
7. Push every 5-10
8. NO PAUSE.

PHASE 0 (always allowed): Doctrine.
  Write docs/fusion/BIOMETRIC_LOCK_DOCTRINE_<date>.md with 9 sections:
    §1 Threat model · §2 Crypto floor · §3 What can be locked · §4 Session model
    §5 Agent isolation · §6 Indexing isolation · §7 UI/UX · §8 Recovery · §9 Open theorems

PHASE B (when gate opens — multi-week):
  B1. BiometricLockService wrapping LocalAuthentication
  B2. LockState column + migration (per note/chat/code-block/vault)
  B3. LockedContentGate macaroon constraint at dispatch layer
  B4. SearchIndexService.fusedSearch filters locked items
  B5. ShadowSearchService + Spotlight: same filter
  B6. UI: lock badge on row + unlock sheet (LAContext) + locked-items placeholder
  B7. Recovery flow: recovery-code printable view (≥ 128 bits entropy)

ACCEPTANCE BAR (V1):
- Property tests prove (a) locked content cannot reach AgentLoop context
  (b) locked content cannot appear in any search index result
  (c) locked content cannot appear in Spotlight
  (d) biometric-failure path is graceful + retryable
  (e) recovery-code entropy ≥ 128 bits

COORDINATION:
- T2 (Agent) macaroons gate work overlaps — coordinate `LockedContentGate` integration.
- T3 (UAS-ACS) UasAddress carries residency tier — lock state could be a tier extension.
- T4 (Vault) retrieval filters — coordinate on locked-item exclusion semantics.

STOP CONDITIONS:
- User says "stop T8" → wind-down · summary · PR · end
- main broken → BLOCKER · no push · surface
- Acceptance bar met → final commit · PR · summary · end loop

START NOW:
1. Gate check (likely CLOSED — that's fine).
2. Phase 0: read QuickCapture biometric addendum cover-to-cover.
3. Iter 1 commit: docs/fusion/BIOMETRIC_LOCK_DOCTRINE_<today>.md skeleton.
4. Push · iter 2 refines §1 threat model · etc.
5. Keep checking gate every iter. When OPEN, start B1.

Go. Privacy moat is the final layer; get it right.
```

---

## T9 — Coordinator + Drift-Catch + Cross-PR Review

### Bootstrap

```bash
git worktree add /Users/jojo/Downloads/Epistemos-t9-coord -b codex/t9-coord-2026-05-16 main
cd /Users/jojo/Downloads/Epistemos-t9-coord
codex
```

### Paste this into Codex:

```
You are Codex CLI in Terminal T9 at /Users/jojo/Downloads/Epistemos-t9-coord
on branch codex/t9-coord-2026-05-16 (cut from main).

You own COORDINATION: you watch every other terminal, catch drift, mediate
conflicts via docs/coordination/, run audit-of-audit cycles on landed PRs,
keep MASTER_FUSION + APP_ISSUES_AUTO_FIX in sync with reality.

ITERATION: continuous. NO PAUSE.

READ FIRST (iter 1):
1. docs/CODEX_9_TERMINAL_PROMPTS_2026_05_16.md (THIS DOC — every terminal's scope lock + acceptance bar)
2. docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §0 + §2 phase loop + §C audit-of-audit
3. docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md (43 §3.x rows)
4. docs/APP_ISSUES_AUTO_FIX.md
5. docs/CANONICAL_AUDIT_LOG.md
6. docs/CRITIQUE_LOG.md
7. docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md §9 (55 audit-of-audit cycles)

SCOPE LOCK:
- docs/coordination/<from>_to_<to>_<date>.md (any cross-terminal coord message)
- docs/audits/T9_AUDIT_<date>.md (per audit-of-audit cycle, every 10 iters)
- docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md (UPDATE in place — never delete a row; mark superseded with cross-link)
- docs/APP_ISSUES_AUTO_FIX.md (UPDATE in place — bump status as issues land)
- docs/CANONICAL_AUDIT_LOG.md (UPDATE — add entries)
- docs/CRITIQUE_LOG.md (UPDATE — add entries on drift caught)
- NO touching code files (you are pure coordination + doctrine)

DON'T TOUCH:
- ANY .swift · .rs · .metal · .h · .c file
- Any other terminal's scope lock (you read it; you don't touch it)

PER-ITER RITUAL:
1. git status / git log on EACH worktree:
   git -C /Users/jojo/Downloads/Epistemos-t1-trifusion log --oneline -3
   git -C /Users/jojo/Downloads/Epistemos-t2-agent log --oneline -3
   git -C /Users/jojo/Downloads/Epistemos-t3-uasacs log --oneline -3
   git -C /Users/jojo/Downloads/Epistemos-t4-vault log --oneline -3
   git -C /Users/jojo/Downloads/Epistemos-t5-emlir log --oneline -3
   git -C /Users/jojo/Downloads/Epistemos-t6-uiux log --oneline -3
   git -C /Users/jojo/Downloads/Epistemos-t7-eml log --oneline -3
   git -C /Users/jojo/Downloads/Epistemos-t8-biometric log --oneline -3
   (skip if worktree not yet created)
2. cargo test --lib on main (≥ 1671)
3. xcodebuild on main green
4. Cross-PR review: for each draft PR open, check the commits against the originator terminal's scope lock. If a commit reaches outside its lane, file docs/coordination/<terminal>_drift_<date>.md and surface in commit message.
5. MASTER_FUSION sync: for each landed slice, update the §3.x row state column.
6. APP_ISSUES sync: for each landed fix, bump status (Open → Investigating → Patched → Verified Fixed).
7. Every 10 iters: run an audit-of-audit on the last 10 landed PRs across all terminals. Output docs/audits/T9_AUDIT_<n>_<date>.md.
8. Every 20 iters: run a synthesis pass — update the 3 integration artifacts (UNIFIED_ACTIVE_SUBSTRATE_CANON + V1_SHIP_LEDGER + DAY_IN_THE_LIFE).
9. Commit · HEREDOC · Co-Authored-By: Codex (T9-coord)
10. Push every 5-10
11. NO PAUSE.

THINGS TO CATCH:
- Scope-lock violations (terminal touches a file outside its lane)
- Doctrine drift (commit message claims X but code doesn't show X)
- Test regression (cargo lib count drops below 1671)
- xcodebuild break (any terminal's PR breaks main build)
- Naming hygiene drift (any new agent_core::hermes module · any new Hermes-related ambiguity)
- Hardware-tier drift (any claim of 36B-on-16GB without §4.E acceptance pass)
- "First N notes" drift (any new code that enumerates first-N from vault)
- Cloud round-trip drift on hot path
- Feature deletion (any commit that removes a feature without explicit user permission)

ACCEPTANCE BAR:
- Every landed PR is audited within 1 iter
- Every audit-of-audit cycle catches ≥ 1 drift item
- MASTER_FUSION stays current with reality (no doctrine drift past 24 hours)
- APP_ISSUES status bumps reflect actual code state

START NOW:
1. Read docs
2. List active worktrees
3. Iter 1: inventory state of every terminal · output docs/coordination/T9_initial_inventory_<today>.md
4. Push · iter 2 begins watching

Go. You are the substrate's conscience.
```

---

## Master cleanup / stop-all checklist (when you're done)

When you want to stop a terminal:
- In its Codex CLI session, say: `stop T<N>` or `wind down`

When you want to stop ALL terminals:
- Paste this into EACH Codex session:
  ```
  STOP. Per §7 of the deep-investigation prompt: graceful wind-down. Finish
  current commit cleanly. Write docs/SESSION_SUMMARY_T<N>_<today>.md. Push.
  Open final draft PR back to main. End the loop. Do NOT schedule another iter.
  ```

To remove a finished worktree:
```bash
git worktree remove /Users/jojo/Downloads/Epistemos-t<N>-<slug>
```

To list all open worktrees:
```bash
git worktree list
```

---

*— End of CODEX_9_TERMINAL_PROMPTS_2026_05_16. Each section is paste-ready. Pre-flight before launching any terminal. Recommended startup order: T4 → T2 → T3 → T6 → then T1/T5/T7. T8 stays gated. T9 anytime.*
