import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Local Backend LLM Client")
struct LocalBackendLLMClientTests {
    private final class AgentEventSink {
        private(set) var events: [AgentProvenanceEvent] = []

        func append(_ event: AgentProvenanceEvent) -> Bool {
            events.append(event)
            return true
        }
    }

    private struct RoutedCall: Equatable {
        let prompt: String
        let systemPrompt: String?
        let maxTokens: Int
        let reasoningMode: LocalReasoningMode
        let modelID: String?
        let requestedRuntimeKind: BackendRuntimeKind?
        let steeringHintsJSON: String?
    }

    private final class StubRoutedLocalClient: RoutedLocalRuntimeClient {
        let response: String
        let streamError: Error?
        var generateCalls: [RoutedCall] = []

        init(response: String, streamError: Error? = nil) {
            self.response = response
            self.streamError = streamError
        }

        func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
            try await generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: .fast,
                modelID: nil,
                requestedRuntimeKind: nil,
                steeringHintsJSON: nil
            )
        }

        func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
            stream(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: .fast,
                modelID: nil,
                requestedRuntimeKind: nil,
                steeringHintsJSON: nil
            )
        }

        func generate(
            prompt: String,
            systemPrompt: String?,
            maxTokens: Int,
            reasoningMode: LocalReasoningMode,
            modelID: String?
        ) async throws -> String {
            try await generate(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID,
                requestedRuntimeKind: nil,
                steeringHintsJSON: nil
            )
        }

        func stream(
            prompt: String,
            systemPrompt: String?,
            maxTokens: Int,
            reasoningMode: LocalReasoningMode,
            modelID: String?
        ) -> AsyncThrowingStream<String, Error> {
            stream(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID,
                requestedRuntimeKind: nil,
                steeringHintsJSON: nil
            )
        }

        func generate(
            prompt: String,
            systemPrompt: String?,
            maxTokens: Int,
            reasoningMode: LocalReasoningMode,
            modelID: String?,
            requestedRuntimeKind: BackendRuntimeKind?,
            steeringHintsJSON: String?
        ) async throws -> String {
            generateCalls.append(
                RoutedCall(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID,
                    requestedRuntimeKind: requestedRuntimeKind,
                    steeringHintsJSON: steeringHintsJSON
                )
            )
            return response
        }

        func stream(
            prompt: String,
            systemPrompt: String?,
            maxTokens: Int,
            reasoningMode: LocalReasoningMode,
            modelID: String?,
            requestedRuntimeKind: BackendRuntimeKind?,
            steeringHintsJSON: String?
        ) -> AsyncThrowingStream<String, Error> {
            generateCalls.append(
                RoutedCall(
                    prompt: prompt,
                    systemPrompt: systemPrompt,
                    maxTokens: maxTokens,
                    reasoningMode: reasoningMode,
                    modelID: modelID,
                    requestedRuntimeKind: requestedRuntimeKind,
                    steeringHintsJSON: steeringHintsJSON
                )
            )
            return AsyncThrowingStream { continuation in
                if let streamError {
                    continuation.finish(throwing: streamError)
                    return
                }
                continuation.yield(response)
                continuation.finish()
            }
        }

        func testConnection() async -> ConnectionTestResult {
            ConnectionTestResult(success: true, message: response)
        }

        func configSnapshot() -> LLMSnapshot {
            LLMSnapshot(provider: .localMLX, model: "", reasoningMode: .fast)
        }
    }

    private enum AgentEventTestError: Error {
        case backendSecret
    }

    private func makeInferenceState() -> InferenceState {
        InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            ),
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
    }

    private func makeTemporaryPreparedDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("main local generation resolves to gguf when the configured gguf runtime is available")
    func mainLocalGenerationResolvesToGGUFWhenAvailable() async throws {
        let inference = makeInferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        let preparedDirectory = try makeTemporaryPreparedDirectory()
        defer { try? FileManager.default.removeItem(at: preparedDirectory) }

        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let mlxClient = StubRoutedLocalClient(response: "mlx")
        let ggufClient = StubRoutedLocalClient(response: "gguf")
        let client = LocalBackendLLMClient(
            inference: inference,
            runtimeControlPlane: controlPlane,
            mlxClient: mlxClient,
            ggufClient: ggufClient,
            refreshAvailableRuntimeKinds: { _, _ in [.mlx, .gguf] },
            preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    mlxOutputPath: preparedDirectory.path,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            )
        )

        let output = try await client.generate(
            prompt: "hello",
            systemPrompt: "be brief",
            maxTokens: 32,
            reasoningMode: LocalReasoningMode.fast,
            modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue
        )

        #expect(output == "gguf")
        #expect(ggufClient.generateCalls.count == 1)
        #expect(ggufClient.generateCalls.first?.requestedRuntimeKind == .gguf)
        #expect(mlxClient.generateCalls.isEmpty)
        #expect(inference.availableLocalGenerationRuntimeKinds == [.mlx, .gguf])
    }

    @Test("main local generation falls back to mlx explicitly when gguf is unavailable")
    func mainLocalGenerationFallsBackToMLXExplicitly() async throws {
        let inference = makeInferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)

        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let mlxClient = StubRoutedLocalClient(response: "mlx")
        let ggufClient = StubRoutedLocalClient(response: "gguf")
        let client = LocalBackendLLMClient(
            inference: inference,
            runtimeControlPlane: controlPlane,
            mlxClient: mlxClient,
            ggufClient: ggufClient,
            refreshAvailableRuntimeKinds: { _, _ in [.mlx] },
            preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            )
        )

        let output = try await client.generate(
            prompt: "hello",
            systemPrompt: nil as String?,
            maxTokens: 32,
            reasoningMode: LocalReasoningMode.fast,
            modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue
        )

        #expect(output == "mlx")
        #expect(mlxClient.generateCalls.count == 1)
        #expect(mlxClient.generateCalls.first?.requestedRuntimeKind == .mlx)
        #expect(ggufClient.generateCalls.isEmpty)
        #expect(inference.availableLocalGenerationRuntimeKinds == [.mlx])
    }

    @Test("backend client snapshot reports gguf when the prepared primary runtime is gguf and available")
    func backendClientSnapshotReportsGGUFWhenPreparedPrimaryRuntimeIsGGUFAndAvailable() throws {
        let inference = makeInferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        let preparedDirectory = try makeTemporaryPreparedDirectory()
        defer { try? FileManager.default.removeItem(at: preparedDirectory) }

        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx, .gguf],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let mlxClient = StubRoutedLocalClient(response: "mlx")
        let ggufClient = StubRoutedLocalClient(response: "gguf")
        let client = LocalBackendLLMClient(
            inference: inference,
            runtimeControlPlane: controlPlane,
            mlxClient: mlxClient,
            ggufClient: ggufClient,
            refreshAvailableRuntimeKinds: { _, _ in [.mlx, .gguf] },
            preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    mlxOutputPath: preparedDirectory.path,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            )
        )

        let snapshot = client.configSnapshot()

        #expect(snapshot.provider == .localGGUF)
        #expect(snapshot.model == LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
    }

    @Test("missing prepared gguf assets do not hijack installed mlx local models")
    func missingPreparedGGUFAssetsDoNotHijackInstalledMLXLocalModels() async throws {
        let inference = makeInferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)

        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let mlxClient = StubRoutedLocalClient(response: "mlx")
        let ggufClient = StubRoutedLocalClient(response: "gguf")
        let client = LocalBackendLLMClient(
            inference: inference,
            runtimeControlPlane: controlPlane,
            mlxClient: mlxClient,
            ggufClient: ggufClient,
            refreshAvailableRuntimeKinds: { _, _ in [.mlx] },
            preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    mlxOutputPath: "/tmp/does-not-exist-\(UUID().uuidString)",
                    status: "missing"
                ),
                speculativeDraftGenerator: nil
            )
        )

        let output = try await client.generate(
            prompt: "hello",
            systemPrompt: nil as String?,
            maxTokens: 32,
            reasoningMode: LocalReasoningMode.fast,
            modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue
        )

        #expect(output == "mlx")
        #expect(mlxClient.generateCalls.count == 1)
        #expect(mlxClient.generateCalls.first?.requestedRuntimeKind == .mlx)
        #expect(ggufClient.generateCalls.isEmpty)
        #expect(client.configSnapshot().provider == .localMLX)
    }

    @Test("gguf only selections fail instead of silently rerouting to mlx")
    func ggufOnlySelectionsFailInsteadOfSilentlyReroutingToMLX() async throws {
        let inference = makeInferenceState()
        inference.setPreparedLocalTextModelIDs([LocalTextModelID.qwopus27Bv3.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwopus27Bv3.rawValue)
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])

        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let mlxClient = StubRoutedLocalClient(response: "mlx")
        let ggufClient = StubRoutedLocalClient(response: "gguf")
        let client = LocalBackendLLMClient(
            inference: inference,
            runtimeControlPlane: controlPlane,
            mlxClient: mlxClient,
            ggufClient: ggufClient,
            refreshAvailableRuntimeKinds: { _, _ in [.mlx] },
            preparedGenerationRuntimeConfiguration: nil
        )

        await #expect(throws: LocalInferenceRoutingError.runtimeUnavailable) {
            _ = try await client.generate(
                prompt: "hello",
                systemPrompt: nil as String?,
                maxTokens: 32,
                reasoningMode: LocalReasoningMode.fast,
                modelID: LocalTextModelID.qwopus27Bv3.rawValue
            )
        }

        #expect(ggufClient.generateCalls.isEmpty)
        #expect(mlxClient.generateCalls.isEmpty)
    }

    @Test("backend stream records sanitized AgentEvents")
    func backendStreamRecordsSanitizedAgentEvents() async throws {
        let inference = makeInferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        let preparedDirectory = try makeTemporaryPreparedDirectory()
        defer { try? FileManager.default.removeItem(at: preparedDirectory) }

        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx, .gguf],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let mlxClient = StubRoutedLocalClient(response: "mlx secret streamed output")
        let ggufClient = StubRoutedLocalClient(response: "gguf secret streamed output")
        let sink = AgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 789 },
            persist: { event in sink.append(event) }
        )
        let client = LocalBackendLLMClient(
            inference: inference,
            runtimeControlPlane: controlPlane,
            mlxClient: mlxClient,
            ggufClient: ggufClient,
            refreshAvailableRuntimeKinds: { _, _ in [.mlx, .gguf] },
            preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    mlxOutputPath: preparedDirectory.path,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            ),
            agentProvenanceRecorder: recorder
        )
        let secretPrompt = "secret backend prompt"
        let secretSystemPrompt = "secret backend system"
        let secretHints = "{\"secret\":\"backend hint\"}"

        let output = try await collectStream(
            client.stream(
                prompt: secretPrompt,
                systemPrompt: secretSystemPrompt,
                maxTokens: 42,
                reasoningMode: .fast,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                requestedRuntimeKind: nil,
                steeringHintsJSON: secretHints
            )
        )

        #expect(output == "gguf secret streamed output")
        #expect(ggufClient.generateCalls.count == 1)
        #expect(mlxClient.generateCalls.isEmpty)
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("local-backend-stream-") == true)
        #expect(sink.events.allSatisfy { event in
            if case .agent(let id, let modelID) = event.actor {
                return id == "local-backend-llm-client" && modelID == nil
            }
            return false
        })
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "local_backend.stream" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "local-backend-stream:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "local_backend_llm_client" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "stream" })
        #expect(sink.events.allSatisfy { $0.metadata["provider"] == "local_backend" })
        #expect(sink.events.last?.metadata["resolved_runtime"] == BackendRuntimeKind.gguf.rawValue)
        #expect(sink.events.last?.metadata["requested_runtime"] == BackendRuntimeKind.gguf.rawValue)
        #expect(sink.events.last?.metadata["reasoning_mode"] == LocalReasoningMode.fast.rawValue)
        #expect(sink.events.last?.metadata["max_tokens"] == "42")
        #expect(sink.events.last?.metadata["prompt_char_count"] == "\(secretPrompt.count)")
        #expect(sink.events.last?.metadata["system_prompt_char_count"] == "\(secretSystemPrompt.count)")
        #expect(sink.events.last?.metadata["steering_hints_present"] == "true")

        let argumentsPayload = try payload(from: sink.events.last?.tool?.argumentsJSON)
        #expect(Set(argumentsPayload.keys) == [
            "max_tokens",
            "prompt_char_count",
            "provider",
            "reasoning_mode",
            "requested_runtime",
            "resolved_runtime",
            "steering_hints_present",
            "system_prompt_char_count"
        ])
        #expect(argumentsPayload["prompt_char_count"] as? Int == secretPrompt.count)
        #expect(argumentsPayload["system_prompt_char_count"] as? Int == secretSystemPrompt.count)
        #expect(argumentsPayload["provider"] as? String == "local_backend")

        let resultPayload = try payload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["chunk_count", "elapsed_ms", "output_char_count", "success"])
        #expect(resultPayload["success"] as? Bool == true)
        #expect(resultPayload["chunk_count"] as? Int == 1)
        #expect(resultPayload["output_char_count"] as? Int == 27)
        #expect(sink.events.last?.tool?.status == .completed)
        #expect(sink.events.last?.tool?.errorMessage == nil)

        try assertNoLocalBackendSecretLeak(
            in: sink.events,
            forbidden: [
                secretPrompt,
                secretSystemPrompt,
                secretHints,
                "gguf secret streamed output",
                "mlx secret streamed output",
                "qwen35-35b-a3b-apexmini",
                LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                preparedDirectory.path
            ]
        )
    }

    @Test("backend stream records sanitized failed AgentEvent")
    func backendStreamRecordsSanitizedFailedAgentEvent() async throws {
        let inference = makeInferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        let preparedDirectory = try makeTemporaryPreparedDirectory()
        defer { try? FileManager.default.removeItem(at: preparedDirectory) }

        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx, .gguf],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let mlxClient = StubRoutedLocalClient(response: "mlx unused")
        let ggufClient = StubRoutedLocalClient(
            response: "gguf unused",
            streamError: AgentEventTestError.backendSecret
        )
        let sink = AgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 790 },
            persist: { event in sink.append(event) }
        )
        let client = LocalBackendLLMClient(
            inference: inference,
            runtimeControlPlane: controlPlane,
            mlxClient: mlxClient,
            ggufClient: ggufClient,
            refreshAvailableRuntimeKinds: { _, _ in [.mlx, .gguf] },
            preparedGenerationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    mlxOutputPath: preparedDirectory.path,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            ),
            agentProvenanceRecorder: recorder
        )

        do {
            _ = try await collectStream(
                client.stream(
                    prompt: "secret backend prompt",
                    systemPrompt: "secret backend system",
                    maxTokens: 42,
                    reasoningMode: .fast,
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    requestedRuntimeKind: nil,
                    steeringHintsJSON: "{\"secret\":\"backend hint\"}"
                )
            )
            Issue.record("Expected local backend stream to fail.")
        } catch AgentEventTestError.backendSecret {
        } catch {
            Issue.record("Expected backendSecret failure, got \(error).")
        }

        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage == "backend_failure")
        #expect(sink.events.last?.metadata["failure_class"] == "backend_failure")

        let resultPayload = try payload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["elapsed_ms", "success"])
        #expect(resultPayload["success"] as? Bool == false)

        try assertNoLocalBackendSecretLeak(
            in: sink.events,
            forbidden: [
                "secret backend prompt",
                "secret backend system",
                "{\"secret\":\"backend hint\"}",
                "gguf unused",
                "mlx unused",
                "backendSecret",
                "qwen35-35b-a3b-apexmini",
                LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                preparedDirectory.path
            ]
        )
    }

    private func collectStream(_ stream: AsyncThrowingStream<String, Error>) async throws -> String {
        var output = ""
        for try await token in stream {
            output += token
        }
        return output
    }

    private func payload(from json: String?) throws -> [String: Any] {
        let json = try #require(json)
        let data = try #require(json.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func assertNoLocalBackendSecretLeak(
        in events: [AgentProvenanceEvent],
        forbidden: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let persisted = try events.map { event -> String in
            let data = try JSONEncoder().encode(event)
            return try #require(String(data: data, encoding: .utf8))
        }.joined(separator: "\n")

        for value in forbidden {
            #expect(!persisted.contains(value), "AgentEvent persisted forbidden value: \(value)", sourceLocation: sourceLocation)
        }
    }
}
