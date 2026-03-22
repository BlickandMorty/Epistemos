import AppIntents

// MARK: - Panel Entity
// Maps to NavTab enum cases for panel navigation.
// Used by OpenPanelIntent to let Siri/Shortcuts navigate the app.

struct PanelEntity: AppEntity, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Panel")
    nonisolated(unsafe) static var defaultQuery = PanelEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    /// Create an entity from a NavTab enum case.
    init(tab: NavTab) {
        self.id = tab.rawValue
        self.name = tab.displayName
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Panel Entity Query

struct PanelEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [PanelEntity] {
        allPanels.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<PanelEntity> {
        let filtered = allPanels.filter { $0.name.localizedCaseInsensitiveContains(string) }
        return IntentItemCollection(items: filtered)
    }

    func suggestedEntities() async throws -> IntentItemCollection<PanelEntity> {
        IntentItemCollection(items: allPanels)
    }

    /// Derived from NavTab.allCases — single source of truth.
    private var allPanels: [PanelEntity] {
        NavTab.allCases.map { PanelEntity(tab: $0) }
    }
}
