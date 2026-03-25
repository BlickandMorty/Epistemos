import Foundation

// MARK: - Shared Omega Extensions

extension Duration {
    /// Convert Duration to milliseconds as Double.
    /// Used across Omega subsystems for latency tracking.
    var omegaMilliseconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1000.0 + Double(attoseconds) / 1_000_000_000_000_000.0
    }
}
