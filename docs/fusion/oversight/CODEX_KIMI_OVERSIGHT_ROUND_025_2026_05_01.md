# Codex / Kimi Oversight Round 025 - W9.30 KIVI KV Cache PR2

Date: 2026-05-01

## Verdict

Proceed with the implemented narrow slice, but do not mark KIVI release-ready or default-on until model-quality/perplexity validation is completed.

## Scope

W9.30 KIVI KV cache PR2:
- Add MLXLMCommon `KVQuantScheme` plumbing with `.affine` as the default.
- Add a real `KIVIKVCache` path that uses transposed key quantization, per-token value quantization, and full-precision residual windows.
- Wire app-side opt-in through `EPISTEMOS_KV_KIVI=1` and context-length thresholding.
- Surface the active KV scheme in the local model about sheet.
- Preserve `.affine` for normal/runtime default behavior.

## Kimi State

Kimi did not edit this slice directly.

First Kimi read-only advisory session hit the step limit without usable output:
- Log: `/tmp/epistemos-w930-kimi-deliberation-20260501.log`

Second Kimi read-only advisory suggested a shortcut implementation:
- Add `KIVIKVCache` with different K/V group sizes along the last axis.
- Omit residual windows.
- Treat that as the smallest honest implementation.
- Log: `/tmp/epistemos-w930-kimi-feasibility-20260501.log`

Codex rejected that shortcut because it did not satisfy the paper/reference requirements:
- It did not implement true key per-channel quantization.
- It omitted KIVI residual full-precision windows.
- It risked shipping an approximation under the KIVI name.

Codex used the stricter deliberation ruling instead:
- Keys are transposed so MLX last-axis quantization groups token windows per channel.
- Values use grouped per-token quantization.
- Recent key/value residual windows remain full precision.
- KIVI remains mutually exclusive with `RotatingKVCache` in this slice.

## Antigravity Scratch State

The Antigravity scratch Cargo files remain outside the Epistemos repository and were not deleted, imported, moved, staged, or treated as branch source:
- `/Users/jojo/.gemini/antigravity/scratch/rex/Cargo.toml`
- `/Users/jojo/.gemini/antigravity/scratch/rex/crates/rex-kernel/Cargo.toml`
- `/Users/jojo/.gemini/antigravity/scratch/rex/crates/rex-kernel/src/lib.rs`
- `/Users/jojo/.gemini/antigravity/scratch/rex/crates/rex-bench/Cargo.toml`

Disposition:
- Do not delete external scratch files without explicit user approval.
- Do not treat scratch Cargo manifests as Epistemos source.
- Continue with shell-audited, gated slices while GUI Kimi/Antigravity is unstable.

## Repo State

W9.30 touched only the approved app/MLX surfaces:
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/LanguageModel.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/AttentionUtils.swift`
- `LocalPackages/mlx-swift-lm/Tests/MLXLMTests/KVCacheTests.swift`
- `Epistemos/Engine/KIVIQuantization.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/Views/Chat/ModelAboutSheet.swift`
- `EpistemosTests/KIVIKVCacheRuntimeTests.swift`
- `docs/fusion/deliberation/w930_kivi_kv_cache_pr2_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_025_2026_05_01.md`

Pre-existing dirty work remains outside this slice, including `graph-engine/**`, `agent_core/Cargo.toml`, and `epistemos-core/Cargo.toml`; W9.30 did not revert or modify those unrelated changes.

## Commands Run

Test-first red:

```bash
swift test --package-path LocalPackages/mlx-swift-lm --filter KVCacheTests/testGenerateParametersDefaultToAffineKVScheme
```

- Log: `/tmp/epistemos-w930-kivi-testfirst-red-20260501.log`
- Expected result: compile failed before implementation because `KIVIKVCache` and `GenerateParameters.kvScheme` did not exist.

Package build:

```bash
swift build --package-path LocalPackages/mlx-swift-lm
```

- Log: `/tmp/epistemos-w930-kivi-mlx-build-final3-20260501.log`
- Result: build complete.

Focused package test:

```bash
swift test --package-path LocalPackages/mlx-swift-lm --filter testGenerateParametersDefaultToAffineKVScheme
```

- Log: `/tmp/epistemos-w930-kivi-generateparams-after-runtime-fix-20260501.log`
- Result: `1` Swift Testing test passed.

Runtime MLX package state/serialization tests:

```bash
swift test --package-path LocalPackages/mlx-swift-lm --filter testKIVIKVCacheFormsGroupedAndResidualState
```

- Log: `/tmp/epistemos-w930-kivi-package-runtime-after-fix-2-20260501.log`
- Result: blocked by local SwiftPM MLX runtime harness failure: `Failed to load the default metallib`.
- Disposition: not counted as package-level KIVI runtime validation; SwiftPM still needs an MLX test harness/resource fix.

App-bundled KIVI runtime validation:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/KIVIKVCacheRuntimeTests test
```

- Initial log: `/tmp/epistemos-w930-kivi-app-runtime-20260501.log`
- Initial result: failed on prompt-cache serialization because exact residual-window flushes could leave an empty residual key tensor (`0.6`) in `KIVIKVCache.state`.
- Fix: only flush complete grouped key windows while preserving the full residual key/value window; removed the dead empty-residual tensor path.
- Follow-up fix: tightened the KIVI-only causal mask fill so masked future residual keys receive a negative sentinel logit instead of a near-zero score.
- Final log: `/tmp/epistemos-w930-kivi-app-runtime-final3-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_09-04-55--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `3` tests passed in `1` suite.
- Note: Xcode still reported SwiftLint build-tool plugin failures for `CodeEditSourceEditor` and `CodeEditTextView` after the success banner; lint found `0` violations and then hit the existing package-plugin `Output` folder issue.

Focused app compile/test:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/ChatPresentationTests test
```

- Log: `/tmp/epistemos-w930-chatpresentation-3-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_02-16-51--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `55` tests passed in `1` suite.

Post-slice audits:
- `/tmp/epistemos-w930-diff-check-final3-20260501.log`
- `/tmp/epistemos-w930-source-audit-final3-20260501.log`
- `/tmp/epistemos-w930-protected-diff-audit-final3-20260501.log`

## Findings

### P0

None.

### P1

KIVI is not release-ready as a default-on feature. The implementation compiles and the app-bundled grouped-state/serialization/causal-mask runtime tests pass, but SwiftPM package runtime tests are still blocked by missing `mlx.metallib`, deterministic quantized attention-tolerance coverage is not complete, and perplexity/quality validation has not been run.

### P2

Protected diff audit still reports pre-existing `graph-engine/**` dirty files. W9.30 did not touch protected note editor files, protected graph view/controller files, or `graph-engine/**`.

### P3

Xcode still reports SwiftLint command failures for `CodeEditSourceEditor` and `CodeEditTextView` after `** TEST SUCCEEDED **`, matching prior focused runs.

## Order Sent To Kimi

No Kimi edit order was sent. Kimi advisory was read-only; Codex independently verified the research/docs, rejected the shortcut, implemented the stricter path, and ran the verification/audit gates.

## Next Gate

W9.30 needs a follow-up quality gate before any release-ready or default-on claim:
- Make MLX package runtime tests load `mlx.metallib`, if package-level runtime coverage is still required beyond the app-bundled Xcode harness.
- Add deterministic attention tolerance coverage against a dequantized/reference path.
- Run a real Qwen-family perplexity/quality comparison before enabling KIVI beyond explicit opt-in.
