import Foundation
import SwiftUI
import Combine

// ---------------------------------------------------------------------------
// MARK: - ClaimState Model
// ---------------------------------------------------------------------------

/// A single claim's visual state for the Resonance Gate view.
public struct ClaimState: Identifiable, Equatable {
    public let id = UUID()
    public let proposition: String
    public let score: Double  // -1.0 ... +1.0
    public let claimState: TernaryClaimState
    public let evidenceCount: Int
    public let kamStability: Double
    public let evidenceMass: Double

    public init(
        proposition: String,
        score: Double,
        claimState: TernaryClaimState,
        evidenceCount: Int,
        kamStability: Double,
        evidenceMass: Double
    ) {
        self.proposition = proposition
        self.score = score
        self.claimState = claimState
        self.evidenceCount = evidenceCount
        self.kamStability = kamStability
        self.evidenceMass = evidenceMass
    }
}

/// Ternary epistemic state: Fits (+1), Waiting (0), or Falls (-1).
public enum TernaryClaimState: String, CaseIterable, Equatable {
    case fits = "Fits"
    case waiting = "Waiting"
    case falls = "Falls"

    public var color: Color {
        switch self {
        case .fits:    return .green
        case .waiting: return .yellow
        case .falls:   return .red
        }
    }

    public var sign: Int {
        switch self {
        case .fits:    return 1
        case .waiting: return 0
        case .falls:   return -1
        }
    }
}

/// Decoded ResonanceSignature for SwiftUI visualisation.
public struct ResonanceSignature: Equatable {
    public let tau: TernaryClaimState
    public let rho: Double      // resonance strength
    public let kappa: Double    // KAM stability
    public let eta: Double      // evidence mass
    public let composite: Double

    public init(tau: TernaryClaimState, rho: Double, kappa: Double, eta: Double, composite: Double) {
        self.tau = tau
        self.rho = rho
        self.kappa = kappa
        self.eta = eta
        self.composite = composite
    }
}

// ---------------------------------------------------------------------------
// MARK: - ResonanceGateModel
// ---------------------------------------------------------------------------

/// Observable model driving the Resonance Gate visualisation.
@MainActor
public final class ResonanceGateModel: ObservableObject {
    /// The currently selected / computed resonance signature.
    @Published public var signature: ResonanceSignature?

    /// All claims being evaluated, with ternary state and visual metadata.
    @Published public var claimStates: [ClaimState] = []

    /// KAM stability points for sparkline (0.0 ... 1.0).
    @Published public var kamPoints: [Double] = []

    /// Evidence mass bars for histogram.
    @Published public var evidenceBars: [Double] = []

    public init() {}

    // MARK: - Populate from Rust AgentStatus

    /// Decode `AgentStatus.resonance_json` into a structured signature.
    public func load(from agent: AgentStatus) {
        guard let data = agent.resonance_json.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let tauRaw = json["tau"] as? String ?? "Waiting"
        let tau = TernaryClaimState(rawValue: tauRaw) ?? .waiting
        let rho = json["rho"] as? Double ?? 0.0
        let kappa = json["kappa"] as? Double ?? 0.0
        let eta = json["eta"] as? Double ?? 0.0
        let composite = json["composite"] as? Double ?? 0.0

        signature = ResonanceSignature(tau: tau, rho: rho, kappa: kappa, eta: eta, composite: composite)
    }

    // MARK: - Visualisation

    /// Build a KAM stability trajectory from the current claim set.
    ///
    /// In production this receives a time-series from the Rust `ResonanceGate`
    /// histogram. Here we synthesise a smooth curve from the current `kamPoints`.
    public func visualizeKAM() -> [CGPoint] {
        let pts = kamPoints.isEmpty ? [0.5, 0.6, 0.55, 0.7, 0.65] : kamPoints
        return pts.enumerated().map { idx, val in
            CGPoint(x: Double(idx), y: val)
        }
    }

    /// Build an evidence mass bar chart from the current claim set.
    public func visualizeEvidence() -> [(label: String, value: Double, color: Color)] {
        claimStates.map { claim in
            (label: claim.proposition.prefix(20).description,
             value: claim.evidenceMass,
             color: claim.claimState.color)
        }
    }

