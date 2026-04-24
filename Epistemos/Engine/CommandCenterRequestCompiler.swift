import Foundation
import os

#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

// MARK: - Command Center Request Compiler
//
// Rust control-plane boundary per PLAN_V2 §3.1 and §4.1.
//
// This type is now a thin Swift wrapper around the Rust authority at
// `agent_core/src/command_center.rs`. It still owns the one dependency
// Rust cannot reach from a stateless FFI call: `VaultSyncService`-backed
// @-mention resolution (vault title lookup still lives on the Swift side
// because `VaultSyncService` holds the indices today).
//
// Swift sends **user intent only** — query, mode, slash token, explicit
// tool toggles, requested brain, available brains, and resolved mention
// bodies. Swift does **not** supply the tool catalog. Rust derives the
// canonical catalog from its own `ToolRegistry` at the tier implied by
// the operating mode, so Rust is the sole source of truth for what tools
// exist and which are permitted at each tier.
//
// Once mentions are resolved, the compiler JSON-encodes the intent
// envelope, hands it to `compileCommandCenterRequest(inputJson:)` FFI, and
// decodes the returned JSON back into `CompiledCommandCenterRequest`. Rust
// owns:
//
//   - tool catalog truth (built from `ToolRegistry`, not from Swift state)
//   - runtime resolution (explicit unavailable brain never silently reroutes)
//   - tool-permission decision against the Rust-owned catalog + user toggles
//   - execution policy / route / budgets / expert allowlist / summary
//   - notes-context block assembly from resolved mentions
//
// `CompiledCommandCenterRequest` and all its nested Codable types stay
// authoritative as the Swift-facing contract — downstream consumers
// (ChatCoordinator and CommandCenterDiagnostics) keep
// binding the same shapes. The Rust side encodes the same JSON shape, and
// the existing Codable parity tests are the golden contract for both sides.

@MainActor
struct CommandCenterRequestCompiler {
    private static let log = Logger(subsystem: "com.epistemos", category: "CCRequestCompiler")

    /// Contract version. Must match `CONTRACT_VERSION` in
    /// `agent_core/src/command_center.rs`. Bump on both sides when the
    /// shape changes in a way that breaks serialization round-trips.
    static let contractVersion: String = "v1"

    struct Dependencies {
        /// Resolve notes by title (fuzzy). Closure so tests can inject fakes.
        let findNotesByTitle: @Sendable (String) async -> [VaultManifest.ManifestEntry]
        /// Fetch full note bodies by page ID.
        let fetchNoteBodies: @Sendable ([String]) async -> [VaultManifest.NoteBody]
        /// Full-text search by query, returns matching page IDs (for vault-scope refs).
        let searchIndex: @Sendable (String) async -> [String]
        /// Currently available brains (populated from InferenceState).
        let availableBrains: @MainActor () -> [ACCBrainSelection]
        /// Current auto-selection preview for the Command Center.
        let preferredAutoBrain: @MainActor () -> ACCBrainSelection?
        /// Absolute path to the currently-active vault. Swift hands this to
        /// Rust so `ToolRegistry` can build the canonical catalog inside
        /// the compile FFI. An empty string means "no vault open" — Rust
        /// will produce an empty catalog and synthesize explicit deny
        /// entries for every user-toggled tool (no silent drops).
        let vaultPath: @MainActor () -> String
    }

    enum CompileError: Error {
        case ffiUnavailable
        case encodeFailed(String)
        case ffiFailed(String)
        case decodeFailed(String)
    }

