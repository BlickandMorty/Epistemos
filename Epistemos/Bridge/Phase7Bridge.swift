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
    static let shared = Phase7Bridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "Phase7Bridge")

    private init() {}

    // MARK: - Specialty D1: NightBrain Trigger

    /// Map a `job_type` string to a `NightBrainService.Job` and run the
    /// pipeline for just that job. Uses `runPipelineForTesting` because
    /// it's the only public single-job entry point on NightBrainService —
    /// safe here because we want the same gating bypass when the agent
    /// explicitly asks for an immediate run.
    func triggerNightbrainJob(jobType: String, priority: String) async -> String {
        guard let bootstrap = AppBootstrap.shared else {
            return errorJson("AppBootstrap is not initialised")
        }
        guard ShipGate.agentsEnabled else {
            return errorJson("agents are disabled by ShipGate — NightBrain unavailable")
        }
        // Map the rust-side `job_type` to the Swift Job enum. Accept both
        // the canonical raw values (e.g. "memory_distillation") and the
        // shorter names from the implementation plan ("memory_distillation",
        // "event_checkpoint", etc.).
        let jobMap: [String: NightBrainService.Job] = [
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
            "vault_integrity_check": .maintenanceLog,
            "maintenance_log": .maintenanceLog,
        ]
        guard let job = jobMap[jobType] else {
            return errorJson("unknown job_type: \(jobType)")
        }

        // Capture the start time so we can report duration.
        let start = Date()
        let result = await bootstrap.nightBrain.runPipelineForTesting(jobOrder: [job])
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)

        return jsonString([
            "success": result == .finished,
            "job": job.rawValue,
            "priority": priority,
            "result": String(describing: result),
            "duration_ms": elapsed,
        ])
    }

    // MARK: - Helpers

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