    /// Refresh with synthetic demo data (for UI previews / first-run).
    public func loadDemoData() {
        claimStates = [
            ClaimState(proposition: "Plan requires 3 agents", score: 0.85, claimState: .fits, evidenceCount: 12, kamStability: 0.91, evidenceMass: 0.73),
            ClaimState(proposition: "SSD tier exceeds budget", score: -0.40, claimState: .falls, evidenceCount: 3, kamStability: 0.30, evidenceMass: 0.15),
            ClaimState(proposition: "Metal kernel outperforms MLX", score: 0.10, claimState: .waiting, evidenceCount: 7, kamStability: 0.55, evidenceMass: 0.42),
            ClaimState(proposition: "Biometric gate latency < 50 ms", score: 0.72, claimState: .fits, evidenceCount: 20, kamStability: 0.88, evidenceMass: 0.80),
            ClaimState(proposition: "Hermes cascade not configured", score: -0.15, claimState: .waiting, evidenceCount: 1, kamStability: 0.45, evidenceMass: 0.05),
        ]
        kamPoints = claimStates.map(\.kamStability)
        evidenceBars = claimStates.map(\.evidenceMass)
    }
}

// ---------------------------------------------------------------------------
// MARK: - ResonanceGateView
// ---------------------------------------------------------------------------

public struct ResonanceGateView: View {
    @StateObject private var model = ResonanceGateModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let sig = model.signature {
                signatureCard(sig)
            }
            claimList
            kamVisualization
            evidenceHistogram
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            model.loadDemoData()
        }
    }

    private var header: some View {
        HStack {
            Text("Resonance Gate")
                .font(.title2.bold())
            Spacer()
            Button("Demo") {
                model.loadDemoData()
            }
        }
    }

    private func signatureCard(_ sig: ResonanceSignature) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Signature", systemImage: "waveform")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f", sig.composite))
                    .font(.title3.monospaced())
                    .foregroundStyle(compositeColor(sig.composite))
            }
            HStack(spacing: 12) {
                MetricPill(label: "τ", value: sig.tau.rawValue, color: sig.tau.color)
                MetricPill(label: "ρ", value: String(format: "%.2f", sig.rho), color: .blue)
                MetricPill(label: "κ", value: String(format: "%.2f", sig.kappa), color: .purple)
                MetricPill(label: "η", value: String(format: "%.2f", sig.eta), color: .orange)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }

    private var claimList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Claims")
                .font(.headline)
            ForEach(model.claimStates) { claim in
                HStack(spacing: 8) {
                    Circle()
                        .fill(claim.claimState.color)
                        .frame(width: 8, height: 8)
                    Text(claim.proposition)
                        .font(.body)
                    Spacer()
                    Text(claim.claimState.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(claim.claimState.color)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var kamVisualization: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KAM Stability")
                .font(.headline)
            GeometryReader { geo in
                let pts = model.visualizeKAM()
                guard pts.count > 1 else { return EmptyView().eraseToAnyView() }
                let maxX = pts.map(\.x).max() ?? 1
                let maxY = 1.0
                Path { path in
                    for (idx, pt) in pts.enumerated() {
                        let x = (pt.x / maxX) * Double(geo.size.width)
                        let y = Double(geo.size.height) - (pt.y / maxY) * Double(geo.size.height)
                        let cgPt = CGPoint(x: x, y: y)
                        if idx == 0 {
                            path.move(to: cgPt)
                        } else {
                            path.addLine(to: cgPt)
                        }
                    }
                }
                .stroke(Color.purple, lineWidth: 2)
            }
            .frame(height: 60)
        }
    }

    private var evidenceHistogram: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evidence Mass")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(model.visualizeEvidence().indices, id: \.self) { idx in
                    let bar = model.visualizeEvidence()[idx]
                    Rectangle()
                        .fill(bar.color)
                        .frame(width: 20, height: CGFloat(bar.value * 80).clamped(to: 4...80))
                        .help(bar.label)
                }
            }
            .frame(height: 90)
        }
    }

    private func compositeColor(_ value: Double) -> Color {
        switch value {
        case ..<0.35: return .red
        case 0.35..<0.65: return .yellow
        default: return .green
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - MetricPill
// ---------------------------------------------------------------------------

public struct MetricPill: View {
    let label: String
    let value: String
    let color: Color

    public var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }
}

// ---------------------------------------------------------------------------
// MARK: - Helpers
// ---------------------------------------------------------------------------

extension View {
    fileprivate func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

extension CGFloat {
    fileprivate func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
