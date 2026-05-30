---
state: dry_run_merge_audit
created_on: 2026-05-30
checkpoint_commit: 5849ea0305
checkpoint_tag: checkpoint/pre-worktree-salvage-2026-05-30
posture: no wholesale merge; port one surface at a time
---

# Worktree Safe Merge Dry Run - 2026-05-30

## Checkpoint

Before this audit, the current dirty worktree was preserved as:

```text
5849ea0305 checkpoint: preserve architecture work before salvage
checkpoint/pre-worktree-salvage-2026-05-30
```

This is the recovery point for any later salvage mistake.

## Rule

Do not wholesale-merge old worktree branches into current Epistemos. The current
tree has moved far enough that even clean branches can reintroduce stale project
settings, old UI surfaces, or pre-checkpoint runtime assumptions.

Safe salvage shape:

```text
branch comparison
  -> file-level conflict scan
  -> read donor file
  -> port one narrow surface
  -> run lightweight relevant guard
  -> commit
```

## Clean Branch Dry-Run Results

The following checks used Git merge-tree/diff analysis only. No branch was
merged and no cherry-pick was run.

| Branch | Status | Safe action |
|---|---|---|
| `wiring/app-systemg-run-seam-2026-05-23` | already ancestor of checkpoint; diff none | no merge needed; removal candidate after approval |
| `wiring/rust-r3-system-g-minimal-slice` | already ancestor of checkpoint; diff none | no merge needed; removal candidate after approval |
| `salvage/t6-uiux-status-2026-05-23` | docs-only status already present | no code mining; keep T6 deferred |
| `phase2-terminal-t1-runtime-router-2026-05-24` | conflicts: changed/added in both, including Xcode project and settings surface | port RuntimeExecutor/RuntimeRouter concepts manually; do not merge branch |
| `phase2-terminal-f-prime-falsifiers-r2-2026-05-24` | conflicts: changed/added in both around falsifier binaries, artifacts, docs | compare against current falsifier set; port missing harnesses only |
| `codex/wave4-page-gather-vault-escalation-2026-05-26` | conflicts across VaultRecall/SearchIndex/chat/settings/Rust storage | port only trace fields or caller-policy deltas that current PageGather lacks |
| `phase2-terminal-d-prime-health-rows-2026-05-24` | conflicts across health rows and bridge | port only missing health-row truth-floor fields |
| `codex/wave4-uas-typed-retrieval-2026-05-26` | conflicts across AnswerPacket, bridge, provenance, storage, UAS | port only missing typed-address fields after current UAS docs/tests agree |
| `codex/repromote-ui-wip-2026-05-26` | broad conflicts across app bootstrap, Epdoc, landing, settings, tests, HTML workspace | do not merge; mine only isolated UI fixes with manual review |

## Same-Day Deepening

After checking the donor files against the checkpoint, several branches proved
to be already represented in current code:

- T1's `RuntimeExecutor.swift`, `RuntimeRouterHealthRow.swift`,
  `RuntimeLanesSection.swift`, `FLocalToolUseTests.swift`, and audit doc are
  already present. Current `RuntimeRouter.swift` and `RuntimeRouterTests.swift`
  are newer/larger than the donor branch.
- F-prime's falsifier binaries and M2 Pro artifacts are already present.
  Current ACS-anchor, Eidos, and VaultRecall falsifier files are generally
  newer than the donor branch.
- Wave4 PageGather vault escalation has a later merge commit in history
  (`966bbffacf`) in addition to the donor branch commit (`18a18d3588`).
- D-prime health-row work has a later merge commit in history (`b842ac5db1`)
  and current health/bridge files are generally newer than the donor branch.

Conclusion: the safest action for these branches is **do not merge**. Treat
them as preservation references and mine only a named missing field after a
current-code read proves the field is absent.

## Current Cleanup Classification

Allowed after explicit user approval:

```text
/Users/jojo/Downloads/Epistemos-wrv-app
/Users/jojo/Downloads/Epistemos-wrv-rust
```

Not automatically removable:

```text
/Users/jojo/Downloads/Epistemos-wrv-audit
```

