import Foundation
import Observation
import os

nonisolated enum LocalTextModelID: String, Codable, Sendable, CaseIterable {
    case qwen35_0_8B4Bit = "mlx-community/Qwen3.5-0.8B-4bit"
    case qwen35_2B4Bit = "mlx-community/Qwen3.5-2B-4bit"
    case qwen35_4B4Bit = "mlx-community/Qwen3.5-4B-4bit"
    case qwen35_9B4Bit = "mlx-community/Qwen3.5-9B-4bit"
    case qwen35_27B4Bit = "mlx-community/Qwen3.5-27B-4bit"
    case qwen35_35BA3B4Bit = "mlx-community/Qwen3.5-35B-A3B-4bit"

    var displayName: String {
        switch self {
        case .qwen35_0_8B4Bit: "Qwen 3.5 0.8B 4-bit"
        case .qwen35_2B4Bit: "Qwen 3.5 2B 4-bit"
        case .qwen35_4B4Bit: "Qwen 3.5 4B 4-bit"
        case .qwen35_9B4Bit: "Qwen 3.5 9B 4-bit"
        case .qwen35_27B4Bit: "Qwen 3.5 27B 4-bit"
        case .qwen35_35BA3B4Bit: "Qwen 3.5 35B-A3B 4-bit"
        }
    }

    var familyName: String {
        "Qwen 3.5"
    }

    var minimumRecommendedMemoryGB: Int {
        switch self {
        case .qwen35_0_8B4Bit: 8
        case .qwen35_2B4Bit: 12
        case .qwen35_4B4Bit: 16
        case .qwen35_9B4Bit: 24
        case .qwen35_27B4Bit: 48
        case .qwen35_35BA3B4Bit: 64
        }
    }

    nonisolated static var ascendingBySize: [LocalTextModelID] {
        allCases.sorted { lhs, rhs in
            lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
        }
    }
}

nonisolated enum LocalRoutingMode: String, Codable, Sendable, CaseIterable {
    case auto
    case localOnly

    var displayName: String {
        switch self {
        case .auto: "Auto"
        case .localOnly: "Local Only"
        }
    }

    var summary: String {
        switch self {
        case .auto:
            "Apple Intelligence handles the lightest local work. Qwen 3.5 handles deeper local tasks."
        case .localOnly:
            "Always use local Qwen 3.5. Apple Intelligence is bypassed."
        }
    }
}

nonisolated enum LocalReasoningMode: String, Codable, Sendable, CaseIterable {
    case fast
    case thinking

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .thinking: "Thinking"
        }
    }
}

nonisolated enum LocalModelInstallStateSummary: String, Codable, Sendable {
    case none
    case installed

    var displayName: String {
        switch self {
        case .none: "None"
        case .installed: "Installed"
        }
    }
}

nonisolated enum LocalRuntimeThermalState: String, Codable, Sendable, Equatable {
    case nominal
    case fair
    case serious
    case critical

    init(_ thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .serious
        }
    }

    var isSeverelyConstrained: Bool {
        switch self {
        case .serious, .critical:
            true
        case .nominal, .fair:
            false
        }
    }
}

nonisolated struct LocalRuntimeConditions: Sendable, Equatable {
    let lowPowerModeEnabled: Bool
    let appActive: Bool
    let thermalState: LocalRuntimeThermalState

    static func current(appActive: Bool = true) -> LocalRuntimeConditions {
        LocalRuntimeConditions(
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            appActive: appActive,
            thermalState: LocalRuntimeThermalState(ProcessInfo.processInfo.thermalState)
        )
    }

    var prefersConstrainedLocalModel: Bool {
        lowPowerModeEnabled || !appActive || thermalState != .nominal
    }

    var allowsAutomaticLocalRouting: Bool {
        appActive && thermalState != .critical
    }
}

nonisolated enum LocalModelSelectionSurface: String, Sendable, Equatable {
    case mainChat
    case miniChat
    case commandPalette
    case noteChat
    case graph
}

nonisolated struct LocalModelSelection: Sendable, Equatable {
    let modelID: String
    let reasoningMode: LocalReasoningMode
    let contentBudget: Int
}

