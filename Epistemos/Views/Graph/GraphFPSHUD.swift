import AppKit
import SwiftUI

// MARK: - GraphFPSHUD
//
// 2026-05-20 — live FPS readout for the hologram graph overlay.
//
// Reads `graphState.graphMeasuredFPS` + `graphMeasuredP99Ms`, which
// MetalGraphView's renderFrame() updates at ~5 Hz when the HUD is on.
// Off by default — toggled via Settings → Graph performance.
//
// Sits as a compact monospaced pill in the bottom-right of the graph
// chrome, color-coded to the FPS bucket so users can see at-a-glance
// whether they're hitting their cap:
//   - green:  meeting or exceeding the configured cap (great)
//   - yellow: ≥45fps but below cap (acceptable, occasional drops)
//   - red:    <45fps (dropping frames; investigate)
//
// Compositor cost is tiny — one text label, no Material / blur. The
// HUD label refreshes at 5 Hz, not 120 Hz, so it doesn't burn frame
// budget while measuring it.

/// Conditionally renders the HUD only when the toggle is on. Kept as a
/// separate struct so the NSHostingView's view type stays stable and
/// the host view doesn't have to be added/removed when the user
/// toggles the setting.
struct GraphFPSHUDHostView: View {
    @Environment(GraphState.self) private var graphState

    var body: some View {
        if graphState.graphFPSHUDEnabled {
            GraphFPSHUD()
        } else {
            EmptyView()
        }
    }
}

struct GraphFPSHUD: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        let fps = graphState.graphMeasuredFPS
        let p99 = graphState.graphMeasuredP99Ms
        HStack(spacing: 8) {
            Circle()
                .fill(bucketColor(for: fps))
                .frame(width: 6, height: 6)
            Text(String(format: "%3.0f fps", fps))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(String(format: "p99 %.1fms", p99))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(capLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
            // Display capability readout — `screen 120` means ProMotion
            // is available; `screen 60` means current display caps out at
            // 60Hz (e.g., external monitor) regardless of what app
            // requests. Helps diagnose "why doesn't the toggle work?".
            Text("· screen \(screenMaxFPS)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        // Tint-only chrome — sits on top of the graph window's existing
        // wallpaper blur. Single-blur policy (see UnifiedFrostedGlass.swift).
        .background(
            Capsule().fill(theme.glassBg.opacity(0.78))
        )
        .overlay(
            Capsule().strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Graph frame rate: \(Int(fps)) frames per second, p99 frame interval \(String(format: "%.1f", p99)) milliseconds, cap \(capLabel)"
        )
    }

    private var capLabel: String {
        if graphState.graphForceMaximumFPS { return "/120⚡" }
        switch graphState.graphMaxFPS {
        case 30: return "/30"
        case 60: return "/60"
        case 120: return "/120"
        default: return "/∞"
        }
    }

    /// Current screen's maximum refresh rate. Reads from NSScreen so the
    /// HUD reflects the ACTUAL display capability, not the app's request.
    /// On a MacBook Pro 14/16" internal display this is 120; on most
    /// external monitors it's 60. If this reads 60, ProMotion can't engage
    /// no matter what the app does.
    private var screenMaxFPS: Int {
        let screens = NSScreen.screens
        let maxRate = screens.map { $0.maximumFramesPerSecond }.max() ?? 60
        return maxRate
    }

    /// Configured target FPS — what the user expects to see. 0 maps to
    /// 120 for the bucket color so an "Unlimited" user still gets the
    /// green when they're hitting their hardware's ProMotion ceiling.
    private var targetFPS: Double {
        switch graphState.graphMaxFPS {
        case 30: return 30
        case 60: return 60
        case 120: return 120
        default: return 120
        }
    }

    private func bucketColor(for fps: Double) -> Color {
        if fps >= targetFPS - 5 {
            return .green
        } else if fps >= 45 {
            return .yellow
        } else {
            return .red
        }
    }
}
