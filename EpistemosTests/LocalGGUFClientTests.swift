import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class LocalGGUFAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

private enum LocalGGUFClientAgentEventTestError: Error {
    case backendSecret
}

@Suite("Local GGUF Client")
struct LocalGGUFClientTests {
    private actor ObservedProfileBox {
        private var profile: LocalGGUFRunProfile?

        func set(_ profile: LocalGGUFRunProfile) {
            self.profile = profile
        }

        func get() -> LocalGGUFRunProfile? {
            profile
        }
    }

    @MainActor
    @Test("gguf runtime resolves prepared artifact files on disk without probing a local endpoint")
    func ggufRuntimeResolvesPreparedArtifactFilesOnDisk() async throws {
        let fixture = try makeGGUFFixture(named: [
            "miscellaneous-model.gguf",
            "qwen35-35b-a3b-apexmini.gguf",
        ])
        defer { try? FileManager.default.removeItem(at: fixture) }

        let runtime = makeRuntime(output: "unused")
        let availability = try await runtime.availability(
            requestedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
            artifactID: "qwen35-35b-a3b-apexmini",
            modelDirectory: fixture
        )

        #expect(availability.runtimeKind == .gguf)
        #expect(availability.resolvedModelID == "qwen35-35b-a3b-apexmini")
        #expect(availability.modelURL.lastPathComponent == "qwen35-35b-a3b-apexmini.gguf")
    }

    @MainActor
    @Test("gguf runtime generates text through the in-process engine")
    func ggufRuntimeGeneratesTextThroughInProcessEngine() async throws {
        let fixture = try makeGGUFFixture(named: [
            "qwen35-35b-a3b-apexmini.gguf",
        ])
        defer { try? FileManager.default.removeItem(at: fixture) }

        let runtime = makeRuntime(output: "Hello from gguf")
        let availability = try await runtime.availability(
            requestedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
            artifactID: "qwen35-35b-a3b-apexmini",
            modelDirectory: fixture
        )
        let output = try await runtime.generate(
            request: LocalGGUFRequest(
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                artifactID: "qwen35-35b-a3b-apexmini",
                modelURL: availability.modelURL,
                prompt: "Say hello",
                systemPrompt: "Be concise.",
                maxTokens: 24,
                reasoningMode: .fast,
                steeringHintsJSON: nil,
                requestedRuntimeKind: .gguf,
                resolvedRuntimeKind: .gguf
            )
        )

        #expect(output == "Hello from gguf")
        let profile = await runtime.profilingSnapshot()
        #expect(profile?.resolvedRuntimeKind == .gguf)
        #expect(profile?.resolvedModelID == "qwen35-35b-a3b-apexmini")
        #expect(profile?.modelURL.lastPathComponent == "qwen35-35b-a3b-apexmini.gguf")
    }