nonisolated struct LocalHardwareCapabilitySnapshot: Sendable, Equatable {
    let physicalMemoryBytes: UInt64
    let roundedMemoryGB: Int
    let maxRecommendedLocalContentLength: Int

    static var current: LocalHardwareCapabilitySnapshot {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let roundedGB = max(8, Int((physicalMemory + 999_999_999) / 1_000_000_000))
        let maxContentLength: Int
        switch roundedGB {
        case ..<16:
            maxContentLength = 4_000
        case ..<24:
            maxContentLength = 10_000
        case ..<36:
            maxContentLength = 18_000
        default:
            maxContentLength = 28_000
        }
        return LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: physicalMemory,
            roundedMemoryGB: roundedGB,
            maxRecommendedLocalContentLength: maxContentLength
        )
    }

    nonisolated func supports(textModelID: String) -> Bool {
        guard let model = LocalTextModelID(rawValue: textModelID) else { return false }
        return roundedMemoryGB >= model.minimumRecommendedMemoryGB
    }

    nonisolated var recommendedLocalTextModelID: LocalTextModelID {
        switch roundedMemoryGB {
        case ..<12:
            .qwen35_0_8B4Bit
        case ..<16:
            .qwen35_2B4Bit
        case ..<24:
            .qwen35_4B4Bit
        case ..<48:
            .qwen35_9B4Bit
        case ..<64:
            .qwen35_27B4Bit
        default:
            .qwen35_35BA3B4Bit
        }
    }

    nonisolated func smallerLocalTextModelID(than modelID: LocalTextModelID) -> LocalTextModelID? {
        guard let index = LocalTextModelID.ascendingBySize.firstIndex(of: modelID),
              index > 0 else {
            return nil
        }
        return LocalTextModelID.ascendingBySize[index - 1]
    }

    nonisolated var recommendedConstrainedLocalTextModelID: LocalTextModelID? {
        smallerLocalTextModelID(than: recommendedLocalTextModelID)
    }

    nonisolated var baseLocalRuntimeContentLength: Int {
        switch roundedMemoryGB {
        case ..<12:
            3_200
        case ..<16:
            4_800
        case ..<24:
            8_000
        case ..<36:
            12_000
        default:
            min(maxRecommendedLocalContentLength, 22_000)
        }
    }

    nonisolated func recommendedLocalTextModelID(for conditions: LocalRuntimeConditions) -> LocalTextModelID {
        let baseline = recommendedLocalTextModelID
        guard conditions.prefersConstrainedLocalModel,
              let constrained = smallerLocalTextModelID(than: baseline) else {
            return baseline
        }
        return constrained
    }

    nonisolated func recommendedLocalContentLength(
        for conditions: LocalRuntimeConditions,
        reasoningMode: LocalReasoningMode = .fast
    ) -> Int {
        _ = reasoningMode
        var total = min(maxRecommendedLocalContentLength, baseLocalRuntimeContentLength)
        if conditions.lowPowerModeEnabled {
            total = Int(Double(total) * 0.82)
        }
        if !conditions.appActive {
            total = Int(Double(total) * 0.72)
        }
        switch conditions.thermalState {
        case .nominal:
            break
        case .fair:
            total = Int(Double(total) * 0.92)
        case .serious:
            total = Int(Double(total) * 0.75)
        case .critical:
            total = Int(Double(total) * 0.60)
        }
        return max(1_800, total)
    }
}

// MARK: - Inference State
// Manages the local-only AI stack: Apple Intelligence availability,
// Qwen 3.5 model policy, and runtime conditions.

@MainActor @Observable
final class InferenceState {
    private nonisolated static let legacyRemoteDefaultsKeys = [
        "epistemos.apiProvider",
        "epistemos.anthropicModel",
        "epistemos.openaiModel",
        "epistemos.googleModel",
        "epistemos.kimiModel",
        "epistemos.ollamaBaseUrl",
        "epistemos.ollamaModel",
        "epistemos.preferredVoiceEngineID",
        "epistemos.preferredVoiceID",
        "epistemos.localAutoDownloadEnabled",
        "epistemos.smartRoutingEnabled",
        "epistemos.offlineOnlyEnabled",
        "epistemos.preferredFallbackLocalTextModelID",
    ]

    var inferenceMode: InferenceMode = .analytical
    var routingMode: LocalRoutingMode = .auto
    var preferredLocalTextModelID: String = LocalHardwareCapabilitySnapshot.current.recommendedLocalTextModelID.rawValue
    private(set) var installedLocalTextModelIDs: Set<String> = []
    private(set) var localRuntimeConditions: LocalRuntimeConditions = .current()
    let hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot = .current
    private let policyEngine = InferencePolicyEngine()

    var appleIntelligenceAvailable: Bool = false
    var appleIntelligenceUnavailableReason: String?

    /// Max tokens for user-visible chat responses. 0 = no cap (model default, ~16k).
    var chatOutputTokens: Int = 0

