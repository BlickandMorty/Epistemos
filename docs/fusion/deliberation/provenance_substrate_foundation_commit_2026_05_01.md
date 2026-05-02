# Provenance Substrate Foundation Commit - 2026-05-01

## Scope

This commit closes the core provenance substrate foundation only:

- Swift artifact/mutation/agent/graph provenance models.
- EventStore tables and APIs for mutation envelopes, mutation projection outbox rows, AgentEvents, and DurableGraphEvents.
- Rust artifact header/provenance mirrors and mutation envelope mirrors used by Swift parity guards.
- Rust OpLog append/iterate/tip/verify C ABI plus Swift owner, projection, replay, and worker primitives.
- Rust in-memory provenance ledger and deterministic replay bundle primitives.

## Explicit Non-Scope

- No protected editor or graph renderer files.
- No generated binding files.
- No Xcode project, entitlement, or bundle setting changes.
- No live AppBootstrap scheduling claim in this commit.
- No Settings UI wiring claim in this commit.
- No PipelineService, ChatCoordinator, Omega, hook, Halo, Theater, or live GraphEvent projection wiring.

## Verification

- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/EventStoreSchemaTests -only-testing:EpistemosTests/MutationEnvelopeParityTests -only-testing:EpistemosTests/ArtifactProvenanceParityTests test`
  - Log: `/tmp/epistemos-provenance-foundation-focused-xcode-20260501.log`
  - Result: 53 Swift Testing tests passed across 3 suites; Xcode reported `** TEST SUCCEEDED **`.
  - Known inherited noise: CodeEdit SwiftLint post-test commands still report failures after the successful test session.
- `cargo test --manifest-path agent_core/Cargo.toml oplog --lib`
  - Log: `/tmp/epistemos-provenance-foundation-oplog-cargo-20260501.log`
  - Result: 19 OpLog tests passed.
- `cargo test --manifest-path agent_core/Cargo.toml artifacts --lib`
  - Log: `/tmp/epistemos-provenance-foundation-artifacts-cargo-20260501.log`
  - Result: 17 artifact tests passed.
- `cargo test --manifest-path agent_core/Cargo.toml mutations --lib`
  - Log: `/tmp/epistemos-provenance-foundation-mutations-cargo-20260501.log`
  - Result: 15 mutation tests passed.
- `cargo test --manifest-path agent_core/Cargo.toml provenance --lib`
  - Log: `/tmp/epistemos-provenance-foundation-provenance-cargo-20260501.log`
  - Result: 24 provenance tests passed.
- `git diff --check` on the exact staged implementation/test set passed.
