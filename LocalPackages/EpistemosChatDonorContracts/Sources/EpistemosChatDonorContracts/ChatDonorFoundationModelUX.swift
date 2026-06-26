import Foundation

public enum ChatDonorFoundationModelRuntime: String, CaseIterable, Codable, Hashable, Sendable {
    case onDevice = "on-device"
    case privateCloudCompute = "private-cloud-compute"

    public var displayName: String {
        switch self {
        case .onDevice:
            "On Device"
        case .privateCloudCompute:
            "Private Cloud Compute"
        }
    }

    public var shortName: String {
        switch self {
        case .onDevice:
            "On-device"
        case .privateCloudCompute:
            "PCC"
        }
    }

    public var modelIdentifier: String {
        switch self {
        case .onDevice:
            "system"
        case .privateCloudCompute:
            "pcc"
        }
    }

    public var systemImage: String {
        switch self {
        case .onDevice:
            "iphone"
        case .privateCloudCompute:
            "icloud"
        }
    }

    public var requiresNewSessionOnSelection: Bool {
        true
    }
}

public enum ChatDonorFoundationModelUnavailableReason: String, Codable, Hashable, Sendable {
    case deviceNotEligible = "device-not-eligible"
    case appleIntelligenceNotEnabled = "apple-intelligence-not-enabled"
    case modelNotReady = "model-not-ready"
    case systemNotReady = "system-not-ready"
    case unsupportedOperatingSystem = "unsupported-operating-system"
    case unsupportedToolchain = "unsupported-toolchain"
    case missingEntitlement = "missing-entitlement"
    case unknown

    public var displayDescription: String {
        switch self {
        case .deviceNotEligible:
            "device is not eligible"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is disabled"
        case .modelNotReady:
            "model assets are not ready"
        case .systemNotReady:
            "PCC is not ready"
        case .unsupportedOperatingSystem:
            "requires macOS 27 or later"
        case .unsupportedToolchain:
            "requires an Xcode 27-built runtime"
        case .missingEntitlement:
            "current process lacks the managed PCC entitlement"
        case .unknown:
            "unknown reason"
        }
    }
}

public enum ChatDonorFoundationModelAuthorization: String, Codable, Hashable, Sendable {
    case notRequired = "not-required"
    case granted
    case missing
    case unknown

    public var displayDescription: String {
        switch self {
        case .notRequired:
            "current-process authorization is not required"
        case .granted:
            "current-process authorization is granted"
        case .missing:
            "current process lacks the managed PCC entitlement"
        case .unknown:
            "current-process authorization is unknown"
        }
    }
}

public struct ChatDonorFoundationModelRuntimeStatus: Codable, Hashable, Sendable {
    public var runtime: ChatDonorFoundationModelRuntime
    public var isSupported: Bool
    public var isAvailable: Bool
    public var isRunnableInCurrentProcess: Bool
    public var authorization: ChatDonorFoundationModelAuthorization
    public var reason: ChatDonorFoundationModelUnavailableReason?

    public init(
        runtime: ChatDonorFoundationModelRuntime,
        isSupported: Bool = true,
        isAvailable: Bool,
        authorization: ChatDonorFoundationModelAuthorization = .notRequired,
        reason: ChatDonorFoundationModelUnavailableReason? = nil
    ) {
        self.runtime = runtime
        self.isSupported = isSupported
        self.isAvailable = isAvailable
        self.authorization = authorization

        let hasRequiredAuthorization = authorization == .granted
            || (runtime == .onDevice && authorization == .notRequired)
        isRunnableInCurrentProcess = isSupported
            && isAvailable
            && hasRequiredAuthorization
        self.reason = reason ?? Self.authorizationReason(
            runtime: runtime,
            authorization: authorization
        )
    }

    public var availabilityDescription: String {
        let name = runtime.modelIdentifier == "system" ? "System" : "PCC"
        if isRunnableInCurrentProcess {
            return "\(name): available"
        }
        if isAvailable {
            return "\(name): available, but not runnable in this process (\(authorization.displayDescription))"
        }
        return "\(name): unavailable (\((reason ?? .unknown).displayDescription))"
    }

    public var settingsActionRecommended: Bool {
        runtime == .onDevice && reason == .appleIntelligenceNotEnabled
    }

    private static func authorizationReason(
        runtime: ChatDonorFoundationModelRuntime,
        authorization: ChatDonorFoundationModelAuthorization
    ) -> ChatDonorFoundationModelUnavailableReason? {
        guard runtime == .privateCloudCompute else { return nil }
        switch authorization {
        case .missing:
            return .missingEntitlement
        case .unknown, .notRequired:
            return .unknown
        case .granted:
            return nil
        }
    }
}

public struct ChatDonorFoundationModelPickerOption: Codable, Hashable, Sendable {
    public var id: String
    public var runtime: ChatDonorFoundationModelRuntime
    public var title: String
    public var subtitle: String
    public var systemImage: String
    public var isEnabled: Bool
    public var requiresNewSessionOnSelection: Bool
    public var settingsActionRecommended: Bool

