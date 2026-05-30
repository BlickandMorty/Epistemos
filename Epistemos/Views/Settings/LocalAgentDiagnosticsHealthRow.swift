import Foundation
import SwiftUI

@MainActor
public struct LocalAgentDiagnosticsHealthRow: View {
    @Environment(InferenceState.self) private var inference
    @State private var snapshot: LocalAgentDiagnostics.Snapshot
    @State private var capabilityCeiling: CapabilityCeilingHealthSnapshot
    @State private var refreshTask: Task<Void, Never>?

    public init() {
        self._snapshot = State(initialValue: LocalAgentDiagnostics.snapshot())
        self._capabilityCeiling = State(initialValue: CapabilityCeilingHealthSnapshot.load())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local agent diagnostics")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Strict grammar, schema drift, and constellation routing")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: "RuntimeRouter profiles",
                productionWired: true,
                falsifierPassed: false,
                falsifier: "docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md",
                wiredToday: "Strict grammar, schema drift, local model counters, and route policy profiles are visible.",
                stillStub: "This row does not prove local tool-use production behavior or an ActiveAssembly PASS witness."
            )

            diagnosticRow(
                label: "Strict-grammar status",
                value: snapshot.strictGrammarSummary,
                systemImage: snapshot.strictMaskingAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                accent: snapshot.strictMaskingAvailable ? .green : .orange
            )
            diagnosticRow(
                label: "Schema-drift detector",
                value: snapshot.schemaDriftSummary,
                systemImage: snapshot.totalSchemaDriftEvents == 0 ? "checkmark.circle" : "waveform.path.ecg",
                accent: snapshot.totalSchemaDriftEvents == 0 ? .green : .orange
            )
            diagnosticRow(
                label: "Soft-guidance fallback",
                value: snapshot.softGuidanceSummary,
                systemImage: snapshot.totalSoftGuidanceToolPlans == 0 ? "arrow.triangle.2.circlepath" : "arrow.down.forward.circle",
                accent: snapshot.totalSoftGuidanceToolPlans == 0 ? .secondary : .orange
            )
            diagnosticRow(
                label: "Constellation health",
                value: constellationHealthDetail,
                systemImage: inference.supportsLocalAgentLoop ? "circle.hexagongrid.fill" : "circle.hexagongrid",
                accent: inference.supportsLocalAgentLoop ? .green : .secondary
            )

            Divider().padding(.vertical, 2)
            capabilityCeilingSection

            if !snapshot.modelCounters.isEmpty {
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent model counters")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(snapshot.modelCounters.prefix(3)) { counter in
                        modelCounterRow(counter)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            refresh()
            startTimer()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onReceive(
            NotificationCenter.default.publisher(for: LocalAgentDiagnostics.didChangeNotification)
        ) { _ in
            refresh()
        }
    }

    private var constellationHealthDetail: String {
        var parts = [snapshot.constellationSummary]
        if let activeModelID = inference.effectiveLocalAgentTextModelID {
            let activeName = LocalTextModelID(rawValue: activeModelID)?.displayName ?? activeModelID
            let grammar = LocalToolGrammar.nativeGrammar(forModelID: activeModelID).displayName
            parts.append("active=\(activeName) · \(grammar)")
        } else {
            parts.append("active=none")
        }
        parts.append(snapshot.routePolicySummary)
        parts.append(snapshot.hotRoleSummary)
        return parts.joined(separator: " · ")
    }

    private func refresh() {
        snapshot = LocalAgentDiagnostics.snapshot()
        capabilityCeiling = CapabilityCeilingHealthSnapshot.load()
    }

    private func startTimer() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                refresh()
            }
        }
    }

    @ViewBuilder
    private func diagnosticRow(
        label: String,
        value: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(accent)
                .frame(width: 14, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func modelCounterRow(_ counter: LocalAgentDiagnostics.ModelCounter) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)
            Text(counter.displayName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(counter.grammarDisplayName)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text("strict \(counter.strictGrammarFallbacks) · soft \(counter.softGuidanceToolPlans) · drift \(counter.schemaDriftEvents)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var capabilityCeilingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capability ceiling")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            VerifiedFloorChipStrip(
                flag: capabilityCeiling.capabilityArtifactFound ? "artifact" : "missing",
                substrate: capabilityCeiling.routeStatus,
                productionWired: false,
                falsifierPassed: capabilityCeiling.capabilityOverallPass,
                falsifier: "docs/audits/CAPABILITY_CEILING_EVALUATION_KERNEL_2026_05_28.md",
                wiredToday: "Settings reads the canonical capability rollup, pending-work guard, and KV-Direct 128K asset contract.",
                stillStub: "A red capability ceiling is honest status, not a product failure; the next build cursor stays on the artifact bottleneck."
            )
            SubstrateHealthMetricLine(
                label: "Route rollup",
                symbol: "point.topleft.down.curvedto.point.bottomright.up",
                state: capabilityCeiling.routeState,
                detail: capabilityCeiling.routeDetail
            )
            SubstrateHealthMetricLine(
                label: "KV 128K asset gate",
                symbol: "externaldrive.connected.to.line.below",
                state: capabilityCeiling.kvContextState,
                detail: capabilityCeiling.kvContextDetail
            )
            SubstrateHealthMetricLine(
                label: "Context inventory",
                symbol: "list.bullet.rectangle.portrait",
                state: capabilityCeiling.contextInventoryState,
                detail: capabilityCeiling.contextInventoryDetail
            )
            SubstrateHealthMetricLine(
                label: "Pending-work guard",
                symbol: "checklist.checked",
                state: capabilityCeiling.pendingGuardState,
                detail: capabilityCeiling.pendingGuardDetail
            )
            SubstrateHealthMetricLine(
                label: "Heavy long-context opt-in",
                symbol: "lock.shield",
                state: capabilityCeiling.heavyLongContextGuardState,
                detail: capabilityCeiling.heavyLongContextGuardDetail
            )
            SubstrateHealthMetricLine(
                label: "Worktree inventory",
                symbol: "square.stack.3d.down.right",
                state: capabilityCeiling.worktreeState,
                detail: capabilityCeiling.worktreeDetail
            )
            SubstrateHealthMetricLine(
                label: "GGUF candidate route",
                symbol: "square.stack.3d.up",
                state: capabilityCeiling.ggufState,
                detail: capabilityCeiling.ggufDetail
            )
        }
    }
}

