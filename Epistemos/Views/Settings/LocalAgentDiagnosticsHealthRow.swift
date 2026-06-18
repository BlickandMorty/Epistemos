import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct LocalAgentDiagnosticsHealthRow: View {
    private static let gemmaCutoverPlanPath =
        "docs/audits/GEMMA_SYSTEMG_USER_FACING_CUTOVER_PLAN_2026_06_09.md"
    private static let gemmaOfficialQATAcquisitionPath =
        "Tools/falsifiers/acquire_gemma_official_qat_gguf.sh"
    private static let gemmaFirstRuntimePathsPath =
        "Tools/falsifiers/gemma_first_runtime_paths.sh"
    private static let gemmaReceiptMaterializerPath =
        "Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh"
    private static let gemmaQualityObservationReplayPath =
        "Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.sh"
    private static let gemmaReleaseAuditAutomatedChecksCursor =
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe"
    private static let gemmaRecommendedLaneSummary =
        "Official Google QAT Q4_0 GGUF ladder: E2B first proof, E4B balanced local lane, 12B Pro flagship after proof; 26B/31B stay research/vault until measured."
    private static var gemmaAcquireCommandTemplate: String {
        guard let candidate = GemmaQATRuntimeLadder.firstRuntimeHarnessCandidate else {
            return "Tools/falsifiers/acquire_gemma_official_qat_gguf.sh --lane e2b --materialize-receipt"
        }
        return gemmaAcquireCommandTemplate(for: candidate)
    }

    private static func gemmaAcquireCommandTemplate(for candidate: GemmaQATRuntimeCandidate) -> String {
        """
        # Acquire \(candidate.displayName) into explicit quarantine.
        # This downloads and verifies bytes/SHA; it does not run Gemma or mutate routes.
        export EPI_GEMMA_PROOF_LANE="\(candidate.acquisitionLaneArgument)"
        export EPI_GEMMA_OWNER_APPROVAL_PHRASE="<owner approval phrase>"
        Tools/falsifiers/acquire_gemma_official_qat_gguf.sh --lane \(candidate.acquisitionLaneArgument) --materialize-receipt
        """
    }
    private static let gemmaQualityObservationReplayTemplate = """
    # Run seven tiny Gemma QAT quality observations and score them digest-only.
    # Set lane to e2b, e4b, or 12b so artifacts do not overwrite another lane.
    # Raw candidate outputs are kept in a temporary file and deleted after replay.
    export EPI_GEMMA_PROOF_LANE="e2b"
    export EPI_GEMMA_LOCAL_MODEL_PATH="<absolute path to verified local E2B/E4B/12B QAT GGUF>"
    export EPI_GEMMA_LLAMA_CLI="/opt/homebrew/bin/llama-cli"
    Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.sh
    """
    private static let gemmaReceiptCommandTemplate = """
    # Official Google Gemma 4 QAT Q4_0 GGUF lane.
    # Choose exactly one local file:
    # - Fast proof: google/gemma-4-E2B-it-qat-q4_0-gguf
    # - Balanced local lane: google/gemma-4-E4B-it-qat-q4_0-gguf
    # - Pro flagship after proof: google/gemma-4-12B-it-qat-q4_0-gguf
    export EPI_GEMMA_OWNER_APPROVAL_PHRASE="<owner approval phrase>"
    export EPI_GEMMA_PROOF_LANE="<e2b | e4b | 12b>"
    export EPI_GEMMA_LOCAL_MODEL_PATH="<absolute path to approved local E2B/E4B/12B QAT GGUF>"
    export EPI_GEMMA_SELECTED_MODEL_ID="<one official google/gemma-4-*-it-qat-q4_0-gguf repo id>"
    export EPI_GEMMA_EXPECTED_FILENAME="<exact local .gguf filename>"
    export EPI_GEMMA_EXPECTED_BYTE_COUNT="<exact local file byte count>"
    export EPI_GEMMA_EXPECTED_LFS_SHA256="<source lfs sha256>"
    export EPI_GEMMA_SOURCE_REVISION="<source revision>"
    export EPI_GEMMA_SOURCE_LICENSE_REF="<source license ref>"
    export EPI_GEMMA_LLAMA_CLI="/opt/homebrew/bin/llama-cli"
    Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh
    """

    @Environment(InferenceState.self) private var inference
    @State private var snapshot: LocalAgentDiagnostics.Snapshot
    @State private var capabilityCeiling: CapabilityCeilingHealthSnapshot
    @State private var refreshTask: Task<Void, Never>?
    @State private var gemmaActionStatus: String?
    @State private var selectedGemmaArtifact: GemmaQATLocalArtifactSelection?

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
            SubstrateHealthMetricLine(
                label: "Gemma proof lane",
                symbol: "checklist.unchecked",
                state: capabilityCeiling.gemmaProofState,
                detail: capabilityCeiling.gemmaProofDetail
            )
            SubstrateHealthMetricLine(
                label: "System G / 70B preservation",
                symbol: "archivebox",
                state: capabilityCeiling.largeRuntimePreservationState,
                detail: capabilityCeiling.largeRuntimePreservationDetail
            )
            gemmaProofActionSurface
        }
    }

    @ViewBuilder
    private var gemmaProofActionSurface: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.trianglehead.branch")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 16, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Gemma action")
                        .font(.system(size: 11, weight: .semibold))
                    Text(gemmaNextActionDetail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Text(Self.gemmaRecommendedLaneSummary)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            gemmaRuntimeLadderSurface
            HStack(spacing: 8) {
                Button("Choose GGUF") {
                    chooseGemmaArtifact()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Open cutover plan") {
                    openProjectPath(Self.gemmaCutoverPlanPath)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Reveal tools") {
                    revealProjectPath(Self.gemmaFirstRuntimePathsPath)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Menu("Copy acquire command") {
                    ForEach(GemmaQATRuntimeLadder.candidates) { candidate in
                        Button("\(candidate.displayName)") {
                            copyGemmaAcquireCommand(for: candidate)
                        }
                    }
                }
                .menuStyle(.button)
                .controlSize(.small)

                Button("Copy receipt template") {
                    copyGemmaReceiptTemplate()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Copy replay command") {
                    copyGemmaQualityReplayCommand()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if let selectedGemmaArtifact {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedGemmaArtifact.summary)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(selectedGemmaArtifact.receiptReadinessSummary)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            if let gemmaActionStatus {
                Text(gemmaActionStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var gemmaRuntimeLadderSurface: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(GemmaQATRuntimeLadder.candidates) { candidate in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(gemmaStageTint(candidate.stage))
                        .frame(width: 7, height: 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(candidate.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                        Text("\(candidate.stage.displayName) · \(candidate.expectedByteCountLabel) · \(capabilityCeiling.gemmaLocalArtifactStatus(for: candidate)) · \(capabilityCeiling.gemmaProofStatus(for: candidate)) · \(candidate.routeIntegrationStatusLabel)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Text(candidate.runtimeLane)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.secondary.opacity(0.14), lineWidth: 0.75)
        }
    }

    private func gemmaStageTint(_ stage: GemmaQATRuntimeStage) -> Color {
        switch stage {
        case .firstRuntimeHarness:
            return .green
        case .nextScaleLane:
            return .orange
        case .proFlagshipCandidate:
            return .purple
        case .specialistCoderFineTune:
            return .blue
        case .reasoningSpecialist:
            return .teal
        case .moeFlagshipCandidate:
            return .pink
        case .liquidGeneralMoe:
            return .mint
        case .gemmaTwelveBLowMemory:
            return .indigo
        }
    }

    private var gemmaNextActionDetail: String {
        if capabilityCeiling.gemmaProductCapabilityRecheckPassed
            && capabilityCeiling.gemmaProductCapabilityLiveRouteIntegrationPendingBound {
            let lanes = capabilityCeiling.gemmaCompletedProofLaneSummary
            let laneDetail = lanes.isEmpty
                ? "E2B/E4B/12B QAT proof lanes"
                : lanes
            return "\(laneDetail) are visible through RuntimeRouter/System G packet evidence; next guard-owned gate: \(capabilityCeiling.gemmaProductRouteIntegrationCursor). Picker/default exposure stays locked."
        }
        if capabilityCeiling.gemmaSettingsDiagnosticsWrvPassed
            && capabilityCeiling.gemmaReleaseAuditEvidenceReady {
            let lanes = capabilityCeiling.gemmaCompletedProofLaneSummary
            let laneDetail = lanes.isEmpty
                ? "Gemma QAT proof lane"
                : lanes
            return "\(laneDetail) are through System G/WRV and release-audit evidence; final gates: \(capabilityCeiling.gemmaFinalReleaseGateDetail) before picker/default exposure."
        }
        if capabilityCeiling.gemmaSettingsDiagnosticsWrvPassed
            && capabilityCeiling.gemmaReleaseAuditAutomatedChecksReady {
            let lanes = capabilityCeiling.gemmaCompletedProofLaneSummary
            let laneDetail = lanes.isEmpty
                ? "Gemma QAT local proof"
                : lanes
            return "\(laneDetail) are through Settings/diagnostics WRV; finish log/manual/distribution evidence and three zero-fail release-audit passes before picker/default exposure."
        }
        if capabilityCeiling.gemmaReceiptMaterializerAvailable
            && capabilityCeiling.gemmaFirstRuntimeProbeAvailable {
            return "Owner-approved local E2B/E4B/12B QAT GGUF receipt is the next real gate; runtime probe stays locked until that digest-only receipt exists."
        }
        return "Gemma command ladder is incomplete; keep Gemma hidden from picker/default routes until the receipt and probe tools are available."
    }

    private func chooseGemmaArtifact() {
        let panel = NSOpenPanel()
        if let ggufType = UTType(filenameExtension: "gguf") {
            panel.allowedContentTypes = [ggufType]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose an owner-approved local Google Gemma 4 QAT Q4_0 GGUF."
        panel.prompt = "Choose GGUF"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            selectedGemmaArtifact = try GemmaQATLocalArtifactSelection(url: url)
            gemmaActionStatus = "Selected \(url.lastPathComponent); copy the receipt template after filling source revision."
        } catch {
            gemmaActionStatus = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func openProjectPath(_ path: String) {
        guard let url = projectURL(for: path) else {
            gemmaActionStatus = "Missing \(URL(fileURLWithPath: path).lastPathComponent)"
            return
        }
        NSWorkspace.shared.open(url)
        gemmaActionStatus = "Opened \(url.lastPathComponent)"
    }

    private func revealProjectPath(_ path: String) {
        guard let url = projectURL(for: path) else {
            gemmaActionStatus = "Missing \(URL(fileURLWithPath: path).lastPathComponent)"
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        gemmaActionStatus = "Revealed \(url.lastPathComponent)"
    }

    private func copyGemmaReceiptTemplate() {
        NSPasteboard.general.clearContents()
        let command = selectedGemmaArtifact?.receiptCommandTemplate
            ?? Self.gemmaReceiptCommandTemplate
        NSPasteboard.general.setString(command, forType: .string)
        gemmaActionStatus = selectedGemmaArtifact == nil
            ? "Copied owner receipt template; fill the placeholders before running."
            : "Copied receipt template with local path, filename, model ID, and byte count filled in."
    }

    private func copyGemmaAcquireCommand(for candidate: GemmaQATRuntimeCandidate? = nil) {
        NSPasteboard.general.clearContents()
        let resolvedCandidate = candidate ?? GemmaQATRuntimeLadder.firstRuntimeHarnessCandidate
        let command = resolvedCandidate.map(Self.gemmaAcquireCommandTemplate(for:))
            ?? Self.gemmaAcquireCommandTemplate
        NSPasteboard.general.setString(command, forType: .string)
        let label = resolvedCandidate?.displayName ?? "Gemma E2B QAT"
        gemmaActionStatus = "Copied official \(label) acquisition command; it verifies bytes before writing a receipt."
    }

    private func copyGemmaQualityReplayCommand() {
        NSPasteboard.general.clearContents()
        let command = selectedGemmaArtifact?.replayCommandTemplate
            ?? Self.gemmaQualityObservationReplayTemplate
        NSPasteboard.general.setString(
            command,
            forType: .string
        )
        gemmaActionStatus = selectedGemmaArtifact == nil
            ? "Copied quality observation replay command; set the lane and local path before running."
            : "Copied quality observation replay command with local path and lane filled in."
    }

    private func projectURL(for path: String) -> URL? {
        let urls = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(path),
            Bundle.main.resourceURL?
                .appendingPathComponent("SourceMirror")
                .appendingPathComponent(path)
        ].compactMap { $0 }
        return urls.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

private struct GemmaQATLocalArtifactSelection: Equatable {
    let url: URL
    let byteCount: UInt64
    let candidate: GemmaQATRuntimeCandidate?

    init(url: URL, fileManager: FileManager = .default) throws {
        let standardizedURL = url.standardizedFileURL
        guard standardizedURL.pathExtension.caseInsensitiveCompare("gguf") == .orderedSame else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let values = try standardizedURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            throw CocoaError(.fileReadUnknown)
        }
        let attributes = try fileManager.attributesOfItem(atPath: standardizedURL.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw CocoaError(.fileReadUnknown)
        }

        self.url = standardizedURL
        self.byteCount = size.uint64Value
        self.candidate = GemmaQATRuntimeLadder.candidate(forFilename: standardizedURL.lastPathComponent)
    }

    var summary: String {
        "\(candidate?.displayName ?? "Unclassified Gemma GGUF") · \(byteCountLabel) · \(url.lastPathComponent)"
    }

    var receiptReadinessSummary: String {
        guard let candidate else {
            return "Filename did not clearly match E2B, E4B, or 12B; verify the official Google repo ID before materializing the receipt."
        }
        if url.lastPathComponent != candidate.expectedFilename || byteCount != UInt64(candidate.expectedFileBytes) {
            return "\(candidate.sourceRepo) detected, but official filename/byte-count does not match; the receipt command will fail closed unless the local artifact is corrected."
        }
        return "\(candidate.sourceRepo) matched official filename and byte count. Only the owner approval phrase must be filled before the materializer runs."
    }

    var receiptCommandTemplate: String {
        let selectedModelID = candidate?.sourceRepo ?? "<one official google/gemma-4-*-it-qat-q4_0-gguf repo id>"
        let sourceRevision = candidate?.sourceRevision ?? "<source revision>"
        let expectedFilename = candidate?.expectedFilename ?? url.lastPathComponent
        let expectedByteCount = UInt64(candidate?.expectedFileBytes ?? Int64(clamping: byteCount))
        let expectedLfsSHA = candidate?.expectedSHA256 ?? "<source lfs sha256>"
        let proofLane = candidate?.acquisitionLaneArgument ?? "<e2b | e4b | 12b>"
        return """
        # Official Google Gemma 4 QAT Q4_0 GGUF receipt.
        # This only hashes/verifies the local file; it does not execute Gemma.
        # Expected LFS SHA256: \(expectedLfsSHA)
        export EPI_GEMMA_OWNER_APPROVAL_PHRASE="<owner approval phrase>"
        export EPI_GEMMA_PROOF_LANE=\(Self.shellExportValue(proofLane))
        export EPI_GEMMA_LOCAL_MODEL_PATH=\(Self.shellExportValue(url.path))
        export EPI_GEMMA_SELECTED_MODEL_ID=\(Self.shellExportValue(selectedModelID))
        export EPI_GEMMA_SOURCE_REPO=\(Self.shellExportValue(selectedModelID))
        export EPI_GEMMA_EXPECTED_FILENAME=\(Self.shellExportValue(expectedFilename))
        export EPI_GEMMA_EXPECTED_BYTE_COUNT="\(expectedByteCount)"
        export EPI_GEMMA_EXPECTED_LFS_SHA256=\(Self.shellExportValue(expectedLfsSHA))
        export EPI_GEMMA_SOURCE_REVISION=\(Self.shellExportValue(sourceRevision))
        export EPI_GEMMA_SOURCE_LICENSE_REF="apache-2.0"
        export EPI_GEMMA_LLAMA_CLI="/opt/homebrew/bin/llama-cli"
        Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh
        """
    }

    var replayCommandTemplate: String {
        let proofLane = candidate?.acquisitionLaneArgument ?? "<e2b | e4b | 12b>"
        return """
        # Run seven tiny Gemma QAT quality observations and score them digest-only.
        # Raw candidate outputs are kept in a temporary file and deleted after replay.
        export EPI_GEMMA_PROOF_LANE=\(Self.shellExportValue(proofLane))
        export EPI_GEMMA_LOCAL_MODEL_PATH=\(Self.shellExportValue(url.path))
        export EPI_GEMMA_LLAMA_CLI="/opt/homebrew/bin/llama-cli"
        Tools/falsifiers/run_gemma_first_runtime_quality_observation_replay.sh
        """
    }

    private var byteCountLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: byteCount), countStyle: .file)
    }

    private static func shellExportValue(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
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

    let gemmaArtifactFound: Bool
    let gemmaReceiptContractPass: Bool
    let gemmaNextCursor: String
    let gemmaOwnerApprovalRequired: Bool
    let gemmaOwnerApprovalGrantedCount: Int
    let gemmaReceiptFixturePresentCount: Int
    let gemmaRuntimeActionCount: Int
    let gemmaRouteMutationCount: Int
    let gemmaSettingsDiagnosticsWrvFound: Bool
    let gemmaSettingsDiagnosticsWrvPassed: Bool
    let gemmaReleaseAuditAutomatedChecksReady: Bool
    let gemmaReleaseAuditAutomatedChecksPassed: Bool
    let gemmaReleaseAuditLogEvidencePassed: Bool
    let gemmaManualRuntimeVerificationPassed: Bool
    let gemmaCapabilityCloseoutPassed: Bool
    let gemmaDistributionFocusedEvidencePassed: Bool
    let gemmaDistributionComplianceReviewPassed: Bool
    let gemmaDistributionProjectIntegritySourceCardPassed: Bool
    let gemmaDistributionProjectIntegrityIssueCount: Int
    let gemmaDistributionComplianceNotClaimed: Bool
    let gemmaReleaseAuditZeroFailLedgerPassed: Bool
    let gemmaReleaseAuditZeroFailPassCount: Int
    let gemmaProductCapabilityRecheckFound: Bool
    let gemmaProductCapabilityRecheckPassed: Bool
    let gemmaProductCapabilityRecheckCursor: String
    let gemmaProductCapabilityLiveRouteIntegrationPendingBound: Bool
    let gemmaSelectedModelID: String
    let gemmaReceiptMaterializedModelID: String
    let gemmaFirstRuntimeExecutionModelID: String
    let gemmaQualityReplayModelID: String
    let gemmaRuntimeRouterAdmissionModelID: String
    let gemmaSystemGDryRunModelID: String
    let gemmaRouteVisibilityModelID: String
    let gemmaSettingsDiagnosticsWrvModelID: String
    let gemmaLocalArtifactStatusByID: [String: String]
    let gemmaLaneProofStatusByID: [String: String]
    let gemmaLiveClaim: Bool
    let gemmaT4Claim: Bool
    let gemmaReceiptMaterializerAvailable: Bool
    let gemmaFirstRuntimeProbeAvailable: Bool
    let gemmaQualityPacketMaterializerAvailable: Bool
    let gemmaQualityReplayExecutionAvailable: Bool
    let gemmaRuntimeRouterAdmissionMaterializerAvailable: Bool
    let gemmaSystemGDryRunRouteMaterializerAvailable: Bool
    let gemmaRouteAnswerPacketVisibilityMaterializerAvailable: Bool
    let gemmaSettingsDiagnosticsWrvMaterializerAvailable: Bool

    static let capabilityArtifactPath = "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json"
    static let kvArtifactPath = "artifacts/falsifiers/kv_direct_gate/result.json"
    static let contextInventoryPath = "docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json"
    static let pendingWorkArtifactPath = "artifacts/falsifiers/architecture_pending_work_guard/result.json"
    static let worktreeInventoryPath = "docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json"
    static let ggufArtifactPath = "artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json"
    static let gemmaArtifactPath = "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_probe/result.json"
    static let gemmaReceiptMaterializedArtifactPath = "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_materializer/receipt.redacted.json"
    static let gemmaFirstRuntimeExecutionArtifactPath = "artifacts/falsifiers/gemma_direct_harness_first_runtime_execution_probe/receipt.redacted.json"
    static let gemmaQualityReplayArtifactPath = "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_replay/result.redacted.json"
    static let gemmaRuntimeRouterAdmissionArtifactPath = "artifacts/falsifiers/gemma_direct_harness_first_runtime_runtime_router_admission/admission.redacted.json"
    static let gemmaSystemGDryRunArtifactPath = "artifacts/falsifiers/gemma_direct_harness_first_runtime_system_g_dry_run_route/system_g_dry_run.redacted.json"
    static let gemmaRouteVisibilityArtifactPath = "artifacts/falsifiers/gemma_direct_harness_first_runtime_route_answer_packet_visibility/visibility.redacted.json"
    static let gemmaSettingsDiagnosticsWrvArtifactPath = "artifacts/falsifiers/gemma_direct_harness_first_runtime_settings_diagnostics_wrv/wrv.redacted.json"
    static let gemmaReleaseAuditAutomatedChecksCursor = "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe"
    static let gemmaReleaseAuditAutomatedChecksArtifactPath = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json"
    static let gemmaReleaseAuditLogEvidenceArtifactPath = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe/result.json"
    static let gemmaManualRuntimeVerificationArtifactPath = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe/result.json"
    static let gemmaCapabilityCloseoutArtifactPath = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_capability_closeout_probe/result.json"
    static let gemmaDistributionFocusedEvidenceArtifactPath = "artifacts/falsifiers/release_audit_distribution_focused_evidence/result.json"
    static let gemmaDistributionComplianceReviewArtifactPath = "artifacts/falsifiers/release_audit_distribution_compliance_review/result.json"
    static let gemmaDistributionProjectIntegrityArtifactPath = "artifacts/falsifiers/distribution_project_integrity_release_blocker_card/result.json"
    static let gemmaReleaseAuditZeroFailLedgerArtifactPath = "artifacts/falsifiers/release_audit_zero_fail_pass_ledger/result.json"
    static let gemmaReleaseAuditZeroFailArtifactPath = "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe/result.json"
    static let gemmaProductCapabilityRecheckArtifactPath = "artifacts/falsifiers/gemma_qat_e2b_product_capability_recheck_gate/result.json"
    static let gemmaReceiptMaterializerPath = "Tools/falsifiers/materialize_gemma_owner_approved_local_artifact_receipt.sh"
    static let gemmaFirstRuntimeProbePath = "Tools/falsifiers/run_gemma_first_runtime_execution_probe.sh"
    static let gemmaQualityPacketMaterializerPath = "Tools/falsifiers/materialize_gemma_first_runtime_quality_packet.sh"
    static let gemmaQualityReplayExecutionPath = "Tools/falsifiers/execute_gemma_first_runtime_quality_replay.sh"
    static let gemmaRuntimeRouterAdmissionMaterializerPath = "Tools/falsifiers/materialize_gemma_first_runtime_runtime_router_admission_packet.sh"
    static let gemmaSystemGDryRunRouteMaterializerPath = "Tools/falsifiers/materialize_gemma_first_runtime_system_g_dry_run_route_packet.sh"
    static let gemmaRouteAnswerPacketVisibilityMaterializerPath = "Tools/falsifiers/materialize_gemma_first_runtime_route_answer_packet_visibility.sh"
    static let gemmaSettingsDiagnosticsWrvMaterializerPath = "Tools/falsifiers/materialize_gemma_first_runtime_settings_diagnostics_wrv.sh"

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
            ? "deferred candidate pass; still separate from canonical MLX KV-Direct"
            : "deferred candidate · opt-in only · \(ggufNextBottleneck)"
    }

    @MainActor
    var gemmaProofState: SubstrateHealthSignalState {
        guard gemmaArtifactFound else { return .unavailable }
        if gemmaSettingsDiagnosticsWrvFound {
            guard gemmaSettingsDiagnosticsWrvPassed else { return .blocked }
            guard !gemmaLiveClaim, !gemmaT4Claim, gemmaRouteMutationCount == 0 else {
                return .blocked
            }
            return .partial
        }
        guard gemmaReceiptContractPass else { return .blocked }
        return gemmaOwnerApprovalGrantedCount == 0
            && gemmaReceiptFixturePresentCount == 0
            && gemmaRuntimeActionCount == 0
            && gemmaRouteMutationCount == 0
            && gemmaReceiptMaterializerAvailable
            && gemmaFirstRuntimeProbeAvailable
            && gemmaQualityPacketMaterializerAvailable
            && gemmaQualityReplayExecutionAvailable
            && gemmaRuntimeRouterAdmissionMaterializerAvailable
            && gemmaSystemGDryRunRouteMaterializerAvailable
            && gemmaRouteAnswerPacketVisibilityMaterializerAvailable
            && gemmaSettingsDiagnosticsWrvMaterializerAvailable
            ? .partial
            : .blocked
    }

    var gemmaProofDetail: String {
        guard gemmaArtifactFound else {
            return "missing \(Self.gemmaSettingsDiagnosticsWrvArtifactPath) and \(Self.gemmaArtifactPath)"
        }
        if gemmaSettingsDiagnosticsWrvFound {
            let laneSummary = gemmaCompletedProofLaneSummary.isEmpty
                ? (gemmaSelectedModelID.isEmpty ? "unknown Gemma lane" : gemmaSelectedModelID)
                : gemmaCompletedProofLaneSummary
            let wrv = gemmaAllQATProofLanesWRVReady
                ? "all QAT lanes WRV passed"
                : gemmaSettingsDiagnosticsWrvPassed ? "WRV passed" : "WRV red"
            let release = gemmaReleaseAuditProgressDetail
            let claimStatus = (!gemmaLiveClaim && !gemmaT4Claim && gemmaRouteMutationCount == 0)
                ? "no live/default/T4 claim"
                : "claim/mutation guard red"
            return "\(laneSummary) · \(wrv) · \(release) · \(gemmaProductRouteIntegrationDetail) · \(claimStatus) · next=\(gemmaProductRouteIntegrationCursor)"
        }
        let approval = gemmaOwnerApprovalRequired ? "owner receipt missing" : "owner receipt policy missing"
        let materializer = gemmaReceiptMaterializerAvailable ? "materializer ready" : "materializer missing"
        let runtimeProbe = gemmaFirstRuntimeProbeAvailable ? "runtime probe ready" : "runtime probe missing"
        let qualityBridge = gemmaQualityPacketMaterializerAvailable ? "quality bridge ready" : "quality bridge missing"
        let replayGate = gemmaQualityReplayExecutionAvailable ? "replay scorer ready" : "replay scorer missing"
        let admissionBridge = gemmaRuntimeRouterAdmissionMaterializerAvailable ? "admission packet ready" : "admission packet missing"
        let systemGBridge = gemmaSystemGDryRunRouteMaterializerAvailable ? "System G dry-run packet ready" : "System G dry-run packet missing"
        let visibilityBridge = gemmaRouteAnswerPacketVisibilityMaterializerAvailable ? "route visibility ready" : "route visibility missing"
        let settingsWrvBridge = gemmaSettingsDiagnosticsWrvMaterializerAvailable ? "settings WRV ready" : "settings WRV missing"
        return "\(approval) · \(materializer) · \(runtimeProbe) · \(qualityBridge) · \(replayGate) · \(admissionBridge) · \(systemGBridge) · \(visibilityBridge) · \(settingsWrvBridge) · next=\(gemmaNextCursor)"
    }

    var gemmaReleaseAuditProgressDetail: String {
        let automated = (gemmaReleaseAuditAutomatedChecksReady || gemmaReleaseAuditAutomatedChecksPassed)
            ? "automated ready"
            : "automated pending"
        let logs = gemmaReleaseAuditLogEvidencePassed ? "logs ready" : "logs pending"
        let manual = gemmaManualRuntimeVerificationPassed ? "manual ready" : "manual pending"
        let closeout = gemmaCapabilityCloseoutPassed ? "closeout ready" : "closeout pending"
        let final = gemmaReleaseAuditEvidenceReady
            ? "final blockers: \(gemmaFinalReleaseGateDetail)"
            : "release-audit evidence still incomplete"
        return "\(automated), \(logs), \(manual), \(closeout); \(final)"
    }

    var gemmaFinalReleaseGateDetail: String {
        let distribution = gemmaDistributionFocusedEvidencePassed
            ? "distribution focused checks passed (\(gemmaDistributionProjectIntegrityIssueCount) source-card issues retained)"
            : gemmaDistributionProjectIntegritySourceCardPassed
            ? "distribution source-card bound (\(gemmaDistributionProjectIntegrityIssueCount) retained issues)"
            : "distribution source-card missing"
        let compliance = gemmaDistributionComplianceNotClaimed
            ? "distribution/compliance review not complete"
            : gemmaDistributionComplianceReviewPassed
            ? "distribution compliance reviewed"
            : "distribution/compliance claim needs audit"
        let zeroFail = gemmaReleaseAuditZeroFailLedgerPassed
            ? "zero-fail \(gemmaReleaseAuditZeroFailPassCount)/3 counted"
            : "zero-fail \(gemmaReleaseAuditZeroFailPassCount)/3"
        return "\(distribution); \(compliance); \(zeroFail)"
    }

    var gemmaReleaseAuditEvidenceReady: Bool {
        (gemmaReleaseAuditAutomatedChecksReady || gemmaReleaseAuditAutomatedChecksPassed)
            && gemmaReleaseAuditLogEvidencePassed
            && gemmaManualRuntimeVerificationPassed
            && gemmaCapabilityCloseoutPassed
    }

    var gemmaProductRouteIntegrationCursor: String {
        if gemmaProductCapabilityRecheckPassed,
           !gemmaProductCapabilityRecheckCursor.isEmpty {
            return gemmaProductCapabilityRecheckCursor
        }
        return GemmaQATRuntimeLadder.productRouteIntegrationCursor
    }

    var gemmaProductRouteIntegrationDetail: String {
        guard gemmaProductCapabilityRecheckFound else {
            return "product recheck missing"
        }
        guard gemmaProductCapabilityRecheckPassed else {
            return "product recheck red"
        }
        let candidateSummary = gemmaProductRouteIntegrationCandidateSummary
        return gemmaProductCapabilityLiveRouteIntegrationPendingBound
            ? "\(candidateSummary); product recheck green; live route integration pending"
            : "product recheck guard red"
    }

    var gemmaProductRouteIntegrationCandidateSummary: String {
        let candidates = GemmaQATRuntimeLadder.productRouteIntegrationCandidates
        guard !candidates.isEmpty else {
            return "no QAT route-integration candidates"
        }
        let names = candidates.map(\.displayName).joined(separator: ", ")
        return "\(candidates.count)/\(GemmaQATRuntimeLadder.candidates.count) QAT route-integration candidates: \(names)"
    }

    var gemmaCompletedProofLaneSummary: String {
        let readyLanes = GemmaQATRuntimeLadder.candidates.compactMap { candidate -> String? in
            let status = gemmaProofStatus(for: candidate)
            return status.contains("WRV + release evidence")
                || status.contains("WRV ready")
                ? candidate.displayName
                : nil
        }
        guard !readyLanes.isEmpty else { return "" }
        return "\(readyLanes.count)/\(GemmaQATRuntimeLadder.candidates.count) QAT lanes ready: \(readyLanes.joined(separator: ", "))"
    }

    var gemmaAllQATProofLanesWRVReady: Bool {
        GemmaQATRuntimeLadder.candidates.allSatisfy { candidate in
            let status = gemmaProofStatus(for: candidate)
            return status.contains("WRV + release evidence")
                || status.contains("WRV ready")
        }
    }

    func gemmaProofStatus(for candidate: GemmaQATRuntimeCandidate) -> String {
        let id = candidate.id
        if gemmaSettingsDiagnosticsWrvPassed && gemmaSettingsDiagnosticsWrvModelID == id {
            return gemmaReleaseAuditEvidenceReady
                ? "WRV + release evidence; final gates"
                : "WRV ready; release evidence pending"
        }
        if let laneStatus = gemmaLaneProofStatusByID[id] {
            return laneStatus
        }
        if gemmaRouteVisibilityModelID == id {
            return "route visibility packet ready"
        }
        if gemmaSystemGDryRunModelID == id {
            return "System G dry-run packet ready"
        }
        if gemmaRuntimeRouterAdmissionModelID == id {
            return "RuntimeRouter admission packet ready"
        }
        if gemmaQualityReplayModelID == id {
            return "quality replay ready"
        }
        if gemmaFirstRuntimeExecutionModelID == id {
            return "first-token receipt ready"
        }
        if gemmaReceiptMaterializedModelID == id {
            return "receipt materialized; runtime pending"
        }

        switch candidate.stage {
        case .firstRuntimeHarness:
            return "receipt/runtime proof pending"
        case .nextScaleLane:
            return "next receipt/runtime repeat"
        case .proFlagshipCandidate:
            return "Pro proof waits for E2B/E4B"
        case .specialistCoderFineTune:
            return "specialist receipt/runtime pending"
        case .reasoningSpecialist:
            return "reasoning receipt/runtime pending"
        case .moeFlagshipCandidate:
            return "MoE receipt/runtime pending"
        case .liquidGeneralMoe:
            return "Liquid receipt/runtime pending"
        case .gemmaTwelveBLowMemory:
            return "Gemma 12B low-mem receipt/runtime pending"
        }
    }

    func gemmaLocalArtifactStatus(for candidate: GemmaQATRuntimeCandidate) -> String {
        gemmaLocalArtifactStatusByID[candidate.id] ?? "local GGUF missing"
    }

    @MainActor
    var largeRuntimePreservationState: SubstrateHealthSignalState {
        guard gemmaArtifactFound || pendingGuardFound || capabilityArtifactFound else { return .unavailable }
        return .partial
    }

    var largeRuntimePreservationDetail: String {
        "Gemma-first proof lane is the near-term bridge; System G, code assembly, and 70B cold assembly remain Pro Research/Vault."
    }

    static func load() -> Self {
        let capability = readJSONObject(path: capabilityArtifactPath)
        let kv = readJSONObject(path: kvArtifactPath)
        let contextInventory = readJSONObject(path: contextInventoryPath)
        let pending = readJSONObject(path: pendingWorkArtifactPath)
        let worktreeInventory = readJSONObject(path: worktreeInventoryPath)
        let gguf = readJSONObject(path: ggufArtifactPath)
        let gemma = readJSONObject(path: gemmaArtifactPath)
        let gemmaReceiptMaterialized = readJSONObject(path: gemmaReceiptMaterializedArtifactPath)
        let gemmaFirstRuntimeExecution = readJSONObject(path: gemmaFirstRuntimeExecutionArtifactPath)
        let gemmaQualityReplay = readJSONObject(path: gemmaQualityReplayArtifactPath)
        let gemmaRuntimeRouterAdmission = readJSONObject(path: gemmaRuntimeRouterAdmissionArtifactPath)
        let gemmaSystemGDryRun = readJSONObject(path: gemmaSystemGDryRunArtifactPath)
        let gemmaRouteVisibility = readJSONObject(path: gemmaRouteVisibilityArtifactPath)
        let gemmaWrv = readJSONObject(path: gemmaSettingsDiagnosticsWrvArtifactPath)
        let gemmaAutomatedChecks = readJSONObject(path: gemmaReleaseAuditAutomatedChecksArtifactPath)
        let gemmaLogEvidence = readJSONObject(path: gemmaReleaseAuditLogEvidenceArtifactPath)
        let gemmaManualRuntime = readJSONObject(path: gemmaManualRuntimeVerificationArtifactPath)
        let gemmaCapabilityCloseout = readJSONObject(path: gemmaCapabilityCloseoutArtifactPath)
        let gemmaDistributionFocusedEvidence = readJSONObject(
            path: gemmaDistributionFocusedEvidenceArtifactPath
        )
        let gemmaDistributionComplianceReview = readJSONObject(
            path: gemmaDistributionComplianceReviewArtifactPath
        )
        let gemmaDistributionProjectIntegrity = readJSONObject(path: gemmaDistributionProjectIntegrityArtifactPath)
        let gemmaReleaseAuditZeroFailLedger = readJSONObject(
            path: gemmaReleaseAuditZeroFailLedgerArtifactPath
        )
        let gemmaReleaseAuditZeroFail = readJSONObject(path: gemmaReleaseAuditZeroFailArtifactPath)
        let gemmaProductCapabilityRecheck = readJSONObject(path: gemmaProductCapabilityRecheckArtifactPath)
        let gemmaDistributionComplianceReviewPassed = topLevelBool(
            gemmaDistributionComplianceReview,
            key: "overall_pass"
        )
        let contextSummary = contextInventory?["summary"] as? [String: Any]
        let worktreeSummary = worktreeInventory?["summary"] as? [String: Any]
        let gemmaStatus = gemmaWrv ?? gemma
        let releaseEvidenceReady = (topLevelBool(gemmaWrv, key: "release_audit_automated_checks_ready")
            || topLevelBool(gemmaAutomatedChecks, key: "overall_pass"))
            && topLevelBool(gemmaLogEvidence, key: "overall_pass")
            && topLevelBool(gemmaManualRuntime, key: "overall_pass")
            && topLevelBool(gemmaCapabilityCloseout, key: "overall_pass")
        let gemmaLaneProofStatusByID = Dictionary(
            uniqueKeysWithValues: GemmaQATRuntimeLadder.candidates.map { candidate in
                (
                    candidate.id,
                    gemmaLaneProofStatus(
                        for: candidate,
                        releaseEvidenceReady: releaseEvidenceReady
                    )
                )
            }
        )
        let gemmaLocalArtifactStatusByID = Dictionary(
            uniqueKeysWithValues: GemmaQATRuntimeLadder.candidates.map { candidate in
                (candidate.id, gemmaLocalArtifactStatus(for: candidate))
            }
        )

        return CapabilityCeilingHealthSnapshot(
            capabilityArtifactFound: capability != nil,
            capabilityOverallPass: topLevelBool(capability, key: "overall_pass"),
            routeStatus: measurementString(capability, key: "route_status", default: "unknown route"),
            nextBottleneck: measurementString(
                capability,
                key: "next_bottleneck",
                default: "missing_fp16_or_provider_reference"
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
                default: "missing_fp16_or_provider_reference"
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
            ggufNextBottleneck: ggufNextBottleneck(gguf),
            gemmaArtifactFound: gemmaStatus != nil,
            gemmaReceiptContractPass: topLevelBool(gemma, key: "overall_pass"),
            gemmaNextCursor: measurementString(
                gemmaStatus,
                key: "next_cursor",
                default: topLevelString(
                    gemmaStatus,
                    key: "next_cursor",
                    default: gemmaWrv == nil
                        ? "gemma_direct_harness_owner_approved_first_runtime_execution_probe"
                        : gemmaReleaseAuditAutomatedChecksCursor
                )
            ),
            gemmaOwnerApprovalRequired: measurementBool(
                gemma,
                key: "owner_approval_required_but_absent"
            ) || measurementInt(gemma, key: "owner_approval_required_count") > 0,
            gemmaOwnerApprovalGrantedCount: measurementInt(
                gemma,
                key: "owner_approval_granted_count"
            ),
            gemmaReceiptFixturePresentCount: measurementInt(
                gemma,
                key: "receipt_fixture_present_count"
            ),
            gemmaRuntimeActionCount: gemmaRuntimeActionCount(gemmaWrv: gemmaWrv, legacyProbe: gemma),
            gemmaRouteMutationCount: gemmaRouteMutationCount(gemmaWrv: gemmaWrv, legacyProbe: gemma),
            gemmaSettingsDiagnosticsWrvFound: gemmaWrv != nil,
            gemmaSettingsDiagnosticsWrvPassed: topLevelBool(
                gemmaWrv,
                key: "settings_diagnostics_wrv_passed"
            ),
            gemmaReleaseAuditAutomatedChecksReady: topLevelBool(
                gemmaWrv,
                key: "release_audit_automated_checks_ready"
            ),
            gemmaReleaseAuditAutomatedChecksPassed: topLevelBool(
                gemmaAutomatedChecks,
                key: "overall_pass"
            ),
            gemmaReleaseAuditLogEvidencePassed: topLevelBool(
                gemmaLogEvidence,
                key: "overall_pass"
            ),
            gemmaManualRuntimeVerificationPassed: topLevelBool(
                gemmaManualRuntime,
                key: "overall_pass"
            ),
            gemmaCapabilityCloseoutPassed: topLevelBool(
                gemmaCapabilityCloseout,
                key: "overall_pass"
            ),
            gemmaDistributionFocusedEvidencePassed: topLevelBool(
                gemmaDistributionFocusedEvidence,
                key: "overall_pass"
            ),
            gemmaDistributionComplianceReviewPassed: gemmaDistributionComplianceReviewPassed,
            gemmaDistributionProjectIntegritySourceCardPassed: topLevelBool(
                gemmaDistributionProjectIntegrity,
                key: "overall_pass"
            ),
            gemmaDistributionProjectIntegrityIssueCount: Self.distributionIssueCount(
                gemmaDistributionProjectIntegrity
            ),
            gemmaDistributionComplianceNotClaimed: !gemmaDistributionComplianceReviewPassed
                && (measurementBool(
                    gemmaReleaseAuditZeroFailLedger,
                    key: "distribution_compliance_not_claimed"
                ) || measurementBool(
                    gemmaReleaseAuditZeroFail,
                    key: "distribution_compliance_not_claimed"
                ) || measurementBool(
                    gemmaAutomatedChecks,
                    key: "distribution_compliance_not_claimed"
                )
            ),
            gemmaReleaseAuditZeroFailLedgerPassed: topLevelBool(
                gemmaReleaseAuditZeroFailLedger,
                key: "overall_pass"
            ),
            gemmaReleaseAuditZeroFailPassCount: measurementInt(
                gemmaReleaseAuditZeroFailLedger ?? gemmaReleaseAuditZeroFail,
                key: "zero_fail_pass_count"
            ),
            gemmaProductCapabilityRecheckFound: gemmaProductCapabilityRecheck != nil,
            gemmaProductCapabilityRecheckPassed: topLevelBool(
                gemmaProductCapabilityRecheck,
                key: "overall_pass"
            ),
            gemmaProductCapabilityRecheckCursor: measurementString(
                gemmaProductCapabilityRecheck,
                key: "next_cursor",
                default: ""
            ),
            gemmaProductCapabilityLiveRouteIntegrationPendingBound: measurementBool(
                gemmaProductCapabilityRecheck,
                key: "live_route_integration_pending_bound"
            ),
            gemmaSelectedModelID: topLevelString(
                gemmaWrv,
                key: "selected_model_id",
                default: ""
            ),
            gemmaReceiptMaterializedModelID: topLevelString(
                gemmaReceiptMaterialized,
                key: "selected_model_id",
                default: ""
            ),
            gemmaFirstRuntimeExecutionModelID: topLevelString(
                gemmaFirstRuntimeExecution,
                key: "selected_model_id",
                default: ""
            ),
            gemmaQualityReplayModelID: topLevelString(
                gemmaQualityReplay,
                key: "selected_model_id",
                default: ""
            ),
            gemmaRuntimeRouterAdmissionModelID: topLevelString(
                gemmaRuntimeRouterAdmission,
                key: "selected_model_id",
                default: ""
            ),
            gemmaSystemGDryRunModelID: topLevelString(
                gemmaSystemGDryRun,
                key: "selected_model_id",
                default: ""
            ),
            gemmaRouteVisibilityModelID: topLevelString(
                gemmaRouteVisibility,
                key: "selected_model_id",
                default: ""
            ),
            gemmaSettingsDiagnosticsWrvModelID: topLevelString(
                gemmaWrv,
                key: "selected_model_id",
                default: ""
            ),
            gemmaLocalArtifactStatusByID: gemmaLocalArtifactStatusByID,
            gemmaLaneProofStatusByID: gemmaLaneProofStatusByID,
            gemmaLiveClaim: topLevelBool(gemmaWrv, key: "live_gemma_claim"),
            gemmaT4Claim: topLevelBool(gemmaWrv, key: "l2_l3_t4_claim"),
            gemmaReceiptMaterializerAvailable: firstExistingURL(
                for: gemmaReceiptMaterializerPath
            ) != nil,
            gemmaFirstRuntimeProbeAvailable: firstExistingURL(
                for: gemmaFirstRuntimeProbePath
            ) != nil,
            gemmaQualityPacketMaterializerAvailable: firstExistingURL(
                for: gemmaQualityPacketMaterializerPath
            ) != nil,
            gemmaQualityReplayExecutionAvailable: firstExistingURL(
                for: gemmaQualityReplayExecutionPath
            ) != nil,
            gemmaRuntimeRouterAdmissionMaterializerAvailable: firstExistingURL(
                for: gemmaRuntimeRouterAdmissionMaterializerPath
            ) != nil,
            gemmaSystemGDryRunRouteMaterializerAvailable: firstExistingURL(
                for: gemmaSystemGDryRunRouteMaterializerPath
            ) != nil,
            gemmaRouteAnswerPacketVisibilityMaterializerAvailable: firstExistingURL(
                for: gemmaRouteAnswerPacketVisibilityMaterializerPath
            ) != nil,
            gemmaSettingsDiagnosticsWrvMaterializerAvailable: firstExistingURL(
                for: gemmaSettingsDiagnosticsWrvMaterializerPath
            ) != nil
        )
    }

    private static func gemmaRuntimeActionCount(
        gemmaWrv: [String: Any]?,
        legacyProbe: [String: Any]?
    ) -> Int {
        if let gemmaWrv {
            return jsonInt(gemmaWrv, key: "command_executed_count")
                + jsonInt(gemmaWrv, key: "process_spawned_count")
                + jsonInt(gemmaWrv, key: "runtime_replay_performed_count")
        }
        return measurementInt(legacyProbe, key: "runtime_action_count")
    }

    private static func gemmaRouteMutationCount(
        gemmaWrv: [String: Any]?,
        legacyProbe: [String: Any]?
    ) -> Int {
        if let gemmaWrv {
            return jsonInt(gemmaWrv, key: "route_priority_mutation_count")
                + jsonInt(gemmaWrv, key: "runtime_router_mutation_count")
                + jsonInt(gemmaWrv, key: "system_g_mutation_count")
                + jsonInt(gemmaWrv, key: "default_model_mutation_count")
        }
        return measurementInt(legacyProbe, key: "route_mutation_count")
    }

    private static func gemmaLaneProofStatus(
        for candidate: GemmaQATRuntimeCandidate,
        releaseEvidenceReady: Bool
    ) -> String {
        let receipt = readJSONObject(path: gemmaLaneArtifactPath(
            folder: "artifacts/falsifiers/gemma_owner_approved_local_artifact_receipt_materializer",
            file: "receipt.redacted.json",
            candidate: candidate
        ))
        let firstRuntime = readJSONObject(path: gemmaLaneArtifactPath(
            folder: "artifacts/falsifiers/gemma_direct_harness_first_runtime_execution_probe",
            file: "receipt.redacted.json",
            candidate: candidate
        ))
        let qualityReplay = readJSONObject(path: gemmaLaneArtifactPath(
            folder: "artifacts/falsifiers/gemma_direct_harness_first_runtime_quality_replay",
            file: "result.redacted.json",
            candidate: candidate
        ))
        let runtimeRouterAdmission = readJSONObject(path: gemmaLaneArtifactPath(
            folder: "artifacts/falsifiers/gemma_direct_harness_first_runtime_runtime_router_admission",
            file: "admission.redacted.json",
            candidate: candidate
        ))
        let systemGDryRun = readJSONObject(path: gemmaLaneArtifactPath(
            folder: "artifacts/falsifiers/gemma_direct_harness_first_runtime_system_g_dry_run_route",
            file: "system_g_dry_run.redacted.json",
            candidate: candidate
        ))
        let routeVisibility = readJSONObject(path: gemmaLaneArtifactPath(
            folder: "artifacts/falsifiers/gemma_direct_harness_first_runtime_route_answer_packet_visibility",
            file: "visibility.redacted.json",
            candidate: candidate
        ))
        let settingsWrv = readJSONObject(path: gemmaLaneArtifactPath(
            folder: "artifacts/falsifiers/gemma_direct_harness_first_runtime_settings_diagnostics_wrv",
            file: "wrv.redacted.json",
            candidate: candidate
        ))

        if topLevelString(settingsWrv, key: "selected_model_id", default: "") == candidate.id,
           topLevelBool(settingsWrv, key: "settings_diagnostics_wrv_passed") {
            return releaseEvidenceReady
                ? "WRV + release evidence; final gates"
                : "WRV ready; release evidence pending"
        }
        if topLevelString(routeVisibility, key: "selected_model_id", default: "") == candidate.id {
            return "route visibility packet ready"
        }
        if topLevelString(systemGDryRun, key: "selected_model_id", default: "") == candidate.id {
            return "System G dry-run packet ready"
        }
        if topLevelString(runtimeRouterAdmission, key: "selected_model_id", default: "") == candidate.id {
            return "RuntimeRouter admission packet ready"
        }
        if topLevelString(qualityReplay, key: "selected_model_id", default: "") == candidate.id {
            return "quality replay ready"
        }
        if topLevelString(firstRuntime, key: "selected_model_id", default: "") == candidate.id {
            return "first-token receipt ready"
        }
        if topLevelString(receipt, key: "selected_model_id", default: "") == candidate.id {
            return "receipt materialized; runtime pending"
        }

        switch candidate.stage {
        case .firstRuntimeHarness:
            return "receipt/runtime proof pending"
        case .nextScaleLane:
            return "next receipt/runtime repeat"
        case .proFlagshipCandidate:
            return "Pro proof waits for E2B/E4B"
        case .specialistCoderFineTune:
            return "specialist receipt/runtime pending"
        case .reasoningSpecialist:
            return "reasoning receipt/runtime pending"
        case .moeFlagshipCandidate:
            return "MoE receipt/runtime pending"
        case .liquidGeneralMoe:
            return "Liquid receipt/runtime pending"
        case .gemmaTwelveBLowMemory:
            return "Gemma 12B low-mem receipt/runtime pending"
        }
    }

    private static func gemmaLaneArtifactPath(
        folder: String,
        file: String,
        candidate: GemmaQATRuntimeCandidate
    ) -> String {
        if candidate.stage == .firstRuntimeHarness {
            return "\(folder)/\(file)"
        }
        return "\(folder)/\(candidate.acquisitionLaneArgument)/\(file)"
    }

    private static func gemmaLocalArtifactStatus(
        for candidate: GemmaQATRuntimeCandidate,
        fileManager: FileManager = .default
    ) -> String {
        let path = gemmaQuarantineArtifactPath(for: candidate)
        guard fileManager.fileExists(atPath: path) else {
            return "local GGUF missing"
        }
        guard
            let attributes = try? fileManager.attributesOfItem(atPath: path),
            let size = attributes[.size] as? NSNumber
        else {
            return "local GGUF unreadable"
        }
        let byteCount = size.int64Value
        guard byteCount == candidate.expectedFileBytes else {
            let actual = ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
            return "local GGUF byte-count mismatch \(actual)"
        }
        return "local GGUF present"
    }

    private static func gemmaQuarantineArtifactPath(for candidate: GemmaQATRuntimeCandidate) -> String {
        let repositoryFolder = candidate.sourceRepo.replacingOccurrences(of: "/", with: "--")
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Epistemos/ModelQuarantine/GemmaQAT")
            .appendingPathComponent(repositoryFolder)
            .appendingPathComponent(candidate.sourceRevision)
            .appendingPathComponent(candidate.expectedFilename)
            .path
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

    private static func distributionIssueCount(_ json: [String: Any]?) -> Int {
        guard
            let measurements = json?["measurements"] as? [String: Any],
            let envelope = measurements["distribution_project_integrity_card"] as? [String: Any],
            let value = envelope["value"] as? [String: Any]
        else {
            return 0
        }
        if let int = value["issue_count"] as? Int { return int }
        if let double = value["issue_count"] as? Double { return Int(double) }
        return 0
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
        var urls: [URL] = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(path)
        ]
        if let checkoutRootURL = sourceCheckoutRootURL() {
            urls.append(checkoutRootURL.appendingPathComponent(path))
        }
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent("SourceMirror").appendingPathComponent(path))
            if let checkoutRootURL = checkoutRootURL(startingAt: resourceURL) {
                urls.append(checkoutRootURL.appendingPathComponent(path))
            }
        }

        var seen = Set<String>()
        return urls.filter { url in
            seen.insert(url.standardizedFileURL.path).inserted
        }
    }

    private static func sourceCheckoutRootURL() -> URL? {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let starts = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            sourceFileURL.deletingLastPathComponent(),
            Bundle.main.resourceURL,
        ].compactMap { $0 }

        for startURL in starts {
            if let checkoutRootURL = checkoutRootURL(startingAt: startURL) {
                return checkoutRootURL
            }
        }
        return nil
    }

    private static func checkoutRootURL(startingAt startURL: URL) -> URL? {
        let fileManager = FileManager.default
        var cursor = startURL.standardizedFileURL
        for _ in 0..<12 {
            let agentsURL = cursor.appendingPathComponent("AGENTS.md")
            let projectURL = cursor.appendingPathComponent("Epistemos.xcodeproj")
            let masterIndexURL = cursor.appendingPathComponent("docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md")
            if fileManager.fileExists(atPath: agentsURL.path),
               fileManager.fileExists(atPath: projectURL.path),
               fileManager.fileExists(atPath: masterIndexURL.path) {
                return cursor
            }

            let parentURL = cursor.deletingLastPathComponent()
            guard parentURL.path != cursor.path else { break }
            cursor = parentURL
        }
        return nil
    }

    private static func topLevelBool(_ json: [String: Any]?, key: String) -> Bool {
        json?[key] as? Bool ?? false
    }

    private static func topLevelString(_ json: [String: Any]?, key: String, default defaultValue: String) -> String {
        json?[key] as? String ?? defaultValue
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
