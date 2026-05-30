# Worktree Salvage Queue — 2026-05-29

Status: audit / preservation queue. No worktree was removed. No branch was
merged by this audit.

Terminology used here:

- UAS = Unified Address Space.
- ACS = Anchored Cognitive Substrate.

## Rule

Do not delete Epistemos sibling folders just because they look duplicated.
Classify them first:

1. Clean + graph-merged into current/origin: removable only after user confirms
   no local data is needed.
2. Clean + unmerged: preserve; inspect and cherry-pick or merge deliberately.
3. Dirty + unmerged: preserve; separate build-artifact churn from real edits.
4. Dirty + graph-merged: likely cleanup candidates, but still preserve until
   generated target churn is handled.
5. Non-git backups: never delete automatically.

## Inventory Snapshot

Source:

```text
docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json
```

Summary:

- candidates: 40
- sibling git worktrees: 34
- dirty candidates: 24
- high duplicate risk: 24
- non-git candidates: 5
- current repo dirty count at scan time: 0 before the generated inventory file
  was refreshed

2026-05-30 refresh: `Tools/audits/epistemos_worktree_inventory.sh` was rerun
from the current repo at `6557488793a6`. No folder was removed. The cleanup
posture remains preserve-first because multiple sibling worktrees still contain
unique commits or small real docs, even though most "dirty" counts are generated
`target/` artifact churn.

## Clean And Graph-Merged

These are the only sibling git worktrees that looked clean and already merged
into current `HEAD` and `origin/main` at scan time. They are the first
removal candidates, but only after explicit user approval.

| Worktree | Branch / state | Head |
|---|---|---|
| `/Users/jojo/Downloads/Epistemos-wrv-app` | `wiring/app-systemg-run-seam-2026-05-23` | `3c8a1e7f63dc` |
| `/Users/jojo/Downloads/Epistemos-wrv-audit` | detached | `24b5052cf2ea` |
| `/Users/jojo/Downloads/Epistemos-wrv-rust` | `wiring/rust-r3-system-g-minimal-slice` | `1dd733982451` |

## Clean But Unmerged

These have no dirty working tree, but their branch heads are not ancestors of
current `HEAD` or `origin/main`.

| Worktree | Branch | Patch status | Salvage note |
|---|---|---|---|
| `/Users/jojo/Downloads/Epistemos-terminal-d-prime` | `phase2-terminal-d-prime-health-rows-2026-05-24` | patch-equivalent (`git cherry` showed `-`) | likely superseded; verify health-row truth-floor changes before removal |
| `/Users/jojo/Downloads/Epistemos-terminal-f-prime` | `phase2-terminal-f-prime-falsifiers-r2-2026-05-24` | unique (`+`, 7 commits) | preserve; contains Round 2 falsifier harness/artifact work |
| `/Users/jojo/Downloads/Epistemos-terminal-t1-runtime-router` | `phase2-terminal-t1-runtime-router-2026-05-24` | unique (`+`, 8 commits) | preserve; RuntimeExecutor / RuntimeRouter / F-LocalToolUse work |
| `/Users/jojo/Downloads/Epistemos-ui-repromotion` | `codex/repromote-ui-wip-2026-05-26` | patch-equivalent (`-`) | likely superseded; verify UI repromotion deltas before removal |
| `/Users/jojo/Downloads/Epistemos-wave4-page-gather-vault-escalation` | `codex/wave4-page-gather-vault-escalation-2026-05-26` | unique (`+`, 1 commit) | preserve; PageGather vault escalation trace may still need landing |
| `/Users/jojo/Downloads/Epistemos-wave4-uas-typed-retrieval` | `codex/wave4-uas-typed-retrieval-2026-05-26` | patch-equivalent (`-`) | likely superseded; verify typed UAS retrieval/claims before removal |
| `/Users/jojo/Downloads/Epistemos-wrv-salvage` | `salvage/t6-uiux-status-2026-05-23` | unique (`+`, 1 commit) | docs-only status; preserve until copied or intentionally dropped |

2026-05-30 update: the docs-only T6 status was ported into
`docs/T6-UIUX-STATUS-2026-05-23.md`. This does not mean the T6 UI/UX branch is
merged; it records the opposite, namely that broad T6 code mining is deferred
because the branch is old and modification-heavy.

Dry-run merge detail is now tracked in
`docs/audits/WORKTREE_SAFE_MERGE_DRY_RUN_2026_05_30.md`. Current result:
`wrv-app` and `wrv-rust` need no merge; every other clean useful branch should
be manually ported, not wholesale-merged.

