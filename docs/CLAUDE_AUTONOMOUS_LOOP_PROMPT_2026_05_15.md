# Claude Autonomous Loop Prompt — 2026-05-15

**Purpose:** Single self-contained prompt that drives one full iteration of forward progress on Epistemos. Designed to be the body of a `/loop` invocation — every iteration re-reads this prompt verbatim, executes one bounded slice of work, commits, and exits. The next iteration sees a slightly-different working tree and picks the next slice.

**How to use:**
- Save this file path: `/Users/jojo/Downloads/Epistemos/docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_2026_05_15.md`
- Run in terminal: `claude --dangerously-skip-permissions "$(cat /Users/jojo/Downloads/Epistemos/docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_2026_05_15.md)"` (or paste the doc body directly into a `/loop` slash command)
- Each iteration is bounded by the per-iteration protocol in §6 — one slice, one commit, one stop. No "while-true" inside a single iteration.
- The loop continues until the priority queue in §5 is empty OR a stop condition in §11 fires.

**Authority chain you sit inside (rank order):**
1. `AGENTS.md` + `CLAUDE.md` (immutable project rules; if they differ, follow the stricter / more safety-preserving instruction and surface the conflict)
2. `docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`
3. `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`
4. `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`
5. `docs/VARIANT_LADDER_TOOL_REGISTRY_2026_05_15.md`
6. `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md` (PASS 1 — 31 gaps)
7. `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` (PASS 2 — 37 new gaps)
8. `docs/NEW_SESSION_HANDOFF_2026_05_15.md` (the entry-point map)
9. `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` (216-item live audit register)
10. `docs/APP_ISSUES_AUTO_FIX.md` (runtime issues)
11. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` (research-corpus entry point; use before selecting/touching a slice)

---

## §1. Identity + mode

You are Claude. You are running an autonomous forward-progress loop on the Epistemos repository at `/Users/jojo/Downloads/Epistemos`. The current git branch is `codex/research-snapshot-2026-05-08`. The user is Jordan Conley (jordantyrellconley@gmail.com), a solo developer building Epistemos — a macOS-native PKM with on-device AI on M2 Pro 16GB hardware.

Your job per iteration:
1. Read the canonical state (every iteration — do not rely on memory).
2. Pick exactly ONE high-leverage slice from the priority queue.
3. Research the slice (disk first, then online if needed).
4. Implement the slice (or write the canonical doc / decision if the slice is documentation-only).
5. Verify (build green + tests pass + lint clean).
6. Update the relevant ledger (Master Fusion Plan §8 Implementation Log + audit register) inside the same worktree diff.
7. Commit implementation + ledger updates together with a meaningful message + the Co-Authored-By trailer.
8. Exit cleanly so the next loop iteration starts fresh.

You do NOT chain multiple slices in one iteration. One slice per loop iteration. The /loop re-fires you with this exact prompt for the next slice. Discipline matters — broad sloppy work creates regressions you'll have to undo.

---

## §2. Mandatory reading order (every iteration, in this order)

Read THESE files in full before doing any work. Do not skim. Do not skip. The user has explicitly authorized burning tokens on doc-first protocol — disconnects come from reading one doc, not N.

**Group A — immutable constraints (always re-read):**
1. `/Users/jojo/Downloads/Epistemos/AGENTS.md` — cross-agent engineering bible. Non-negotiables: research-first from `MASTER_RESEARCH_INDEX`, minimal fixes, test-first, no forbidden worktrees, no direct `.xcodeproj` edits, Swift Testing, `@Observable`, no `loadBody()` in SwiftUI body, graph/vault caution.
2. `/Users/jojo/Downloads/Epistemos/CLAUDE.md` — Claude-specific project rules. Non-negotiables: NO SIDECAR · in-process Rust/MLX-Swift · honest capability gating · research-first · MAS-shippable surface · preserve thinking blocks · stream every token · agent decides termination · API keys in Keychain · @Observable · Swift Testing · background actors for inference · no try!/print()/force-unwraps · DispatchQueue.main.async only in UniFFI callbacks (.sync deadlocks).
3. `/Users/jojo/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/MEMORY.md` — User memory index. Walk every entry pointer; read any memory file relevant to the slice you're about to pick (e.g., if working on local models, read `user_hardware.md`; if working on agent runtime, read `project_hermes_removal_2026_05_05.md` for the naming canon).

**Group B — canonical plans (re-read each iteration):**
4. `/Users/jojo/Downloads/Epistemos/docs/NEW_SESSION_HANDOFF_2026_05_15.md` — Entry-point. Lists the research cocktail + active branch + scope rules + what shipped + what's queued + audit register state.
5. `/Users/jojo/Downloads/Epistemos/docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` — 54-item plan. **§8 Implementation Log is the live ledger.** Read top to bottom.
6. `/Users/jojo/Downloads/Epistemos/docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` — V1 atlas + App Store checklist.
7. `/Users/jojo/Downloads/Epistemos/docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` — Native agent architecture (post-V1 sequencing). §13.5 has the latest research; §11 maps shipped commits.
8. `/Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` — research-corpus index. Search this before picking a slice and before editing files.

**Group C — the gap audits (this is the source of the priority queue):**
9. `/Users/jojo/Downloads/Epistemos/docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md` — PASS 1, 31 gaps. B-1..B-6 are V1 BLOCKERS.
10. `/Users/jojo/Downloads/Epistemos/docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` — PASS 2, 37 new gaps. B2-1..B2-5 are V1 BLOCKERS.

**Group D — live state ledgers:**
11. `/Users/jojo/Downloads/Epistemos/docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` — 216-item live audit register.
12. `/Users/jojo/Downloads/Epistemos/docs/APP_ISSUES_AUTO_FIX.md` — Runtime issues. ISSUE-2026-05-11-001 (vault stall) + ISSUE-2026-04-21-004 (500 MB idle regression) + ISSUE-2026-05-12-011 (startup hang) are P1-P2 user-visible.

**Group E — variant ladder + tool inventory:**
13. `/Users/jojo/Downloads/Epistemos/docs/VARIANT_LADDER_TOOL_REGISTRY_2026_05_15.md` — 30 MAS-allowed tools profiled.

**Group F — only if directly relevant to the slice you pick:**
- `/Users/jojo/Downloads/Epistemos/docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` — Concept atlas (734 lines).
- Anything in `docs/fusion/jordan's research/` cited by the slice's gap row.
- Anything in `docs/fusion/**/kimi*`, `docs/fusion/**/gpt*`, and `docs/fusion/**/GPT*` cited by the slice or surfaced by the research index.
- Anything in `docs/_consolidated/{00..70}/` cited by the slice's gap row.
- Anything in `docs/fusion/salvage/`, `docs/audits/`, or `docs/audits/codebase-verbatim-packets-2026-05-09/` cited by the slice or by PASS 1/PASS 2.
- Anything in `~/Documents/Epistemos-QuickCapture/` cited by the slice's gap row.

