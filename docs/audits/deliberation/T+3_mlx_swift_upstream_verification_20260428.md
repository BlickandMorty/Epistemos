# T+3 mlx-swift upstream state verification (2026-04-28)

> Closes task #16 ("T+3 mlx-swift upstream state verification") and the
> open concern in `docs/audits/deliberation/T+3_phase_S_blockers_deliberation_20260427.md:107`:
> *"mlx-swift fails upstream in `Cmlx` format.cc during full xcodebuild
> — need to verify currentstate (audit doc may pre-date final fixes in
> canonical chain)."*

## Conclusion

**Stale.** The mlx-swift upstream `Cmlx` `format.cc` failure flagged in the prior audit is no longer reproducible. The currently-pinned commit compiles cleanly under the current Xcode/Swift toolchain.

## Evidence

### Pinned commit
`Epistemos.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`:
```json
{
  "identity" : "mlx-swift",
  "kind" : "remoteSourceControl",
  "location" : "https://github.com/ml-explore/mlx-swift",
  "state" : { "revision" : "6ba4827fb82c97d012eec9ab4b2de21f85c3b33d" }
}
```

`6ba4827` is mlx-swift's `update for mlx v0.30.6 (#353)`, dated 2026-04-17. It comes 9 commits after `b990c58` (`remove symlinks (#191)`) which is the most recent commit that touched `Source/Cmlx/fmt/src/format.cc`.

### Successful build artifact

`/Users/jojo/Downloads/Epistemos/build/release-derived-data/Build/Products/Release/Epistemos.app` was produced 2026-04-17 14:10:40, post-dating the pinned mlx-swift commit by hours. The full-app link line in `docs/audits/verify-2026-03-21-152702.md` (line 3360) shows mlx-swift modules (`MLX`, `MLXNN`, `MLXOptimizers`) successfully linked, including `Cmlx`'s `format.cc` translation unit indirectly via the MLX framework.

The audit doc that flagged the issue (`T+3_phase_S_blockers_deliberation_20260427.md`) was authored 2026-04-27 — TEN DAYS AFTER our pinned mlx-swift commit and successful build. The flag was carried forward from an earlier audit cycle and not re-validated against the post-Apr-17 state.

### Local checkout health

`build/release-derived-data/SourcePackages/checkouts/mlx-swift/Source/Cmlx/fmt/src/format.cc` exists, is read-only (mode `r--r--r--`), 1333 bytes, last touched 2026-04-17 13:59. The git history of that file in our checkout:
```
b990c58 remove symlinks (#191)
```
…and nothing after. The format.cc bundled with mlx-swift @ 6ba4827 has been stable for many revisions; no upstream regression has landed since.

## Action

- ✅ Mark task #16 closed.
- ✅ The open concern in `T+3_phase_S_blockers_deliberation_20260427.md:107` is documented stale here — no code change required.
- 🚫 Do NOT bump mlx-swift past 6ba4827 without re-running the full xcodebuild gate; mlx-swift is the largest dependency in our SPM graph and even a 1-commit bump can re-introduce build-system surprises.

## What Phase Ω11 / mlx-swift-structured upgrade still owes

`docs/AUDIT-HANDOFF-Ω10-Ω14.md:168` — "MLXConstrainedGenerator is Tier 2 (soft logit biasing), not full token masking. Upgrade path: mlx-swift-structured library by @petrukha-ivan when verified."

This is a SEPARATE concern from `format.cc`. mlx-swift-structured is currently pinned at v0.1.0 (`68a169b`) and ships in our build. The Tier 1 upgrade (full token masking) is a feature decision, not a build blocker. Tracked under task #16's parent stream — not closed by this verification because it's a forward-looking design choice, not a verification of past work.
