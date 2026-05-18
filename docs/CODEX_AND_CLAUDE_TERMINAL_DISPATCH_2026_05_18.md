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

Eight terminals can launch simultaneously. They all create NEW modules or touch entirely separate files, with zero conflicts with each other or with T5's paths.

| Terminal | Tool | T-ID | Scope |
|---|---|---|---|
| 1 | Claude | T09 | `docs/CURRENT_PRODUCT_ARCHITECTURE_LEDGER_2026_05_18.md` only |
| 2 | Claude | T21 | `agent_core/src/storage/vault.rs` + retrieval tests + diagnostics |
| 3 | Codex | T17B | `docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md` + `agent_core/src/lattice_wbo/` (NEW) |
| 4 | Codex | T23B | `docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md` only |
| 5 | Claude | T10 | `agent_core/src/eidos/` (NEW) + `Epistemos/Eidos/` (NEW) |
| 6 | Claude | T11 | `agent_core/src/agent_runtime_v2/` (NEW) + `Epistemos/AgentRuntimeV2/` (NEW) |
| 7 | Codex | T12 | `agent_core/src/research/eml_ir/` + `Epistemos/Shaders/morph_eval_reduced.metal` (NEW) — NOT operator_ir/scan_ir/tropical_ir (T5) |
| 8 | Codex | T18B | `agent_core/src/acs_admission/` (NEW) |

**Note:** T10, T11, T12, T18B were previously gated to "after T09 lands" out of caution. Reassessment: T09 builds a docs-only ledger, and T10/T11/T12/T18B all create NEW modules that don't read from the ledger to *build* — they only consume it later for final classification. So all 8 can launch concurrently. With T5 still running, that's 9 active terminals.

### Cohort B — start after T10 + T11 land (so dependents have substrate)

| Terminal | Tool | T-ID | Why this order |
|---|---|---|---|

| 9 | Codex | T10B | Same `agent_core/src/eidos/` module as T10 — must come after T10 lands |
| 10 | Claude | T22B | Needs T10's source IDs to validate citations against |
| 11 | Codex | T13 | KV-Direct gate — independent but I/O-heavy, defer to avoid disk pressure overlap |
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

## §3.5 Forever-loop discipline (mandatory for every terminal)

Every terminal is a **forever loop**. Do not exit unless Jojo explicitly stops you. The point of the cadence below is to maximize accurate canonical code and **minimize disk pressure** from constant rebuilds — Jojo runs M2 Pro 16GB and concurrent full app builds across multiple terminals trigger memory + SSD pressure.

### Tool-specific invocation

- **Claude Code terminals**: at session start, invoke the `/loop` skill self-paced with this entire prompt as the body. Each `/loop` tick = one iteration of the cadence below.
- **Codex terminals**: the prompt IS your autonomous-loop driver. Iterate `iter-1`, `iter-2`, ... `iter-N`. Status-pulse every 10-20 iterations. Never exit.

### Per-iteration cadence (build-first, test-later)