It is clean and graph-merged, but detached worktrees are easier to misread.
Inspect its exact purpose before removal.

Preserve-first:

```text
T5 EML/IR
T17b lattice/WBO
T18b ACS admission
Terminal S hyperdynamic loop
Terminal C System G
Terminal T1 runtime router
T2 local agent
T4 VaultRecall
Wave4 PageGather vault escalation
```

## Dirty High-Priority Branch Reality

The dirty worktrees were inspected by branch head, not by their dirty
`target/` directories. Current-vs-branch stats show why broad merges are
forbidden:

| Branch | Current-vs-branch risk | Decision |
|---|---|---|
| `codex/t17b-lattice-wbo-register-2026-05-18` | ancestor of checkpoint; diff none | no merge needed; generated dirt only |
| `codex/t18b-acs-admission-field-2026-05-18` | ancestor of checkpoint; diff none | no merge needed; generated dirt only |
| `phase2-terminal-s-hyperdynamic-loop-2026-05-24` | hundreds of files differ; branch would delete current RuntimeRouter/HTML workspace/current surfaces | donor reference only |
| `terminal/c-system-g-full-path-2026-05-23` | hundreds of files differ; branch lacks current post-Wave surfaces | donor reference only |
| `codex/t5-emlir-2026-05-16` | over a thousand files differ; branch would delete many current app/runtime files | mine only specific IR modules/docs after current-code read |
| `codex/t2-agent-2026-05-16` | over a thousand files differ; branch would delete current app/runtime files | mine only specific local-agent diagnostics if absent |
| `codex/t4-vault-2026-05-16` | over a thousand files differ; branch would delete current app/runtime files | mine only specific VaultRecall tests/policy if absent |

This is the concrete cause of the prior "app went back in time" failure mode:
old donor branches are valuable, but they are not valid merge bases for the
current app.

## Next Safe Port Target

The best next code-facing target is **not** a branch merge. It is a small
manual comparison of current code against the Terminal T1 doctrine:

```text
RuntimeExecutor.swift
RuntimeRouter.swift
RuntimeRouterHealthRow.swift
FLocalToolUseTests.swift
RuntimeRouterTests.swift
```

Reason: local agents and model mixtures are core to the app, but this branch
touches Xcode project files and settings surfaces, and the current tree already
contains a newer RuntimeRouter surface. The branch itself is too stale to merge
wholesale.

Exit condition for a T1 port:

```text
no Xcode project rollback
no legacy settings overwrite
provider policy remains fail-closed until live MLX/GGUF is bound
AnswerPacket provenance remains required
lightweight Swift/Rust checks only unless user allows app build
```

## 2026-05-30 Post-Checkpoint Inventory Refresh

Current active checkpoint:

```text
cac98f826b harden provider reference replay file gate
```

The active `/Users/jojo/Downloads/Epistemos` worktree is clean. No stale branch
was merged, cherry-picked, checked out, reset, or deleted during this refresh.

Current `git worktree list --porcelain` shows 38 registered worktrees,
including the active tree and 3 `.claude/worktrees/*` donors. The important
classification is:

| Class | Worktrees / branches | Safe action |
|---|---|---|
| Already ancestor of current checkpoint | `wiring/app-systemg-run-seam-2026-05-23`, `wiring/rust-r3-system-g-minimal-slice` | removable candidates after explicit approval; content already represented |
| Clean but not ancestor | `Epistemos-terminal-t1-runtime-router`, `Epistemos-ui-repromotion`, `Epistemos-wave4-page-gather-vault-escalation`, `Epistemos-wave4-uas-typed-retrieval`, `Epistemos-terminal-d-prime`, `Epistemos-terminal-f-prime`, `.claude/worktrees/simulation`, `.claude/worktrees/vigorous-goldberg-3a2d35`, `.claude/worktrees/agent-a0550f9c` | preserve as donors; mine only named missing files or fields |
| Dirty due generated/target churn | most `Epistemos-t*`, `Epistemos-terminal-*`, and `Epistemos-wirings-2026-05-23` worktrees report thousands of changes under `target/` directories | do not interpret as source work; do not bulk-clean without approval |
| Detached but clean | `Epistemos-wrv-audit` | inspect purpose before removal |
| Has one untracked doc | `Epistemos-wrv-docs` has an older `docs/CANONICAL_CHRONICLE_2026_05_23.md` | no promotion; current main has the richer chronicle |

