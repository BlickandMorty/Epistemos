import AppKit
import SwiftUI

// MARK: - UasAcsHealthRow
//
// W-10: UAS / ACS (Anchored Cognitive Substrate) status surface.
// The row is intentionally honest: address taxonomy and residency
// tiers are reachable via FFI; measured falsifier gates are read from
// their result.json artifacts; production anchor lookup is reported
// separately so harness PASS does not imply runtime adapter installation.

@MainActor
public struct UasAcsHealthRow: View {
    @State private var snapshot: SubstrateHealthUnifiedSnapshot
    @State private var gates: UasAcsGateSnapshot
    @Environment(SubstrateHealthClock.self) private var healthClock: SubstrateHealthClock?

    public init() {
        self._snapshot = State(initialValue: SubstrateHealthUnifiedClient.snapshot())
        self._gates = State(initialValue: UasAcsGateSnapshot.load())
    }

    public var body: some View {
        let uas = snapshot.uasAcs
        let gateSnapshot = gates
        VStack(alignment: .leading, spacing: 8) {
            SubstrateHealthMetricLine(
                label: "UAS address taxonomy",
                symbol: "point.3.connected.trianglepath.dotted",
                state: uas.ffiReachable ? .partial : .unavailable,
                detail: "\(uas.knownUasKinds.count) known kinds; \(uas.residencyTiers.count) residency tiers"
            )
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: uas.productionAnchorLookupWired
                    ? "production anchor lookup"
                    : (gateSnapshot.allPassed ? "falsifiers pass" : "taxonomy + artifacts"),
                productionWired: uas.productionAnchorLookupWired,
                falsifierPassed: gateSnapshot.allPassed,
                falsifier: "F-UAS-CopyCount + F-ACS-AnchorLookup",
                wiredToday: "UAS kind taxonomy, residency tiers, copy counters, and measured artifact gates are readable.",
                stillStub: "Production anchor lookup stays non-green until the MAS runtime adapter uses anchor_registry.rs directly."
            )
            SubstrateHealthMetricLine(
                label: "Copy counters",
                symbol: "arrow.triangle.2.circlepath",
                state: uas.ffiReachable ? .partial : .unavailable,
                detail: "copies=\(uas.copyCount) allocs=\(uas.allocCount) bytes=\(uas.bytesAllocated)"
            )
            gateButton(
                gateSnapshot.copyCount,
                symbol: "doc.on.doc",
                defaultLabel: "F-UAS-CopyCount"
            )
            gateButton(
                gateSnapshot.anchorLookup,
                symbol: "key.horizontal",
                defaultLabel: "F-ACS-AnchorLookup"
            )
            SubstrateHealthMetricLine(
                label: "Production adapter",
                symbol: "lock.shield",
                state: uas.productionAnchorLookupWired ? .pass : .partial,
                detail: uas.productionAnchorLookupWired
                    ? "production anchor lookup wired"
                    : "anchor_registry.rs exists; MAS runtime adapter pending"
            )
        }
        .substrateHealthPoll {
            if let unified = healthClock?.unified { snapshot = unified }
            // SS-SH: move the per-tick UAS-gate load OFF the MainActor. After the unified-snapshot
            // dedup (6 FFI/sec → 1), this `UasAcsGateSnapshot.load()` (copyCount + anchorLookup file
            // reads) was the ONE remaining 1 Hz SYNCHRONOUS read on the main thread in the panel —
            // the residual freeze/stutter contributor. Matches the off-MainActor pattern the other
            // rows use: load on a detached task, hop the result back.
            Task {
                let freshGates = await Task.detached { UasAcsGateSnapshot.load() }.value
                gates = freshGates
            }
        }
    }

    @ViewBuilder
    private func gateButton(
        _ gate: UasAcsGate,
        symbol: String,
        defaultLabel: String
    ) -> some View {
        Button {
            openGateDetail(gate)
        } label: {
            SubstrateHealthMetricLine(
                label: gate.falsifier.isEmpty ? defaultLabel : gate.falsifier,
                symbol: symbol,
                state: gateState(gate),
                detail: gate.detail
            )
        }
        .buttonStyle(.plain)
        .help(gate.helpText)
        .accessibilityLabel("\(defaultLabel) artifact detail")
    }

    private func gateState(_ gate: UasAcsGate) -> SubstrateHealthSignalState {
        guard gate.artifactFound else { return .unavailable }
        return gate.status.uppercased() == "PASS" ? .pass : .blocked
    }

    private func openGateDetail(_ gate: UasAcsGate) {
        if let url = gate.preferredDetailURL {
            NSWorkspace.shared.open(url)
        }
    }
}

// UAS: settings/uas-acs-gate-snapshot
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CurrentApp
nonisolated struct UasAcsGateSnapshot: Sendable, Equatable {
    let copyCount: UasAcsGate
    let anchorLookup: UasAcsGate

    var allPassed: Bool {
        copyCount.isPassing && anchorLookup.isPassing
    }

    static func load() -> Self {
        UasAcsGateSnapshot(
            copyCount: .copyCount(),
            anchorLookup: .anchorLookup()
        )
    }
}