    public init(status: ChatDonorFoundationModelRuntimeStatus) {
        id = status.runtime.modelIdentifier
        runtime = status.runtime
        title = status.runtime.displayName
        subtitle = status.availabilityDescription
        systemImage = status.runtime.systemImage
        isEnabled = status.isRunnableInCurrentProcess
        requiresNewSessionOnSelection = status.runtime.requiresNewSessionOnSelection
        settingsActionRecommended = status.settingsActionRecommended
    }

    public static func options(from statuses: [ChatDonorFoundationModelRuntimeStatus]) -> [Self] {
        statuses.map(Self.init(status:))
    }
}

public struct ChatDonorFoundationModelAvailabilityNotice: Codable, Hashable, Sendable {
    public var title: String
    public var message: String
    public var settingsActionRecommended: Bool
    public var canBrowseWithoutModel: Bool

    public init(
        reason: ChatDonorFoundationModelUnavailableReason?,
        title: String = "Apple Intelligence Is Unavailable"
    ) {
        self.title = title
        settingsActionRecommended = reason == .appleIntelligenceNotEnabled
        canBrowseWithoutModel = true

        switch reason {
        case .deviceNotEligible:
            message = "This device does not support Apple Intelligence for the on-device model."
        case .appleIntelligenceNotEnabled:
            message = "Turn on Apple Intelligence in Settings, then try the on-device model again."
        case .modelNotReady:
            message = "The on-device model is still downloading. Try again when the download finishes."
        case .unknown, .none:
            message = "The on-device model is not available right now. You can still browse saved sessions."
        case .systemNotReady:
            message = "The Private Cloud Compute runtime is not ready yet."
        case .unsupportedOperatingSystem:
            message = "Private Cloud Compute requires a newer operating system runtime."
        case .unsupportedToolchain:
            message = "Private Cloud Compute requires a newer toolchain-built runtime."
        case .missingEntitlement:
            message = "This process is missing the managed Private Cloud Compute entitlement."
        }
    }
}

public enum ChatDonorFoundationModelReasoningLevel: String, CaseIterable, Codable, Hashable, Sendable {
    case none
    case light
    case moderate
    case deep

    public var displayName: String {
        switch self {
        case .none:
            "None"
        case .light:
            "Light"
        case .moderate:
            "Moderate"
        case .deep:
            "Deep"
        }
    }

    public var systemImage: String {
        switch self {
        case .none, .moderate:
            "brain"
        case .light:
            "bolt"
        case .deep:
            "brain.head.profile"
        }
    }

    public func isSelectable(for runtime: ChatDonorFoundationModelRuntime) -> Bool {
        runtime == .privateCloudCompute || self == .none
    }
}

public enum ChatDonorFoundationModelSamplingMode: Codable, Hashable, Sendable {
    case greedy
    case topK(Int, seed: UInt64? = nil)
    case topP(Double, seed: UInt64? = nil)

    public var seed: UInt64? {
        switch self {
        case .greedy:
            nil
        case .topK(_, let seed), .topP(_, let seed):
            seed
        }
    }
}

public struct ChatDonorFoundationModelGenerationOptions: Codable, Hashable, Sendable {
    public var sampling: ChatDonorFoundationModelSamplingMode?
    public var temperature: Double?
    public var maximumResponseTokens: Int?

    public init(
        sampling: ChatDonorFoundationModelSamplingMode? = nil,
        temperature: Double? = nil,
        maximumResponseTokens: Int? = nil
    ) {
        self.sampling = sampling
        self.temperature = temperature
        self.maximumResponseTokens = maximumResponseTokens
    }

    public var normalized: Self {
        let normalizedSampling: ChatDonorFoundationModelSamplingMode?
        switch sampling {
        case .greedy:
            normalizedSampling = .greedy
        case .topK(let top, let seed):
            normalizedSampling = .topK(max(1, top), seed: seed)
        case .topP(let threshold, let seed):
            let validThreshold = threshold.isFinite ? min(max(threshold, 0), 1) : 0.9
            normalizedSampling = .topP(validThreshold, seed: seed)
        case nil:
            normalizedSampling = nil
        }

        let normalizedTemperature = temperature.flatMap { value in
            value.isFinite ? min(max(0, value), 2) : nil
        }
        let normalizedMaximumResponseTokens = maximumResponseTokens.flatMap { value in
            value > 0 ? value : nil
        }

        return Self(
            sampling: normalizedSampling,
            temperature: normalizedTemperature,
            maximumResponseTokens: normalizedMaximumResponseTokens
        )
    }

    public var samplingDescription: String {
        guard let sampling else { return "System Default" }
        switch sampling {
        case .greedy:
            return "Greedy"
        case .topK(let top, let seed):
            return "Top-K \(top)" + seedDescription(seed)
        case .topP(let threshold, let seed):
            return "Top-P \(Self.fixedTwoDigitString(threshold))" + seedDescription(seed)
        }
    }