    let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// Compile a parsed user request into a fully resolved, normalized,
    /// serializable execution contract by delegating to the Rust authority.
    /// Swift resolves @-mentions locally (vault access), then everything
    /// else happens in `agent_core/src/command_center.rs`.
    func compile(
        request: ACCCommandRequest,
        conversationHistory: String?
    ) async -> CompiledCommandCenterRequest {
        let resolvedContextRefs = await resolveContextRefs(
            mentions: request.mentions,
            slashToken: request.slashToken,
            query: request.query
        )

        let availableBrains = dependencies.availableBrains().map(SerializedBrainSelection.init)
        let preferredAuto = dependencies.preferredAutoBrain().map(SerializedBrainSelection.init)
        let vaultPath = dependencies.vaultPath()

        let envelope = CompileInputEnvelope(
            query: request.query,
            conversationHistory: conversationHistory,
            operatingMode: request.operatingMode,
            slashToken: request.slashToken.map(SerializedSlashToken.init),
            brainOverride: request.brainOverride.map(SerializedBrainSelection.init),
            enabledToolNames: Array(request.enabledToolNames).sorted(),
            requestedMentions: request.mentions.map(SerializedMention.init),
            resolvedMentions: resolvedContextRefs,
            availableBrains: availableBrains,
            preferredAutoBrain: preferredAuto,
            vaultPath: vaultPath,
            graphContext: request.graphContext.map(SerializedGraphContext.init)
        )

        do {
            let compiled = try Self.compileViaFFI(envelope: envelope)
            Self.log.info(
                "[CCRC] compiled v=\(Self.contractVersion) mentions=\(resolvedContextRefs.count) tools_allow=\(compiled.resolvedToolPermissions.filter { $0.decision == .allow }.count)/\(compiled.resolvedToolPermissions.count) runtime=\(compiled.resolvedRuntime.resolved.displayName) route=\(compiled.resolvedExecutionPolicy.route)"
            )
            return compiled
        } catch {
            Self.log.error(
                "[CCRC] FFI compile failed — falling back to unavailable-brain shell: \(String(describing: error), privacy: .public)"
            )
            // Fail-closed shell so the caller still sees an inspectable
            // request even if the Rust side panics or the FFI is missing.
            // The fallback explicitly surfaces the failure via
            // `resolvedRuntime.fallbackReason` and an empty permission
            // table, so no silent success can hide a compiler outage.
            return Self.failClosedShell(
                envelope: envelope,
                resolvedContextRefs: resolvedContextRefs,
                reason: "ffi_compile_failed:\(error.localizedDescription)"
            )
        }
    }

    private static func compileViaFFI(envelope: CompileInputEnvelope) throws -> CompiledCommandCenterRequest {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let inputData: Data
        do {
            inputData = try encoder.encode(envelope)
        } catch {
            throw CompileError.encodeFailed(error.localizedDescription)
        }
        guard let inputJson = String(data: inputData, encoding: .utf8) else {
            throw CompileError.encodeFailed("non-utf8 input json")
        }

        #if canImport(agent_coreFFI)
        let outJson: String
        do {
            outJson = try compileCommandCenterRequest(inputJson: inputJson)
        } catch {
            throw CompileError.ffiFailed(String(describing: error))
        }
        guard let outData = outJson.data(using: .utf8) else {
            throw CompileError.decodeFailed("non-utf8 output json")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(CompiledCommandCenterRequest.self, from: outData)
        } catch {
            throw CompileError.decodeFailed(error.localizedDescription)
        }
        #else
        throw CompileError.ffiUnavailable
        #endif
    }

    private static func failClosedShell(
        envelope: CompileInputEnvelope,
        resolvedContextRefs: [ResolvedContextRef],
        reason: String
    ) -> CompiledCommandCenterRequest {
        // The fail-closed shell surfaces the compile failure explicitly via
        // `resolvedRuntime.fallbackReason` and an empty permission table so
        // no silent success can hide a compiler outage. `requested` is nil
        // here because `ResolvedRuntime.init` takes an `ACCBrainSelection?`
        // and this path is fed from the pre-serialized envelope — the
        // user's original intent remains visible at the top-level
        // `requestedBrain` field.
        let unavailable = ResolvedRuntime(
            requested: nil,
            resolved: .unavailable(reason: reason),
            fallbackReason: reason
        )
        let policy = ResolvedExecutionPolicy(
            requestedOperatingMode: envelope.operatingMode,
            effectiveOperatingMode: envelope.operatingMode,
            route: OverseerExecutionRoute.localOnly.rawValue,
            maxTurns: 1,
            maxReasoningSteps: 0,
            maxToolCalls: 0,
            maxOutputTokens: 4_096,
            expertAllowlist: ["general"],
            summary: "Tools: compile failed — \(reason)"
        )
        return CompiledCommandCenterRequest(
            contractVersion: Self.contractVersion,
            compiledAt: Date(),
            query: envelope.query,
            conversationHistory: envelope.conversationHistory,
            requestedSlashToken: envelope.slashToken,
            requestedOperatingMode: envelope.operatingMode,
            requestedBrain: envelope.brainOverride,
            requestedToolNames: Set(envelope.enabledToolNames),
            requestedMentions: envelope.requestedMentions,
            resolvedRuntime: unavailable,
            resolvedToolPermissions: [],
            resolvedContextRefs: resolvedContextRefs,
            resolvedExecutionPolicy: policy,
            notesContext: nil,
            graphContext: envelope.graphContext
        )
    }

