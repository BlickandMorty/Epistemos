# AI Stack Phase Audit Log

This file is the gate for the active local AI stack.

## Phase 0 — Decision Reset

Status: complete

What landed:

- the live target architecture was reduced to Apple Intelligence plus one Qwen local text lane
- DeepSeek/reasoner runtime routing was removed from live code
- the prepared model manifest no longer carries reasoner entries

What was validated:

- focused routing/runtime validation passed
- build passed

Next phase allowed:

- yes

## Phase 4.5 — Pre-Phase-5 Stabilization

Status: partial, audited

What landed:

- BTK result boundary cleanup
- QueryRuntime hot-path cleanup
- frame-paced UI token delivery
- first residency coordinator
- semantic fallback honesty
- plain chat now auto-resolves high-confidence note requests without requiring `@` note syntax
- DeepSeek/reasoner removal from live runtime state, tests, scripts, and manifest
- optional sidecar/worker routing has been removed from the live app
- in-process Qwen is now the only live local text path
- built retrieval indexes now load into the Rust engine as a real runtime store
- prepared semantic search now runs against that Rust store
- prepared retrieval execution state now reports `preparedIndexReady`
- prepared retrieval reranking now scores candidate page IDs inside Rust
- prepared retrieval asset layout now exposes explicit readiness and rebuild states
- Xcode Rust input tracking now includes `retrieval_index.rs`, so the app-linked static library rebuilds when retrieval runtime code changes

What was validated:

- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/TriageServiceTests -only-testing:EpistemosTests/RuntimeValidationTests`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/PipelineServiceTests -only-testing:EpistemosTests/TriageServiceTests`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LocalModelInfrastructureTests -only-testing:EpistemosTests/BlockEmbeddingTests -only-testing:EpistemosTests/RuntimeValidationTests`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/QueryRuntimeTests -only-testing:EpistemosTests/BlockEmbeddingTests -only-testing:EpistemosTests/RuntimeValidationTests`
- `cargo test retrieval_index --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml`

What is still open:

- Rust-native BGE execution
- real cross-encoder reranker runtime
- final retrieval lifecycle/rebuild policy
- deeper memory/KV/runtime hardening around the remaining local Qwen lane

Open risk:

- retrieval still has too much scaffolding relative to the final architecture
- the remaining local text path is simpler now, but it still needs more operational hardening before Phase 5

Next phase allowed:

- 4.5 may continue
- Phase 5 is still blocked
