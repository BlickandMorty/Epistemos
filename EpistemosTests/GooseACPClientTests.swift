import Foundation
import Testing
@testable import Epistemos

@Suite("Goose ACP codec")
struct GooseACPCodecTests {
    @Test("initialize request encodes ACP protocol version 1 with Goose client metadata")
    func initializeRequestEncoding() throws {
        let request = GooseACPJSONRPCRequest(
            id: .int(1),
            method: GooseACPMethod.initialize.rawValue,
            params: GooseACPInitializeRequest.epistemos(clientVersion: "test-version")
        )

        let object = try encodedObject(request)
        #expect(object["jsonrpc"] == .string("2.0"))
        #expect(object["id"] == .int(1))
        #expect(object["method"] == .string("initialize"))

        let params = try #require(object["params"]?.objectValue)
        #expect(params["protocolVersion"] == .int(1))
        #expect(params["clientInfo"]?.objectValue?["name"] == .string("Epistemos"))
        #expect(params["clientInfo"]?.objectValue?["version"] == .string("test-version"))
        #expect(params["clientCapabilities"]?.objectValue?["elicitation"]?.objectValue?["form"] == .object([:]))
        #expect(params["clientCapabilities"]?.objectValue?["_meta"]?.objectValue?["goose"]?.objectValue?["customNotifications"] == .bool(true))
    }

    @Test("session new and prompt requests use ACP method names and content blocks")
    func sessionRequestEncoding() throws {
        let newSession = GooseACPJSONRPCRequest(
            id: .int(2),
            method: GooseACPMethod.newSession.rawValue,
            params: GooseACPNewSessionRequest(cwd: "/Users/jojo/Downloads/Epistemos")
        )
        let newSessionObject = try encodedObject(newSession)
        #expect(newSessionObject["method"] == .string("session/new"))
        #expect(newSessionObject["params"]?.objectValue?["cwd"] == .string("/Users/jojo/Downloads/Epistemos"))
        #expect(newSessionObject["params"]?.objectValue?["mcpServers"] == .array([]))

        let prompt = GooseACPJSONRPCRequest(
            id: .int(3),
            method: GooseACPMethod.prompt.rawValue,
            params: GooseACPPromptRequest(
                sessionId: "session-1",
                prompt: [.text("hello goose")]
            )
        )
        let promptObject = try encodedObject(prompt)
        #expect(promptObject["method"] == .string("session/prompt"))
        let params = try #require(promptObject["params"]?.objectValue)
        #expect(params["sessionId"] == .string("session-1"))
        #expect(params["prompt"] == .array([.object(["type": .string("text"), "text": .string("hello goose")])]))
    }

    @Test("incoming session update decodes assistant text chunks")
    func incomingSessionUpdateDecoding() throws {
        let json = """
        {
          "jsonrpc": "2.0",
          "method": "session/update",
          "params": {
            "sessionId": "session-1",
            "update": {
              "sessionUpdate": "agent_message_chunk",
              "content": { "type": "text", "text": "partial answer" }
            }
          }
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(GooseACPIncomingMessage.self, from: json)
        guard case .notification(let method, let params) = message else {
            Issue.record("expected notification")
            return
        }
        #expect(method == .sessionUpdate)
        let notification = try params.decode(GooseACPSessionNotification.self)
        #expect(notification.sessionId == "session-1")
        #expect(notification.update == .agentMessageChunk(.init(content: .text("partial answer"))))
    }

    @Test("incoming envelope preserves explicit JSON nulls and rejects missing response payloads")
    func incomingEnvelopeNullAndMissingPayloadDecoding() throws {
        let nullParams = #"{"jsonrpc":"2.0","id":"perm-null","method":"session/request_permission","params":null}"#
            .data(using: .utf8)!
        let nullParamsMessage = try JSONDecoder().decode(GooseACPIncomingMessage.self, from: nullParams)
        guard case .request(let requestId, let method, let params) = nullParamsMessage else {
            Issue.record("expected request with explicit null params")
            return
        }
        #expect(requestId == .string("perm-null"))
        #expect(method == .requestPermission)
        #expect(params == .null)

        let nullResult = #"{"jsonrpc":"2.0","id":7,"result":null}"#
            .data(using: .utf8)!
        let nullResultMessage = try JSONDecoder().decode(GooseACPIncomingMessage.self, from: nullResult)
        guard case .response(let responseId, let result) = nullResultMessage else {
            Issue.record("expected response with explicit null result")
            return
        }
        #expect(responseId == .int(7))
        #expect(result == .null)

        let missingPayload = #"{"jsonrpc":"2.0","id":8}"#
            .data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(GooseACPIncomingMessage.self, from: missingPayload)
        }
    }

    @Test("incoming permission requests map native choices to ACP outcomes")
    func permissionRequestRoundTrip() throws {
        let json = """
        {
          "jsonrpc": "2.0",
          "id": "perm-1",
          "method": "session/request_permission",
          "params": {
            "sessionId": "session-1",
            "toolCall": {
              "toolCallId": "tool-1",
              "title": "Write file",
              "status": "pending"
            },
            "options": [
              { "optionId": "once", "name": "Allow once", "kind": "allow_once" },
              { "optionId": "always", "name": "Always allow", "kind": "allow_always" },
              { "optionId": "deny", "name": "Deny once", "kind": "reject_once" }
            ]
          }
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(GooseACPIncomingMessage.self, from: json)
        guard case .request(let id, let method, let params) = message else {
            Issue.record("expected request")
            return
        }
        #expect(id == .string("perm-1"))
        #expect(method == .requestPermission)
        let request = try params.decode(GooseACPRequestPermissionRequest.self)
        #expect(request.sessionId == "session-1")
        #expect(request.toolCall.toolCallId == "tool-1")
        #expect(request.option(for: .allowAlways)?.optionId == "always")

        let selected = GooseACPRequestPermissionResponse.selected(optionId: "always")
        #expect(try encodedObject(selected)["outcome"] == .object(["outcome": .string("selected"), "optionId": .string("always")]))
        #expect(try encodedObject(GooseACPRequestPermissionResponse.cancelled())["outcome"] == .object(["outcome": .string("cancelled")]))
    }

    @Test("permission request decodes future tool kinds as other")
    func permissionRequestFutureToolKind() throws {
        let json = """
        {
          "jsonrpc": "2.0",
          "id": "perm-2",
          "method": "session/request_permission",
          "params": {
            "sessionId": "session-1",
            "toolCall": {
              "toolCallId": "tool-2",
              "title": "New action",
              "kind": "future_kind",
              "status": "pending"
            },
            "options": [
              { "optionId": "once", "name": "Allow once", "kind": "allow_once" }
            ]
          }
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(GooseACPIncomingMessage.self, from: json)
        guard case .request(_, _, let params) = message else {
            Issue.record("expected request")
            return
        }
        let request = try params.decode(GooseACPRequestPermissionRequest.self)
        #expect(request.toolCall.kind == .other)
    }

    @Test("form elicitation requests and responses preserve structured values")
    func formElicitationRoundTrip() throws {
        let json = """
        {
          "jsonrpc": "2.0",
          "id": 8,
          "method": "elicitation/create",
          "params": {
            "mode": "form",
            "sessionId": "session-1",
            "message": "Need a title",
            "requestedSchema": {
              "type": "object",
              "properties": {
                "title": { "type": "string", "title": "Title" }
              },
              "required": ["title"]
            }
          }
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(GooseACPIncomingMessage.self, from: json)
        guard case .request(_, let method, let params) = message else {
            Issue.record("expected request")
            return
        }
        #expect(method == .createElicitation)
        let request = try params.decode(GooseACPCreateElicitationRequest.self)
        #expect(request.mode == .form)
        #expect(request.sessionId == "session-1")
        #expect(request.requestedSchema.objectValue?["required"] == .array([.string("title")]))

        let accepted = GooseACPCreateElicitationResponse.accept([
            "title": .string("A native answer")
        ])
        #expect(try encodedObject(accepted)["action"] == .string("accept"))
        #expect(try encodedObject(accepted)["content"]?.objectValue?["title"] == .string("A native answer"))
    }

    @Test("elicitation form fields are bounded before native prompt rendering")
    func elicitationFormFieldsAreBoundedBeforeNativePromptRendering() {
        let longTitle = String(repeating: "t", count: GooseACPElicitationFormField.maxFieldTitleCharacters + 10)
        var properties: [String: JSONValue] = [:]
        for index in 0..<(GooseACPElicitationFormField.maxFields + 5) {
            properties[String(format: "field-%02d", index)] = .object([
                "type": .string("string"),
                "title": .string(longTitle),
            ])
        }
        properties[String(repeating: "x", count: GooseACPElicitationFormField.maxFieldIDCharacters + 1)] = .object([
            "type": .string("string"),
            "title": .string("oversized id"),
        ])

        let fields = GooseACPElicitationFormField.fields(from: .object([
            "type": .string("object"),
            "required": .array([.string("field-00")]),
            "properties": .object(properties),
        ]))

        #expect(fields.count == GooseACPElicitationFormField.maxFields)
        #expect(fields.first?.id == "field-00")
        #expect(fields.first?.isRequired == true)
        #expect(fields.allSatisfy { $0.id.count <= GooseACPElicitationFormField.maxFieldIDCharacters })
        #expect(fields.allSatisfy { $0.title.count <= GooseACPElicitationFormField.maxFieldTitleCharacters })
    }
}

@Suite("Goose ACP client")
struct GooseACPClientTests {
    @Test("client sends initialize, session new, prompt, and permission responses over transport")
    func clientSendsCoreFlow() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"sessionId":"session-1"}}"#,
            #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"session-1","update":{"sessionUpdate":"agent_thought_chunk","content":{"type":"text","text":"thinking"}}}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"stopReason":"end_turn"}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        let initialized = try await client.initialize()
        #expect(initialized.protocolVersion == 1)