1. **Re-read your acceptance bar** from `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4. Don't drift from the spec.
2. **Pick the smallest canonical advancement** — feature work if acceptance bar not yet met, or hardening if it is.
3. **Implement** accurate, canonical, no-compromise code. Preserve research nuance; never collapse lanes.
4. **Write the unit test alongside** but **do not** run the full build yet.
5. **Commit small** with a clear message naming the acceptance-bar progress.
6. **Repeat 1-5** for ~3-10 iterations. Accumulate changes.
7. **Then run narrow tests** — never `cargo test --workspace` or full `xcodebuild`. Use:
   - Rust: `cargo test -p <crate> <test-filter>`
   - Swift: `xcodebuild test -scheme Epistemos -only-testing:<target>/<test>`
8. **Green: continue. Red: minimum fix only.** Do not refactor adjacent code.
9. **When the acceptance bar is met**, enter **deep hardening only if truly super done**:
   - error paths
   - edge cases (empty, nil, max, unicode, concurrent, rapid toggle)
   - doc updates where load-bearing
   - additional property tests / fixture variations
   - WRV (Wired, Reachable, Visible, Verified) end-to-end check
   - cross-link to CROSS_TERMINAL_WIRING_BACKLOG W-rows where relevant
10. **After a complete hardening pass, return to step 1.** Find the next no-compromise nuance. **The acceptance bar is a floor, never a ceiling.** Loop forever.

### Scope lock — strict, no exceptions

- Never leave your T-prompt's scope-locked paths.
- Never edit another terminal's scope-locked paths.
- Never touch T5's paths: `agent_core/src/research/{operator_ir,scan_ir,tropical_ir}/`.
- Never merge T-branches — user-authorized only.
- If a fix obviously needs another terminal's substrate, **append a new W-row** to `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` and **continue inside your scope**. Do not "just fix" cross-terminal needs.

### Disk-pressure mitigation

- **Build features first** in steps 1-5. Defer compile/test cycles to batched runs at step 7.
- **Never `cargo build --workspace`** if you touched one crate. Use `cargo build -p <crate>`.
- **Never full `xcodebuild`** if you only touched Rust or docs.
- **Never `cargo clean`** unless something is genuinely broken. Incremental is correct.
- **Batch test runs** at iteration-end, not after every commit.

### Canonical discipline

- No-compromise canon **trumps** shortcuts.
- "It compiles" is **not** "it ships". WRV is the bar.
- **Aegis name is REJECTED.** System G / Invader Agent canon. Code namespace: `agent_runtime_v2`.
- Hermes prompt-format parity may stay; Hermes subprocess stays purged.
- **Preserve research lanes**; never collapse them into product paths.
- "Preserve wide, build narrow" is the permanent commandment.

## §4. Paste-ready Cohort A (start these four now)

Open four terminals. Paste one block into each. Wait — terminal 1 (T09) finishes first; the others can run in parallel with it but their outputs depend on T09's ledger for some classifications.

### Terminal 1 — Claude Code — T09 Product Architecture Ledger (FOREVER LOOP)

```text
You are Claude Code working in /Users/jojo/Downloads/Epistemos. Obey AGENTS.md.

FIRST ACTION: invoke the `/loop` skill self-paced with this entire prompt as the body. Each `/loop` tick = one iteration of the cadence below. NEVER EXIT unless Jojo explicitly stops you.

Read once at session start:
1. docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md
2. docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md §3.5 (full forever-loop discipline)
3. docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### T09 - Current Product Architecture Ledger" (your acceptance bar)
4. docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA.
Agent naming: System G / Invader Agent canon. Aegis is REJECTED. agent_runtime_v2 in code.
Do not merge T-branches. Do not touch T5 paths: agent_core/src/research/{operator_ir,scan_ir,tropical_ir}/.

Mission: T09 Product Architecture Ledger — FOREVER LOOP.
Branch: codex/t09-product-ledger-2026-05-18
Output: docs/CURRENT_PRODUCT_ARCHITECTURE_LEDGER_2026_05_18.md

PER-ITERATION CADENCE (build-first / test-later):
1. Re-read your acceptance bar (§4 T09). Don't drift.
2. Pick smallest canonical advancement: classify ONE more subsystem OR harden ONE existing row.
3. Write the row with no-compromise discipline: status (current-wired / visible-working / visible-broken / hidden-working / hidden-dead / implemented-not-wired / feature-gated / scaffold-only / not-implemented / excluded-speculative) + lane (MAS / Pro / Research / Infrastructure / Vault / R0) + evidence + missing proof + next action + falsifier.
4. Verify with rg/find/git-log. DO NOT run cargo build or xcodebuild — this is docs-only.
5. Commit small with clear message ("docs(ledger): classify <subsystem> as <status>").
6. Repeat 1-5 for ~3-10 ticks.
7. THEN batch-verify: re-grep the codebase for your last 3-10 classified subsystems; confirm evidence holds.
8. If a classification was wrong: minimum correction only. Do not refactor adjacent rows.
9. When the ledger covers every subsystem in AppBootstrap + AppEnvironment + ChatCoordinator + LocalAgent + Omega/MCP + scope_rex + cognitive_dag + provenance + Halo/Shadow + .epdoc + LSP + Knowledge Fusion + Settings UI + delete/hide/merge/keep/build-next lists: enter DEEP HARDENING only if truly super done.
10. DEEP HARDENING: every row has a falsifier link, every "visible-working" claim survives WRV end-to-end, cross-link CROSS_TERMINAL_WIRING_BACKLOG W-rows. After hardening pass, return to step 1 — find subsystems the canon mentions that aren't yet in the ledger. Acceptance bar is a floor, never a ceiling. Loop forever.

