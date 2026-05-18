---
state: codex-claude-terminal-dispatch
created_on: 2026-05-18
purpose: Paste-ready terminal launchers for the no-compromise substrate hardening pass. Each of the 27 T-prompts is assigned to Codex or Claude based on what each tool is best at, organized into cohorts that respect scope locks and the T5 in-flight constraint.
authority: docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md is the T-prompt source-of-truth; this doc is the dispatch layer over it.
---

# Codex / Claude Terminal Dispatch — 2026-05-18

## §1. Tool assignment rationale

| | Claude Code wins when... | Codex wins when... |
|---|---|---|
| Workload | Cross-language work (Swift + Rust + Metal in one slice) | Single-language Rust substrate modules |
| Tempo | Interactive iteration with course corrections | Long autonomous loops (many iterations to acceptance) |
| Stakes | User-facing UI / naming nuance / architectural tradeoffs | Mechanical primitive implementation / measurement harnesses |
| Strengths | Holding many invariants in head; cross-doc synthesis; product judgment | Scope-locked grinding; falsifier benchmarks; doc-heavy classification |

## §2. Full assignment table (all 27 T-prompts)

| T-ID | Title | Tool | Why this tool |
|---|---|---|---|
| T09 | Product Architecture Ledger | **Claude** | Cross-codebase audit + nuance about wired-vs-scaffold-vs-hidden-dead |
| T10 | Eidos V0 | **Claude** | Rust core + Swift bridge + tests + Settings diagnostics row |
| T10B | Eidos Form Layer | **Codex** | Pure Rust typed schema layer + property tests |
| T11 | Agent Runtime v2 / System G | **Claude** | Architectural depth + Aegis-rejection discipline + cross-language |
| T12 | F-ULP Oracle | **Codex** | Metal kernel + 412k-point fp16 ULP measurement loop |
| T13 | F-KV-Direct Gate | **Codex** | 100-prompt corpus benchmark on Qwen3-8B-MLX-4bit |
| T14 | Five-plane UAS-ACS Wiring | **Claude** | Plane-placement nuance + naming-drift discipline |
| T15 | Executor Trait | **Codex** | Rust trait + mock + adapter sketch |
| T16 | Live File Compiler | **Codex** | 10-state machine + LivePlan.v1 schema |
| T17 | Cognitive Weight Class Enforcement | **Codex** | Metadata enforcement rules engine |
| T17B | Lattice / WBO Register | **Codex** | Doc-heavy + lightweight Rust types (no kernels yet) |
| T18 | Residency Governor + Rail | **Claude** | Rust governor + Swift Settings + memory-tier policy |
| T18B | ACS Admission Field | **Codex** | Typed policy module + verdict tests |
| T19 | Halo V1 + Eidos Control Vectors | **Claude** | Delicate Halo UI surface; needs restraint |
| T20 | Variant Ladder Generalization | **Codex** | Mechanical one-route wiring with logged tier choices |
| T21 | Vault Recall Contract / F-VaultRecall-50 | **Claude** | Cross-language fix + visible UX + Brain Panel diagnostics |
| T22 | Substrate Health Panel | **Claude** | SwiftUI design + integrating multiple service health signals |
| T22B | Brain Panel Closed Citations | **Claude** | Chat UX + visible citation truth |
| T23 | F-70B Local Cocktail | **Codex** | Long-running measurement harness; Research-tier only |
| T23B | M2 Pro Falsifier Handbook | **Codex** | Catalog-style doc generation |
| T24 | Lean ClaimLedger Schema Authority | **Claude** | Lean + Rust + Swift schema generation + family-choice judgment |
| T25 | ACS Naming Reconciliation | **Codex** | Mechanical lint + doc edits |
| T26 | Self-Evolving Adapter Lane (L_SE) | **Codex** | Research-tier type skeleton |
| T27 | WRV Product Surfacing | **Claude** | Cross-language + UI + judgment about which 3 P0 W-rows |

**Score: 12 Claude / 15 Codex.** Roughly balanced. Claude takes the user-facing slices and architectural ones; Codex takes substrate primitives and falsifier harnesses.

## §3. Cohort plan (respects scope locks + T5 in-flight)

### Cohort A — start NOW (T5 still running, zero conflicts)

These four touch entirely separate files and none touch T5's paths.

