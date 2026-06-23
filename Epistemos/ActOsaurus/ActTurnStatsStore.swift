import Foundation
import SwiftUI

/// 0.33a (owner "prefill/stats") — the native side-channel for act generation telemetry.
///
/// Osaurus showed "TTFT 7.36s · 39 tokens" in its transcript; the native act surface streams
/// only visible text (`actStreamIfArmed`) and the protocol stats are filtered out. Rather than
/// leak the raw `stats:` sentinel back into the visible message (which would defeat the clean
/// send path), the act bridge emits a structured `.generationStats` event at turn finish and the
/// string handler records it HERE. The act chat's last-assistant bubble observes this and renders
/// a native stats chip — same information, owner's Epistemos chrome, zero text contamination.
struct ActTurnStats: Equatable, Sendable {
    var ttftSeconds: Double?
    var tokensPerSecond: Double?
    var tokenCount: Int?

    var hasAny: Bool { ttftSeconds != nil || tokensPerSecond != nil || (tokenCount ?? 0) > 0 }
}

@MainActor
@Observable
final class ActTurnStatsStore {
    static let shared = ActTurnStatsStore()

    /// The most-recently completed act turn's telemetry, or nil before the first turn finishes.
    private(set) var latest: ActTurnStats?

    private init() {}

    /// Record the finished turn's stats (called off the act stream's completion).
    func record(_ stats: ActTurnStats) {
        latest = stats.hasAny ? stats : nil
    }

    /// Clear when a new turn begins so a stale chip never lingers on a fresh send.
    func clearForNewTurn() {
        latest = nil
    }
}

/// Native Epistemos stats chip — the owner's "TTFT 7.36s · 39 tokens" line, Epistemos-styled.
struct ActGenerationStatsChip: View {
    let stats: ActTurnStats

    private var parts: [String] {
        var out: [String] = []
        if let ttft = stats.ttftSeconds, ttft > 0 {
            out.append(String(format: "TTFT %.2fs", ttft))
        }
        if let count = stats.tokenCount, count > 0 {
            out.append("\(count) tokens")
        }
        if let tps = stats.tokensPerSecond, tps > 0 {
            out.append(String(format: "%.0f tok/s", tps))
        }
        return out
    }

    var body: some View {
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Generation stats: \(parts.joined(separator: ", "))")
        }
    }
}
