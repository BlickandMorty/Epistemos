# Agent Runtime Audit — 2026-05-17

Scope: T2 §4.E + §4.F Phase A, iteration 1. This is a read-only substrate audit of the in-process local/cloud agent runtime, model gating, grammar wiring, and AnswerPacket emission path.

## §5.0 Evidence

- `git status --short --branch`: clean on `codex/t2-agent-2026-05-16` before edits.
- `wc -l agent_core/src/agent_runtime/*.rs agent_core/src/agent_loop.rs agent_core/src/bridge.rs agent_core/src/session.rs agent_core/src/providers/*.rs Epistemos/LocalAgent/*.swift Epistemos/State/InferenceState.swift Epistemos/Engine/LocalModelInfrastructure.swift Epistemos/App/AppBootstrap.swift Epistemos/Bridge/StreamingDelegate.swift`: 29,425 LOC across the required runtime surfaces.
- `agent_core/src/agent_runtime/`: 766 LOC across `function_call.rs`, `prompt_format.rs`, `procedural_memory.rs`, `self_evolution.rs`, `skills.rs`, `mod.rs`.
- `git log --follow` anchors: `LocalModelInfrastructure.swift` and `AppBootstrap.swift` last changed by `15cc2ced4 feat(model-gating): power-user mode override + runtime gate probe`; `StreamingDelegate.swift` carries `7a00db484` AnswerPacket first wiring and `c0c14f98e` Option-B id binding.
- `cargo test --manifest-path agent_core/Cargo.toml --lib`: PASS, 1671 passed, 0 failed, 2 dead-code warnings.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`: first clean-ish pass failed on generated input ordering for `build-rust/swift-bindings/omega_ax.swift`; immediate incremental rerun PASS. Rerun also proved `CMLXStructured` imports into the app target by generating `CMLXStructured-*.pcm`.

## Runtime Inventory

| Surface | Current reality | Audit state |
|---|---|---|
| `agent_core::agent_runtime::function_call` | Parses and incrementally detects Hermes-format `<tool_call>` JSON, skips `<think>` and `<scratch_pad>`, handles malformed `<tool_call<` prefix. | SHIPPED, single grammar family |
| `agent_core::agent_runtime::prompt_format` | Builds canonical `<tools>` / `<tool_call>` system prompt and canonicalizes tool names through the registry alias table. | SHIPPED, XML/Hermes-format parity only |
| `agent_core::agent_runtime::procedural_memory` | SQLite procedure outcome store with recency/similarity recall; mirrors writes into Cognitive DAG dispatch. | SHIPPED, local deterministic |
| `agent_core::agent_runtime::self_evolution` | Detects repeated successful tool sequences and proposes reviewable learned skills. | SHIPPED substrate, no UI promotion loop audited in this slice |
| `agent_core::agent_runtime::skills` | Re-exports existing skill router/store/tool surfaces. | PARTIAL; stale comment still says `agent_core::hermes::skills` |
| `agent_core/src/agent_loop.rs` | Cloud provider loop streams deltas, preserves thinking/tool blocks, runs approval gates, writes `TranscriptTurn` and `TraceEvent` through `GlobalSessions`. | SHIPPED cloud loop; no first-class AnswerPacket trace event yet |
| `agent_core/src/session.rs` + `storage/session_store.rs` | Session folders persist `session.json`, `transcript.jsonl`, `trace.json`, and structured summaries. | SHIPPED; this is closest current RunEventLog substitute |
| `agent_core/src/providers/*` | Claude, OpenAI, OpenAI-compatible, Gemini, Perplexity stream provider-native events. | SHIPPED cloud-native grammars for supported providers |
| `Epistemos/LocalAgent/LocalToolGrammar.swift` | Strict decoding is behind `canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)`; fallback is always-on soft guidance. | PARTIAL; no per-model family switch |
| `Epistemos/LocalAgent/LocalAgentLoop.swift` | Local loop uses soft/strict plan, streaming tool-call detector, repair prompts, synthetic file-call rescue, and local tool execution. | SHIPPED local loop, single prompt grammar |
| `Epistemos/LocalAgent/ConfidenceRouter.swift` | Routes by complexity/current-info/code-exec/privacy and `canActAsAgent`. | PARTIAL; no task-class constellation, no idle unload policy |

## AnswerPacket Runtime Emission

Current code is better than the stale critique but still not at the §4.F B1 acceptance bar.

- `StreamingDelegate.onComplete` builds an `AnswerPacket.turnCompletionStub`, emits it to `AnswerPacketEmitter.shared`, then yields `.complete(... answerPacketId: packet.id ...)`.
- `ChatState.completeProcessing` and `AgentChatState.completeProcessing` accept `answerPacketId` and stamp it onto live `ChatMessage`.
- `MessageBubble.AnswerPacketChipRow` can render chips by resolving the id against `LatestAnswerPacketSink.shared`.
- `SDMessage` has no `answerPacketId` property, no encoded packet payload, and `SDMessage.chatMessage(chatId:)` cannot restore a packet id. Scrollback therefore loses the binding.
- `agent_core/src/storage/session_store.rs` has `TranscriptTurn` and `TraceEvent`, but neither carries AnswerPacket id, VRM label, claim kind, citation ids, or packet JSON.

Verdict: **PARTIAL**. Runtime emission exists for the live Rust-stream completion path, but durable SDChat/SDMessage persistence and run-log emission are missing. B1 next slice should add `SDMessage.answerPacketId`, persist/restore it, and then add a bounded packet JSON or run-log event so replay can survive process restart.

## Local Agent Excellence Gaps

1. **Per-model native grammars are absent.** Qwen/Hermes XML is the only live local prompt grammar. DeepSeek, Llama, Mistral, Phi, and LocalAgent families are not independently described or validated.
2. **Router is not yet a constellation.** `ConfidenceRouter` does not expose task classes such as code, planning, quick chat, tool-caller, retrieval ranking, or vision, and it has no warm/hot/cold model state.
3. **Strict grammar status is not user-visible.** `AnswerPacketHealthRow` exists, but Settings has no strict grammar row, schema-drift row, or constellation-health row.
4. **AgentBlueprint UI is not present in the audited settings/chat paths.** Agent control exists, but the requested name/role/model/tools/scope/approval blueprint flow is not wired to a `MissionPacket`.
5. **Run timeline/replay is not present.** Session folders persist trace/transcript data; no Swift timeline UI or replay reader was found in the scoped files.
6. **Naming hygiene drift remains.** There is no `agent_core::hermes` module, but `open_hermes_procedural_memory`, `execute_hermes_skill_step`, `HermesLocalAgentCompatibility.swift`, and stale comments keep compatibility vocabulary alive. These are not subprocess resurrection, but they should be classified as compatibility shims or renamed in a later cleanup slice.

## Runtime Probe Capture

Probe source: `Epistemos/App/AppBootstrap.swift` logs `Local agent model selected:` and `Local model gating probe:` using `LocalToolGrammar.supportsStructuredToolCalling`, `supportsSoftGuidanceToolCalling`, `supportsLocalAgentLoop`, `inference.cloudModelsEnabled`, and configured providers.

Capture command: launched `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-drqatsahnuzlqudfoowzgnoffiqw/Build/Products/Debug/Epistemos.app` and streamed `/usr/bin/log stream --info --style compact` for `process == "Epistemos"`, `subsystem == "com.epistemos"`, `category == "app"`.

```text
2026-05-17 07:10:36.193 I  Epistemos[97644:1484dde] [com.epistemos:app] Local agent model selected: Qwen 3 8B, ~4.000000 GB (host 18 GB, 36B opt-in min 32 GB, power-user mode OFF)
2026-05-17 07:10:36.193 I  Epistemos[97644:1484dde] [com.epistemos:app] Local model gating probe: strict-tool-grammar=ACTIVE, soft-guidance=ON, local-agent-loop=OK, cloud-models=ON, configured-cloud-providers=
2026-05-17 07:10:36.193 I  Epistemos[97644:1484dde] [com.epistemos:app] AppBootstrap: initialized — local AI stack ready
```

Interpretation: strict grammar is not dead-gated on this build; `MLXStructured`, `CMLXStructured`, and `JSONSchema` all resolve in the app target. The user-facing gating issue is now primarily policy/UI: agent visibility still uses strict grammar, but the fallback loop is live, and the power-user RAM override remains hidden unless set directly in UserDefaults.

## Next Slice

Phase A iter 2 should convert this probe into visible diagnostics: Settings rows for strict-grammar status, schema-drift status, and active constellation. The highest-value code slice after Phase A is B1 persistence: `SDMessage.answerPacketId` + restore into `ChatMessage` + a trace event row for AnswerPacket emission.