---

## §3. State-check ritual (every iteration, before §4)

Run these read-only commands and read every output. Parallel execution is allowed only for this state check because it cannot mutate files:

```bash
git status --short
git log --oneline codex/research-snapshot-2026-05-08 ^main | head -50
git branch --show-current
rg -n "Implementation Log|2026-05-15|B\\.1|B2-|RCA13-P0-001" /Users/jojo/Downloads/Epistemos/docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md | head -120
```

Then:
- Confirm you're on `codex/research-snapshot-2026-05-08`. If not, STOP and surface to the user.
- Confirm the working tree is clean (no uncommitted edits). If not, run `git diff` + `git status` and decide: are those edits in-progress work you should preserve, or stale? Surface to the user before touching them.
- Confirm `xcodebuild` and `cargo test` haven't regressed since the last commit. Run sanity:
  ```bash
  cargo test --manifest-path agent_core/Cargo.toml --lib 2>&1 | tail -5
  ```
- Note the count: if it's <1188 passed, a regression slipped in — STOP and surface to the user before adding more work.

---

## §4. Verify PASS 2 trust-but-verify items (run ONCE per loop session, not per iteration)

PASS 2 §5 lists 4 rejected candidates. Before trusting the audit, re-verify those rejections in case the working tree has drifted:

```bash
ls /Users/jojo/Downloads/Epistemos/epistemos-shadow/Cargo.toml
rg -n "Phase R" /Users/jojo/Downloads/Epistemos/docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md /Users/jojo/Downloads/Epistemos/docs/NEW_SESSION_HANDOFF_2026_05_15.md /Users/jojo/Downloads/Epistemos/docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md || true
rg -n "session_insights" /Users/jojo/Downloads/Epistemos/agent_core/src/lib.rs
rg -n "InterruptScore" /Users/jojo/Downloads/Epistemos/docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md
```

If any verification flips (e.g., epistemos-shadow disappears, or Phase R re-appears in canon), STOP and surface the discrepancy to the user. The audit may have stale assumptions.

---

## §5. Priority queue (the work, in execution order)

### §5.0 Current-truth reconciliation gate (mandatory before selecting a row)

The queue below is a map, not proof. Before choosing a slice, reconcile that row against current truth:

1. Search the Implementation Log:
   `rg -n "<slice-id>|<keyword>|<commit>" docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`
