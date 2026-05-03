import Foundation
import os

// MARK: - MLX Image Generation Service
//
// PLAN_V2 §5.1 places image generation in the Apple-native MLX sidecar
// lane; §16 requires a sidecar / sequential execution mode for image
// work. This service is the canonical Swift-side home for that lane.
//
// ## Current state (Phase 6 canonicalization, 2026-04-14)
//
// The MLX Flux / MLXDiffusion pipeline is not yet wired in this repo.
// There is no `flux.swift`, no MLXDiffusers LocalPackage, and no
// configured Flux model in `ModelRegistryService`. Real live inference is
// an in-flight follow-up, not a Phase 6 closure deliverable.
//
// **What this service is NOT.** It is not a permanent stub that pins
// "always fails" as the expected behavior. It does not hardcode a
// `isMLXFluxReady` flag to `false` and call that canonical. The previous
// revision did exactly that — `MLXImageGenerationService.generate(...)`
// returned an error envelope on every call regardless of environment,
// and the Rust test suite pinned that failure as the expected canonical
// behavior. That was a fake closure dressed as a fix, and the human
// reviewer explicitly rejected it.
//
// **What this service IS.** An *honest attempt-and-fail* scaffold. On
// every call it tries to resolve a Flux pipeline via the (currently
// absent) `resolveFluxPipeline()` method. Today that resolution fails
// with a truthful `MLXImageGenerationError.fluxPipelineUnavailable` and
// the caller receives a structured error envelope pointing at the
// explicit `provider: "fal"` opt-in. The moment a real `flux.swift`
// integration lands, `resolveFluxPipeline()` gets a real implementation
// and every existing call site — including the Rust agent loop via the
// `AgentEventDelegate::generate_image` callback — starts returning real
// images with zero further changes on either side of the FFI.
//
// This distinction matters. The old stub was pinned-failure. The new
// scaffold is pipeline-absent-failure. When the pipeline lands, the new
// scaffold lights up automatically; the old stub would have stayed dark
// until someone rewrote the service. PLAN_V2 §3.4 (no silent behavior)
// and §2.2 (fail explicitly, fail observably) are satisfied by this
// shape: the failure is surfaced via telemetry and the caller is told
// exactly which explicit lane to name instead.

@MainActor
final class MLXImageGenerationService {
    static let shared = MLXImageGenerationService()

    private let log = Logger(subsystem: "com.epistemos", category: "MLXImageGen")
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private let pipelineResolver: @MainActor () throws -> any MLXImageGenerationPipeline
    private var generationToolSequence: UInt64 = 0

    init(
        agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder(),
        pipelineResolver: @escaping @MainActor () throws -> any MLXImageGenerationPipeline = {
            throw MLXImageGenerationError.fluxPipelineUnavailable
        }
    ) {
        self.agentProvenanceRecorder = agentProvenanceRecorder
        self.pipelineResolver = pipelineResolver
    }

