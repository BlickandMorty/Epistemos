import Foundation

// Duration.milliseconds replacement for the deleted OmegaExtensions.swift
extension Duration {
    var omegaMilliseconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1000.0 + Double(attoseconds) / 1e15
    }
}