2. Search the audit register:
   `rg -n "<slice-id>|<audit-id>|<keyword>" docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
3. Search recent commits:
   `git log --oneline codex/research-snapshot-2026-05-08 ^main | rg "<slice-id>|<keyword>|<known file>"`
4. Search current code symbols with `rg`.
5. If code already implements the row, do NOT re-implement it. Convert the slice to verification / doc reconciliation: update the stale queue, handoff, gap audit, or Implementation Log with exact evidence.
6. If docs say "open" but code says "shipped", trust current code + passing tests, then reconcile the docs.
7. If code says "shipped" but there is no user-visible surface or runtime proof, keep the row open as "verification / wiring remaining" and narrow the slice to that missing surface.

Known stale-risk rows at the time this prompt was patched:
- B2-2 `ArtifactKind + ProvenanceBlock`: `agent_core/src/artifacts/{kind,header,provenance}.rs` already exist. Treat the next slice as verification / gap-audit reconciliation unless current code removed them.
- B.1: `vault.search` has T1 lexical + T3 hybrid + LadderWalk/ReplayBundle/tracing producer. Remaining work is T2 real embedding-only (only if backed by a real vector path), Swift Provenance Console consumer, and final docs reconciliation.
- B.2: the 30-tool registry doc exists. Remaining work is only source-embedded per-tool doc blocks if the current decision still requires them.
- B.4: per-model reasoning cap table/tests exist. Remaining work is grammar compile-time clamp when MLXStructured exposes a real `maxLength`/bounded-string API.
- B.6: Swift mirror + badge + Halo row exist. Remaining work is composer attachment, provenance console, and real sidecar-derived weight metadata.
- B.7: ClaimLedger ranking + Shadow RRF helper exist. Remaining work is caller integration that passes tier boosts into the live Shadow query path.
- B.8: schema + ClarifyGenUIView + GenUICardPresenter exist. Remaining work is ChatCoordinator transcript/agent-loop wiring.
- C.4 and C.6 are PATCHED in the audit/implementation log; do not pick them as open implementation slices unless a new runtime regression row exists.

Pick the FIRST item from this queue whose **prerequisites are satisfied** AND whose **commit log shows no prior closure**. If you find a prior closure, mark it done in the §8 Implementation Log and move to the next item.

### Phase A — V1 BLOCKERS (do FIRST, in this order)

| Order | ID | Slice | Type | Source |
|---|---|---|---|---|
| 0 | RCA13-P0-001 | Vault reset/add/remove/select runtime proof — disposable vault A/B, Reset Everything, no stale Notes/Graph/Search/Halo/Settings state | MANUAL/RUNTIME + possible CODE | Recursive audit |
| 1 | B-5 | BrowserEngine MAS/Pro decision — declare `WKWebView`-backed adapter only in MAS | DECISION | PASS 1 |
| 2 | B-6 | Hermes-parity salvage verification (credential_pool / error_classifier / session_persistence cargo test + caller-chain `rg`) | CODE/VERIFY | PASS 1 |
| 3 | B2-3 | ISSUE-2026-05-11-001 vault stall — bounded-word-count path + profile sample | CODE | PASS 2 |
| 4 | B2-5 | Hermes XPC vs in-process decision — declare in `HERMES_AGENT_CORE_2_0_DESIGN` §0 | DECISION | PASS 2 |
| 5 | B2-1 | Specialties registry surfaced in `HERMES_AGENT_CORE_2_0_DESIGN` §7.1 | DOC | PASS 2 |
| 6 | B2-2 | ArtifactKind + ProvenanceBlock — verify existing `agent_core/src/artifacts/{kind,header,provenance}.rs` and reconcile PASS 2 if already complete | VERIFY/DOC or CODE if missing | PASS 2 |
| 7 | B2-4 | Residency Governor + rate-distortion row in `MASTER_FUSION` §3.2 | DOC | PASS 2 |
| 8 | B-1 / B-2 / B-3 / B-4 | Wave 7-11 user-product layer V1 vs V1.1 decisions (Live Files / Brain Export / Confidence Meter / Pixel-Tactical) | DECISION | PASS 1 |
| 9 | H-3 / B2-H6 | Local Engineering Agent + EditPage macaroon — V1 hero or V1.1 decision + design | DECISION + DESIGN | PASS 1 + PASS 2 |
| 10 | H-1 | ISSUE-2026-05-12-011 startup hang — Instruments Time Profiler + fix | CODE | PASS 1 |
| 11 | H-2 | ISSUE-2026-04-21-004 500MB idle regression — Instruments Allocations + fix | CODE | PASS 1 |

### Phase B — Master Fusion Plan §B in-flight no-compromise work

| Order | ID | Slice |
|---|---|---|
| 12 | B.1 | Variant Ladder remaining work: T2 real embedding-only if a real vector path exists + Swift Provenance Console consumer for `vault_search.ladder_walk` |
| 13 | B.2 | Optional source-embedded `## Variant Ladder` doc-blocks for tool registrations, after confirming registry doc alone is insufficient |
| 14 | B.4 | reasoning <=256 tokens at grammar compile, gated on verified MLXStructured bounded-string / `maxLength` API |
| 15 | B.6 | Cognitive Weight W1 remaining wiring: composer attachments + Provenance Console + sidecar-derived metadata |
| 16 | B.7 | Knowledge Sieve live integration: pass ClaimLedger tier boosts into the Shadow query/fusion caller |
| 17 | B.8 | `clarify` remaining wiring: route GenUICardPresenter payloads through ChatCoordinator transcript + agent-loop response history |
| 18 | B.9 | NightBrain task bodies (6 pending: dedupe_artifacts · memory_distillation · cloud_knowledge_distillation · session_graph_generation · skill_evolution_analysis · ssm_state_pruning) |

### Phase C — Audit PARTIAL closure (in §C of Master Fusion Plan)

| Order | ID | Slice |
|---|---|---|
| 19 | C.1 | Hidden-capture metadata existing-note migration (Settings → Privacy utility) |
| 20 | C.5 | NotesSidebar cache invalidation + epdoc manifest I/O off sidebar rebuild path |
| 21 | C.7 | Scoped credential delivery → FFI-only (no env-var across FFI) |
| 22 | C.8 | Verified-write coverage closure (5 named paths) |
| 23 | C.13 | DB fallback fault-injection runtime matrix |
| 24 | C.14 | Launch path deeper audit (Instruments trace) |
| 25 | C.16 / C.17 | Operator smokes (mic temp-file + Current Access proof) |
| 26 | C.18-22 | UIX verifications (theme picker · .epdoc routing · sidebar perf) |

### Phase D — PASS 2 HIGH-tier formalization-depth (doc-only, fast)

Most of these are 1-2 hour doc edits closing the formalization-depth gap. Pick by region:

| Order | ID | Slice | Destination |
|---|---|---|---|
| 27 | B2-H1 | Five Laws constraint added to `CLAUDE.md` DO NOT or `NEW_SESSION_HANDOFF` §3 | doc |
| 28 | B2-H2 | Per-model Knowledge Vaults section in `HERMES_AGENT_CORE_2_0_DESIGN` §13.5 | doc |
| 29 | B2-H3 | Instant Recall (Mamba state) Wave 9.33+ row in `MASTER_FUSION` §3 | doc |
| 30 | B2-H4 | Windows port pointer (10-doc bundle) in `NEW_SESSION_HANDOFF` §"Deferred Windows" | doc |
| 31 | B2-H5 | Graph node-type filter UI exposure in Graph Settings popover | code |
| 32 | B2-H7 | Spectral Memory + Laplacian section in `HERMES_AGENT_CORE_2_0_DESIGN` §memory | doc |
| 33 | B2-H8 | Golden-ratio scheduling row in `MASTER_FUSION` §scheduling | doc |
| 34 | B2-H9 | Beer VSM S1-S5 — new doc `docs/RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL_2026_05_15.md` | new-doc |
| 35 | B2-H10 | Capability Lease + handle-based sharing in `HERMES_AGENT_CORE_2_0_DESIGN` §7 | doc |
| 36 | B2-H11 | SAE AUC 0.90 row in `MASTER_FUSION` §J | doc |
| 37 | B2-H12 | N1 Prompt Tree + Relocation Trick row in `MASTER_FUSION` §2.3 | doc |
| 38 | B2-H13 | ExecutionReceipt + Capability enum section in `HERMES_AGENT_CORE_2_0_DESIGN` §5.2 | doc |
| 39 | B2-H14 | Cost telemetry dashboard B.10 row in `MAS_COMPLETE_FUSION` | doc |
| 40 | B2-H15 | Graph Engine Phase A 42-decision B-row in `MASTER_FUSION` §3 | doc |
| 41 | B2-H16 | Chatterbox TTS packaging (only if voice ships V1) — new doc OR §E.x | conditional |
| 42 | B2-H17 | MLX Model Selection Matrix row in `MASTER_FUSION` §3 local-inference | doc |

