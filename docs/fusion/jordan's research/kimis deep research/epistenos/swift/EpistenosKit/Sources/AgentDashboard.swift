import Foundation
import SwiftUI
import Combine

// ---------------------------------------------------------------------------
// MARK: - Data Models
// ---------------------------------------------------------------------------

/// A visual representation of a single memory tier for charting.
public struct TierVisualization: Identifiable, Equatable {
    public let id = UUID()
    public let tier: String
    public let bytes: UInt64
    public let colorHex: String

    public var gigabytes: Double { Double(bytes) / 1_073_741_824.0 }
}

/// Throughput data point for sparkline / chart rendering.
public struct ThroughputDataPoint: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let tokPerSecond: Double
}

/// A rolling window of throughput samples.
public struct ThroughputData: Equatable {
    public var points: [ThroughputDataPoint]
    public var maxPoints: Int

    public init(points: [ThroughputDataPoint] = [], maxPoints: Int = 60) {
        self.points = points
        self.maxPoints = maxPoints
    }

    public mutating func append(_ tokPerSecond: Double) {
        let point = ThroughputDataPoint(timestamp: Date(), tokPerSecond: tokPerSecond)
        points.append(point)
        if points.count > maxPoints {
            points.removeFirst(points.count - maxPoints)
        }
    }

    public var latest: Double { points.last?.tokPerSecond ?? 0.0 }
    public var average: Double {
        guard !points.isEmpty else { return 0.0 }
        return points.map(\.tokPerSecond).reduce(0.0, +) / Double(points.count)
    }
}

// ---------------------------------------------------------------------------
// MARK: - AgentDashboardModel
// ---------------------------------------------------------------------------

/// The observable model backing the SwiftUI Agent Dashboard.
///
/// `AgentDashboardModel` polls the Rust runtime via UniFFI (`helios_ffi`)
/// and transforms raw `AgentStatus` records into view-ready structures
/// including tier visualisations and throughput charts.
@MainActor
public final class AgentDashboardModel: ObservableObject {
    /// Live agents from the Rust orchestrator.
    @Published public var agents: [AgentStatus] = []

    /// Per-tier memory visualisation data.
    @Published public var memoryTiers: [TierVisualization] = []

    /// Rolling throughput chart data.
    @Published public var throughputChart = ThroughputData()

    /// Is a background refresh in progress?
    @Published public var isRefreshing = false

    /// Last error surfaced from the Rust layer.
    @Published public var lastError: String?

    /// Polling interval (seconds). Default 2.0.
    public var pollInterval: TimeInterval = 2.0

    private var pollTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public init() {}

    deinit {
        pollTask?.cancel()
    }

    // MARK: - Polling Control

    /// Start continuous background polling.
    public func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: UInt64((self?.pollInterval ?? 2.0) * 1_000_000_000))
            }
        }
    }

    /// Stop the background poll loop.
    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Refresh

    /// Single-shot refresh: fetch agent status and vault snapshot from Rust.
    public func refresh() async {
        await MainActor.run { isRefreshing = true }
        defer { Task { @MainActor in isRefreshing = false } }

        do {
            // Poll agent status via UniFFI
            let statuses = try await Task.detached(priority: .userInitiated) {
                helios_ffi.get_agent_status()
            }.value

            // Poll vault snapshot for tier visualisation
            let snapshot = try await Task.detached(priority: .userInitiated) {
                helios_ffi.get_vault_snapshot()
            }.value

            let tiers = snapshot.tiers.map { (name, bytes) -> TierVisualization in
                TierVisualization(
                    tier: name,
                    bytes: bytes,
                    colorHex: Self.colorForTier(name)
                )
            }.sorted { $0.gigabytes > $1.gigabytes }

            // Simulate a throughput sample from the latest agent
            let simulatedTokS = statuses.first.flatMap { _ in Double.random(in: 20...110) } ?? 0.0

            await MainActor.run {
                self.agents = statuses
                self.memoryTiers = tiers
                self.throughputChart.append(simulatedTokS)
                self.lastError = nil
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private static func colorForTier(_ tier: String) -> String {
        switch tier {
        case "L0ExactHot":          return "#FF6B6B"
        case "L1CompressedResidual": return "#4ECDC4"
        case "L2ShadowSketch":       return "#45B7D1"
        case "L3SSDOracle":          return "#96CEB4"
        case "L4HermesCascade":      return "#FFEAA7"
        case "LSESelfEvolving":      return "#DDA0DD"
        default:                     return "#A0A0A0"
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - SwiftUI AgentDashboard View (structural)
// ---------------------------------------------------------------------------

public struct AgentDashboardView: View {
    @StateObject private var model = AgentDashboardModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            agentList
            tierChart
            throughputSparkline
            if let error = model.lastError {
                errorBanner(error)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 320)
        .onAppear { model.startPolling() }
        .onDisappear { model.stopPolling() }
    }

    private var header: some View {
        HStack {
            Text("Agent Dashboard")
                .font(.title2.bold())
            Spacer()
            if model.isRefreshing {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Button("Refresh") {
                Task { await model.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)
        }
    }

    private var agentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Agents")
                .font(.headline)
            ForEach(model.agents, id: \.name) { agent in
                AgentStatusRow(agent: agent)
            }
        }
    }

    private var tierChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Tiers")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(model.memoryTiers) { tier in
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color(hex: tier.colorHex))
                            .frame(width: 24, height: CGFloat(tier.gigabytes * 10).clamped(to: 4...120))
                        Text(tier.tier.prefix(2))
                            .font(.caption2)
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
            .frame(height: 140)
        }
    }

    private var throughputSparkline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Throughput (tok/s)")
                .font(.headline)
            GeometryReader { geo in
                Path { path in
                    let pts = model.throughputChart.points
                    guard pts.count > 1 else { return }
                    let maxVal = max(pts.map(\.tokPerSecond).max() ?? 1.0, 1.0)
                    let stepX = geo.size.width / CGFloat(pts.count - 1)
                    for (idx, pt) in pts.enumerated() {
                        let x = CGFloat(idx) * stepX
                        let y = geo.size.height - (CGFloat(pt.tokPerSecond / maxVal) * geo.size.height)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)
            }
            .frame(height: 80)
            HStack {
                Text("Latest: \(String(format: "%.1f", model.throughputChart.latest)) tok/s")
                Spacer()
                Text("Avg: \(String(format: "%.1f", model.throughputChart.average)) tok/s")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func errorBanner(_ error: String) -> some View {
        Text("Error: \(error)")
            .font(.caption)
            .foregroundStyle(.red)
            .padding(6)
            .background(Color.red.opacity(0.1))
            .cornerRadius(6)
    }
}

// ---------------------------------------------------------------------------
// MARK: - AgentStatusRow
// ---------------------------------------------------------------------------

public struct AgentStatusRow: View {
    public let agent: AgentStatus

    public var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.system(.body, design: .monospaced))
                Text(agent.state.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Show composite scalar if we can parse resonance_json
            if let composite = compositeValue {
                Text("\(String(format: "%.2f", composite))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var stateColor: Color {
        switch agent.state.lowercased() {
        case "idle":    return .green
        case "running": return .blue
        case "gated":   return .orange
        case "error":   return .red
        default:        return .gray
        }
    }

    private var compositeValue: Double? {
        guard let data = agent.resonance_json.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let val = json["composite"] as? Double else {
            return nil
        }
        return val
    }
}

// ---------------------------------------------------------------------------
// MARK: - Helpers
// ---------------------------------------------------------------------------

extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Color {
    fileprivate init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
