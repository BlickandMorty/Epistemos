# T5 Lean Custody Status - 2026-05-23

Terminal: T4 worktree and auxiliary branch salvage
Status branch: `salvage/t5-lean-custody-status-2026-05-23`
Custody worktree inspected: `/Users/jojo/Downloads/Epistemos-t5-emlir`
Custody branch: `codex/t5-emlir-2026-05-16`
Custody head: `2ba7142e28`

## Decision

Do not vendor `tomdif/eml-lean` in this PR.

The Lean toolchain and T5 custody branch build are not the active blocker
anymore. The remaining blocker is source custody: `tomdif/eml-lean` is not
vendored or attested under `lean/Epistemos/eml-lean`.

## Verification

Run in `/Users/jojo/Downloads/Epistemos-t5-emlir`.

```text
PATH="$HOME/.elan/bin:$PATH"; lean --version; lake --version
Lean (version 4.16.0, arm64-apple-darwin23.6.0, commit 128a1e6b0a82, Release)
Lake version 5.0.0-128a1e6 (Lean version 4.16.0)
```

```text
PATH="$HOME/.elan/bin:$PATH"; cd lean/Epistemos && lake build
Build completed successfully.
```

```text
Tools/sorry-budget/sorry-budget.sh
W24 sorry-budget: PASS (0 total sorries across all ids)
```

```text
test -d lean/Epistemos/eml-lean
eml-lean=missing
```

## Main-Branch Sync Note

The T5 custody branch is green, but the current `origin/main` checkout is not
equivalent to that T5 state:

- `origin/main` still has `lean/Epistemos/lakefile.lean` option syntax with
  `pp.unicode.fun` / `autoImplicit` entries written using the Lean 4.16
  incompatible mapsto token (`U+21A6`), which fails under Lean 4.16.0.
- `origin/main` currently reports `W24 sorry-budget: PASS (37 total sorries
  across all ids)`.
- `codex/t5-emlir-2026-05-16` carries the Lean-compatible lakefile option
  syntax and zero-sorry project state.

This doc is therefore a custody/status note, not a main-branch claim that T5
Lean source has already landed.

## Donor-Mining Test

| Test | Result | Evidence |
| --- | --- | --- |
| Unique vs main? | Yes | T5 branch carries Lean-compatible lakefile state, generated Lean IR modules, and zero-sorry theorem files not present on `origin/main`. |
| Pure-additive? | No for wholesale T5 branch | The branch modifies existing Lean theorem files and lakefile state. It must remain split/scoped, not wholesale-merged. |
| Compiles without old architecture? | Yes on T5 custody branch | `lake build` completed successfully with explicit `~/.elan/bin` PATH. |
| Preserves doctrine? | Yes, with custody caveat | T5 branch preserves the Primitive IR / Lean schema direction, but source custody for `tomdif/eml-lean` remains unresolved. |
| Spine class | Spine-critical | Lean schema authority and EML source custody gate certificate trust. |

## WRV Classification

- T5 custody branch: `verified-green`, `spine-critical`, `blocked-on-vendor-attestation`.
- Current main: `not-current-wired-for-T5-custody`, because the green Lean
  custody state has not landed on main.
- This PR: `status-only`, `no-code-mined`.

## Vendor Decision Still Needed

Before vendoring `tomdif/eml-lean`, require an explicit decision covering:

- source URL and exact commit/tag to vendor;
- license compatibility and attribution;
- storage form: vendored source directory, submodule, or pinned external fetch;
- manifest/hash attestation;
- offline `lake build` proof after vendoring;
- no hidden network fetches during normal verification.

Until that decision is made, keep `EML-LEAN-VENDOR` open and do not copy
external source into the repo.