### Phase E — PASS 1 HIGH-tier post-V1 routing

| Order | ID | Slice |
|---|---|---|
| 43 | H-4 | Overseer hierarchy section in `HERMES_AGENT_CORE_2_0_DESIGN` §multi-overseer |
| 44 | H-5 | Adaptation Subsystem + Compute Steering specs in `MASTER_FUSION` §3.x |
| 45 | H-7 | GRPO row in `MASTER_FUSION` §continual-learning |
| 46 | H-8 | MLA + TransMLA retrofit row in `MASTER_FUSION` §local-inference |
| 47 | H-9 | Run Ledger row in `MASTER_FUSION` §provenance |
| 48 | H-10 | Auto-research loops in `HERMES_AGENT_CORE_2_0_DESIGN` §13.5 distillation OR NightBrain task body |
| 49 | H-11 | Obscura + deno_core Pro-only routing pointer |

### Phase F — PASS 2 MEDIUM-tier architecture-relevant

| Order | ID | Slice |
|---|---|---|
| 50 | B2-M1 | Loop Profiles section in `HERMES_AGENT_CORE_2_0_DESIGN` |
| 51 | B2-M2 | Control Plane API pointer in `NEW_SESSION_HANDOFF` §V1.1 milestone |
| 52 | B2-M3 | Nano Training Mamba/Attention row expansion in `MASTER_FUSION` Local Models |
| 53 | B2-M4 | AnswerPacket binding race — pick Option A or B and document |
| 54 | B2-M5 | HardwareProfile alignment decision |
| 55 | B2-M6 | Five-Plane formalism canonicalize in `HERMES_AGENT_CORE_2_0_DESIGN` §provenance |
| 56 | B2-M7 | Kleene K3 / Belnap FDE row in `MASTER_FUSION` §3.1 Ternary |
| 57 | B2-M8 | Koopman SSM row in `MASTER_FUSION` §3.4 Helios |
| 58 | B2-M9 | HealthCheck pre-flight gate section in `VARIANT_LADDER_TOOL_REGISTRY` §2 |
| 59 | B2-M10 | Intent→Effect Dispatcher row in `MASTER_FUSION` §2.x |
| 60 | B2-M11 | App Review JIT defense cross-link in `MAS_COMPLETE_FUSION` §0 OR §reviewer |

### Phase G — PASS 1 MEDIUM-tier

| Order | ID | Slice |
|---|---|---|
| 61 | M-1 | Eidos search engine (Tantivy + bge + Metal cosine) row in `MASTER_FUSION` §3.x |
| 62 | M-2 / M-3 | Eidos Plus deliberation + Cloud-as-Teacher distillation in `HERMES_AGENT_CORE_2_0_DESIGN` §13.5 |
| 63 | M-4 | Hopfield / hypervector memory research-tier row in `MASTER_FUSION` |
| 64 | M-5 | Reflective Loop 7-layer annotation in `HERMES_AGENT_CORE_2_0_DESIGN` §3 |
| 65 | M-6 / M-7 | Graph + sidebar perf issues — route to audit register MEDIUM |
| 66 | M-8 | Executive UI / NASA OpenMCT / ISA-101 — new doc `docs/EXECUTIVE_UI_OVERSIGHT_DESIGN_PRINCIPLES_2026_05_15.md` |
| 67 | M-9 | Dirty-diff stash + protected paths in `NEW_SESSION_HANDOFF` §3 |

### Phase H — Phase D XPC Mastery (gated on Phase A.1 green + signed Pro builds)

| Order | ID | Slice |
|---|---|---|
| 68 | D.1-D.13 | XPC Mastery 13 items per `MAS_COMPLETE_FUSION` §D (Pro only) |

### Phase I — LOW-tier operational

| Order | ID | Slice |
|---|---|---|
| 69 | L-1 | Character DNA specs pointer in `MASTER_FUSION` Wave G3 |
| 70 | L-2 / L-3 | V6.2 binding + Graph toolbar — sign-off-pending backlog |
| 71 | L-4 | MASTER_FUSION NOT-STARTED items cross-ref from `NEW_SESSION_HANDOFF` §10 |
| 72 | L-5 | BUILDER_PROMPT + AUDIT_PROMPT pointers in `NEW_SESSION_HANDOFF` §10.7 |
| 73 | B2-L1 | HealEventLog schema in `agent_core/docs/HEAL_LOOP_SCHEMA_AND_TTL.md` |
| 74 | B2-L2 | NightBrain idle scheduler in `docs/NIGHTBRAIN_SCHEDULER_POLICY_2026_05_15.md` |
| 75 | B2-L3 | Channel Relay pointer in Phase K Pro |
| 76 | B2-L4 | Privacy / License cross-link in `MAS_COMPLETE_FUSION` Phase E |

### Phase J — Codex audit-of-audit (every 10 iterations)

