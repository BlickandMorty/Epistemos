---
state: safe_non_runtime_audit
created_on: 2026-05-30
scope: non-runtime hardening, architecture preservation, worktree salvage
posture: no app launch; no Xcode build; no MLX/GGUF/model probe; no Metal stress
---

# Non-Runtime Feature And Worktree Check - 2026-05-30

## Scope Guard

This pass deliberately stayed out of the crash-risk runtime lane:

```text
no app launch
no xcodebuild
no MLX or GGUF generation
no model-file mmap probe
no 128K / 70B context run
no Metal stress witness
no worktree deletion
```

The goal was to verify the buildable non-runtime architecture: schemas,
manifests, dry-run planners, honest red gates, and worktree preservation.

## Executable Guard Result

`F-Architecture-Pending-Work-Guard` is the current recursive-loop guard.

Current required non-runtime axes:

| Axis | Expected state | Meaning |
|---|---|---|
| `weight_block_range_hash_dry_run_available` | `true` | Model byte-range manifests have a bounded hashing ABI that rejects over-budget reads before touching data. |
| `residency_plan_dry_run_available` | `true` | A deterministic residency plan can represent cold SSD-addressed body plus hot/warm active set without loading model bytes. |
| `provider_reference_manifest_dry_run_available` | `true` | Provider/reference comparison manifests have a retained shape fixture and prompt-suite binding. |
| `local_70b_cocktail_honest_red` | `true` | The 70B route remains red for the correct reason instead of pretending the planner is live inference. |

Current large-model meaning:

```text
safe planner floor exists
  + provider/reference shape exists
  + 70B preflight remains red on missing_fp16_or_provider_reference
  != live 70B runtime proof
```

## Safe Green Non-Runtime Surface

These surfaces are appropriate to continue while runtime-heavy probes are
paused:

- shared falsifier artifact schema and validator;
- `WeightBlockManifest` range hashing and known-hash ingestion;
- `ResidencyPlan` active-set planning with rollback, WBO, and codec labels;
- `ConstructionCard` binding ProblemCard, LiftChart, ProjectionPacket, Witness,
  Budget, Falsifier, Rollback, and a passed plan;
- `ProviderReferenceManifest` shape and prompt-suite digest binding;
- `ResidencyPatternBoost` dry-run artifacts: assembly genome, constraint
  repair trace, sparse fingerprint, held-out replay score, elite archive
  lineage, LatticeAbstentionGate result, ComputeResumeLease, rollback, and
  AnswerPacket witness schema;
- worktree/model-context inventories;
- architecture pending-work guard;
- AetherLink/OAS intake as addressing, contracts, ledger, verifier, and
  planner doctrine.

## Still Runtime-Red

These are not complete and must not be described as working yet:

- live 70B local generation;
- SSD-backed sparse-active 70B decode;
- PatternBoost-derived live route/layout mutation without replay, abstention,
  rollback, and witness evidence;
- live MLX/GGUF local-agent streaming through System G;
- dense PageGather primary bandwidth;
- live 128K KV-Direct residual-patched mmap/NF4 spill;
- local model mixture replacing a frontier model in measured quality/speed.

## Worktree Preservation Priority

No sibling folder should be deleted until current work is committed or
otherwise intentionally preserved. Priority preserve/inspect surfaces:

| Priority | Worktree family | Why it matters |
|---:|---|---|
| 1 | `Epistemos-t5-emlir` | EML / Geometry / Info / Operator IR stack, directly tied to the primitive-collapse ambition. |
| 2 | `Epistemos-t17b-lattice-wbo-register` | Lattice/WBO register path, directly tied to weight lattice and budget discipline. |
| 3 | `Epistemos-t18b-acs-admission-field` | Legacy path for SCOPE-Rex admission field and state-contract discipline. |
| 4 | `Epistemos-terminal-s` | Hyperdynamic/schema repair loop. |
| 5 | `Epistemos-terminal-d` | Substrate health rows and user-visible truth floor. |
| 6 | `Epistemos-terminal-a` | Eidos citation/evidence bridge. |
| 7 | `Epistemos-terminal-c` and `Epistemos-terminal-t1-runtime-router` | System G and runtime routing seams; runtime later, but code salvage now. |
| 8 | `Epistemos-t2-agent` | Local-agent diagnostics, answer packets, model selection, provider discipline. |
| 9 | `Epistemos-t4-vault` and `Epistemos-wave4-page-gather-vault-escalation` | VaultRecall, RRF, PageGather, and retrieval escalation. |

Clean merged removal candidates still require explicit user approval:

```text
/Users/jojo/Downloads/Epistemos-wrv-app
/Users/jojo/Downloads/Epistemos-wrv-audit
/Users/jojo/Downloads/Epistemos-wrv-rust
```

Claude worktrees and non-git backups are preserve-only until separately
classified.

## Next Safe Build Actions

1. Keep `F-Architecture-Pending-Work-Guard` green after every non-runtime
   architecture edit.
2. Compare clean unique worktrees before dirty/generated-churn worktrees.
3. Port only one salvage family at a time.
4. Do not resume 128K/70B runtime probes until the provider reference, heavy-run
   guard, crash-safe harness policy, and rollback plan are all explicit.
5. When runtime resumes, prove the smallest step first: reference manifest ->
   tiny live provider/reference row -> bounded local runtime smoke -> only then
   larger context/model probes.