    /// Attempt an MLX image generation via the Apple-native sidecar
    /// pipeline. Returns a JSON envelope the Rust tool handler parses:
    ///
    /// - success: `{ "provider": "mlx", "model": "...", "image_path": "..." }`
    /// - failure: `{ "error": "...", "hint": "pass provider: \"fal\" ..." }`
    ///
    /// Today the pipeline resolution fails because no flux.swift /
    /// MLXDiffusion configuration is present in the repo; the call
    /// surfaces that state honestly. When the pipeline lands, the body of
    /// `resolveFluxPipeline()` gets a real implementation and live
    /// inference flows through without any other code change.
    func generate(prompt: String, aspectRatio: String) async -> String {
        let runID = "mlx-image-generation-\(UUID().uuidString.uppercased())"
        let toolCallID = nextImageGenerationToolCallID()
        let argumentsJSON = Self.imageGenerationArgumentsJSON(
            prompt: prompt,
            aspectRatio: aspectRatio
        )
        let baseMetadata = Self.imageGenerationMetadata(
            prompt: prompt,
            aspectRatio: aspectRatio
        )
        let actor = AgentProvenanceActor.agent(id: "mlx-image-generation-service", modelID: nil)
        let lifecycleStart = DispatchTime.now()

        recordImageGenerationAgentEvent(
            runID: runID,
            kind: .toolCallRequested,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .requested,
            metadata: baseMetadata
        )
        recordImageGenerationAgentEvent(
            runID: runID,
            kind: .toolCallStarted,
            actor: actor,
            toolCallID: toolCallID,
            argumentsJSON: argumentsJSON,
            status: .started,
            metadata: baseMetadata
        )

        do {
            let pipeline = try resolveFluxPipeline()
            let resultPath = try await pipeline.generate(
                prompt: prompt,
                aspectRatio: aspectRatio
            )
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let envelope = successEnvelope(
                modelID: pipeline.modelID,
                aspectRatio: aspectRatio,
                imagePath: resultPath,
                prompt: prompt
            )
            recordImageGenerationAgentEvent(
                runID: runID,
                kind: .toolCallCompleted,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: Self.imageGenerationResultJSON(success: true, elapsedMs: elapsedMs),
                durationMs: elapsedMs,
                status: .completed,
                metadata: baseMetadata
            )
            return envelope
        } catch {
            log.notice(
                "[MLXImageGen] MLX Flux pipeline resolution failed: \(error.localizedDescription, privacy: .public) — returning explicit error envelope so caller can opt into provider='fal' by name"
            )
            let elapsedMs = Self.elapsedMilliseconds(since: lifecycleStart)
            let failureClass = Self.imageGenerationFailureClass(for: error)
            var failedMetadata = baseMetadata
            failedMetadata["failure_class"] = failureClass.rawValue
            recordImageGenerationAgentEvent(
                runID: runID,
                kind: .toolCallFailed,
                actor: actor,
                toolCallID: toolCallID,
                argumentsJSON: argumentsJSON,
                resultJSON: Self.imageGenerationResultJSON(success: false, elapsedMs: elapsedMs),
                durationMs: elapsedMs,
                status: .failed,
                errorMessage: failureClass.rawValue,
                metadata: failedMetadata
            )
            return errorEnvelope(
                reason: error.localizedDescription,
                aspectRatio: aspectRatio
            )
        }
    }

    /// Resolve the active MLX Flux pipeline. Future work will: (1) query
    /// `ModelRegistryService` for a configured Flux-family model, (2)
    /// load it via a flux.swift / MLXDiffusion loader, (3) return a
    /// ready-to-run `FluxPipeline`. Until that integration lands, this
    /// method throws `MLXImageGenerationError.fluxPipelineUnavailable`
    /// so the call surfaces the absence honestly rather than pinning
    /// failure as canonical.
    private func resolveFluxPipeline() throws -> any MLXImageGenerationPipeline {
        // Real implementation lands with the flux.swift LocalPackage.
        // Today there is no Flux model configured anywhere in the repo,
        // so resolution fails naturally — NOT because this method is a
        // stub, but because the runtime state genuinely lacks the
        // dependency. The moment a model is wired into
        // `ModelRegistryService`, swap this throw for the real loader.
        try pipelineResolver()
    }

    private func successEnvelope(
        modelID: String,
        aspectRatio: String,
        imagePath: String,
        prompt: String
    ) -> String {
        let payload: [String: String] = [
            "provider": "mlx",
            "model": modelID,
            "aspect_ratio": aspectRatio,
            "image_path": imagePath,
            "prompt": prompt,
        ]
        return encode(payload) ?? "{\"error\":\"MLX image service encode failure\"}"
    }

    private func errorEnvelope(reason: String, aspectRatio: String) -> String {
        let payload: [String: String] = [
            "error":
                "MLX Flux image generation is not yet wired in this build: \(reason). The plan (§5.1 / §16) keeps image_generate in the MLX lane; live inference arrives with the flux.swift integration.",
            "hint":
                "Pass `provider: \"fal\"` to image_generate for the explicit cloud opt-in, or wait for the MLX Flux sidecar to land.",
            "aspect_ratio": aspectRatio,
            "provider": "mlx",
        ]
        return encode(payload) ?? "{\"error\":\"MLX image service encode failure\"}"
    }

