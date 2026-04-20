import Foundation
import Observation
import OSLog

// MARK: - Skill Evolution Service

/// Service for analyzing session traces and proposing skill mutations via GEPA.
/// Reads both vault session traces and live harness JSONL traces so evolution
/// can operate on the data the app actually produces today.
@Observable
@MainActor
final class SkillEvolutionService {

    // MARK: - Properties

    private let vaultRegistry: VaultRegistry
    private let sessionBrowser: SessionBrowser

    /// Currently proposed mutations awaiting review
    var pendingProposals: [SkillMutationProposal] = []

    /// History of approved mutations
    var approvedMutations: [SkillMutationRecord] = []

    /// History of rejected mutations
    var rejectedMutations: [SkillMutationRecord] = []

    /// Whether analysis is in progress
    var isAnalyzing = false

    /// Analysis progress message
    var progressMessage = ""

    /// Minimum sessions required before analysis
    let minSessionsForAnalysis = 5

    /// Minimum traces per skill for meaningful analysis
    let minTracesPerSkill = 3

    // MARK: - Initialization

    init(
        vaultRegistry: VaultRegistry = .shared,
        sessionBrowser: SessionBrowser = .shared
    ) {
        self.vaultRegistry = vaultRegistry
        self.sessionBrowser = sessionBrowser
    }

    // MARK: - Trace Analysis