Sample dirty status confirms the large dirty counts are not useful app-source
work: `Epistemos-t09-product-ledger` reports deleted `substrate-core/target/*`
artifacts, and `Epistemos-terminal-s` reports modified
`syntax-core/target/*` build outputs. These are build artifact directories, not
canon-bearing source changes.

Current safe-deletion posture:

```text
do not delete any worktree in this loop
do not force-remove dirty worktrees
do not merge broad donor branches
commit current-main salvage first, then remove only after explicit approval
```

Current safe mining posture:

```text
1. choose one branch/donor by named feature
2. compare donor file to current file
3. port one narrow source/doc/test surface by hand
4. run lightweight Rust/doc guard only
5. commit
```

Most useful next donor checks, in order:

1. `Epistemos-terminal-t1-runtime-router` - local-agent/model-mixture router
   doctrine; compare only `RuntimeExecutor`, `RuntimeRouter`,
   `RuntimeRouterHealthRow`, and focused tests. Current refresh result:
   `RuntimeExecutor.swift`, `RuntimeRouterHealthRow.swift`,
   `FLocalToolUseTests.swift`, `InferenceState+RouteProfiles.swift`,
   `RuntimeLanesSection.swift`, and `LocalToolGrammar.swift` are identical to
   the donor; current `Epistemos/LocalAgent/RuntimeRouter.swift` is newer
   because it retains the agent capability badge truth surface and tests. Do
   not merge T1 wholesale.
2. `Epistemos-wave4-uas-typed-retrieval` - UAS/ACS typed retrieval fields;
   compare only after current UAS docs/tests name the missing field.
3. `Epistemos-terminal-c` - System G full path; donor-only until a single
   missing event/run seam is named.
4. `Epistemos-wrv-docs` - no source promotion needed; the donor's untracked
   25 KB chronicle is older than current main's 160 KB canonical chronicle, and
   `docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md` already says
   "Do not promote."

This preserves the user's goal: keep every beneficial idea, but prevent the
old-worktree regression where a stale donor branch rolls the app backward.

## Salvage Port 1 - T5 EML Closure Slice

Status: **ported surgically; branch still donor-only.**

Source branch:

```text
codex/t5-emlir-2026-05-16
```

Ported only additive EML research files, not the stale app/UI/project surfaces:

```text
agent_core/src/research/eml/branched.rs
agent_core/src/research/eml/certificate.rs
agent_core/src/research/eml/closure.rs
agent_core/src/research/eml/closure_builders.rs
agent_core/src/research/eml/normalize.rs
agent_core/tests/cross_ir_attention_via_closure.rs
agent_core/tests/cross_ir_info_to_eml.rs
agent_core/tests/cross_ir_tropical_to_eml.rs
agent_core/tests/eml_ir_corpus_round_trip.rs
```

Current `agent_core/src/research/eml/mod.rs` was patched by hand so the newer
current ULP gate stays intact while the donor closure / normalization /
certificate surface becomes callable.

Verification:

```text
cargo test --manifest-path agent_core/Cargo.toml --features research \
  --test eml_ir_corpus_round_trip \
  --test cross_ir_attention_via_closure \
  --test cross_ir_info_to_eml \
  --test cross_ir_tropical_to_eml

29 passed; 0 failed

cargo test --manifest-path agent_core/Cargo.toml --features research \
  research::eml:: --lib

579 passed; 0 failed; 8168 filtered out
```

Not done by this port:

- no Lean files copied yet;
- no `research_custody/` files copied yet;
- no old LandingWave / app UI files resurrected;
- no branch merge, checkout, or Xcode project rewrite.

## Salvage Port 2 - T5 Lean Schema + Research Custody Slice

