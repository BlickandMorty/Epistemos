import AppIntents

// MARK: - Research Stage Entity
// Maps to PipelineStage enum. Used by RunAnalysisIntent and RunTriageIntent
// to let users target specific stages of the analysis pipeline.

struct ResearchStageEntity: AppEntity, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Research Stage")
    nonisolated(unsafe) static var defaultQuery = ResearchStageEntityQuery()

    var id: String
    var name: String
    var description: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(description)")
    }

    /// Create an entity from a PipelineStage enum case.
    init(stage: PipelineStage) {
        self.id = stage.rawValue.lowercased()
        self.name = stage.displayName
        self.description = stage.stageDescription
    }

    init(id: String, name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
}

// MARK: - Research Stage Entity Query

struct ResearchStageEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ResearchStageEntity] {
        allStages.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<ResearchStageEntity> {
        let filtered = allStages.filter { $0.name.localizedCaseInsensitiveContains(string) }
        return IntentItemCollection(items: filtered)
    }

    func suggestedEntities() async throws -> IntentItemCollection<ResearchStageEntity> {
        IntentItemCollection(items: allStages)
    }

    /// Derived from PipelineStage.allCases — single source of truth.
    private var allStages: [ResearchStageEntity] {
        PipelineStage.allCases.map { ResearchStageEntity(stage: $0) }
    }
}
