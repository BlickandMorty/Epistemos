// Phase7Bridge.swift
//
// Bridges Phase 7 Intelligence Layer specialties (nightbrain_trigger) from
// the Rust agent_core FFI to the existing Swift services
// (NightBrainService).
//
// All public methods are @MainActor — the StreamingDelegate hops the FFI
// thread onto the main actor via a Task + DispatchSemaphore so the Rust
// handler can call this synchronously.

import Foundation
import os

@MainActor
final class Phase7Bridge {
    typealias BootstrapProvider = @MainActor () -> AppBootstrap?

    static let shared = Phase7Bridge()
    nonisolated static let supportedJobAliases: [String: NightBrainService.Job] = [
        "event_checkpoint": .eventStoreCheckpointVacuum,
        "event_store_checkpoint_vacuum": .eventStoreCheckpointVacuum,
        "search_index_checkpoint": .searchIndexPassiveCheckpoint,
        "search_index_passive_checkpoint": .searchIndexPassiveCheckpoint,
        "artifact_dedup": .dedupeArtifacts,
        "dedupe_artifacts": .dedupeArtifacts,
        "workspace_compaction": .workspaceSnapshotCompaction,
        "workspace_snapshot_compaction": .workspaceSnapshotCompaction,
        "memory_distillation": .memoryDistillation,
        "cloud_knowledge_distillation": .cloudKnowledgeDistillation,
        "session_graph_generation": .sessionGraphGeneration,
        "skill_evolution_analysis": .skillEvolutionAnalysis,
        "ssm_state_pruning": .ssmStatePruning,
        "maintenance_log": .maintenanceLog,
    ]

    private let logger = Logger(subsystem: "app.epistemos", category: "Phase7Bridge")
    private let bootstrapProvider: BootstrapProvider
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private var toolCallSequence: UInt64 = 0