| Terminal | Tool | T-ID | Scope |
|---|---|---|---|
| 1 | Claude | T09 | `docs/CURRENT_PRODUCT_ARCHITECTURE_LEDGER_2026_05_18.md` only |
| 2 | Claude | T21 | `agent_core/src/storage/vault.rs` + retrieval tests + diagnostics |
| 3 | Codex | T17B | `docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md` + `agent_core/src/lattice_wbo/` (NEW) |
| 4 | Codex | T23B | `docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md` only |

### Cohort B — start after T09 lands (so it can reference the ledger)

| Terminal | Tool | T-ID | Scope |
|---|---|---|---|
| 5 | Claude | T10 | `agent_core/src/eidos/` (NEW) + `Epistemos/Eidos/` (NEW) |
| 6 | Claude | T11 | `agent_core/src/agent_runtime_v2/` (NEW) + `Epistemos/AgentRuntimeV2/` (NEW) |
| 7 | Codex | T12 | `agent_core/src/research/eml_ir/` + `Epistemos/Shaders/morph_eval_reduced.metal` (NEW) |
| 8 | Codex | T18B | `agent_core/src/acs_admission/` (NEW) |

### Cohort C — start after T10 lands

| Terminal | Tool | T-ID | Scope | Why ordered |
|---|---|---|---|---|
| 9 | Codex | T10B | `agent_core/src/eidos/forms.rs` | Same module as T10; must come after |
| 10 | Claude | T22B | Chat / Brain Panel | Needs T10's source IDs to validate against |
| 11 | Codex | T13 | `agent_core/src/scope_rex/kv/` | Independent; could overlap with Cohort B but I/O heavy |

### Cohort D — start after T11 lands

| Terminal | Tool | T-ID | Scope |
|---|---|---|---|
| 12 | Codex | T15 | `agent_core/src/executor/` (NEW) — pairs with T11 |
| 13 | Codex | T16 | `agent_core/src/live_files/` (NEW) |

### Cohort E — lower-priority, flexible timing

| Tool | T-IDs | Notes |
|---|---|---|
| Codex | T17, T20, T25, T26 | Mechanical / docs-heavy |
| Claude | T19, T24 | Halo adapter + Lean schema |

### Cohort F — merge-gated (waits for user authorization)

| T-ID | Why gated |
|---|---|
| T14 | needs T3 codex/t3-uasacs-2026-05-16 merged |
| T18 (full) | needs T3 merged |
| T22 (full) | needs T2 + T3 + T4 + T7 merged |
| T23 | not merge-gated but heavy; defer until cohorts A-D done |
| T27 | needs merges + the 45 W-rows |

## §4. Paste-ready Cohort A (start these four now)

Open four terminals. Paste one block into each. Wait — terminal 1 (T09) finishes first; the others can run in parallel with it but their outputs depend on T09's ledger for some classifications.

### Terminal 1 — Claude Code — T09 Product Architecture Ledger

```text
You are Claude Code working in /Users/jojo/Downloads/Epistemos. Obey AGENTS.md.

Read this canon first, in order:
1. docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md
2. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
3. docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md (your full T-prompt body is in §4 under "### T09 - Current Product Architecture Ledger")
4. docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md
5. docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA, ~200 GB/s.
Agent naming: System G / Invader Agent canon. Aegis is REJECTED.
Do not merge T-branches. Do not touch T5 paths: agent_core/src/research/{operator_ir,scan_ir,tropical_ir}/.

Mission this session: execute T09 Product Architecture Ledger.
Branch: codex/t09-product-ledger-2026-05-18
Output: docs/CURRENT_PRODUCT_ARCHITECTURE_LEDGER_2026_05_18.md

Discipline:
- WRV before claiming done. "File exists" is never shipped without caller chain and visible proof.
- Every subsystem gets a status: current-wired, visible-working, visible-broken, hidden-working, hidden-dead, implemented-not-wired, feature-gated, scaffold-only, not-implemented, excluded-speculative.
- Every row records lane: MAS/current, Pro, Research, Infrastructure/reserved, Vault, R0.
- Include delete/hide/merge/keep/build-next lists at the end.
- Commit after every meaningful section. Use clear messages.

Read the §4 entry for T09 in full before starting. Then execute. Report exact files inspected and tests/greps used to verify each classification.
```

### Terminal 2 — Claude Code — T21 Vault Recall Contract / F-VaultRecall-50

