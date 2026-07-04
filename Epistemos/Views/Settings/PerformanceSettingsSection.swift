import SwiftUI

// MARK: - PerformanceSettingsSection (ISSUE-2026-05-12-007)
//
// Two-axis startup/idle settings per the 7-drop research synthesis
// + Codex's two-axis recommendation. Replaces the user's original
// "4 separate toggles" suggestion with two orthogonal axes whose
// natural cross-product gives all 4 useful combinations.
//
// Settings persist via @AppStorage so they survive app restarts. The
// behavioral wiring (reading these at AppBootstrap / idle-unload time) is
// NOT yet connected — see Status below; PerformanceSettingsReader is the
// intended read seam once those issues land.
//
// Status: UI shipped + flags persisted. The actual behavioral wiring
// (graph pause unload, cache trimming, ProjectionCache warm-up)
// lands as their respective issues complete:
// - ISSUE-2026-05-12-005 (graph pauseEngine unload) wires Low Memory
// - ISSUE-2026-05-12-009 (ProjectionCache) wires Prepared Launch's
//   sidebar-warm phase
// - ISSUE-2026-05-12-006 (memory profiling) defines the right Low
//   Memory thresholds based on real measurement

public enum StartupMode: String, CaseIterable, Sendable {
    case instant
    case prepared

    public var displayName: String {
        switch self {
        case .instant: "Instant Launch"
        case .prepared: "Prepared Launch"
        }
    }

    public var explanation: String {
        switch self {
        case .instant:
            return "Opens immediately. Sidebar and graph warm up lazily as you use them."
        case .prepared:
            return "Brief \"Preparing vault…\" splash on launch (1–3 s). Sidebar, search, and graph render snappily afterward."
        }
    }
}

public enum IdleMemoryMode: String, CaseIterable, Sendable {
    case keepWarm
    case lowMemory

    public var displayName: String {
        switch self {
        case .keepWarm: "Keep Warm"
        case .lowMemory: "Low Memory"
        }
    }

    public var explanation: String {
        switch self {
        case .keepWarm:
            return "Keeps vault, graph, search, and editor caches warm for responsive navigation — the balanced default."
        case .lowMemory:
            return "Trims search caches, graph resources, and Metal pipelines quickly when the app is idle. Resuming after a pause may take a moment."
        }
    }

    /// Apply this mode to the hardware-tuned idle-unload `base` delay. `.keepWarm` preserves the
    /// balanced default; `.lowMemory` caps it so cache/resource release paths run promptly.
    public nonisolated func idleUnloadDelay(base: Duration) -> Duration {
        switch self {
        case .keepWarm:
            return base
        case .lowMemory:
            return min(base, .seconds(2))
        }
    }
}

@MainActor
public struct PerformanceSettingsSection: View {
    @AppStorage("epistemos.startup.mode") private var startupModeRaw = StartupMode.instant.rawValue
    @AppStorage("epistemos.idle.memoryMode") private var idleMemoryModeRaw = IdleMemoryMode.keepWarm.rawValue

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            startupModeRow
            Divider()
            idleMemoryModeRow
            Divider()
            disclaimer
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var startupModeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "power")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text("Startup Mode")
                    .font(.system(size: 13, weight: .medium))
            }
            Picker("", selection: $startupModeRaw) {
                ForEach(StartupMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(currentStartupMode.explanation)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var idleMemoryModeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "memorychip")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text("Idle Memory Mode")
                    .font(.system(size: 13, weight: .medium))
            }
            Picker("", selection: $idleMemoryModeRaw) {
                ForEach(IdleMemoryMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(currentIdleMemoryMode.explanation)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("These modes persist your preference but are not yet wired to runtime behavior. Idle cache release currently runs on system memory pressure (not this toggle); startup-splash gating, graph engine unload, and cluster pyramid persistence land with their respective upgrades.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentStartupMode: StartupMode {
        StartupMode(rawValue: startupModeRaw) ?? .instant
    }

    private var currentIdleMemoryMode: IdleMemoryMode {
        IdleMemoryMode(rawValue: idleMemoryModeRaw) ?? .keepWarm
    }
}

// MARK: - Public helpers — read the modes from anywhere in the app
// without importing the settings UI.

public enum PerformanceSettingsReader {
    /// Read the current startup mode. Safe to call from any thread.
    /// Intended read seam for AppBootstrap's "Preparing vault" splash
    /// decision — not yet wired (no caller today).
    public static var startupMode: StartupMode {
        let raw = UserDefaults.standard.string(forKey: "epistemos.startup.mode") ?? ""
        return StartupMode(rawValue: raw) ?? .instant
    }

    /// Read the current idle memory mode. Safe to call from any thread (UserDefaults read), so
    /// `nonisolated` consumers can cap idle cache/resource release delays (`.lowMemory`).
    public nonisolated static var idleMemoryMode: IdleMemoryMode {
        let raw = UserDefaults.standard.string(forKey: "epistemos.idle.memoryMode") ?? ""
        return IdleMemoryMode(rawValue: raw) ?? .keepWarm
    }
}
