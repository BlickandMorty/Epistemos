import AppKit
import SwiftUI

// MARK: - Unified Substrate Health FFI Mirror

nonisolated struct SubstrateHealthUnifiedSnapshot: Sendable, Equatable, Decodable {
    let generatedAtMs: Int64
    let emlObservatory: EmlObservatory
    let uasAcs: UasAcs
    let cognitiveDagCounts: CognitiveDagCounts
    let planePlacement: PlanePlacement
    let cognitiveWeight: CognitiveWeight
    let driftMonitor: DriftMonitor
    let ffiErrorDescription: String?

    enum CodingKeys: String, CodingKey {
        case generatedAtMs = "generated_at_ms"
        case emlObservatory = "eml_observatory"
        case uasAcs = "uas_acs"
        case cognitiveDagCounts = "cognitive_dag_counts"
        case planePlacement = "plane_placement"
        case cognitiveWeight = "cognitive_weight"
        case driftMonitor = "drift_monitor"
    }

    static func unavailable(_ message: String) -> Self {
        SubstrateHealthUnifiedSnapshot(
            generatedAtMs: 0,
            emlObservatory: .unavailable,
            uasAcs: .unavailable,
            cognitiveDagCounts: .unavailable,
            planePlacement: .unavailable,
            cognitiveWeight: .unavailable,
            driftMonitor: .unavailable,
            ffiErrorDescription: message
        )
    }

    init(
        generatedAtMs: Int64,
        emlObservatory: EmlObservatory,
        uasAcs: UasAcs,
        cognitiveDagCounts: CognitiveDagCounts,
        planePlacement: PlanePlacement,
        cognitiveWeight: CognitiveWeight,
        driftMonitor: DriftMonitor,
        ffiErrorDescription: String? = nil
    ) {
        self.generatedAtMs = generatedAtMs
        self.emlObservatory = emlObservatory
        self.uasAcs = uasAcs
        self.cognitiveDagCounts = cognitiveDagCounts
        self.planePlacement = planePlacement
        self.cognitiveWeight = cognitiveWeight
        self.driftMonitor = driftMonitor
        self.ffiErrorDescription = ffiErrorDescription
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            generatedAtMs: try c.decode(Int64.self, forKey: .generatedAtMs),
            emlObservatory: try c.decode(EmlObservatory.self, forKey: .emlObservatory),
            uasAcs: try c.decode(UasAcs.self, forKey: .uasAcs),
            cognitiveDagCounts: try c.decode(CognitiveDagCounts.self, forKey: .cognitiveDagCounts),
            planePlacement: try c.decode(PlanePlacement.self, forKey: .planePlacement),
            cognitiveWeight: try c.decode(CognitiveWeight.self, forKey: .cognitiveWeight),
            driftMonitor: try c.decode(DriftMonitor.self, forKey: .driftMonitor)
        )
    }

    nonisolated struct EmlObservatory: Sendable, Equatable, Decodable {
        let ffiReachable: Bool
        let liveStreamWired: Bool
        let sampleObservations: Int
        let augmentedAuc: Double
        let aucBar: Double
        let summaryCount: Int
        let summaryPositives: Int
        let summaryNegatives: Int
        let meanPotential: Double?
        let falsifier: String
        let wRow: String

        enum CodingKeys: String, CodingKey {
            case ffiReachable = "ffi_reachable"
            case liveStreamWired = "live_stream_wired"
            case sampleObservations = "sample_observations"
            case augmentedAuc = "augmented_auc"
            case aucBar = "auc_bar"
            case summaryCount = "summary_count"
            case summaryPositives = "summary_positives"
            case summaryNegatives = "summary_negatives"
            case meanPotential = "mean_potential"
            case falsifier
            case wRow = "w_row"
        }

        static let unavailable = EmlObservatory(
            ffiReachable: false,
            liveStreamWired: false,
            sampleObservations: 0,
            augmentedAuc: 0,
            aucBar: 0.90,
            summaryCount: 0,
            summaryPositives: 0,
            summaryNegatives: 0,
            meanPotential: nil,
            falsifier: "docs/falsifiers/F-ULP-Oracle_2026_05_17.md",
            wRow: "W-07"
        )
    }

    nonisolated struct UasAcs: Sendable, Equatable, Decodable {
        let ffiReachable: Bool
        let knownUasKinds: [String]
        let residencyTiers: [String]
        let copyCount: Int
        let allocCount: Int
        let bytesAllocated: Int
        let productionAnchorLookupWired: Bool
        let falsifier: String
        let wRow: String

        enum CodingKeys: String, CodingKey {
            case ffiReachable = "ffi_reachable"
            case knownUasKinds = "known_uas_kinds"
            case residencyTiers = "residency_tiers"
            case copyCount = "copy_count"
            case allocCount = "alloc_count"
            case bytesAllocated = "bytes_allocated"
            case productionAnchorLookupWired = "production_anchor_lookup_wired"
            case falsifier
            case wRow = "w_row"
        }

        static let unavailable = UasAcs(
            ffiReachable: false,
            knownUasKinds: [],
            residencyTiers: [],
            copyCount: 0,
            allocCount: 0,
            bytesAllocated: 0,
            productionAnchorLookupWired: false,
            falsifier: "docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md",
            wRow: "W-10"
        )
    }

    nonisolated struct CognitiveDagCounts: Sendable, Equatable, Decodable {
        let ffiReachable: Bool
        let nodeCount: Int
        let edgeCount: Int
        let schemaVersion: UInt32
        let merkleRootHex: String
        let nodeKindCounts: [String: Int]
        let edgeKindCounts: [String: Int]
        let falsifier: String
        let wRow: String

        enum CodingKeys: String, CodingKey {
            case ffiReachable = "ffi_reachable"
            case nodeCount = "node_count"
            case edgeCount = "edge_count"
            case schemaVersion = "schema_version"
            case merkleRootHex = "merkle_root_hex"
            case nodeKindCounts = "node_kind_counts"
            case edgeKindCounts = "edge_kind_counts"
            case falsifier
            case wRow = "w_row"
        }

        static let unavailable = CognitiveDagCounts(
            ffiReachable: false,
            nodeCount: 0,
            edgeCount: 0,
            schemaVersion: 0,
            merkleRootHex: "",
            nodeKindCounts: [:],
            edgeKindCounts: [:],
            falsifier: "docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md",
            wRow: "W-26"
        )
    }

    nonisolated struct PlanePlacement: Sendable, Equatable, Decodable {
        let ffiReachable: Bool
        let terminalGRequired: Bool
        let planeFieldsWired: Bool
        let stateCount: Int
        let episodicCount: Int
        let assemblyCount: Int
        let controllerCount: Int
        let verificationCount: Int
        let unplacedCount: Int
        let dependency: String
        let falsifier: String
        let wRow: String

        enum CodingKeys: String, CodingKey {
            case ffiReachable = "ffi_reachable"
            case terminalGRequired = "terminal_g_required"
            case planeFieldsWired = "plane_fields_wired"
            case stateCount = "state_count"
            case episodicCount = "episodic_count"
            case assemblyCount = "assembly_count"
            case controllerCount = "controller_count"
            case verificationCount = "verification_count"
            case unplacedCount = "unplaced_count"
            case dependency
            case falsifier
            case wRow = "w_row"
        }

        static let unavailable = PlanePlacement(
            ffiReachable: false,
            terminalGRequired: false,
            planeFieldsWired: false,
            stateCount: 0,
            episodicCount: 0,
            assemblyCount: 0,
            controllerCount: 0,
            verificationCount: 0,
            unplacedCount: 0,
            dependency: "agent_core FFI unavailable",
            falsifier: "docs/falsifiers/F-ACS-AnchorLookup_2026_05_24.md",
            wRow: "W-24/W-28/T14"
        )
    }

    nonisolated struct CognitiveWeight: Sendable, Equatable, Decodable {
        let ffiReachable: Bool
        let policyEnforcementWired: Bool
        let classes: [WeightClass]
        let falsifier: String
        let wRow: String

        enum CodingKeys: String, CodingKey {
            case ffiReachable = "ffi_reachable"
            case policyEnforcementWired = "policy_enforcement_wired"
            case classes
            case falsifier
            case wRow = "w_row"
        }

        static let unavailable = CognitiveWeight(
            ffiReachable: false,
            policyEnforcementWired: false,
            classes: [],
            falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md",
            wRow: "W-30"
        )
    }

    nonisolated struct WeightClass: Sendable, Equatable, Decodable, Identifiable {
        let badge: String
        let label: String
        let className: String
        let range: String
        let policyAuthority: Bool

        var id: String { badge }

        enum CodingKeys: String, CodingKey {
            case badge
            case label
            case className = "class"
            case range
            case policyAuthority = "policy_authority"
        }
    }

    nonisolated struct DriftMonitor: Sendable, Equatable, Decodable {
        let ffiReachable: Bool
        let wboAppendsAccounted: UInt64
        let wboTier: String
        let wboFalsifier: String
        let dagRoot: String
        let copyCount: Int
        let allocCount: Int
        let falsifierPassed: Bool
        let falsifier: String
        let wRow: String

        enum CodingKeys: String, CodingKey {
            case ffiReachable = "ffi_reachable"
            case wboAppendsAccounted = "wbo_appends_accounted"
            case wboTier = "wbo_tier"
            case wboFalsifier = "wbo_falsifier"
            case dagRoot = "dag_root"
            case copyCount = "copy_count"
            case allocCount = "alloc_count"
            case falsifierPassed = "falsifier_passed"
            case falsifier
            case wRow = "w_row"
        }

        static let unavailable = DriftMonitor(
            ffiReachable: false,
            wboAppendsAccounted: 0,
            wboTier: "",
            wboFalsifier: "",
            dagRoot: "",
            copyCount: 0,
            allocCount: 0,
            falsifierPassed: false,
            falsifier: "docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md",
            wRow: "W-33"
        )
    }
}