    // MARK: - Mention Resolution
    // Rust control-plane boundary: this is the Swift implementation of @-mention
    // resolution that will move into `compile_command_center_request()` FFI once
    // agent_core exposes vault note lookup by title as a direct entry point. Today
    // it routes through VaultSyncService which already calls into Rust-backed
    // indices internally.

    private func resolveContextRefs(
        mentions: [ACCContextMention],
        slashToken: ParsedSlashToken?,
        query: String
    ) async -> [ResolvedContextRef] {
        var resolved: [ResolvedContextRef] = []
        resolved.reserveCapacity(mentions.count + 1)

        for mention in mentions {
            let ref = await resolveSingleMention(mention)
            resolved.append(ref)
        }

        return resolved
    }

    private func resolveSingleMention(
        _ mention: ACCContextMention
    ) async -> ResolvedContextRef {
        switch mention.mentionType {
        case .openNote:
            // User typed @[NoteTitle] or @NoteTitle — look up the vault note.
            let matches = await dependencies.findNotesByTitle(mention.token)
            guard let first = matches.first else {
                return .unresolved(
                    token: mention.token,
                    reason: "no_vault_note_matches_title"
                )
            }
            // Load the full body so downstream execution gets real content,
            // not just a chip label.
            let bodies = await dependencies.fetchNoteBodies([first.pageId])
            guard let body = bodies.first else {
                return .note(
                    id: first.pageId,
                    title: first.title,
                    preview: first.snippet,
                    body: nil,
                    approxTokens: first.wordCount * 4 / 3
                )
            }
            return .note(
                id: body.pageId,
                title: body.title,
                preview: first.snippet,
                body: body.body,
                approxTokens: body.body.count / 4
            )

        case .agent:
            return .agentTarget(
                agentId: mention.id.replacingOccurrences(of: "agent:", with: ""),
                label: mention.resolvedLabel
            )

        case .vault:
            // Vault-wide scope tokens: @AllNotes, @CurrentVault.
            let scope = VaultScope.fromToken(mention.token)
            return .vaultScope(scope: scope, label: mention.resolvedLabel)

        case .graph:
            return .graphScope(label: mention.resolvedLabel)

        case .folder:
            return .folderScope(folderName: mention.token, label: mention.resolvedLabel)

        case .skill:
            return .skillTarget(skillId: mention.token, label: mention.resolvedLabel)

        case .custom:
            return .unresolved(token: mention.token, reason: "custom_mention_type")
        }
    }

    // MARK: - FFI Input Envelope
    //
    // Codable shape that mirrors the Rust `CompileCommandCenterInput` struct
    // at `agent_core/src/command_center.rs`. Field names use camelCase so
    // they match the `#[serde(rename_all = "camelCase")]` attribute on the
    // Rust side exactly.
    //
    // This envelope carries user intent only. Swift does not send a tool
    // catalog — Rust builds the catalog from `ToolRegistry` at the tier
    // implied by `operatingMode`. Swift does pre-resolve mentions because
    // `VaultSyncService` still holds the indices; Rust consumes the
    // resolved refs directly.

    fileprivate struct CompileInputEnvelope: Codable {
        let query: String
        let conversationHistory: String?
        let operatingMode: EpistemosOperatingMode
        let slashToken: SerializedSlashToken?
        let brainOverride: SerializedBrainSelection?
        let enabledToolNames: [String]
        let requestedMentions: [SerializedMention]
        let resolvedMentions: [ResolvedContextRef]
        let availableBrains: [SerializedBrainSelection]
        let preferredAutoBrain: SerializedBrainSelection?
        /// Absolute path to the active vault so Rust can open it and build
        /// the Rust-owned tool catalog inside the compile FFI. Empty when
        /// no vault is open — Rust responds with an empty catalog and
        /// synthesized deny entries for every user-toggled tool.
        let vaultPath: String
        /// Graph context when the request originated from a graph-workspace
        /// "Ask Graph Chat" action. PLAN_V2 §4.1 requires the normalized
        /// command to carry real graph context into the Rust compile path.
        let graphContext: SerializedGraphContext?
    }
}

// MARK: - Compiled Request Contract (Codable; Swift↔Rust round-trip)

/// Fully resolved Command Center request, ready for downstream execution.
/// Carries both requested user input and resolved runtime truth in a single,
/// inspectable, serializable record. The shape is the Swift mirror of the
/// eventual Rust `CompiledCommandCenterRequest` that will own this resolution.
struct CompiledCommandCenterRequest: Codable, Sendable, Equatable {
    // Contract envelope
    let contractVersion: String
    let compiledAt: Date

    // Cleaned query + history passed straight through
    let query: String
    let conversationHistory: String?

