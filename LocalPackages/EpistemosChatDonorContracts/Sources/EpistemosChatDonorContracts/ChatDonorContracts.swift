import Foundation

public enum ChatDonorID: String, CaseIterable, Codable, Sendable {
    case agentClone = "agent-clone"
    case agentUpstream = "agent-upstream"
    case swarm
    case swiftedMind = "swiftedmind"
    case agentSDK = "agentsdk-swift"
    case mcpSwiftSDK = "mcp-swift-sdk"
    case agentKit = "agentkit"
    case foundationModelsExample = "foundation-models-example"
    case swiftAgent1amageek = "swiftagent-1amageek"
    case swiftAIAgent = "swiftaia-agent"
}

public enum ChatDonorImportMode: String, CaseIterable, Codable, Sendable {
    case fullCloneFoundation = "full-clone-foundation"
    case vendoredPackage = "vendored-package"
    case adapter
    case cleanRoomStudy = "clean-room-study"
    case provenanceBaseline = "provenance-baseline"
    case referenceOnly = "reference-only"
}

public enum ChatDonorLicenseDisposition: String, CaseIterable, Codable, Sendable {
    case knownPermissive = "known-permissive"
    case mixedAttributionRequired = "mixed-attribution-required"
    case closedDependencyRisk = "closed-dependency-risk"
    case unknownStudyOnly = "unknown-study-only"
}

public enum ChatDonorCapabilityStatus: String, CaseIterable, Codable, Sendable {
    case liveFoundation = "live-foundation"
    case vendoredNotDriving = "vendored-not-driving"
    case contractedPending = "contracted-pending"
    case adaptedWithTests = "adapted-with-tests"
    case provenanceOnly = "provenance-only"
    case cleanRoomPending = "clean-room-pending"
    case blocked
}

public enum ChatDonorDestinationSeam: String, CaseIterable, Codable, Sendable {
    case visibleShell = "visible-shell"
    case transcriptRenderer = "transcript-renderer"
    case composer
    case providerPicker = "provider-picker"
    case providerRuntime = "provider-runtime"
    case toolRegistry = "tool-registry"
    case permissionEngine = "permission-engine"
    case mcpBridge = "mcp-bridge"
    case sessionStore = "session-store"
    case memory
    case settingsSurface = "settings-surface"
    case sidePanel = "side-panel"
    case workflow
    case observability
    case modelUX = "model-ux"
    case recentsBridge = "recents-bridge"

    public var requiresRuntimeOffMainActor: Bool {
        switch self {
        case .providerRuntime, .toolRegistry, .permissionEngine, .mcpBridge,
             .sessionStore, .memory, .workflow, .observability, .recentsBridge:
            true
        case .visibleShell, .transcriptRenderer, .composer, .providerPicker,
             .settingsSurface, .sidePanel, .modelUX:
            false
        }
    }
}

public struct ChatDonorThreadingPolicy: Codable, Hashable, Sendable {
    public var uiUpdatesOnMainActor: Bool
    public var runtimeWorkOffMainActor: Bool
    public var usesStructuredConcurrency: Bool
    public var requiresCancellation: Bool
    public var maxConcurrentToolCalls: Int
    public var debounceNanoseconds: UInt64
    public var notes: String

    public init(
        uiUpdatesOnMainActor: Bool,
        runtimeWorkOffMainActor: Bool,
        usesStructuredConcurrency: Bool,
        requiresCancellation: Bool,
        maxConcurrentToolCalls: Int,
        debounceNanoseconds: UInt64,
        notes: String = ""
    ) {
        self.uiUpdatesOnMainActor = uiUpdatesOnMainActor
        self.runtimeWorkOffMainActor = runtimeWorkOffMainActor
        self.usesStructuredConcurrency = usesStructuredConcurrency
        self.requiresCancellation = requiresCancellation
        self.maxConcurrentToolCalls = maxConcurrentToolCalls
        self.debounceNanoseconds = debounceNanoseconds
        self.notes = notes
    }

    public static let nativeRuntimeDefault = ChatDonorThreadingPolicy(
        uiUpdatesOnMainActor: true,
        runtimeWorkOffMainActor: true,
        usesStructuredConcurrency: true,
        requiresCancellation: true,
        maxConcurrentToolCalls: 4,
        debounceNanoseconds: 150_000_000,
        notes: "UI updates stay on MainActor; provider, tool, MCP, parsing, and persistence work must run off-main with explicit cancellation."
    )

    public static let uiOnlyDefault = ChatDonorThreadingPolicy(
        uiUpdatesOnMainActor: true,
        runtimeWorkOffMainActor: false,
        usesStructuredConcurrency: true,
        requiresCancellation: true,
        maxConcurrentToolCalls: 1,
        debounceNanoseconds: 100_000_000,
        notes: "Visual-only donor surface; runtime work belongs to another contract."
    )

    public func validationFailures(for seams: [ChatDonorDestinationSeam]) -> [ChatDonorContractValidationFailure] {
        var failures: [ChatDonorContractValidationFailure] = []
        if !uiUpdatesOnMainActor {
            failures.append(.uiNotMainActor)
        }
        if seams.contains(where: \.requiresRuntimeOffMainActor) && !runtimeWorkOffMainActor {
            failures.append(.runtimeOnMainActor)
        }
        if !usesStructuredConcurrency {
            failures.append(.missingStructuredConcurrency)
        }
        if !requiresCancellation {
            failures.append(.missingCancellation)
        }
        if maxConcurrentToolCalls < 1 {
            failures.append(.invalidConcurrencyBudget)
        }
        return failures
    }
}

public struct ChatDonorMemoryPolicy: Codable, Hashable, Sendable {
    public var maxBufferedEvents: Int
    public var maxInMemoryAttachmentBytes: Int
    public var maxVisibleTranscriptCharacters: Int
    public var allowsUnboundedStreams: Bool
    public var spillLargeInputsToResourceChips: Bool
    public var preallocateHotBuffers: Bool
    public var notes: String

    public init(
        maxBufferedEvents: Int,
        maxInMemoryAttachmentBytes: Int,
        maxVisibleTranscriptCharacters: Int,
        allowsUnboundedStreams: Bool,
        spillLargeInputsToResourceChips: Bool,
        preallocateHotBuffers: Bool,
        notes: String = ""
    ) {
        self.maxBufferedEvents = maxBufferedEvents
        self.maxInMemoryAttachmentBytes = maxInMemoryAttachmentBytes
        self.maxVisibleTranscriptCharacters = maxVisibleTranscriptCharacters
        self.allowsUnboundedStreams = allowsUnboundedStreams
        self.spillLargeInputsToResourceChips = spillLargeInputsToResourceChips
        self.preallocateHotBuffers = preallocateHotBuffers
        self.notes = notes
    }

    public static let nativeChatDefault = ChatDonorMemoryPolicy(
        maxBufferedEvents: 256,
        maxInMemoryAttachmentBytes: 1_048_576,
        maxVisibleTranscriptCharacters: 200_000,
        allowsUnboundedStreams: false,
        spillLargeInputsToResourceChips: true,
        preallocateHotBuffers: true,
        notes: "Bound stream growth; large files become resource chips instead of prompt-sized String copies."
    )