2026-05-30 current-checkpoint update: a second non-mutating merge sweep at
`6557488793a6` found zero missing files across the clean-but-divergent donor
branches. The remaining differences are divergent hunks in files current main
already owns. Direct merge would conflict for D-prime, F-prime, T1,
UI-repromotion, Wave4 PageGather, and Wave4 UAS typed retrieval. Current code is
newer on the important truth surfaces: F-prime now has full-scope falsifiers
instead of the older scoped mini-harnesses, D-prime health rows preserve orange
partial states, PageGather traces carry UAS/schedule fields, and W-03 ACS
ledger reads are partial rather than overclaimed.

2026-05-30 update: the first T5 EML/IR code slice was ported manually from
`codex/t5-emlir-2026-05-16`: EML closure typestate, closure builders,
normalization, Lean-certificate string emitters, and four focused integration
tests. This is **not** a whole-branch merge; T5 remains a donor reference for
Lean files, research custody files, and any still-unmined IR work.

2026-05-30 update: the T5 Lean schema / research-custody slice was also
ported additively. Primitive-IR Lean files are now present and import-wired
without importing existing H/PCF side stubs. `lakefile.lean` was patched for
the pinned Lean 4.16 syntax, but the local mathlib cache fetch failed with a
dyld cache-binary error, so this is preserved schema work rather than a green
Lean proof gate.

2026-05-30 update: the missing T4 Shadow-first retrieval contract module was
ported to `agent_core/src/retrieval/mod.rs` and exposed in `agent_core/src/lib.rs`.
Only the Rust contract surface was copied. Donor Swift tests, ignored local
vault baseline tests, old UI, and project files remain unmerged.

2026-05-30 update: the W-03 ACS ClaimLedger bridge was hardened in current
code without a branch merge. `ClaimLedger` now exposes deterministic
`claim_acs_anchor`, `anchored_claims`, and `claims_for_acs_theorem` read
surfaces. Focused Rust verification: `cargo test --manifest-path
agent_core/Cargo.toml provenance::ledger:: --lib` passed 31/31.

2026-05-30 update: old donor Mermaid live-diagram files were deliberately
skipped. Current source guards require the inert legacy diagram / HTML
Workspace replacement route, and reintroducing donor Mermaid would risk the
Epdoc `graph TD` typing glitch the user reported.

2026-05-30 follow-up: Wave4 UAS typed retrieval was rechecked with
`git merge-base --is-ancestor`, `git merge-tree`, and file-level UAS diffs.
It remains a surgical donor only. Current already has donor `UasKind::Claim`
and `AcsAnchor: Eq`, while the donor would remove current
`AcsAnchorPlaneProjection` read fields. No donor hunk was ported. Instead, the
current non-runtime planner was hardened so compressed/lattice
`WeightBlockManifest` entries cannot satisfy the dense rollback gate with a
non-`ModelComponent` UAS address.

## Dirty But Mostly Generated Churn

Many old worktrees report 2955 dirty files, almost entirely tracked build
artifacts under:

```text
substrate-core/target
syntax-core/target
```

This dirt is not valuable product work. It should still not be destructively
discarded until the branch-level salvage is complete.

Examples:

- `/Users/jojo/Downloads/Epistemos-t09-product-ledger`
- `/Users/jojo/Downloads/Epistemos-t10-eidos`
- `/Users/jojo/Downloads/Epistemos-t11-agent-runtime-v2`
- `/Users/jojo/Downloads/Epistemos-t12-f-ulp`
- `/Users/jojo/Downloads/Epistemos-t17b-lattice-wbo-register`
- `/Users/jojo/Downloads/Epistemos-t18b-acs-admission-field`
- `/Users/jojo/Downloads/Epistemos-t21-vault`
- `/Users/jojo/Downloads/Epistemos-t23b-m2pro-falsifier-handbook`
- `/Users/jojo/Downloads/Epistemos-wirings-2026-05-23`

These heads are graph-merged, but dirty target churn prevents clean removal
without an explicit cleanup step.

## Dirty And Unmerged — Preserve

These are important because they have unique branch commits and dirty target
churn. Do not remove until the unique commits are compared against current
code.