SCOPE LOCK: write docs/CURRENT_PRODUCT_ARCHITECTURE_LEDGER_2026_05_18.md (NEW). Append W-rows to docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md as cross-terminal needs surface. Touch nothing else. No app code edits. No T5 paths. No T-branch merges.

DISK PRESSURE: docs-only — no cargo build, no xcodebuild. rg/grep only.

CANONICAL: no-compromise > shortcuts. WRV > "it compiles". Preserve every research nuance. Aegis REJECTED.
```

### Terminal 2 — Claude Code — T21 Vault Recall Contract / F-VaultRecall-50 (FOREVER LOOP)

```text
You are Claude Code working in /Users/jojo/Downloads/Epistemos. Obey AGENTS.md.

FIRST ACTION: invoke the `/loop` skill self-paced with this entire prompt as the body. Each `/loop` tick = one iteration. NEVER EXIT unless Jojo explicitly stops you.

Read once at session start:
1. docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md
2. docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md §3.5 (full forever-loop discipline)
3. docs/audits/F_VAULT_RECALL_50_DIAGNOSIS_2026_05_16.md (bug diagnosis + Fix-A/B/C plan)
4. docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### T21 - Vault Recall Contract" (acceptance bar)
5. docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md (W-19, W-20, W-21, W-22, W-23 directly relevant)

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA.
Agent naming: System G / Invader Agent canon. Aegis REJECTED. agent_runtime_v2 in code.
Do not merge T-branches. Do not touch T5 paths.

Mission: T21 Vault Recall Contract / F-VaultRecall-50 — FOREVER LOOP.
Branch: codex/t21-vault-recall-contract-2026-05-18
Primary fix: agent_core/src/storage/vault.rs (Fix-B + Fix-C from diagnosis doc).
Plus: ChatCoordinator vault-context-injection seam, F-VaultRecall-50 fixture, Brain Panel "Retrieved by" surface.

PER-ITERATION CADENCE (build-first / test-later):
1. Re-read §4 T21 + F-VaultRecall-50 diagnosis. Don't drift.
2. Pick smallest canonical advancement: ONE fix lands OR ONE trace surface lands OR ONE fixture row added OR ONE diagnostic exposed.
3. Write a failing test FIRST that reproduces the failure mode you're about to fix.
4. Implement the canonical fix: Fix-B (set_conjunction_by_default(true) + stopword filter) or Fix-C (drop score.clamp(0,1)) or trace-emit code or Brain Panel surface code. No-compromise — never collapse the lexical+semantic+graph+recency+MMR trace into a simple ranked list.
5. Commit small with clear message ("fix(vault): Fix-B conjunction default + stopword filter" etc).
6. Repeat 1-5 for ~3-10 ticks (accumulate code changes).
7. THEN run narrow tests: `cargo test -p agent_core <vault-filter>`. Never --workspace. Never full xcodebuild unless a SwiftUI surface was touched.
8. Green: continue. Red: minimum fix only. Do not refactor adjacent code.
9. When acceptance bar met (no production retrieval path builds context from index-order LIMIT N + every retrieval emits lexical+semantic+graph+recency+MMR trace + UI shows loaded source titles+snippets + F-VaultRecall-50 fixture pass rate visible in Settings diagnostics + WRV: user reaches fix from chat, sees trace, trace cites actual loaded IDs): enter DEEP HARDENING only if truly super done.
10. DEEP HARDENING: edge cases (empty vault, unicode queries, rapid typing, high-token chatter, single-word queries, multi-paragraph queries, queries with only stopwords), property tests on trace structure, doc updates, cross-link W-19/W-20/W-21/W-22/W-23. After hardening pass, return to step 1 — find no-compromise nuances the diagnosis hints at but didn't enumerate. Loop forever.

