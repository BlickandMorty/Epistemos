import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Local Backend LLM Client")
struct LocalBackendLLMClientTests {
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
        var generateCalls: [RoutedCall] = []

        init(response: String) {
            self.response = response
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

    @Test("main local generation resolves to gguf when the configured gguf runtime is available")
    func mainLocalGenerationResolvesToGGUFWhenAvailable() async throws {
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
        #expect(mlxClient.generateCalls.first?.requestedRuntimeKind == .gguf)
        #expect(ggufClient.generateCalls.isEmpty)
        #expect(inference.availableLocalGenerationRuntimeKinds == [.mlx])
    }

    @Test("backend client snapshot reports gguf when the prepared primary runtime is gguf and available")
    func backendClientSnapshotReportsGGUFWhenPreparedPrimaryRuntimeIsGGUFAndAvailable() {
        let inference = makeInferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])

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
                    status: "ready"
                ),
                speculativeDraftGenerator: nil
            )
        )

        let snapshot = client.configSnapshot()

        #expect(snapshot.provider == .localGGUF)
        #expect(snapshot.model == LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
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
}
