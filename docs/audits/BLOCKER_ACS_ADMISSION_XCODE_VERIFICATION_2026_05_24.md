# Blocker — ACS Admission Xcode Verification

## Summary

Terminal E Rust verification passes on latest `main`, but targeted Xcode verification hit three consecutive build failures. Per the stop rule, no fourth Xcode attempt was run.

## Passing Checks

- PASS: `rustup run stable cargo test --manifest-path agent_core/Cargo.toml --test r5_acs_tool_handoff`
- PASS: `rustup run stable cargo test --manifest-path agent_core/Cargo.toml --test r4_acs_audit_snapshot_helper --test acs_admission_bridge`
- PASS: `rustup run stable cargo build --manifest-path agent_core/Cargo.toml --no-default-features --features pro-build,lsp-runtime --target x86_64-apple-darwin`

## Failed Xcode Attempts

Command shape for all attempts:

```sh
./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/CloudKnowledgeDistillationTests -only-testing:EpistemosTests/ProvenanceConsoleSourceGuardTests -only-testing:EpistemosTests/SearchFusionHealthRowTests test CODE_SIGNING_ALLOWED=NO -quiet
```

1. DerivedData `/tmp/EpistemosTerminalEACSRev2`, result bundle `build/xcode-results/2026-05-23-231959-82228.xcresult`.
   Failure: Swift clients could not find generated UniFFI wrapper functions (`produceAnswerPacketJson`, `cognitiveDagStatsJson`, LSP functions, provenance functions). The generated `build-rust/swift-bindings/agent_core.swift` existed after the build phase but was not in the first Xcode source filelist. Retrying after generation moved past this.

2. DerivedData `/tmp/EpistemosTerminalEACSRev2b`, result bundle `build/xcode-results/2026-05-23-232907-1953.xcresult`.
   Failure: `ChatCoordinator+EidosCitationGate.swift` called `EidosBridge.validateCitations(packet:sourceIds:)` from a nonisolated static method, while Swift 6 default isolation treated the extension method as `MainActor`.
   Mitigation applied: `Epistemos/Eidos/EidosBridge.swift` now marks the production static bridge methods and logger as `nonisolated`.

3. DerivedData `/tmp/EpistemosTerminalEACSRev2c`, result bundle `build/xcode-results/2026-05-23-233611-14264.xcresult`.
   Failure: `EpistemosTests/CloudKnowledgeDistillationTests.swift:565` calls the helper `makeNote(...)` from inside the synchronous nonisolated `sourceNotesProvider` closure. Under Swift 6 default isolation, the helper is main-actor isolated.

## Likely Next Fix

Make the CSI gate test's source note construction actor-correct before running Xcode again. The lowest-risk fix is to construct the `KnowledgeSourceNote` outside `sourceNotesProvider` and have the closure return the prebuilt value, or mark the helper `makeNote(...)` `nonisolated` if all of its inputs and return type are safe for that isolation.

After that fix, rerun the same targeted Xcode command once.

## Stop Rule

This file is the required blocker doc after three consecutive Xcode build/test failures. No success is claimed for Swift/Xcode verification.