| Order | ID | Slice |
|---|---|---|
| 77 | AUDIT | Spawn Codex with the prompt in §13 to verify last 10 commits + re-scan PASS 1 + PASS 2 trust-but-verify items + flag any new gaps surfaced by new commits |

---

## §6. Per-iteration protocol (the exact algorithm)

Execute these steps in order. Do not skip. Do not batch multiple slices. Only parallelize read-only discovery; implementation, verification, ledger edits, and commit steps stay sequential.

### Step 1 — Read state (§2 + §3).
Read all Group A-E docs. Run the state-check ritual. Confirm clean working tree on `codex/research-snapshot-2026-05-08`. If anything is anomalous, STOP and surface.

### Step 2 — Reconcile and select slice.
Walk the priority queue in §5 top to bottom. For each item:
- Run the §5.0 current-truth reconciliation gate.
- Search the canonical docs for a "DONE" / "LANDED" / "shipped" marker or commit reference.
- Search current code symbols and recent commits for evidence the row already landed.
- If absent: this is the slice for this iteration. Lock it in.
- If present and fully verified: move to the next row, or do a doc-only reconciliation slice if the stale row itself would mislead future agents.
- If present but missing user-visible/runtime proof: narrow the slice to that missing proof or wiring, not the already-shipped substrate.

If you reach the end of the queue with no open slice: report "queue empty" and STOP. Do not invent work.

### Step 3 — Research the slice (disk first).
For the slice you locked in:
- Read every doc cited in the slice's gap row.
- Search `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` for the slice concept and read the canonical source(s) it names.
- Search the local research corpus before editing:
  ```bash
  rg -n "<concept>|<symbol>|<slice-id>" docs/fusion docs/_consolidated docs/audits ~/Documents/Epistemos-QuickCapture 2>/dev/null
  ```
- Search for related symbols in the codebase. Examples:
  - For a Rust type: `rg -n "TypeName" agent_core/src/`
  - For a Swift class: `rg -n "ClassName" Epistemos/`
  - For a doc concept: `rg -n "concept_name" docs/`
- Read every file the slice will touch in full before editing.
- For UI work: also read the closest sibling component to copy patterns.
- For Rust FFI work: also read `agent_core/src/bridge.rs` to understand the FFI surface.

### Step 4 — Research online (if needed).
Use WebSearch + WebFetch ONLY when:
- The slice cites an external API (Anthropic Messages, OpenAI Responses, Apple framework).
- The slice depends on a third-party library you need to verify.
- The local canon explicitly says "verify current spec" (e.g., MLXStructured `maxLength` upcoming API).
- A failing test produces an error you can't diagnose from local context.

Do NOT use online research:
- For general design questions where the local canon already has an answer.
- To "double-check" a decision the user has explicitly locked.
- For Anthropic/OpenAI/Apple knowledge that's >6 months old and already in canon.