        let session = try await client.newSession(cwd: "/Users/jojo/Downloads/Epistemos")
        #expect(session.sessionId == "session-1")

        let event = try await client.receiveEvent()
        #expect(event == .sessionUpdate(.init(sessionId: "session-1", update: .agentThoughtChunk(.init(content: .text("thinking"))))))

        let prompt = try await client.prompt(sessionId: "session-1", text: "hello")
        #expect(prompt.stopReason == .endTurn)

        try await client.respondToPermission(requestId: .string("perm-1"), response: .selected(optionId: "always"))
        let sent = await transport.sentMessages()
        #expect(Array(sent.compactMap(\.method).prefix(3)) == [.initialize, .newSession, .prompt])
        #expect(sent.last?.id == .string("perm-1"))
        #expect(sent.last?.raw.objectValue?["result"]?.objectValue?["outcome"]?.objectValue?["optionId"] == .string("always"))
        await client.close()
    }

    @Test("client close wakes event waiters with closed instead of skipped-frame diagnostics")
    func clientCloseDoesNotDeliverSkippedFrameDiagnostic() async throws {
        let transport = GooseACPMemoryTransport(incoming: [])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")
        let eventTask = Task {
            try await client.receiveEvent()
        }

        await transport.waitUntilReceiveWaiters(count: 1)
        await client.close()

        do {
            _ = try await eventTask.value
            Issue.record("close should fail waiting event receivers with GooseACPProtocolError.closed")
        } catch GooseACPProtocolError.closed {
            // expected
        }
    }

    @Test("client close drops queued ACP events instead of replaying stale state")
    func clientCloseDropsQueuedEvents() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"session-1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"stale"}}}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        await transport.waitUntilReceiveWaiters(count: 1)
        await client.close()

        do {
            _ = try await client.receiveEvent()
            Issue.record("close should discard queued ACP events and report GooseACPProtocolError.closed")
        } catch GooseACPProtocolError.closed {
            // expected
        }
    }

    @Test("prompt streams session updates before the final prompt response")
    func promptStreamsBeforeFinalResponse() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"sessionId":"session-1"}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let session = try await client.newSession(cwd: "/Users/jojo/Downloads/Epistemos")

        let promptTask = Task {
            try await client.prompt(sessionId: session.sessionId, text: "stream please")
        }
        await transport.waitUntilSent(count: 3)

        await transport.enqueue(
            #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"session-1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"live chunk"}}}}"#
        )
        let event = try await client.receiveEvent()
        #expect(event == .sessionUpdate(.init(sessionId: "session-1", update: .agentMessageChunk(.init(content: .text("live chunk"))))))

        await transport.enqueue(#"{"jsonrpc":"2.0","id":3,"result":{"stopReason":"end_turn"}}"#)
        #expect(try await promptTask.value.stopReason == .endTurn)
        await client.close()
    }

    @Test("client sends the Phase 0 read-only Goose custom ACP subset")
    func clientSendsReadOnlyGooseCustomACPSubset() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"entries":[{"providerId":"mock","configured":true}]}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"extensions":[{"enabled":true,"extension":{"type":"builtin","name":"developer"}}],"warnings":["env missing"]}}"#,
            #"{"jsonrpc":"2.0","id":4,"result":{"values":[{"key":"gooseThinkingEffort","value":"medium"}]}}"#,
            #"{"jsonrpc":"2.0","id":5,"result":{"providerId":"mock","modelId":"mock-model"}}"#,
            #"{"jsonrpc":"2.0","id":6,"result":{"session":{"sessionId":"session-1","cwd":"/tmp","updatedAt":"2026-06-27T00:00:00Z"}}}"#,
            #"{"jsonrpc":"2.0","id":7,"result":{"report":{"summary":"ok"}}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let providers = try await client.listGooseProviders()
        let extensions = try await client.listGooseConfigExtensions()
        let preferences = try await client.readGoosePreferences(keys: [.gooseThinkingEffort])
        let defaults = try await client.readGooseDefaults()
        let sessionInfo = try await client.readGooseSessionInfo(sessionId: "session-1")
        let diagnostics = try await client.readGooseDiagnostics(sessionId: "session-1", level: .summary)

        #expect(providers.entries.count == 1)
        #expect(extensions.extensions.count == 1)
        #expect(extensions.warnings == ["env missing"])
        #expect(preferences.values == [.init(key: .gooseThinkingEffort, value: .string("medium"))])
        #expect(defaults.providerId == "mock")
        #expect(defaults.modelId == "mock-model")
        #expect(sessionInfo.session.objectValue?["sessionId"] == .string("session-1"))
        #expect(diagnostics.report.objectValue?["summary"] == .string("ok"))

        let methods = await transport.sentMessages().compactMap { $0.raw.objectValue?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/providers/list"),
            .string("_goose/unstable/config/extensions/list"),
            .string("_goose/unstable/preferences/read"),
            .string("_goose/unstable/defaults/read"),
            .string("_goose/unstable/session/info"),
            .string("_goose/unstable/diagnostics/get"),
        ])
        await client.close()
    }

    @Test("provider inventory normalizes live ACP ids before native Models picker")
    func providerInventoryNormalizesLiveACPIDsBeforeNativeModelsPicker() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"""
            {"jsonrpc":"2.0","id":2,"result":{"entries":[
              {"providerId":" openai ","providerName":" OpenAI ","configured":true,"defaultModel":" gpt-4.1 ","models":[{"id":" gpt-4.1 "},{"id":" "},{"id":"gpt-4.1"},{"id":"gpt-4.2"}]},
              {"providerId":"   ","providerName":"Blank","models":[{"id":"bad"}]},
              {"providerId":"openai","providerName":"Duplicate","models":[{"id":"duplicate"}]},
              {"provider_id":"anthropic","provider_name":" Anthropic ","default_model":" claude ","models":[" claude ",{"id":"claude"},{"id":"sonnet"}]},
              {"providerId":"","id":"local","providerName":"","name":" Local ","defaultModel":"","models":[{"id":""},{"id":" qwen "}]},
              {"name":"missing-id"}
            ]}}
            """#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let inventory = try await client.listGooseProviderInventory()

        #expect(inventory.map(\.providerId) == ["openai", "anthropic", "local"])
        #expect(inventory.map(\.providerName) == ["OpenAI", "Anthropic", "Local"])
        #expect(inventory[0].defaultModel == "gpt-4.1")
        #expect(inventory[1].defaultModel == "claude")
        #expect(inventory[2].defaultModel == nil)
        #expect(inventory[0].configured)
        #expect(inventory[0].models.map(\.id) == ["gpt-4.1", "gpt-4.2"])
        #expect(inventory[1].models.map(\.id) == ["claude", "sonnet"])
        #expect(inventory[2].models.map(\.id) == ["qwen"])
        await client.close()
    }

    @Test("client sends the Skills source list Goose custom ACP subset")
    func clientSendsSkillsSourceListGooseCustomACPSubset() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"sources":[{"type":"skill","name":"local-review","description":"Review local code","content":"Use review steps","path":"/repo/.agents/skills/local-review","global":false,"writable":true,"supportingFiles":[],"properties":{}}]}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"sources":[{"type":"builtinSkill","name":"goose-doc-guide","description":"Reference Goose docs","content":"Read docs first","path":"builtin://skills/goose-doc-guide","global":true}]}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let projectSkills = try await client.listGooseSources(type: .skill, projectDir: "/repo")
        let builtInSkills = try await client.listGooseSources(type: .builtinSkill, projectDir: "/repo")

        #expect(projectSkills.sources.first?.sourceType == .skill)
        #expect(projectSkills.sources.first?.name == "local-review")
        #expect(projectSkills.sources.first?.writable == true)
        #expect(builtInSkills.sources.first?.sourceType == .builtinSkill)
        #expect(builtInSkills.sources.first?.path == "builtin://skills/goose-doc-guide")
        #expect(builtInSkills.sources.first?.writable == false)
        #expect(builtInSkills.sources.first?.supportingFiles == [])
        #expect(builtInSkills.sources.first?.properties == [:])

        let sent = await transport.sentMessages()
        let methods = sent.compactMap { $0.raw.objectValue?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/sources/list"),
            .string("_goose/unstable/sources/list"),
        ])
        let projectParams = try #require(sent.dropFirst().first?.raw.objectValue?["params"]?.objectValue)
        #expect(projectParams["type"] == .string("skill"))
        #expect(projectParams["projectDir"] == .string("/repo"))
        #expect(projectParams["includeProjectSources"] == nil)
        let builtInParams = try #require(sent.dropFirst(2).first?.raw.objectValue?["params"]?.objectValue)
        #expect(builtInParams["type"] == .string("builtinSkill"))
        #expect(builtInParams["projectDir"] == .string("/repo"))
        await client.close()
    }

    @Test("client sends the Skills source export Goose custom ACP subset")
    func clientSendsSkillsSourceExportGooseCustomACPSubset() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"json":"{\"type\":\"skill\",\"name\":\"local-review\"}","filename":"local-review.skill.json"}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let exported = try await client.exportGooseSource(type: .skill, path: "/repo/.agents/skills/local-review")

        #expect(exported.filename == "local-review.skill.json")
        #expect(exported.json.contains(#""name":"local-review""#))

        let sent = await transport.sentMessages()
        let exportParams = try #require(sent.dropFirst().first?.raw.objectValue?["params"]?.objectValue)
        #expect(sent.dropFirst().first?.raw.objectValue?["method"] == .string("_goose/unstable/sources/export"))
        #expect(exportParams["type"] == .string("skill"))
        #expect(exportParams["path"] == .string("/repo/.agents/skills/local-review"))
        await client.close()
    }

    @Test("client sends the Skills source mutation Goose custom ACP subset")
    func clientSendsSkillsSourceMutationGooseCustomACPSubset() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"source":{"type":"skill","name":"phase0-skill","description":"Draft skill","content":"Use draft steps","path":"/repo/.agents/skills/phase0-skill","global":false,"writable":true}}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"source":{"type":"skill","name":"phase0-skill","description":"Updated skill","content":"Use updated steps","path":"/repo/.agents/skills/phase0-skill","global":false,"writable":true}}}"#,
            #"{"jsonrpc":"2.0","id":4,"result":{}}"#,
            #"{"jsonrpc":"2.0","id":5,"result":{"sources":[{"type":"skill","name":"phase0-skill","description":"Imported skill","content":"Use imported steps","path":"/repo/.agents/skills/phase0-skill","global":false,"writable":true}]}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let target = GooseACPSourceScope.projectDir("/repo")
        let created = try await client.createGooseSource(
            type: .skill,
            name: "phase0-skill",
            description: "Draft skill",
            content: "Use draft steps",
            target: target,
            properties: ["origin": .string("unit-test")]
        )
        let updated = try await client.updateGooseSource(
            type: .skill,
            path: created.source.path,
            name: created.source.name,
            description: "Updated skill",
            content: "Use updated steps"
        )
        try await client.deleteGooseSource(type: .skill, path: updated.source.path)
        let imported = try await client.importGooseSources(data: #"{"type":"skill"}"#, target: target)

        #expect(created.source.description == "Draft skill")
        #expect(updated.source.content == "Use updated steps")
        #expect(imported.sources.first?.sourceType == .skill)

        let sent = await transport.sentMessages()
        let methods = sent.compactMap { $0.raw.objectValue?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/sources/create"),
            .string("_goose/unstable/sources/update"),
            .string("_goose/unstable/sources/delete"),
            .string("_goose/unstable/sources/import"),
        ])
        let createParams = try #require(sent.dropFirst().first?.raw.objectValue?["params"]?.objectValue)
        #expect(createParams["type"] == .string("skill"))
        #expect(createParams["target"]?.objectValue?["scope"] == .string("projectDir"))
        #expect(createParams["target"]?.objectValue?["projectDir"] == .string("/repo"))
        #expect(createParams["properties"]?.objectValue?["origin"] == .string("unit-test"))
        let updateParams = try #require(sent.dropFirst(2).first?.raw.objectValue?["params"]?.objectValue)
        #expect(updateParams["path"] == .string("/repo/.agents/skills/phase0-skill"))
        #expect(updateParams["properties"] == nil)
        let deleteParams = try #require(sent.dropFirst(3).first?.raw.objectValue?["params"]?.objectValue)
        #expect(deleteParams["path"] == .string("/repo/.agents/skills/phase0-skill"))
        let importParams = try #require(sent.dropFirst(4).first?.raw.objectValue?["params"]?.objectValue)
        #expect(importParams["target"]?.objectValue?["scope"] == .string("projectDir"))
        await client.close()
    }

    @Test("client sends the provider settings read-only Goose custom ACP subset")
    func clientSendsProviderSettingsReadOnlyCustomACPSubset() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"providerId":"mock","models":["mock-model","mock-large"]}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"fields":[{"key":"MOCK_API_KEY","value":null,"isSet":false,"isSecret":true,"required":true},{"key":"MOCK_HOST","value":"https://mock.local","isSet":true}]}}"#,
            #"{"jsonrpc":"2.0","id":4,"result":{"statuses":[{"providerId":"mock","isConfigured":false}]}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let models = try await client.listGooseProviderSupportedModels(providerId: "mock")
        let config = try await client.readGooseProviderConfig(providerId: "mock")
        let status = try await client.readGooseProviderConfigStatus(providerIds: ["mock"])

        #expect(models.providerId == "mock")
        #expect(models.models == ["mock-model", "mock-large"])
        #expect(config.fields == [
            .init(key: "MOCK_API_KEY", value: nil, isSet: false, isSecret: true, required: true),
            .init(key: "MOCK_HOST", value: "https://mock.local", isSet: true, isSecret: false, required: false),
        ])
        #expect(status.statuses == [
            .init(providerId: "mock", isConfigured: false),
        ])

        let methods = await transport.sentMessages().compactMap { $0.raw.objectValue?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/providers/supported-models/list"),
            .string("_goose/unstable/providers/config/read"),
            .string("_goose/unstable/providers/config/status"),
        ])
        await client.close()
    }

    @Test("client sends Goose provider catalog ACP methods")
    func clientSendsProviderCatalogCustomACPMethods() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"providers":[{"providerId":"openai-compatible","name":"OpenAI Compatible","format":"openai","apiUrl":"https://example.invalid/v1","modelCount":2,"docUrl":"https://docs.example.invalid","envVar":"OPENAI_API_KEY"}]}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"providers":[{"providerId":"openai","name":"OpenAI","category":"cloud","description":"OpenAI models","setupMethod":"single_api_key","nativeConnectQuery":null,"fields":[{"key":"OPENAI_API_KEY","label":"API key","secret":true,"required":true}],"binaryName":null,"docUrl":"https://platform.openai.com","group":"default","showOnlyWhenInstalled":false,"aliases":["gpt"],"supportsInstall":false,"supportsAuth":false,"supportsAuthStatus":true}]}}"#,
            #"{"jsonrpc":"2.0","id":4,"result":{"template":{"providerId":"openai-compatible","name":"OpenAI Compatible","format":"openai","apiUrl":"https://example.invalid/v1","models":[{"id":"mock-model","name":"Mock Model","contextLimit":128000,"capabilities":{"toolCall":true,"reasoning":false,"attachment":false,"temperature":true},"deprecated":false}],"supportsStreaming":true,"envVar":"OPENAI_API_KEY","docUrl":"https://docs.example.invalid"}}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let catalog = try await client.listGooseProviderCatalog(format: "openai")
        let setupCatalog = try await client.listGooseProviderSetupCatalog()
        let template = try await client.readGooseProviderCatalogTemplate(providerId: "openai-compatible")

        #expect(catalog.providers == [
            GooseACPProviderTemplateCatalogEntry(
                providerId: "openai-compatible",
                name: "OpenAI Compatible",
                format: "openai",
                apiUrl: "https://example.invalid/v1",
                modelCount: 2,
                docUrl: "https://docs.example.invalid",
                envVar: "OPENAI_API_KEY"
            ),
        ])
        #expect(setupCatalog.providers.first?.providerId == "openai")
        #expect(setupCatalog.providers.first?.fields.first?.key == "OPENAI_API_KEY")
        #expect(setupCatalog.providers.first?.aliases == ["gpt"])
        #expect(template.template.providerId == "openai-compatible")
        #expect(template.template.models.first?.id == "mock-model")
        #expect(template.template.models.first?.capabilities.toolCall == true)

        let sent = await transport.sentMessages()
        let methods = sent.compactMap { $0.raw.objectValue?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/providers/catalog/list"),
            .string("_goose/unstable/providers/setup/catalog/list"),
            .string("_goose/unstable/providers/catalog/template"),
        ])
        let catalogParams = try #require(sent.dropFirst().first?.raw.objectValue?["params"]?.objectValue)
        #expect(catalogParams["format"] == .string("openai"))
        let templateParams = try #require(sent.dropFirst(3).first?.raw.objectValue?["params"]?.objectValue)
        #expect(templateParams["providerId"] == .string("openai-compatible"))
        await client.close()
    }

    @Test("client sends the provider settings mutation Goose custom ACP subset")
    func clientSendsProviderSettingsMutationCustomACPSubset() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{"status":{"providerId":"mock","isConfigured":true},"refresh":{"jobs":[]}}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{"status":{"providerId":"mock","isConfigured":false},"refresh":{"jobs":[]}}}"#,
            #"{"jsonrpc":"2.0","id":4,"result":{"status":{"providerId":"mock","isConfigured":true},"refresh":{"jobs":[]}}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let save = try await client.saveGooseProviderConfig(
            providerId: "mock",
            fields: [.init(key: "MOCK_API_KEY", value: "redacted-test-key")]
        )
        let delete = try await client.deleteGooseProviderConfig(providerId: "mock")
        let auth = try await client.authenticateGooseProviderConfig(providerId: "mock")

        #expect(save.status == .init(providerId: "mock", isConfigured: true))
        #expect(delete.status == .init(providerId: "mock", isConfigured: false))
        #expect(auth.status == .init(providerId: "mock", isConfigured: true))

        let sent = await transport.sentMessages()
        let methods = sent.compactMap { $0.raw.objectValue?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/providers/config/save"),
            .string("_goose/unstable/providers/config/delete"),
            .string("_goose/unstable/providers/config/authenticate"),
        ])
        let saveParams = try #require(sent.dropFirst().first?.raw.objectValue?["params"]?.objectValue)
        #expect(saveParams["providerId"] == .string("mock"))
        #expect(saveParams["fields"] == .array([
            .object([
                "key": .string("MOCK_API_KEY"),
                "value": .string("redacted-test-key"),
            ]),
        ]))
        await client.close()
    }

    @Test("client preserves Goose custom ACP JSON-RPC error data")
    func clientPreservesCustomACPJSONRPCErrorData() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"error":{"code":-32602,"message":"Invalid params","data":"Provider does not support native authentication: xai"}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        do {
            _ = try await client.authenticateGooseProviderConfig(providerId: "xai")
            Issue.record("provider authenticate should have failed")
        } catch GooseACPProtocolError.jsonRPCError(let code, let message, let data) {
            #expect(code == -32602)
            #expect(message == "Invalid params")
            #expect(data == .string("Provider does not support native authentication: xai"))
        }
        await client.close()
    }

    @Test("timed ACP requests fail their waiter without poisoning later requests")
    func timedACPRequestsFailWithoutPoisoningLaterRequests() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        do {
            _ = try await client.listGooseProviders(timeout: .milliseconds(20))
            Issue.record("provider inventory request should have timed out")
        } catch GooseACPProtocolError.responseTimedOut(let method, let id, let timeout) {
            #expect(method == "_goose/unstable/providers/list")
            #expect(id == .int(2))
            #expect(timeout == .milliseconds(20))
        }

        let defaultsTask = Task {
            try await client.readGooseDefaults(timeout: .seconds(1))
        }
        await transport.waitUntilSent(count: 3)
        await transport.enqueue(#"{"jsonrpc":"2.0","id":2,"result":{"entries":[{"providerId":"late","configured":true}]}}"#)
        await transport.enqueue(#"{"jsonrpc":"2.0","id":3,"result":{"providerId":"mock","modelId":"mock-model"}}"#)

        let defaults = try await defaultsTask.value
        #expect(defaults.providerId == "mock")
        #expect(defaults.modelId == "mock-model")
        await client.close()
    }

    @Test("active ACP response waiters are bounded before sending another request")
    func activeACPResponseWaitersAreBoundedBeforeSendingAnotherRequest() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        let pending = (0..<GooseACPClient.maxPendingResponses).map { _ in
            Task {
                try await client.listGooseProviders()
            }
        }
        await transport.waitUntilSent(count: 1 + GooseACPClient.maxPendingResponses)

        do {
            _ = try await client.listGooseProviders()
            Issue.record("client should reject the request before adding another pending response")
        } catch GooseACPProtocolError.tooManyPendingResponses(let limit) {
            #expect(limit == GooseACPClient.maxPendingResponses)
        }
        #expect(await transport.sentMessages().count == 1 + GooseACPClient.maxPendingResponses)

        await client.close()
        for task in pending {
            _ = await task.result
        }
    }

    @Test("queued ACP events are bounded to the newest retained tail")
    func queuedEventsAreBoundedToNewestTail() async throws {
        let eventCount = GooseACPClient.maxQueuedEvents + 3
        let notifications = (0..<eventCount).map { index in
            #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"session-1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"event-\#(index)"}}}}"#
        }
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
        ] + notifications + [
            #"{"jsonrpc":"2.0","id":2,"result":{"entries":[{"providerId":"mock","configured":true}]}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        _ = try await client.listGooseProviders()

        let events = await client.drainQueuedEvents()
        let texts = events.compactMap { event -> String? in
            guard case .sessionUpdate(let notification) = event,
                  case .agentMessageChunk(let chunk) = notification.update,
                  case .text(let text) = chunk.content else {
                return nil
            }
            return text
        }
        #expect(texts.count == GooseACPClient.maxQueuedEvents)
        #expect(texts.first == "event-3")
        #expect(texts.last == "event-\(eventCount - 1)")
        await client.close()
    }

    @Test("old unmatched ACP responses cannot satisfy future requests after queue overflow")
    func oldQueuedResponsesAreEvictedBeforeFutureRequests() async throws {
        let strayResponseCount = GooseACPClient.maxQueuedResponses + 2
        let strayResponses = (0..<strayResponseCount).map { offset in
            let id = 2 + offset
            return #"{"jsonrpc":"2.0","id":\#(id),"result":{"entries":[{"providerId":"stale-\#(id)","configured":true}]}}"#
        }
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
        ] + strayResponses + [
            #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"session-1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"stray responses processed"}}}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        _ = try await client.receiveEvent()

        let providersTask = Task {
            try await client.listGooseProviders(timeout: .seconds(1))
        }
        await transport.waitUntilSent(count: 2)
        await transport.enqueue(#"{"jsonrpc":"2.0","id":2,"result":{"entries":[{"providerId":"actual","configured":true}]}}"#)

        let providers = try await providersTask.value
        #expect(providers.entries.first?.objectValue?["providerId"] == .string("actual"))
        await client.close()
    }

    @Test("client sends the settings mutation Goose custom ACP subset")
    func clientSendsSettingsMutationCustomACPSubset() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            #"{"jsonrpc":"2.0","id":2,"result":{}}"#,
            #"{"jsonrpc":"2.0","id":3,"result":{}}"#,
            #"{"jsonrpc":"2.0","id":4,"result":{"providerId":"mock","modelId":"mock-model"}}"#,
        ])
        let client = GooseACPClient(transport: transport, clientVersion: "test-version")

        _ = try await client.initialize()
        _ = try await client.saveGoosePreferences(values: [
            .init(key: .gooseThinkingEffort, value: .string("high")),
            .init(key: .autoCompactThreshold, value: .double(0.5)),
        ])
        _ = try await client.removeGoosePreferences(keys: [.voiceDictationPreferredMic])
        let defaults = try await client.saveGooseDefaults(providerId: "mock", modelId: "mock-model")

        #expect(defaults.providerId == "mock")
        #expect(defaults.modelId == "mock-model")

        let sent = await transport.sentMessages()
        let methods = sent.compactMap { $0.raw.objectValue?["method"] }
        #expect(methods == [
            .string("initialize"),
            .string("_goose/unstable/preferences/save"),
            .string("_goose/unstable/preferences/remove"),
            .string("_goose/unstable/defaults/save"),
        ])
        let saveParams = try #require(sent.dropFirst().first?.raw.objectValue?["params"]?.objectValue)
        #expect(saveParams["values"] == .array([
            .object(["key": .string("gooseThinkingEffort"), "value": .string("high")]),
            .object(["key": .string("autoCompactThreshold"), "value": .double(0.5)]),
        ]))
        let removeParams = try #require(sent.dropFirst(2).first?.raw.objectValue?["params"]?.objectValue)
        #expect(removeParams["keys"] == .array([.string("voiceDictationPreferredMic")]))
        let defaultsParams = try #require(sent.dropFirst(3).first?.raw.objectValue?["params"]?.objectValue)
        #expect(defaultsParams["providerId"] == .string("mock"))
        #expect(defaultsParams["modelId"] == .string("mock-model"))
        await client.close()
    }
}