    // ───── Requested (explicit user choices) ─────
    let requestedSlashToken: SerializedSlashToken?
    let requestedOperatingMode: EpistemosOperatingMode
    let requestedBrain: SerializedBrainSelection?
    let requestedToolNames: Set<String>
    let requestedMentions: [SerializedMention]

    // ───── Resolved (compiler output) ─────
    let resolvedRuntime: ResolvedRuntime
    let resolvedToolPermissions: [ResolvedToolPermission]
    let resolvedContextRefs: [ResolvedContextRef]
    let resolvedExecutionPolicy: ResolvedExecutionPolicy

    // ───── Derived artifacts passed into downstream execution ─────
    let notesContext: String?
    /// Graph context when the request originated from a graph workspace
    /// "Ask Graph Chat" action. Passed through from the input so
    /// downstream execution and the inspector can surface provenance.
    let graphContext: SerializedGraphContext?

    // Convenience accessors used by the inspector + tests.
    var allowedToolNames: Set<String> {
        Set(resolvedToolPermissions.compactMap { $0.decision == .allow ? $0.toolName : nil })
    }

    var resolvedNoteIds: [String] {
        resolvedContextRefs.compactMap { ref in
            if case .note(let id, _, _, _, _) = ref { return id }
            return nil
        }
    }

    var unresolvedMentions: [String] {
        resolvedContextRefs.compactMap { ref in
            if case .unresolved(let token, _) = ref { return token }
            return nil
        }
    }
}

// MARK: - Resolved Runtime

struct ResolvedRuntime: Codable, Sendable, Equatable {
    /// nil = user did not pick an explicit brain (auto-route).
    let requested: SerializedBrainSelection?
    /// What the runtime will actually run on.
    let resolved: ResolvedBrainDescriptor
    /// Populated when requested != resolved.
    let fallbackReason: String?

    init(
        requested: ACCBrainSelection?,
        resolved: ResolvedBrainDescriptor,
        fallbackReason: String?
    ) {
        self.requested = requested.map(SerializedBrainSelection.init)
        self.resolved = resolved
        self.fallbackReason = fallbackReason
    }
}

enum ResolvedBrainDescriptor: Codable, Sendable, Equatable {
    case local(modelId: String, displayName: String)
    case appleIntelligence
    case cloud(provider: String, displayName: String)
    case unavailable(reason: String)

    init(from selection: ACCBrainSelection) {
        switch selection {
        case .local(let modelId, let name, _, _, _):
            self = .local(modelId: modelId, displayName: name)
        case .appleIntelligence:
            self = .appleIntelligence
        case .cloud(let provider):
            self = .cloud(provider: provider.rawValue, displayName: provider.displayName)
        }
    }

    var displayName: String {
        switch self {
        case .local(_, let name): name
        case .appleIntelligence: "Apple Intelligence"
        case .cloud(_, let name): name
        case .unavailable(let reason): "Unavailable (\(reason))"
        }
    }

    var category: String {
        switch self {
        case .local: "local"
        case .appleIntelligence: "apple_intelligence"
        case .cloud: "cloud"
        case .unavailable: "unavailable"
        }
    }
}

// MARK: - Resolved Tool Permission

struct ResolvedToolPermission: Codable, Sendable, Equatable, Identifiable {
    let toolName: String
    let agent: String
    let description: String
    let decision: Decision
    let requiresConfirmation: Bool
    let destructive: Bool

    var id: String { toolName }

    enum Decision: Codable, Sendable, Equatable {
        case allow
        case deny(reason: String)

        var isAllowed: Bool {
            if case .allow = self { return true }
            return false
        }
    }
}

// MARK: - Resolved Context Ref

enum ResolvedContextRef: Codable, Sendable, Hashable, Identifiable {
    case note(id: String, title: String, preview: String, body: String?, approxTokens: Int)
    case agentTarget(agentId: String, label: String)
    case vaultScope(scope: VaultScope, label: String)
    case graphScope(label: String)
    case folderScope(folderName: String, label: String)
    case skillTarget(skillId: String, label: String)
    case unresolved(token: String, reason: String)

    var id: String {
        switch self {
        case .note(let id, _, _, _, _): "note:\(id)"
        case .agentTarget(let id, _): "agent:\(id)"
        case .vaultScope(let scope, _): "vault:\(scope.rawValue)"
        case .graphScope: "graph"
        case .folderScope(let name, _): "folder:\(name)"
        case .skillTarget(let id, _): "skill:\(id)"
        case .unresolved(let token, _): "unresolved:\(token)"
        }
    }