    @MainActor
    @Test("gguf client publishes run profiles for shared runtime health")
    func ggufClientPublishesRunProfilesForSharedRuntimeHealth() async throws {
        let fixture = try makeGGUFFixture(named: [
            "qwen35-35b-a3b-apexmini.gguf",
        ])
        defer { try? FileManager.default.removeItem(at: fixture) }

        let runtime = makeRuntime(output: "Profile from gguf")
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx, .gguf],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            ),
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setPreparedLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)

        let client = LocalGGUFClient(
            runtime: runtime,
            inference: inference,
            runtimeControlPlane: controlPlane
        )
        client.configurePreparedGenerationRuntime(
            PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    mlxOutputPath: fixture.path,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            )
        )

        let observedProfile = ObservedProfileBox()
        client.setOnRunProfileUpdated { profile in
            Task {
                await observedProfile.set(profile)
            }
        }

        let output = try await client.generate(
            prompt: "Say hello",
            systemPrompt: "Be concise.",
            maxTokens: 24,
            reasoningMode: .fast,
            modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
            requestedRuntimeKind: .gguf,
            steeringHintsJSON: nil
        )

        #expect(output == "Profile from gguf")
        let recordedProfile = await observedProfile.get()
        #expect(recordedProfile?.resolvedRuntimeKind == .gguf)
        #expect(recordedProfile?.resolvedModelID == "qwen35-35b-a3b-apexmini")
        #expect(recordedProfile?.modelURL.lastPathComponent == "qwen35-35b-a3b-apexmini.gguf")
    }

    @MainActor
    @Test("gguf client generate records sanitized AgentEvents")
    func ggufClientGenerateRecordsSanitizedAgentEvents() async throws {
        let fixture = try makeGGUFFixture(named: [
            "qwen35-35b-a3b-apexmini.gguf",
        ])
        defer { try? FileManager.default.removeItem(at: fixture) }

        let runtime = makeRuntime(output: "Secret local output")
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: false
            )
        )
        let inference = makeLocalGGUFInference()
        let sink = LocalGGUFAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 123 },
            persist: { event in sink.append(event) }
        )
        let client = LocalGGUFClient(
            runtime: runtime,
            inference: inference,
            runtimeControlPlane: controlPlane,
            agentProvenanceRecorder: recorder
        )
        client.configurePreparedGenerationRuntime(
            PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    mlxOutputPath: fixture.path,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            )
        )

        let output = try await client.generate(
            prompt: "secret gguf prompt",
            systemPrompt: "secret gguf system",
            maxTokens: 24,
            reasoningMode: .fast,
            modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
            requestedRuntimeKind: .gguf,
            steeringHintsJSON: "{\"secret\":\"hint\"}"
        )

        #expect(output == "Secret local output")
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("local-gguf-generate-") == true)
        #expect(sink.events.allSatisfy { event in
            if case .agent(let id, let modelID) = event.actor {
                return id == "local-gguf-client" && modelID == nil
            }
            return false
        })
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "local_generate.gguf" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "local-gguf-generate:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "local_gguf_client" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "generate" })
        #expect(sink.events.allSatisfy { $0.metadata["provider"] == "local_gguf" })
        #expect(sink.events.allSatisfy { $0.metadata["resolved_runtime"] == BackendRuntimeKind.gguf.rawValue })
        #expect(sink.events.allSatisfy { $0.metadata["requested_runtime"] == BackendRuntimeKind.gguf.rawValue })
        #expect(sink.events.allSatisfy { $0.metadata["reasoning_mode"] == LocalReasoningMode.fast.rawValue })
        #expect(sink.events.allSatisfy { $0.metadata["max_tokens"] == "24" })
        #expect(sink.events.allSatisfy { $0.metadata["prompt_char_count"] == "18" })
        #expect(sink.events.allSatisfy { $0.metadata["system_prompt_char_count"] == "18" })
        #expect(sink.events.allSatisfy { $0.metadata["steering_hints_present"] == "true" })

        let argumentsPayload = try payload(from: sink.events.first?.tool?.argumentsJSON)
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
        #expect(argumentsPayload["prompt_char_count"] as? Int == 18)
        #expect(argumentsPayload["system_prompt_char_count"] as? Int == 18)
        #expect(argumentsPayload["provider"] as? String == "local_gguf")

        let resultPayload = try payload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["elapsed_ms", "output_char_count", "success"])
        #expect(resultPayload["success"] as? Bool == true)
        #expect(resultPayload["output_char_count"] as? Int == 19)
        #expect(sink.events.last?.tool?.status == .completed)
        #expect(sink.events.last?.tool?.errorMessage == nil)

        try assertNoLocalGGUFSecretLeak(
            in: sink.events,
            forbidden: [
                "secret gguf prompt",
                "secret gguf system",
                "Secret local output",
                "qwen35-35b-a3b-apexmini",
                fixture.path,
                "{\"secret\":\"hint\"}",
                LocalTextModelID.qwen35_35BA3B4Bit.rawValue
            ]
        )
    }

    @MainActor
    @Test("gguf client generate records sanitized failed AgentEvent")
    func ggufClientGenerateRecordsSanitizedFailedAgentEvent() async throws {
        let fixture = try makeGGUFFixture(named: [
            "qwen35-35b-a3b-apexmini.gguf",
        ])
        defer { try? FileManager.default.removeItem(at: fixture) }

        let runtime = makeRuntime(
            output: "unused",
            generate: { _, _, _ in
                throw LocalGGUFClientAgentEventTestError.backendSecret
            }
        )
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: false
            )
        )
        let inference = makeLocalGGUFInference()
        let sink = LocalGGUFAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 456 },
            persist: { event in sink.append(event) }
        )
        let client = LocalGGUFClient(
            runtime: runtime,
            inference: inference,
            runtimeControlPlane: controlPlane,
            agentProvenanceRecorder: recorder
        )
        client.configurePreparedGenerationRuntime(
            PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwen 3.5 35B APEXMini",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    servedModelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    mlxOutputPath: fixture.path,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            )
        )

        do {
            _ = try await client.generate(
                prompt: "secret gguf prompt",
                systemPrompt: "secret gguf system",
                maxTokens: 24,
                reasoningMode: .fast,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                requestedRuntimeKind: .gguf,
                steeringHintsJSON: "{\"secret\":\"hint\"}"
            )
            Issue.record("Expected local GGUF generate to fail.")
        } catch LocalGGUFClientAgentEventTestError.backendSecret {
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

        try assertNoLocalGGUFSecretLeak(
            in: sink.events,
            forbidden: [
                "secret gguf prompt",
                "secret gguf system",
                "backendSecret",
                "qwen35-35b-a3b-apexmini",
                fixture.path,
                "{\"secret\":\"hint\"}",
                LocalTextModelID.qwen35_35BA3B4Bit.rawValue
            ]
        )
    }

    @MainActor
    @Test("gguf client rejects fast mode for always-thinking families")
    func ggufClientRejectsFastModeForAlwaysThinkingFamilies() async throws {
        let fixture = try makeGGUFFixture(named: [
            "qwopus-27b-v3.gguf",
        ])
        defer { try? FileManager.default.removeItem(at: fixture) }

        let runtime = makeRuntime(output: "unused")
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            ),
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setPreparedLocalTextModelIDs([LocalTextModelID.qwopus27Bv3.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwopus27Bv3.rawValue)

        let client = LocalGGUFClient(
            runtime: runtime,
            inference: inference,
            runtimeControlPlane: controlPlane
        )
        client.configurePreparedGenerationRuntime(
            PreparedGenerationRuntimeConfiguration(
                primaryGenerator: PreparedModelDescriptor(
                    key: "generator_primary",
                    role: .generator,
                    displayName: "Qwopus 27B v3",
                    declaredRuntimeKind: .gguf,
                    artifactID: "qwopus-27b-v3",
                    modelID: LocalTextModelID.qwopus27Bv3.rawValue,
                    servedModelID: LocalTextModelID.qwopus27Bv3.rawValue,
                    mlxOutputPath: fixture.path,
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            )
        )

        await #expect(throws: LocalGGUFRuntimeError.fastModeUnsupported(modelID: LocalTextModelID.qwopus27Bv3.rawValue)) {
            try await client.generate(
                prompt: "Say hello",
                systemPrompt: "Be concise.",
                maxTokens: 24,
                reasoningMode: .fast,
                modelID: LocalTextModelID.qwopus27Bv3.rawValue,
                requestedRuntimeKind: .gguf,
                steeringHintsJSON: nil
            )
        }
    }

    @MainActor
    @Test("gguf client snapshot reports the gguf local provider identity")
    func ggufClientSnapshotReportsGGUFProviderIdentity() {
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            ),
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwopus27Bv3.rawValue)
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )
        let client = LocalGGUFClient(
            runtime: makeRuntime(output: "unused"),
            inference: inference,
            runtimeControlPlane: controlPlane
        )

        let snapshot = client.configSnapshot()

        #expect(snapshot.provider == .localGGUF)
        #expect(snapshot.model == LocalTextModelID.qwopus27Bv3.rawValue)
    }

    private func makeRuntime(
        output: String,
        generate: (@Sendable (String, String?, Int) async throws -> String)? = nil
    ) -> LocalGGUFInProcessRuntime {
        LocalGGUFInProcessRuntime(
            engineBuilder: { _, _, _ in
                LocalGGUFEngine(
                    generate: generate ?? { _, _, _ in output },
                    stream: { _, _, _ in
                        AsyncThrowingStream { continuation in
                            continuation.yield(output)
                            continuation.finish()
                        }
                    }
                )
            }
        )
    }

    private func makeGGUFFixture(named files: [String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for file in files {
            let fileURL = root.appendingPathComponent(file)
            FileManager.default.createFile(atPath: fileURL.path, contents: Data("gguf".utf8))
        }
        return root
    }

    @MainActor
    private func makeLocalGGUFInference() -> InferenceState {
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            ),
            keychainLoad: { _ in nil },
            keychainSave: { _, _ in true },
            keychainDelete: { _ in }
        )
        inference.setPreparedLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        return inference
    }

    private func payload(from json: String?) throws -> [String: Any] {
        let json = try #require(json)
        let data = try #require(json.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func assertNoLocalGGUFSecretLeak(
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
