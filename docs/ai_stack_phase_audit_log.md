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
- prepared retrieval reranking now scores candidate page IDs inside Rust, but this is still similarity-based rescoring rather than the final cross-encoder runtime
- prepared retrieval asset layout now exposes explicit readiness and rebuild states
- Xcode Rust input tracking now includes `retrieval_index.rs`, so the app-linked static library rebuilds when retrieval runtime code changes
- prepared retrieval runtime configuration now refreshes on app activation instead of requiring a relaunch to pick up newly built assets
- prepared semantic search and similarity reranking now share a cached prepared-index load boundary instead of reloading the same manifest on every query turn
- prepared retrieval cache invalidation now keys on manifest content, not just manifest path, so in-place rebuilds can reload the Rust store instead of staying stale
- graph inspector summaries still try Apple Intelligence first and only fall back to local Qwen when needed
- graph semantic clustering remains intentionally disabled on the prepared runtime until the semantic embedding space is fully unified

What was validated:

- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/TriageServiceTests -only-testing:EpistemosTests/RuntimeValidationTests`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/PipelineServiceTests -only-testing:EpistemosTests/TriageServiceTests`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LocalModelInfrastructureTests -only-testing:EpistemosTests/BlockEmbeddingTests -only-testing:EpistemosTests/RuntimeValidationTests`
- `xcodebuild -project /Users/jojo/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/QueryRuntimeTests -only-testing:EpistemosTests/BlockEmbeddingTests -only-testing:EpistemosTests/RuntimeValidationTests`
- `cargo test retrieval_index --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml`

What is still open:

- Rust-native BGE query embedding execution (Swift still owns prepared query vectors today)
- real cross-encoder reranker runtime
- final retrieval lifecycle/rebuild policy
- deeper memory/KV/runtime hardening around the remaining in-process Qwen lane

Open risk:

- retrieval still depends on Swift-owned query embeddings and similarity rescoring relative to the final architecture
- the remaining local text path is simpler now, but it still needs more operational hardening before Phase 5

Next phase allowed:

- 4.5 may continue
- Phase 5 is still blocked
