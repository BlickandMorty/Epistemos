# Codex / Kimi Oversight Round 026 - W9.30 KIVI Attention Tolerance

Date: 2026-05-01

## Verdict

Proceed after post-slice audits. The W9.30 follow-up adds deterministic arithmetic tolerance coverage for the KIVI mixed grouped/residual attention path, but it still does not make KIVI release-ready or default-on.

## Scope

Narrow tests-only W9.30 follow-up:

- Add deterministic app-harness coverage for KIVI attention after grouped flush.
- Compare KIVI output against an explicit full-precision attention reference.
- Keep KIVI opt-in only.
- Record the red/green evidence and limitations in the fusion docs.

## Kimi State

Kimi did not edit this slice. It was used as read-only advisory from `/tmp`:

- Log: `/tmp/epistemos-w930-kivi-quality-kimi-advisory-20260501.log`

Accepted advice:

- Keep the work additive and test-only.
- Avoid `MLXFast.scaledDotProductAttention` as the reference for this tolerance gate.
- Use supported MLX quantization group sizes.
- Keep Qwen-family perplexity as a separate unresolved gate.

Codex retained control of edits, verification, and docs. No Kimi file edits, staging, commits, or tool actions occurred.

## Repo State

Round 026 was constrained to:

- `EpistemosTests/KIVIKVCacheRuntimeTests.swift`
- `docs/fusion/deliberation/w930_kivi_attention_tolerance_deliberation_2026_05_01.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_026_2026_05_01.md`

Pre-existing dirty work remains outside this slice, including protected `graph-engine/**` changes. Round 026 did not edit protected note editor files, protected graph view/controller files, `graph-engine/**`, project files, entitlements, generated artifacts, branches, stashes, staging, or commits.

## Commands Run

Initial red app-harness run:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/KIVIKVCacheRuntimeTests test
```

- Log: `/tmp/epistemos-w930-kivi-attention-tolerance-20260501.log`
- Result: failed because MLX rejected quantization group size `4`.
- Fix: use a supported `32`-token group and `32`-dimension head for the deterministic fixture.

Final app-harness run:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/KIVIKVCacheRuntimeTests test
```

- Log: `/tmp/epistemos-w930-kivi-attention-tolerance-final2-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_09-25-49--0500.xcresult`
- Result: `** TEST SUCCEEDED **`
- Swift Testing result: `4` tests passed in `1` suite.
- Note: Xcode still reported SwiftLint build-tool plugin failures for `CodeEditSourceEditor` and `CodeEditTextView` after the success banner; this matches earlier focused runs and the command exited `0`.

Post-slice audits:

- `/tmp/epistemos-w930-kivi-attention-diff-check-docfinal-20260501.log`
- `/tmp/epistemos-w930-kivi-attention-trailing-whitespace-docfinal-20260501.log`
- `/tmp/epistemos-w930-kivi-attention-source-antipattern-docfinal-20260501.log`
- `/tmp/epistemos-w930-kivi-attention-protected-diff-docfinal-20260501.log`

## Findings

### P0

None.

### P1

None for this tests-only gate.

### P2

KIVI is still not release-ready or default-on. This gate validates a deterministic small-tensor arithmetic tolerance, not model-level quality, long-context behavior, or perplexity on Qwen-family workloads.

### P3

SwiftPM package runtime KIVI tests remain blocked by local MLX `default.metallib` loading. The app-bundled Xcode harness is the validated runtime path for this slice.

Protected diff audit still reports pre-existing `graph-engine/**` dirty files. Round 026 did not modify those files.

Xcode still reports CodeEdit SwiftLint build-tool plugin failures after `** TEST SUCCEEDED **`, matching prior focused runs.

## Order Sent To Kimi

No Kimi edit/build order was sent. Kimi was advisory only; Codex implemented the final safe version and rejected any default-on or quality-claim escalation.

## Next Gate

Before any KIVI default-on or release-ready claim:

- Run a real Qwen-family perplexity/quality comparison for affine versus KIVI.
- Decide whether package-level MLX runtime tests need a separate `default.metallib` resource fix.
- Keep KIVI behind explicit opt-in until those gates pass.