    var label: String {
        switch self {
        case .note(_, let title, _, _, _): title
        case .agentTarget(_, let label): label
        case .vaultScope(_, let label): label
        case .graphScope(let label): label
        case .folderScope(_, let label): label
        case .skillTarget(_, let label): label
        case .unresolved(let token, _): token
        }
    }

    var kind: String {
        switch self {
        case .note: "note"
        case .agentTarget: "agent"
        case .vaultScope: "vault_scope"
        case .graphScope: "graph_scope"
        case .folderScope: "folder_scope"
        case .skillTarget: "skill"
        case .unresolved: "unresolved"
        }
    }
}

enum VaultScope: String, Codable, Sendable, Hashable {
    case allNotes
    case currentVault
    case currentGraph

    static func fromToken(_ token: String) -> VaultScope {
        switch token.lowercased() {
        case "allnotes", "all notes", "all_notes": .allNotes
        case "currentgraph", "current graph": .currentGraph
        default: .currentVault
        }
    }
}

// MARK: - Resolved Execution Policy

struct ResolvedExecutionPolicy: Codable, Sendable, Equatable {
    let requestedOperatingMode: EpistemosOperatingMode
    let effectiveOperatingMode: EpistemosOperatingMode
    /// Raw route value from OverseerExecutionRoute ("local_only" | "overseer_local_execution" | "managed_agent_session").
    let route: String
    let maxTurns: Int
    let maxReasoningSteps: Int
    let maxToolCalls: Int
    let maxOutputTokens: Int
    let expertAllowlist: [String]
    let summary: String
}

// MARK: - Serialized mirrors for Codable round-trip

/// Codable mirror of ParsedSlashToken. ParsedSlashToken contains non-Codable
/// payloads (SkillDiscoveryEntry), so the compiled request carries a projected
/// serializable form.
struct SerializedSlashToken: Codable, Sendable, Equatable {
    let kind: Kind
    let identifier: String
    let displayName: String

    enum Kind: String, Codable, Sendable, Equatable {
        case builtinMode
        case skill
    }

    init(_ token: ParsedSlashToken) {
        switch token {
        case .builtinMode(let cmd):
            self.kind = .builtinMode
            self.identifier = cmd.rawValue
            self.displayName = cmd.displayName
        case .skill(let entry):
            self.kind = .skill
            self.identifier = entry.identifier
            self.displayName = entry.title
        }
    }

    /// SF Symbol name for inspector rendering. Reconstructed from the
    /// identifier so the inspector can display a compiled slash token without
    /// needing the original ParsedSlashToken back.
    var icon: String {
        switch kind {
        case .builtinMode:
            return ACCSlashCommand(rawValue: identifier)?.icon ?? "text.bubble"
        case .skill:
            return "wand.and.stars"
        }
    }
}

/// Codable mirror of ACCBrainSelection.
struct SerializedBrainSelection: Codable, Sendable, Equatable {
    let kind: Kind
    let identifier: String
    let displayName: String

    enum Kind: String, Codable, Sendable, Equatable {
        case local
        case appleIntelligence
        case cloud
    }

    init(_ selection: ACCBrainSelection) {
        switch selection {
        case .local(let modelId, let name, _, _, _):
            self.kind = .local
            self.identifier = modelId
            self.displayName = name
        case .appleIntelligence:
            self.kind = .appleIntelligence
            self.identifier = "apple"
            self.displayName = "Apple Intelligence"
        case .cloud(let provider):
            self.kind = .cloud
            self.identifier = provider.rawValue
            self.displayName = provider.displayName
        }
    }
}

/// Codable mirror of GraphChatRequest for the FFI round-trip. Carries the
/// six PLAN_V2 §4.1 fields into the Rust compile path.
struct SerializedGraphContext: Codable, Sendable, Equatable {
    let graphNodeId: String
    let sourceId: String?
    let nodeType: String
    let nodeLabel: String
    let graphRoute: String

    init(_ request: GraphChatRequest) {
        self.graphNodeId = request.graphNodeId
        self.sourceId = request.sourceId
        self.nodeType = request.nodeType
        self.nodeLabel = request.nodeLabel
        self.graphRoute = request.route.serializationKey
    }
}

/// Codable mirror of ACCContextMention.
struct SerializedMention: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let token: String
    let resolvedLabel: String
    let mentionType: String

    init(_ mention: ACCContextMention) {
        self.id = mention.id
        self.token = mention.token
        self.resolvedLabel = mention.resolvedLabel
        self.mentionType = mention.mentionType.rawValue
    }
}
