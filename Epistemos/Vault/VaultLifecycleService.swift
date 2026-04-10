import Foundation
import os

// MARK: - Vault Lifecycle Service
//
// Wires the unwired FFI exports from Phases 3, 4, and 6 into the app's
// session lifecycle. Each method is called at the appropriate point:
//
// - On session end: generate knowledge graph
// - On vault write: detect contradictions
// - On NightBrain: merge graphs, analyze traces, propose mutations
//
// All FFI calls are dispatched to background threads to avoid blocking.

actor VaultLifecycleService {
    static let log = Logger(subsystem: "com.epistemos", category: "VaultLifecycle")

    private let vaultPath: String

    init(vaultPath: String) {
        self.vaultPath = vaultPath
    }

    // MARK: - Phase 3: Contradiction Detection

    /// Check an incoming fact against existing vault facts for contradictions.
    /// Returns any detected conflicts for UI display.
    func detectContradictions(
        incomingFact: String,
        existingFacts: [VaultFactFFI]
    ) -> [ContradictionFFI] {
        let contradictions = detectVaultContradictions(
            incoming: incomingFact,
            existingFacts: existingFacts
        )
        if !contradictions.isEmpty {
            Self.log.warning("Detected \(contradictions.count) contradiction(s) for incoming fact")
        }
        return contradictions
    }

    // MARK: - Phase 4: Knowledge Graph

    /// Generate a knowledge graph for a completed session.
    /// Called after agent sessions complete.
    func generateGraphForSession(sessionFolderPath: String) {
        do {
            let graphJSON = try generateSessionGraph(sessionFolderPath: sessionFolderPath)
            Self.log.info("Generated session graph (\(graphJSON.count) bytes) at \(sessionFolderPath)")
        } catch {
            Self.log.error("Failed to generate session graph: \(error.localizedDescription)")
        }
    }

    /// Merge all session graphs into a vault-level graph.
    /// Called by NightBrain during idle maintenance.
    func mergeVaultGraphs() {
        // List all session folders, generate graphs for any missing, then merge
        let sessions = listSessionFolders(vaultPath: vaultPath)
        var generatedCount = 0

        for session in sessions {
            let graphPath = URL(fileURLWithPath: session.folderPath)
                .appendingPathComponent("graph.json")
            if !FileManager.default.fileExists(atPath: graphPath.path) {
                generateGraphForSession(sessionFolderPath: session.folderPath)
                generatedCount += 1
            }
        }

        if generatedCount > 0 {
            Self.log.info("Generated \(generatedCount) missing session graph(s)")
        }

        do {
            let mergedGraphPath = try merge_vault_graph(vaultPath: vaultPath)
            Self.log.info("Merged vault graph at \(mergedGraphPath, privacy: .public)")
        } catch {
            Self.log.error("Failed to merge vault graph: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Phase 6: GEPA Self-Evolution

    /// Analyze traces for a specific skill and propose mutations.
    /// Called by NightBrain for skills with sufficient trace data.
    func analyzeAndProposeEvolution(skillName: String) -> SkillEvolutionResult? {
        // Step 1: Analyze traces
        guard let patternJSON = try? analyzeSkillTraces(
            vaultPath: vaultPath,
            skillName: skillName
        ) else {
            Self.log.error("Failed to analyze traces for skill: \(skillName)")
            return nil
        }

        if patternJSON.isEmpty || patternJSON == "{}" {
            return nil
        }

        // Step 2: Load current skill content
        let skillPath = URL(fileURLWithPath: vaultPath)
            .appendingPathComponent("skills")
            .appendingPathComponent(skillName)
            .appendingPathComponent("SKILL.md")
        guard let skillContent = try? String(contentsOf: skillPath, encoding: .utf8) else {
            Self.log.warning("Skill file not found: \(skillName)")
            return nil
        }

        // Step 3: Propose mutation
        guard let mutationJSON = try? proposeSkillMutation(
            skillContent: skillContent,
            tracePatternJson: patternJSON
        ), !mutationJSON.isEmpty else {
            return nil
        }

        Self.log.info("GEPA proposed evolution for skill: \(skillName)")
        return SkillEvolutionResult(
            skillName: skillName,
            patternJSON: patternJSON,
            mutationJSON: mutationJSON
        )
    }

    /// Run the full GEPA evolution pipeline across all registered skills.
    /// Returns proposals for skills that have improvement signals.
    func runEvolutionSweep() -> [SkillEvolutionResult] {
        let skills = listRegisteredSkills(vaultPath: vaultPath)
        var proposals: [SkillEvolutionResult] = []

        for skill in skills {
            // Only analyze skills with enough usage data
            guard skill.useCount >= 5 else { continue }

            if let result = analyzeAndProposeEvolution(skillName: skill.name) {
                proposals.append(result)
            }
        }

        if !proposals.isEmpty {
            Self.log.info("GEPA sweep: \(proposals.count) evolution proposal(s) generated")
        }
        return proposals
    }
}

// MARK: - Supporting Types

struct SkillEvolutionResult: Sendable {
    let skillName: String
    let patternJSON: String
    let mutationJSON: String
}

// MARK: - Swift Compatibility Bridge

extension VaultFactFfi: @unchecked Sendable {}
extension ContradictionFfi: @unchecked Sendable {}
extension SessionFolderInfoFfi: @unchecked Sendable {}
extension SkillRegistryEntryFfi: @unchecked Sendable {}

typealias VaultFactFFI = VaultFactFfi
typealias ContradictionFFI = ContradictionFfi
typealias SessionFolderInfoFFI = SessionFolderInfoFfi
typealias SkillRegistryEntryFFI = SkillRegistryEntryFfi

private nonisolated struct SessionFileMetadata: Decodable, Sendable {
    let id: String
    let model: String
    let provider: String
    let startedAt: Date?
    let status: String?
    let turnCount: UInt32?

    enum CodingKeys: String, CodingKey {
        case id
        case model
        case provider
        case startedAt = "started_at"
        case status
        case turnCount = "turn_count"
    }
}

private nonisolated struct TranscriptLine: Decodable, Sendable {
    nonisolated struct ToolCall: Decodable, Sendable {
        let name: String
    }

    let content: String
    let toolCalls: [ToolCall]

    enum CodingKeys: String, CodingKey {
        case content
        case toolCalls = "tool_calls"
    }
}

private nonisolated struct TraceAnalysisPattern: Codable, Sendable {
    let skillName: String
    let traceCount: Int
    let successCount: Int
    let failureCount: Int
    let averageDurationMs: Double
    let topFailureOutputs: [String]
}

@MainActor func sessionFolderPathLocal(sessionId: String) -> String? {
    let shortID = String(sessionId.prefix(8))
    for entry in VaultRegistry.shared.entries {
        let sessionsRoot = entry.rootURL.appendingPathComponent("sessions", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            continue
        }
        for case let folderURL as URL in enumerator {
            guard (try? folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }
            let name = folderURL.lastPathComponent
            if name.hasSuffix(shortID) || name.contains(sessionId) {
                return folderURL.path
            }
        }
    }
    return nil
}

nonisolated func readSessionMetadataLocal(sessionFolderPath: String) throws -> String {
    let url = URL(fileURLWithPath: sessionFolderPath).appendingPathComponent("session.json")
    return try String(contentsOf: url, encoding: .utf8)
}

nonisolated func listSessionFoldersLocal(vaultPath: String) -> [SessionFolderInfoFFI] {
    let sessionsRoot = URL(fileURLWithPath: vaultPath).appendingPathComponent("sessions", isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
        at: sessionsRoot,
        includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    var results: [SessionFolderInfoFFI] = []
    for case let folderURL as URL in enumerator {
        guard (try? folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            continue
        }

        let sessionFileURL = folderURL.appendingPathComponent("session.json")
        guard let data = try? Data(contentsOf: sessionFileURL),
              let metadata = try? decoder.decode(SessionFileMetadata.self, from: data) else {
            continue
        }

        let startedAt = metadata.startedAt?.timeIntervalSince1970
            ?? (try? folderURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate?.timeIntervalSince1970)
            ?? 0

        results.append(
            SessionFolderInfoFFI(
                sessionId: metadata.id,
                model: metadata.model,
                provider: metadata.provider,
                startedAtEpoch: startedAt,
                status: metadata.status ?? "unknown",
                turnCount: metadata.turnCount ?? 0,
                folderPath: folderURL.path
            )
        )
    }

    return results.sorted { $0.startedAtEpoch > $1.startedAtEpoch }
}

nonisolated func generateSessionGraphLocal(sessionFolderPath: String) throws -> String {
    let folderURL = URL(fileURLWithPath: sessionFolderPath, isDirectory: true)
    let sessionID = folderURL.lastPathComponent
    let transcriptURL = folderURL.appendingPathComponent("transcript.jsonl")
    let summaryURL = folderURL.appendingPathComponent("summary.md")

    var graphNodes: [GraphNodeData] = [
        GraphNodeData(
            id: "session_\(sessionID)",
            label: sessionID,
            nodeType: "other",
            properties: [:],
            communityId: 0,
            centrality: 0
        )
    ]
    var graphEdges: [GraphEdgeData] = []
    var seenNodeIDs: Set<String> = ["session_\(sessionID)"]

    if let transcript = try? String(contentsOf: transcriptURL, encoding: .utf8) {
        let decoder = JSONDecoder()
        for line in transcript.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let turn = try? decoder.decode(TranscriptLine.self, from: data) else {
                continue
            }

            for toolCall in turn.toolCalls {
                let toolID = "tool_\(toolCall.name)"
                if seenNodeIDs.insert(toolID).inserted {
                    graphNodes.append(
                        GraphNodeData(
                            id: toolID,
                            label: toolCall.name,
                            nodeType: "tool",
                            properties: [:],
                            communityId: 1,
                            centrality: 0
                        )
                    )
                }
                graphEdges.append(
                    GraphEdgeData(
                        source: "session_\(sessionID)",
                        target: toolID,
                        relation: "uses",
                        confidence: "extracted",
                        score: 1.0
                    )
                )
            }

            for concept in inferredConcepts(from: turn.content) {
                let conceptID = "concept_\(slugified(concept))"
                if seenNodeIDs.insert(conceptID).inserted {
                    graphNodes.append(
                        GraphNodeData(
                            id: conceptID,
                            label: concept,
                            nodeType: "concept",
                            properties: [:],
                            communityId: 2,
                            centrality: 0
                        )
                    )
                }
                graphEdges.append(
                    GraphEdgeData(
                        source: "session_\(sessionID)",
                        target: conceptID,
                        relation: "mentions",
                        confidence: "extracted",
                        score: 0.8
                    )
                )
            }
        }
    }

    if let summary = try? String(contentsOf: summaryURL, encoding: .utf8) {
        for heading in markdownHeadings(in: summary) {
            let nodeID = "summary_\(slugified(heading))"
            if seenNodeIDs.insert(nodeID).inserted {
                graphNodes.append(
                    GraphNodeData(
                        id: nodeID,
                        label: heading,
                        nodeType: "decision",
                        properties: ["source": "summary.md"],
                        communityId: 3,
                        centrality: 0
                    )
                )
            }
            graphEdges.append(
                GraphEdgeData(
                    source: "session_\(sessionID)",
                    target: nodeID,
                    relation: "summarizes",
                    confidence: "extracted",
                    score: 0.9
                )
            )
        }
    }

    let degrees = graphEdges.reduce(into: [String: Double]()) { partialResult, edge in
        partialResult[edge.source, default: 0] += 1
        partialResult[edge.target, default: 0] += 1
    }
    graphNodes = graphNodes.map { node in
        GraphNodeData(
            id: node.id,
            label: node.label,
            nodeType: node.nodeType,
            properties: node.properties,
            communityId: node.communityId,
            centrality: degrees[node.id, default: 0]
        )
    }

    let communities = Dictionary(grouping: graphNodes, by: \.communityId)
        .map { communityID, nodes in
            GraphCommunityData(
                id: communityID,
                size: nodes.count,
                topNodes: nodes
                    .sorted { $0.centrality > $1.centrality }
                    .prefix(5)
                    .map(\.label)
            )
        }
        .sorted { $0.id < $1.id }

    let graph = GraphData(nodes: graphNodes, edges: graphEdges, communities: communities)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(graph)
    let json = String(decoding: data, as: UTF8.self)

    try data.write(to: folderURL.appendingPathComponent("graph.json"), options: .atomic)
    try graphReport(for: graph, sessionID: sessionID)
        .write(to: folderURL.appendingPathComponent("GRAPH_REPORT.md"), atomically: true, encoding: .utf8)
    return json
}

nonisolated func generate_session_graph(sessionFolder: String) throws -> String {
    try generateSessionGraph(sessionFolderPath: sessionFolder)
}

nonisolated func merge_vault_graph(vaultPath: String) throws -> String {
    let sessionInfos = listSessionFolders(vaultPath: vaultPath)
    var mergedNodes: [String: GraphNodeData] = [:]
    var mergedEdges: [String: GraphEdgeData] = [:]
    var mergedCommunities: [Int: Set<String>] = [:]

    let decoder = JSONDecoder()
    for session in sessionInfos {
        let graphURL = URL(fileURLWithPath: session.folderPath).appendingPathComponent("graph.json")
        let json: String
        if let existing = try? String(contentsOf: graphURL, encoding: .utf8) {
            json = existing
        } else {
            json = try generateSessionGraph(sessionFolderPath: session.folderPath)
        }
        guard let data = json.data(using: .utf8),
              let graph = try? decoder.decode(GraphData.self, from: data) else {
            continue
        }

        for node in graph.nodes {
            let current = mergedNodes[node.id]
            if current == nil || node.centrality > current?.centrality ?? 0 {
                mergedNodes[node.id] = node
            }
            mergedCommunities[node.communityId, default: []].insert(node.label)
        }
        for edge in graph.edges {
            let key = "\(edge.source)|\(edge.target)|\(edge.relation)"
            if mergedEdges[key] == nil || edge.score > mergedEdges[key]?.score ?? 0 {
                mergedEdges[key] = edge
            }
        }
    }

    let communities = mergedCommunities.map { communityID, labels in
        GraphCommunityData(
            id: communityID,
            size: labels.count,
            topNodes: Array(labels).sorted().prefix(5).map { $0 }
        )
    }
    .sorted { $0.id < $1.id }

    let mergedGraph = GraphData(
        nodes: mergedNodes.values.sorted { $0.id < $1.id },
        edges: mergedEdges.values.sorted {
            ($0.source, $0.target, $0.relation) < ($1.source, $1.target, $1.relation)
        },
        communities: communities
    )

    let outputURL = URL(fileURLWithPath: vaultPath).appendingPathComponent("vault_graph.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(mergedGraph)
    try data.write(to: outputURL, options: .atomic)
    return outputURL.path
}

nonisolated func detectVaultContradictionsLocal(
    incoming: String,
    existingFacts: [VaultFactFFI]
) -> [ContradictionFFI] {
    let normalizedIncoming = normalizedFactTokens(incoming)
    guard !normalizedIncoming.context.isEmpty else {
        return []
    }

    return existingFacts.compactMap { fact in
        let normalizedExisting = normalizedFactTokens(fact.content)
        let sharedContext = normalizedIncoming.context.intersection(normalizedExisting.context)
        guard sharedContext.count >= 2 else {
            return nil
        }

        if let incomingValue = normalizedIncoming.number,
           let existingValue = normalizedExisting.number,
           abs(incomingValue - existingValue) > .ulpOfOne {
            return ContradictionFFI(
                incomingFact: incoming,
                existingFilePath: fact.filePath,
                existingSection: fact.section,
                existingContent: fact.content,
                conflictType: "numeric",
                confidence: min(0.98, 0.6 + (Double(sharedContext.count) * 0.08))
            )
        }

        if let incomingBool = normalizedIncoming.boolean,
           let existingBool = normalizedExisting.boolean,
           incomingBool != existingBool {
            return ContradictionFFI(
                incomingFact: incoming,
                existingFilePath: fact.filePath,
                existingSection: fact.section,
                existingContent: fact.content,
                conflictType: "boolean",
                confidence: min(0.95, 0.58 + (Double(sharedContext.count) * 0.07))
            )
        }

        if containsAntonymConflict(incoming: incoming, existing: fact.content) {
            return ContradictionFFI(
                incomingFact: incoming,
                existingFilePath: fact.filePath,
                existingSection: fact.section,
                existingContent: fact.content,
                conflictType: "antonym",
                confidence: min(0.85, 0.5 + (Double(sharedContext.count) * 0.05))
            )
        }

        return nil
    }
    .sorted { $0.confidence > $1.confidence }
}

nonisolated func analyzeSkillTracesLocal(vaultPath: String, skillName: String) throws -> String {
    let sessions = listSessionFolders(vaultPath: vaultPath)
    var matchingEvents = 0
    var successCount = 0
    var failureOutputs: [String] = []
    var durations: [Double] = []

    let needle = skillName.lowercased()
    for session in sessions {
        let traceURL = URL(fileURLWithPath: session.folderPath).appendingPathComponent("trace.json")
        guard let data = try? Data(contentsOf: traceURL),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            continue
        }

        for event in jsonArray {
            let searchable = [
                event["name"] as? String,
                event["input_summary"] as? String,
                event["output_summary"] as? String
            ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

            guard searchable.contains(needle) else {
                continue
            }

            matchingEvents += 1
            if let outcome = (event["outcome"] as? String)?.lowercased(), !outcome.contains("fail") {
                successCount += 1
            } else if let output = event["output_summary"] as? String {
                failureOutputs.append(output)
            }

            if let duration = event["duration_ms"] as? Double {
                durations.append(duration)
            } else if let durationInt = event["duration_ms"] as? Int {
                durations.append(Double(durationInt))
            }
        }
    }

    let pattern = TraceAnalysisPattern(
        skillName: skillName,
        traceCount: matchingEvents,
        successCount: successCount,
        failureCount: max(0, matchingEvents - successCount),
        averageDurationMs: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count),
        topFailureOutputs: Array(failureOutputs.prefix(5))
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(pattern)
    return String(decoding: data, as: UTF8.self)
}

nonisolated func proposeSkillMutationHeuristic(skillContent: String, tracePatternJson: String) throws -> String {
    let decoder = JSONDecoder()
    guard let data = tracePatternJson.data(using: .utf8) else {
        return ""
    }
    let pattern = try decoder.decode(TraceAnalysisPattern.self, from: data)
    guard pattern.traceCount >= 3, pattern.failureCount > pattern.successCount else {
        return ""
    }

    let proposal: [String: Any] = [
        "mutation_type": "instruction_tightening",
        "reasoning": "Observed \(pattern.failureCount) failing traces for \(pattern.skillName); clarify failure-prone guidance.",
        "proposed_appendix": """
        ## Reliability Notes
        - Prefer deterministic, narrower tool usage when the request already names the target file or command.
        - Reflect the actual runtime result back to the caller before moving to the next step.
        - If the supporting trace format changes, update the parser before relying on automated analysis.
        """
    ]
    let json = try JSONSerialization.data(withJSONObject: proposal, options: [.prettyPrinted, .sortedKeys])
    return String(decoding: json, as: UTF8.self)
}

nonisolated func listRegisteredSkillsLocal(vaultPath: String) -> [SkillRegistryEntryFFI] {
    let skillsRoot = URL(fileURLWithPath: vaultPath).appendingPathComponent("skills", isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(
        at: skillsRoot,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    var entries: [SkillRegistryEntryFFI] = []
    for case let skillURL as URL in enumerator {
        let manifestURL = skillURL.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            continue
        }
        let content = (try? String(contentsOf: manifestURL, encoding: .utf8)) ?? ""
        let description = content
            .split(separator: "\n")
            .map(String.init)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("#") })
            ?? "Local skill"
        entries.append(
            SkillRegistryEntryFFI(
                name: skillURL.lastPathComponent,
                description: description,
                version: "v1",
                useCount: 0,
                successRate: 0
            )
        )
    }
    return entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

private nonisolated func markdownHeadings(in markdown: String) -> [String] {
    markdown
        .split(separator: "\n")
        .compactMap { line in
            guard line.hasPrefix("#") else { return nil }
            return line.trimmingCharacters(in: CharacterSet(charactersIn: "# ").union(.whitespaces))
        }
}

private nonisolated func inferredConcepts(from text: String) -> [String] {
    let stopwords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "into", "your", "their",
        "have", "will", "would", "should", "could", "about", "there", "after", "before"
    ]
    let words = text
        .lowercased()
        .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .map(String.init)
        .filter { $0.count >= 4 && !stopwords.contains($0) }
    return Array(Set(words)).sorted().prefix(6).map { $0 }
}

private nonisolated func slugified(_ text: String) -> String {
    let collapsed = text
        .lowercased()
        .map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
    return String(collapsed)
        .split(separator: "-", omittingEmptySubsequences: true)
        .joined(separator: "-")
}

private nonisolated func graphReport(for graph: GraphData, sessionID: String) -> String {
    let nodeSummary = Dictionary(grouping: graph.nodes, by: \.nodeType)
        .map { key, value in "- \(key): \(value.count)" }
        .sorted()
        .joined(separator: "\n")
    return """
    # Graph Report: \(sessionID)

    - Nodes: \(graph.nodes.count)
    - Edges: \(graph.edges.count)

    ## Node Types
    \(nodeSummary)
    """
}

private struct NormalizedFactTokens {
    let context: Set<String>
    let number: Double?
    let boolean: Bool?
}

private nonisolated func normalizedFactTokens(_ text: String) -> NormalizedFactTokens {
    let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "to", "of", "in", "on", "for", "with", "is", "are", "was", "were"
    ]
    let lowercased = text.lowercased()
    let tokens = Set(
        lowercased
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 3 && !stopwords.contains($0) }
    )

    let regex = try? NSRegularExpression(pattern: #"-?\d+(?:\.\d+)?"#)
    let number: Double? = {
        guard let regex else { return nil }
        let nsrange = NSRange(lowercased.startIndex..<lowercased.endIndex, in: lowercased)
        guard let match = regex.firstMatch(in: lowercased, range: nsrange),
              let range = Range(match.range, in: lowercased) else {
            return nil
        }
        return Double(lowercased[range])
    }()

    let boolean: Bool? = {
        let positives = ["true", "yes", "enabled", "allow", "allowed", "supports"]
        let negatives = ["false", "no", "disabled", "deny", "denied", "unsupported"]
        if positives.contains(where: lowercased.contains) { return true }
        if negatives.contains(where: lowercased.contains) { return false }
        return nil
    }()

    return NormalizedFactTokens(context: tokens, number: number, boolean: boolean)
}

private nonisolated func containsAntonymConflict(incoming: String, existing: String) -> Bool {
    let pairs = [
        ("increase", "decrease"),
        ("enabled", "disabled"),
        ("allow", "deny"),
        ("before", "after"),
        ("open", "close")
    ]
    let left = incoming.lowercased()
    let right = existing.lowercased()
    for (positive, negative) in pairs {
        if (left.contains(positive) && right.contains(negative)) ||
            (left.contains(negative) && right.contains(positive)) {
            return true
        }
    }
    return false
}
