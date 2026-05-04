# W9.30 Deliberation - KIVI KV Cache PR2

Date: 2026-05-01
Owner: Codex active overseer
Status: APPROVED FOR A NARROW IMPLEMENTATION SLICE

## Slice

Implement the smallest honest W9.30 runtime slice:

- Add MLXLMCommon `KVQuantScheme` plumbing with `.affine` as default.
- Add a real `KIVIKVCache` path only if it preserves KIVI's asymmetric algorithm:
  - keys quantized per-channel by transposing cached keys and quantizing grouped token windows;
  - values quantized per-token using the existing last-dimension MLX quantizer;
  - recent residual key/value windows kept full precision;
  - no `RotatingKVCache` + KIVI combination in this slice.
- Add prompt-cache serialization coverage for `KIVIKVCache`.
- Keep app activation opt-in via `EPISTEMOS_KV_KIVI=1`, and keep `.affine` default.

This gate does not approve KIVI as default-on. It does not approve TurboQuant work. It does not approve model-quality claims beyond targeted unit/build proof.

## Repo Evidence

- `Epistemos/Engine/KIVIQuantization.swift` currently contains only runtime preference scaffolding and explicitly says the actual MLX `KIVIKVCache` is a follow-up.
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift` has `QuantizedKVCache`, but it quantizes both keys and values with `quantized(..., groupSize:bits:)` over the last dimension of `[B, H, T, D]`.
- `LocalPackages/mlx-swift-lm/.build/checkouts/mlx-swift/Source/MLX/Ops.swift` exposes `quantized(_:, groupSize:bits:mode:)` with no arbitrary axis parameter; MLX documentation says quantization groups consecutive elements in the last dimension.
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/AttentionUtils.swift` currently sends all `QuantizedKVCacheProtocol` caches through one symmetric `quantizedScaledDotProductAttention` path.
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/LanguageModel.swift` creates `RotatingKVCache` whenever `GenerateParameters.maxKVSize` is set; `RotatingKVCache.toQuantized` still `fatalError`s.
- `Epistemos/Engine/MLXInferenceService.swift` currently passes `maxKVSize` and `kvBits: 4`, so KIVI must not be bolted onto the existing rotating-cache path.

## Research Evidence

- KIVI arXiv 2402.02750 says keys should be quantized per-channel and values per-token, with grouped and residual cache parts.
- The paper explains that key per-channel quantization spans tokens and cannot be directly appended in the streaming setting; KIVI keeps residual full-precision windows and quantizes complete groups.
- The official `jy-yuan/KIVI` reference implementation transposes keys before quantizing them along the last dimension and keeps `residual_length` full-precision tokens.
- Local dossier `docs/RESEARCH_DOSSIER_TIER_3_4.md` identifies current `QuantizedKVCache` as symmetric and mandates KIVI as opt-in first.
- `final v2` research warns that TurboQuant may supersede KIVI on Apple Silicon and that sub-3-bit KV schemes need per-model-family validation.

## Correctness Ruling

Do not implement KIVI by merely setting existing affine `QuantizedKVCache(bits: 2)`. That would quantize keys per-token, not per-channel, and would violate the "no fake features" rule.

The acceptable pure-MLX path is:

1. Store KIVI grouped keys as transposed quantized tensors shaped from `[B, H, D, groupedT]`, because MLX quantizes the last dimension.
2. Store grouped values with existing per-token last-dimension quantization over `[B, H, groupedT, D]`.
3. Store residual keys/values in full precision.
4. Compute attention logits as quantized grouped-key matmul plus residual-key matmul, concatenate logits, softmax once, then split attention weights for quantized grouped values plus residual values.
5. Preserve `.affine` behavior unchanged unless `.kivi` is explicitly selected.

## Allowed Files

- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/AttentionUtils.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift`
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/LanguageModel.swift`
- `LocalPackages/mlx-swift-lm/Tests/MLXLMTests/KVCacheTests.swift`
- `Epistemos/Engine/KIVIQuantization.swift`
- `Epistemos/Engine/MLXInferenceService.swift`
- `Epistemos/State/InferenceState.swift`
- `Epistemos/Views/Chat/ModelAboutSheet.swift`
- targeted tests under `EpistemosTests/` only if app-facing plumbing changes
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_025_2026_05_01.md`

## Forbidden Files

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/**`
- generated `.rlib`, DerivedData, `.xcresult`
- `/Users/jojo/.gemini/antigravity/scratch/rex/**` unless the user explicitly requests external scratch cleanup

## Test-First Plan

1. Add package tests proving `GenerateParameters.kvScheme` defaults to `.affine` and selects `KIVIKVCache` only when no rotating cache is requested.
2. Add KIVI cache serialization tests through `savePromptCache` / `loadPromptCache`.
3. Add shape/state tests that feed more than `residualLength` tokens and assert grouped KIVI state plus residual state exist.
4. Add a comparison test for the KIVI attention path on small deterministic tensors against a dequantized/reference path with a tolerance appropriate for 2-bit quantization.

## Verification Commands

- `swift test --package-path LocalPackages/mlx-swift-lm --filter KVCache`
- `swift test --package-path LocalPackages/mlx-swift-lm --filter MLXTokenIterator`
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/TriageServiceTests test` if `MLXInferenceService.swift` request plumbing changes.
- Source audits:
  - `rg -n "KIVIKVCache|kvScheme|EPISTEMOS_KV_KIVI" LocalPackages/mlx-swift-lm Epistemos`
  - `git diff -- Epistemos/Views/Notes/ProseEditor*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift graph-engine/`

## Stop Triggers

- Any implementation uses `QuantizedKVCache(bits: 2)` and calls it KIVI.
- KIVI combines with `RotatingKVCache` in this slice.
- KIVI becomes default-on.
- Prompt cache load/save cannot round-trip `KIVIKVCache`.
- Shape tests require broad rewrites of model attention files.
- Kimi or Codex touches protected files.
- The Antigravity scratch Cargo files move into the Epistemos repo.

## Runtime Follow-Up

The narrow implementation slice now has app-bundled Xcode runtime coverage for grouped/residual state, prompt-cache serialization, and causal masking over residual keys:

- Log: `/tmp/epistemos-w930-kivi-app-runtime-final3-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_09-04-55--0500.xcresult`
- Result: `3` Swift Testing tests passed in `1` suite.

That app-harness run found and verified a real runtime fix: exact residual-window flushes must preserve a non-empty full-precision residual key/value window and must not serialize empty KIVI state tensors.

The follow-up app-harness run also verified that KIVI causal masking blocks future residual keys. SwiftPM package runtime tests remain blocked by local MLX `default.metallib` resource loading, so package-level runtime coverage is still not a release gate pass. KIVI remains explicit opt-in and not default-on until deterministic quantized attention tolerance and Qwen-family perplexity/quality checks are complete.

## Rollback

Revert only files touched by this slice. Do not reset or checkout unrelated dirty work. If KIVI tests fail after implementation, keep `.affine` default and remove/disable `.kivi` dispatch rather than shipping a mislabeled feature.