#Preview("LocalAgentDiagnosticsHealthRow") {
    LocalAgentDiagnosticsHealthRow()
        .padding()
}

// UAS: settings/capability-ceiling-health-snapshot
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CurrentApp
nonisolated struct CapabilityCeilingHealthSnapshot: Sendable, Equatable {
    let capabilityArtifactFound: Bool
    let capabilityOverallPass: Bool
    let routeStatus: String
    let nextBottleneck: String

    let kvArtifactFound: Bool
    let kvContextSupportsRequired: Bool
    let kvModelContextTokens: Int
    let kvRequiredContextTokens: Int
    let kvResolvedModelRepoID: String
    let kvResolvedModelAssetPath: String

    let contextInventoryFound: Bool
    let contextInventoryCanonicalOK: Bool
    let contextInventoryBestCandidateRepoID: String
    let contextInventoryBestCandidateTokens: Int
    let contextInventoryRequiredCandidateCount: Int
    let contextInventoryEntries: [CapabilityCeilingContextInventoryEntry]

    let pendingGuardFound: Bool
    let pendingGuardPass: Bool
    let nextExistingWork: String
    let queueDuplicateGapIDCount: Int
    let queueDuplicateOrderCount: Int
    let heavyLongContextGuardPresent: Bool

    let worktreeInventoryFound: Bool
    let worktreeHighDuplicateRiskCount: Int
    let worktreeSiblingCount: Int
    let worktreeDirtyCandidateCount: Int

    let ggufArtifactFound: Bool
    let ggufRoutePass: Bool
    let ggufNextBottleneck: String

    static let capabilityArtifactPath = "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json"
    static let kvArtifactPath = "artifacts/falsifiers/kv_direct_gate/result.json"
    static let contextInventoryPath = "docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json"
    static let pendingWorkArtifactPath = "artifacts/falsifiers/architecture_pending_work_guard/result.json"
    static let worktreeInventoryPath = "docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json"
    static let ggufArtifactPath = "artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json"

    @MainActor
    var routeState: SubstrateHealthSignalState {
        guard capabilityArtifactFound else { return .unavailable }
        return capabilityOverallPass ? .pass : .blocked
    }

    var routeDetail: String {
        guard capabilityArtifactFound else {
            return "missing \(Self.capabilityArtifactPath)"
        }
        return "\(routeStatus) · next=\(nextBottleneck)"
    }

    @MainActor
    var kvContextState: SubstrateHealthSignalState {
        guard kvArtifactFound else { return .unavailable }
        return kvContextSupportsRequired ? .pass : .blocked
    }

    var kvContextDetail: String {
        guard kvArtifactFound else {
            return "missing \(Self.kvArtifactPath)"
        }
        let repo = kvResolvedModelRepoID.isEmpty ? "unknown repo" : kvResolvedModelRepoID
        let context = "\(kvModelContextTokens)/\(kvRequiredContextTokens) tokens"
        if kvResolvedModelAssetPath.isEmpty {
            return "\(repo) · \(context) · no asset path"
        }
        return "\(repo) · \(context) · \(kvResolvedModelAssetPath)"
    }

    @MainActor
    var contextInventoryState: SubstrateHealthSignalState {
        guard contextInventoryFound else { return .unavailable }
        return contextInventoryCanonicalOK ? .pass : .partial
    }

    var contextInventoryDetail: String {
        guard contextInventoryFound else {
            return "missing \(Self.contextInventoryPath)"
        }
        if contextInventoryCanonicalOK {
            return "canonical Qwen/Qwen3-8B-MLX-4bit satisfies 128K context"
        }
        let repo = contextInventoryBestCandidateRepoID.isEmpty
            ? "no candidate"
            : contextInventoryBestCandidateRepoID
        return "canonical red · best candidate=\(repo) \(contextInventoryBestCandidateTokens) tokens · candidate count=\(contextInventoryRequiredCandidateCount)"
    }

    @MainActor
    var pendingGuardState: SubstrateHealthSignalState {
        guard pendingGuardFound else { return .unavailable }
        return pendingGuardPass && queueDuplicateGapIDCount == 0 && queueDuplicateOrderCount == 0 ? .pass : .blocked
    }

    var pendingGuardDetail: String {
        guard pendingGuardFound else {
            return "missing \(Self.pendingWorkArtifactPath)"
        }
        return "next=\(nextExistingWork) · duplicate gaps=\(queueDuplicateGapIDCount) orders=\(queueDuplicateOrderCount)"
    }

    @MainActor
    var heavyLongContextGuardState: SubstrateHealthSignalState {
        guard pendingGuardFound else { return .unavailable }
        return heavyLongContextGuardPresent ? .pass : .blocked
    }

    var heavyLongContextGuardDetail: String {
        guard pendingGuardFound else {
            return "missing \(Self.pendingWorkArtifactPath)"
        }
        return heavyLongContextGuardPresent
            ? "normal local runs stay under 32K; >32K requires EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1"
            : "missing >32K opt-in guard; do not run long-context local probes"
    }

    @MainActor
    var worktreeState: SubstrateHealthSignalState {
        guard worktreeInventoryFound else { return .unavailable }
        return worktreeHighDuplicateRiskCount == 0 ? .pass : .partial
    }

    var worktreeDetail: String {
        guard worktreeInventoryFound else {
            return "missing \(Self.worktreeInventoryPath)"
        }
        return "sibling worktrees=\(worktreeSiblingCount) · dirty=\(worktreeDirtyCandidateCount) · preserve-before-new-work risk=\(worktreeHighDuplicateRiskCount)"
    }

    @MainActor
    var ggufState: SubstrateHealthSignalState {
        guard ggufArtifactFound else { return .unavailable }
        return ggufRoutePass ? .pass : .partial
    }

    var ggufDetail: String {
        guard ggufArtifactFound else {
            return "missing \(Self.ggufArtifactPath)"
        }
        return ggufRoutePass
            ? "candidate pass; still separate from canonical MLX KV-Direct"
            : "candidate only · next=\(ggufNextBottleneck)"
    }

    static func load() -> Self {
        let capability = readJSONObject(path: capabilityArtifactPath)
        let kv = readJSONObject(path: kvArtifactPath)
        let contextInventory = readJSONObject(path: contextInventoryPath)
        let pending = readJSONObject(path: pendingWorkArtifactPath)
        let worktreeInventory = readJSONObject(path: worktreeInventoryPath)
        let gguf = readJSONObject(path: ggufArtifactPath)
        let contextSummary = contextInventory?["summary"] as? [String: Any]
        let worktreeSummary = worktreeInventory?["summary"] as? [String: Any]

        return CapabilityCeilingHealthSnapshot(
            capabilityArtifactFound: capability != nil,
            capabilityOverallPass: topLevelBool(capability, key: "overall_pass"),
            routeStatus: measurementString(capability, key: "route_status", default: "unknown route"),
            nextBottleneck: measurementString(
                capability,
                key: "next_bottleneck",
                default: "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct"
            ),
            kvArtifactFound: kv != nil,
            kvContextSupportsRequired: measurementBool(kv, key: "model_context_supports_required_context"),
            kvModelContextTokens: measurementInt(kv, key: "model_context_window_tokens"),
            kvRequiredContextTokens: measurementInt(kv, key: "prompt_suite_min_context_tokens", default: 128_000),
            kvResolvedModelRepoID: measurementString(kv, key: "resolved_model_repo_id", default: ""),
            kvResolvedModelAssetPath: measurementString(kv, key: "resolved_model_asset_path", default: ""),
            contextInventoryFound: contextInventory != nil,
            contextInventoryCanonicalOK: summaryBool(contextSummary, key: "canonical_context_ok"),
            contextInventoryBestCandidateRepoID: summaryString(
                contextSummary,
                key: "best_required_context_candidate_repo_id",
                default: ""
            ),
            contextInventoryBestCandidateTokens: summaryInt(
                contextSummary,
                key: "best_required_context_candidate_tokens"
            ),
            contextInventoryRequiredCandidateCount: summaryInt(
                contextSummary,
                key: "required_context_text_model_candidate_count"
            ),
            contextInventoryEntries: contextInventoryEntries(contextInventory),
            pendingGuardFound: pending != nil,
            pendingGuardPass: topLevelBool(pending, key: "overall_pass"),
            nextExistingWork: measurementString(
                pending,
                key: "next_existing_work",
                default: "resolve_qwen3_8b_128k_context_model_assets_for_kv_direct"
            ),
            queueDuplicateGapIDCount: measurementInt(pending, key: "queue_duplicate_gap_id_count"),
            queueDuplicateOrderCount: measurementInt(pending, key: "queue_duplicate_order_count"),
            heavyLongContextGuardPresent: measurementBool(pending, key: "heavy_long_context_guard_present"),
            worktreeInventoryFound: worktreeInventory != nil,
            worktreeHighDuplicateRiskCount: summaryInt(worktreeSummary, key: "high_duplicate_risk_count"),
            worktreeSiblingCount: summaryInt(worktreeSummary, key: "sibling_worktree_count"),
            worktreeDirtyCandidateCount: summaryInt(worktreeSummary, key: "dirty_candidate_count"),
            ggufArtifactFound: gguf != nil,
            ggufRoutePass: topLevelBool(gguf, key: "overall_pass"),
            ggufNextBottleneck: ggufNextBottleneck(gguf)
        )
    }

    func contextInventoryEntry(for modelID: String) -> CapabilityCeilingContextInventoryEntry? {
        contextInventoryEntries.first { $0.repoID == modelID }
    }

    private static func contextInventoryEntries(_ json: [String: Any]?) -> [CapabilityCeilingContextInventoryEntry] {
        guard let entries = json?["entries"] as? [[String: Any]] else {
            return []
        }
        return entries.compactMap { entry in
            guard let repoID = entry["repo_id"] as? String else {
                return nil
            }
            return CapabilityCeilingContextInventoryEntry(
                repoID: repoID,
                effectiveContextTokens: jsonInt(entry, key: "effective_context_tokens"),
                declaredContextTokens: jsonInt(entry, key: "declared_context_tokens"),
                hasLocalWeights: entry["has_local_weights"] as? Bool ?? false,
                isCanonicalKVDirectModel: entry["is_canonical_kv_direct_model"] as? Bool ?? false,
                isTextGenerationCandidate: entry["is_text_generation_candidate"] as? Bool ?? false,
                satisfiesRequiredContext: entry["satisfies_required_context"] as? Bool ?? false,
                contextSource: entry["context_source"] as? String ?? "unknown"
            )
        }
    }

    private static func ggufNextBottleneck(_ json: [String: Any]?) -> String {
        if let value = measurementString(json, key: "next_bottleneck", default: nil) {
            return value
        }
        if let anomalies = json?["anomalies"] as? [[String: Any]],
           let missing = anomalies.first(where: { ($0["kind"] as? String) == "missing_gguf_model_file" }),
           let detail = missing["detail"] as? String {
            return detail
        }
        return "download_or_register_qwen3_8b_128k_gguf_model_file"
    }

    private static func readJSONObject(path: String) -> [String: Any]? {
        guard let url = firstExistingURL(for: path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
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

    private static func topLevelBool(_ json: [String: Any]?, key: String) -> Bool {
        json?[key] as? Bool ?? false
    }

    private static func measurementBool(_ json: [String: Any]?, key: String) -> Bool {
        measurementValue(json, key: key) as? Bool ?? false
    }

    private static func measurementInt(_ json: [String: Any]?, key: String, default defaultValue: Int = 0) -> Int {
        let value = measurementValue(json, key: key)
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String, let int = Int(string) { return int }
        return defaultValue
    }

    private static func measurementString(_ json: [String: Any]?, key: String, default defaultValue: String?) -> String? {
        guard let value = measurementValue(json, key: key) else {
            return defaultValue
        }
        if let string = value as? String { return string }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        if let int = value as? Int { return String(int) }
        if let double = value as? Double { return String(double) }
        return defaultValue
    }

    private static func measurementString(_ json: [String: Any]?, key: String, default defaultValue: String) -> String {
        measurementString(json, key: key, default: Optional(defaultValue)) ?? defaultValue
    }

    private static func measurementValue(_ json: [String: Any]?, key: String) -> Any? {
        guard
            let measurements = json?["measurements"] as? [String: Any],
            let envelope = measurements[key] as? [String: Any]
        else {
            return nil
        }
        return envelope["value"]
    }

    private static func summaryBool(_ summary: [String: Any]?, key: String) -> Bool {
        summary?[key] as? Bool ?? false
    }

    private static func summaryInt(_ summary: [String: Any]?, key: String, default defaultValue: Int = 0) -> Int {
        let value = summary?[key]
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String, let int = Int(string) { return int }
        return defaultValue
    }

    private static func summaryString(_ summary: [String: Any]?, key: String, default defaultValue: String) -> String {
        summary?[key] as? String ?? defaultValue
    }

    private static func jsonInt(_ json: [String: Any], key: String, default defaultValue: Int = 0) -> Int {
        let value = json[key]
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String, let int = Int(string) { return int }
        return defaultValue
    }
}

nonisolated struct CapabilityCeilingContextInventoryEntry: Sendable, Equatable {
    let repoID: String
    let effectiveContextTokens: Int
    let declaredContextTokens: Int
    let hasLocalWeights: Bool
    let isCanonicalKVDirectModel: Bool
    let isTextGenerationCandidate: Bool
    let satisfiesRequiredContext: Bool
    let contextSource: String
}
