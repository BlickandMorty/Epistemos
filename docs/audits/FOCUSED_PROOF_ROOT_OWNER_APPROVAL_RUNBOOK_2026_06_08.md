---
state: canon_runbook
created_on: 2026-06-08
scope: owner-approved focused proof-root execution boundary for graph-filter release-audit evidence
upstream_witnesses:
  - F-GraphFilterVisibilityFocusedProofRootCommandCard
  - F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate
promotion_tier: T0 runbook, no runtime execution performed
---

# Focused Proof-Root Owner Approval Runbook - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Purpose

This runbook defines the approval boundary for the first focused graph-filter
proof-root execution. It exists because the architecture now has:

- `F-GraphFilterVisibilityFocusedProofRootCommandCard`: an unarmed command
  envelope with proof-root-scoped Xcode command templates.
- `F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate`: a post-run
  parser contract for selected product digest, `.xcresult` digest, nonzero
  executed-test count, source-status digests, RunEventLog, AnswerPacket, and
  rollback evidence.

This document does not run Xcode, open test products, open result bundles,
modify product source, load model/runtime bytes, or promote L2/L3/product/
release/large-model capability.

## Owner Approval Boundary

The focused proof-root run is allowed only after the owner explicitly approves
an Xcode execution session. Acceptable approval wording should name the scope,
for example:

```text
I approve one focused graph-filter proof-root Xcode run using the current
proof-root command card and execution-artifact parser gate. Do not run the
full release audit unless I approve it separately.
```

Without that approval, agents may update canon, improve parser contracts,
inspect source, and prepare manifests, but must not execute the focused
`xcodebuild build-for-testing` or `xcodebuild test-without-building` commands.

## Pre-Run Conditions

Before a focused run can start, verify:

- exactly one `/Users/jojo/Downloads/Epistemos` worktree on `main`;
- `git status --short` recorded before the run;
- no staged unrelated changes;
- current HEAD recorded;
- `F-GraphFilterVisibilityFocusedProofRootCommandCard` passes;
- `F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate` passes;
- proof root is under `artifacts/xcode/graph-filter-visibility-test-products/`;
- global DerivedData is not used;
- scheme pre-action accounting is captured;
- rollback, RunEventLog, and AnswerPacket output paths are declared;
- full `xcodebuild_test` automated-check row remains required after any focused
  pass.

## Evidence Contract

The future focused execution artifact must write
`focused-proof-root-execution-artifact.json` and satisfy the 18-field contract:

```text
source_commit_sha
pre_build_source_status_digest
post_test_source_status_digest
scheme_pre_action_ledger_digest
selected_test_product_path
selected_test_product_kind
selected_test_product_digest
selected_test_product_commit_sha
enumeration_json_digest
focused_selector_digest
focused_result_bundle_path
focused_result_bundle_digest
focused_result_bundle_status
executed_test_count
full_automated_check_row_status
run_event_log_digest
answer_packet_digest
rollback_digest
```

The parser must fail closed on:

- zero executed tests;
- missing selected product digest or commit;
- missing focused `.xcresult` digest;
- missing pre/post source-status digest;
- missing scheme pre-action ledger;
- focused proof replacing the full automated-check row;
- product-source mutation not accounted by the manifest;
- raw note/prompt/model bytes in logs;
- L2/L3/product/release green claims;
- live dense-70B or SSD-as-RAM claims.

## Safe Command Shape

The command card binds the following shapes as unarmed templates:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS -derivedDataPath "$PROOF_ROOT/DerivedData" build-for-testing -resultBundlePath "$PROOF_ROOT/build-for-testing.xcresult"

xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS -derivedDataPath "$PROOF_ROOT/DerivedData" -xctestrun "$SELECTED_TEST_PRODUCT" -enumerate-tests > "$PROOF_ROOT/enumerated-tests.json"

xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS -derivedDataPath "$PROOF_ROOT/DerivedData" -xctestrun "$SELECTED_TEST_PRODUCT" -only-testing:"$FOCUSED_SELECTOR" test-without-building -resultBundlePath "$PROOF_ROOT/focused-graph-filter.xcresult"
```

The actual run must resolve `$PROOF_ROOT`, `$SELECTED_TEST_PRODUCT`, and
`$FOCUSED_SELECTOR` into manifest-bound values before any evidence can count.

## Promotion Truth

- T0: this runbook is canon/runbook only.
- T1/L1: the command card and execution-artifact parser gate are already
  metadata-only witnesses.
- T2/L2: unchanged and red until capability kernel evidence changes.
- T3/L3: unchanged and red until WRV plus log-correlated product evidence
  exists.
- T4/T5: no green claim.

The owner-approved focused run, if it passes, still cannot replace full
`xcodebuild_test`, all five automated checks, log evidence, manual runtime
verification, distribution/compliance review, and repeated zero-fail release
audit evidence.

## Why This Matters For Large Local Models

Large local models need a trustworthy runtime and release proof floor before
Gemma QAT, GGUF/LiteRT/MLX lanes, TurboVec/Eidos caches, KV reuse, sparse
residency, or cold assembly can become user-facing. If focused Xcode evidence
can be stale, selector-laundered, or promoted beyond its scope, later
large-model runtime wins would inherit false confidence. This runbook keeps the
proof floor strict before larger model work turns live.