```text
You are Claude Code working in /Users/jojo/Downloads/Epistemos. Obey AGENTS.md.

Read this canon first, in order:
1. docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md
2. docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md (the bug diagnosis with the Fix-A/B/C plan)
3. docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### T21 - Vault Recall Contract"
4. docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md
5. docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA.
Agent naming: System G / Invader Agent canon. Aegis REJECTED.
Do not merge T-branches. Do not touch T5 paths.

Mission this session: execute T21 Vault Recall Contract / F-VaultRecall-50.
Branch: codex/t21-vault-recall-contract-2026-05-18
Primary fix file: agent_core/src/storage/vault.rs (apply Fix-B and Fix-C from the diagnosis doc)
Plus: ChatCoordinator vault-context-injection seam, F-VaultRecall-50 fixture, Brain Panel "Retrieved by" surface.

Discipline:
- Write a failing test first that reproduces the "first 7 irrelevant notes" failure with a fixture vault.
- Apply Fix-B (set_conjunction_by_default(true) + stopword filter) and Fix-C (remove score.clamp(0.0, 1.0) so BM25 signal survives).
- No production retrieval path may build context from index-order LIMIT N.
- Every retrieval emits lexical + semantic + graph + recency + MMR trace.
- UI must show loaded source titles + snippets for chat/agent retrieval.
- F-VaultRecall-50 fixture pass rate must be visible in Settings diagnostics.
- WRV: user can reach the fix from a chat query, see the trace, and the trace cites the actual loaded note IDs.
- Commit after each fix lands with the relevant test passing.

Read the §4 entry for T21 in full + the F-VaultRecall-50 diagnosis before touching code. Then execute.
```

### Terminal 3 — Codex — T17B Lattice / WBO Register

```text
You are Codex working in /Users/jojo/Downloads/Epistemos. Follow AGENTS.md.

Read docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md for full doctrine.

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA, ~200 GB/s.
Agent naming: System G / Invader Agent canon. Aegis REJECTED. Code namespace: agent_runtime_v2.
No merging T-branches. T5 scope-locked: agent_core/src/research/{operator_ir,scan_ir,tropical_ir}/.

Mission: T17B Lattice / WBO Register.
Branch: codex/t17b-lattice-wbo-register-2026-05-18

Full spec in docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### T17B - Lattice / WBO Register". Read it before iterating.

Output:
- docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md (preserves Lattice-Wyner-Ziv, LatticeCoder<BITS>, Babai/GPTQ, Sherry, ShadowKV, QuIP/E8, residual/sketch, WBO terms T_W/T_K/T_R/T_Q/T_S/T_SE/T_num, softmax-½ post-correction)
- agent_core/src/lattice_wbo/ (NEW) — lightweight types: LatticeBudget, LatticeCoderKind, LatticeErrorContribution, WboLedgerEntry, ActiveSupportBudget, SideInformationKind
- Tests: serialize/deserialize budget structs

Do NOT implement heavy kernels yet. This is accounting substrate, not a speed claim.

Iterate to acceptance bar. Commit every meaningful change with acceptance-bar progress. Stop when accepted.
```

### Terminal 4 — Codex — T23B M2 Pro Falsifier Handbook

```text
You are Codex working in /Users/jojo/Downloads/Epistemos. Follow AGENTS.md.

Read docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md for full doctrine.

Hardware floor (the subject of this terminal): M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA, ~200 GB/s.
Agent naming: System G / Invader Agent canon. Aegis REJECTED.
No merging T-branches. T5 scope-locked.

Mission: T23B M2 Pro Falsifier Handbook.
Branch: codex/t23b-m2pro-falsifier-handbook-2026-05-18

Full spec in docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### T23B - M2 Pro Falsifier Handbook". Read it before writing.

Output:
- docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md
- tools/falsifiers/ stubs marked NOT IMPLEMENTED where scripts don't exist

Required falsifiers (each with purpose / status / input fixture / pass threshold / failure meaning / fallback route / product lane / command / expected artifact):
F-Eidos-ClosedCitation, F-VaultRecall-50, F-PageGather-Baseline, F-PageGather-Scatter, F-UAS-CopyCount, F-ACS-AnchorLookup, F-InterruptScore-CPU, F-PacketRouter1bit, F-ControllerKernelPack, F-SemiseparableBlockScan, F-LocalRecallIsland, F-KV-Direct-Gate, F-WBO-DriftLedger, F-ULP-Oracle, F-70B-Local-Cocktail-Lite.

Do NOT claim any gate passed unless repo evidence exists. Mark all unimplemented scripts NOT IMPLEMENTED explicitly.

Iterate to acceptance bar. Commit each falsifier-row addition. Stop when handbook is complete and accepted.
```

