# T1 Tri-Fusion Closeout - 2026-05-17

Branch: `codex/t1-trifusion-2026-05-16`

This note is the T1 wind-down handoff for Claude. The user asked to stop after the current turn, so no new Tri-Fusion feature work should be started from this handoff unless explicitly requested.

## Last Pushed T1 Commits

- `35f922925 feat(tri-fusion): wire hyperdynamic projection shape`
- `c6afac221 docs(tri-fusion): reconcile doctrine with phase c state`
- `59ded876b test(tri-fusion): add round-trip corpus shards`
- `1be496d8f test(tri-fusion): harden swift provenance witness`
- `d71e19d20 test(tri-fusion): prove ffi provenance commit`
- `739ed2643 test(tri-fusion): prove provenance mirror commit`
- `a9ac16c04 test(tri-fusion): harden local agent mutation prompt`
- `19daab802 fix(tri-fusion): gate epdoc model-authored highlights`

## Verification Snapshot

- `cargo test --manifest-path agent_core/Cargo.toml --lib`
  - Passed: `1721 passed; 0 failed`
- `cargo test --manifest-path agent_core/Cargo.toml --features research --lib projection_shape`
  - Passed: 2 feature-gated Tri-Fusion/hyperdynamic integration tests
- `cargo test --manifest-path agent_core/Cargo.toml --features research --lib tri_fusion_projection_subset`
  - Passed: 3 hyperdynamic schema projection subset tests
- Swift FFI targeted verification passed earlier:
  - `./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/RustTriFusionDocumentClientTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM=`
  - Result: 5 Swift tests passed
  - Known warning during that run: `patch_mlx_metal_warnings.sh ... candidate_swiftlint_plugin_roots[@]: unbound variable`; tests still completed and passed.

## Landed State

- `agent_core/src/tri_fusion/mod.rs`
  - `TriFusionDocument`, `TriFusionMutation`, and `TriFusionWitness` exist.
  - Markdown, HTML, and JSON canonical subsets round-trip through JSON.
  - 240-document property corpus is sharded across 20 module tests.
  - Mutation witnesses carry before/after hashes and touched block IDs.
  - Provenance commits create ClaimLedger evidence and mirror a deterministic Cognitive DAG `DerivesFrom` edge.
  - Under `research`, `TriFusionDocument` can validate against hyperdynamic `DocumentShape`.
- `agent_core/src/bridge.rs`
  - Tri-Fusion opaque handle round-trips canonical JSON/Markdown/HTML.
  - Mutations and provenance mutation responses are exposed through Rust bridge tests.
- `Epistemos/LocalAgent/LocalToolGrammar.swift`
  - Tri-Fusion mutation grammar is present for `insert-block`, `mutate-block`, `link-block`, and `transclude-block`.
- `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift`
  - Prompt builder emits Tri-Fusion mutation contract and provenance requirements.
- `Epistemos/Engine/Epdoc*.swift`
  - Structured mutation receiver exists.
  - Model-authored block highlighting is gated to agent-authored blocks.
- `docs/fusion/TRI_FUSION_HYPERDYNAMIC_SCHEMAS_2026_05_17.md`
  - Doctrine doc was reconciled with current Phase C state.

## Final Code Slice

`35f922925` adds `DocumentShape::tri_fusion_projection_subset()` and feature-gated Tri-Fusion validation helpers:

- `DocumentShape::tri_fusion_projection_subset()`
  - Supports `heading`, `codeBlock`, `blockquote`, `bulletList`, `listItem`, and `transclusion`.
  - Requires stable nested paths for missing `heading.attrs.level` and `transclusion.attrs.id`.
- `TriFusionDocument::validate_dynamic_shape()`
- `TriFusionDocument::validate_projection_shape()`

The integration is deliberately behind `#[cfg(feature = "research")]` because `agent_core/src/lib.rs` only exposes `research` under that feature. Do not remove the cfg gates unless the module boundary changes.

## Remaining Gaps

- External `tests/tri_fusion_*.rs` fixtures are still open; the 240-document corpus currently lives in module tests.
- The projection subset does not yet cover tables, tasks, math, callouts, Mermaid, chart, image, link, highlight, or arbitrary custom node attrs.
- Hyperdynamic `FieldType` is still scalar-oriented; array/object attribute support needs careful schema design before richer Tri-Fusion attrs are modeled.
- Replay-bundle witness integration and failure-injection atomicity remain open.
- Manual retain/release leak accounting is still open because the UniFFI-facing lifecycle is handled through `Arc`.
- `docs/audits/HYPERDYNAMIC_SCHEMAS_AUDIT_2026_05_17.md` remains a historical Phase A audit. For latest Phase C state, read this closeout and `docs/fusion/TRI_FUSION_HYPERDYNAMIC_SCHEMAS_2026_05_17.md`.

## Worktree Warnings

- `syntax-core/target/...` contains generated build artifacts that are modified in the worktree. They were intentionally not staged.
- Do not touch prohibited T1-adjacent areas without an explicit new request: `vault.rs`, `InferenceState.swift` gating, `AmbientFrequency`, or biometric code.

## Suggested Next Slice

The safest continuation is either:

- promote the 240-document corpus into external `tests/tri_fusion_*.rs` fixture tests for acceptance artifact custody, or
- expand the feature-gated hyperdynamic projection only after adding tested array/object field support to `hyperdynamic_schemas`.

Avoid broad editor or provenance rewrites until the user explicitly resumes T1 work.
