import Foundation
import Testing
@testable import Epistemos

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

    private func makeRuntime(output: String) -> LocalGGUFInProcessRuntime {
        LocalGGUFInProcessRuntime(
            engineBuilder: { _, _, _ in
                LocalGGUFEngine(
                    generate: { _, _, _ in output },
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
}