    init(
        bootstrapProvider: @escaping BootstrapProvider = { AppBootstrap.shared },
        agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()
    ) {
        self.bootstrapProvider = bootstrapProvider
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    // MARK: - Specialty D1: NightBrain Trigger

    /// Map a `job_type` string to a `NightBrainService.Job` and run the
    /// pipeline for just that job. Uses `runPipelineForTesting` because
    /// it's the only public single-job entry point on NightBrainService —
    /// safe here because we want the same gating bypass when the agent
    /// explicitly asks for an immediate run.
    func triggerNightbrainJob(jobType: String, priority: String) async -> String {
        let toolCallID = nextToolCallID()
        let priorityClass = normalizedPriorityClass(priority)
        recordNightBrainTriggerEvent(
            toolCallID: toolCallID,
            kind: .toolCallRequested,
            status: .requested,
            job: Self.supportedJobAliases[jobType],
            priorityClass: priorityClass,
            requestedJobSupported: Self.supportedJobAliases[jobType] != nil
        )

        // Map the rust-side `job_type` to the Swift Job enum. Accept both
        // the canonical raw values (e.g. "memory_distillation") and the
        // shorter names from the implementation plan ("memory_distillation",
        // "event_checkpoint", etc.).
        if jobType == "vault_integrity_check" {
            recordNightBrainTriggerEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                job: nil,
                priorityClass: priorityClass,
                requestedJobSupported: false,
                failureClass: "unsupported_job_type",
                errorMessage: "NightBrain job was not accepted."
            )
            return errorJson("job_type vault_integrity_check is not implemented by NightBrainService")
        }
        guard let job = Self.supportedJobAliases[jobType] else {
            recordNightBrainTriggerEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                job: nil,
                priorityClass: priorityClass,
                requestedJobSupported: false,
                failureClass: "unsupported_job_type",
                errorMessage: "NightBrain job was not accepted."
            )
            return errorJson("unknown job_type: \(jobType)")
        }
        guard let bootstrap = bootstrapProvider() else {
            recordNightBrainTriggerEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                job: job,
                priorityClass: priorityClass,
                requestedJobSupported: true,
                failureClass: "bootstrap_unavailable",
                errorMessage: "NightBrain job could not be started."
            )
            return errorJson("AppBootstrap is not initialised")
        }
        guard ShipGate.agentsEnabled else {
            recordNightBrainTriggerEvent(
                toolCallID: toolCallID,
                kind: .toolCallFailed,
                status: .failed,
                job: job,
                priorityClass: priorityClass,
                requestedJobSupported: true,
                failureClass: "agents_disabled",
                errorMessage: "NightBrain job could not be started."
            )
            return errorJson("agents are disabled by ShipGate — NightBrain unavailable")
        }

        // Capture the start time so we can report duration.
        recordNightBrainTriggerEvent(
            toolCallID: toolCallID,
            kind: .toolCallStarted,
            status: .started,
            job: job,
            priorityClass: priorityClass,
            requestedJobSupported: true
        )
        let start = Date()
        let result = await bootstrap.nightBrain.runPipelineForTesting(jobOrder: [job])
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        let durationMs = elapsed >= 0 ? UInt64(elapsed) : nil
        let completed = result == .finished
        recordNightBrainTriggerEvent(
            toolCallID: toolCallID,
            kind: completed ? .toolCallCompleted : .toolCallFailed,
            status: completed ? .completed : .failed,
            job: job,
            priorityClass: priorityClass,
            requestedJobSupported: true,
            result: result,
            durationMs: durationMs,
            failureClass: completed ? nil : "pipeline_deferred",
            errorMessage: completed ? nil : "NightBrain job did not finish."
        )

        return jsonString([
            "success": result == .finished,
            "job": job.rawValue,
            "priority": priority,
            "result": String(describing: result),
            "duration_ms": elapsed,
        ])
    }

    // MARK: - Helpers

    private func nextToolCallID() -> String {
        let sequence = toolCallSequence
        if toolCallSequence < UInt64.max {
            toolCallSequence += 1
        }
        return "phase7-nightbrain-trigger-\(sequence)"
    }

    private func recordNightBrainTriggerEvent(
        toolCallID: String,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        job: NightBrainService.Job?,
        priorityClass: String,
        requestedJobSupported: Bool,
        result: NightBrainService.PipelineResult? = nil,
        durationMs: UInt64? = nil,
        failureClass: String? = nil,
        errorMessage: String? = nil
    ) {
        _ = agentProvenanceRecorder.recordToolEvent(
            runID: "phase7-nightbrain-trigger",
            traceID: nil,
            kind: kind,
            actor: .agent(id: "phase7-bridge", modelID: nil),
            toolCallID: toolCallID,
            toolName: "nightbrain_trigger",
            argumentsJSON: nightBrainTriggerArgumentsJSON(
                job: job,
                priorityClass: priorityClass,
                requestedJobSupported: requestedJobSupported
            ),
            resultJSON: result.map { nightBrainTriggerResultJSON(result: $0) },
            durationMs: durationMs,
            status: status,
            errorMessage: errorMessage,
            metadata: nightBrainTriggerMetadata(
                job: job,
                priorityClass: priorityClass,
                requestedJobSupported: requestedJobSupported,
                failureClass: failureClass
            )
        )
    }

    private func nightBrainTriggerArgumentsJSON(
        job: NightBrainService.Job?,
        priorityClass: String,
        requestedJobSupported: Bool
    ) -> String {
        var payload: [String: Any] = [
            "priority_class": priorityClass,
            "requested_job_supported": requestedJobSupported,
        ]
        if let job {
            payload["job"] = job.rawValue
        }
        return jsonString(payload)
    }

    private func nightBrainTriggerResultJSON(result: NightBrainService.PipelineResult) -> String {
        jsonString([
            "result": String(describing: result),
            "success": result == .finished,
        ])
    }

    private func nightBrainTriggerMetadata(
        job: NightBrainService.Job?,
        priorityClass: String,
        requestedJobSupported: Bool,
        failureClass: String?
    ) -> [String: String] {
        var metadata: [String: String] = [
            "source": "phase7_bridge",
            "surface": "nightbrain_trigger",
            "priority_class": priorityClass,
            "requested_job_supported": requestedJobSupported ? "true" : "false",
        ]
        if let job {
            metadata["job"] = job.rawValue
        }
        if let failureClass {
            metadata["failure_class"] = failureClass
        }
        return metadata
    }

    private func normalizedPriorityClass(_ priority: String) -> String {
        switch priority.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "high", "urgent":
            return "high"
        case "normal", "default":
            return "normal"
        case "low":
            return "low"
        case "background", "idle":
            return "background"
        default:
            return "unknown"
        }
    }

    private func errorJson(_ message: String) -> String {
        jsonString(["error": message, "success": false])
    }

    private func jsonString(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{\"error\":\"json_encode_failed\"}"
        }
        return string
    }
}