    public var temperatureDescription: String {
        temperature.map(Self.fixedTwoDigitString) ?? "System Default"
    }

    public var maximumResponseTokensDescription: String {
        maximumResponseTokens.map(String.init) ?? "System Default"
    }

    private func seedDescription(_ seed: UInt64?) -> String {
        guard let seed else { return "" }
        return " - Seed \(seed)"
    }

    private static func fixedTwoDigitString(_ value: Double) -> String {
        let rounded = (value * 100).rounded(.toNearestOrAwayFromZero) / 100
        return String(format: "%.2f", rounded)
    }
}

public struct ChatDonorFoundationModelSessionConfiguration: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var prompt: String
    public var instructions: String
    public var runtime: ChatDonorFoundationModelRuntime
    public var reasoningLevel: ChatDonorFoundationModelReasoningLevel
    public var generationOptions: ChatDonorFoundationModelGenerationOptions
    public var selectedToolIDs: [String]
    public var createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        prompt: String = "",
        instructions: String = "",
        runtime: ChatDonorFoundationModelRuntime = .onDevice,
        reasoningLevel: ChatDonorFoundationModelReasoningLevel = .none,
        generationOptions: ChatDonorFoundationModelGenerationOptions = ChatDonorFoundationModelGenerationOptions(),
        selectedToolIDs: [String] = [],
        createdAt: Date = .now,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.instructions = instructions
        self.runtime = runtime
        self.reasoningLevel = reasoningLevel
        self.generationOptions = generationOptions
        self.selectedToolIDs = selectedToolIDs
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        normalize()
    }

    public var normalized: Self {
        var copy = self
        copy.normalize()
        return copy
    }

    public mutating func normalize() {
        if runtime == .onDevice {
            reasoningLevel = .none
        }
        generationOptions = generationOptions.normalized
        selectedToolIDs = Self.uniquedNonEmpty(selectedToolIDs)
        if !createdAt.timeIntervalSinceReferenceDate.isFinite {
            createdAt = .now
        }
        if !modifiedAt.timeIntervalSinceReferenceDate.isFinite || modifiedAt < createdAt {
            modifiedAt = createdAt
        }
    }

    public var runSummaryRows: [ChatDonorFoundationModelSummaryRow] {
        [
            ChatDonorFoundationModelSummaryRow(label: "Runtime", value: runtime.displayName),
            ChatDonorFoundationModelSummaryRow(label: "Model", value: runtime.modelIdentifier),
            ChatDonorFoundationModelSummaryRow(label: "Reasoning", value: reasoningLevel.displayName),
            ChatDonorFoundationModelSummaryRow(label: "Sampling", value: generationOptions.samplingDescription),
            ChatDonorFoundationModelSummaryRow(label: "Temperature", value: generationOptions.temperatureDescription),
            ChatDonorFoundationModelSummaryRow(label: "Maximum response tokens", value: generationOptions.maximumResponseTokensDescription)
        ]
    }

    private static func uniquedNonEmpty(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var output: [String] = []
        output.reserveCapacity(values.count)
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            output.append(trimmed)
        }
        return output
    }
}

public struct ChatDonorFoundationModelSummaryRow: Codable, Hashable, Sendable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public enum ChatDonorFoundationModelOutputMode: Codable, Hashable, Sendable {
    case text
    case structured(schemaName: String, schemaSummary: String)

    public var isStructured: Bool {
        switch self {
        case .text:
            false
        case .structured:
            true
        }
    }

    public var summaryRow: ChatDonorFoundationModelSummaryRow {
        switch self {
        case .text:
            ChatDonorFoundationModelSummaryRow(label: "Output", value: "Text")
        case .structured(let schemaName, _):
            ChatDonorFoundationModelSummaryRow(label: "Output", value: "Structured: \(schemaName)")
        }
    }
}

public enum ChatDonorFoundationModelRequestValidationFailure: String, Codable, Hashable, Sendable {
    case emptyPrompt = "empty-prompt"
    case emptyStructuredSchemaName = "empty-structured-schema-name"
}

public struct ChatDonorFoundationModelRunRequest: Codable, Hashable, Sendable {
    public var configuration: ChatDonorFoundationModelSessionConfiguration
    public var outputMode: ChatDonorFoundationModelOutputMode

    public init(
        configuration: ChatDonorFoundationModelSessionConfiguration,
        outputMode: ChatDonorFoundationModelOutputMode = .text
    ) {
        self.configuration = configuration.normalized
        self.outputMode = outputMode
    }

    public var validationFailures: [ChatDonorFoundationModelRequestValidationFailure] {
        var failures: [ChatDonorFoundationModelRequestValidationFailure] = []
        if configuration.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyPrompt)
        }
        if case .structured(let schemaName, _) = outputMode,
           schemaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyStructuredSchemaName)
        }
        return failures
    }

    public var runSummaryRows: [ChatDonorFoundationModelSummaryRow] {
        configuration.runSummaryRows + [outputMode.summaryRow]
    }
}
