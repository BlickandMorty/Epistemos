# Stash Triage — 2026-06-21

Per `SESSION_CONTINUATION_PROMPT_2026_06_21.md` §⚠️ STASH TRIAGE and the owner's
"no WIP/stash hiding places" rule: every floating `git stash` is triaged here and
then **deliberately dropped**, so no forgotten WIP can silently regress the tree.

## Method (preserve-everything, then drop)
All 24 stashes were inspected (`git stash show -u`). Each stash's **real source/docs
diff** (tracked + untracked) was exported to `patches/stash-NN.patch`, **filtered to
exclude regenerable build artifacts** (`target/`, `*.rlib/.rmeta/.rcgu.o/.d`, vendored
KaTeX/mermaid fonts+bundles, the generated `Resources/Editor/editor.{js,css,html}`
bundle, and `artifacts/reliability/` + `artifacts/lattice-coordinate-explainer/`
generated data). These patches are the **durable record** — anything of value is
recoverable from them with `git apply` even after the stashes are dropped.

Four stashes (5, 8, 14, 15) were **pure build-artifact noise** (0 real files) and were
dropped **without** an archive patch — they carry zero IP and are 100% regenerable.

## Anti-drift note (owner 2026-06-21)
Every stash below is **pre-2026-06-19 WIP** from prior terminal/phase sessions whose
work landed via their own PRs. Per the anti-drift guard, these are **historical context
only** — they are NOT resurrected onto the current Osaurus-first walk. They are
preserved (durable patches) and dropped. No stash is applied onto `main`. Stashes that
touch the chat surfaces (10, 20, 22) are preserved, never applied — honoring the
chat-quarantine guard. Individual "already-landed vs. superseded" status was NOT
re-verified file-by-file (that would be the pre-06-19 rabbit hole the guard forbids);
the patch archive is the safety net if a later porting cycle wants a specific change.

## Per-stash classification + decision

| # | Subject | Real content | Decision |
|---|---------|--------------|----------|
| 0 | docs/canon-chronicle 2026-06-03 | `CANONICAL_CHRONICLE_2026_05_23.md` (chronicle doc) | archived → **drop** |
| 1 | terminal-e ACS-gate fragments | 4 ACS-admission audit docs | archived → **drop** |
| 2 | terminal-d r2 fragments | `EidosBridge.swift` (1-line) + substrate-health doc | archived → **drop** |
| 3 | terminal-d r3 fragments | dup of #2 | archived → **drop** |
| 4 | b-prime followup 2026-05-26 | 131 files: AmbientFrequency, settings/landing views, tests, js-editor | archived (source only) → **drop** |
| 5 | D-prime syntax-core build churn | **0 real files** (build artifacts) | **drop, no archive** |
| 6 | terminal-e rev2 docs | dup of #1 (ACS docs) | archived → **drop** |
| 7 | terminal-e pre-main rev2 | `EidosBridge.swift` + 2 vault-recall audit docs | archived → **drop** |
| 8 | tree-sitter build churn | **0 real files** (build artifacts) | **drop, no archive** |
| 9 | wip-pre-rebase (terminal-e) | ACS-admission Swift+Rust source + tests (r5_acs_tool_handoff) | archived → **drop** |
| 10 | preserve-wip merge-wave | chat WIP (ChatCoordinator/MessageBubble/MiniChat/NoteChatSidebar) + docs | archived (preserve, never applied — chat quarantine) → **drop** |
| 11 | auto-stash ff-pull | settings health-rows + providers (`openai.rs`) WIP (47 files) | archived → **drop** |
| 12 | t12 eml_ir | `witness.rs` (23 lines) | archived → **drop** |
| 13 | t11 agent-runtime PRE-CURSOR-HANDOFF | `capability.rs` (62 lines) | archived → **drop** |
| 14 | t2-agent PRE-REMOVAL | **0 real files** (build artifacts) | **drop, no archive** |
| 15 | t1-trifusion PRE-REMOVAL | **0 real files** (build artifacts) | **drop, no archive** |
| 16 | runB PRE-REMOVAL | `a2ui/accordion.rs` + `carousel.rs` | archived → **drop** |
| 17 | multi-terminal recovery | `acs_admission/mod.rs` (300) + `lib.rs` + handbook doc | archived → **drop** |
| 18 | t17b lattice-format | `lattice_wbo/mod.rs` (6 lines) | archived → **drop** |
| 19 | graph-filters/expansion | graph physics (engine/forces/simulation.rs) + Swift + tests | archived → **drop** |
| 20 | W9.21 PR4 + W9.8 partial | shadow `honest_handle.rs` + chat + CRITIQUE_LOG (source only) | archived (preserve, never applied) → **drop** |
| 21 | parallel-during-landing-wave | landing-wave + graph inspector views (15 files) | archived → **drop** |
| 22 | wip-multi-terminal-recovery | project.pbxproj + AgentCommandCenter/Notes/Graph views (72 files) | archived (preserve, never applied) → **drop** |
| 23 | invisible-text editor fix | `EpistemosTheme.swift` + `CodeEditorView.swift` (isRichText) | archived (not re-verified vs current main) → **drop** |

## Outcome
After this triage: **0 stashes remain.** Unfinished work going forward is a canon
commit or an explicit ledger item — never a floating stash.
