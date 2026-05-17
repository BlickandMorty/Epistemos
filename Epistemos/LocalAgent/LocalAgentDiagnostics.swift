import Foundation

nonisolated enum LocalAgentDiagnostics {
    static let defaultsKey = "epistemos.localAgent.schemaDriftCounters.v1"
    static let didChangeNotification = Notification.Name("LocalAgentDiagnosticsDidChange")

    enum EventKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
        case strictGrammarFallback = "strict_grammar_fallback"
        case softGuidanceToolPlan = "soft_guidance_tool_plan"
        case toolParseFailure = "tool_parse_failure"
        case explicitToolRepair = "explicit_tool_repair"

        var displayName: String {
            switch self {
            case .strictGrammarFallback: "Strict-grammar fallback"
            case .softGuidanceToolPlan: "Soft-guidance plan"
            case .toolParseFailure: "Tool parse failure"
            case .explicitToolRepair: "Tool repair prompt"
            }
        }
    }

    struct ModelCounter: Codable, Sendable, Equatable, Identifiable {
        let modelID: String
        let grammarRawValue: String
        var strictGrammarFallbacks: Int
        var softGuidanceToolPlans: Int
        var toolParseFailures: Int
        var explicitToolRepairs: Int
        var updatedAt: Date?

        var id: String { modelID }

        var displayName: String {
            if modelID == unknownModelID { return "Unknown local model" }
            return LocalTextModelID(rawValue: modelID)?.displayName ?? modelID
        }

        var grammar: LocalToolGrammar.NativeToolGrammar {
            LocalToolGrammar.NativeToolGrammar(rawValue: grammarRawValue) ?? .canonicalXML
        }

        var grammarDisplayName: String {
            grammar.displayName
        }

        var schemaDriftEvents: Int {
            toolParseFailures + explicitToolRepairs
        }

        var totalEvents: Int {
            strictGrammarFallbacks + softGuidanceToolPlans + schemaDriftEvents
        }

        static func empty(
            modelID: String,
            grammar: LocalToolGrammar.NativeToolGrammar
        ) -> ModelCounter {
            ModelCounter(
                modelID: modelID,
                grammarRawValue: grammar.rawValue,
                strictGrammarFallbacks: 0,
                softGuidanceToolPlans: 0,
                toolParseFailures: 0,
                explicitToolRepairs: 0,
                updatedAt: nil
            )
        }
    }

    struct ConstellationRole: Sendable, Equatable, Identifiable {
        let taskClass: ConfidenceRouter.TaskClass
        let primaryModelID: String?
        let primaryModelName: String
        let grammar: LocalToolGrammar.NativeToolGrammar

        var id: String { taskClass.rawValue }

        var displayName: String {
            taskClass.rawValue
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }

    enum ConstellationRuntimeState: String, Codable, Sendable, Equatable, Hashable {
        case hot
        case warm
        case cold

        var displayName: String {
            switch self {
            case .hot: "HOT"
            case .warm: "WARM"
            case .cold: "COLD"
            }
        }

        var sortRank: Int {
            switch self {
            case .hot: 0
            case .warm: 1
            case .cold: 2
            }
        }
    }

    struct ActiveConstellationModel: Sendable, Equatable, Identifiable {
        let modelID: String
        let displayName: String
        let state: ConstellationRuntimeState
        let schemaMode: String
        let grammar: LocalToolGrammar.NativeToolGrammar
        let roles: [String]
        let isInstalled: Bool

        var id: String { modelID }

        var rolesSummary: String {
            roles.isEmpty ? "No explicit route" : roles.joined(separator: ", ")
        }

        var schemaSummary: String {
            "\(schemaMode) · \(grammar.displayName)"
        }
    }

    struct Snapshot: Sendable, Equatable {
        let capturedAt: Date
        let strictMaskingAvailable: Bool
        let softGuidanceAvailable: Bool
        let modelCounters: [ModelCounter]
        let constellationRoles: [ConstellationRole]
        let routeProfiles: [ConfidenceRouter.RouteProfile]

        var totalStrictGrammarFallbacks: Int {
            modelCounters.reduce(0) { $0 + $1.strictGrammarFallbacks }
        }

        var totalSoftGuidanceToolPlans: Int {
            modelCounters.reduce(0) { $0 + $1.softGuidanceToolPlans }
        }

        var totalToolParseFailures: Int {
            modelCounters.reduce(0) { $0 + $1.toolParseFailures }
        }

        var totalExplicitToolRepairs: Int {
            modelCounters.reduce(0) { $0 + $1.explicitToolRepairs }
        }

        var totalSchemaDriftEvents: Int {
            totalToolParseFailures + totalExplicitToolRepairs
        }

        var modelCountWithDrift: Int {
            modelCounters.filter { $0.schemaDriftEvents > 0 }.count
        }

        var strictGrammarSummary: String {
            if strictMaskingAvailable {
                if totalStrictGrammarFallbacks == 0 {
                    return "MLXStructured masking is linked; no strict fallback recorded."
                }
                return "MLXStructured linked; \(totalStrictGrammarFallbacks) strict fallback events recorded."
            }
            return "Strict masking is unavailable in this target; soft guidance is the active boundary."
        }

        var softGuidanceSummary: String {
            if totalSoftGuidanceToolPlans == 0 {
                return softGuidanceAvailable
                    ? "Soft-guidance fallback is armed; no tool-plan fallback recorded."
                    : "Soft-guidance fallback is unavailable."
            }
            return "\(totalSoftGuidanceToolPlans) tool plans used soft guidance."
        }

        var schemaDriftSummary: String {
            if totalSchemaDriftEvents == 0 {
                return "0 parse failures or repair prompts recorded."
            }
            return "\(totalSchemaDriftEvents) events across \(modelCountWithDrift) models: \(totalToolParseFailures) parse · \(totalExplicitToolRepairs) repair."
        }

        var constellationSummary: String {
            let roleCount = constellationRoles.count
            let primaryCount = Set(constellationRoles.compactMap(\.primaryModelID)).count
            return "\(roleCount) task roles · \(primaryCount) primary local models · \(LocalToolGrammar.NativeToolGrammar.allCases.count) grammar profiles · \(LocalAgentDiagnostics.idleUnloadPolicySummary)."
        }

        var routePolicySummary: String {
            let strictRoutes = routeProfiles.filter { $0.nativeGrammar != .canonicalXML }.count
            return "\(routeProfiles.count) task-class routes · \(strictRoutes) native grammar routes · \(LocalAgentDiagnostics.idleUnloadPolicySummary)."
        }

        var hotRoleSummary: String {
            let roles = constellationRoles.prefix(4).map { role in
                "\(role.displayName): \(role.primaryModelName)"
            }
            return roles.isEmpty ? "No router roles configured." : roles.joined(separator: " · ")
        }
    }

    private struct Store: Codable, Equatable {
        let schemaVersion: Int
        var counters: [ModelCounter]
    }

    private static let schemaVersion = 1
    private static let unknownModelID = "unknown"

    static var idleUnloadPolicySummary: String {
        ConfidenceRouter.localAgentIdleUnloadPolicySummary
    }

    static func record(
        _ eventKind: EventKind,
        modelID: String?,
        nativeGrammar: LocalToolGrammar.NativeToolGrammar? = nil,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        let resolvedModelID = normalizedModelID(modelID)
        let resolvedGrammar = nativeGrammar ?? LocalToolGrammar.nativeGrammar(forModelID: modelID)
        var store = loadStore(defaults: defaults)
        var counters = store.counters
        let index = counters.firstIndex { $0.modelID == resolvedModelID }
        var counter = index.map { counters[$0] } ?? ModelCounter.empty(
            modelID: resolvedModelID,
            grammar: resolvedGrammar
        )

        counter = incremented(counter, eventKind: eventKind, grammar: resolvedGrammar, now: now)

        if let index {
            counters[index] = counter
        } else {
            counters.append(counter)
        }

        store.counters = normalize(counters)
        saveStore(store, defaults: defaults)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    static func snapshot(
        defaults: UserDefaults = .standard,
        capturedAt: Date = Date()
    ) -> Snapshot {
        Snapshot(
            capturedAt: capturedAt,
            strictMaskingAvailable: LocalToolGrammar.supportsStructuredToolCalling,
            softGuidanceAvailable: LocalToolGrammar.supportsSoftGuidanceToolCalling,
            modelCounters: normalize(loadStore(defaults: defaults).counters),
            constellationRoles: constellationRoles(),
            routeProfiles: ConfidenceRouter.routeProfiles()
        )
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static func loadStore(defaults: UserDefaults) -> Store {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let store = try? JSONDecoder().decode(Store.self, from: data),
            store.schemaVersion == schemaVersion
        else {
            return Store(schemaVersion: schemaVersion, counters: [])
        }
        return Store(schemaVersion: schemaVersion, counters: normalize(store.counters))
    }

    static func activeConstellationModels(
        activeAgentModelID: String?,
        activeChatModelID: String?,
        latestRuntimeModelID: String?,
        installedModelIDs: Set<String>,
        roles: [ConstellationRole]? = nil,
        strictMaskingAvailable: Bool = LocalToolGrammar.supportsStructuredToolCalling
    ) -> [ActiveConstellationModel] {
        let routeRoles = roles ?? constellationRoles()
        var rolesByModelID: [String: [String]] = [:]
        for role in routeRoles {
            guard let modelID = role.primaryModelID else { continue }
            rolesByModelID[modelID, default: []].append(role.displayName)
        }

        var modelIDs = Set(rolesByModelID.keys)
        [activeAgentModelID, activeChatModelID, latestRuntimeModelID]
            .compactMap(normalizedOptionalModelID)
            .forEach { modelIDs.insert($0) }

        let schemaMode = strictMaskingAvailable ? "STRICT" : "SOFT"
        return modelIDs.map { modelID in
            let model = LocalTextModelID(rawValue: modelID)
            return ActiveConstellationModel(
                modelID: modelID,
                displayName: model?.displayName ?? modelID,
                state: runtimeState(
                    modelID: modelID,
                    activeAgentModelID: activeAgentModelID,
                    activeChatModelID: activeChatModelID,
                    latestRuntimeModelID: latestRuntimeModelID,
                    installedModelIDs: installedModelIDs
                ),
                schemaMode: schemaMode,
                grammar: LocalToolGrammar.nativeGrammar(forModelID: modelID),
                roles: (rolesByModelID[modelID] ?? []).sorted(),
                isInstalled: installedModelIDs.contains(modelID)
            )
        }
        .sorted { lhs, rhs in
            if lhs.state.sortRank == rhs.state.sortRank {
                if lhs.roles.count == rhs.roles.count {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.roles.count > rhs.roles.count
            }
            return lhs.state.sortRank < rhs.state.sortRank
        }
    }

    private static func saveStore(_ store: Store, defaults: UserDefaults) {
        let normalizedStore = Store(
            schemaVersion: schemaVersion,
            counters: normalize(store.counters)
        )
        guard let data = try? JSONEncoder().encode(normalizedStore) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private static func incremented(
        _ counter: ModelCounter,
        eventKind: EventKind,
        grammar: LocalToolGrammar.NativeToolGrammar,
        now: Date
    ) -> ModelCounter {
        var next = ModelCounter(
            modelID: counter.modelID,
            grammarRawValue: grammar.rawValue,
            strictGrammarFallbacks: counter.strictGrammarFallbacks,
            softGuidanceToolPlans: counter.softGuidanceToolPlans,
            toolParseFailures: counter.toolParseFailures,
            explicitToolRepairs: counter.explicitToolRepairs,
            updatedAt: now
        )
        switch eventKind {
        case .strictGrammarFallback:
            next.strictGrammarFallbacks += 1
        case .softGuidanceToolPlan:
            next.softGuidanceToolPlans += 1
        case .toolParseFailure:
            next.toolParseFailures += 1
        case .explicitToolRepair:
            next.explicitToolRepairs += 1
        }
        return next
    }

    private static func normalize(_ counters: [ModelCounter]) -> [ModelCounter] {
        var byModel: [String: ModelCounter] = [:]
        for counter in counters {
            let modelID = normalizedModelID(counter.modelID)
            let existing = byModel[modelID]
            byModel[modelID] = ModelCounter(
                modelID: modelID,
                grammarRawValue: counter.grammarRawValue,
                strictGrammarFallbacks: (existing?.strictGrammarFallbacks ?? 0) + max(0, counter.strictGrammarFallbacks),
                softGuidanceToolPlans: (existing?.softGuidanceToolPlans ?? 0) + max(0, counter.softGuidanceToolPlans),
                toolParseFailures: (existing?.toolParseFailures ?? 0) + max(0, counter.toolParseFailures),
                explicitToolRepairs: (existing?.explicitToolRepairs ?? 0) + max(0, counter.explicitToolRepairs),
                updatedAt: [existing?.updatedAt, counter.updatedAt].compactMap(\.self).max()
            )
        }
        return byModel.values
            .filter { $0.totalEvents > 0 }
            .sorted { lhs, rhs in
                if lhs.totalEvents == rhs.totalEvents {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.totalEvents > rhs.totalEvents
            }
    }

    private static func constellationRoles() -> [ConstellationRole] {
        ConfidenceRouter.routeProfiles().map { profile in
            return ConstellationRole(
                taskClass: profile.taskClass,
                primaryModelID: profile.primaryModelID,
                primaryModelName: profile.primaryModelName,
                grammar: profile.nativeGrammar
            )
        }
    }

    private static func normalizedModelID(_ modelID: String?) -> String {
        let trimmed = (modelID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? unknownModelID : trimmed
    }

    private static func normalizedOptionalModelID(_ modelID: String?) -> String? {
        let trimmed = (modelID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func runtimeState(
        modelID: String,
        activeAgentModelID: String?,
        activeChatModelID: String?,
        latestRuntimeModelID: String?,
        installedModelIDs: Set<String>
    ) -> ConstellationRuntimeState {
        let normalizedAgent = normalizedOptionalModelID(activeAgentModelID)
        let normalizedChat = normalizedOptionalModelID(activeChatModelID)
        let normalizedRuntime = normalizedOptionalModelID(latestRuntimeModelID)
        if modelID == normalizedRuntime || modelID == normalizedAgent {
            return .hot
        }
        if modelID == normalizedChat || installedModelIDs.contains(modelID) {
            return .warm
        }
        return .cold
    }
}