    public func validationFailures() -> [ChatDonorContractValidationFailure] {
        var failures: [ChatDonorContractValidationFailure] = []
        if maxBufferedEvents < 1 {
            failures.append(.invalidEventBuffer)
        }
        if maxInMemoryAttachmentBytes < 1 || maxVisibleTranscriptCharacters < 1 {
            failures.append(.invalidMemoryBudget)
        }
        if allowsUnboundedStreams {
            failures.append(.unboundedStream)
        }
        if !spillLargeInputsToResourceChips {
            failures.append(.largeInputsStayInline)
        }
        if !preallocateHotBuffers {
            failures.append(.missingHotBufferPreallocation)
        }
        return failures
    }
}

public struct ChatDonorProofRequirement: Codable, Hashable, Sendable {
    public var commands: [String]
    public var capabilityProofs: [String]
    public var visualReadbackRequired: Bool
    public var endpointProofRequired: Bool
    public var notes: String

    public init(
        commands: [String],
        capabilityProofs: [String],
        visualReadbackRequired: Bool,
        endpointProofRequired: Bool,
        notes: String = ""
    ) {
        self.commands = commands
        self.capabilityProofs = capabilityProofs
        self.visualReadbackRequired = visualReadbackRequired
        self.endpointProofRequired = endpointProofRequired
        self.notes = notes
    }

    public func validationFailures() -> [ChatDonorContractValidationFailure] {
        var failures: [ChatDonorContractValidationFailure] = []
        if commands.isEmpty {
            failures.append(.missingProofCommand)
        }
        if capabilityProofs.isEmpty {
            failures.append(.missingCapabilityProof)
        }
        return failures
    }
}

public enum ChatDonorContractValidationFailure: String, Codable, Hashable, Sendable, CustomStringConvertible {
    case emptyIdentifier = "empty-identifier"
    case emptySourcePaths = "empty-source-paths"
    case emptyDestinationSeams = "empty-destination-seams"
    case uiNotMainActor = "ui-not-main-actor"
    case runtimeOnMainActor = "runtime-on-main-actor"
    case missingStructuredConcurrency = "missing-structured-concurrency"
    case missingCancellation = "missing-cancellation"
    case invalidConcurrencyBudget = "invalid-concurrency-budget"
    case invalidEventBuffer = "invalid-event-buffer"
    case invalidMemoryBudget = "invalid-memory-budget"
    case unboundedStream = "unbounded-stream"
    case largeInputsStayInline = "large-inputs-stay-inline"
    case missingHotBufferPreallocation = "missing-hot-buffer-preallocation"
    case missingProofCommand = "missing-proof-command"
    case missingCapabilityProof = "missing-capability-proof"
    case missingImplementationPath = "missing-implementation-path"
    case unknownLicenseWithoutCleanRoom = "unknown-license-without-clean-room"

    public var description: String { rawValue }
}

public struct ChatDonorFeatureContract: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var donor: ChatDonorID
    public var featureID: String
    public var sourcePaths: [String]
    public var destinationSeams: [ChatDonorDestinationSeam]
    public var importMode: ChatDonorImportMode
    public var licenseDisposition: ChatDonorLicenseDisposition
    public var status: ChatDonorCapabilityStatus
    public var threading: ChatDonorThreadingPolicy
    public var memory: ChatDonorMemoryPolicy
    public var proof: ChatDonorProofRequirement
    public var implementationPaths: [String]
    public var notes: String

    public init(
        id: String,
        donor: ChatDonorID,
        featureID: String,
        sourcePaths: [String],
        destinationSeams: [ChatDonorDestinationSeam],
        importMode: ChatDonorImportMode,
        licenseDisposition: ChatDonorLicenseDisposition,
        status: ChatDonorCapabilityStatus,
        threading: ChatDonorThreadingPolicy,
        memory: ChatDonorMemoryPolicy = .nativeChatDefault,
        proof: ChatDonorProofRequirement,
        implementationPaths: [String] = [],
        notes: String = ""
    ) {
        self.id = id
        self.donor = donor
        self.featureID = featureID
        self.sourcePaths = sourcePaths
        self.destinationSeams = destinationSeams
        self.importMode = importMode
        self.licenseDisposition = licenseDisposition
        self.status = status
        self.threading = threading
        self.memory = memory
        self.proof = proof
        self.implementationPaths = implementationPaths
        self.notes = notes
    }

    public var validationFailures: [ChatDonorContractValidationFailure] {
        var failures: [ChatDonorContractValidationFailure] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            featureID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyIdentifier)
        }
        if sourcePaths.isEmpty || sourcePaths.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            failures.append(.emptySourcePaths)
        }
        if destinationSeams.isEmpty {
            failures.append(.emptyDestinationSeams)
        }
        if licenseDisposition == .unknownStudyOnly &&
            importMode != .cleanRoomStudy &&
            importMode != .referenceOnly {
            failures.append(.unknownLicenseWithoutCleanRoom)
        }
        if status == .adaptedWithTests &&
            (implementationPaths.isEmpty || implementationPaths.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })) {
            failures.append(.missingImplementationPath)
        }
        failures.append(contentsOf: threading.validationFailures(for: destinationSeams))
        failures.append(contentsOf: memory.validationFailures())
        failures.append(contentsOf: proof.validationFailures())
        return failures
    }

    public var isValid: Bool {
        validationFailures.isEmpty
    }
}

