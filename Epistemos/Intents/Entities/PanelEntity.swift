import AppIntents

// MARK: - Panel Entity
// Maps to NavTab enum cases for panel navigation.
// Used by OpenPanelIntent to let Siri/Shortcuts navigate the app.

struct PanelEntity: AppEntity, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Panel")
    }
    static var defaultQuery: PanelEntityQuery {
        PanelEntityQuery()
    }

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
        identifiers.compactMap { id in
            NavTab(rawValue: id).map { PanelEntity(tab: $0) }
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<PanelEntity> {
        let filtered = searchablePanels.filter { $0.name.localizedCaseInsensitiveContains(string) }
        return IntentItemCollection(items: filtered)
    }

    func suggestedEntities() async throws -> IntentItemCollection<PanelEntity> {
        IntentItemCollection(items: searchablePanels)
    }

    /// Derived from the supported NavTab cases so Shortcuts stays aligned with in-scope panels.
    private var searchablePanels: [PanelEntity] {
        AppIntentSearchSupport.searchableTabs.map { PanelEntity(tab: $0) }
    }
}
