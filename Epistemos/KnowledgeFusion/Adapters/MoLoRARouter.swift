import Foundation

// MARK: - MoLoRA Router

/// Mixture of LoRA Experts: routes inference through multiple adapters simultaneously.
/// Per-token routing selects the best adapter(s) based on task intent.
///
/// CRITICAL: Never fuse adapters permanently into the base model.
/// Hot-swap only — fusion causes throughput collapse (~21 tok/s → ~7 tok/s on MLX).
@MainActor @Observable
final class MoLoRARouter {

    /// Active adapters available for routing.
    private(set) var activeAdapters: [AdapterInfo] = []

    /// Current routing weights per adapter (normalized to sum to 1.0).
    private(set) var routingWeights: [String: Double] = [:]

    /// Path to router centroids (computed by train_router.py).
    /// When available, enables AdaFuse decide-once routing via MoLoRAInferenceService.
    var centroidsPath: URL? {
        let path = FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("Epistemos/MoLoRA/router_centroids.safetensors")
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return path
    }

    /// Whether MoLoRA per-token routing is available (requires centroids + 2+ adapters).
    var isMoLoRAAvailable: Bool {
        centroidsPath != nil && activeAdapters.count >= 2
    }

    /// Register an adapter as available for routing.
    func registerAdapter(_ adapter: AdapterInfo) {
        if !activeAdapters.contains(where: { $0.id == adapter.id }) {
            activeAdapters.append(adapter)
            recomputeWeights()
        }
    }

    /// Remove an adapter from the routing pool.
    func unregisterAdapter(id: String) {
        activeAdapters.removeAll { $0.id == id }
        recomputeWeights()
    }

    /// Select the best adapter for a given task intent.
    /// Returns the adapter ID and routing confidence.
    func route(taskIntent: TaskIntent) -> (adapterId: String, confidence: Double)? {
        guard !activeAdapters.isEmpty else { return nil }

        // Simple intent-based routing
        let preferred = activeAdapters.first { adapter in
            switch taskIntent {
            case .knowledge: adapter.type == .knowledge
            case .style: adapter.type == .style
            case .toolUse: adapter.type == .toolUse
            case .general: true // any adapter
            }
        }

        if let adapter = preferred {
            return (adapter.id, routingWeights[adapter.id] ?? 0.5)
        }

        // Fallback to highest-weight adapter
        if let best = activeAdapters.max(by: { (routingWeights[$0.id] ?? 0) < (routingWeights[$1.id] ?? 0) }) {
            return (best.id, routingWeights[best.id] ?? 0.3)
        }

        return nil
    }

    /// Recompute routing weights based on adapter quality metrics.
    private func recomputeWeights() {
        guard !activeAdapters.isEmpty else {
            routingWeights.removeAll()
            return
        }

        // Equal weights initially — will be refined by autoresearch loop
        let weight = 1.0 / Double(activeAdapters.count)
        routingWeights = Dictionary(uniqueKeysWithValues: activeAdapters.map { ($0.id, weight) })
    }
}

// MARK: - Supporting Types

struct AdapterInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let type: AdapterType
    let path: URL

    enum AdapterType: String, Sendable {
        case knowledge
        case style
        case toolUse
        case general
    }
}

enum TaskIntent: Sendable {
    case knowledge
    case style
    case toolUse
    case general
}