public enum ChatDonorContractCatalog: Sendable {
    public static let swiftChat20260625: [ChatDonorFeatureContract] = [
        ChatDonorFeatureContract(
            id: "agent-clone.visible-foundation",
            donor: .agentClone,
            featureID: "visible-foundation",
            sourcePaths: [
                "LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/ViewModels/AgentViewModel.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Services/LLMServices"
            ],
            destinationSeams: [.visibleShell, .transcriptRenderer, .composer, .providerPicker, .settingsSurface, .toolRegistry, .sidePanel],
            importMode: .fullCloneFoundation,
            licenseDisposition: .closedDependencyRisk,
            status: .liveFoundation,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "swift build --package-path LocalPackages/AgentClone",
                    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' build"
                ],
                capabilityProofs: [
                    "fresh Chat screenshot readback",
                    "provider picker reachable",
                    "tool toggles reachable",
                    "MCP surface reachable",
                    "Codex reasoning is separated from answer text"
                ],
                visualReadbackRequired: true,
                endpointProofRequired: true
            ),
            notes: "Live full-clone foundation; must be transformed into Epistemos old-chat ontology without losing provider/tool/MCP surfaces."
        ),
        ChatDonorFeatureContract(
            id: "agent-clone.capability-preservation-manifest",
            donor: .agentClone,
            featureID: "capability-preservation-manifest",
            sourcePaths: [
                "LocalPackages/AgentClone/Sources/AgentClone/Services/LLMProviderSetup.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Models/ToolNames.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Services/ToolPreferencesService.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/MCP",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Settings",
                "LocalPackages/AgentClone/Sources/AgentClone/Services/SessionStore.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Services/TokenUsageStore.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Services/FileBackupService.swift",
                "LocalPackages/AgentClone/Package.swift",
                "LocalPackages/AgentClone/VENDOR.md"
            ],
            destinationSeams: [
                .providerPicker,
                .providerRuntime,
                .toolRegistry,
                .permissionEngine,
                .mcpBridge,
                .sessionStore,
                .settingsSurface,
                .sidePanel,
                .workflow,
                .observability,
                .modelUX,
                .recentsBridge
            ],
            importMode: .adapter,
            licenseDisposition: .closedDependencyRisk,
            status: .blocked,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "20-provider preservation manifest proof",
                    "28-tool preservation manifest proof",
                    "MCP/session/history/rollback/usage/permission/messages/settings surface source-anchor proof",
                    "closed Agent* dependency risk owner-approval proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorAgentCloneCapabilityManifest.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "Executable preservation inventory for AgentClone's live capability stack. This does not complete live endpoint or visual proof; it prevents future UI simplification from silently deleting providers, tools, MCP, permissions, history, rollback, usage, Messages, automation, or the known closed package risk."
        ),
        ChatDonorFeatureContract(
            id: "agent-clone.visible-ontology-chrome",
            donor: .agentClone,
            featureID: "visible-ontology-chrome",
            sourcePaths: [
                "LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/EpistemosReskin.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Settings/SettingsView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Tabs/NewMainTabSheet.swift"
            ],
            destinationSeams: [.visibleShell, .composer, .providerPicker, .settingsSurface, .sidePanel, .modelUX],
            importMode: .adapter,
            licenseDisposition: .closedDependencyRisk,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts",
                    "swift build --package-path LocalPackages/AgentClone"
                ],
                capabilityProofs: [
                    "mounted Epistemos chrome source proof",
                    "model picker/settings/history/new-session/context controls remain reachable",
                    "composer tools and model badge preservation proof",
                    "monospace user/composer/tool chrome token proof"
                ],
                visualReadbackRequired: true,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/EpistemosReskin.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "First mounted recurring-chat ontology step: adds persistent Epistemos title/context/model chrome and restores monospaced user/composer/tool tokens without replacing AgentClone's provider, settings, history, tab, tool, or side-panel paths. Fresh visual readback remains required before the broad visible foundation can close."
        ),
        ChatDonorFeatureContract(
            id: "agent-clone.start-message-bar-ontology",
            donor: .agentClone,
            featureID: "start-message-bar-ontology",
            sourcePaths: [
                "LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/EpistemosReskin.swift"
            ],
            destinationSeams: [.visibleShell, .composer, .providerPicker, .modelUX],
            importMode: .adapter,
            licenseDisposition: .closedDependencyRisk,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts",
                    "swift build --package-path LocalPackages/AgentClone",
                    "swift build --package-path /tmp/AgentCloneVisualHost"
                ],
                capabilityProofs: [
                    "start surface lands directly on Epistemos message bar",
                    "donor keyboard-hint/tip copy removed from visible start state",
                    "bootstrap status lines do not displace empty start surface",
                    "model picker badge and composer tool paths remain reachable",
                    "fresh package-host start-surface screenshot readback"
                ],
                visualReadbackRequired: true,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "Refines the empty/start Chat state toward the old message-bar ontology by removing donor instructional hint rows, ignoring bootstrap-only status logs for the empty-surface decision, and using Epistemos message placeholders while preserving composer tools and provider/model settings."
        ),
        ChatDonorFeatureContract(
            id: "agent-clone.full-app-chat-route-start-proof",
            donor: .agentClone,
            featureID: "full-app-chat-route-start-proof",
            sourcePaths: [
                "Epistemos/App/RootView.swift",
                "Epistemos/Views/Landing/WorkspaceModeSelection.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/EpistemosReskin.swift"
            ],
            destinationSeams: [.visibleShell, .composer, .providerPicker, .settingsSurface, .sidePanel, .modelUX],
            importMode: .adapter,
            licenseDisposition: .closedDependencyRisk,
            status: .adaptedWithTests,
            threading: .uiOnlyDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts",
                    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-ChatRouteProof build"
                ],
                capabilityProofs: [
                    "RootView .chat mode mounts AgentCloneChatHostSurface",
                    "AgentCloneChatHostSurface embeds AgentClone.ContentView without restoring old native chat",
                    "RootView injects Epistemos theme tokens through AgentClone.AgentSkin before mount",
                    "WorkspaceModeSelection persists the chat route choice",
                    "full Epistemos app build succeeds with the AgentClone route linked",
                    "full Epistemos app screenshot shows Epistemos start title and Message Epistemos composer"
                ],
                visualReadbackRequired: true,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "Epistemos/App/RootView.swift",
                "Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift",
                "Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift",
                "Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift",
                "Epistemos/Views/Landing/WorkspaceModeSelection.swift",
                "EpistemosTests/AgentCloneAppContextSnapshotTests.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "Full-app route proof for the current AgentClone start/message-bar ontology: .chat mode selects the Epistemos-skinned AgentClone surface, the app builds, and visual readback shows the Epistemos start mark plus message composer in the real app. This does not close the broader visible-foundation endpoint proof."
        ),
        ChatDonorFeatureContract(
            id: "agent-clone.chatview2-route-ontology",
            donor: .agentClone,
            featureID: "chatview2-route-ontology",
            sourcePaths: [
                "Epistemos/App/RootView.swift",
                "Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift",
                "Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift",
                "Epistemos/Views/AgentFusion/AgentPortalRouteRequest.swift",
                "Epistemos/State/AgentChatState.swift",
                "Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift",
                "Epistemos/Views/AgentFusion/AgentCompactPortalView.swift",
                "Epistemos/App/UtilityWindowManager.swift",
                "Epistemos/App/EpistemosApp.swift",
                "Epistemos/Views/Graph/GraphWorkspaceContainer.swift",
                "Epistemos/Views/Notes/NoteDetailWorkspaceView.swift",
                "EpistemosTests/AgentCloneAppContextSnapshotTests.swift",
                "Epistemos/Chat/ChatRouteView.swift",
                "Epistemos/Chat/ChatSurfaceCoordinator.swift",
                "Epistemos/Chat/ChatViewModel.swift",
                "Epistemos/Views/Chat/ChatView.swift",
                "Epistemos/Views/Chat/ChatInputBar.swift",
                "Epistemos/Views/Chat/ChatSidebarView.swift",
                "Epistemos/Views/MiniChat/MiniChatView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Services/LLMProviderSetup.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Models/ToolNames.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPService.swift"
            ],
            destinationSeams: [
                .visibleShell,
                .transcriptRenderer,
                .composer,
                .providerPicker,
                .settingsSurface,
                .sidePanel,
                .modelUX,
                .recentsBridge,
                .toolRegistry,
                .mcpBridge
            ],
            importMode: .adapter,
            licenseDisposition: .closedDependencyRisk,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts",
                    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-ChatRouteProof build"
                ],
                capabilityProofs: [
                    "RootView .chat mode mounts AgentCloneChatHostSurface as an Epistemos-owned shell",
                    "AgentCloneChatHostSurface embeds AgentClone.ContentView as the Swift-agent foundation",
                    "ChatRouteView and the Epistemos/Chat backend route files are deleted",
                    "Old ChatView is a visual language reference only, not a live backend route",
                    "Landing search creates and submits the same AgentPortalContextSnapshot.landing into AgentChatState instead of an implicit old-chat handoff",
                    "Note and Graph entry points post typed AgentPortalContextSnapshot values into the shared AgentClone/fusion route",
                    "Note and Graph portal contexts keep Epistemos vault root distinct from the app workspace path",
                    "The compact floating agent portal uses AgentPortalContextSnapshot.mini and AgentCloneBridge instead of the deleted MiniChat engine",
                    "The compact floating agent portal keeps Epistemos vault root distinct from the app workspace path in both portal and AgentClone host context",
                    "The compact floating agent portal renders active portal context/action chips and can insert a bounded Epistemos app-context snapshot into the composer",
                    "The compact floating agent portal preserves activated Note/Graph portal context on submission instead of downgrading it to a generic compact context",
                    "AgentChatState owns bounded shared recent portal sessions for main, mini, note, graph, vault, and landing portals",
                    "AgentChatState can activate a recent portal context without faking restored transcript persistence",
                    "AgentCloneChatHostSurface renders an Epistemos-owned idle landing mark from AgentChatState rather than exposing donor empty-state chrome",
                    "AgentCloneChatHostSurface keeps AgentClone mounted for runtime capability while masking donor/internal chrome behind an Epistemos-owned conversation canvas",
                    "AgentCloneChatHostSurface uses ChatView-derived column and composer dimensions in AgentFusionChatLayout without importing the old ChatView backend",
                    "AgentCloneChatHostSurface removes the foreground transcript diagnostics strip, extra transcript card, and composer shadow from standard Chat",
                    "AgentCloneChatHostSurface renders role-specific ChatView-style rows through retained markdown/assistant chrome instead of generic icon-led debug rows",
                    "AgentCloneChatHostSurface hides temporary foundation/backend/fusion vocabulary from foreground rails while preserving the active provider/tool/MCP foundation",
                    "AgentCloneChatHostSurface restores the old message-bar rhythm with a top vault context strip while keeping slash/model/session/mic/new-session controls reachable",
                    "AgentCloneChatHostSurface makes the top model affordance open the inline model picker while context remains reachable from the side rail",
                    "AgentCloneChatHostSurface renders dedicated recent-session rows with active state and portal/session/message metadata instead of generic settings rows",
                    "AgentCloneChatHostSurface exposes Tools, Skills, Commands, and MCP capability counts in the Epistemos context rail without mounting old chat diagnostics",
                    "AgentCloneChatHostSurface can insert a bounded Epistemos app-context snapshot into the composer from the shared context rail",
                    "AgentCloneChatHostSurface renders descriptor-backed Portal Actions rows and composer chips with approval/mutation cues instead of opaque action ids",
                    "AgentCloneChatHostSurface submits from the resolved active portal context with attachments, prompt preview, and session identity instead of resetting Note/Graph/Vault portals to the root context",
                    "AgentPortalContextSnapshot builds a bounded AgentClone prompt envelope so Landing, main host, and compact portal deliver typed Epistemos context into the clone runtime while keeping the Epistemos transcript prompt raw",
                    "AgentPortalContextSnapshot carries an Epistemos-owned portal action catalog for app-context snapshots, vault search, note create/update/delete/rewrite, graph read/mutate, session summary, and skill discovery with approval and mutation metadata",
                    "AgentCompactPortalView renders descriptor-backed compact action chips with native approval cues instead of old MiniChat action strings",
                    "Landing, main host, and compact portal submit AgentCloneBridge prompts through portalContext.agentClonePromptEnvelope instead of raw trimmed text",
                    "AgentCloneChatHostSurface renders active tool execution inline using ToolActivityNarrator instead of hiding tool activity in runtime state",
                    "AgentCloneChatHostSurface exposes typed portal context rows for Note, Graph, and attached resources without restoring old surface-specific chat engines",
                    "AgentCloneChatHostSurface renders typed UserFacingChatErrorKind recovery rows instead of a single generic error diagnostic",
                    "AgentCloneChatHostSurface renders failed MessageContentBlock.toolResult entries as transcript-visible native tool failure rows",
                    "AgentCloneChatHostSurface renders shared ChatApprovalQueue pending approvals inline without creating a second approval engine",
                    "AgentCloneChatHostSurface shows a reactivated recent-session context mark instead of a generic empty state after honest non-restoring activation",
                    "AgentCloneChatHostSurface shows bounded Note/Graph/attachment/action context from AgentPortalSessionSummary.portalContext on the resume mark",
                    "AgentCloneChatHostSurface opens the shared Epistemos context rail from the resume mark instead of restoring old Note/Graph chat sidebars",
                    "AgentCloneChatHostSurface uses the Epistemos MotionTitle ASCII/typewriter blur title on idle and reactivated-session marks",
                    "AgentCloneChatHostSurface renders bounded approved-action chips from AgentPortalContextSnapshot into the composer without invoking old portal engines",
                    "AgentCloneChatHostSurface derives toolbar and session-rail status from live AgentChatState and ChatApprovalQueue instead of static ready chrome",
                    "AgentCloneChatHostSurface resolves visible session chrome from AgentChatState.activeSessionId before portal snapshot fallback",
                    "AgentClone provider/tool/MCP capability sources remain the active Chat foundation",
                    "project.yml, Xcode project metadata, and SwiftPM resolution no longer mount deleted native chat, Osaurus, AgentBlueprint, or SystemG paths",
                    "Standard Chat must not expose old Epistemos local-chat routing/Overseer diagnostics as the primary UI"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "Epistemos/App/RootView.swift",
                "Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift",
                "Epistemos/Views/AgentFusion/AgentPortalContextSnapshot.swift",
                "Epistemos/Views/AgentFusion/AgentPortalRouteRequest.swift",
                "Epistemos/State/AgentChatState.swift",
                "Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift",
                "Epistemos/Views/AgentFusion/AgentCompactPortalView.swift",
                "Epistemos/App/UtilityWindowManager.swift",
                "Epistemos/App/EpistemosApp.swift",
                "Epistemos/Views/Graph/GraphWorkspaceContainer.swift",
                "Epistemos/Views/Notes/NoteDetailWorkspaceView.swift",
                "EpistemosTests/AgentCloneAppContextSnapshotTests.swift",
                "Epistemos/Chat/ChatRouteView.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "Blocked/rejected route experiment. Owner clarified ChatView is UI language only; the live Chat foundation must remain AgentClone/new Swift-agent fusion, and the old Epistemos local-chat backend must be deleted rather than used as ChatView 2."
        ),
        ChatDonorFeatureContract(
            id: "agent-clone.chatview2-brain-panel-parity",
            donor: .agentClone,
            featureID: "chatview2-brain-panel-parity",
            sourcePaths: [
                "Epistemos/Chat/ChatRouteView.swift",
                "Epistemos/State/ChatState.swift",
                "Epistemos/Views/Chat/ChatView.swift",
                "Epistemos/Views/Chat/ChatInputBar.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Services/LLMProviderSetup.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Models/ToolNames.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/MCP/MCPService.swift"
            ],
            destinationSeams: [
                .sidePanel,
                .toolRegistry,
                .mcpBridge,
                .settingsSurface,
                .modelUX,
                .observability
            ],
            importMode: .adapter,
            licenseDisposition: .closedDependencyRisk,
            status: .blocked,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts",
                    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-ChatRouteProof build"
                ],
                capabilityProofs: [
                    "ChatView2BrainPanel was rejected because it exposed routing/request/execution-plan diagnostics in standard Chat",
                    "Epistemos/Chat backend route files are deleted",
                    "Old ChatBrainPanel may inform future scratch UI language only after the AgentClone foundation owns the route",
                    "AgentClone provider/tool/MCP/settings capabilities remain the active foundation",
                    "Standard Chat must use progressive disclosure for internals, never a primary Overseer diagnostic panel"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "Epistemos/Chat/ChatRouteView.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "Blocked/rejected panel experiment. It leaked internal routing/request/model-input/Overseer material into standard Chat and used the deleted Epistemos/Chat route instead of rebuilding the old-chat feel inside the AgentClone foundation."
        ),
        ChatDonorFeatureContract(
            id: "agent-clone.chatview2-transcript-bubble-parity",
            donor: .agentClone,
            featureID: "chatview2-transcript-bubble-parity",
            sourcePaths: [
                "Epistemos/Chat/ChatRouteView.swift",
                "Epistemos/Chat/ChatTranscript.swift",
                "Epistemos/Views/Chat/ChatView.swift",
                "Epistemos/Views/Chat/MessageBubble.swift",
                "Epistemos/Views/Chat/AssistantInlineTranscriptView.swift",
                "Epistemos/Views/Chat/TaggedMarkdownTextView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Output/MessagesView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Models/ChatModels.swift"
            ],
            destinationSeams: [
                .transcriptRenderer,
                .visibleShell,
                .recentsBridge,
                .observability
            ],
            importMode: .adapter,
            licenseDisposition: .closedDependencyRisk,
            status: .blocked,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts",
                    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCodexBuild-ChatRouteProof build"
                ],
                capabilityProofs: [
                    "ChatView2TranscriptBubble was rejected because it lived on the deleted Epistemos/Chat route",
                    "Old MessageBubble and AssistantInlineTranscriptView are deleted visual-language history, not reusable backend surfaces",
                    "AgentClone MessagesView and ChatModels remain the target foundation for rebuilt transcript UI",
                    "Future transcript parity must be implemented inside the AgentClone/new Swift-agent surface",
                    "Deleted Epistemos/Chat route files cannot drive standard Chat"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "Epistemos/Chat/ChatRouteView.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "Blocked/rejected transcript experiment. The old ChatView look should be rebuilt from scratch over AgentClone message models, not by reviving Epistemos/Chat ChatTurnRow or old local chat rendering code."
        ),
        ChatDonorFeatureContract(
            id: "agent-clone.message-bar-layout-parity",
            donor: .agentClone,
            featureID: "message-bar-layout-parity",
            sourcePaths: [
                "Epistemos/Views/Chat/ChatInputBar.swift",
                "Epistemos/Views/MiniChat/MiniChatView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift",
                "LocalPackages/AgentClone/Sources/AgentClone/EpistemosReskin.swift"
            ],
            destinationSeams: [.composer, .visibleShell, .providerPicker, .modelUX],
            importMode: .adapter,
            licenseDisposition: .closedDependencyRisk,
            status: .adaptedWithTests,
            threading: .uiOnlyDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts",
                    "swift build --package-path LocalPackages/AgentClone",
                    "swift build --package-path /tmp/AgentCloneVisualHost"
                ],
                capabilityProofs: [
                    "AgentClone composer is capped to the old Epistemos 620pt message-bar width",
                    "AgentClone composer uses Epistemos 11/9/7 padding and 4pt/6pt control-row rhythm",
                    "Full app .chat route uses AgentClone.ContentView as the foundation; old ChatInputBar is reference only",
                    "model/provider settings button remains reachable",
                    "screenshot, paste image, dictation, hotword, stop/clear, and send controls remain reachable",
                    "AgentClone package-host start surface and active transcript surface share the same adapted InputSectionView"
                ],
                visualReadbackRequired: true,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/AgentClone/Sources/AgentClone/Views/Input/InputSectionView.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "Visible composer parity slice for the AgentClone package shell. Old ChatInputBar is now reference-only; full-app Chat remains on AgentClone.ContentView while the old-chat message-bar feel is rebuilt inside that foundation."
        ),
        ChatDonorFeatureContract(
            id: "agent-upstream.provenance-baseline",
            donor: .agentUpstream,
            featureID: "provenance-baseline",
            sourcePaths: [
                ".research-clones/swift-act/agent-macos26/Agent/AgentApp.swift",
                ".research-clones/swift-act/agent-macos26/Agent/Views/ContentView",
                ".research-clones/swift-act/agent-macos26/Agent/Services"
            ],
            destinationSeams: [.visibleShell, .settingsSurface, .toolRegistry],
            importMode: .provenanceBaseline,
            licenseDisposition: .knownPermissive,
            status: .provenanceOnly,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: ["git -C .research-clones/swift-act/agent-macos26 rev-parse HEAD"],
                capabilityProofs: ["diff AgentClone against upstream before future wholesale harvest"],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            notes: "Reference baseline only; never overwrite Epistemos changes with an upstream recopy."
        ),
        ChatDonorFeatureContract(
            id: "swarm.typed-runtime-substrate",
            donor: .swarm,
            featureID: "typed-runtime-substrate",
            sourcePaths: [
                "LocalPackages/Swarm/Sources/Swarm/Core/AgentRuntime.swift",
                "LocalPackages/Swarm/Sources/Swarm/Agents/Agent.swift",
                "LocalPackages/Swarm/Sources/Swarm/Tools",
                "LocalPackages/Swarm/Sources/Swarm/Memory",
                "LocalPackages/Swarm/Sources/Swarm/Guardrails"
            ],
            destinationSeams: [.providerRuntime, .toolRegistry, .sessionStore, .memory, .workflow, .observability],
            importMode: .vendoredPackage,
            licenseDisposition: .knownPermissive,
            status: .vendoredNotDriving,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: ["swift build --package-path LocalPackages/Swarm"],
                capabilityProofs: [
                    "bounded event stream proof",
                    "tool-call ordering proof",
                    "provider adapter proof",
                    "guardrail rejection proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: true
            ),
            notes: "Main robustness donor; should not take over the visible shell."
        ),
        ChatDonorFeatureContract(
            id: "swarm.in-process-chat-substrate",
            donor: .swarm,
            featureID: "in-process-chat-substrate",
            sourcePaths: [
                "LocalPackages/Swarm/Sources/Swarm/Agents/Agent.swift",
                "LocalPackages/Swarm/Sources/Swarm/Core/AgentEvent.swift",
                "LocalPackages/Swarm/Sources/Swarm/Core/AgentRuntime.swift",
                "LocalPackages/Swarm/Sources/Swarm/Core/StreamHelper.swift",
                "Epistemos/Chat/EpistemosInProcessProvider.swift",
                "Epistemos/Chat/EpistemosChatSession.swift",
                "Epistemos/Chat/EpistemosChatAgentFactory.swift",
                "Epistemos/Chat/ChatTranscript.swift",
                "Epistemos/Chat/ChatViewModel.swift",
                "Epistemos/App/AppBootstrap.swift",
                "Epistemos/App/AppEnvironment.swift"
            ],
            destinationSeams: [.providerRuntime, .transcriptRenderer, .sessionStore, .workflow, .observability],
            importMode: .adapter,
            licenseDisposition: .knownPermissive,
            status: .blocked,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "deleted Epistemos/Chat in-process provider proof",
                    "deleted Epistemos/Chat session proof",
                    "removed ChatSurfaceCoordinator environment injection proof",
                    "RootView .chat stays on AgentClone foundation",
                    "Swarm remains a donor target for future integration inside the AgentClone/fused foundation"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "Epistemos/App/AppBootstrap.swift",
                "Epistemos/App/AppEnvironment.swift",
                "LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift"
            ],
            notes: "Blocked/deleted old substrate. The Epistemos/Chat Swarm-backed route was removed because Chat must be rebuilt around the AgentClone/new Swift-agent foundation. Swarm remains assigned to runtime/events/tools/memory/guardrails/workflow/observability, but future work must integrate it behind that foundation rather than resurrecting the deleted old local chat route."
        ),
        ChatDonorFeatureContract(
            id: "swiftedmind.transcript-stream-values",
            donor: .swiftedMind,
            featureID: "transcript-stream-values",
            sourcePaths: [
                ".research-clones/swift-act/swiftagent-swiftedmind/Sources",
                ".research-clones/swift-act/swiftagent-swiftedmind/Tests"
            ],
            destinationSeams: [.transcriptRenderer, .sessionStore, .observability],
            importMode: .adapter,
            licenseDisposition: .knownPermissive,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "git -C .research-clones/swift-act/swiftagent-swiftedmind rev-parse HEAD",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "fragment buffer reconstruction proof",
                    "token usage accounting proof",
                    "tool-run value roundtrip proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorTranscriptValues.swift"
            ],
            notes: "Use for value models and tests, not as another live provider stack."
        ),
        ChatDonorFeatureContract(
            id: "mcp-swift-sdk.canonical-mcp-bridge",
            donor: .mcpSwiftSDK,
            featureID: "canonical-mcp-bridge",
            sourcePaths: [
                ".research-clones/swift-act/mcp-swift-sdk/Sources",
                ".research-clones/swift-act/mcp-swift-sdk/Tests"
            ],
            destinationSeams: [.mcpBridge, .toolRegistry, .permissionEngine],
            importMode: .adapter,
            licenseDisposition: .mixedAttributionRequired,
            status: .contractedPending,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: ["git -C .research-clones/swift-act/mcp-swift-sdk rev-parse HEAD"],
                capabilityProofs: [
                    "tools/resources/prompts proof",
                    "progress and cancellation proof",
                    "auth or elicitation proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: true
            ),
            notes: "Canonical MCP semantics donor; avoid duplicate MCP truth."
        ),
        ChatDonorFeatureContract(
            id: "mcp-swift-sdk.semantic-values",
            donor: .mcpSwiftSDK,
            featureID: "semantic-values",
            sourcePaths: [
                ".research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Server/Tools.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Server/Resources.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Server/Prompts.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Base/Utilities/Progress.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Base/Utilities/Cancellation.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Client/Elicitation.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Base/Authorization/OAuthURLValidator.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Sources/MCP/Base/Authorization/OAuthModels.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Tests/MCPTests/ToolTests.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Tests/MCPTests/ResourceTests.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Tests/MCPTests/PromptTests.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Tests/MCPTests/ProgressTests.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Tests/MCPTests/CancellationTests.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Tests/MCPTests/ElicitationTests.swift",
                ".research-clones/swift-act/mcp-swift-sdk/Tests/MCPTests/OAuthURLValidatorTests.swift"
            ],
            destinationSeams: [.mcpBridge, .toolRegistry, .permissionEngine],
            importMode: .adapter,
            licenseDisposition: .mixedAttributionRequired,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "git -C .research-clones/swift-act/mcp-swift-sdk rev-parse HEAD",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "tools/resources/prompts semantic proof",
                    "progress and cancellation semantic proof",
                    "auth and elicitation semantic proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorMCPSemantics.swift"
            ],
            notes: "Epistemos-owned MCP value and policy layer. The broader live endpoint bridge remains pending under mcp-swift-sdk.canonical-mcp-bridge."
        ),
        ChatDonorFeatureContract(
            id: "agentsdk.typed-agent-boundaries",
            donor: .agentSDK,
            featureID: "typed-agent-boundaries",
            sourcePaths: [
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Agent.swift",
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Tool.swift",
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Guardrail.swift",
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Handoff.swift",
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Run.swift",
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/RunContext.swift",
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Usage.swift",
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/ModelSettings.swift",
                ".research-clones/swift-act/agentsdk-swift/Sources/AgentSDK-Swift/Models/ModelInterface.swift",
                ".research-clones/swift-act/agentsdk-swift/Tests/AgentSDK-SwiftTests/AgentSDK_SwiftTests.swift"
            ],
            destinationSeams: [.providerRuntime, .toolRegistry, .permissionEngine, .workflow],
            importMode: .adapter,
            licenseDisposition: .knownPermissive,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "git -C .research-clones/swift-act/agentsdk-swift rev-parse HEAD",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "typed tool enablement proof",
                    "guardrail rejection mapping proof",
                    "handoff event mapping proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: true
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorAgentSDKBoundaries.swift"
            ],
            notes: "Epistemos-owned value and decision layer for AgentSDK's typed agent/tool/guardrail/handoff boundaries. Does not import AgentSDK's OpenAI model provider."
        ),
        ChatDonorFeatureContract(
            id: "agentkit.lightweight-agent-ergonomics",
            donor: .agentKit,
            featureID: "lightweight-agent-ergonomics",
            sourcePaths: [
                ".research-clones/swift-act/agentkit/Sources",
                ".research-clones/swift-act/agentkit/Tests"
            ],
            destinationSeams: [.providerRuntime, .sessionStore, .mcpBridge, .observability],
            importMode: .adapter,
            licenseDisposition: .knownPermissive,
            status: .contractedPending,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: ["git -C .research-clones/swift-act/agentkit rev-parse HEAD"],
                capabilityProofs: [
                    "retry/backoff proof",
                    "conversation window trimming proof",
                    "callback ordering proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            )
        ),
        ChatDonorFeatureContract(
            id: "agentkit.retry-window-callbacks",
            donor: .agentKit,
            featureID: "retry-window-callbacks",
            sourcePaths: [
                ".research-clones/swift-act/agentkit/Sources/AgentKit/InvokeWithRetry/RetryStrategy.swift",
                ".research-clones/swift-act/agentkit/Sources/AgentKit/InvokeWithRetry/ExponentialBackoff.swift",
                ".research-clones/swift-act/agentkit/Sources/AgentKit/InvokeWithRetry/JitterBackoff.swift",
                ".research-clones/swift-act/agentkit/Sources/AgentKit/InvokeWithRetry/InvokeWithRetry.swift",
                ".research-clones/swift-act/agentkit/Sources/AgentKit/ConversationManager/SlidingWindowConversationManager.swift",
                ".research-clones/swift-act/agentkit/Sources/AgentKit/Agent+Callback.swift",
                ".research-clones/swift-act/agentkit/Sources/AgentKit/Agent+StreamAsync.swift",
                ".research-clones/swift-act/agentkit/Tests/AgentKitTests/ConversationManagerTests.swift"
            ],
            destinationSeams: [.providerRuntime, .sessionStore, .observability],
            importMode: .adapter,
            licenseDisposition: .knownPermissive,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "git -C .research-clones/swift-act/agentkit rev-parse HEAD",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "retry/backoff schedule proof",
                    "conversation window trimming proof",
                    "callback ordering proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorAgentKitErgonomics.swift"
            ],
            notes: "First AgentKit adaptation: Epistemos-owned retry/backoff, conversation window, and callback ordering values. MCP ergonomics are covered by agentkit.mcp-ergonomics; the broad service lifecycle remains pending until live integration proves it."
        ),
        ChatDonorFeatureContract(
            id: "agentkit.mcp-ergonomics",
            donor: .agentKit,
            featureID: "mcp-ergonomics",
            sourcePaths: [
                ".research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPCLient.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPClient+Configuration.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPClient+Stdio.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPClient+HTTP.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPClientKit/MCPClient+ToolProtocol.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPClientKit/Array+MCPClient.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPShared/MCPTransport.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPShared/ToolProtocol.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPShared/ToolProtocol+MCP.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPShared/MCPServerError.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPServer.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPServer+Tools.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPServer+Resources.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPServer+Prompts.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPTool.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPResource.swift",
                ".research-clones/swift-act/agentkit/Sources/MCPServerKit/MCPPrompt.swift",
                ".research-clones/swift-act/agentkit/Tests/MCPClientTests/MCPConfigurationTests.swift",
                ".research-clones/swift-act/agentkit/Tests/MCPServerTests/MCPServerTests.swift",
                ".research-clones/swift-act/agentkit/Tests/MCPServerTests/MCPToolProtocolTests.swift"
            ],
            destinationSeams: [.mcpBridge, .toolRegistry, .observability],
            importMode: .adapter,
            licenseDisposition: .knownPermissive,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "git -C .research-clones/swift-act/agentkit rev-parse HEAD",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "mixed stdio/http mcp.json configuration proof",
                    "client tool routing and wrapper proof",
                    "server tools/resources/prompts capability assembly proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorAgentKitMCPErgonomics.swift"
            ],
            notes: "Epistemos-owned MCP ergonomics values for config decoding, disabled/timeout validation, tool-to-client routing, tool wrappers, prompt rendering, and server capability assembly. Does not launch processes or claim the live MCP endpoint bridge complete."
        ),
        ChatDonorFeatureContract(
            id: "foundation-models.apple-native-model-ux",
            donor: .foundationModelsExample,
            featureID: "apple-native-model-ux",
            sourcePaths: [
                ".research-clones/swift-act/foundation-models-framework-example/Foundation Lab/ViewModels",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore"
            ],
            destinationSeams: [.modelUX, .providerPicker, .settingsSurface],
            importMode: .referenceOnly,
            licenseDisposition: .knownPermissive,
            status: .contractedPending,
            threading: .uiOnlyDefault,
            proof: proof(
                commands: ["git -C .research-clones/swift-act/foundation-models-framework-example rev-parse HEAD"],
                capabilityProofs: [
                    "availability-gated UI proof",
                    "sampling/options UX proof",
                    "structured-output motif proof"
                ],
                visualReadbackRequired: true,
                endpointProofRequired: false
            ),
            notes: "UX reference only until platform/API fit is rechecked."
        ),
        ChatDonorFeatureContract(
            id: "foundation-models.availability-options-values",
            donor: .foundationModelsExample,
            featureID: "availability-options-values",
            sourcePaths: [
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Capabilities/CheckModelAvailabilityUseCase.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Capabilities/InspectModelRuntimeUseCase.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Capabilities/GenerateStructuredDataUseCase.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Results/ModelAvailabilityResult.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Results/ModelRuntimeStatusResult.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Models/FoundationLabModelRuntime.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Models/FoundationLabReasoningLevel.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Models/FoundationLabGenerationOptions.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Models/FoundationLabExperimentConfiguration.swift",
                ".research-clones/swift-act/foundation-models-framework-example/FoundationLabCore/Sources/FoundationLabCore/Providers/FoundationModelsRuntimeInspector.swift",
                ".research-clones/swift-act/foundation-models-framework-example/Foundation Lab/Views/Playground/PlaygroundInspectorView.swift",
                ".research-clones/swift-act/foundation-models-framework-example/Foundation Lab/Views/Runs/RunConfigurationSection.swift",
                ".research-clones/swift-act/foundation-models-framework-example/Foundation Lab/Views/ModelUnavailableView.swift",
                ".research-clones/swift-act/foundation-models-framework-example/Tools/AFMCLI/Sources/AFMCLI/Commands/AvailableCommand.swift",
                ".research-clones/swift-act/foundation-models-framework-example/Tools/AFMCLI/Sources/AFMCLI/Commands/ModelRuntimePresentation.swift"
            ],
            destinationSeams: [.modelUX, .providerPicker, .settingsSurface],
            importMode: .adapter,
            licenseDisposition: .knownPermissive,
            status: .adaptedWithTests,
            threading: .uiOnlyDefault,
            proof: proof(
                commands: [
                    "git -C .research-clones/swift-act/foundation-models-framework-example rev-parse HEAD",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "availability and runtime picker gating proof",
                    "sampling/options normalization proof",
                    "structured-output request validation proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorFoundationModelUX.swift"
            ],
            notes: "Epistemos-owned value layer for Apple-native model availability, runtime picker presentation, generation options, reasoning gating, and structured-output request motifs. The broader visual UX contract remains pending until live Chat UI readback exists."
        ),
        ChatDonorFeatureContract(
            id: "foundation-models.runtime-picker-live-readback",
            donor: .foundationModelsExample,
            featureID: "runtime-picker-live-readback",
            sourcePaths: [
                ".research-clones/swift-act/foundation-models-framework-example/Foundation Lab/Views/Playground/PlaygroundInspectorView.swift",
                ".research-clones/swift-act/foundation-models-framework-example/Foundation Lab/Views/ModelUnavailableView.swift",
                ".research-clones/swift-act/foundation-models-framework-example/Tools/AFMCLI/Sources/AFMCLI/Commands/ModelRuntimePresentation.swift",
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorFoundationModelUX.swift"
            ],
            destinationSeams: [.modelUX, .providerPicker, .settingsSurface],
            importMode: .adapter,
            licenseDisposition: .knownPermissive,
            status: .adaptedWithTests,
            threading: .uiOnlyDefault,
            proof: proof(
                commands: [
                    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' test -only-testing:EpistemosTests/EpistemosRuntimePickerTests -only-testing:EpistemosTests/InlineRuntimePickerPanelTests",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "Apple Intelligence runtime availability metadata proof",
                    "settings action readback proof",
                    "new-session runtime-switch cue proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "Epistemos/Engine/EpistemosRuntimePicker.swift",
                "Epistemos/Views/Chat/InlineRuntimePickerPanel.swift",
                "Epistemos/App/RootView.swift",
                "Epistemos/Views/Settings/EpistemosPicksSectionView.swift",
                "EpistemosTests/EpistemosRuntimePickerTests.swift",
                "EpistemosTests/InlineRuntimePickerPanelTests.swift"
            ],
            notes: "Partial live app adaptation: the existing Epistemos picker now carries Foundation Models-style runtime availability, settings-action, system-image, and new-session readback for Apple Intelligence. This does not complete the broader apple-native-model-ux contract because no fresh visual readback was captured in this slice."
        ),
        ChatDonorFeatureContract(
            id: "swiftagent-1amageek.permissions-sandbox-cleanroom",
            donor: .swiftAgent1amageek,
            featureID: "permissions-sandbox-cleanroom",
            sourcePaths: [
                ".research-clones/swift-act/swiftagent-1amageek/Sources",
                ".research-clones/swift-act/swiftagent-1amageek/Tests"
            ],
            destinationSeams: [.permissionEngine, .toolRegistry, .mcpBridge],
            importMode: .cleanRoomStudy,
            licenseDisposition: .unknownStudyOnly,
            status: .cleanRoomPending,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: ["git -C .research-clones/swift-act/swiftagent-1amageek rev-parse HEAD"],
                capabilityProofs: [
                    "allow/deny grammar proof",
                    "approval bridge proof",
                    "timeout/cancellation proof",
                    "sandbox execution proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: true
            ),
            notes: "Study-only until license resolves; recreate concepts clean-room."
        ),
        ChatDonorFeatureContract(
            id: "swiftagent-1amageek.permission-policy-cleanroom",
            donor: .swiftAgent1amageek,
            featureID: "permission-policy-cleanroom",
            sourcePaths: [
                ".research-clones/swift-act/swiftagent-1amageek/Docs/SECURITY.md",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/PermissionRule.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/PermissionConfiguration.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/PermissionMiddleware.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/PermissionMode.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/SecurityConfiguration.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Security/SandboxExecutor.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/IO/ApprovalHandler.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/IO/ApprovalBridgeHandler.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/IO/TurnCancellationToken.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgent/Race.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgentPlugins/PluginToolPermission.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Sources/SwiftAgentSkills/SkillPermissions.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Tests/SwiftAgentTests/SecurityTests.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Tests/SwiftAgentTests/PluginPermissionRuntimeTests.swift",
                ".research-clones/swift-act/swiftagent-1amageek/Tests/SwiftAgentTests/TurnCancellationTokenTests.swift"
            ],
            destinationSeams: [.permissionEngine, .toolRegistry],
            importMode: .cleanRoomStudy,
            licenseDisposition: .unknownStudyOnly,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "git -C .research-clones/swift-act/swiftagent-1amageek rev-parse HEAD",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "allow/deny/final-deny/override grammar proof",
                    "approval receipt and session-memory proof",
                    "sandbox requirement and timeout proof",
                    "turn cancellation proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorPermissionCleanroom.swift"
            ],
            notes: "Clean-room Epistemos-owned permission policy, approval, sandbox requirement, timeout, and cancellation values inspired by 1amageek's security model. The broader skills/MCP/sandbox execution contract remains pending."
        ),
        ChatDonorFeatureContract(
            id: "swiftaia-agent.workflow-model-cleanroom",
            donor: .swiftAIAgent,
            featureID: "workflow-model-cleanroom",
            sourcePaths: [
                ".research-clones/swift-act/swiftaia-agent/README.md",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/AIAgent.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/AIAgentOutput.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/AIAgentOutput+File.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/Model/AIAgentConfiguration.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agent/Model/ToolCallingValue.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/Workflow.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/GoalManager.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/GoalManagerConfiguration.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/GoalManagerExecutionState.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Agents/GoalManagerError.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Models/AITask.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Models/AIGoalClarification.swift",
                ".research-clones/swift-act/swiftaia-agent/Sources/SwiftAIAgent/Models/AIStrategy.swift",
                ".research-clones/swift-act/swiftaia-agent/Tests/SwiftAIAgentTests/WorkflowTests.swift",
                ".research-clones/swift-act/swiftaia-agent/Tests/SwiftAIAgentTests/ToolCallingValueTests.swift",
                ".research-clones/swift-act/swiftaia-agent/Tests/SwiftAIAgentTests/AIAgentOutput+FileTests.swift",
                ".research-clones/swift-act/swiftaia-agent/Tests/SwiftAIAgentTests/FunctionCallingTests.swift"
            ],
            destinationSeams: [.workflow, .providerRuntime, .modelUX],
            importMode: .cleanRoomStudy,
            licenseDisposition: .unknownStudyOnly,
            status: .adaptedWithTests,
            threading: .nativeRuntimeDefault,
            proof: proof(
                commands: [
                    "git -C .research-clones/swift-act/swiftaia-agent rev-parse HEAD",
                    "swift test --package-path LocalPackages/EpistemosChatDonorContracts"
                ],
                capabilityProofs: [
                    "output normalization proof",
                    "max tool-iteration stop proof",
                    "workflow/goal loop motif proof"
                ],
                visualReadbackRequired: false,
                endpointProofRequired: false
            ),
            implementationPaths: [
                "LocalPackages/EpistemosChatDonorContracts/Sources/EpistemosChatDonorContracts/ChatDonorSwiftAIAgentCleanroom.swift"
            ],
            notes: "Clean-room Epistemos-owned workflow, model-output, tool-call parsing, max-iteration, and goal-plan values. Does not absorb Gemini SDK, Google tools, MCP client, or macro code."
        )
    ]

    public static func contracts(for donor: ChatDonorID) -> [ChatDonorFeatureContract] {
        swiftChat20260625.filter { $0.donor == donor }
    }

    public static var validationFailures: [String: [ChatDonorContractValidationFailure]] {
        Dictionary(
            uniqueKeysWithValues: swiftChat20260625.map { contract in
                (contract.id, contract.validationFailures)
            }
        ).filter { !$0.value.isEmpty }
    }

    private static func proof(
        commands: [String],
        capabilityProofs: [String],
        visualReadbackRequired: Bool,
        endpointProofRequired: Bool
    ) -> ChatDonorProofRequirement {
        ChatDonorProofRequirement(
            commands: commands,
            capabilityProofs: capabilityProofs,
            visualReadbackRequired: visualReadbackRequired,
            endpointProofRequired: endpointProofRequired
        )
    }
}