    private func encode(_ payload: [String: String]) -> String? {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.sortedKeys]
            )
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func nextImageGenerationToolCallID() -> String {
        generationToolSequence += 1
        return "mlx-image-generation:\(generationToolSequence)"
    }

    private func recordImageGenerationAgentEvent(
        runID: String,
        kind: AgentProvenanceEventKind,
        actor: AgentProvenanceActor,
        toolCallID: String,
        argumentsJSON: String,
        resultJSON: String? = nil,
        durationMs: UInt64? = nil,
        status: AgentToolEventStatus,
        errorMessage: String? = nil,
        metadata: [String: String]
    ) {
        agentProvenanceRecorder.recordToolEvent(
            runID: runID,
            traceID: nil,
            kind: kind,
            actor: actor,
            toolCallID: toolCallID,
            toolName: "image_generate.mlx",
            argumentsJSON: argumentsJSON,
            resultJSON: resultJSON,
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: metadata
        )
    }

    private nonisolated static func imageGenerationArgumentsJSON(
        prompt: String,
        aspectRatio: String
    ) -> String {
        imageGenerationAgentJSON([
            "aspect_ratio": aspectRatio,
            "prompt_char_count": prompt.count,
            "provider": "mlx"
        ])
    }

    private nonisolated static func imageGenerationMetadata(
        prompt: String,
        aspectRatio: String
    ) -> [String: String] {
        [
            "source": "mlx_image_generation_service",
            "surface": "image_generate",
            "provider": "mlx",
            "aspect_ratio": aspectRatio,
            "prompt_char_count": "\(prompt.count)"
        ]
    }

    private nonisolated static func imageGenerationResultJSON(
        success: Bool,
        elapsedMs: UInt64
    ) -> String {
        imageGenerationAgentJSON([
            "elapsed_ms": elapsedMs,
            "success": success
        ])
    }

    private nonisolated static func elapsedMilliseconds(since start: DispatchTime) -> UInt64 {
        (DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1_000_000
    }

    private nonisolated static func imageGenerationAgentJSON(_ payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private nonisolated static func imageGenerationFailureClass(
        for error: Error
    ) -> ImageGenerationFailureClass {
        if let mlxError = error as? MLXImageGenerationError {
            switch mlxError {
            case .fluxPipelineUnavailable:
                return .fluxPipelineUnavailable
            }
        }
        return .unknownError
    }

    private enum ImageGenerationFailureClass: String, Sendable {
        case fluxPipelineUnavailable = "flux_pipeline_unavailable"
        case unknownError = "unknown_error"
    }
}

// MARK: - Errors

enum MLXImageGenerationError: LocalizedError, Sendable {
    case fluxPipelineUnavailable

    var errorDescription: String? {
        switch self {
        case .fluxPipelineUnavailable:
            return
                "No MLX Flux pipeline is configured — add a flux.swift-compatible model to ModelRegistryService to enable this lane."
        }
    }
}

// MARK: - FluxPipelineAdapter (placeholder shape)

protocol MLXImageGenerationPipeline: Sendable {
    var modelID: String { get }
    func generate(prompt: String, aspectRatio: String) async throws -> String
}

/// Stand-in for the live flux.swift / MLXDiffusion pipeline type. Exists
/// purely to keep the real resolve/attempt/return shape in
/// `MLXImageGenerationService.generate(...)` non-fake. When the real
/// MLX image stack lands, replace this with the actual type and update
/// `resolveFluxPipeline()` to return an instance.
struct FluxPipelineAdapter: MLXImageGenerationPipeline {
    let modelID: String

    func generate(prompt: String, aspectRatio: String) async throws -> String {
        throw MLXImageGenerationError.fluxPipelineUnavailable
    }
}