    /// Analyzes traces for a specific skill across all sessions.
    /// - Parameters:
    ///   - skillName: Name of the skill to analyze
    ///   - vaultIdentity: Which vault to search
    /// - Returns: Analysis results with improvement signals
    func analyzeTraces(
        forSkill skillName: String,
        in vaultIdentity: VaultIdentity
    ) async -> TraceAnalysisResult? {
        guard let vaultPath = vaultRegistry.resolveVaultPath(for: vaultIdentity) else {
            return nil
        }

        isAnalyzing = true
        progressMessage = "Loading session traces..."

        defer {
            isAnalyzing = false
            progressMessage = ""
        }

        do {
            let traceSessions = try await loadTraceSessions(from: vaultPath)
            let matchingTraceCount = traceSessions.values
                .flatMap { $0 }
                .filter { $0.matches(skillName: skillName) }
                .count

            guard matchingTraceCount >= minTracesPerSkill else {
                progressMessage = "Insufficient traces (need \(minTracesPerSkill), found \(matchingTraceCount))"
                return nil
            }

            progressMessage = "Analyzing \(matchingTraceCount) traces via GEPA..."

            let result = TraceAnalysisResult.analyze(skillName: skillName, traceSessions: traceSessions)
            Logger.evolution.info("Analyzed \(skillName, privacy: .public): \(result.signals.count) signals found")
            return result
        } catch {
            Logger.evolution.error("Trace analysis failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Analyzes all skills in a vault that have sufficient trace data.
    /// - Parameter vaultIdentity: Target vault
    /// - Returns: Map of skill names to their analysis results
    func analyzeAllSkills(in vaultIdentity: VaultIdentity) async -> [String: TraceAnalysisResult] {
        guard let vaultPath = vaultRegistry.resolveVaultPath(for: vaultIdentity) else {
            return [:]
        }

        sessionBrowser.refreshSessions(for: vaultIdentity)

        let traceSessions: [String: [SkillTraceEvent]]
        do {
            traceSessions = try await loadTraceSessions(from: vaultPath)
        } catch {
            Logger.evolution.error("Failed to load trace sessions: \(error.localizedDescription, privacy: .public)")
            return [:]
        }

        var skillTraces: [String: Int] = [:]
        for sessionEvents in traceSessions.values {
            for trace in sessionEvents where trace.kind == "tool_call" {
                guard let name = trace.name, !name.isEmpty else { continue }
                skillTraces[name, default: 0] += 1
            }
        }

        var results: [String: TraceAnalysisResult] = [:]
        for (skillName, count) in skillTraces where count >= minTracesPerSkill {
            results[skillName] = TraceAnalysisResult.analyze(skillName: skillName, traceSessions: traceSessions)
        }

        return results
    }

    // MARK: - Mutation Proposal

    /// Requests a skill mutation proposal based on trace analysis.
    /// - Parameters:
    ///   - skillName: Skill to evolve
    ///   - skillContent: Current SKILL.md content
    ///   - analysis: Trace analysis results
    ///   - vaultIdentity: Target vault
    /// - Returns: Proposed mutation, or nil if constraints not met
    func proposeMutation(
        forSkill skillName: String,
        skillContent: String,
        analysis: TraceAnalysisResult,
        in vaultIdentity: VaultIdentity
    ) async -> SkillMutationProposal? {

        isAnalyzing = true
        progressMessage = "Generating mutation proposal..."

        defer {
            isAnalyzing = false
            progressMessage = ""
        }

        do {
            let analysisJson = try JSONEncoder().encode(analysis)
            guard let analysisString = String(data: analysisJson, encoding: .utf8) else {
                return nil
            }

            let proposalJson = try proposeSkillMutation(
                skillContent: skillContent,
                tracePatternJson: analysisString
            )

            guard let data = proposalJson.data(using: .utf8), !data.isEmpty else {
                progressMessage = "No mutation proposed (constraints not met)"
                return nil
            }

            let decodedProposal = try JSONDecoder().decode(RustSkillMutationProposal.self, from: data)
            let proposal = SkillMutationProposal(from: decodedProposal)

            guard proposal.constraintCheck.allGatesPass else {
                let failed = proposal.constraintCheck.failedGates.joined(separator: ", ")
                progressMessage = "Proposal rejected: \(failed)"
                return nil
            }

            pendingProposals.append(proposal)

            Logger.evolution.info("Proposed mutation for \(skillName, privacy: .public): \(proposal.rationale, privacy: .public)")
            return proposal
        } catch {
            Logger.evolution.error("Mutation proposal failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Automatically proposes mutations for all skills with improvement signals.
    /// - Parameter vaultIdentity: Target vault
    /// - Returns: Number of proposals generated
    func autoProposeMutations(in vaultIdentity: VaultIdentity) async -> Int {
        let analyses = await analyzeAllSkills(in: vaultIdentity)

        var proposalCount = 0

        for (skillName, analysis) in analyses {
            guard !analysis.signals.isEmpty else { continue }
            guard let skillContent = await loadSkillContent(skillName, in: vaultIdentity) else {
                continue
            }

            if await proposeMutation(
                forSkill: skillName,
                skillContent: skillContent,
                analysis: analysis,
                in: vaultIdentity
            ) != nil {
                proposalCount += 1
            }
        }

        return proposalCount
    }

    // MARK: - Mutation Review

    /// Approves a mutation proposal.
    /// - Parameters:
    ///   - proposal: The proposal to approve
    ///   - vaultIdentity: Target vault
    func approveMutation(
        _ proposal: SkillMutationProposal,
        in vaultIdentity: VaultIdentity
    ) async throws {
        try await writeSkillVersion(proposal, in: vaultIdentity)

        let record = SkillMutationRecord(
            skillName: proposal.skillName,
            oldVersion: proposal.oldVersion,
            newVersion: proposal.newVersion,
            rationale: proposal.rationale,
            timestamp: Date(),
            approved: true
        )
        approvedMutations.append(record)
        pendingProposals.removeAll { $0.id == proposal.id }

        Logger.evolution.info("Approved mutation for \(proposal.skillName, privacy: .public) v\(proposal.newVersion, privacy: .public)")
    }

    /// Rejects a mutation proposal.
    /// - Parameter proposal: The proposal to reject
    func rejectMutation(_ proposal: SkillMutationProposal) {
        let record = SkillMutationRecord(
            skillName: proposal.skillName,
            oldVersion: proposal.oldVersion,
            newVersion: proposal.newVersion,
            rationale: proposal.rationale,
            timestamp: Date(),
            approved: false
        )
        rejectedMutations.append(record)
        pendingProposals.removeAll { $0.id == proposal.id }

        Logger.evolution.info("Rejected mutation for \(proposal.skillName, privacy: .public)")
    }

    // MARK: - Private Helpers

    private func loadTraceSessions(from vaultPath: String) async throws -> [String: [SkillTraceEvent]] {
        var sessions = try loadVaultTraceSessions(from: vaultPath)
        let harnessSessions = try loadHarnessTraceSessions()
        mergeTraceSessions(harnessSessions, into: &sessions)
        return sessions
    }

    private func loadVaultTraceSessions(from vaultPath: String) throws -> [String: [SkillTraceEvent]] {
        let sessionsPath = URL(fileURLWithPath: vaultPath, isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)

        guard let enumerator = FileManager.default.enumerator(
            at: sessionsPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var sessions: [String: [SkillTraceEvent]] = [:]

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "trace.json" {
            let sessionKey = fileURL.deletingLastPathComponent().lastPathComponent
            let data = try Data(contentsOf: fileURL)
            let payloads = try JSONDecoder().decode([VaultTraceEventPayload].self, from: data)
            let normalized = payloads.map { $0.normalized(sessionKey: sessionKey) }
            if !normalized.isEmpty {
                sessions[sessionKey, default: []].append(contentsOf: normalized)
            }
        }

        return sessions
    }

    private func loadHarnessTraceSessions() throws -> [String: [SkillTraceEvent]] {
        let tracesRoot = FoundationSafety.userApplicationSupportDirectory()
            .appendingPathComponent("com.epistemos.app/traces/production", isDirectory: true)

        guard FileManager.default.fileExists(atPath: tracesRoot.path) else {
            return [:]
        }

        guard let enumerator = FileManager.default.enumerator(
            at: tracesRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return [:]
        }

        var sessions: [String: [SkillTraceEvent]] = [:]

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            for line in contents.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let data = line.data(using: .utf8),
                      let payload = try? JSONDecoder().decode(HarnessTraceEventPayload.self, from: data),
                      let normalized = payload.normalized() else {
                    continue
                }
                sessions[normalized.sessionKey, default: []].append(normalized)
            }
        }

        return sessions
    }

    private func mergeTraceSessions(
        _ incoming: [String: [SkillTraceEvent]],
        into existing: inout [String: [SkillTraceEvent]]
    ) {
        for (sessionKey, events) in incoming {
            existing[sessionKey, default: []].append(contentsOf: events)
        }
    }

    private func loadSkillContent(_ skillName: String, in vaultIdentity: VaultIdentity) async -> String? {
        guard let vaultPath = vaultRegistry.resolveVaultPath(for: vaultIdentity) else {
            return nil
        }

        let skillPath = (vaultPath as NSString)
            .appendingPathComponent("skills/\(skillName)/SKILL.md")

        guard FileManager.default.fileExists(atPath: skillPath) else {
            return nil
        }

        do {
            return try String(contentsOfFile: skillPath, encoding: .utf8)
        } catch {
            Logger.evolution.warning("Failed to read skill content at \(skillPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func writeSkillVersion(
        _ proposal: SkillMutationProposal,
        in vaultIdentity: VaultIdentity
    ) async throws {
        guard let vaultPath = vaultRegistry.resolveVaultPath(for: vaultIdentity) else {
            throw EvolutionError.vaultNotFound
        }

        let skillDir = (vaultPath as NSString)
            .appendingPathComponent("skills/\(proposal.skillName)")

        do {
            try FileManager.default.createDirectory(
                atPath: skillDir,
                withIntermediateDirectories: true
            )
        } catch {
            Logger.evolution.error(
                "Failed to create skill directory at \(skillDir, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }

        let skillPath = (skillDir as NSString).appendingPathComponent("SKILL.md")
        try proposal.newContent.write(toFile: skillPath, atomically: true, encoding: .utf8)

        let versionsDir = (skillDir as NSString).appendingPathComponent("versions")
        do {
            try FileManager.default.createDirectory(
                atPath: versionsDir,
                withIntermediateDirectories: true
            )
        } catch {
            Logger.evolution.error(
                "Failed to create skill versions directory at \(versionsDir, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }

        let versionPath = (versionsDir as NSString)
            .appendingPathComponent("\(proposal.newVersion).md")
        try proposal.newContent.write(toFile: versionPath, atomically: true, encoding: .utf8)

        let diffPath = (versionsDir as NSString)
            .appendingPathComponent("\(proposal.oldVersion)-\(proposal.newVersion).diff")
        try proposal.diff.write(toFile: diffPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Supporting Types

struct TraceAnalysisResult: Codable {
    let skillName: String
    let sessionsAnalyzed: Int
    let successCount: Int
    let failureCount: Int
    let avgDurationMs: Double
    let improvementSignals: [ImprovementSignal]

    var totalTraces: Int { successCount + failureCount }
    var signals: [ImprovementSignal] { improvementSignals }

    private enum CodingKeys: String, CodingKey {
        case skillName = "skill_name"
        case sessionsAnalyzed = "sessions_analyzed"
        case successCount = "success_count"
        case failureCount = "failure_count"
        case avgDurationMs = "avg_duration_ms"
        case improvementSignals = "improvement_signals"
    }

    static func analyze(
        skillName: String,
        traceSessions: [String: [SkillTraceEvent]]
    ) -> TraceAnalysisResult {
        let matchingSessions = traceSessions.values.compactMap { sessionEvents -> [SkillTraceEvent]? in
            let matching = sessionEvents.filter { $0.matches(skillName: skillName) }
            return matching.isEmpty ? nil : matching
        }

        var totalDuration = 0.0
        var durationCount = 0
        var successCount = 0
        var failureCount = 0

        for sessionEvents in matchingSessions {
            for event in sessionEvents {
                if let durationMs = event.durationMs {
                    totalDuration += durationMs
                    durationCount += 1
                }
                switch event.outcome?.lowercased() {
                case "success", "ok":
                    successCount += 1
                case "error", "failure":
                    failureCount += 1
                default:
                    break
                }
            }
        }

        let avgDurationMs = durationCount > 0 ? totalDuration / Double(durationCount) : 0

        return TraceAnalysisResult(
            skillName: skillName,
            sessionsAnalyzed: matchingSessions.count,
            successCount: successCount,
            failureCount: failureCount,
            avgDurationMs: avgDurationMs,
            improvementSignals: ImprovementSignal.detectSignals(
                in: matchingSessions,
                fallbackSkillName: skillName
            )
        )
    }
}

enum ImprovementSignal: Identifiable, Codable, Sendable, Equatable {
    case frequentRetries(step: String, avgRetryCount: Double, sessionsAffected: Int)
    case slowExecution(step: String, avgMs: Double, p95Ms: Double)
    case consistentFailure(step: String, errorPattern: String, occurrenceCount: Int)
    case unusedCapability(capability: String)

    var id: String {
        switch self {
        case .frequentRetries(let step, _, _):
            return "frequentRetries:\(step)"
        case .slowExecution(let step, _, _):
            return "slowExecution:\(step)"
        case .consistentFailure(let step, let errorPattern, _):
            return "consistentFailure:\(step):\(errorPattern)"
        case .unusedCapability(let capability):
            return "unusedCapability:\(capability)"
        }
    }

    private enum VariantKey: String, CodingKey {
        case frequentRetries = "FrequentRetries"
        case slowExecution = "SlowExecution"
        case consistentFailure = "ConsistentFailure"
        case unusedCapability = "UnusedCapability"
    }

    private enum FrequentRetriesCodingKeys: String, CodingKey {
        case step
        case avgRetryCount = "avg_retry_count"
        case sessionsAffected = "sessions_affected"
    }

    private enum SlowExecutionCodingKeys: String, CodingKey {
        case step
        case avgMs = "avg_ms"
        case p95Ms = "p95_ms"
    }

    private enum ConsistentFailureCodingKeys: String, CodingKey {
        case step
        case errorPattern = "error_pattern"
        case occurrenceCount = "occurrence_count"
    }

    private enum UnusedCapabilityCodingKeys: String, CodingKey {
        case capability
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: VariantKey.self)

        if container.contains(.frequentRetries) {
            let nested = try container.nestedContainer(keyedBy: FrequentRetriesCodingKeys.self, forKey: .frequentRetries)
            self = .frequentRetries(
                step: try nested.decode(String.self, forKey: .step),
                avgRetryCount: try nested.decode(Double.self, forKey: .avgRetryCount),
                sessionsAffected: try nested.decode(Int.self, forKey: .sessionsAffected)
            )
            return
        }

        if container.contains(.slowExecution) {
            let nested = try container.nestedContainer(keyedBy: SlowExecutionCodingKeys.self, forKey: .slowExecution)
            self = .slowExecution(
                step: try nested.decode(String.self, forKey: .step),
                avgMs: try nested.decode(Double.self, forKey: .avgMs),
                p95Ms: try nested.decode(Double.self, forKey: .p95Ms)
            )
            return
        }

        if container.contains(.consistentFailure) {
            let nested = try container.nestedContainer(keyedBy: ConsistentFailureCodingKeys.self, forKey: .consistentFailure)
            self = .consistentFailure(
                step: try nested.decode(String.self, forKey: .step),
                errorPattern: try nested.decode(String.self, forKey: .errorPattern),
                occurrenceCount: try nested.decode(Int.self, forKey: .occurrenceCount)
            )
            return
        }

        let nested = try container.nestedContainer(keyedBy: UnusedCapabilityCodingKeys.self, forKey: .unusedCapability)
        self = .unusedCapability(capability: try nested.decode(String.self, forKey: .capability))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: VariantKey.self)

        switch self {
        case .frequentRetries(let step, let avgRetryCount, let sessionsAffected):
            var nested = container.nestedContainer(keyedBy: FrequentRetriesCodingKeys.self, forKey: .frequentRetries)
            try nested.encode(step, forKey: .step)
            try nested.encode(avgRetryCount, forKey: .avgRetryCount)
            try nested.encode(sessionsAffected, forKey: .sessionsAffected)

        case .slowExecution(let step, let avgMs, let p95Ms):
            var nested = container.nestedContainer(keyedBy: SlowExecutionCodingKeys.self, forKey: .slowExecution)
            try nested.encode(step, forKey: .step)
            try nested.encode(avgMs, forKey: .avgMs)
            try nested.encode(p95Ms, forKey: .p95Ms)

        case .consistentFailure(let step, let errorPattern, let occurrenceCount):
            var nested = container.nestedContainer(keyedBy: ConsistentFailureCodingKeys.self, forKey: .consistentFailure)
            try nested.encode(step, forKey: .step)
            try nested.encode(errorPattern, forKey: .errorPattern)
            try nested.encode(occurrenceCount, forKey: .occurrenceCount)

        case .unusedCapability(let capability):
            var nested = container.nestedContainer(keyedBy: UnusedCapabilityCodingKeys.self, forKey: .unusedCapability)
            try nested.encode(capability, forKey: .capability)
        }
    }

    fileprivate static func detectSignals(
        in sessions: [[SkillTraceEvent]],
        fallbackSkillName: String
    ) -> [ImprovementSignal] {
        var signals: [ImprovementSignal] = []

        var retrySessions: [String: [Int]] = [:]
        for sessionEvents in sessions {
            var toolCounts: [String: Int] = [:]
            for event in sessionEvents {
                guard let name = event.name else { continue }
                toolCounts[name, default: 0] += 1
            }
            for (tool, count) in toolCounts where count >= 3 {
                retrySessions[tool, default: []].append(count)
            }
        }
        for (tool, counts) in retrySessions where counts.count >= 2 {
            let average = Double(counts.reduce(0, +)) / Double(counts.count)
            signals.append(
                .frequentRetries(
                    step: tool,
                    avgRetryCount: average,
                    sessionsAffected: counts.count
                )
            )
        }

        var toolDurations: [String: [Double]] = [:]
        for sessionEvents in sessions {
            for event in sessionEvents {
                guard let name = event.name, let durationMs = event.durationMs else { continue }
                toolDurations[name, default: []].append(durationMs)
            }
        }
        for (tool, durations) in toolDurations {
            guard durations.count >= 3 else { continue }
            let sorted = durations.sorted()
            let average = sorted.reduce(0, +) / Double(sorted.count)
            let p95Index = min(Int(Double(sorted.count) * 0.95), sorted.count - 1)
            let p95 = sorted[p95Index]
            if average > 5_000 {
                signals.append(.slowExecution(step: tool, avgMs: average, p95Ms: p95))
            }
        }

        var errorPatterns: [String: Int] = [:]
        for sessionEvents in sessions {
            for event in sessionEvents where event.outcome?.lowercased() == "error" {
                guard let outputSummary = event.outputSummary else { continue }
                let name = event.name ?? fallbackSkillName
                let key = "\(name)::\(String(outputSummary.prefix(80)))"
                errorPatterns[key, default: 0] += 1
            }
        }
        for (pattern, count) in errorPatterns where count >= 3 {
            let parts = pattern.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            let step = parts.first.map(String.init) ?? fallbackSkillName
            let errorPattern = parts.dropFirst(2).joined(separator: ":")
            signals.append(
                .consistentFailure(
                    step: step,
                    errorPattern: errorPattern,
                    occurrenceCount: count
                )
            )
        }

        return signals
    }
}

struct SkillMutationProposal: Identifiable {
    let id = UUID()
    let skillName: String
    let oldVersion: String
    let newVersion: String
    let oldContent: String
    let newContent: String
    let diff: String
    let rationale: String
    let constraintCheck: ConstraintCheck

    init(from decodedProposal: RustSkillMutationProposal) {
        self.skillName = decodedProposal.skillName
        self.newVersion = decodedProposal.version
        self.oldVersion = Self.previousVersion(of: decodedProposal.version)
        self.oldContent = decodedProposal.oldContent
        self.newContent = decodedProposal.newContent
        self.diff = Self.renderDiff(old: decodedProposal.oldContent, new: decodedProposal.newContent)
        self.rationale = decodedProposal.rationale
        self.constraintCheck = ConstraintCheck(from: decodedProposal.constraintCheck)
    }

    private static func previousVersion(of version: String) -> String {
        guard version.hasPrefix("v"),
              let numeric = Int(version.dropFirst()),
              numeric > 1 else {
            return "v1"
        }
        return "v\(numeric - 1)"
    }

    private static func renderDiff(old: String, new: String) -> String {
        if old == new {
            return old
        }

        let oldLines = old.components(separatedBy: .newlines)
        let newLines = new.components(separatedBy: .newlines)
        let sharedCount = min(oldLines.count, newLines.count)

        var diff: [String] = []
        for index in 0..<sharedCount {
            let oldLine = oldLines[index]
            let newLine = newLines[index]
            if oldLine == newLine {
                diff.append("  \(newLine)")
            } else {
                diff.append("- \(oldLine)")
                diff.append("+ \(newLine)")
            }
        }

        if newLines.count > sharedCount {
            for line in newLines[sharedCount...] {
                diff.append("+ \(line)")
            }
        }

        if oldLines.count > sharedCount {
            for line in oldLines[sharedCount...] {
                diff.append("- \(line)")
            }
        }

        return diff.joined(separator: "\n")
    }
}

struct ConstraintCheck {
    let sizeOk: Bool
    let semanticPreserved: Bool
    let allGatesPass: Bool
    let failedGates: [String]

    var allPassed: Bool { allGatesPass }

    init(from rust: RustConstraintCheck) {
        self.sizeOk = rust.sizeOk
        self.semanticPreserved = rust.semanticPreserved
        self.allGatesPass = rust.allGatesPass

        var failed: [String] = []
        if !rust.sizeOk {
            failed.append("size")
        }
        if !rust.semanticPreserved {
            failed.append("semantic")
        }
        self.failedGates = failed
    }
}

struct SkillMutationRecord: Identifiable {
    let id = UUID()
    let skillName: String
    let oldVersion: String
    let newVersion: String
    let rationale: String
    let timestamp: Date
    let approved: Bool
}

struct SkillTraceEvent: Sendable, Equatable {
    let sessionKey: String
    let timestamp: String
    let kind: String
    let name: String?
    let inputSummary: String?
    let outputSummary: String?
    let durationMs: Double?
    let outcome: String?

    func matches(skillName: String) -> Bool {
        name?
            .localizedCaseInsensitiveContains(skillName) == true
    }
}

enum EvolutionError: Error {
    case vaultNotFound
    case skillNotFound
    case insufficientTraces
    case constraintViolation(String)
}

// MARK: - Decoding Payloads

private struct VaultTraceEventPayload: Codable {
    let timestamp: String
    let kind: String
    let name: String?
    let inputSummary: String?
    let outputSummary: String?
    let durationMs: Double?
    let outcome: String?

    private enum CodingKeys: String, CodingKey {
        case timestamp
        case kind
        case name
        case inputSummary = "input_summary"
        case outputSummary = "output_summary"
        case durationMs = "duration_ms"
        case outcome
    }

    func normalized(sessionKey: String) -> SkillTraceEvent {
        SkillTraceEvent(
            sessionKey: sessionKey,
            timestamp: timestamp,
            kind: kind,
            name: name,
            inputSummary: inputSummary,
            outputSummary: outputSummary,
            durationMs: durationMs,
            outcome: outcome
        )
    }
}

private struct HarnessTraceEventPayload: Codable {
    let ts: String
    let type: String
    let sessionId: String
    let tool: String?
    let toolInput: String?
    let toolOutput: String?
    let durationMs: Double?
    let errorMessage: String?

    func normalized() -> SkillTraceEvent? {
        guard type == "tool_call" || type == "tool_result" || type == "error" else {
            return nil
        }

        let outputSummary = toolOutput ?? errorMessage
        let outcome: String?
        if let errorMessage, !errorMessage.isEmpty {
            outcome = "error"
        } else if type == "tool_call" || type == "tool_result" {
            outcome = "success"
        } else {
            outcome = nil
        }

        return SkillTraceEvent(
            sessionKey: sessionId,
            timestamp: ts,
            kind: type,
            name: tool,
            inputSummary: toolInput,
            outputSummary: outputSummary,
            durationMs: durationMs,
            outcome: outcome
        )
    }
}

struct RustSkillMutationProposal: Codable {
    let skillName: String
    let version: String
    let rationale: String
    let oldContent: String
    let newContent: String
    let constraintCheck: RustConstraintCheck

    private enum CodingKeys: String, CodingKey {
        case skillName = "skill_name"
        case version
        case rationale
        case oldContent = "old_content"
        case newContent = "new_content"
        case constraintCheck = "constraint_check"
    }
}

struct RustConstraintCheck: Codable {
    let sizeOk: Bool
    let semanticPreserved: Bool
    let allGatesPass: Bool

    private enum CodingKeys: String, CodingKey {
        case sizeOk = "size_ok"
        case semanticPreserved = "semantic_preserved"
        case allGatesPass = "all_gates_pass"
    }
}

// MARK: - Logger Extension

extension Logger {
    fileprivate static let evolution = Logger(subsystem: "com.epistemos", category: "SkillEvolution")
}
