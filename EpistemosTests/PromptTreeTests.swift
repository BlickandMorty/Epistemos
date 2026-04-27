import Foundation
import Testing
@testable import Epistemos

// MARK: - N1 — Prompt Tree (JSPF + PTF) tests
//
// 8 tests covering the foundation:
//   1. compose_includesAllRequiredSections
//   2. renderAnthropic_includesCacheControl_with4BreakpointCap
//   3. renderAnthropic_appliesRelocationTrick
//   4. renderOpenAI_omitsCacheControl
//   5. renderAFM_returnsGenerableSchema
//   6. cacheHints_capsAtFour
//   7. persist_writesPTFRoundTrip
//   8. structureRegistry_includesNewPromptSchemas

@Suite("PromptTree foundation")
struct PromptTreeTests {

    // MARK: - Test 1: composer

    @Test("compose includes all required sections from typed inputs")
    func compose_includesAllRequiredSections() async throws {
        let prompt = PromptComposer.compose(
            forChatTurn: "session-abc",
            turnIndex: 1,
            identitySystemText: "You are Epistemos.",
            capabilityManifest: "Manifest text",
            toolDefinitionsJSON: """
                [{"name":"vault_search","description":"Search the vault.","input_schema":{"type":"object"}}]
                """,
            relevantNotes: ["note-1", "note-2"],
            recentChatsJSON: "{\"turns\":3}",
            ontology: ["concept-a": "Concept A"],
            objective: "Find my notes about cognition.",
            mode: "agent",
            effortTier: "thinking",
            constraintBlocks: [
                ConstraintSection(label: "Privacy", text: "No PII to cloud.")
            ],
            outputSchema: OutputSchema(registryId: "ontology_node", humanDescription: nil)
        )

        #expect(prompt.version == 1)
        #expect(prompt.id.contains("session-abc:1:"))
        #expect(prompt.identity?.systemText == "You are Epistemos.")
        #expect(prompt.identity?.capabilityManifest == "Manifest text")
        #expect(prompt.tools.count == 1)
        #expect(prompt.tools.first?.name == "vault_search")
        #expect(prompt.memory?.recentChats == "{\"turns\":3}")
        #expect(prompt.memory?.relevantNotes == ["note-1", "note-2"])
        #expect(prompt.memory?.ontology == ["concept-a": "Concept A"])
        #expect(prompt.task.objective == "Find my notes about cognition.")
        #expect(prompt.task.mode == "agent")
        #expect(prompt.task.effortTier == "thinking")
        #expect(prompt.constraints.count == 1)
        #expect(prompt.outputSchema?.registryId == "ontology_node")
        #expect(prompt.cacheHints.applyRelocationTrick == true)
    }

    // MARK: - Test 2: Anthropic render with cache_control breakpoints

    @Test("Anthropic render emits cache_control on system + objective and respects 4-breakpoint cap")
    func renderAnthropic_includesCacheControl_with4BreakpointCap() async throws {
        let prompt = makeChatPrompt()
        let rendered = PromptRenderer.render(prompt, target: .anthropicMessages)
        guard case let .anthropic(systemBlocks, messages) = rendered else {
            Issue.record("expected .anthropic case")
            return
        }
        // System block has cache_control: ephemeral
        #expect(systemBlocks.count >= 1)
        let firstSystem = systemBlocks[0]
        let systemCacheControl = firstSystem["cache_control"]?.value as? [String: String]
        #expect(systemCacheControl?["type"] == "ephemeral")

        // Objective message (last) has cache_control: ephemeral on its content block
        #expect(messages.count >= 1)
        let objectiveMsg = messages.last!
        let contentArray = objectiveMsg["content"]?.value as? [[String: Any]]
        let lastBlock = contentArray?.last
        let objCacheControl = lastBlock?["cache_control"] as? [String: String]
        #expect(objCacheControl?["type"] == "ephemeral")

        // PromptCache.hints respects the 4-breakpoint cap
        let hints = PromptCache.hints(for: prompt, target: .anthropicMessages)
        #expect(hints.count <= PromptCache.maxAnthropicBreakpoints)
    }

    // MARK: - Test 3: Relocation Trick

    @Test("Anthropic render with relocation moves dynamic content out of system prefix")
    func renderAnthropic_appliesRelocationTrick() async throws {
        let prompt = makeChatPrompt() // applyRelocationTrick = true
        let rendered = PromptRenderer.render(prompt, target: .anthropicMessages)
        guard case let .anthropic(systemBlocks, messages) = rendered else {
            Issue.record("expected .anthropic case")
            return
        }
        // System prefix should NOT contain the recent-chats marker
        // because relocation moves it to the user message tail.
        let systemText = systemBlocks[0]["text"]?.value as? String ?? ""
        #expect(!systemText.contains("recent-chats"))
        #expect(!systemText.contains("turns\":3"))

        // The session-context user message should contain it.
        let firstUser = messages.first!
        let firstContent = firstUser["content"]?.value as? [[String: Any]]
        let firstText = firstContent?.first?["text"] as? String ?? ""
        #expect(firstText.contains("<session-context>"))
        #expect(firstText.contains("recent-chats"))
    }

    // MARK: - Test 4: OpenAI omits cache_control

