# Claude Shadow Handle Preservation Closeout - 2026-05-26

Status: closed for current honest-handle product recovery.

Source surfaces:

- Draft preservation PR: `#81`
- Branch: `codex/recovery-claude-shadow-handle-2026-05-26`
- Overlapping stash: `stash@{16}` (`session-stash-2026-04-27`)

Recovery rule: do not raw-merge `#81`. Its visible preservation payload is
`RustShadowFFIClient.swift`, `epistemos-shadow/src/honest_handle.rs`, and
`agent_core/Cargo.lock`, but the branch tree is stale relative to current
`main`. The useful honest-handle behavior is already present on main in a newer
form.

## Current Main Evidence

| Claim | Evidence |
|---|---|
| Swift no longer binds the legacy global search/insert/remove path | `Epistemos/Engine/RustShadowFFIClient.swift` owns `private let handle: UnsafePointer<UInt8>` and binds `shadow_handle_open_at`, `shadow_handle_search`, `shadow_handle_insert`, `shadow_handle_remove`, `shadow_handle_flush`, `shadow_handle_stats`, `shadow_handle_last_timings_json`, and `shadow_handle_free_string`. |
| Rust exports the panic-safe handle surface | `epistemos-shadow/src/honest_handle.rs` exports `shadow_handle_*` entry points using `panic::catch_unwind` / `AssertUnwindSafe` and owns string freeing through `shadow_handle_free_string`. |
| The current main version is newer than the preservation branch | The preservation branch lacks current-main additions such as `shadow_handle_last_timings_json` consumer wiring and related timing guards. Raw merge would be a downgrade. |
| Source guards prevent regression | `EpistemosTests/ShadowServicesTests.swift` contains `ShadowHonestHandleSourceGuardTests`, including guards for the Swift consumer, AppBootstrap construction, and the Rust handle export surface. |

## Why The Draft PR Stays Non-Mergeable

`#81` is a recovery reference, not a feature PR. Its stale branch diff would
rewrite current main's newer Shadow client and lockfile state. The only safe use
for the branch is donor inspection.

## Remaining Donor Ideas

The honest-handle slice is closed. The overlapping `stash@{16}` may still hold
unrelated approval/UI donor ideas, especially:

- `Epistemos/State/ChatApprovalQueue.swift`
- `Epistemos/Views/Approval/ApprovalModalView.swift`
- historical editor asset notes

Recover those only as separate, focused slices from current `origin/main`. Do
not bundle them with the shadow handle work.