| Worktree | Branch | Unique commits | Main theme |
|---|---|---:|---|
| `/Users/jojo/Downloads/Epistemos-t2-agent` | `codex/t2-agent-2026-05-16` | 38 | local-agent diagnostics, answer packets, tool grammar, model selection |
| `/Users/jojo/Downloads/Epistemos-t4-vault` | `codex/t4-vault-2026-05-16` | 144 | VaultRecall-50, RRF fusion, retrieval traces, Rust vault retrieval |
| `/Users/jojo/Downloads/Epistemos-t5-emlir` | `codex/t5-emlir-2026-05-16` | 961 | EML/Geometry/Info/Operator IR research stack |
| `/Users/jojo/Downloads/Epistemos-t6-uiux` | `codex/t6-uiux-2026-05-16` | 38 | UI/UX audits and fixes |
| `/Users/jojo/Downloads/Epistemos-terminal-a` | `terminal/a-eidos-bridge-2026-05-23` | 2 | Eidos real vault binding, citation gate |
| `/Users/jojo/Downloads/Epistemos-terminal-c` | `terminal/c-system-g-full-path-2026-05-23` | 7 | System G run seam and runtime registry |
| `/Users/jojo/Downloads/Epistemos-terminal-d` | `phase2-terminal-d-substrate-health-wrv-2026-05-24` | 1 | unified substrate health panel |
| `/Users/jojo/Downloads/Epistemos-terminal-f` | `phase2-terminal-f-falsifiers-m2pro-2026-05-23` | 1 | patch-equivalent first falsifier bundle; verify before removal |
| `/Users/jojo/Downloads/Epistemos-terminal-g` | `phase2-terminal-g-t14-uas-no-orphan-2026-05-24` | 1 | patch-equivalent UAS no-orphan bridge; verify before removal |
| `/Users/jojo/Downloads/Epistemos-terminal-s` | `phase2-terminal-s-hyperdynamic-loop-2026-05-24` | 8 | hyperdynamic/schema repair loop |
| `/Users/jojo/Downloads/Epistemos-terminal-t0` | `phase2-terminal-t0-verified-floor-2026-05-24` | 1 | patch-equivalent verified-floor chips; verify before removal |

## Worktrees With Small Real Dirty Docs

`/Users/jojo/Downloads/Epistemos-terminal-e` is graph-merged but has real dirty
doc edits in addition to generated target churn:

- `docs/audits/ACS_ADMISSION_PRODUCTION_GATE_2026_05_24.md`
- `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md`
- `docs/audits/DECISION_NEEDED_ACS_ANCHOR_ADDRESSING_2026_05_24.md`

`/Users/jojo/Downloads/Epistemos-wrv-docs` is graph-merged but has one
untracked doc:

- `docs/CANONICAL_CHRONICLE_2026_05_23.md`

Preserve these until the docs are copied, intentionally dropped, or merged.

## Claude Worktrees

Do not delete these from the filesystem. They are not safe cleanup candidates.

| Worktree | Branch | Unique commits | Note |
|---|---|---:|---|
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/agent-a0550f9c` | `codex/recovery-claude-shadow-handle-2026-05-26` | 1 | locked by Claude; preserves honest-handle WIP |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/simulation` | `worktree-simulation` | 17 | simulation/Hermes/landing/notes sidebar work |
| `/Users/jojo/Downloads/Epistemos/.claude/worktrees/vigorous-goldberg-3a2d35` | `claude/vigorous-goldberg-3a2d35` | 55 | Quick Capture, first-run bootstrap, tool trait, cache, browser engine |

## Non-Git Folders

These need manual backup/archive classification before deletion:

- `/Users/jojo/Downloads/Epistemos-live-data-backup-20260401-191422`
- `/Users/jojo/Downloads/Epistemos-live-data-backup-20260401-191440`
- `/Users/jojo/Downloads/epistemos-public`
- `/Users/jojo/Downloads/Epistemos-safety-backup-20260401-183510`
- `/Users/jojo/Downloads/EPISTEMOS_HELIOS_MASTER_ARCHIVE_2026_05_05_PRESERVATION_BUNDLE`

## Recommended Salvage Order

1. Freeze current worktree changes in logical commits before any cleanup.
2. Preserve or port the clean unique branches first:
   - Terminal F prime falsifiers
   - Terminal T1 runtime router
   - Wave4 PageGather vault escalation
   - WRV salvage docs
3. Compare dirty unique branches after ignoring target churn:
   - T2 agent
   - T4 vault
   - T5 EML/IR
   - T6 UI/UX
   - Terminal A Eidos
   - Terminal C System G
   - Terminal D substrate health
   - Terminal S hyperdynamic loop