@Suite("Goose ACP event bridge")
@MainActor
struct GooseACPEventBridgeTests {
    @Test("bridge publishes permission requests and responds with the selected native option")
    func bridgeRoutesPermissionRequests() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            """
            {
              "jsonrpc": "2.0",
              "id": "perm-1",
              "method": "session/request_permission",
              "params": {
                "sessionId": "session-1",
                "toolCall": {
                  "toolCallId": "tool-1",
                  "title": "Write file",
                  "kind": "edit",
                  "status": "pending"
                },
                "options": [
                  { "optionId": "once", "name": "Allow once", "kind": "allow_once" },
                  { "optionId": "always", "name": "Always allow", "kind": "allow_always" }
                ]
              }
            }
            """,
        ])
        let bridge = GooseACPEventBridge()

        bridge.connect(transport: transport, clientVersion: "test-version")
        try await waitUntil { bridge.pendingPermission != nil }

        let pending = try #require(bridge.pendingPermission)
        #expect(pending.request.toolCall.title == "Write file")
        #expect(pending.request.option(for: .allowAlways)?.optionId == "always")

        bridge.resolvePermission(promptID: pending.id, optionID: "always")
        await transport.waitUntilSent(count: 2)

        let sent = await transport.sentMessages()
        #expect(sent.first?.method == .initialize)
        #expect(sent.last?.id == .string("perm-1"))
        #expect(sent.last?.raw.objectValue?["result"]?.objectValue?["outcome"]?.objectValue?["optionId"] == .string("always"))
        #expect(bridge.pendingPermission == nil)
        await bridge.disconnect()
    }

    @Test("bridge ignores stale ACP response-send failures after disconnect")
    func bridgeIgnoresStaleResponseSendFailuresAfterDisconnect() async throws {
        let transport = GooseACPBlockingSendFailureTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            """
            {
              "jsonrpc": "2.0",
              "id": "perm-1",
              "method": "session/request_permission",
              "params": {
                "sessionId": "session-1",
                "toolCall": {
                  "toolCallId": "tool-1",
                  "title": "Write file",
                  "kind": "edit",
                  "status": "pending"
                },
                "options": [
                  { "optionId": "once", "name": "Allow once", "kind": "allow_once" }
                ]
              }
            }
            """,
        ])
        let bridge = GooseACPEventBridge()

        bridge.connect(transport: transport, clientVersion: "test-version")
        try await waitUntil { bridge.pendingPermission != nil }

        let pending = try #require(bridge.pendingPermission)
        bridge.resolvePermission(promptID: pending.id, optionID: "once")
        await transport.waitUntilBlockedSend()

        await bridge.disconnect()
        #expect(bridge.unhandledDiagnostics.isEmpty)

        await transport.releaseBlockedSend()
        await transport.waitUntilBlockedSendFailed()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(bridge.unhandledDiagnostics.isEmpty)
    }

    @Test("bridge clears pending ACP prompts when the connection fails")
    func bridgeClearsPendingPromptsOnConnectionFailure() async throws {
        let transport = GooseACPFramesThenFailTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            """
            {
              "jsonrpc": "2.0",
              "id": "perm-1",
              "method": "session/request_permission",
              "params": {
                "sessionId": "session-1",
                "toolCall": {
                  "toolCallId": "tool-1",
                  "title": "Write file",
                  "kind": "edit",
                  "status": "pending"
                },
                "options": [
                  { "optionId": "once", "name": "Allow once", "kind": "allow_once" }
                ]
              }
            }
            """,
        ])
        let bridge = GooseACPEventBridge()

        bridge.connect(transport: transport, clientVersion: "test-version")
        try await waitUntil {
            if case .failed = bridge.status {
                return true
            }
            return false
        }

        #expect(bridge.pendingPermission == nil)
        #expect(bridge.pendingElicitation == nil)
        await bridge.disconnect()
    }

    @Test("bridge cancels an old pending permission request before replacing it")
    func bridgeCancelsReplacedPermissionRequests() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            """
            {
              "jsonrpc": "2.0",
              "id": "perm-1",
              "method": "session/request_permission",
              "params": {
                "sessionId": "session-1",
                "toolCall": {
                  "toolCallId": "tool-1",
                  "title": "Write first",
                  "kind": "edit",
                  "status": "pending"
                },
                "options": [
                  { "optionId": "once", "name": "Allow once", "kind": "allow_once" }
                ]
              }
            }
            """,
            """
            {
              "jsonrpc": "2.0",
              "id": "perm-2",
              "method": "session/request_permission",
              "params": {
                "sessionId": "session-1",
                "toolCall": {
                  "toolCallId": "tool-2",
                  "title": "Write second",
                  "kind": "edit",
                  "status": "pending"
                },
                "options": [
                  { "optionId": "once", "name": "Allow once", "kind": "allow_once" }
                ]
              }
            }
            """,
        ])
        let bridge = GooseACPEventBridge()

        bridge.connect(transport: transport, clientVersion: "test-version")
        try await waitUntil { bridge.pendingPermission?.request.toolCall.title == "Write second" }
        await transport.waitUntilSent(count: 2)

        let pending = try #require(bridge.pendingPermission)
        #expect(pending.request.toolCall.toolCallId == "tool-2")
        let sent = await transport.sentMessages()
        #expect(sent.first?.method == .initialize)
        #expect(sent.last?.id == .string("perm-1"))
        let result = try #require(sent.last?.raw.objectValue?["result"]?.objectValue)
        let outcome = try #require(result["outcome"]?.objectValue)
        #expect(outcome["outcome"] == .string("cancelled"))
        await bridge.disconnect()
    }

    @Test("bridge publishes form elicitation requests and responds with native field values")
    func bridgeRoutesFormElicitationRequests() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            """
            {
              "jsonrpc": "2.0",
              "id": 7,
              "method": "elicitation/create",
              "params": {
                "mode": "form",
                "sessionId": "session-1",
                "message": "Need a title",
                "requestedSchema": {
                  "type": "object",
                  "properties": {
                    "title": { "type": "string", "title": "Title" }
                  },
                  "required": ["title"]
                }
              }
            }
            """,
        ])
        let bridge = GooseACPEventBridge()

        bridge.connect(transport: transport, clientVersion: "test-version")
        try await waitUntil { bridge.pendingElicitation != nil }

        let pending = try #require(bridge.pendingElicitation)
        #expect(pending.message == "Need a title")
        #expect(pending.fields == [.init(id: "title", title: "Title", type: .string, isRequired: true)])

        bridge.acceptElicitation(promptID: pending.id, values: ["title": .string("Native answer")])
        await transport.waitUntilSent(count: 2)

        let sent = await transport.sentMessages()
        #expect(sent.last?.id == .int(7))
        #expect(sent.last?.raw.objectValue?["result"]?.objectValue?["action"] == .string("accept"))
        #expect(sent.last?.raw.objectValue?["result"]?.objectValue?["content"]?.objectValue?["title"] == .string("Native answer"))
        #expect(bridge.pendingElicitation == nil)
        await bridge.disconnect()
    }

    @Test("bridge cancels an old pending elicitation request before replacing it")
    func bridgeCancelsReplacedElicitationRequests() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            """
            {
              "jsonrpc": "2.0",
              "id": 7,
              "method": "elicitation/create",
              "params": {
                "mode": "form",
                "sessionId": "session-1",
                "message": "First title",
                "requestedSchema": {
                  "type": "object",
                  "properties": {
                    "title": { "type": "string", "title": "Title" }
                  }
                }
              }
            }
            """,
            """
            {
              "jsonrpc": "2.0",
              "id": 8,
              "method": "elicitation/create",
              "params": {
                "mode": "form",
                "sessionId": "session-1",
                "message": "Second title",
                "requestedSchema": {
                  "type": "object",
                  "properties": {
                    "title": { "type": "string", "title": "Title" }
                  }
                }
              }
            }
            """,
        ])
        let bridge = GooseACPEventBridge()

        bridge.connect(transport: transport, clientVersion: "test-version")
        try await waitUntil { bridge.pendingElicitation?.message == "Second title" }
        await transport.waitUntilSent(count: 2)

        let pending = try #require(bridge.pendingElicitation)
        #expect(pending.message == "Second title")
        let sent = await transport.sentMessages()
        #expect(sent.first?.method == .initialize)
        #expect(sent.last?.id == .int(7))
        #expect(sent.last?.raw.objectValue?["result"]?.objectValue?["action"] == .string("cancel"))
        await bridge.disconnect()
    }

    @Test("bridge retries an initial ACP handshake failure before marking the connection failed")
    func bridgeRetriesInitialHandshakeFailure() async throws {
        let sequence = GooseACPTransportSequence([
            GooseACPFailingTransport(),
            GooseACPMemoryTransport(incoming: [
                #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            ]),
        ])
        let bridge = GooseACPEventBridge()

        bridge.connect(
            transportFactory: { sequence.next() },
            clientVersion: "test-version",
            initialHandshakeAttempts: 2
        )
        try await waitUntil {
            if case .connected = bridge.status {
                return true
            }
            return false
        }

        #expect(sequence.requestedCount() == 2)
        await bridge.disconnect()
    }

    @Test("bridge surfaces unhandled ACP requests and replies with a structured JSON-RPC error")
    func bridgeSurfacesUnhandledRequests() async throws {
        let transport = GooseACPMemoryTransport(incoming: [
            #"{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1,"agentCapabilities":{},"agentInfo":{"name":"goose","version":"dev"}}}"#,
            """
            {
              "jsonrpc": "2.0",
              "id": "custom-1",
              "method": "_goose/unstable/session/recipe/request-params",
              "params": {
                "sessionId": "session-1",
                "recipe": { "title": "Needs input" }
              }
            }
            """,
        ])
        let bridge = GooseACPEventBridge()

        bridge.connect(transport: transport, clientVersion: "test-version")
        try await waitUntil { !bridge.unhandledDiagnostics.isEmpty }
        await transport.waitUntilSent(count: 2)

        let diagnostic = try #require(bridge.unhandledDiagnostics.first)
        #expect(diagnostic.kind == .request)
        #expect(diagnostic.method == "_goose/unstable/session/recipe/request-params")
        #expect(diagnostic.parameterSummary.contains("sessionId"))

        let sent = await transport.sentMessages()
        #expect(sent.last?.id == .string("custom-1"))
        let error = try #require(sent.last?.raw.objectValue?["error"]?.objectValue)
        #expect(error["code"] == .int(-32601))
        #expect(error["message"] == .string("Unsupported ACP request: _goose/unstable/session/recipe/request-params"))
        await bridge.disconnect()
    }
}

@Suite("Goose Web native prompt bridge")
@MainActor
struct GooseWebNativePromptBridgeTests {
    @Test("native prompt bridge publishes renderer permission requests and replies with selected outcome")
    func bridgeRoutesRendererPermissionRequests() throws {
        let bridge = GooseWebNativePromptBridge()
        let capture = GoosePromptReplyCapture()

        bridge.receivePromptMessage([
            "type": "permission",
            "id": "native-perm-1",
            "request": [
                "sessionId": "session-1",
                "toolCall": [
                    "toolCallId": "tool-1",
                    "title": "Write file",
                    "kind": "edit",
                    "status": "pending",
                ],
                "options": [
                    ["optionId": "once", "name": "Allow once", "kind": "allow_once"],
                    ["optionId": "always", "name": "Always allow", "kind": "allow_always"],
                ],
            ],
        ]) { object, error in
            capture.capture(object: object, error: error)
        }

        let pending = try #require(bridge.pendingPermission)
        #expect(pending.id == "native-perm-1")
        #expect(pending.request.toolCall.title == "Write file")

        bridge.resolvePermission(promptID: pending.id, optionID: "always")
        let reply = try #require(capture.object as? [String: Any])
        let outcome = try #require(reply["outcome"] as? [String: Any])
        #expect(outcome["outcome"] as? String == "selected")
        #expect(outcome["optionId"] as? String == "always")
        #expect(capture.error == nil)
        #expect(bridge.pendingPermission == nil)
    }

    @Test("native prompt bridge publishes renderer elicitation requests and replies with form values")
    func bridgeRoutesRendererElicitationRequests() throws {
        let bridge = GooseWebNativePromptBridge()
        let capture = GoosePromptReplyCapture()

        bridge.receivePromptMessage([
            "type": "elicitation",
            "id": "native-elicit-1",
            "request": [
                "mode": "form",
                "sessionId": "session-1",
                "message": "Need a title",
                "requestedSchema": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string", "title": "Title"],
                    ],
                    "required": ["title"],
                ],
            ],
        ]) { object, error in
            capture.capture(object: object, error: error)
        }

        let pending = try #require(bridge.pendingElicitation)
        #expect(pending.id == "native-elicit-1")
        #expect(pending.message == "Need a title")
        #expect(pending.fields == [.init(id: "title", title: "Title", type: .string, isRequired: true)])

        bridge.acceptElicitation(promptID: pending.id, values: ["title": .string("Native answer")])
        let reply = try #require(capture.object as? [String: Any])
        let content = try #require(reply["content"] as? [String: Any])
        #expect(reply["action"] as? String == "accept")
        #expect(content["title"] as? String == "Native answer")
        #expect(capture.error == nil)
        #expect(bridge.pendingElicitation == nil)
    }

    @Test("native prompt bridge cancels pending renderer replies on deinit")
    func bridgeCancelsPendingRendererRepliesOnDeinit() throws {
        let permissionCapture = GoosePromptReplyCapture()
        let elicitationCapture = GoosePromptReplyCapture()

        do {
            let bridge = GooseWebNativePromptBridge()
            bridge.receivePromptMessage([
                "type": "permission",
                "id": "native-perm-deinit",
                "request": [
                    "sessionId": "session-1",
                    "toolCall": [
                        "toolCallId": "tool-1",
                        "title": "Write file",
                        "kind": "edit",
                        "status": "pending",
                    ],
                    "options": [
                        ["optionId": "once", "name": "Allow once", "kind": "allow_once"],
                    ],
                ],
            ]) { object, error in
                permissionCapture.capture(object: object, error: error)
            }
            bridge.receivePromptMessage([
                "type": "elicitation",
                "id": "native-elicit-deinit",
                "request": [
                    "mode": "form",
                    "sessionId": "session-1",
                    "message": "Need a title",
                    "requestedSchema": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string", "title": "Title"],
                        ],
                    ],
                ],
            ]) { object, error in
                elicitationCapture.capture(object: object, error: error)
            }
            #expect(bridge.pendingPermission != nil)
            #expect(bridge.pendingElicitation != nil)
        }

        let permissionReply = try #require(permissionCapture.object as? [String: Any])
        let outcome = try #require(permissionReply["outcome"] as? [String: Any])
        #expect(outcome["outcome"] as? String == "cancelled")
        #expect(permissionCapture.error == nil)

        let elicitationReply = try #require(elicitationCapture.object as? [String: Any])
        #expect(elicitationReply["action"] as? String == "cancel")
        #expect(elicitationCapture.error == nil)
    }
}