// UAS: settings/uas-acs-gate
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CurrentApp
nonisolated struct UasAcsGate: Sendable, Equatable {
    let falsifier: String
    let status: String
    let detail: String
    let artifactPath: String
    let docPath: String
    let artifactFound: Bool

    var isPassing: Bool {
        artifactFound && status.uppercased() == "PASS"
    }

    var helpText: String {
        artifactFound
            ? "\(artifactPath) - \(docPath)"
            : "Missing \(artifactPath); fallback doc \(docPath)"
    }

    var preferredDetailURL: URL? {
        Self.firstExistingURL(for: artifactPath) ?? Self.firstExistingURL(for: docPath)
    }

    static func copyCount() -> Self {
        let artifactPath = "artifacts/falsifiers/uas_copy_count/result.json"
        let docPath = "docs/falsifiers/F-UAS-CopyCount_2026_05_24.md"
        guard
            let url = firstExistingURL(for: artifactPath),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(CopyCountArtifact.self, from: data)
        else {
            return UasAcsGate(
                falsifier: "F-UAS-CopyCount",
                status: "MISSING",
                detail: "missing artifact \(artifactPath)",
                artifactPath: artifactPath,
                docPath: docPath,
                artifactFound: false
            )
        }

        let m = decoded.measurements
        let detail = [
            "copies=\(m.tensorCopyCount)",
            "bytes=\(m.dataCopyBytes)",
            "allocs=\(m.allocatorCountInstrumented)"
        ].joined(separator: " ")
        return UasAcsGate(
            falsifier: decoded.falsifier,
            status: decoded.status,
            detail: "\(decoded.status) - \(detail)",
            artifactPath: artifactPath,
            docPath: docPath,
            artifactFound: true
        )
    }

    static func anchorLookup() -> Self {
        let artifactPath = "artifacts/falsifiers/acs_anchor_lookup/result.json"
        let docPath = "docs/falsifiers/F-ACS-AnchorLookup_2026_05_24.md"
        guard
            let url = firstExistingURL(for: artifactPath),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(AnchorLookupArtifact.self, from: data)
        else {
            return UasAcsGate(
                falsifier: "F-ACS-AnchorLookup",
                status: "MISSING",
                detail: "missing artifact \(artifactPath)",
                artifactPath: artifactPath,
                docPath: docPath,
                artifactFound: false
            )
        }

        let m = decoded.measurements
        let detail = [
            "avg=\(m.avgLookupNs)ns",
            "found=\(m.foundCount)/\(m.claimCount)",
            "reject=\(m.invalidTheoremRejected)"
        ].joined(separator: " ")
        return UasAcsGate(
            falsifier: decoded.falsifier,
            status: decoded.status,
            detail: "\(decoded.status) - \(detail)",
            artifactPath: artifactPath,
            docPath: docPath,
            artifactFound: true
        )
    }

    private static func firstExistingURL(for path: String) -> URL? {
        candidateURLs(for: path).first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func candidateURLs(for path: String) -> [URL] {
        var urls = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(path)
        ]
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent("SourceMirror").appendingPathComponent(path))
        }
        return urls
    }

    // UAS: settings/uas-copy-count-falsifier-artifact
    // Plane: RuntimePlane::Verification
    // Residency: ResidencyTier::BundleArtifact
    private struct CopyCountArtifact: Decodable {
        let falsifier: String
        let status: String
        let measurements: Measurements

        struct Measurements: Decodable {
            let tensorCopyCount: Int
            let dataCopyBytes: Int
            let allocatorCountInstrumented: Int

            enum CodingKeys: String, CodingKey {
                case tensorCopyCount = "tensor_copy_count"
                case dataCopyBytes = "data_copy_bytes"
                case allocatorCountInstrumented = "allocator_count_instrumented"
            }
        }
    }

    // UAS: settings/acs-anchor-lookup-falsifier-artifact
    // Plane: RuntimePlane::Verification
    // Residency: ResidencyTier::BundleArtifact
    private struct AnchorLookupArtifact: Decodable {
        let falsifier: String
        let status: String
        let measurements: Measurements

        struct Measurements: Decodable {
            let claimCount: Int
            let foundCount: Int
            let avgLookupNs: Int
            let invalidTheoremRejected: Bool

            enum CodingKeys: String, CodingKey {
                case claimCount = "claim_count"
                case foundCount = "found_count"
                case avgLookupNs = "avg_lookup_ns"
                case invalidTheoremRejected = "invalid_theorem_rejected"
            }
        }
    }
}

#if DEBUG
#Preview("UasAcsHealthRow") {
    UasAcsHealthRow()
        .padding()
        .frame(width: 460)
}
#endif