## §5. Cohort B+C+D wrapper templates

Once Cohort A finishes, use these templates. Replace `<T-ID>`, `<short title>`, and `<branch-slug>` per the assignment table.

### Generic Claude wrapper

```text
You are Claude Code working in /Users/jojo/Downloads/Epistemos. Obey AGENTS.md.

Read this canon first, in order:
1. docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md
2. docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### <T-ID> - <short title>"
3. Whatever else the §4 entry's "Read first" block names.

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA, ~200 GB/s.
Agent naming: System G / Invader Agent canon. Aegis REJECTED. Code namespace: agent_runtime_v2.
Do not merge T-branches. Do not touch T5 paths.

Mission this session: execute <T-ID> (<short title>).
Branch: codex/<branch-slug>-2026-05-18

Discipline:
- WRV before claiming done.
- Write a failing test first when fixing code.
- Keep scope locks tight. Do not refactor adjacent code.
- Commit after every meaningful change.
- Report exact commands and outputs.
- Mark anything without a caller as implemented-not-wired.
- Append cross-terminal wiring discoveries as new W-rows to docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md.

Read the §4 entry for <T-ID> in full before starting. Then execute.
```

### Generic Codex wrapper

```text
You are Codex working in /Users/jojo/Downloads/Epistemos. Follow AGENTS.md.

Read docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md for full doctrine.

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA.
Agent naming: System G / Invader Agent canon. Aegis REJECTED. Code namespace: agent_runtime_v2.
No merging T-branches. T5 scope-locked: agent_core/src/research/{operator_ir,scan_ir,tropical_ir}/.

Mission: <T-ID> (<short title>).
Branch: codex/<branch-slug>-2026-05-18
Full spec: docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### <T-ID> - <short title>".

Iterate to acceptance bar. Commit every meaningful change with explicit acceptance-bar-progress message. Run narrow relevant tests and report exact commands + outputs. Stop when acceptance bar passes or when blocked (surface the blocker).
```

## §6. Branch-slug map (for the Codex `codex/<slug>-2026-05-18` pattern)

| T-ID | Branch slug |
|---|---|
| T09 | t09-product-ledger |
| T10 | t10-eidos-v0 |
| T10B | t10b-eidos-form-layer |
| T11 | t11-agent-runtime-v2 |
| T12 | t12-f-ulp-oracle |
| T13 | t13-kv-direct-gate |
| T14 | t14-five-plane-uas-acs |
| T15 | t15-executor-trait |
| T16 | t16-live-file-compiler |
| T17 | t17-cognitive-weight-class |
| T17B | t17b-lattice-wbo-register |
| T18 | t18-residency-governor |
| T18B | t18b-acs-admission-field |
| T19 | t19-halo-eidos-control-vectors |
| T20 | t20-variant-ladder-generalization |
| T21 | t21-vault-recall-contract |
| T22 | t22-substrate-health-panel |
| T22B | t22b-brain-panel-closed-citations |
| T23 | t23-f70b-local-cocktail |
| T23B | t23b-m2pro-falsifier-handbook |
| T24 | t24-lean-claimledger-schema |
| T25 | t25-acs-reconciliation |
| T26 | t26-lse-adapter-lane |
| T27 | t27-wrv-product-surfacing |

## §7. Merge phase (USER-AUTHORIZED only)

When Jojo says "merge T-branches now":
1. Confirm T5 has finished (`git log codex/t5-emlir-2026-05-16` shows a final commit, no in-flight work).
2. Walk `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-row dependency order — not arbitrary branch order.
3. Merge in groups that unblock the most P0 W-rows first (likely T3 + T4 → unblocks W-01, W-04, W-19, W-22; then T2 → unblocks W-11, W-14, W-15; then T1 + T6 + T7 → unblocks W-06, W-20, W-26).
4. After merges, run T14 + T18 (full) + T22 (full) + T27. These were Cohort F.
5. Tag `v2.0` when the substrate becomes the runtime.

## §8. What this dispatch is NOT

- Not a replacement for the prompt deck. The deck §4 is the source-of-truth for T-prompt bodies; this doc is the dispatch layer.
- Not a license to merge T-branches. Merge phase is user-authorized.
- Not a license to touch T5 paths until T5 completes.
- Not a fixed tool assignment. If a Codex terminal hits a cross-language slice and stalls, switch to Claude. If a Claude session is grinding through a mechanical loop, consider switching to Codex.
