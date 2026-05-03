import Foundation
import Testing
@testable import Epistemos

@Suite("Backend Runtime Contract")
struct BackendRuntimeContractTests {
    @Test("capability handshake resolves runtime capabilities before generation")
    func capabilityHandshakeResolvesRuntimeCapabilitiesBeforeGeneration() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf, .mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let handshake = try await controlPlane.handshake(
            request: BackendRuntimeHandshakeRequest(
                requestedRuntimeKind: .gguf,
                executionMode: .local,
                operation: .generate,
                reasoningProfile: .deep,
                executionPolicyRef: nil
            )
        )

        #expect(handshake.requestedRuntimeKind == .gguf)
        #expect(handshake.resolvedRuntimeKind == .gguf)
        #expect(handshake.requestedReasoningProfile == .deep)
        #expect(handshake.resolvedReasoningProfile == .deep)
        #expect(BackendReasoningProfile.deep.rawValue == "deep_graph")
        #expect(handshake.executionPolicyID == "policy.deep_graph.local")
        #expect(!handshake.usedFallbackResolution)
        #expect(handshake.capabilities.supportsGenerate)
        #expect(handshake.capabilities.supportsStreamingFromSSD)
        #expect(handshake.capabilities.supportsSerialIOAudit)
        #expect(!handshake.capabilities.supportsSpeculativeDecoding)
        #expect(!handshake.capabilities.supportsDynamicSparsity)
    }

    @Test("capability handshake reports explicit mlx fallback when gguf is unavailable")
    func capabilityHandshakeReportsExplicitMLXFallbackWhenGGUFUnavailable() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let handshake = try await controlPlane.handshake(
            request: BackendRuntimeHandshakeRequest(
                requestedRuntimeKind: .gguf,
                executionMode: .local,
                operation: .generate,
                reasoningProfile: .standard,
                executionPolicyRef: nil
            )
        )

        #expect(handshake.requestedRuntimeKind == .gguf)
        #expect(handshake.resolvedRuntimeKind == .mlx)
        #expect(handshake.usedFallbackResolution)
        #expect(handshake.capabilities.supportsGenerate)
    }

    @Test("capability handshake exposes mlx embedding support before execution starts")
    func capabilityHandshakeExposesMLXEmbeddingSupportBeforeExecutionStarts() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let handshake = try await controlPlane.handshake(
            request: BackendRuntimeHandshakeRequest(
                requestedRuntimeKind: .mlx,
                executionMode: .local,
                operation: .embed,
                reasoningProfile: nil,
                executionPolicyRef: nil
            )
        )

        #expect(handshake.requestedRuntimeKind == .mlx)
        #expect(handshake.resolvedRuntimeKind == .mlx)
        #expect(handshake.capabilities.supportsEmbed)
        #expect(!handshake.usedFallbackResolution)
    }

    @Test("runtime resolution remains explicit and policy driven")
    func runtimeResolutionRemainsExplicitAndPolicyDriven() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let fallbackRuntime = try await controlPlane.resolveGenerationRuntimeKind(
            requestedRuntimeKind: .gguf
        )
        #expect(fallbackRuntime == .mlx)

        let explicitRuntime = try await controlPlane.resolveGenerationRuntimeKind(
            requestedRuntimeKind: .mlx
        )
        #expect(explicitRuntime == .mlx)
    }

    @Test("generation falls back to mlx when gguf is unavailable")
    func generationFallsBackToMLXWhenGGUFUnavailable() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let handle = try await controlPlane.loadModel(
            request: BackendModelLoadRequest(
                requestedRuntimeKind: nil,
                executionMode: .local,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                artifactID: "qwen35-35b-a3b-apexmini"
            )
        )

        #expect(handle.runtimeKind == .mlx)
        #expect(handle.modelID == LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        #expect(handle.artifactID == "qwen35-35b-a3b-apexmini")
    }

    @Test("generation stream preserves requested and resolved runtime identities")
    func generationStreamPreservesRequestedAndResolvedRuntimeIdentities() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let launch = try await controlPlane.generate(
            request: BackendGenerationRequest(
                requestID: "req-1",
                requestedRuntimeKind: .gguf,
                executionMode: .local,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                artifactID: "qwen35-35b-a3b-apexmini",
                modelHandleID: nil,
                prompt: "Hello",
                systemPrompt: "Be direct.",
                maxOutputTokens: 32,
                temperature: 0.2,
                stopSequences: [],
                toolPolicyRef: nil,
                contextRef: nil,
                reasoningProfile: .deep,
                executionPolicyRef: "policy.deep_graph.local",
                steeringHintsJSON: nil,
                priority: 0,
                timeoutMS: 30_000,
                streamOptions: BackendGenerationStreamOptions()
            )
        )

        #expect(launch.requestedRuntimeKind == .gguf)
        #expect(launch.resolvedRuntimeKind == .mlx)
        #expect(launch.requestedReasoningProfile == .deep)
        #expect(launch.resolvedReasoningProfile == .deep)
        #expect(launch.executionPolicyID == "policy.deep_graph.local")

        try await controlPlane.appendStarted(streamHandle: launch.streamHandle)
        try await controlPlane.appendToken(streamHandle: launch.streamHandle, text: "Hello")
        try await controlPlane.finishCompleted(
            streamHandle: launch.streamHandle,
            summary: BackendGenerationSummary(
                requestID: "req-1",
                requestedRuntimeKind: .gguf,
                resolvedRuntimeKind: .mlx,
                requestedReasoningProfile: .deep,
                resolvedReasoningProfile: .deep,
                executionMode: .local,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                artifactID: "qwen35-35b-a3b-apexmini",
                executionPolicyID: "policy.deep_graph.local",
                fallbackMode: "resident",
                timeToFirstTokenMS: 42,
                totalDurationMS: 120,
                tokensPerSecond: 18,
                outputTokenCount: 4,
                outputCharacterCount: 5,
                memoryPressureState: "normal",
                executionPhase: "decode",
                maskingState: "dense",
                kvPolicyState: "baseline",
                expertBudgetState: "default",
                adaptationState: "disabled",
                guardrailState: "clear",
                sidecarState: "disabled",
                budgetOutcome: "within_budget",
                planTracePresent: true,
                cancelled: false,
                errorClass: nil
            )
        )

        let events = try await controlPlane.pollEvents(
            streamHandle: launch.streamHandle,
            maxEvents: 10
        )

        #expect(events.map(\.kind) == [.started, .token, .completed])
        #expect(events.last?.summary?.requestedRuntimeKind == .gguf)
        #expect(events.last?.summary?.resolvedRuntimeKind == .mlx)
        #expect(events.last?.summary?.requestedReasoningProfile == .deep)
        #expect(events.last?.summary?.resolvedReasoningProfile == .deep)
        #expect(events.last?.summary?.executionPolicyID == "policy.deep_graph.local")
        #expect(events.last?.summary?.sidecarState == "disabled")
        #expect(events.last?.summary?.budgetOutcome == "within_budget")
        #expect(events.last?.summary?.planTracePresent == true)

        let stats = try await controlPlane.stats(target: .stream(launch.streamHandle))
        #expect(stats.requestedReasoningProfile == .deep)
        #expect(stats.resolvedReasoningProfile == .deep)
        #expect(stats.executionPolicyID == "policy.deep_graph.local")
        #expect(stats.planTracePresent == true)
        #expect(stats.capabilities.supportsGenerate)
        #expect(stats.capabilities.supportsSerialIOAudit)
        #expect(!stats.capabilities.supportsAdapt)
        #expect(stats.sidecarState == "disabled")
        #expect(stats.budgetOutcome == "within_budget")
    }

    @Test("default execution policy metadata is resolved by the control plane")
    func defaultExecutionPolicyMetadataIsResolvedByControlPlane() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf, .mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let launch = try await controlPlane.generate(
            request: BackendGenerationRequest(
                requestID: "req-default-policy",
                requestedRuntimeKind: .gguf,
                executionMode: .local,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                artifactID: "qwen35-35b-a3b-apexmini",
                modelHandleID: nil,
                prompt: "Hello",
                systemPrompt: nil,
                maxOutputTokens: 32,
                temperature: 0.2,
                stopSequences: [],
                toolPolicyRef: nil,
                contextRef: nil,
                reasoningProfile: .deep,
                executionPolicyRef: nil,
                steeringHintsJSON: nil,
                priority: 0,
                timeoutMS: 30_000,
                streamOptions: BackendGenerationStreamOptions()
            )
        )

        #expect(launch.executionPolicyID == "policy.deep_graph.local")

        let stats = try await controlPlane.stats(target: .stream(launch.streamHandle))
        #expect(stats.executionPolicyID == "policy.deep_graph.local")
        #expect(stats.planTracePresent == true)
        #expect(stats.maskingState == "dense")
        #expect(stats.kvPolicyState == "baseline")
        #expect(stats.expertBudgetState == "deep")
        #expect(stats.adaptationState == "disabled")
        #expect(stats.guardrailState == "clear")
        #expect(stats.sidecarState == "disabled")
        #expect(stats.budgetOutcome == "within_budget")
    }

    @Test("output token budgets are denied before generation launches")
    func outputTokenBudgetsAreDeniedBeforeGenerationLaunches() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf, .mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        await #expect(throws: BackendRuntimeContractError.policyDenied) {
            _ = try await controlPlane.generate(
                request: BackendGenerationRequest(
                    requestID: "req-token-budget",
                    requestedRuntimeKind: .gguf,
                    executionMode: .local,
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelHandleID: nil,
                    prompt: "Hello",
                    systemPrompt: nil,
                    maxOutputTokens: 256,
                    temperature: 0.2,
                    stopSequences: [],
                    toolPolicyRef: nil,
                    contextRef: nil,
                    reasoningProfile: .standard,
                    executionPolicyRef: nil,
                    steeringHintsJSON: """
                    {"depth_budget":{"max_turns":2,"max_reasoning_steps":4,"max_tool_calls":3,"max_output_tokens":64}}
                    """,
                    priority: 0,
                    timeoutMS: 30_000,
                    streamOptions: BackendGenerationStreamOptions()
                )
            )
        }
    }

    @Test("budget trimming is surfaced in runtime stats")
    func budgetTrimmingIsSurfacedInRuntimeStats() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf, .mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let launch = try await controlPlane.generate(
            request: BackendGenerationRequest(
                requestID: "req-budget-trim",
                requestedRuntimeKind: .gguf,
                executionMode: .local,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                artifactID: "qwen35-35b-a3b-apexmini",
                modelHandleID: nil,
                prompt: "Hello",
                systemPrompt: nil,
                maxOutputTokens: 32,
                temperature: 0.2,
                stopSequences: [],
                toolPolicyRef: nil,
                contextRef: nil,
                reasoningProfile: .deep,
                executionPolicyRef: nil,
                steeringHintsJSON: """
                {"depth_budget":{"max_turns":2,"max_reasoning_steps":4,"max_tool_calls":0,"max_output_tokens":64}}
                """,
                priority: 0,
                timeoutMS: 30_000,
                streamOptions: BackendGenerationStreamOptions()
            )
        )

        let stats = try await controlPlane.stats(target: .stream(launch.streamHandle))
        #expect(stats.sidecarState == "disabled")
        #expect(stats.budgetOutcome == "trimmed_to_minimal_graph")
    }

    @Test("model handles are runtime scoped")
    func modelHandlesAreRuntimeScoped() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf, .mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let handle = try await controlPlane.loadModel(
            request: BackendModelLoadRequest(
                requestedRuntimeKind: .mlx,
                executionMode: .local,
                modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
                artifactID: nil
            )
        )

        await #expect(throws: BackendRuntimeContractError.invalidTransition) {
            _ = try await controlPlane.generate(
                request: BackendGenerationRequest(
                    requestID: "req-cross-runtime",
                    requestedRuntimeKind: .gguf,
                    executionMode: .local,
                    modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
                    artifactID: nil,
                    modelHandleID: handle.id,
                    prompt: "Test",
                    systemPrompt: nil,
                    maxOutputTokens: 16,
                    temperature: 0.1,
                    stopSequences: [],
                    toolPolicyRef: nil,
                    contextRef: nil,
                    reasoningProfile: .standard,
                    executionPolicyRef: nil,
                    steeringHintsJSON: nil,
                    priority: 0,
                    timeoutMS: 5_000,
                    streamOptions: BackendGenerationStreamOptions()
                )
            )
        }
    }

    @Test("reserved v1 capabilities fail explicitly except mlx embeddings")
    func reservedV1CapabilitiesFailExplicitlyExceptMLXEmbeddings() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        try await controlPlane.embed()

        await #expect(throws: BackendRuntimeContractError.unsupportedCapability) {
            try await controlPlane.adapt()
        }

        await #expect(throws: BackendRuntimeContractError.unsupportedCapability) {
            try await controlPlane.imageGenerate()
        }
    }

    @Test("embed requests resolve through the mlx runtime contract")
    func embedRequestsResolveThroughTheMLXRuntimeContract() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            ),
            embeddingResolver: { request in
                #expect(request.requestedRuntimeKind == .mlx)
                #expect(request.expectedDimension == 2)
                return [0.25, 0.75]
            }
        )

        let result = try await controlPlane.embed(
            request: BackendEmbeddingRequest(
                requestedRuntimeKind: .mlx,
                executionMode: .local,
                modelID: "apple.nl.embedding",
                artifactID: nil,
                text: "hello world",
                expectedDimension: 2
            )
        )

        #expect(result.requestedRuntimeKind == .mlx)
        #expect(result.resolvedRuntimeKind == .mlx)
        #expect(result.dimension == 2)
        #expect(result.vector == [0.25, 0.75])
    }

    @Test("unsupported advanced reasoning profiles are denied by policy")
    func unsupportedAdvancedReasoningProfilesAreDeniedByPolicy() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf, .mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        await #expect(throws: BackendRuntimeContractError.policyDenied) {
            _ = try await controlPlane.generate(
                request: BackendGenerationRequest(
                    requestID: "req-adaptive",
                    requestedRuntimeKind: .gguf,
                    executionMode: .local,
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelHandleID: nil,
                    prompt: "Hello",
                    systemPrompt: nil,
                    maxOutputTokens: 32,
                    temperature: 0.2,
                    stopSequences: [],
                    toolPolicyRef: nil,
                    contextRef: nil,
                    reasoningProfile: .adaptive,
                    executionPolicyRef: "policy.adaptive.helper",
                    steeringHintsJSON: nil,
                    priority: 0,
                    timeoutMS: 30_000,
                    streamOptions: BackendGenerationStreamOptions()
                )
            )
        }

        await #expect(throws: BackendRuntimeContractError.policyDenied) {
            _ = try await controlPlane.generate(
                request: BackendGenerationRequest(
                    requestID: "req-visual-sidecar",
                    requestedRuntimeKind: .mlx,
                    executionMode: .local,
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelHandleID: nil,
                    prompt: "Hello",
                    systemPrompt: nil,
                    maxOutputTokens: 32,
                    temperature: 0.2,
                    stopSequences: [],
                    toolPolicyRef: nil,
                    contextRef: nil,
                    reasoningProfile: .visualSidecar,
                    executionPolicyRef: "policy.visual_sidecar.local",
                    steeringHintsJSON: nil,
                    priority: 0,
                    timeoutMS: 30_000,
                    streamOptions: BackendGenerationStreamOptions()
                )
            )
        }
    }

    @Test("mismatched execution policy refs are denied by policy")
    func mismatchedExecutionPolicyRefsAreDeniedByPolicy() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.gguf, .mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        await #expect(throws: BackendRuntimeContractError.policyDenied) {
            _ = try await controlPlane.generate(
                request: BackendGenerationRequest(
                    requestID: "req-mismatched-policy",
                    requestedRuntimeKind: .gguf,
                    executionMode: .local,
                    modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                    artifactID: "qwen35-35b-a3b-apexmini",
                    modelHandleID: nil,
                    prompt: "Hello",
                    systemPrompt: nil,
                    maxOutputTokens: 32,
                    temperature: 0.2,
                    stopSequences: [],
                    toolPolicyRef: nil,
                    contextRef: nil,
                    reasoningProfile: .deep,
                    executionPolicyRef: "policy.standard.local",
                    steeringHintsJSON: nil,
                    priority: 0,
                    timeoutMS: 30_000,
                    streamOptions: BackendGenerationStreamOptions()
                )
            )
        }
    }

    @Test("terminal events close the stream to further writes")
    func terminalEventsCloseTheStreamToFurtherWrites() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let launch = try await controlPlane.generate(
            request: BackendGenerationRequest(
                requestID: "req-terminal",
                requestedRuntimeKind: nil,
                executionMode: .local,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                artifactID: "qwen35-35b-a3b-apexmini",
                modelHandleID: nil,
                prompt: "Hello",
                systemPrompt: nil,
                maxOutputTokens: 16,
                temperature: 0.2,
                stopSequences: [],
                toolPolicyRef: nil,
                contextRef: nil,
                reasoningProfile: .standard,
                executionPolicyRef: nil,
                steeringHintsJSON: nil,
                priority: 0,
                timeoutMS: 10_000,
                streamOptions: BackendGenerationStreamOptions()
            )
        )

        try await controlPlane.appendStarted(streamHandle: launch.streamHandle)
        try await controlPlane.finishCompleted(
            streamHandle: launch.streamHandle,
            summary: BackendGenerationSummary(
                requestID: "req-terminal",
                requestedRuntimeKind: nil,
                resolvedRuntimeKind: .mlx,
                requestedReasoningProfile: .standard,
                resolvedReasoningProfile: .standard,
                executionMode: .local,
                modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
                artifactID: "qwen35-35b-a3b-apexmini",
                executionPolicyID: nil,
                fallbackMode: "resident",
                timeToFirstTokenMS: 15,
                totalDurationMS: 40,
                tokensPerSecond: 20,
                outputTokenCount: 1,
                outputCharacterCount: 5,
                memoryPressureState: "normal",
                executionPhase: "decode",
                maskingState: "dense",
                kvPolicyState: "baseline",
                expertBudgetState: "default",
                adaptationState: "disabled",
                guardrailState: "clear",
                sidecarState: "disabled",
                budgetOutcome: "within_budget",
                planTracePresent: true,
                cancelled: false,
                errorClass: nil
            )
        )

        await #expect(throws: BackendRuntimeContractError.contractViolation) {
            try await controlPlane.appendToken(
                streamHandle: launch.streamHandle,
                text: "late"
            )
        }
    }

    @Test("failed and cancelled runtime events carry error classes across FFI")
    func failedAndCancelledRuntimeEventsCarryErrorClassesAcrossFFI() async throws {
        let controlPlane = BackendRuntimeControlPlane(
            policy: BackendRuntimePolicy(
                availableRuntimeKinds: [.mlx],
                primaryGenerationRuntimeKind: .gguf,
                allowMLXGenerationFallback: true
            )
        )

        let failedLaunch = try await controlPlane.generate(
            request: Self.generationRequest(requestID: "req-failed-error-class")
        )
        try await controlPlane.appendStarted(streamHandle: failedLaunch.streamHandle)
        try await controlPlane.finishFailed(
            streamHandle: failedLaunch.streamHandle,
            errorClass: .backendFailure,
            message: "backend_failure",
            summary: Self.generationSummary(
                requestID: "req-failed-error-class",
                errorClass: .backendFailure
            )
        )

        let failedEvents = try await controlPlane.pollEvents(
            streamHandle: failedLaunch.streamHandle,
            maxEvents: 10
        )
        #expect(failedEvents.map(\.kind) == [.started, .failed])
        #expect(failedEvents.last?.errorClass == .backendFailure)
        #expect(failedEvents.last?.summary?.errorClass == .backendFailure)

        let cancelledLaunch = try await controlPlane.generate(
            request: Self.generationRequest(requestID: "req-cancelled-error-class")
        )
        try await controlPlane.appendStarted(streamHandle: cancelledLaunch.streamHandle)
        try await controlPlane.finishCancelled(
            streamHandle: cancelledLaunch.streamHandle,
            summary: Self.generationSummary(
                requestID: "req-cancelled-error-class",
                cancelled: true,
                errorClass: .cancelled
            )
        )

        let cancelledEvents = try await controlPlane.pollEvents(
            streamHandle: cancelledLaunch.streamHandle,
            maxEvents: 10
        )
        #expect(cancelledEvents.map(\.kind) == [.started, .cancelled])
        #expect(cancelledEvents.last?.errorClass == .cancelled)
        #expect(cancelledEvents.last?.summary?.cancelled == true)
        #expect(cancelledEvents.last?.summary?.errorClass == .cancelled)
    }

    private static func generationRequest(requestID: String) -> BackendGenerationRequest {
        BackendGenerationRequest(
            requestID: requestID,
            requestedRuntimeKind: nil,
            executionMode: .local,
            modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
            artifactID: "qwen35-35b-a3b-apexmini",
            modelHandleID: nil,
            prompt: "Hello",
            systemPrompt: nil,
            maxOutputTokens: 16,
            temperature: 0.2,
            stopSequences: [],
            toolPolicyRef: nil,
            contextRef: nil,
            reasoningProfile: .standard,
            executionPolicyRef: nil,
            steeringHintsJSON: nil,
            priority: 0,
            timeoutMS: 10_000,
            streamOptions: BackendGenerationStreamOptions()
        )
    }

    private static func generationSummary(
        requestID: String,
        cancelled: Bool = false,
        errorClass: BackendRuntimeContractError? = nil
    ) -> BackendGenerationSummary {
        BackendGenerationSummary(
            requestID: requestID,
            requestedRuntimeKind: nil,
            resolvedRuntimeKind: .mlx,
            requestedReasoningProfile: .standard,
            resolvedReasoningProfile: .standard,
            executionMode: .local,
            modelID: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
            artifactID: "qwen35-35b-a3b-apexmini",
            executionPolicyID: nil,
            fallbackMode: "resident",
            timeToFirstTokenMS: 15,
            totalDurationMS: 40,
            tokensPerSecond: 20,
            outputTokenCount: 1,
            outputCharacterCount: 5,
            memoryPressureState: "normal",
            executionPhase: "decode",
            maskingState: "dense",
            kvPolicyState: "baseline",
            expertBudgetState: "default",
            adaptationState: "disabled",
            guardrailState: "clear",
            sidecarState: "disabled",
            budgetOutcome: "within_budget",
            planTracePresent: true,
            cancelled: cancelled,
            errorClass: errorClass
        )
    }
}