@MainActor
private final class GoosePromptReplyCapture {
    var object: Any?
    var error: String?

    func capture(object: Any?, error: String?) {
        self.object = object
        self.error = error
    }
}

actor GooseACPMemoryTransport: GooseACPTransport {
    private var incoming: [String]
    private var sent: [String] = []
    private var receiveWaiters: [CheckedContinuation<String?, Error>] = []
    private var receiveWaiterCountWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var sentCountWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var isClosed = false

    init(incoming: [String]) {
        self.incoming = incoming
    }

    func send(_ text: String) async throws {
        sent.append(text)
        resumeSentCountWaiters()
    }

    func receive() async throws -> String? {
        guard !isClosed else { return nil }

        guard incoming.isEmpty else {
            return incoming.removeFirst()
        }

        return try await withCheckedThrowingContinuation { continuation in
            receiveWaiters.append(continuation)
            resumeReceiveWaiterCountWaiters()
        }
    }

    func close() async {
        isClosed = true
        let waiters = receiveWaiters
        receiveWaiters.removeAll()
        for continuation in waiters {
            continuation.resume(returning: nil)
        }
    }

    func enqueue(_ text: String) {
        guard !isClosed else { return }

        if receiveWaiters.isEmpty {
            incoming.append(text)
        } else {
            receiveWaiters.removeFirst().resume(returning: text)
        }
    }

    func waitUntilSent(count: Int) async {
        guard sent.count < count else { return }
        await withCheckedContinuation { continuation in
            sentCountWaiters.append((count: count, continuation: continuation))
        }
    }

    func waitUntilReceiveWaiters(count: Int) async {
        guard receiveWaiters.count < count else { return }
        await withCheckedContinuation { continuation in
            receiveWaiterCountWaiters.append((count: count, continuation: continuation))
        }
    }

    func sentMessages() -> [GooseACPSentMessage] {
        sent.compactMap { text in
            guard let data = text.data(using: .utf8),
                  let raw = try? JSONDecoder().decode(JSONValue.self, from: data) else {
                return nil
            }
            let object: [String: JSONValue]?
            if case .object(let decodedObject) = raw {
                object = decodedObject
            } else {
                object = nil
            }
            let method: GooseACPMethod?
            if case .string(let rawMethod)? = object?["method"] {
                method = GooseACPMethod(rawValue: rawMethod)
            } else {
                method = nil
            }
            let id = object?["id"].flatMap { try? JSONDecoder().decode(GooseACPRequestID.self, from: JSONEncoder().encode($0)) }
            return GooseACPSentMessage(raw: raw, method: method, id: id)
        }
    }

    private func resumeSentCountWaiters() {
        var stillWaiting: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
        for waiter in sentCountWaiters {
            if sent.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                stillWaiting.append(waiter)
            }
        }
        sentCountWaiters = stillWaiting
    }

    private func resumeReceiveWaiterCountWaiters() {
        var stillWaiting: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
        for waiter in receiveWaiterCountWaiters {
            if receiveWaiters.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                stillWaiting.append(waiter)
            }
        }
        receiveWaiterCountWaiters = stillWaiting
    }
}