SCOPE LOCK: agent_core/src/storage/vault.rs + ChatCoordinator vault-context-injection seam + F-VaultRecall-50 fixture + Brain Panel "Retrieved by" surface. Nothing else. No T5 paths. No T-branch merges. Cross-terminal needs → append W-row to docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md.

DISK PRESSURE: `cargo test -p agent_core <filter>` only. Never --workspace. No full xcodebuild unless Swift UI was actually touched this iteration. No cargo clean.

CANONICAL: The "first 7 irrelevant notes" failure must become structurally impossible. No-compromise > shortcuts. System G / Invader Agent canon.
```

### Terminal 3 — Codex — T17B Lattice / WBO Register (FOREVER LOOP)

```text
You are Codex working in /Users/jojo/Downloads/Epistemos. Follow AGENTS.md.

THIS IS A FOREVER LOOP. Iterate iter-1, iter-2, ... iter-N. Status-pulse every 10-20 iters. NEVER EXIT unless Jojo explicitly stops you.

Read docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md and docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md §3.5 (full forever-loop discipline).

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA, ~200 GB/s.
Agent naming: System G / Invader Agent canon. Aegis REJECTED. Code namespace: agent_runtime_v2.
No merging T-branches. T5 frozen: agent_core/src/research/{operator_ir,scan_ir,tropical_ir}/.

Mission: T17B Lattice / WBO Register — FOREVER LOOP.
Branch: codex/t17b-lattice-wbo-register-2026-05-18
Full spec: docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### T17B - Lattice / WBO Register".

Output:
- docs/LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md (preserves Lattice-Wyner-Ziv, LatticeCoder<BITS>, Babai/GPTQ, Sherry, ShadowKV, QuIP/E8, residual/sketch, WBO terms T_W/T_K/T_R/T_Q/T_S/T_SE/T_num, softmax-½ post-correction)
- agent_core/src/lattice_wbo/ (NEW) — lightweight types: LatticeBudget, LatticeCoderKind, LatticeErrorContribution, WboLedgerEntry, ActiveSupportBudget, SideInformationKind

PER-ITERATION CADENCE (build-first / test-later):
1. Re-read §4 T17B acceptance bar. Don't drift.
2. Pick smallest canonical advancement: ONE register row added OR ONE type implemented OR ONE cross-link added.
3. Implement no-compromise canonical content. Preserve every research nuance: Lattice-Wyner-Ziv unification, LatticeCoder<BITS> abstraction, Babai/GPTQ/nearest-plane interpretation, Sherry/ShadowKV/QuIP differences, Wyner-Ziv side-information. CRITICAL caveat: weight quant uses calibration Hessian, KV quant uses runtime Hessian — keep T_K separate from T_LWZ.
4. Write the unit test alongside (serialize/deserialize for new types). DO NOT run full build yet.
5. Commit small with clear message ("docs(lattice-wbo): map L1 Sherry residual to T_R term" etc).
6. Repeat 1-5 for ~3-10 iters.
7. THEN run narrow tests: `cargo test -p agent_core lattice_wbo`. Never --workspace.
8. Green: continue. Red: minimum fix.
9. When acceptance bar met (register doc + types + tests complete + every memory tier mapped to codec + codec to WBO term + WBO term to falsifier + caveats preserved): enter DEEP HARDENING only if truly super done.
10. DEEP HARDENING: property tests on budget composition, doc cross-links to MASTER_FUSION §3.2 / §3.4 / §3.8 / §3.16 / §3.18 and UNIFIED_ACTIVE_SUBSTRATE_CANON §2/§4/§5, ensure UAS references memory tiers without replacing them, edge cases (zero-budget, max-budget, mixed side-info kinds). After hardening pass, return to step 1 — find no-compromise nuances the canon expects. Loop forever.