4. Inspect Claude worktrees as donor branches, not cleanup targets.
5. Only after salvage is complete, remove clean merged worktrees with
   `git worktree remove`, never by manually dragging random folders to trash.

## Non-Runtime Feature Check - 2026-05-30

Safe, non-runtime hardening that is already represented in the current repo:

- schema-normalized falsifier artifacts and the shared artifact validator;
- `F-WeightBlockRangeHash-DryRun` for bounded model-byte range manifests;
- `F-ResidencyPlan-DryRun` for deterministic active-set planning over a
  model-shaped cold body without loading model bytes;
- `F-ProviderReferenceManifest-DryRun` for the prompt-suite-bound reference ABI;
- `F-70B-Local-Cocktail-Lite` as an honest red preflight consuming the safe
  planner rungs while refusing to pretend live 70B works;
- `F-Architecture-Pending-Work-Guard`, which now checks those rungs plus the
  worktree/model-context inventories before any recursive architecture loop.
- Eidos W-49 and W-50 Rust substrates are already in the current tree:
  `LedgerBackedClaimEvidence` and `DagBackedGraphNeighborhood` pass the
  closed-citation test surface. Terminal A remains a donor reference, not a
  merge target, because the useful Rust pieces are already represented and the
  branch would roll back newer runtime/app files.

Preserve these worktree families before deleting anything because they map to
the user's non-runtime architecture surface:

1. T5 EML / Geometry / Info / Operator IR stack.
2. T17b lattice / WBO register path.
3. T18b ACS admission field.
4. Terminal S hyperdynamic/schema repair loop.
5. Terminal D substrate health rows.
6. Terminal A Eidos citation/evidence bridge.
7. Terminal C System G and Terminal T1 runtime router.
8. T2 local-agent diagnostics / model-selection discipline.
9. T4 VaultRecall and Wave4 PageGather vault escalation.

Still not proven by the non-runtime surface:

- live 70B generation;
- SSD-backed sparse-active 70B decode;
- live MLX/GGUF local-agent streaming through System G;
- dense PageGather primary bandwidth;
- live 128K KV-Direct residual-patched mmap/NF4 spill.

Those remain runtime gates and should not be launched again until the heavy-run
guard, provider reference, and crash-safe harness policy are explicit.

## Critical-Path Reality Check

The 70B / mmap / SSD-resident-model ambition is present in canon and must not
be dropped. It is also not yet a finished runtime in the current tree.

Current local evidence:

- `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` defines the
  70B local cocktail as the user's end-game vision: 70B weights on SSD,
  sparse-active subsets awake in UMA, and F-70B-Local-Cocktail as the gate.
  The same section marks the composed 70B system as conjectural until the gate
  passes.
- `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` also marks
  F-KV-Direct-Gate as the memory-floor experiment and explicitly says the
  end-to-end harness is not started in that doc.
- `agent_core/src/bin/falsify_uas_zero_copy_spine.rs` is an honest fallback
  witness: it measures only the in-process Rust provenance path and records the
  Swift / Metal / MLX / IOSurface paths as unmeasured anomalies.
- `agent_core/src/bin/falsify_agent_local_model_runtime_bridge.rs` has since
  been promoted from the old red state to a guarded primary witness for the
  local bridge seam. The artifact proves catalog selection, guarded local
  client construction, streamed token chunks, and local-model provenance on the
  safe Qwen3-8B MLX route. It does **not** prove the 128K/70B/SSD-resident
  runtime.
- `agent_core/src/bridge.rs` exposes System G provider-aware start and now has a
  guarded local-model bridge path; the next hard gate remains the
  Qwen3-8B-128K GGUF / repair stall, not another unsafe 70B probe.

Salvage implication: prioritize branches that contain the missing runtime
bridge and measurement pieces before deleting anything that looks duplicated:

1. Terminal T1 runtime router and Terminal C System G run seam.
2. T2 local-agent diagnostics / model selection.
3. Wave4 PageGather vault escalation and T4 VaultRecall.
4. T5 EML / Geometry / Info / Operator IR stack.
5. Terminal A Eidos, Terminal S hyperdynamic loop, and Terminal D substrate
   health rows.

This keeps the no-compromise path intact while preserving honesty: current
Epistemos has scaffolds and several real witnesses, but the SSD-backed 70B
runtime still needs the live mmap / MLX / IOSurface / sparse-active harness.
