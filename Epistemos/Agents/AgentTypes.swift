import Foundation

// MARK: - Agent Identity

enum AgentID: String, Sendable, Codable, CaseIterable {
    case triage
    case librarian
    case writer
    case builder

    nonisolated var displayName: String {
        switch self {
        case .triage: "Triage"
        case .librarian: "Librarian"
        case .writer: "Writer"
        case .builder: "Builder"
        }
    }

    nonisolated var iconName: String {
        switch self {
        case .triage: "arrow.triangle.branch"
        case .librarian: "books.vertical"
        case .writer: "pencil.and.outline"
        case .builder: "wrench.and.screwdriver"
        }
    }
}

// MARK: - Agent Lifecycle

enum AgentStatus: Sendable, Equatable {
    case idle
    case thinking
    case working(task: String)
    case waitingForApproval(action: String)
    case error(String)

    nonisolated var isActive: Bool {
        switch self {
        case .thinking, .working: true
        default: false
        }
    }

    nonisolated var label: String {
        switch self {
        case .idle: "Idle"
        case .thinking: "Thinking…"
        case .working(let task): "Working: \(task)"
        case .waitingForApproval(let action): "Needs approval: \(action)"
        case .error(let msg): "Error: \(msg)"
        }
    }
}

// MARK: - Trust Levels

enum TrustLevel: String, Sendable, Codable, Comparable {
    case sandbox
    case standard
    case elevated

    nonisolated private var rank: Int {
        switch self {
        case .sandbox: 0
        case .standard: 1
        case .elevated: 2
        }
    }

    nonisolated static func < (lhs: TrustLevel, rhs: TrustLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

// MARK: - Agent Task

struct AgentTask: Identifiable, Sendable {
    let id: String
    let from: AgentID
    let to: AgentID
    let instruction: String
    let context: String
    let createdAt: Date

    init(from: AgentID, to: AgentID, instruction: String, context: String = "") {
        self.id = UUID().uuidString
        self.from = from
        self.to = to
        self.instruction = instruction
        self.context = context
        self.createdAt = Date()
    }
}

// MARK: - Agent Result

struct AgentResult: Sendable {
    let taskId: String
    let from: AgentID
    let output: String
    let artifacts: [AgentArtifact]

    init(taskId: String, from: AgentID, output: String, artifacts: [AgentArtifact] = []) {
        self.taskId = taskId
        self.from = from
        self.output = output
        self.artifacts = artifacts
    }
}

// MARK: - Artifacts

enum ArtifactType: String, Sendable, Codable {
    case file
    case note
    case draft
    case searchResult
    case codeBlock
}

struct AgentArtifact: Sendable {
    let type: ArtifactType
    let path: String?
    let content: String?
}

// MARK: - Agent Protocol

@MainActor
protocol AgentProtocol: AnyObject {
    var id: AgentID { get }
    var status: AgentStatus { get }
    var trustLevel: TrustLevel { get set }

    func handleTask(_ task: AgentTask) async
    func handleMention(from: AgentID, context: String, request: String) async -> String
    func handleInsight(_ insight: String, from: AgentID)
    func cancel()
}

// MARK: - Indexable Content (for Learning Pool)

struct IndexableContent: Sendable {
    let title: String
    let body: String
    let source: AgentID
    let tags: [String]
}

// MARK: - Search Types

struct SearchQuery: Sendable {
    let text: String
    let maxResults: Int
    let from: AgentID
}

struct SearchChunk: Sendable, Identifiable {
    let id: String
    let content: String
    let source: String
    let relevanceScore: Double
}

// MARK: - Triage Classification

enum TriageClassification: String, Sendable, Codable {
    case direct
    case librarian
    case writer
    case builder
    case learningPool
}
