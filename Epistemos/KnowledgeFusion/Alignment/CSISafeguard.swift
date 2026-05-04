import Foundation

// MARK: - CSI Safeguard

/// Cluster Separation Index (CSI) safeguard for detecting reward hacking
/// during autoresearch and on-device training loops.
///
/// Monitors latent space diversity to detect when the model begins
/// over-optimizing on spurious features. If CSI drops below threshold,
/// halts training and reverts to the last known-good adapter.
///
/// Reference: InfoRM (NeurIPS 2024) — CSI detects over-optimized latent representations.
@MainActor @Observable
final class CSISafeguard {

    /// CSI threshold below which training is halted.
    let threshold: Double

    /// History of CSI values for monitoring trends. Capped at
    /// `maxHistoryRetained` via sliding-window eviction in
    /// `recordMeasurement(...)`. Only the last 3 entries are inspected
    /// (rapid-decline check below) so a small ceiling doesn't change
    /// any decision logic.
    private(set) var csiHistory: [CSIMeasurement] = []
    private let maxHistoryRetained: Int = 10

    /// Whether the safeguard has triggered (training should halt).
    private(set) var isTriggered = false

    /// The measurement that triggered the halt (if any).
    private(set) var triggerMeasurement: CSIMeasurement?

    init(threshold: Double = 0.3) {
        self.threshold = threshold
    }

    /// Record a new CSI measurement from the training loop.
    /// Returns true if training should continue, false if it should halt.
    func recordMeasurement(value: Double, epoch: Int, experimentId: String) -> Bool {
        let measurement = CSIMeasurement(
            value: value,
            epoch: epoch,
            experimentId: experimentId,
            timestamp: Date()
        )
        csiHistory.append(measurement)
        if csiHistory.count > maxHistoryRetained {
            csiHistory.removeFirst(csiHistory.count - maxHistoryRetained)
        }

        // Check if CSI has dropped below threshold
        if value < threshold {
            isTriggered = true
            triggerMeasurement = measurement
            return false // halt training
        }

        // Check for rapid decline (CSI dropping by >50% in last 3 measurements)
        if csiHistory.count >= 3 {
            let recent = Array(csiHistory.suffix(3))
            if let first = recent.first, let last = recent.last {
                let decline = (first.value - last.value) / first.value
                if decline > 0.5 {
                    isTriggered = true
                    triggerMeasurement = measurement
                    return false
                }
            }
        }

        return true // continue training
    }

    /// Reset the safeguard for a new training session.
    func reset() {
        csiHistory.removeAll()
        isTriggered = false
        triggerMeasurement = nil
    }

    /// Compute a simple cluster separation metric from embedding distances.
    /// This is a simplified version — full InfoRM CSI uses learned reward model embeddings.
    static func computeCSI(intraClusterDistances: [Double], interClusterDistances: [Double]) -> Double {
        guard !intraClusterDistances.isEmpty && !interClusterDistances.isEmpty else {
            return 1.0 // no data = assume good separation
        }

        let avgIntra = intraClusterDistances.reduce(0.0, +) / Double(intraClusterDistances.count)
        let avgInter = interClusterDistances.reduce(0.0, +) / Double(interClusterDistances.count)

        guard avgIntra > 0 else { return 1.0 }

        // CSI = inter-cluster distance / intra-cluster distance
        // Higher = better separation = healthier model
        return avgInter / avgIntra
    }
}

// MARK: - CSI Measurement

struct CSIMeasurement: Identifiable, Sendable {
    let id = UUID()
    let value: Double
    let epoch: Int
    let experimentId: String
    let timestamp: Date
}