nonisolated enum SubstrateHealthDiagnostics {
    static let maxStatusMessageCharacters = 240
    private static let maxDomainCharacters = 96
    private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

    static func statusMessage(for error: Error, fallback: String = "substrate health unavailable") -> String {
        let nsError = error as NSError
        let domain = safeDomain(nsError.domain)
        return statusMessage("\(fallback) (domain=\(domain) code=\(nsError.code))", fallback: fallback)
    }

    static func statusMessage(_ message: String, fallback: String = "substrate health unavailable") -> String {
        let bounded = String(message.prefix(maxStatusMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxStatusMessageCharacters else {
            return value
        }
        return String(value.prefix(maxStatusMessageCharacters - 3)) + "..."
    }

    private static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
            return "Error"
        }
        let value = trimmed.isEmpty ? "Error" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Error"
        }
        let safeDomain = String(value.prefix(maxDomainCharacters))
        return safeDomain.isEmpty ? "Error" : safeDomain
    }
}

nonisolated enum SubstrateHealthUnifiedClient {
    static func snapshot() -> SubstrateHealthUnifiedSnapshot {
        #if canImport(agent_coreFFI)
        do {
            let raw = try substrateHealthUnifiedJson()
            let decoded = try JSONDecoder().decode(
                SubstrateHealthUnifiedSnapshot.self,
                from: Data(raw.utf8)
            )
            return decoded
        } catch {
            return .unavailable(SubstrateHealthDiagnostics.statusMessage(for: error))
        }
        #else
        return .unavailable("agent_core FFI unavailable")
        #endif
    }

    /// SS-SH (substrate-health "glitched / not working"): the SAME unified snapshot,
    /// but fetched OFF the MainActor — the synchronous Rust FFI + JSON decode run on
    /// a detached background task, and only the result hops back. The old per-row
    /// pollers previously ran this FFI ON the MainActor (~6 sync round-trips/sec on
    /// one panel), so a single slow/contended FFI call froze the whole panel and
    /// blocked scrolling — violating "never block @MainActor". Callers set their
    /// `@State` from the awaited result (back on the MainActor).
    static func snapshotAsync() async -> SubstrateHealthUnifiedSnapshot {
        await Task.detached { snapshot() }.value
    }
}

