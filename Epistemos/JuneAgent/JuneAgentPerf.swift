#if EPISTEMOS_APP_STORE
import Foundation
import Observation
import SwiftUI
import os.signpost

extension Sig {
    /// Agent-surface perf channel (doctrine §4) — the MAS complement of the
    /// Pro build's identically-named channel (mutually exclusive #if gates),
    /// so Instruments filtering works the same on both builds.
    nonisolated public static let agentSurface = OSSignposter(subsystem: "io.epistemos.core", category: "agent_surface")
}

/// Measurement producer for docs/perf-budgets.toml [agent_surface] on the MAS
/// build (June-in-WKWebView + in-process engines). Milliseconds of the most
/// recent occurrence; nil = not yet exercised this process (honest, never
/// faked). Mirrors the shared agent-surface metric shape.
@MainActor
@Observable
final class JuneAgentPerfMetrics {
    static let shared = JuneAgentPerfMetrics()

    /// Agent tab first open -> June SPA painted. Budget: cold_open_ms_max 1500.
    private(set) var coldOpenMs: Double?
    /// Tab-return fast path (warm WebView re-mount). Budget: warm_reopen_ms_max 100.
    private(set) var warmReopenMs: Double?
    /// prompt.submit -> first streamed delta. Budget: first_token_ms_max 1200.
    private(set) var firstTokenMs: Double?
    private(set) var lastUpdated: Date?

    func recordColdOpen(milliseconds: Double) {
        coldOpenMs = milliseconds
        lastUpdated = Date()
    }

    func recordWarmReopen(milliseconds: Double) {
        warmReopenMs = milliseconds
        lastUpdated = Date()
    }

    func recordFirstToken(milliseconds: Double) {
        firstTokenMs = milliseconds
        lastUpdated = Date()
    }
}

/// Settings → Diagnostics row: the owner-visible cold-open / warm-reopen /
/// first-token numbers vs their budget contracts (doctrine §4 — a producer
/// must exist before the budgets can be enforced).
struct JuneAgentHealthRow: View {
    @State private var metrics = JuneAgentPerfMetrics.shared

    var body: some View {
        LabeledContent("Workspace surface") {
            HStack(spacing: 12) {
                budgetLabel("cold", value: metrics.coldOpenMs, budget: 1500)
                budgetLabel("warm", value: metrics.warmReopenMs, budget: 100)
                budgetLabel("token", value: metrics.firstTokenMs, budget: 1200)
            }
            .font(.caption.monospacedDigit())
        }
    }

    @ViewBuilder
    private func budgetLabel(_ name: String, value: Double?, budget: Double) -> some View {
        if let value {
            Text("\(name) \(Int(value))ms")
                .foregroundStyle(value <= budget ? Color.green : Color.red)
        } else {
            Text("\(name) —")
                .foregroundStyle(.secondary)
        }
    }
}
#else
import SwiftUI

/// Experimental builds get their own diagnostics instead; this symbol exists so the
/// shared Settings panel compiles on both targets.
struct JuneAgentHealthRow: View {
    var body: some View { EmptyView() }
}
#endif