    init() {
        let (available, reason) = AppleIntelligenceService.shared.checkAvailability()
        self.appleIntelligenceAvailable = available
        self.appleIntelligenceUnavailableReason = reason

        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: "epistemos.localRoutingMode"),
           let mode = LocalRoutingMode(rawValue: saved) {
            self.routingMode = mode
        } else if defaults.object(forKey: "epistemos.offlineOnlyEnabled") != nil,
                  defaults.bool(forKey: "epistemos.offlineOnlyEnabled") {
            self.routingMode = .localOnly
        }
        if let saved = defaults.string(forKey: "epistemos.preferredLocalTextModelID"),
           LocalTextModelID(rawValue: saved) != nil {
            self.preferredLocalTextModelID = saved
        }
        defaults.removeObject(forKey: "epistemos.automaticLocalModelSelectionEnabled")
        defaults.removeObject(forKey: "epistemos.preferredLocalReasoningMode")
        defaults.removeObject(forKey: "epistemos.showLocalThinkingPanel")
        self.chatOutputTokens = defaults.integer(forKey: "epistemos.chatOutputTokens")  // 0 if unset

        Self.purgeLegacyRemoteConfiguration(defaults: defaults)
    }

    static func purgeLegacyRemoteConfiguration(defaults: UserDefaults = .standard) {
        for key in legacyRemoteDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    func setInferenceMode(_ mode: InferenceMode) { inferenceMode = mode }

    var localModelInstallStateSummary: LocalModelInstallStateSummary {
        installedLocalTextModelIDs.isEmpty ? .none : .installed
    }

    var policyContext: InferencePolicyContext {
        InferencePolicyContext(
            routingMode: routingMode,
            appleIntelligenceAvailable: appleIntelligenceAvailable,
            preferredLocalTextModelID: preferredLocalTextModelID,
            installedLocalTextModelIDs: installedLocalTextModelIDs,
            hardwareCapabilitySnapshot: hardwareCapabilitySnapshot,
            runtimeConditions: localRuntimeConditions
        )
    }

    private var supportedInstalledLocalTextModels: [LocalTextModelID] {
        installedLocalTextModelIDs
            .compactMap(LocalTextModelID.init(rawValue:))
            .filter { hardwareCapabilitySnapshot.supports(textModelID: $0.rawValue) }
            .sorted { lhs, rhs in
                lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
            }
    }

    var effectiveLocalTextModelID: String? {
        policyEngine.resolvedPreferredLocalSelection(in: policyContext)?.modelID
    }

    var hasUsableLocalTextModel: Bool {
        effectiveLocalTextModelID != nil
    }

    var activeLocalTextModelID: String? {
        return effectiveLocalTextModelID
    }

    var activeLocalTextModelDisplayName: String {
        guard let modelID = activeLocalTextModelID,
              let model = LocalTextModelID(rawValue: modelID) else {
            return "Qwen 3.5"
        }
        return model.displayName
    }

    func routeDecision(for profile: InferenceRequestProfile) -> InferenceRouteDecision {
        policyEngine.decide(profile: profile, context: policyContext)
    }

    func localModelSelection(for profile: InferenceRequestProfile) -> LocalModelSelection? {
        policyEngine.localSelection(for: profile, context: policyContext)
    }

    func canAutomaticallyRouteToLocalMLX(for profile: InferenceRequestProfile) -> Bool {
        guard localRuntimeConditions.allowsAutomaticLocalRouting else { return false }
        guard let selection = localModelSelection(for: profile) else { return false }
        guard hardwareCapabilitySnapshot.supports(textModelID: selection.modelID) else { return false }
        return profile.contentLength <= selection.contentBudget
    }

    func canRouteToLocalMLX(contentLength: Int) -> Bool {
        canAutomaticallyRouteToLocalMLX(
            for: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: contentLength,
                promptLength: contentLength,
                contextBlockCount: max(1, contentLength / 2_400),
                estimatedTokenLoad: max(1, contentLength / 4),
                baseComplexity: 0.35,
                queryComplexity: 0,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            )
        )
    }

    func setChatOutputTokens(_ tokens: Int) {
        chatOutputTokens = max(0, tokens)
        UserDefaults.standard.set(chatOutputTokens, forKey: "epistemos.chatOutputTokens")
    }

    func setRoutingMode(_ mode: LocalRoutingMode) {
        routingMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "epistemos.localRoutingMode")
    }

    func setPreferredLocalTextModelID(_ modelID: String) {
        guard LocalTextModelID(rawValue: modelID) != nil else { return }
        preferredLocalTextModelID = modelID
        UserDefaults.standard.set(modelID, forKey: "epistemos.preferredLocalTextModelID")
    }

    func setLocalRuntimeConditions(_ conditions: LocalRuntimeConditions) {
        localRuntimeConditions = conditions
    }

    func setInstalledLocalTextModelIDs(_ ids: Set<String>) {
        installedLocalTextModelIDs = ids
    }
}
