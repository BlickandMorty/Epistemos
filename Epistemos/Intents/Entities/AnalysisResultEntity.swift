import AppIntents

// MARK: - Analysis Result Entity
// Represents the output of a pipeline analysis — evidence grade,
// confidence, summary, and identified weaknesses.
// Used by DeepAnalyzeIntent and FactCheckIntent.

struct AnalysisResultEntity: AppEntity, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Analysis Result")
    nonisolated(unsafe) static var defaultQuery = AnalysisResultEntityQuery()

    var id: String
    @Property(title: "Grade") var grade: String // A/B/C/D/F
    @Property(title: "Confidence") var confidence: Double
    @Property(title: "Summary") var summary: String
    @Property(title: "Weaknesses") var weaknesses: String

    init(id: String = UUID().uuidString, grade: String = "C", confidence: Double = 0.5, summary: String = "", weaknesses: String = "") {
        self.id = id
        self.grade = grade
        self.confidence = confidence
        self.summary = summary
        self.weaknesses = weaknesses
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Grade \(grade)", subtitle: "\(Int(confidence * 100))% confidence")
    }
}

// MARK: - Analysis Result Entity Query

struct AnalysisResultEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [AnalysisResultEntity] {
        // Analysis results are ephemeral — not persisted
        []
    }

    func entities(matching string: String) async throws -> [AnalysisResultEntity] {
        // Analysis results are ephemeral — not persisted
        []
    }
}