// MARK: - Shared Substrate Health UI Primitives

@MainActor
enum SubstrateHealthSignalState {
    case pass
    case partial
    case blocked
    case unavailable

    var tint: Color {
        switch self {
        case .pass: .green
        case .partial: .orange
        case .blocked: .red
        case .unavailable: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .pass: "checkmark.circle.fill"
        case .partial: "exclamationmark.triangle.fill"
        case .blocked: "xmark.circle.fill"
        case .unavailable: "circle.dashed"
        }
    }
}

@MainActor
struct SubstrateHealthMetricLine: View {
    let label: String
    let symbol: String
    let state: SubstrateHealthSignalState
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: state.symbol)
                .foregroundStyle(state.tint)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

@MainActor
struct SubstrateFalsifierLink: View {
    let path: String
    let wRow: String

    var body: some View {
        Button {
            openDoc()
        } label: {
            Label("\(wRow) falsifier: \(shortName)", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(path)
        .accessibilityLabel("\(wRow) falsifier document \(shortName)")
    }

    private var shortName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private func openDoc() {
        if let url = candidateURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.open(url)
        }
    }

    private var candidateURLs: [URL] {
        var urls = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(path)
        ]
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent("SourceMirror").appendingPathComponent(path))
        }
        return urls
    }
}