Status: **ported additively; build blocked by mathlib cache/runtime tooling.**

Source branch:

```text
codex/t5-emlir-2026-05-16
```

Ported Primitive-IR Lean schema files:

```text
lean/Epistemos/Epistemos/EML.lean
lean/Epistemos/Epistemos/EMLGeneratedSample.lean
lean/Epistemos/Epistemos/Geometry.lean
lean/Epistemos/Epistemos/GeometryGeneratedSample.lean
lean/Epistemos/Epistemos/Info.lean
lean/Epistemos/Epistemos/InfoGeneratedSample.lean
lean/Epistemos/Epistemos/Operator.lean
lean/Epistemos/Epistemos/OperatorGeneratedSample.lean
lean/Epistemos/Epistemos/Scan.lean
lean/Epistemos/Epistemos/ScanGeneratedSample.lean
lean/Epistemos/Epistemos/Tropical.lean
lean/Epistemos/Epistemos/TropicalGeneratedSample.lean
```

Also ported:

```text
research_custody/{eml,geometry,info,operator,scan,tropical}/...
lean/Epistemos/.gitignore
lean/Epistemos/lake-manifest.json
```

Current `lean/Epistemos/Epistemos.lean` imports only the new Primitive-IR
schema modules plus the existing E1-E7 stubs. It intentionally does not import
H1-H17 or PCF_1-PCF_10 because those existing side files still contain `sorry`
placeholders and the previous top-level file documented them as filesystem
budget-tracked rather than aggregate-build-ready.

Compatibility fix:

```text
lean/Epistemos/lakefile.lean
```

was patched from the newer `↦` Lake option syntax back to the v4.16-compatible
tuple syntax used by the donor branch and by the pinned
`leanprover/lean4:v4.16.0` toolchain.

Verification:

```text
rg --pcre2 '(^|[^A-Za-z_-])(sorry|admit)([^A-Za-z_-]|$)' \
  lean/Epistemos/Epistemos/{EML,EMLGeneratedSample,Geometry,GeometryGeneratedSample,Info,InfoGeneratedSample,Operator,OperatorGeneratedSample,Scan,ScanGeneratedSample,Tropical,TropicalGeneratedSample}.lean

0 executable sorry/admit matches

cd lean/Epistemos && lake env lean --version

Lean 4.16.0, arm64-apple-darwin23.6.0
```

Lean build caveat:

```text
lake env lean --version
```

created the manifest and cloned mathlib, but the mathlib cache fetch emitted:

```text
dyld: __DATA_CONST segment missing SG_READ_ONLY flag ...
error: mathlib: failed to fetch cache
```

Therefore this port does **not** claim `lake build` green. The schema files are
preserved and import-wired; a later Lean tooling pass must repair the mathlib
cache path or build dependencies from source before promoting this to a green
proof gate.

## Salvage Port 3 - T4 Shadow-First Retrieval Contract

Status: **ported surgically; branch still donor-only.**

Source branch:

```text
codex/t4-vault-2026-05-16
```

Ported only the missing Rust contract module:

```text
agent_core/src/retrieval/mod.rs
```

and exposed it through:

```text
agent_core/src/lib.rs
```

Why this was safe to port: current docs already claimed
`agent_core/src/retrieval/` as the Shadow-first answerability contract home,
but current code did not contain that module. The newer current
`storage::retrieval_trace` remains intact; this port adds the missing
Shadow-first / exact-escalation / residual-decode contract surface without
rewriting live vault storage, Swift UI, Xcode project files, or old LandingWave
code.

Verification:

```text
rustfmt --edition 2021 --check agent_core/src/lib.rs agent_core/src/retrieval/mod.rs

cargo test --manifest-path agent_core/Cargo.toml retrieval:: --lib

77 passed; 0 failed; 4075 filtered out
```

Not done by this port:

- no donor Swift VaultRecall tests copied yet;
- no ignored local-user-vault baseline test copied;
- no live caller wiring changed;
- no app/Xcode build or runtime probe run.

## Salvage Port 4 - ACS ClaimLedger Read Surface

Status: **built in current tree; no branch merge.**