SCOPE LOCK: docs + agent_core/src/lattice_wbo/ NEW. Do NOT implement heavy kernels. No T5 paths. No T-branch merges. Cross-terminal needs → W-row append.

DISK PRESSURE: `cargo test -p agent_core <filter>` only. No --workspace. No xcodebuild. No cargo clean.

CANONICAL: This is ACCOUNTING substrate, not a speed claim. No-compromise > shortcuts. Preserve every research nuance.
```

### Terminal 4 — Codex — T23B M2 Pro Falsifier Handbook (FOREVER LOOP)

```text
You are Codex working in /Users/jojo/Downloads/Epistemos. Follow AGENTS.md.

THIS IS A FOREVER LOOP. Iterate iter-1, iter-2, ... iter-N. Status-pulse every 10-20 iters. NEVER EXIT unless Jojo explicitly stops you.

Read docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md and docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md §3.5 (full forever-loop discipline).

Hardware floor (this terminal's subject): M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA, ~200 GB/s.
Agent naming: System G / Invader Agent canon. Aegis REJECTED.
No merging T-branches. T5 frozen.

Mission: T23B M2 Pro Falsifier Handbook — FOREVER LOOP.
Branch: codex/t23b-m2pro-falsifier-handbook-2026-05-18
Full spec: docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### T23B - M2 Pro Falsifier Handbook".

Output:
- docs/falsifiers/M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md
- tools/falsifiers/ stubs marked NOT IMPLEMENTED where scripts don't exist

Required falsifiers (each with purpose / current status / input fixture / pass threshold / failure meaning / fallback route / product lane / exact command / expected artifact):
F-Eidos-ClosedCitation, F-VaultRecall-50, F-PageGather-Baseline, F-PageGather-Scatter, F-UAS-CopyCount, F-ACS-AnchorLookup, F-InterruptScore-CPU, F-PacketRouter1bit, F-ControllerKernelPack, F-SemiseparableBlockScan, F-LocalRecallIsland, F-KV-Direct-Gate, F-WBO-DriftLedger, F-ULP-Oracle, F-70B-Local-Cocktail-Lite.

PER-ITERATION CADENCE (build-first / test-later):
1. Re-read §4 T23B acceptance bar. Don't drift.
2. Pick smallest canonical advancement: ONE falsifier row added OR ONE script stub created OR ONE cross-link added.
3. Write the row with no-compromise canonical accuracy. Mark NOT IMPLEMENTED where no script exists. Do NOT claim a gate passed unless repo evidence exists (check git log / cargo test output).
4. If adding a script stub: shebang + comment "NOT IMPLEMENTED — depends on <substrate>" + exit 1. NEVER run the stub (most depend on missing substrate).
5. Commit small with clear message ("docs(falsifiers): add F-PageGather-Baseline row" etc).
6. Repeat 1-5 for ~3-10 iters.
7. THEN batch-verify: re-read your last 3-10 rows for canonical accuracy + cross-link health. Confirm every "passed" claim has actual repo evidence (commit SHA / test output).
8. When all 15 falsifiers have rows + every claimed "passed" has repo evidence + handbook ranks run-first order (Eidos closed citation → PageGather baseline → UAS copy-count → F-ULP-Oracle → KV-Direct → SemiseparableBlockScan / LocalRecallIsland): enter DEEP HARDENING only if truly super done.
9. DEEP HARDENING: cross-link each falsifier to MASTER_FUSION rows, UNIFIED_ACTIVE_SUBSTRATE_CANON §5 sort, V6.2 falsifier order, prompt-deck T-IDs. Add risk register per falsifier. Add fallback-route detail.
10. After hardening pass, return to step 1 — find falsifiers the canon mentions that aren't yet in the handbook (helios v6.2 §V6_2_FALSIFIER_ORDER, MASTER_FUSION §3.16, prompt-deck §4 entries for T12/T13/T23). Loop forever.

SCOPE LOCK: docs/falsifiers/* + tools/falsifiers/ stubs only. No app code. No --workspace. No xcodebuild. No T-branch merges. Cross-terminal needs → W-row append.

DISK PRESSURE: docs + script stubs only. No builds. No tests.

CANONICAL: Do NOT claim any gate passed unless repo evidence exists. All unimplemented scripts marked NOT IMPLEMENTED explicitly. No-compromise > shortcuts.
```

## §5. Cohort B+C+D wrapper templates

Once Cohort A finishes, use these templates. Replace `<T-ID>`, `<short title>`, and `<branch-slug>` per the assignment table.

### Generic Claude wrapper (FOREVER LOOP)

```text
You are Claude Code working in /Users/jojo/Downloads/Epistemos. Obey AGENTS.md.

FIRST ACTION: invoke the `/loop` skill self-paced with this entire prompt as the body. Each `/loop` tick = one iteration of the §3.5 cadence. NEVER EXIT unless Jojo explicitly stops you.

Read once at session start:
1. docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md
2. docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md §3.5 (full forever-loop discipline + per-iteration cadence)
3. docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### <T-ID> - <short title>" (your acceptance bar)
4. Whatever else the §4 entry's "Read first" block names.

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA.
Agent naming: System G / Invader Agent canon. Aegis REJECTED. agent_runtime_v2 in code.
No merging T-branches. T5 frozen: agent_core/src/research/{operator_ir,scan_ir,tropical_ir}/.

Mission: <T-ID> (<short title>) — FOREVER LOOP.
Branch: codex/<branch-slug>-2026-05-18

Follow the §3.5 cadence strictly: build features first (steps 1-5), batch narrow tests at step 7 (never --workspace, never full xcodebuild if only Rust/docs changed), deep harden only when truly super done (step 9-10), then return to step 1 — acceptance bar is a floor, never a ceiling. Loop forever.

Scope lock: stay in your T-prompt's paths only. Cross-terminal needs → append W-row to docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md, continue inside scope.

Canonical: no-compromise > shortcuts. WRV > "it compiles". Preserve every research nuance.
```

### Generic Codex wrapper (FOREVER LOOP)

```text
You are Codex working in /Users/jojo/Downloads/Epistemos. Follow AGENTS.md.

THIS IS A FOREVER LOOP. Iterate iter-1, iter-2, ... iter-N. Status-pulse every 10-20 iters. NEVER EXIT unless Jojo explicitly stops you.

Read docs/CLAUDE_NO_COMPROMISE_SUBSTRATE_HANDOFF_2026_05_18.md and docs/CODEX_AND_CLAUDE_TERMINAL_DISPATCH_2026_05_18.md §3.5 (full forever-loop discipline + per-iteration cadence).

Hardware floor: M2 Pro 14" 2023, 12-core CPU, 19-core GPU, 16GB UMA.
Agent naming: System G / Invader Agent canon. Aegis REJECTED. agent_runtime_v2 in code.
No merging T-branches. T5 frozen: agent_core/src/research/{operator_ir,scan_ir,tropical_ir}/.

Mission: <T-ID> (<short title>) — FOREVER LOOP.
Branch: codex/<branch-slug>-2026-05-18
Full spec: docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md §4 "### <T-ID> - <short title>".

Follow the §3.5 cadence strictly: build features first (steps 1-5), batch narrow tests at step 7 (never --workspace, never full xcodebuild if only Rust changed), deep harden only when truly super done (step 9-10), then return to step 1 — acceptance bar is a floor, never a ceiling. Loop forever.

Scope lock: stay in your T-prompt's paths only. Cross-terminal needs → append W-row to docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md, continue inside scope.

Canonical: no-compromise > shortcuts. Preserve every research nuance.
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
