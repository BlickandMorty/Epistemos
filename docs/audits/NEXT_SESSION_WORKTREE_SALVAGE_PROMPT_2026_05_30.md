# Next Session Prompt - Worktree Salvage and Runtime Hardening

Use this prompt to continue from the current safe point without losing work,
bulk-merging stale branches, or rerunning heavy probes.

```text
Continue the Epistemos worktree salvage and runtime-hardening loop from
/Users/jojo/Downloads/Epistemos.

Start by reading AGENTS.md and obeying it exactly. Then read these local canon
and audit files before changing anything:

1. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
2. docs/audits/WORKTREE_SAFE_MERGE_DRY_RUN_2026_05_30.md
3. docs/audits/WORKTREE_SALVAGE_QUEUE_2026_05_29.md
4. docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json
5. docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json

Current safe checkpoint:

- branch: codex/inline-tool-loop-transcript-2026-05-27
- current audited commit: 57e507428898
- pre-salvage tag: checkpoint/pre-worktree-merge-salvage-2026-05-30-6557488793

Safety rules:

- Do not run 70B, 128K, full Metal witness, mmap/SSD stress, live MLX/GGUF
  heavy probes, or any command likely to pressure memory until a crash-safe
  harness is explicitly implemented and approved.
- Do not delete any worktree or sibling Epistemos-like folder without explicit
  user approval.
- Do not touch ~/Epistemos-RETRO/, src-tauri/, or ~/meta-analytical-pfc/.
- Do not wholesale merge clean-but-divergent donor branches. Use non-mutating
  checks first: git merge-tree, git diff --name-status, git merge-base
  --is-ancestor, and file-level diffs.
- Do not treat file existence, docs rows, branch-local code, or fixtures as a
  product ship claim. Preserve WRV: Wired, Reachable, Visible, Verified.
- If a donor would remove stricter current truth-floor fields, skip it and
  record why.

Known worktree state from the last audit:

- Graph-merged/no-merge-needed cleanup candidates, only after approval:
  - /Users/jojo/Downloads/Epistemos-wrv-app
  - /Users/jojo/Downloads/Epistemos-wrv-rust
- Detached preservation-only:
  - /Users/jojo/Downloads/Epistemos-wrv-audit
- Clean divergent donor branches that must remain surgical-only:
  - phase2-terminal-d-prime-health-rows-2026-05-24
  - phase2-terminal-f-prime-falsifiers-r2-2026-05-24
  - phase2-terminal-t1-runtime-router-2026-05-24
  - codex/repromote-ui-wip-2026-05-26
  - codex/wave4-page-gather-vault-escalation-2026-05-26
  - codex/wave4-uas-typed-retrieval-2026-05-26
- Most dirty worktrees are generated target churn. Filter dirty status through
  target/build-artifact exclusions before concluding real source changes exist.

Suggested next work, in order:

1. Verify the repo is clean.
2. Run Tools/audits/epistemos_worktree_inventory.sh and inspect only the diff.
3. Re-run the source/doc dirty filter for sibling worktrees, ignoring target/
   and build artifacts.
4. Pick one small donor surface and either:
   - prove it is already absorbed by current code, or
   - port one additive, low-risk file/hunk with a focused test.
5. Prefer safe runtime-hardening surfaces over docs-only work:
   - ResidencyPlan / WeightBlockManifest guardrails.
   - local model bridge provenance and failure honesty.
   - System G guarded routes that do not launch heavy inference.
   - ACS/UAS read surfaces that are pure Rust and testable with focused cargo
     unit tests.
6. If no code is safe to port, update the salvage docs with exact reasons and
   leave the repo clean.
7. Run only lightweight verification:
   - git diff --check
   - focused cargo tests for touched Rust modules only
   - no Xcode/full-app/heavy Metal/model tests unless explicitly requested.
8. Commit the salvage checkpoint before ending.

Current truth:

- The 70B/SSD-resident/UAS local-model ambition remains core canon, but it is
  not proven. The safe path is ResidencyPlan over WeightBlockManifest first,
  then guarded dry-run witnesses, then crash-safe harnesses, then measured
  runtime probes.
- The local model bridge has a guarded primary witness on the safe Qwen3-8B MLX
  route, but the 128K/70B/GGUF SSD-resident capability remains pending.
- Current clean divergent donors have no missing files; remaining differences
  are divergent hunks in files main already owns.

End with a concise report: what was inspected, what was ported or skipped, what
verification ran, whether the repo is clean, and which worktree/folder is next.
```

## Last Session Notes

- `git worktree prune --dry-run` returned no stale worktree metadata.
- No worktrees were deleted.
- No wholesale merge was attempted.
- No heavy model, mmap, Xcode, or Metal probe was run.
- The live worktree inventory was refreshed at `57e507428898`.