This closes the narrow W-03 bridge gap that was still awkward for downstream
Provenance / AnswerPacket / UI work: current `Claim` already carried optional
`AcsAnchor`, but `ClaimLedger` did not expose a deterministic anchor read
surface. Added:

```text
ClaimLedger::claim_acs_anchor(&ClaimId) -> Result<Option<&AcsAnchor>, LedgerError>
ClaimLedger::anchored_claims() -> Vec<&Claim>
ClaimLedger::claims_for_acs_theorem(&str) -> Vec<&Claim>
```

Why this matters: UI and agent surfaces can now inspect anchored claims by
theorem id without crawling private ledger maps or duplicating ACS anchor logic.
Legacy claims remain allowed to have no anchor, so this is a product bridge,
not a false claim that every archived claim is already fully anchored.

Verification:

```text
rustfmt --edition 2021 agent_core/src/provenance/ledger.rs --check

cargo test --manifest-path agent_core/Cargo.toml provenance::ledger:: --lib

31 passed; 0 failed; 4123 filtered out
```

Not done by this port:

- no Provenance Console ACS theorem-tag column yet;
- no Swift/Xcode build or UI probe run;
- no heavy runtime/model/Metal test run.

## Donor Branch Skip - Mermaid Live Diagram Node

Status: **intentionally not ported.**

Multiple old donor branches contain:

```text
js-editor/src/extensions/mermaid-node.ts
Epistemos/Resources/Editor/vendor/mermaid/...
```

Current source guards require Mermaid to remain a legacy inert diagram surface
handled by `legacy-diagram-node.ts` / HTML Workspace replacement paths:

```text
EpistemosTests/HTMLWorkspaceSourceGuardTests.swift
EpistemosTests/EpdocSlashMenuViewTests.swift
EpistemosTests/EpdocPasteClassifierTests.swift
```

Reason: the user reported the `graph TD` button causing an Epdoc typing glitch.
Restoring the donor live Mermaid extension would fight the current guardrails
and likely resurrect that bug.

## Donor Branch Check - Terminal A Eidos

Status: **do not merge; current tree already carries the useful Rust substrate.**

The donor branch:

```text
terminal/a-eidos-bridge-2026-05-23
```

would delete or roll back current runtime, HTML workspace, AnswerPacket,
falsifier, and app files if merged wholesale. Current `agent_core/src/eidos/`
already contains the valuable W-49/W-50 Rust surfaces:

```text
agent_core/src/eidos/ledger_backed_claim_evidence.rs
agent_core/src/eidos/dag_backed_graph_neighborhood.rs
```

Current verification:

```text
cargo test --manifest-path agent_core/Cargo.toml eidos:: --lib

463 passed; 0 failed; 3691 filtered out
```

Remaining Eidos work is not branch salvage; it is forward wiring:

- W-46 Swift/Rust FFI bridge;
- W-47 ChatCoordinator closed-citation emit gate;
- W-48 Brain Panel "Retrieved by Eidos" surface;
- W-51 ShadowBackedSemanticIndex over the current shadow backend.

## Safe Build - ResidencyPlan Overlap Guard

Status: **built in current tree; no heavy runtime test.**

The safe 70B path now rejects overlapping model byte ranges before any mmap,
MLX, Metal, KV, or generation path can run. This hardens the
`WeightBlockManifest` -> `ResidencyPlan` gate:

```text
ResidencyPlanViolation::OverlappingByteRange
```

Why this matters: the 70B / SSD-resident ambition depends on treating model
weights as exact UAS-addressed byte ranges. Two active blocks from the same
source file must not overlap silently, even when their hashes differ, because
that would double-count or alias the cold SSD body before the runtime ever has
a chance to prove itself.

Verification:

```text
cargo test --manifest-path agent_core/Cargo.toml uas::weight_block::tests --lib

14 passed; 0 failed; 4142 filtered out
```

The dry-run falsifier now exposes this as the named axis:

```text
overlapping_ranges_rejected
```

and the 70B Lite preflight requires that axis before it can advance past the
residency-plan rung.