private actor GooseACPBlockingSendFailureTransport: GooseACPTransport {
    private var incoming: [String]
    private var sent: [String] = []
    private var receiveWaiters: [CheckedContinuation<String?, Error>] = []
    private var blockedSendContinuation: CheckedContinuation<Void, Never>?
    private var blockedSendWaiters: [CheckedContinuation<Void, Never>] = []
    private var blockedSendFailedWaiters: [CheckedContinuation<Void, Never>] = []
    private var isClosed = false
    private var blockedSendFailed = false

    init(incoming: [String]) {
        self.incoming = incoming
    }

    func send(_ text: String) async throws {
        sent.append(text)
        guard sent.count == 2 else { return }
        await withCheckedContinuation { continuation in
            blockedSendContinuation = continuation
            resumeBlockedSendWaiters()
        }
        blockedSendFailed = true
        resumeBlockedSendFailedWaiters()
        throw GooseACPInjectedFailure()
    }

    func receive() async throws -> String? {
        guard !isClosed else { return nil }

        guard incoming.isEmpty else {
            return incoming.removeFirst()
        }

        return try await withCheckedThrowingContinuation { continuation in
            receiveWaiters.append(continuation)
        }
    }

    func close() async {
        isClosed = true
        let waiters = receiveWaiters
        receiveWaiters.removeAll()
        for continuation in waiters {
            continuation.resume(returning: nil)
        }
    }

    func waitUntilBlockedSend() async {
        guard blockedSendContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            blockedSendWaiters.append(continuation)
        }
    }

    func releaseBlockedSend() {
        blockedSendContinuation?.resume()
        blockedSendContinuation = nil
    }

    func waitUntilBlockedSendFailed() async {
        guard !blockedSendFailed else { return }
        await withCheckedContinuation { continuation in
            blockedSendFailedWaiters.append(continuation)
        }
    }

    private func resumeBlockedSendWaiters() {
        let waiters = blockedSendWaiters
        blockedSendWaiters.removeAll()
        for continuation in waiters {
            continuation.resume()
        }
    }

    private func resumeBlockedSendFailedWaiters() {
        let waiters = blockedSendFailedWaiters
        blockedSendFailedWaiters.removeAll()
        for continuation in waiters {
            continuation.resume()
        }
    }
}