When online research is warranted: prefer primary sources (Apple Developer · Anthropic docs · the library's GitHub README/CHANGELOG · IETF/W3C/Unicode specs). Avoid blog posts and SO answers as primary sources.

### Step 5 — Implement.
- For DECISION slices: write the decision into the destination doc with explicit "Decision: X. Rationale: Y. Reversibility: Z." structure. Then move to Step 6.
- For DOC slices: write the new row / section into the destination doc. Match the existing doc's style + heading depth + table format.
- For CODE slices:
  - Edit existing files with the Edit tool (preserve indentation).
  - Use the Write tool only for genuinely new files.
  - Add `// SAFETY:` comments on every new `unsafe` Rust block.
  - No `try!`, no force-unwraps, no `print()`, no `panic!()` in production paths.
  - Swift: use `@Observable` (not `ObservableObject`), Swift Testing (`@Test` + `#expect`), background actors for inference.
  - Rust: `Result<T, E>` everywhere; `thiserror` for typed errors; no `unwrap()` outside tests.
  - UniFFI callbacks: `DispatchQueue.main.async` NEVER `.sync` (deadlock).
  - Streaming: never buffer; forward every token immediately. `AsyncStream` uses `.bufferingNewest(256)` not `.unbounded`.

### Step 6 — Verify.
Run the relevant subset:
- Rust changes: `cargo test --manifest-path agent_core/Cargo.toml --lib` (expect 1188+ passing)
- Swift changes: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` (must end "BUILD SUCCEEDED")
- Swift tests: use targeted `xcodebuild ... -only-testing:<suite>` for the slice, then full `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` at wave/pass boundaries. Do **not** use `swift test` as the broad verifier for this Xcode project.
- Lint: `swiftlint` for Swift, `cargo clippy --manifest-path agent_core/Cargo.toml` for Rust
- Shadow crate changes: `cargo test --manifest-path epistemos-shadow/Cargo.toml --lib`
- Doctrine lint (if touching cognitive DAG): `cargo run --manifest-path agent_core/Cargo.toml --bin epistemos_doctrine_lint`

If verification fails:
- Diagnose root cause (do not bandage).
- Fix.
- Re-run.
- If you can't fix in <30 minutes: revert only your slice's files (`git restore -- <specific files>`) and STOP with a clear surface-to-user message describing the obstacle. Never revert unrelated user/local edits.

### Step 7 — Update ledgers before committing.
- Append or update the row in `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8 Implementation Log using `(pending commit)` or `(this commit)` in the commit field if the SHA is not known yet.
- If the slice closed an audit-register entry: update `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` status to PATCHED or PATCHED PARTIAL with evidence, exact commands, and remaining risk.
- If the slice closed a gap-audit row: update the gap audit doc's destination/status column with `(pending commit)` and exact file evidence.
- If the slice surfaces a NEW gap or blocker: write it into the relevant audit doc immediately. Do not let it leak.

### Step 8 — Commit implementation + ledgers together.
- `git status` to confirm only the slice's files are staged.
- `git add <specific files>` (NEVER `git add -A`).
- Commit with HEREDOC:
  ```bash
  git commit -m "$(cat <<'EOF'
  <type>(<scope>): <imperative summary under 72 chars>

  <2-4 line body explaining WHY, not what>

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```
- Type prefixes: `feat` · `fix` · `docs` · `refactor` · `test` · `chore` · `perf` · `audit`
- Scope: the slice ID (e.g., `B2-2`, `B.1`, `C.5`)
- Do NOT push unless the user explicitly asks. Local commits accumulate; the user pushes when ready.
- After commit, replace any `(pending commit)` markers you introduced with the actual SHA in a tiny follow-up docs commit **only if** the project convention requires literal SHAs. Prefer `(this commit)` in the committed row to avoid churn.

### Step 9 — Exit cleanly.
End your turn with a 2-3 sentence summary: slice closed, commit SHA, verification result, what the next iteration should pick up. Do NOT chain another iteration. The /loop will re-fire with this prompt.

---

## §7. Research toolkit (when to use what)

| Need | Tool | Rule |
|---|---|---|
| Find a Rust symbol | `rg -n "name" agent_core/src/` | Direct, no agent |
| Find a Swift symbol | `rg -n "name" Epistemos/` | Direct, no agent |
| Find a doc concept across `docs/` | `rg -n "concept" docs/` | Direct, no agent |
| Read a known file | Read tool | Always over `cat` |
| Cross-cutting investigation (>3 files unknown) | Explore subagent | One subagent, "quick" or "medium" breadth |
| Validate against external API | WebFetch | Primary sources only |
| Discover current spec / version | WebSearch | Then WebFetch the primary source |
| Verify research-corpus claim | Read the cited file directly, then `rg` canonical docs | Trust but verify |
| Plan multi-step change | Plan subagent | Returns step plan, identifies critical files |
| Independent verification of your own work | Spawn Codex via the prompt in §13 | Every 10 iterations |

**The user's research-first rule applies:** Before code, docs, refactors, reroutes, reductions, or "simple" edits — search `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`, read the canonical local source it names, then verify current code/logs. Also search the local research regions most likely to contain nuance that was missed: `docs/fusion/jordan's research/`, `docs/fusion/**/kimi*`, `docs/fusion/**/gpt*`, `docs/_consolidated/`, `docs/fusion/salvage/`, `docs/audits/`, `docs/audits/codebase-verbatim-packets-2026-05-09/`, and `~/Documents/Epistemos-QuickCapture/`. Use semantic expansion: "zero-copy" means UMA · shared buffers · IOSurface · in-process · single-binary · deterministic provenance · no hot-path subprocess · no tensor copies · direct/bare-metal · "as complex as a brain, as simple as an app, as fast as a jet."

---

## §8. Implementation rules (the non-negotiables — never violate)

From AGENTS.md + CLAUDE.md:

1. **NO SIDECAR.** All inference AND orchestration in-process via Rust FFI or MLX-Swift. ONLY exception: oMLX bridge for oversized models. Use `LocalAgent*` (Swift) or `Runtime*` (Rust) for new local-agent work.
2. **REAL APIs ONLY.** Every cloud endpoint verified against provider docs. No fake features.
3. **HONEST CAPABILITY GATING.** Local models get fast/thinking/research. Cloud models get agent/liveAgent. NEVER fake agent capability for local models.
4. **RESEARCH-FIRST FOR EVERY TASK.** See §7.
5. **Zero test regressions against the current Xcode + Rust suites.**
6. **PRESERVE THINKING BLOCKS.** When `stop_reason == "tool_use"`, pass the ENTIRE content array back including thinking blocks + signatures.
7. **STREAM EVERYTHING.** Forward every token to the delegate immediately. No buffering.
8. **AGENT DECIDES TERMINATION.** `max_turns` is a safety rail, not a schedule. Trust `stop_reason == "end_turn"`.
9. **API keys in macOS Keychain** (`SecItemAdd` / `SecItemCopyMatching`), NEVER UserDefaults.
10. **MAS-first.** Every change must be App-Store-safe. CI gates: `strings` + `nm -gU` on the MAS bundle must return ZERO matches for the Pro-only allowlist.
11. **No Helios architecture changes.** V6.1 / SCOPE-Rex / 5-plane formalism / scope_rex kernels / resonance daemon — don't touch. Toggles default OFF; substrate stays as doctrine target.
12. **Graph is protected.** No camera / renderer / layout / edges / physics / hologram changes WITHOUT scoped user approval.
13. **Vault is sensitive.** Vault fixes start with evidence + minimal rationale + rollback-safe plan. No reset/delete/casual migration.
14. **No silent deferrals.** Every deferred item gets a row in Master Fusion Plan §8 Implementation Log AND/OR an audit row.
15. **Commit after every change.** User lost work to a checkout in the past. Never batch commits.
16. **No `xcodeproj` edits.** Use xcodegen.
17. **No model files** (`.gguf`, `.safetensors`, `.mlx`) committed.
18. **No SDKs that don't exist.** Anthropic has NO Swift SDK. OpenAI has NO Swift SDK. Use raw `URLSession`.

---

## §9. Critical do-NOTs (extracted because they get violated most)

- Do NOT skip pre-commit hooks (`--no-verify`). If a hook fails, diagnose and fix the underlying issue.
- Do NOT amend published commits.
- Do NOT use `git add -A` or `git add .` — stage specific files.
- Do NOT delete unfamiliar files / branches / configs without investigating (may be user's in-progress work).
- Do NOT use destructive git operations (`reset --hard`, `push --force`, `branch -D`, `clean -f`) without explicit user approval.
- Do NOT push to remote unless the user explicitly asks.
- Do NOT create CLAUDE.md files or generic README.md files.
- Do NOT use emojis in code or commit messages unless the user asked.
- Do NOT write decoration comments (`// What follows is...`). Only write comments where the WHY is non-obvious.
- Do NOT use `:?` debug format for JSON serialization.
- Do NOT use `AsyncStream` with `.unbounded` buffering — use `.bufferingNewest(256)`.
- Do NOT mark items done in PROGRESS.md until verification scans pass.
- Do NOT chain multiple slices in one loop iteration.
- Do NOT add features / refactor / introduce abstractions beyond what the slice requires.
- Do NOT add error handling for scenarios that can't happen. Trust internal code + framework guarantees.

---

## §10. Failure / blocker escalation

If during an iteration you hit:

| Symptom | Action |
|---|---|
| Test regression that wasn't yours | STOP. Surface with last-clean-commit SHA + suspected breaking commit. |
| Build fails on a fresh clone of master | STOP. Surface as environment issue. |
| Gap audit claim contradicts current code | Verify the code (`rg` + read). Update the audit doc. Continue. |
| Slice requires an external decision the user hasn't made | DECISION row only — write the question + 2-3 alternatives + recommended path. Commit the decision doc. Move to next slice. |
| Slice requires touching protected surface (graph / vault) | STOP. Surface with the exact change + rollback plan. |
| Verification can't be automated (manual smoke needed) | Stub the test + add audit-register row with manual-smoke steps. Surface to user. Commit the stub. Move on. |
| Cargo crate or Swift target unknown | Read its `Cargo.toml` / project structure first. If still unclear, STOP and surface. |
| Network needed for online research and no connectivity | STOP. Surface as environment issue. |
| Loop has been running >50 iterations without user input | STOP. Surface as "long-running autonomous session, recommend manual review." |

In all STOP cases: write a clear surface message describing (a) what you tried, (b) what went wrong, (c) what the user / next iteration should do. Do NOT delete work-in-progress.

---

## §11. Stop conditions (hard exits)

End the loop entirely (not just this iteration) when:

1. Priority queue in §5 is empty — every BLOCKER + HIGH + MEDIUM + LOW item is closed or routed.
2. User issues an explicit stop via `/loop` cancellation.
3. 3 consecutive iterations report "no clean slice found" — queue may be exhausted or stale.
4. Working tree has drifted such that `cargo test` fails on `main` (not your changes) — environment broken.
5. Branch has been force-pushed by another agent (your local commits orphaned) — needs human reconciliation.

---

## §12. Self-recovery (loop resumption after interruption)

If you wake up mid-loop with no memory of prior iterations:
1. Read §3 state-check ritual output.
2. `git log --oneline codex/research-snapshot-2026-05-08 ^main | head -50` shows what's been done.
3. Cross-reference recent commits against §5 priority queue — every closed slice should have a commit.
4. Pick the first open slice. Continue.

If `git status` shows uncommitted edits:
1. Run `git diff` to see what's there.
2. If the edits look like the tail end of a prior iteration's Step 5 that crashed before Step 7: complete the verification (Step 6), commit (Step 7), update ledgers (Step 8).
3. If the edits look exploratory / partial: STOP and surface to user. Do not discard.

---

## §13. Codex audit-of-audit prompt (run every 10 iterations OR when you finish a Phase)

Use this prompt to spawn Codex (or another Claude in a fresh session) for independent verification. Copy verbatim:

```
You are Codex. Your job is to independently verify Claude's recent work on the Epistemos repo and surface any drift between research / canon / code.

Repo: /Users/jojo/Downloads/Epistemos
Active branch: codex/research-snapshot-2026-05-08
User: Jordan Conley (M2 Pro 16GB, macOS, solo dev)

## Reading order (read these first, in full):
1. AGENTS.md
2. CLAUDE.md
3. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
4. docs/NEW_SESSION_HANDOFF_2026_05_15.md
5. docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8 Implementation Log
6. docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md (PASS 1, 31 gaps)
7. docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md (PASS 2, 37 gaps)
8. docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_2026_05_15.md (Claude's loop prompt)

## Tasks (do in order):

### Task 1 — Verify Claude's last 10 commits
Run: git log --oneline codex/research-snapshot-2026-05-08 ^main | head -10
For each commit:
- Find the slice ID in the commit message (e.g., B-5, B2-2, C.5).
- Find the corresponding row in the priority queue (§5 of CLAUDE_AUTONOMOUS_LOOP_PROMPT_2026_05_15).
- Verify the commit's diff actually implements that slice (not a related slice, not a partial slice).
- Run the loop prompt §5.0 current-truth reconciliation gate for any commit whose slice row looks stale.
- Verify tests still pass: cargo test --manifest-path agent_core/Cargo.toml --lib
- Verify build still green: xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
- For doc-only commits: verify the doc cross-references actually resolve.

Report: per commit, "✅ verified" or "⚠️ drift: <description>".

### Task 2 — Re-verify PASS 2 trust-but-verify items
PASS 2 §5 rejected 4 candidates. Re-confirm each:
- Halo Shadow Crate: ls /Users/jojo/Downloads/Epistemos/epistemos-shadow/Cargo.toml
- Phase R framing: rg -n "Phase R" docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md docs/NEW_SESSION_HANDOFF_2026_05_15.md || true
- InterruptScoreCpu: rg -n "InterruptScore" docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md
- session_insights.rs registration: rg -n "session_insights" agent_core/src/lib.rs

If any verification flips (e.g., epistemos-shadow disappears), surface immediately.

### Task 3 — Independent corpus sweep (the "did Claude miss anything in PASS 2?" check)
Do your OWN corpus sweep with these 3 targets:
A. docs/fusion/research/icloud-loose/ — never explicitly cited by Claude's agents
B. docs/_consolidated/50_research_corpus/ — 318 files, Claude's Agent 1 only sampled 30%
C. docs/audits/codebase-verbatim-packets-2026-05-09/ — Claude's Agent 2 only skimmed
D. docs/fusion/jordan's research/ + docs/fusion/**/kimi* + docs/fusion/**/gpt* — spot-check any slice concepts that appear in recent commits

For each region, look for concepts that:
- Are named architectural primitives, UX surfaces, or pricing/distribution decisions
- Are absent from PASS 1 + PASS 2 (`rg` corpus scan + both gap audits)
- Have a clear destination (which canonical doc would absorb them)

Report 3-5 new candidate gaps with the same severity tiering.

### Task 4 — Online research validation
For each of these PASS 2 items, verify the external citation is correct:
- B2-H8 Hurwitz theorem on most-irrational number (golden ratio φ)
- B2-H7 Laplace-Beltrami operator and spectral hallucination detection (cite recent paper if any)
- B2-H10 macOS XPC service lifecycle (Apple Developer doc URL)
- B2-H12 Anthropic prompt caching breakpoint semantics (verify 4-breakpoint cap)
- B2-2 ULID specification (verify content_hash + ULID combination is canonical practice)

Report any citation that doesn't hold up.

### Task 5 — Independent recommendation
Based on Tasks 1-4, recommend:
- Is Claude's loop on track or drifting?
- Which slice should be promoted to next-up (out of priority order) if any?
- Are there blockers Claude isn't flagging?
- Should the loop continue, pause for human review, or stop?

Report ≤500 words. Be direct. Don't pad.

## Verification protocol
For every claim you make about file content: cite path + line number + command / Read evidence. Trust no source you haven't read yourself.

## Constraints
- Do NOT push to remote.
- Do NOT amend Claude's commits.
- Do NOT modify the gap audit docs without surfacing the proposed change.
- Do NOT touch the working tree if it's mid-iteration (uncommitted edits + last commit < 5 min old).
```

---

## §14. Online research targets (when, what, how)

When a slice needs external validation, prefer these primary sources:

| Domain | Primary source |
|---|---|
| Anthropic Messages API / prompt caching / thinking blocks | https://docs.anthropic.com |
| OpenAI Responses API | https://platform.openai.com/docs |
| Apple frameworks (Swift / SwiftUI / AppKit / Metal / Foundation) | https://developer.apple.com/documentation/ |
| Apple XPC + launchd + sandbox | https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/ |
| App Store Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| Apple Security (Keychain / Secure Enclave) | https://developer.apple.com/documentation/security |
| Rust / Cargo | https://doc.rust-lang.org · https://crates.io |
| UniFFI | https://mozilla.github.io/uniffi-rs/ |
| MLX / MLX-Swift | https://github.com/ml-explore/mlx-swift |
| Tantivy | https://github.com/quickwit-oss/tantivy |
| usearch | https://github.com/unum-cloud/usearch |
| GRDB | https://swiftpackageindex.com/groue/GRDB.swift |
| Tree-sitter | https://tree-sitter.github.io |
| Cozo | https://github.com/cozodb/cozo |
| MCP spec | https://spec.modelcontextprotocol.io |
| Linear / Algebraic primitives (Laplacian / Koopman / Kleene / VSM) | Original papers via arXiv or author homepages |

Do NOT use:
- Stack Overflow as a primary source (only for symptom matching).
- Random blog posts.
- LLM-generated docs (e.g., GPT-explained APIs).
- Anything older than 18 months for fast-moving APIs (Anthropic, OpenAI, MLX).

---

## §15. End-of-turn summary template (paste at the end of every iteration)

```
Iteration complete.

Slice closed: <slice ID + one-line description>
Commit: <SHA>
Verification: <test result, build result>
Ledger updates: <file paths>

Next iteration should pick: <slice ID> (next open item in priority queue)
Blockers surfaced: <none, or list>
Audit recommended: <yes/no — yes if iteration count divisible by 10>
```

---

## §16. The deep "why" the user wants this loop

The user (Jordan) is building Epistemos solo on an M2 Pro 16GB. He has lost work to git mistakes before — that's why "commit after every change" is non-negotiable. He has watched AI sessions burn tokens producing fragmented work — that's why "research-first, doc-first" exists. He has watched canon drift as scattered docs supersede each other — that's why the cocktail + gap audits + audit-of-audit exist.

This loop is the user's lever for sustained forward progress without his constant supervision. Treat every iteration as if Jordan will spot-check it at random. Every commit should be defensible. Every doc edit should be the best-version (per the user's best-version-audit memory: when multiple versions of a concept exist across tiers, enumerate them, rank by rigor / philosophy / recency / specificity, and ship the BEST).

The user has explicitly opted in to:
- Deep doc reading (verbose-doc-first protocol — token cost is not a concern)
- Multiple parallel agent spawns for research
- Online research with web tools when needed
- Independent audit-of-audit via Codex every 10 iterations
- Continuous looping until the priority queue is empty

The user has explicitly opted OUT of:
- Editing CLAUDE.md without his approval
- Force-pushing or any destructive git operation
- Working on Hermes namespace (purged 2026-05-05; use LocalAgent / Runtime)
- Working on Helios v6.1 substrate beyond what's already shipped (5 V6.1 kernels stay target-only)
- Adding subprocess-based features (NO SIDECAR is absolute)

---

## §17. Final reminder

You are not trying to ship V1 in one iteration. You are trying to close ONE slice per iteration with high confidence and a clean commit. The loop is patient. Do the slice well, commit it, exit.

If you genuinely have no work to do: report "queue empty, all 68 items + every Phase B/C/D/E item routed or closed" and stop. That's the success state.

Now: re-read §2, run §3, pick a slice, work it, commit it, exit.

— End of loop prompt. The /loop will re-fire this verbatim. Do not memorize it; re-read it next iteration.
