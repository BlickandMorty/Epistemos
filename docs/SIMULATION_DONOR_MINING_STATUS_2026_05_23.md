---
state: simulation-donor-mining-status
created_on: 2026-05-23
worktree: /Users/jojo/Downloads/Epistemos-wrv-salvage
main_head: 24b5052cf2
donor_branch: worktree-simulation
donor_head: 3163b170d0
decision: no-code-mined
---

# Simulation Donor Mining Status - 2026-05-23

## Decision

Do not mine Simulation donor code in this pass.

M3 allowed only two narrow candidates:

1. AgentEvent normalizer
2. Applier sandbox guard

The AgentEvent/normalizer code is real, but it is not a pure compile
drop-in. The sandbox guard is valuable, but current `agent_core` does
not compile from `origin/main` with the explicit installed Rust
toolchain, so this pass cannot satisfy the "pure-additive and compiling"
bar. No source changes are left in the worktree.

## Candidate 1: AgentEvent Normalizer

Donor files sampled:

```text
worktree-simulation:agent_core/src/events.rs
worktree-simulation:agent_core/src/normalize/mod.rs
worktree-simulation:agent_core/src/normalize/hermes.rs
worktree-simulation:agent_core/src/normalize/anthropic.rs
worktree-simulation:agent_core/src/normalize/openai.rs
worktree-simulation:agent_core/src/normalize/kimi.rs
worktree-simulation:agent_core/src/normalize/local_mlx.rs
```

Findings:

- `events.rs` is a real event substrate: typed identifiers, event enum,
  graph-event proof vocabulary, Blake3 input hashes, tool events, and
  provider-neutral message/tool/graph/recovery events.
- `normalize/hermes.rs` is a real normalizer pattern and handles unknown
  methods as forward-compatible `Ok(None)`.
- The code imports Simulation companion types, including
  `crate::companions::{ActivityState, CompanionId, HeadShape, ProviderRole}`.
- The Hermes normalizer revives a retired namespace. Current doctrine
  after the Hermes purge does not allow bringing Hermes back as a live
  runtime path.
- Mining this cleanly would require deciding a current System G
  `AgentEvent` owner, renaming/reworking Hermes-specific pieces, adding
  root module exports, and likely adapting provider/runtime callers.

Donor-mining test:

| Question | Result |
|---|---|
| Unique vs main? | Yes. Current main has no root `agent_core/src/events.rs` or `agent_core/src/normalize/*`. |
| Pure-additive? | File-additive only. Behavior requires new exports and runtime ownership. |
| Compiles without old architecture? | No proof. It imports companion modules and Hermes naming. |
| Preserves current doctrine? | Not as-is. The provider-neutral pattern is useful; the Hermes/Simulation coupling is not. |
| Spine class | Spine-adjacent, blocked. |

Classification: **implemented-not-wired / blocked**.

Future safe scope: write a fresh System G `AgentEvent` spec or source
guard first, then port only provider-neutral event names and unknown
method handling. Do not import Simulation companions or Hermes-specific
runtime names.

## Candidate 2: Applier Sandbox Guard

Donor file sampled:

```text
worktree-simulation:agent_core/src/adapters/epbox.rs
```

Relevant donor behavior:

```text
open_epbox(root, vault_root)
- rejects non-directory roots
- canonicalizes root and vault_root
- rejects root when canonical_root does not start with canonical_vault
- validates manifest/content shape after the sandbox check
```

The guard is valuable because it prevents a user-controlled package path
from escaping the vault root via parent traversal or sibling-prefix
confusion. The surrounding `.epbox` parser and appliers are tied to the
Simulation companion gift-box model, so the only safely reusable piece is
the path-within-root guard.

I tested the salvage path by temporarily adding source-guard tests to
`agent_core/src/security.rs` for:

- child path accepted
- parent traversal rejected
- sibling prefix collision rejected
- unicode path accepted
- repeated call stable
- empty input rejected

That probe was not committed and has been removed.

## Compile Proof Attempt

Command:

```bash
cargo +stable-aarch64-apple-darwin test --manifest-path agent_core/Cargo.toml --lib sandbox_path --quiet
```

Result: failed before a mineable compile proof could be established.

Baseline blockers after removing the temporary sandbox tests:

```text
src/cache/mod.rs:328: unresolved import crate::tools::VariantId
src/tools_v2/legacy_adapter.rs:148: unresolved import crate::tools::runner
src/tools_v2/legacy_adapter.rs:149: unresolved import crate::tools::Status
src/tools_v2/reason_think.rs:115: unresolved import crate::tools::runner
src/tools_v2/reason_think.rs:116: unresolved import crate::tools::Status
src/tools_v2/reason_think.rs:161: unresolved import crate::tools::SchemaValidator
src/tools_v2/reason_think.rs:210: unresolved import crate::tools::SchemaValidator
src/tools_v2/v2_catalog/mod.rs:561: unresolved import crate::tools::Profile
src/skill_discovery/mod.rs:309: missing crate/module ulid
```

Because M3 requires "pure-additive and compiling", the sandbox guard was
not mined.

## WRV Classification

| Candidate | Classification | Reason |
|---|---|---|
| AgentEvent normalizer | blocked | No current caller chain and imports old Simulation/Hermes architecture. |
| Applier sandbox guard | blocked | Valuable and likely small, but compile proof is blocked by existing `agent_core` errors. |
| Simulation renderer/assets/UI | tangential/archive | Presentation surface, not spine-critical. |

## Next Safe Step

When `agent_core` compile is green again, the smallest safe sandbox-guard
salvage would be:

1. Add tests in `agent_core/src/security.rs` for child, parent traversal,
   sibling-prefix, unicode, repeated-call, and empty-input cases.
2. Add a generic function such as `validate_path_inside_root(path, root)`
   in `security.rs`.
3. Run the narrow `security` tests with explicit Rust toolchain.
4. Do not import `.epbox`, companion registry, applier modules, Hermes, or
   Simulation UI.

## Verification Performed

```bash
git show worktree-simulation:docs/simulation-mode/DOCTRINE.md | sed -n '1,140p'
git show worktree-simulation:agent_core/src/events.rs | sed -n '1,180p'
git show worktree-simulation:agent_core/src/normalize/hermes.rs | sed -n '1,220p'
git show worktree-simulation:agent_core/src/adapters/epbox.rs | sed -n '220,520p'
rg --files agent_core/src | rg '(^|/)(events|event_log|normalize|adapters|audit|simulation|companions|security)(/|\.rs$)'
cargo +stable-aarch64-apple-darwin test --manifest-path agent_core/Cargo.toml --lib sandbox_path --quiet
```

## Final M3 Status

M3 is closed as **blocked/status-only**. No Simulation code was mined.
