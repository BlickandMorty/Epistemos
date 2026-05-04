# W9.30 Follow-Up Deliberation - KIVI Attention Tolerance

Date: 2026-05-01
Owner: Codex overseer
Status: Approved for a tests-only quality gate

## Gate

Approved action: add deterministic app-harness coverage proving the KIVI attention path stays within an explicit tolerance against a full-precision reference on small fixed tensors.

This gate does not approve KIVI as default-on, does not approve release-ready quality claims, does not run or claim perplexity validation, and does not change model routing beyond the existing explicit `EPISTEMOS_KV_KIVI=1` opt-in.

## Classification

Core/MAS-safe test coverage for the local MLX stack.

## Repo Evidence

- W9.30 implemented `KIVIKVCache` with transposed grouped key quantization, grouped value quantization, and full-precision residual windows.
- App-bundled Xcode runtime coverage already passes for grouped/residual state, prompt-cache serialization, and causal masking over residual keys.
- SwiftPM package runtime coverage is still blocked by local MLX `default.metallib` loading, so the app Xcode harness is the current trustworthy MLX runtime path.
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_025_2026_05_01.md` explicitly names deterministic attention tolerance coverage as the next W9.30 gate before any broader claim.

## Decision

Add one focused app-harness test that:

- Prefills a `KIVIKVCache` past one grouped flush.
- Runs one incremental attention step with grouped quantized K/V plus residual full-precision K/V active in the same softmax.
- Builds a `KVCacheSimple` full-precision reference from the same deterministic history.
- Compares KIVI output against an explicit full-precision `matmul -> softmax -> matmul` attention reference with an explicit max-absolute-error tolerance.
- Keeps the tolerance honest for 2-bit quantization and does not call it bit-exact.

## Alternatives

- Skip tolerance coverage: rejected because W9.30 would remain shape/serialization-only and could still hide a mixed grouped/residual softmax bug.
- Run Qwen perplexity now: rejected as a heavier model-quality gate that needs model fixture selection, runtime budget, and acceptance thresholds.
- Fix SwiftPM MLX resources first: useful later, but app-bundled MLX runtime tests already exercise the code path without the local `metallib` blocker.

## Allowed Write Scope

- `EpistemosTests/KIVIKVCacheRuntimeTests.swift`
- `docs/fusion/deliberation/w930_kivi_attention_tolerance_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_026_2026_05_01.md`

## Forbidden Scope

- No production KIVI routing changes.
- No default-on KIVI behavior.
- No model-quality or perplexity claim.
- No protected note editor files.
- No protected graph view/controller files.
- No `graph-engine/**`, `agent_core/**`, project files, entitlements, generated artifacts, branches, stashes, staging, or commits.

## Verification Plan

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/KIVIKVCacheRuntimeTests test
```

Post-test audits:

- `git diff --check`
- touched-file trailing whitespace audit
- source anti-pattern audit for `try!`, force unwrap, and `DispatchQueue.main.asyncAfter`
- protected diff audit

## Kimi Advisory

Kimi was invoked in read-only advisory mode from `/tmp`; it produced a useful advisory after an initial apparent stall. Codex accepted the safe parts of the advice:

- keep the slice additive and test-only
- avoid `MLXFast.scaledDotProductAttention` as the reference for this tolerance check
- use a supported MLX quantization group size (`32`, `64`, or `128`)
- keep Qwen-family perplexity validation as a separate unresolved default-on prerequisite

Kimi did not edit files, run tests, stage, commit, or change the repo.

Log path:

- `/tmp/epistemos-w930-kivi-quality-kimi-advisory-20260501.log`

## Rollback

Revert only this test/doc follow-up. Keep the W9.30 implementation intact unless this test exposes a real KIVI correctness bug; if it does, keep KIVI opt-in and fix the implementation before any broader claim.

## Stop Triggers

- The test requires changing production routing or enabling KIVI by default.
- The comparison only passes with an unreasonably loose tolerance.
- The fix requires protected editor/graph, `graph-engine/**`, generated bindings, project, entitlement, branch, stash, staging, or commit changes.
- Any failure suggests KIVI is only shape-correct but numerically incoherent.

## Result

Implemented the tests-only gate in `EpistemosTests/KIVIKVCacheRuntimeTests.swift`.

Initial red result:

- Log: `/tmp/epistemos-w930-kivi-attention-tolerance-20260501.log`
- Failure: MLX rejected group size `4`; supported sizes are `32`, `64`, and `128`.
- Correction: moved the deterministic fixture to a `32`-token group and `32`-dimension head.

Final verification:

- Log: `/tmp/epistemos-w930-kivi-attention-tolerance-final2-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_09-25-49--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `4` tests passed in `1` suite.

Post-slice audits:

- Diff check: `/tmp/epistemos-w930-kivi-attention-diff-check-docfinal-20260501.log`
- Touched-file trailing whitespace audit: `/tmp/epistemos-w930-kivi-attention-trailing-whitespace-docfinal-20260501.log`
- Source anti-pattern audit: `/tmp/epistemos-w930-kivi-attention-source-antipattern-docfinal-20260501.log`
- Protected diff audit: `/tmp/epistemos-w930-kivi-attention-protected-diff-docfinal-20260501.log`

Known limits:

- This only validates a deterministic arithmetic tolerance on small tensors; it does not assert model-level quality.
- KIVI remains explicit opt-in and not release-ready/default-on.
- Qwen-family perplexity/quality validation remains required before any default-on discussion.
- SwiftPM package runtime KIVI tests remain blocked by local MLX `default.metallib` loading; the app-bundled Xcode harness remains the current validated runtime path.
- Xcode still reports CodeEdit SwiftLint build-tool plugin failures after `** TEST SUCCEEDED **`; this matches earlier focused runs and did not prevent the command from exiting `0`.