struct GooseACPSentMessage: Equatable {
    let raw: JSONValue
    let method: GooseACPMethod?
    let id: GooseACPRequestID?
}

@MainActor
private final class GooseACPTransportSequence {
    private var transports: [any GooseACPTransport]
    private var count = 0

    init(_ transports: [any GooseACPTransport]) {
        self.transports = transports
    }

    func next() -> any GooseACPTransport {
        count += 1
        if transports.count > 1 {
            return transports.removeFirst()
        }
        return transports[0]
    }

    func requestedCount() -> Int {
        count
    }
}

private actor GooseACPFailingTransport: GooseACPTransport {
    func send(_ text: String) async throws {
        throw GooseACPInjectedFailure()
    }

    func receive() async throws -> String? {
        throw GooseACPInjectedFailure()
    }

    func close() async {}
}

private actor GooseACPFramesThenFailTransport: GooseACPTransport {
    private var incoming: [String]

    init(incoming: [String]) {
        self.incoming = incoming
    }

    func send(_ text: String) async throws {}

    func receive() async throws -> String? {
        guard !incoming.isEmpty else {
            throw GooseACPInjectedFailure()
        }
        return incoming.removeFirst()
    }

    func close() async {}
}

private struct GooseACPInjectedFailure: LocalizedError {
    var errorDescription: String? {
        "Injected ACP handshake failure"
    }
}

@MainActor
private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async throws {
    for _ in 0..<50 {
        if condition() { return }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    Issue.record("condition was not satisfied")
}

private func encodedObject<T: Encodable>(_ value: T) throws -> [String: JSONValue] {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode([String: JSONValue].self, from: data)
}

private extension JSONValue {
    nonisolated var objectValue: [String: JSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }

    nonisolated var stringValue: String? {
        guard case .string(let string) = self else { return nil }
        return string
    }

    nonisolated func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
