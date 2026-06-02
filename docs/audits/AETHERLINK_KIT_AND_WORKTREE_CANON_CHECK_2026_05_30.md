---
state: audit_no_delete
created_on: 2026-05-30
scope: AetherLink kit intake plus Epistemos sibling worktree cleanup safety
posture: preserve first; delete only after merged/clean/approved evidence
---

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

# AetherLink Kit And Worktree Canon Check - 2026-05-30

## AetherLink Kit

Found:

```text
/Users/jojo/Downloads/AETHERLINK_APPLICATION_KIT_FULL
/Users/jojo/Downloads/AETHERLINK_APPLICATION_KIT_FULL.zip
```

Contents include the application packet PDFs/DOCX files plus
`AETHERLINK_APPLICATION_PROJECT/` with docs, schemas, Python demos, Rust
scaffold, Metal stubs, and Lean skeleton.

Decision:

- Keep the kit.
- Do not delete or move it during Epistemos cleanup.
- Do not raw-copy its runtime code into the app target.
- Intake the doctrine through
  `docs/fusion/AETHERLINK_OAS_CANON_INTAKE_2026_05_30.md`.

## Worktree Cleanup Rule

No folder should be deleted merely because it looks duplicated. Cleanup is
allowed only when all of these are true:

1. current Epistemos working tree has been committed or deliberately preserved;
2. the candidate folder is a git worktree, not a backup/archive;
3. its working tree is clean;
4. its branch is merged, patch-equivalent, or explicitly recorded as dropped;
5. no untracked docs or artifacts are present;
6. the user explicitly approves deletion/removal;
7. removal uses `git worktree remove` for git worktrees, not manual `rm -rf`.

## Current Inventory Summary

Source:

```text
docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json
docs/audits/WORKTREE_SALVAGE_QUEUE_2026_05_29.md
```

Snapshot:

- 40 Epistemos-looking candidates under Downloads.
- 34 sibling git worktrees.
- 25 dirty candidates.
- 24 high duplicate-risk surfaces.
- 5 non-git candidates.

## First Removal Candidates, After Approval Only

These were previously classified as clean and graph-merged. They are the
earliest candidates, but still require user approval:

| Folder | Reason it may be removable |
|---|---|
| `/Users/jojo/Downloads/Epistemos-wrv-app` | clean, graph-merged |
| `/Users/jojo/Downloads/Epistemos-wrv-audit` | clean, graph-merged detached worktree |
| `/Users/jojo/Downloads/Epistemos-wrv-rust` | clean, graph-merged |

## Preserve For Salvage

These should not be deleted until their unique commits and dirty surfaces are
compared against current main/current working tree:

| Folder | Preserve reason |
|---|---|
| `/Users/jojo/Downloads/Epistemos-t2-agent` | local-agent diagnostics, answer packets, tool grammar, model selection |
| `/Users/jojo/Downloads/Epistemos-t4-vault` | VaultRecall, RRF, retrieval traces, Rust vault retrieval |
| `/Users/jojo/Downloads/Epistemos-t5-emlir` | EML / Geometry / Info / Operator / IR research stack |
| `/Users/jojo/Downloads/Epistemos-t17b-lattice-wbo-register` | lattice/WBO register path; directly relevant to weight lattice ambition |
| `/Users/jojo/Downloads/Epistemos-t18b-acs-admission-field` | legacy path for SCOPE-Rex admission field + AcsAnchor link |
| `/Users/jojo/Downloads/Epistemos-terminal-c` | System G run seam |
| `/Users/jojo/Downloads/Epistemos-terminal-t1-runtime-router` | RuntimeExecutor / RuntimeRouter / local tool use |
| `/Users/jojo/Downloads/Epistemos-wave4-page-gather-vault-escalation` | PageGather vault escalation trace |
| `/Users/jojo/Downloads/Epistemos-terminal-s` | hyperdynamic/schema repair loop |

## Non-Git Folders

These are not deletion candidates without a manual archive/backup decision:

- `/Users/jojo/Downloads/Epistemos-live-data-backup-20260401-191422`
- `/Users/jojo/Downloads/Epistemos-live-data-backup-20260401-191440`
- `/Users/jojo/Downloads/Epistemos-safety-backup-20260401-183510`
- `/Users/jojo/Downloads/epistemos-public`
- `/Users/jojo/Downloads/EPISTEMOS_HELIOS_MASTER_ARCHIVE_2026_05_05_PRESERVATION_BUNDLE`
- `/Users/jojo/Downloads/AETHERLINK_APPLICATION_KIT_FULL`

## Cleanup Recommendation

Do not clean up tonight by deleting folders. First:

1. commit or otherwise preserve the current dirty Epistemos worktree;
2. port any still-needed work from T5, T17b, T18b, Terminal C/T1, and Wave4;
3. regenerate the worktree inventory;
4. remove only the approved clean/merged worktrees.

This keeps the AetherLink/OAS intake, ScopeRex, Helios, System G, ACS/UAS,
lattice-WBO, EML/IR, and large-model substrate surfaces from being lost.

## Non-Runtime Architecture Reality Check

The AetherLink kit reinforces the Epistemos large-model route as a
planner-first architecture:

```text
OAS / UAS address
  -> WeightBlockManifest
  -> ResidencyPlan
  -> ConstructionCard
  -> provider/reference comparison
  -> runtime probe only after crash-safe gates
```

Current safe evidence is planner/manifest evidence, not live inference:

- `F-WeightBlockRangeHash-DryRun` proves bounded byte-range ingestion.
- `F-ResidencyPlan-DryRun` proves active-set planning without loading model
  bytes.
- `F-ProviderReferenceManifest-DryRun` proves the reference ABI shape while
  refusing to count shape-only fixtures as prompt-level evidence.
- `F-70B-Local-Cocktail-Lite` correctly stays red on
  `missing_fp16_or_provider_reference`.

So the AetherLink/OAS language is valuable, but it should enter Epistemos as
addressing, contracts, ledger, verifier, and planner hardening first. The live
runtime pieces stay behind explicit heavy-run gates.