    @Test("OpenAI render omits Anthropic-specific cache_control fields")
    func renderOpenAI_omitsCacheControl() async throws {
        let prompt = makeChatPrompt()
        let rendered = PromptRenderer.render(prompt, target: .openAIResponses)
        guard case let .openAI(payload) = rendered else {
            Issue.record("expected .openAI case")
            return
        }
        let asString = String(describing: payload.mapValues { $0.value })
        #expect(!asString.contains("cache_control"))
        #expect(!asString.contains("ephemeral"))

        // Hints for OpenAI must be empty (auto-cache, no explicit markers)
        let hints = PromptCache.hints(for: prompt, target: .openAIResponses)
        #expect(hints.isEmpty)
    }

    // MARK: - Test 5: AFM returns Generable schema reference

    @Test("AFM render returns instructions plus the registered schema id")
    func renderAFM_returnsGenerableSchema() async throws {
        let schema = OutputSchema(
            registryId: "ontology_node",
            rawJSONSchema: nil,
            humanDescription: nil
        )
        let prompt = makeChatPrompt(outputSchema: schema)
        let rendered = PromptRenderer.render(prompt, target: .afmGenerable)
        guard case let .afm(instructions, registryId, _) = rendered else {
            Issue.record("expected .afm case")
            return
        }
        #expect(instructions.contains("# Identity"))
        #expect(instructions.contains("# Task"))
        #expect(registryId == "ontology_node")
    }

    // MARK: - Test 6: cacheHints caps at 4

    @Test("PromptCache caps Anthropic breakpoints at 4 even when more requested")
    func cacheHints_capsAtFour() async throws {
        let allFive: [PromptSubtree] = [
            .identity, .tools, .ontology, .outputSchema, .memory
        ]
        let prompt = Prompt(
            id: "test-cap",
            identity: IdentitySection(role: "x", systemText: "x"),
            tools: [
                ToolSpec(name: "t", description: "t", inputSchemaJSON: "{}")
            ],
            memory: MemorySection(
                recentChats: "x",
                relevantNotes: ["x"],
                ontology: ["c": "C"]
            ),
            task: TaskSection(objective: "x"),
            constraints: [],
            outputSchema: OutputSchema(registryId: "x"),
            cacheHints: CacheHints(stableSubtrees: allFive, applyRelocationTrick: true)
        )

        let hints = PromptCache.hints(for: prompt, target: .anthropicMessages)
        #expect(hints.count == 4)
        // The first four (identity, tools, ontology, outputSchema) are kept;
        // memory drops because it churns most.
        let kept = Set(hints.map { $0.subtree })
        #expect(kept == [.identity, .tools, .ontology, .outputSchema])
    }

    // MARK: - Test 7: PTF round-trip

    @Test("PTF persist + load round-trips identical Prompt")
    func persist_writesPTFRoundTrip() async throws {
        let original = makeChatPrompt()
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos-n1-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try await PromptTreePersister.shared.persist(
            original,
            sessionID: "session-rt",
            turnIndex: 7,
            vaultRoot: tempRoot
        )

        let loaded = try await PromptTreePersister.shared.load(
            sessionID: "session-rt",
            turnIndex: 7,
            vaultRoot: tempRoot
        )

        #expect(loaded != nil)
        #expect(loaded?.id == original.id)
        #expect(loaded?.version == original.version)
        #expect(loaded?.identity == original.identity)
        #expect(loaded?.tools == original.tools)
        #expect(loaded?.memory == original.memory)
        #expect(loaded?.task == original.task)
        #expect(loaded?.constraints == original.constraints)
        #expect(loaded?.outputSchema == original.outputSchema)
        #expect(loaded?.cacheHints == original.cacheHints)
        // Hashable identity: round-tripped value equals original
        #expect(loaded == original)
    }

    // MARK: - Test 8: StructureRegistry has the new prompt-shape entries

    @Test("StructureRegistry catalogs the 5 N1 prompt-shape descriptors")
    func structureRegistry_includesNewPromptSchemas() async throws {
        let expected = [
            "prompt_root",
            "prompt_identity",
            "prompt_tools",
            "prompt_memory",
            "prompt_task",
        ]
        for id in expected {
            let entry = StructureRegistry.schema(id: id)
            #expect(entry != nil, "missing StructureRegistry entry: \(id)")
            #expect(entry?.maturity == .full)
            #expect(entry?.profiles == [.mas, .pro])
            #expect(entry?.surface == "agent_invocation")
        }
    }

    // MARK: - Helpers

    private func makeChatPrompt(
        outputSchema: OutputSchema? = OutputSchema(registryId: "ontology_node")
    ) -> Prompt {
        return PromptComposer.compose(
            forChatTurn: "session-1",
            turnIndex: 0,
            identitySystemText: "You are Epistemos.",
            capabilityManifest: nil,
            toolDefinitionsJSON: """
                [{"name":"vault_search","description":"Search vault.","input_schema":{"type":"object"}}]
                """,
            relevantNotes: ["Note A: cognitive substrate."],
            recentChatsJSON: "{\"turns\":3}",
            ontology: ["cognition": "Cognition"],
            objective: "Tell me about my recent notes.",
            mode: "thinking",
            effortTier: "auto",
            constraintBlocks: [],
            outputSchema: outputSchema
        )
    }
}
