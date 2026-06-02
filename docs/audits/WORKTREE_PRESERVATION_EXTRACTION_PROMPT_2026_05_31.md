# Worktree Preservation Extraction Prompt

Use this prompt from `/Users/jojo/Downloads/Epistemos` when the goal is to
mine preserved worktrees for useful code, docs, tests, or research without
deleting, cleaning, or wholesale-merging them.

## Mission

Audit preserved donor worktrees one at a time. Extract only current-compatible
value into the active Epistemos worktree:

- one small code hunk;
- one test;
- one source guard;
- one doc row;
- one falsifier axis;
- one research intake note;
- or one proof that a donor surface is already absorbed/superseded.

Do not merge an entire branch. Do not delete a worktree. Do not clean generated
`target/` churn. Do not edit Xcode project files unless explicitly asked.

## Required Reading

1. `AGENTS.md`
2. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
3. `docs/audits/WORKTREE_SAFE_MERGE_DRY_RUN_2026_05_30.md`
4. `docs/audits/WORKTREE_SALVAGE_QUEUE_2026_05_29.md`
5. `docs/audits/NEXT_SESSION_WORKTREE_SALVAGE_PROMPT_2026_05_30.md`
6. `docs/audits/NON_RUNTIME_FEATURE_WORKTREE_CHECK_2026_05_30.md`
7. `docs/audits/UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.md`
8. `docs/audits/FULL_ARCHITECTURE_CONTINUATION_PROMPT_2026_05_31.md`
9. `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
10. `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`

## Non-Negotiables

- Preserve every worktree unless the user explicitly approves removal.
- No `git merge`, no cherry-pick, no checkout/reset of current files.
- Use non-mutating analysis first: `git diff --name-status`, `git diff`,
  `git merge-base --is-ancestor`, `git merge-tree`, `rg`, `sed`, `git show`.
- Mine only a named missing field, missing guard, missing test, missing doc
  row, or missing research idea.
- If current code is newer/stricter, record `superseded` and do not port.
- If the donor would remove UAS, AcsAnchor projection fields, SCOPE-Rex /
  SovereignGate gates, Eidos route-prior guards, AppColdStore active-byte
  admission, ProductBuild/ProStatus, WBO, RunEventLog, AnswerPacket, rollback,
  or falsifier witnesses, skip it.
- Keep UAS as primitive. EML is one Primitive-IR chart, not the substrate.
- Keep ColdStore/AppColdStore for residency. Do not revive `ACS` as Active
  Cold Storage or admission shorthand.
- Keep Eidos as evidence/search/citation and route-prior selector; do not
  create `AgentSearch`, `AgentMemory`, `AgentEvidence`, or `AgentCitation` as
  separate authorities.
- Keep ResidencyPatternBoost as an offline/idle discovery and distillation
  layer. Donor worktrees may contribute genomes, repair kernels, fingerprints,
  trace frames, or falsifier axes, but they must not install an ungoverned live
  param router or mutate route policy without replay, abstention, rollback, and
  witness fields.
- Do not run heavy probes: no 70B, no 128K, no full Xcode, no live MLX/GGUF,
  no mmap/SSD stress.

## Worktree Classes

### Cleanup Candidates Only After Explicit Approval

Do not remove during extraction work.

- `/Users/jojo/Downloads/Epistemos-wrv-app`
- `/Users/jojo/Downloads/Epistemos-wrv-rust`

Detached preservation-only:

- `/Users/jojo/Downloads/Epistemos-wrv-audit`

### Highest-Value Preserved Donors

Mine these with surgical diffs only:

| Worktree | Default value to inspect |
|---|---|
| `/Users/jojo/Downloads/Epistemos-t4-vault` | VaultRecall-50, RRF fusion, exact/Unicode matching, retrieval traces, Rust vault retrieval. |
| `/Users/jojo/Downloads/Epistemos-wave4-page-gather-vault-escalation` | PageGather vault escalation trace and schedule fields. |
| `/Users/jojo/Downloads/Epistemos-terminal-a` | Eidos real vault binding and citation/evidence bridge. |
| `/Users/jojo/Downloads/Epistemos-terminal-c` | System G full path, runtime registry, mission/run seam. |
| `/Users/jojo/Downloads/Epistemos-terminal-t1-runtime-router` | RuntimeExecutor / RuntimeRouter / F-LocalToolUse ideas. |
| `/Users/jojo/Downloads/Epistemos-terminal-s` | Hyperdynamic schema/repair loop. |
| `/Users/jojo/Downloads/Epistemos-terminal-d` | Substrate health rows and WRV truth floor. |
| `/Users/jojo/Downloads/Epistemos-t2-agent` | Local-agent diagnostics, answer packets, tool grammar, model selection/provider discipline. |
| `/Users/jojo/Downloads/Epistemos-t5-emlir` | Primitive IR / EML / Geometry / Info / Operator research stack; extract only falsifier-shaped or doc-indexable items. |
| `/Users/jojo/Downloads/Epistemos-t6-uiux` | UI/UX audit and polish; avoid old shells and project-file churn. |

### Claude Donors

Preserve. Audit as donor branches, not cleanup targets.

| Worktree | Default value to inspect |
|---|---|
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/agent-a0550f9c` | Honest-handle WIP; locked by Claude. |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation` | Simulation/companion/Hermes-lineage donor. |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/vigorous-goldberg-3a2d35` | Quick Capture, first-run bootstrap, tool trait, cache, browser engine. |

## Preferred Extraction Order

1. Reconfirm active worker/worktree state.
2. Pick exactly one donor theme from the table.
3. Run non-mutating diff against current head.
4. Classify each candidate hunk:
   - `already_absorbed`;
   - `superseded_by_current_truth_floor`;
   - `unsafe_broad_merge`;
   - `useful_additive_patch`;
   - `research_only`;
   - `needs_user_decision`.
5. If there is a useful additive patch, port it manually into current source
   with `apply_patch`, following current code style.
6. Add or update a focused test/falsifier/doc guard.
7. Run lightweight verification:
   - `git diff --check`;
   - focused cargo/Swift source guard only for touched code;
   - no heavy runtime.
8. Commit the small extraction.
9. If no code is safe, commit a concise audit note only if it materially
   updates the salvage ledger; otherwise leave no commit.

## Current Best First Targets

Prefer one of these:

1. `Epistemos-t4-vault`: prove the remaining T4 unique-value question is
   absorbed or port one additive retrieval test/hunk.
2. `Epistemos-terminal-a`: compare old Eidos bridge with current
   `EidosRoutePrior` and AppColdStore route-card binding; port only missing
   citation/evidence guardrails.
3. `Epistemos-terminal-c` or `Epistemos-terminal-t1-runtime-router`: extract a
   non-executing System G / RuntimeRouter manifest or source guard.
4. `.claude/worktrees/vigorous-goldberg-3a2d35`: extract only tool/cache/browser
   ideas that map to System G, RuntimeRouter, RunEventLog, AnswerPacket, or
   Eidos; do not revive obsolete subprocess architecture.

## Report Format

End every worker run with:

```text
Inspected donor:
Compared paths:
Ported:
Skipped as absorbed:
Skipped as superseded:
Verification:
Commit:
Next donor:
```
