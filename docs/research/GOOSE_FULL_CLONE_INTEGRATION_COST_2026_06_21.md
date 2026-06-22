# Goose full-clone integration cost — grounded finding (2026-06-21)

**Owner directive (addendum §446-448):** vendor block/goose as a REAL Cargo dependency — STOP
hand-porting `Role`/`Message`/`permission`/`recipe`/`retry` one at a time (the current
`agent_core/src/work.rs` `vendored_goose` leaf-ports, already SUPERSEDED-banner'd). The
integration cost is ACCEPTED, BUT (§446-460) heavy vendors are done "**where the build can
iterate — do NOT commit to main red**."

## What was inspected (real, not assumed)
Shallow-cloned `block/goose` (660 MB, 2,440 files) and read the workspace + Cargo manifests.
Workspace crates: `goose`, `goose-cli`, `goose-mcp`, `goose-providers`, `goose-server`,
`goose-sdk`, `goose-sdk-types`, `goose-test*`, `goose-acp-macros`.

### Where the leaf-ported types actually live
- **`goose-sdk-types`** is LIGHT (`serde` + `schemars` + `agent-client-protocol`) — but it holds
  only ACP custom notifications/requests. It does **NOT** contain `Role`/`Message`/`Permission`/
  `Recipe`/`RetryConfig`.
- Those types live in the **`goose` crate** (and some in `goose-providers`) — the **heavy
  runtime** crate: **179 dependency lines**, incl. `tokio`, `reqwest`, `rmcp`, `sqlx`, `oauth2`,
  `smithy-transport-reqwest`.

### The concrete blocker: dependency-graph clashes with agent_core
| dep | agent_core | goose | impact |
|-----|-----------|-------|--------|
| **reqwest** | **0.12** | **0.13.2** | **incompatible MAJOR versions** — Cargo compiles BOTH; types don't cross the boundary; the real reconciliation cost |
| rmcp | (work seam's pin) | 1.4 | feature/version split to reconcile |
| tokio | 1.43 | 1.48 | unifies, but feature-set differences |
| sqlx/oauth2/smithy | — | present | large new transitive surface |

## Verdict (honest sequencing — lower-but-CERTAIN, NOT dropped)
Vendoring the heavy `goose` crate as a real dep is a **multi-iteration, build-red-prone**
integration (reqwest 0.12→0.13 reconciliation + a 179-dep graph), and 660 MB of vendored source.
That is **not** a single green-only main-loop iteration. Per the owner's own rule it belongs in a
**dedicated build-iteration context** (worktree / branch the build can go red on), exactly like the
dual-MLX consolidation was done — not committed red to main.

**Until then:** the `work.rs` `vendored_goose` leaf-ports remain the HONEST interim (clearly
SUPERSEDED-banner'd, isolated, Chat/Act unchanged). They are not "done" and not "dropped" — they
are the placeholder the real-crate vendor replaces when it gets its iterate-able context.

**Recommended path when that context exists:**
1. Vendor `block/goose` into `agent_core/vendor/goose` (or a worktree).
2. Add `goose` as a path dep behind a `goose-clone` Cargo feature (OFF by default → `mas-build`
   stays green).
3. Reconcile reqwest (move agent_core to 0.13, or isolate goose behind an FFI/process boundary so
   the reqwest majors don't have to unify).
4. Replace the leaf-ports with re-exports of the real `goose` types; delete `vendored_goose`.
5. `cargo build --features goose-clone` green → land.

(OpenCode's runtime is a parallel heavy vendor — Bun/Node bundle into `Resources/opencode-runtime/`,
needs the Bun toolchain + a build-phase step; the Swift seam/terminal/resolver already go LIVE the
moment that bundle is dropped in.)
