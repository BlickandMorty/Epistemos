import Foundation

nonisolated enum AdvertisedModelPolicy {
    static func effectiveAdvertised(
        persisted: [String]?,
        canonDefaults: [String],
        fullCatalog: Set<String>
    ) -> [String] { [] }

    static func advertising(_ id: String, in current: [String]) -> [String] { current }
    static func unadvertising(_ id: String, in current: [String]) -> [String] { current }
    static func toggling(_ id: String, in current: [String]) -> [String] { current }
    static func isAdvertised(_ id: String, in current: [String]) -> Bool { false }
}

nonisolated struct AdvertisedModelStore {
    static let persistenceKey = "epistemos.advertisedModelIDs.v1"
    static var canonDefaults: [String] { [] }

    init(defaults: UserDefaults = .standard) {}

    var persistedSelection: [String]? { nil }
    var isCustomized: Bool { false }
    func effectiveAdvertised(fullCatalog: Set<String>) -> [String] { [] }
    func isAdvertised(_ id: String, fullCatalog: Set<String>) -> Bool { false }
    func setAdvertised(_ ids: [String]) {}
    func toggleAdvertised(_ id: String, fullCatalog: Set<String>) {}
    func resetToCanonDefaults() {}
}

nonisolated struct ModelStackRow: Identifiable, Sendable, Equatable {
    let id: String
    let displayName: String
    let summary: String
    let sizeText: String
    let ramText: String
    let isInstalled: Bool
    let isAdvertised: Bool
}

nonisolated struct ModelStackSource: Sendable, Equatable {
    let id: String
    let displayName: String
    let summary: String
    let approximateDownloadBytes: Int64
    let minimumRecommendedMemoryGB: Int
}

nonisolated enum ModelStackAssembler {
    static func sizeText(bytes: Int64) -> String { "0 KB" }
    static func ramText(gb: Int) -> String { "unavailable" }

    static func rows(
        sources: [ModelStackSource],
        installedIDs: Set<String>,
        advertisedIDs: [String]
    ) -> [ModelStackRow] { [] }
}
