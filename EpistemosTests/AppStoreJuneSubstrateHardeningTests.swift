import Foundation
import Testing

@Suite("App Store June substrate hardening")
struct AppStoreJuneSubstrateHardeningTests {
    @Test("App Store June model catalog keeps local chat and cloud thinking honest")
    func appStoreJuneModelCatalogKeepsLocalChatAndCloudThinkingHonest() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let source = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentModelCatalog.swift")
        let inference = try loadMirroredSourceTextFile("Epistemos/State/InferenceState.swift")
        let modelsPayload = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: source,
            startingAt: "static func modelsPayload(",
            endingBefore: "static func cloudCapabilities("
        ))

        #expect(
            modelsPayload.contains(#""capabilities": [String](),"#),
            "MAS local Apple/GGUF rows must stay chat-tier and must not advertise tool/function-calling capabilities."
        )
        #expect(
            modelsPayload.contains(#""compact-context""#),
            "MAS local rows must carry the compact-context trait so Prompt Forge/UI can optimize for lower context windows."
        )
        #expect(
            gateway.contains("let ramProblem = GGUFModelCatalog.ramGate(for: entry)")
                && source.contains("No download will start")
                && gateway.contains("guard GGUFModelCatalog.ramGate(for: entry) == nil else { return }")
                && gateway.contains(#"can't run on this Mac. \(ramProblem.userCopy)"#),
            "June must make oversized GGUF rows honest before download/selection, not only after llama.cpp tries to load them."
        )
        #expect(
            source.contains("static func cloudCapabilities(")
                && source.contains("model.supportedOperatingModes.contains(.thinking)")
                && source.contains(#""supportsReasoningDeltas""#)
                && source.contains("model.supportsNativeReasoningEffortControl")
                && source.contains("private static func genericCloudCapabilities(")
                && source.contains(#""capabilities": genericCloudCapabilities(preferredConfiguredCloudModel)"#)
                && gateway.contains("preferredConfiguredCloudModel()?.rawValue")
                && source.contains(#"return ["supportsFunctionCalling"]"#),
            "June cloud model rows must expose thinking/reasoning from the Swift model truth source, not from descriptive copy."
        )
        #expect(
            gateway.contains("preferredConfiguredCloudModelID() ?? JuneModelID.cloud")
                && gateway.contains("first send fails honestly with cloudNotConfigured")
                && !gateway.contains("Best runnable local lane first"),
            "June's MAS default must stay cloud-first; local chat is the secondary privacy/offline lane and must not be the silent default."
        )
        #expect(
            modelsPayload.contains(#""name": "Cloud Agent""#)
                && modelsPayload.contains("configured OpenAI or Anthropic account")
                && modelsPayload.contains("receipt-gated Epistemos Cloud proxy is retained as scaffolding")
                && !modelsPayload.contains("Requires an active subscription"),
            "The generic June cloud row must not advertise the retained receipt-gated proxy as the active MAS route."
        )
        #expect(
            inference.contains("case .zaiGLM52, .zaiGLM5, .zaiGLM5Turbo, .zaiGLM47, .zaiGLM47Flash,")
                && inference.contains(".zaiGLM45Flash:")
                && inference.contains("case .openAI, .anthropic, .google, .zai:")
                && inference.contains(#"return tier == .heavy ? "Max" : tier.displayName"#),
            "GLM rows with Rust Z.AI thinking/effort extensions must expose native effort controls; Kimi keeps native thinking request support in Rust without fabricating low/medium/high UI effort tiers."
        )
    }

    @Test("App Store June RuntimeRouter is cloud-first, witnessed, and local-chat honest")
    func appStoreJuneRuntimeRouterIsCloudFirstWitnessedAndLocalChatHonest() throws {
        let router = try loadMirroredSourceTextFile("Epistemos/LocalAgent/RuntimeRouter.swift")
        let confidence = try loadMirroredSourceTextFile("Epistemos/LocalAgent/ConfidenceRouter.swift")
        let routeProfiles = try loadMirroredSourceTextFile("Epistemos/State/InferenceState+RouteProfiles.swift")
        let lanesSection = try loadMirroredSourceTextFile("Epistemos/Views/Settings/RuntimeLanesSection.swift")
        let policyOrderGuard = try loadMirroredSourceTextFile("agent_core/tests/runtime_router_policy_order_source_guard.rs")
        let toolCaller = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: router,
            startingAt: "case .toolCaller:",
            endingBefore: "case .trivial:"
        ))
        let openAI = try #require(toolCaller.range(of: #".cloud(provider: "openai")"#))
        let claude = try #require(toolCaller.range(of: #".cloud(provider: "claude")"#))
        let apple = try #require(toolCaller.range(of: ".appleIntelligence"))
        let gguf = try #require(toolCaller.range(of: ".gguf"))

        #expect(
            router.contains("modelPreferenceTable")
                && router.contains(#""june.cloud-first.agent""#)
                && openAI.lowerBound < apple.lowerBound
                && claude.lowerBound < apple.lowerBound
                && openAI.lowerBound < gguf.lowerBound
                && claude.lowerBound < gguf.lowerBound,
            "June's RuntimeRouter must prefer agentic cloud lanes before local chat fallback."
        )
        #expect(
            router.contains("toolCallMode: .none")
                && router.contains("grammarSupport: []")
                && router.contains("case .gguf:")
                && router.contains("if request.requiresTools && capability.toolCallMode == .none")
                && router.contains(".toolCallGrammarUnsupported"),
            "The local Apple/GGUF lanes must remain chat-tier and reject tool/grammar demands unless a real deterministic lane is admitted."
        )
        #expect(
            router.contains(#"let agenticCloud = provider == "openai" || provider == "claude""#)
                && router.contains("toolCallMode: agenticCloud ? .native : .none")
                && router.contains(#"grammarSupport: agenticCloud ? ["provider_native_tools"] : []"#),
            "RuntimeRouter cloud capability must not promote every cloud provider to the full agentic tool lane."
        )
        #expect(
            router.contains("RouteVerdict")
                && router.contains("recordAccept(verdict, role: packet.role)")
                && router.contains("recordReject(role: packet.role, reason: reason)")
                && router.contains("RuntimeRouter witness lanes do not execute model requests."),
            "RuntimeRouter must be a witnessed routing substrate, not a hidden executor or fallback."
        )
        #expect(
            confidence.contains("RuntimeRouter.defaultRouteProfiles().map")
                && routeProfiles.contains("RuntimeRouter.defaultRouteProfiles()")
                && lanesSection.contains("RuntimeLane.knownLanes.filter { $0 != .stub }")
                && lanesSection.contains("router.setLaneEnabled(lane, newValue)"),
            "Diagnostics and lane toggles must read the router's policy table instead of maintaining placeholders."
        )
        #expect(
            policyOrderGuard.contains("tool_caller_chain_keeps_agentic_cloud_before_local_chat_fallback")
                && policyOrderGuard.contains("current MAS routing must not reintroduce local MLX tool lanes"),
            "Rust source guards must enforce the current cloud-first MAS mandate, not the retired local-first tool-caller chain."
        )
    }

    @Test("App Store June agent_core cloud path preserves native thinking deltas")
    func appStoreJuneAgentCoreCloudPathPreservesNativeThinkingDeltas() throws {
        let runner = try loadMirroredSourceTextFile("Epistemos/Goose/GooseInProcessACPServer.swift")
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let openAI = try loadMirroredSourceTextFile("agent_core/src/providers/openai.rs")
        let claude = try loadMirroredSourceTextFile("agent_core/src/providers/claude.rs")
        let gemini = try loadMirroredSourceTextFile("agent_core/src/providers/gemini.rs")
        let openAICompatible = try loadMirroredSourceTextFile("agent_core/src/providers/openai_compatible.rs")

        #expect(
            runner.contains("enableThinking: true")
                && runner.contains(#"effort: "high""#)
                && runner.contains("func onThinkingDelta(thought: String)")
                && runner.contains("emit(.thinkingDelta(thought))"),
            "June's in-process MAS runner must request thinking and forward delegate thinking callbacks."
        )
        #expect(
            bridge.contains("Ok(StreamEvent::ThinkingDelta { text, .. })")
                && bridge.contains("delegate.on_thinking_delta(text)"),
            "agent_core bridge must forward provider thinking stream events to the Swift delegate."
        )
        #expect(
            openAI.contains("response.reasoning_summary_text.delta")
                && openAI.contains("visible_reasoning_delta_ignores_raw_responses_reasoning_text"),
            "OpenAI Responses thinking must surface model-provided summaries while filtering raw private reasoning text."
        )
        #expect(
            openAI.contains("pub fn gpt53_codex()")
                && openAI.contains(#""gpt-5.3-codex""#)
                && openAI.contains("provider_native_thinking_gpt5_request_body_includes_summary_controls")
                && bridge.contains(#""openai_gpt53_codex" => Ok(Arc::new(OpenAIProvider::gpt53_codex()))"#)
                && runner.contains(#"if lower.contains("gpt-5.3-codex") { return "openai_gpt53_codex" }"#),
            "Codex/GPT-5 model picker rows must route to native OpenAI reasoning models, not collapse to a legacy GPT-4o alias."
        )
        #expect(
            claude.contains("DeltaData::ThinkingDelta")
                && claude.contains("StreamEvent::ThinkingDelta"),
            "Anthropic/Claude thinking blocks must remain native StreamEvent::ThinkingDelta events."
        )
        #expect(
            gemini.contains("includeThoughts")
                && gemini.contains("part.thought == Some(true)")
                && gemini.contains("stream_chunk_exposes_thought_parts_as_thinking_delta"),
            "Gemini thought parts must request and preserve native thinking deltas."
        )
        #expect(
            openAICompatible.contains("openai_compatible_reasoning_delta_text")
                && openAICompatible.contains("reasoning_content")
                && openAICompatible.contains("kimi_stream_chunk_exposes_reasoning_content_as_thinking_delta")
                && openAICompatible.contains("provider_native_thinking_kimi_k27_code_uses_native_thinking_parameter")
                && openAICompatible.contains("provider_native_thinking_zai_request_extension_maps_thinking_and_effort")
                && openAICompatible.contains("RequestExtension::ZaiThinking"),
            "Kimi/ZAI/OpenAI-compatible reasoning fields must be routed into thinking deltas when providers emit them."
        )
        #expect(
            runner.contains(#"return lower.contains("reasoner") ? "deepseek_reasoner" : "deepseek""#)
                && bridge.contains(#""deepseek_reasoner""#)
                && bridge.contains("provider_native_thinking_explicit_deepseek_reasoner_override_is_supported")
                && openAICompatible.contains("pub fn deepseek_reasoner()")
                && openAICompatible.contains(#""deepseek-reasoner""#)
                && openAICompatible.contains("provider_native_thinking_deepseek_chat_and_reasoner_are_distinct"),
            "DeepSeek Reasoner rows must route to the reasoning constructor instead of collapsing to the generic non-thinking DeepSeek chat model."
        )
    }

    @Test("App Store June redacts vault roots from tool and approval payloads")
    func appStoreJuneRedactsVaultRootsFromToolAndApprovalPayloads() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let vaultScope = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentCoreVaultScope.swift")
        let toolBounds = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneToolEventBounds.swift")
        let vaultPath = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: vaultScope,
            startingAt: "static func vaultPathForAgentCore",
            endingBefore: "static func redactedVaultRootCandidates"
        ))
        let vaultRedaction = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: vaultScope,
            startingAt: "static func redactedVaultRootCandidates",
            endingBefore: "#endif"
        ))
        let eventLoop = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "case .toolStarted(let id, let name, let inputJson):",
            endingBefore: "case .complete(let stopReason"
        ))
        let redaction = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: toolBounds,
            startingAt: "static func boundedToolPayload",
            endingBefore: "#endif"
        ))

        #expect(
            eventLoop.contains("let boundedInput = JuneToolEventBounds.boundedToolPayload(inputJson)")
                && eventLoop.contains(#""input_json": boundedInput"#)
                && eventLoop.contains("let boundedResult = JuneToolEventBounds.boundedToolPayload(result)")
                && eventLoop.contains(#""result": boundedResult"#)
                && eventLoop.contains(#""input_json": JuneToolEventBounds.boundedToolPayload(inputJson)"#)
                && eventLoop.contains("JuneToolEventBounds.approvalDescription("),
            "June must redact and bound tool inputs/results and approval input_json before forwarding agent events to webview JS."
        )
        #expect(
            toolBounds.contains("static let maxToolEventIDBytes = 128")
                && toolBounds.contains("static let maxToolNameBytes = 128")
                && toolBounds.contains("static let maxToolRiskLevelBytes = 64")
                && toolBounds.contains("static func boundedToolMetadata")
                && toolBounds.contains("static func boundedToolProtocolID")
                && toolBounds.contains("static func isBoundedToolProtocolID")
                && gateway.contains("JuneToolEventBounds.isBoundedToolProtocolID(requestID)")
                && eventLoop.contains("guard let toolID = JuneToolEventBounds.boundedToolProtocolID(id) else { break }")
                && eventLoop.contains("let toolName = JuneToolEventBounds.boundedToolMetadata(")
                && eventLoop.contains("maxBytes: JuneToolEventBounds.maxToolNameBytes")
                && eventLoop.contains("guard !toolName.isEmpty else { break }")
                && eventLoop.contains("let explicitToolName = JuneToolEventBounds.boundedToolMetadata(")
                && eventLoop.contains(#"toolCalls.first { $0.id == toolID }?.name ?? "tool""#)
                && eventLoop.contains(#""tool_call_id": toolID"#)
                && eventLoop.contains(#""tool_name": toolName"#)
                && eventLoop.contains("let boundedToolName = JuneToolEventBounds.boundedToolMetadata(")
                && eventLoop.contains("let boundedRiskLevel = JuneToolEventBounds.boundedToolMetadata(")
                && eventLoop.contains("maxBytes: JuneToolEventBounds.maxToolRiskLevelBytes")
                && eventLoop.contains("guard !boundedRiskLevel.isEmpty else")
                && eventLoop.contains(#""tool_name": boundedToolName"#)
                && eventLoop.contains(#""risk_level": boundedRiskLevel"#),
            "Tool ids, names, and approval risk labels must be bounded before live JS events, approval descriptions, and durable replay."
        )
        #expect(
            vaultPath.contains("if let selectedVaultPath = watchedVaultPathForAgentCore()")
                && vaultPath.contains("return agentCoreScratchURL().path")
                && gateway.contains("vaultPath: JuneAgentCoreVaultScope.vaultPathForAgentCore()")
                && vaultScope.contains(".applicationSupportDirectory")
                && vaultScope.contains("Epistemos/JuneAgent/agent-core-scratch")
                && !vaultScope.contains("ProcessInfo.processInfo.environment")
                && !vaultScope.contains("EPISTEMOS_VAULT_PATH")
                && !vaultScope.contains("VAULT_PATH"),
            "June agent_core vault pathing must use only the selected watched vault or an app-support scratch vault, never ambient environment paths."
        )
        #expect(
            redaction.contains("maxToolPayloadBytes")
                && redaction.contains("toolPayloadTruncationMarker")
                && redaction.contains("let roots = JuneAgentCoreVaultScope.redactedVaultRootCandidates()")
                && redaction.contains("let lookaheadBytes = roots.reduce(0)")
                && redaction.contains("let scanLimit = maxToolPayloadBytes + lookaheadBytes")
                && redaction.contains("truncateUTF8(value, maxBytes: scanLimit, appendMarker: false)")
                && redaction.contains("redactKnownVaultRoots(in: scanned, roots: roots)")
                && redaction.contains("truncateUTF8(redacted, maxBytes: maxToolPayloadBytes")
                && redaction.contains("value.utf8.count > maxToolPayloadBytes")
                && vaultRedaction.contains("watchedVaultPathForAgentCore()")
                && vaultRedaction.contains("agentCoreScratchURL(createDirectory: false)")
                && vaultRedaction.contains("rootRedactionForms(for:")
                && vaultRedaction.contains(".standardizedFileURL")
                && vaultRedaction.contains(".resolvingSymlinksInPath()")
                && vaultRedaction.contains(".absoluteString")
                && vaultRedaction.contains("addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)")
                && vaultRedaction.contains("unique.sorted")
                && vaultRedaction.contains("left.count == right.count ? left < right : left.count > right.count")
                && !redaction.contains("ProcessInfo.processInfo.environment")
                && !redaction.contains("EPISTEMOS_VAULT_PATH")
                && !redaction.contains("VAULT_PATH")
                && !vaultRedaction.contains("ProcessInfo.processInfo.environment")
                && !vaultRedaction.contains("EPISTEMOS_VAULT_PATH")
                && !vaultRedaction.contains("VAULT_PATH")
                && redaction.contains(#"replacingOccurrences(of: path, with: "[vault]")"#)
                && redaction.contains("let bodyLimit = max(0, maxBytes - marker.utf8.count)")
                && redaction.contains("candidate.utf8.count > bodyLimit")
                && redaction.contains("let bounded = boundedToolPayload(inputJson)"),
            "Tool/approval payload redaction must cover raw, file-url, percent-encoded, and symlink-resolved selected/scratch roots, with byte-bounded truncation before JS exposure."
        )
    }

    @Test("App Store June persists reasoning and tool replay fields")
    func appStoreJunePersistsReasoningAndToolReplayFields() throws {
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let store = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneSessionStore.swift")
        let eventLoop = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: gateway,
            startingAt: "var full = \"\"",
            endingBefore: "} catch {"
        ))
        let messagesPayload = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: store,
            startingAt: "func messagesPayload(sessionID: String)",
            endingBefore: "return [\"messages\": rows]"
        ))

        #expect(
            store.contains("let reasoning: String?")
                && store.contains("let toolCalls: String?")
                && store.contains("let toolCallID: String?")
                && store.contains("let toolName: String?")
                && store.contains("let answerPacketID: String?"),
            "June's durable session store must retain Hermes-compatible reasoning/tool/AnswerPacket fields, not only assistant text."
        )
        #expect(
            messagesPayload.contains(#"row["reasoning"] = reasoning"#)
                && messagesPayload.contains(#"row["reasoning_content"] = reasoning"#)
                && messagesPayload.contains(#"row["tool_calls"] = toolCalls"#)
                && messagesPayload.contains(#"row["tool_call_id"] = toolCallID"#)
                && messagesPayload.contains(#"row["tool_name"] = toolName"#)
                && messagesPayload.contains(#"row["answer_packet_id"] = answerPacketID"#),
            "hermes_bridge_session_messages must replay fields the June UI already knows how to render."
        )
        #expect(
            gateway.contains("private static let maxPersistedReasoningBytes = 64 * 1024")
                && gateway.contains("private static let maxPersistedToolResults = 64")
                && gateway.contains("private func emitTurnAnswerPacket(")
                && gateway.contains("AnswerPacket.turnCompletionStub")
                && gateway.contains("AnswerPacketEmitter.shared.emit(packet)")
                && gateway.contains("answerPacketAttentionMode(forJuneModelID: modelID)")
                && gateway.contains("return .unavailable")
                && eventLoop.contains("Self.appendBounded(delta, to: &reasoning, maxBytes: Self.maxPersistedReasoningBytes)")
                && eventLoop.contains("Self.persistedToolCallsJSON(toolCalls)")
                && eventLoop.contains(#""answer_packet_id": packetID"#)
                && eventLoop.contains("answerPacketID: answerPacketID")
                && eventLoop.contains(#"role: "tool""#),
            "June must persist bounded thinking/tool/AnswerPacket evidence at turn finalization so relaunch replay matches the live stream."
        )
        #expect(
            gateway.contains(#"case "tool":"#)
                && gateway.contains(#"who = "Tool""#),
            "Tool-result replay messages must not be folded back into later prompts as if the user wrote them."
        )
    }

    @Test("App Store June ReplayBundle export FFI is bounded and subprocess-free")
    func appStoreJuneReplayBundleExportFFIIsBoundedAndSubprocessFree() throws {
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let juneBridge = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentBridge.swift")
        let exportBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bridge,
            startingAt: "pub fn export_replay_bundle_epbundle_bytes(",
            endingBefore: "/// Returns a JSON summary of the global routing accumulator."
        ))
        let nativeExportBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: juneBridge,
            startingAt: "private func exportReplayBundlePayload",
            endingBefore: "private static func boundedReplayToken"
        ))

        #expect(
            exportBody.contains("ReplayBundle::build")
                && exportBody.contains(".to_epbundle_bytes()")
                && exportBody.contains("Claim::new")
                && exportBody.contains("Evidence::new")
                && exportBody.contains(#""answer_packet_id""#)
                && exportBody.contains("bounded_replay_bundle_token"),
            "ReplayBundle export must use the native provenance builder with a non-empty bounded AnswerPacket evidence claim."
        )
        #expect(
            exportBody.contains("answer_packet:<id>")
                && exportBody.contains("does not claim answer correctness")
                && !exportBody.contains("Verified"),
            "ReplayBundle export must stay audit-only and must not fabricate a verified/correctness claim."
        )
        #expect(
            !exportBody.contains("Command::new")
                && !exportBody.contains("std::process")
                && !exportBody.contains("epistemos-trace")
                && !exportBody.contains("std::fs::write"),
            "MAS ReplayBundle export must return bytes through FFI, not invoke a verifier subprocess or write files behind the user's back."
        )
        #expect(
            bridge.contains("replay_bundle_export_ffi_mints_verifiable_epbundle_bytes")
                && bridge.contains("ReplayBundle::from_epbundle_bytes")
                && bridge.contains("verify_integrity()")
                && bridge.contains("replay_bundle_export_ffi_rejects_missing_answer_packet_id"),
            "The ReplayBundle FFI must keep focused Rust coverage for parse/verify success and fail-closed missing ids."
        )
        #expect(
            juneBridge.contains(#"case "june_export_replay_bundle":"#)
                && nativeExportBody.contains("gateway.store.loadMessages(sessionID: sessionID)")
                && nativeExportBody.contains("message.answerPacketID == answerPacketID")
                && nativeExportBody.contains("exportReplayBundleEpbundleBytes")
                && nativeExportBody.contains("NSSavePanel()")
                && nativeExportBody.contains("Data(bytes).write(to: url, options: [.atomic])")
                && !nativeExportBody.contains("Process(")
                && !nativeExportBody.contains("Command::new"),
            "June's native export command must verify stored AnswerPacket evidence, return through Rust FFI bytes, and save only through a user-mediated native panel."
        )
    }

    @Test("App Store June deterministic substrate gates are default-on with rollback")
    func appStoreJuneDeterministicSubstrateGatesAreDefaultOnWithRollback() throws {
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")
        let vault = try loadMirroredSourceTextFile("agent_core/src/storage/vault.rs")
        let eml = try loadMirroredSourceTextFile("agent_core/src/eml_rerank.rs")
        let schemaGate = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: registry,
            startingAt: "fn schema_gate_enabled() -> bool",
            endingBefore: "\n}\n\n#[cfg(not(feature = \"pro-build\"))]"
        ))
        let emlGate = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: vault,
            startingAt: "pub fn eml_rerank_enabled() -> bool",
            endingBefore: "/// The secondary signal"
        ))

        for (name, body) in [("schema", schemaGate), ("eml", emlGate)] {
            #expect(
                body.contains(#""0" | "false" | "no" | "off""#)
                    && body.contains("Err(_) => true")
                    && !body.contains(#"Ok("1" | "true" | "yes" | "on")"#),
                "\(name) gate must be default-on with explicit rollback values, not opt-in."
            )
        }
        #expect(
            registry.contains("schema_gate_validates_input_by_default_and_can_be_disabled")
                && registry.contains("std::env::remove_var(\"EPISTEMOS_SCHEMA_GATE_V1\")")
                && registry.contains("std::env::set_var(\"EPISTEMOS_SCHEMA_GATE_V1\", \"0\")")
                && registry.contains("expected a schema-gate rejection"),
            "Schema gate coverage must prove default rejection plus explicit rollback."
        )
        #expect(
            vault.contains("eml_rerank_is_flag_gated_and_fuses_excerpt_coverage")
                && vault.contains("default-on → excerpt-coverage fusion promotes B")
                && vault.contains("std::env::set_var(\"EPISTEMOS_EML_RERANK_V1\", \"0\")")
                && eml.contains("default is\n//! ON"),
            "EML rerank coverage must prove default-on vault grounding and explicit rollback."
        )
    }

    @Test("App Store June vault search confidence floor bounds raw BM25")
    func appStoreJuneVaultSearchConfidenceFloorBoundsRawBM25() throws {
        let ladder = try loadMirroredSourceTextFile("agent_core/src/tools/vault_search_ladder.rs")
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")
        let acceptBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: ladder,
            startingAt: "fn accept_above_floor",
            endingBefore: "/// Construct the canonical `vault.search` ladder"
        ))

        #expect(
            acceptBody.contains("let top_confidence")
                && acceptBody.contains("score_floor_confidence(r.score)")
                && acceptBody.contains("top_confidence >= floor"),
            "vault.search must compare bounded confidence against floors, not raw BM25 magnitude."
        )
        #expect(
            ladder.contains("pub(crate) fn score_floor_confidence(score: f64) -> f64")
                && ladder.contains("if score <= 1.0")
                && ladder.contains("(score / (score + 1.0)).clamp(0.0, 1.0)")
                && ladder.contains("t1_declines_representative_raw_bm25_after_confidence_mapping")
                && ladder.contains("ladder_maps_strong_raw_bm25_to_t1_confidence")
                && !ladder.contains("t1_accepts_raw_bm25_post_fix_c_floor_bypass_documenting"),
            "The confidence-floor guard must preserve legacy [0,1] fixtures while bounding raw BM25 and removing the documented bypass."
        )
        #expect(
            registry.contains("No notes matched with high enough confidence"),
            "June's vault search must keep an honest no-confident-answer outcome when all tiers decline."
        )
    }

    @Test("App Store June vault writes route through reversible effects")
    func appStoreJuneVaultWritesRouteThroughReversibleEffects() throws {
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")
        let effect = try loadMirroredSourceTextFile("agent_core/src/effect/mod.rs")
        let vaultApplier = try loadMirroredSourceTextFile("agent_core/src/effect/vault_applier.rs")
        let writeBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: registry,
            startingAt: "impl ToolHandler for VaultWriteHandler",
            endingBefore: "#[cfg(feature = \"pro-build\")]"
        ))

        #expect(
            writeBody.contains("Intent::VaultWrite")
                && writeBody.contains("VaultIntentApplier::new")
                && writeBody.contains("applier.apply(intent).await")
                && writeBody.contains("effect.compute_inverse")
                && writeBody.contains(#""effect_kind": effect_kind(&effect)"#)
                && writeBody.contains(#""inverse_kind": inverse_kind(&inverse)"#),
            "vault.write must route mutations through the reversible effect applier and expose non-secret effect metadata."
        )
        #expect(
            !writeBody.contains(".write(path, content, Some(&tags), append)"),
            "vault.write must not bypass the effect system with a direct backend write."
        )
        #expect(
            effect.contains("Effect::VaultWrote")
                && effect.contains("Inverse::RestoreVaultContent")
                && vaultApplier.contains("PriorState::WroteOverExisting")
                && vaultApplier.contains("body_sha256")
                && registry.contains("vault_write_effect_metadata_does_not_expose_prior_body"),
            "The effect path must preserve reversibility while tests prove prior note bodies are not returned to the agent/UI."
        )
    }

    @Test("App Store June context compiler bounds vault file ingestion")
    func appStoreJuneContextCompilerBoundsVaultFileIngestion() throws {
        let compiler = try loadMirroredSourceTextFile("agent_core/src/context_compiler.rs")
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let readerBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: compiler,
            startingAt: "fn read_context_file",
            endingBefore: "fn split_sections"
        ))
        let markdownBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: compiler,
            startingAt: "fn markdown_files",
            endingBefore: "fn should_skip_context_dir"
        ))
        let skillBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: compiler,
            startingAt: "fn load_skill_summaries",
            endingBefore: "fn load_examples"
        ))
        let bridgeBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: bridge,
            startingAt: "pub fn compile_context_prompt_json",
            endingBefore: "/// Export a minimal canonical `.epbundle`"
        ))

        #expect(
            compiler.contains("const MAX_CONTEXT_FILE_BYTES: u64 = 64 * 1024")
                && compiler.contains("const MAX_MARKDOWN_FILES: usize = 512")
                && compiler.contains("TRUNCATED_CONTEXT_MARKER")
                && readerBody.contains(".take(MAX_CONTEXT_FILE_BYTES)")
                && readerBody.contains("metadata.len() > MAX_CONTEXT_FILE_BYTES"),
            "June context assembly must cap each vault file before UTF-8 decoding so large notes cannot inflate memory during grounding."
        )
        #expect(
            markdownBody.contains("files.len() >= MAX_MARKDOWN_FILES")
                && markdownBody.contains("pending.clear()")
                && compiler.contains("fn should_skip_context_dir")
                && compiler.contains(#"Some(".epistemos" | ".git" | ".obsidian" | "node_modules" | "target" | "build")"#),
            "June context assembly must cap recursive markdown discovery and skip private/cache/build directories."
        )
        #expect(
            skillBody.contains("skill_paths.truncate(MAX_MARKDOWN_FILES)")
                && compiler.contains("context_file_reader_caps_large_inputs")
                && compiler.contains("context_compiler_caps_skill_summary_count")
                && compiler.contains("markdown_files_skip_private_context_dirs")
                && compiler.contains("markdown_files_cap_large_vault_scans"),
            "June skill and RAG context loaders must carry source-level tests for bounded file bytes, bounded counts, and private directory skips."
        )
        #expect(
            bridgeBody.contains("ContextCompiler::new")
                && bridgeBody.contains("VaultIdentity::Personal")
                && bridgeBody.contains("compiled.assembled_prompt()")
                && bridgeBody.contains(#""source": "agent_core.context_compiler""#)
                && bridgeBody.contains(#""cache_breakpoints": compiled.cache_breakpoints"#)
                && !bridgeBody.contains(#""vault_path":"#),
            "The FFI bridge must expose the bounded Rust context compiler without echoing the absolute vault path into the JSON payload."
        )
        #expect(
            bridge.contains("compile_context_prompt_json_uses_bounded_context_compiler")
                && bridge.contains("compile_context_prompt_json_rejects_relative_vault_path"),
            "The FFI context compiler seam must have focused Rust tests for real assembly and fail-closed vault path validation."
        )
    }

    @Test("App Store June MAS PDF tool is root-confined and allowlisted")
    func appStoreJuneMASPDFToolIsRootConfinedAndAllowlisted() throws {
        let registry = try loadMirroredSourceTextFile("agent_core/src/tools/registry.rs")
        let runner = try loadMirroredSourceTextFile("Epistemos/Goose/GooseInProcessACPServer.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")
        let handlerBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: registry,
            startingAt: "impl ToolHandler for PdfToMarkdownTool",
            endingBefore: "struct ResolvedVaultPdf"
        ))
        let resolverBody = try #require(AppStoreJuneSourceGuard.sourceSection(
            in: registry,
            startingAt: "fn resolve_vault_pdf_path",
            endingBefore: "fn path_to_str"
        ))

        #expect(
            registry.contains("fn register_phase_two_pdf_tools")
                && registry.contains("PdfToMarkdownTool::new(root)")
                && registry.contains("name: \"pdf.to_markdown\"")
                && registry.contains("risk_level: RiskLevel::ReadOnly")
                && registry.contains("tier: ToolTier::Agent"),
            "The MAS PDF converter must be a read-only, agent-tier tool registered only after the active vault root is known."
        )
        #expect(
            handlerBody.contains("crate::liteparse::pdf_to_markdown")
                && handlerBody.contains("bounded_pdf_tool_markdown")
                && handlerBody.contains(#""writes_vault": false"#)
                && !handlerBody.contains("std::process")
                && !handlerBody.contains("Command::new"),
            "The PDF tool must reuse the in-process LiteParse/EdgeParse seam, cap returned Markdown, and never spawn a sidecar."
        )
        #expect(
            resolverBody.contains("Component::Normal")
                && resolverBody.contains("!crate::liteparse::is_supported_pdf")
                && resolverBody.contains("candidate_metadata.file_type().is_symlink()")
                && resolverBody.contains("MAX_PDF_TOOL_INPUT_BYTES")
                && resolverBody.contains("canonical_pdf.starts_with(&canonical_root)")
                && !resolverBody.contains(#""vault_path":"#),
            "The PDF tool resolver must accept only vault-relative PDF paths, reject symlinks and oversized files, and avoid absolute vault-path payloads."
        )
        #expect(
            registry.contains("phase_two_pdf_tool_is_agent_only_and_root_gated")
                && registry.contains("pdf_to_markdown_rejects_absolute_and_traversal_paths")
                && registry.contains("pdf_to_markdown_rejects_oversized_pdf_before_parser")
                && registry.contains("pdf_to_markdown_parser_errors_do_not_leak_vault_root"),
            "Focused Rust tests must lock registration, path confinement, OOM bounds, and vault-root redaction."
        )
        #expect(
            runner.contains(#""pdf.to_markdown""#)
                && runner.contains("allowedToolNames: Self.allowedMASTools")
                && gateway.contains(#""pdf.to_markdown""#)
                && gateway.contains("observableCompositionTools"),
            "June's MAS runner and replay observer must explicitly admit the canonical PDF tool name without widening the general tool surface."
        )
    }

    @Test("App Store June does not auto-discover arbitrary URL MCP servers")
    func appStoreJuneDoesNotAutoDiscoverArbitraryURLMCPServers() throws {
        let urlServers = try loadMirroredSourceTextFile("agent_core/src/mcp/url_servers.rs")
        let bridge = try loadMirroredSourceTextFile("agent_core/src/bridge.rs")
        let runner = try loadMirroredSourceTextFile("Epistemos/Goose/GooseInProcessACPServer.swift")

        #expect(
            urlServers.contains("cfg!(feature = \"pro-build\")")
                && urlServers.contains("url_mcp_discovery_is_disabled_for_mas_builds")
                && urlServers.contains("assert!(discover_url_mcp_servers().is_empty())"),
            "MAS builds must not auto-load user/project URL-MCP config files; fixed HTTPS allowlist admission must be explicit."
        )
        #expect(
            bridge.contains("MAS builds deliberately return")
                && bridge.contains("fixed HTTPS allowlist"),
            "The agent_core FFI bridge must document that URL-MCP discovery is Pro-only until MAS allowlist admission lands."
        )
        #expect(
            runner.contains("allowedToolNames: Self.allowedMASTools")
                && !runner.contains("stdio_mcp")
                && !runner.contains("cli_passthrough")
                && !runner.contains("code_execution"),
            "June's MAS runner must keep using the explicit tool-name allowlist and must not expose forbidden Pro-only tools."
        )
    }
}
