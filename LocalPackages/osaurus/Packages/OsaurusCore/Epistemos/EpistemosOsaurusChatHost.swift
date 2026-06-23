//  EpistemosOsaurusChatHost.swift
//  OsaurusCore — EPISTEMOS HOST SEAM
//
//  Owner directive 2026-06-22 ("ACT = OSAURUS IS THE CHAT"): the Epistemos
//  "act" surface must BE the real Osaurus chat UI — the genuine vendored
//  surface, skinned from Epistemos's selected theme tokens — not the old Epistemos `ChatView`
//  with an engine swap behind a toggle. The Osaurus `ChatView` /
//  `ChatWindowState` are `internal` to this package, so the Epistemos module
//  cannot reference them directly even though it links `OsaurusCore`.
//
//  This file is the ONE public entry point that closes that gap. It is purely
//  additive: it modifies no existing Osaurus type and changes no Osaurus
//  behaviour. It owns a stable `ChatWindowState` (held as `@StateObject` so the
//  window/session survive re-renders) and renders the genuine Osaurus
//  `ChatView`, then skins it from Epistemos-supplied preset/custom tokens by
//  feeding Epistemos-built tokens into a source-level Osaurus skin seam that
//  the cloned chat views read directly. The host does not persist or globally
//  select an Osaurus theme.

import SwiftUI

/// Primitive theme bridge from Epistemos into OsaurusCore. The Epistemos app
/// owns the real preset/custom theme system; OsaurusCore only needs resolved
/// colors and fonts, not the Epistemos module's theme types.
public struct EpistemosOsaurusThemeTokens: Equatable, Sendable {
    public var id: String
    public var isDark: Bool
    public var primaryText: String
    public var secondaryText: String
    public var tertiaryText: String
    public var primaryBackground: String
    public var secondaryBackground: String
    public var tertiaryBackground: String
    public var sidebarBackground: String
    public var sidebarSelectedBackground: String
    public var accentColor: String
    public var accentColorLight: String
    public var primaryBorder: String
    public var secondaryBorder: String
    public var focusBorder: String
    public var cardBackground: String
    public var cardBorder: String
    public var buttonBackground: String
    public var buttonBorder: String
    public var inputBackground: String
    public var inputBorder: String
    public var glassTintOverlay: String
    public var codeBlockBackground: String
    public var shadowColor: String
    public var selectionColor: String
    public var cursorColor: String
    public var placeholderText: String
    public var primaryFont: String
    public var monoFont: String

    public init(
        id: String,
        isDark: Bool,
        primaryText: String,
        secondaryText: String,
        tertiaryText: String,
        primaryBackground: String,
        secondaryBackground: String,
        tertiaryBackground: String,
        sidebarBackground: String,
        sidebarSelectedBackground: String,
        accentColor: String,
        accentColorLight: String,
        primaryBorder: String,
        secondaryBorder: String,
        focusBorder: String,
        cardBackground: String,
        cardBorder: String,
        buttonBackground: String,
        buttonBorder: String,
        inputBackground: String,
        inputBorder: String,
        glassTintOverlay: String,
        codeBlockBackground: String,
        shadowColor: String,
        selectionColor: String,
        cursorColor: String,
        placeholderText: String,
        primaryFont: String,
        monoFont: String
    ) {
        self.id = id
        self.isDark = isDark
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.tertiaryText = tertiaryText
        self.primaryBackground = primaryBackground
        self.secondaryBackground = secondaryBackground
        self.tertiaryBackground = tertiaryBackground
        self.sidebarBackground = sidebarBackground
        self.sidebarSelectedBackground = sidebarSelectedBackground
        self.accentColor = accentColor
        self.accentColorLight = accentColorLight
        self.primaryBorder = primaryBorder
        self.secondaryBorder = secondaryBorder
        self.focusBorder = focusBorder
        self.cardBackground = cardBackground
        self.cardBorder = cardBorder
        self.buttonBackground = buttonBackground
        self.buttonBorder = buttonBorder
        self.inputBackground = inputBackground
        self.inputBorder = inputBorder
        self.glassTintOverlay = glassTintOverlay
        self.codeBlockBackground = codeBlockBackground
        self.shadowColor = shadowColor
        self.selectionColor = selectionColor
        self.cursorColor = cursorColor
        self.placeholderText = placeholderText
        self.primaryFont = primaryFont
        self.monoFont = monoFont
    }

    public static let fallback = EpistemosOsaurusThemeTokens(
        id: "epistemos-fallback",
        isDark: false,
        primaryText: "#1c1c1e",
        secondaryText: "#6e6e73",
        tertiaryText: "#8e8e93",
        primaryBackground: "#fbfaf5",
        secondaryBackground: "#f4f3ee",
        tertiaryBackground: "#eeede7",
        sidebarBackground: "#f2f1eb",
        sidebarSelectedBackground: "#e7e6df",
        accentColor: "#1c1c1e",
        accentColorLight: "#3a3a3c",
        primaryBorder: "#e3e1d8",
        secondaryBorder: "#eceae2",
        focusBorder: "#1c1c1e",
        cardBackground: "#ffffff",
        cardBorder: "#e3e1d8",
        buttonBackground: "#f4f3ee",
        buttonBorder: "#e3e1d8",
        inputBackground: "#ffffff",
        inputBorder: "#e3e1d8",
        glassTintOverlay: "#fbfaf5e0",
        codeBlockBackground: "#f2f1eb",
        shadowColor: "#000000",
        selectionColor: "#1c1c1e33",
        cursorColor: "#1c1c1e",
        placeholderText: "#a8a8ad",
        primaryFont: "SF Pro",
        monoFont: "SF Mono"
    )

    var signature: String {
        [
            id,
            String(isDark),
            primaryText,
            secondaryText,
            tertiaryText,
            primaryBackground,
            secondaryBackground,
            tertiaryBackground,
            sidebarBackground,
            sidebarSelectedBackground,
            accentColor,
            accentColorLight,
            primaryBorder,
            secondaryBorder,
            focusBorder,
            cardBackground,
            cardBorder,
            buttonBackground,
            buttonBorder,
            inputBackground,
            inputBorder,
            glassTintOverlay,
            codeBlockBackground,
            shadowColor,
            selectionColor,
            cursorColor,
            placeholderText,
            primaryFont,
            monoFont,
        ].joined(separator: "|")
    }

    var customTheme: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "E9150305-0000-0000-0000-000000000001")!,
                name: "Epistemos",
                version: "1.0",
                author: "Epistemos"
            ),
            colors: ThemeColors(
                primaryText: primaryText,
                secondaryText: secondaryText,
                tertiaryText: tertiaryText,
                primaryBackground: primaryBackground,
                secondaryBackground: secondaryBackground,
                tertiaryBackground: tertiaryBackground,
                sidebarBackground: sidebarBackground,
                sidebarSelectedBackground: sidebarSelectedBackground,
                accentColor: accentColor,
                accentColorLight: accentColorLight,
                primaryBorder: primaryBorder,
                secondaryBorder: secondaryBorder,
                focusBorder: focusBorder,
                successColor: "#34c759",
                warningColor: "#ff9f0a",
                errorColor: "#ff3b30",
                infoColor: accentColor,
                cardBackground: cardBackground,
                cardBorder: cardBorder,
                buttonBackground: buttonBackground,
                buttonBorder: buttonBorder,
                inputBackground: inputBackground,
                inputBorder: inputBorder,
                glassTintOverlay: glassTintOverlay,
                codeBlockBackground: codeBlockBackground,
                shadowColor: shadowColor,
                selectionColor: selectionColor,
                cursorColor: cursorColor,
                placeholderText: placeholderText
            ),
            background: .default,
            glass: ThemeGlass(enabled: false),
            typography: ThemeTypography(primaryFont: primaryFont, monoFont: monoFont),
            isBuiltIn: false,
            isDark: isDark
        )
    }
}

public struct EpistemosOsaurusRecentSessionSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let updatedAt: Date

    public init(id: UUID, title: String, subtitle: String, updatedAt: Date) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.updatedAt = updatedAt
    }
}

public struct EpistemosOsaurusTranscriptMessage: Identifiable, Equatable, Sendable {
    public enum Role: String, Equatable, Sendable {
        case user
        case assistant
        case tool
        case system
    }

    public let id: UUID
    public let role: Role
    public let content: String
    public let createdAt: Date?
    public let completedAt: Date?
    public let thinking: String
    public let thinkingDuration: TimeInterval?

    public init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date? = nil,
        completedAt: Date? = nil,
        thinking: String = "",
        thinkingDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.thinking = thinking
        self.thinkingDuration = thinkingDuration
    }
}

public struct EpistemosOsaurusSessionTranscript: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let selectedModel: String?
    public let messages: [EpistemosOsaurusTranscriptMessage]

    public init(
        id: UUID,
        title: String,
        selectedModel: String?,
        messages: [EpistemosOsaurusTranscriptMessage]
    ) {
        self.id = id
        self.title = title
        self.selectedModel = selectedModel
        self.messages = messages
    }
}

public enum EpistemosOsaurusSessionBridge {
    @MainActor
    public static func recentSessions(limit: Int = 4) -> [EpistemosOsaurusRecentSessionSummary] {
        ChatSessionsManager.shared.refresh()
        return ChatSessionsManager.shared.sessions(for: Agent.defaultId)
            .filter { !$0.archived }
            .prefix(max(0, limit))
            .map { session in
                EpistemosOsaurusRecentSessionSummary(
                    id: session.id,
                    title: session.title.isEmpty ? L("New Chat") : session.title,
                    subtitle: session.selectedModel ?? L("Osaurus chat"),
                    updatedAt: session.updatedAt
                )
            }
    }

    @MainActor
    public static func loadTranscript(id: UUID) -> EpistemosOsaurusSessionTranscript? {
        guard let session = ChatSessionStore.load(id: id) else { return nil }
        return EpistemosOsaurusSessionTranscript(
            id: session.id,
            title: session.title.isEmpty ? L("New Chat") : session.title,
            selectedModel: session.selectedModel,
            messages: session.turns.map(transcriptMessage)
        )
    }

    @MainActor
    @discardableResult
    public static func saveTranscript(
        sessionId: UUID?,
        messages: [EpistemosOsaurusTranscriptMessage],
        selectedModel: String?,
        title: String? = nil
    ) -> UUID {
        let now = Date()
        let turns = messages.map(turnData)
        let providedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var session = sessionId.flatMap { ChatSessionStore.load(id: $0) } ?? ChatSessionData(
            id: sessionId ?? UUID(),
            title: providedTitle.isEmpty ? ChatSessionData.generateTitle(from: turns) : providedTitle,
            createdAt: now,
            updatedAt: now,
            selectedModel: selectedModel,
            turns: [],
            agentId: Agent.defaultId
        )
        session.turns = turns
        session.updatedAt = now
        session.selectedModel = selectedModel ?? session.selectedModel
        session.agentId = session.agentId ?? Agent.defaultId
        if !providedTitle.isEmpty {
            session.title = providedTitle
        } else if session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || session.title == L("New Chat")
            || session.title == "New Chat" {
            session.title = ChatSessionData.generateTitle(from: turns)
        }
        session.capabilities = SessionCapability.derive(from: turns)
        ChatSessionsManager.shared.save(session)
        return session.id
    }

    private static func transcriptMessage(_ turn: ChatTurnData) -> EpistemosOsaurusTranscriptMessage {
        EpistemosOsaurusTranscriptMessage(
            id: turn.id,
            role: transcriptRole(turn.role),
            content: turn.content,
            createdAt: turn.createdAt,
            completedAt: turn.completedAt,
            thinking: turn.thinking,
            thinkingDuration: turn.thinkingDuration
        )
    }

    private static func turnData(_ message: EpistemosOsaurusTranscriptMessage) -> ChatTurnData {
        ChatTurnData(
            id: message.id,
            role: osaurusRole(message.role),
            content: message.content,
            thinkingDuration: message.thinkingDuration,
            thinking: message.thinking,
            createdAt: message.createdAt,
            completedAt: message.completedAt
        )
    }

    private static func transcriptRole(_ role: MessageRole) -> EpistemosOsaurusTranscriptMessage.Role {
        switch role {
        case .user: return .user
        case .assistant: return .assistant
        case .tool: return .tool
        case .system: return .system
        }
    }

    private static func osaurusRole(_ role: EpistemosOsaurusTranscriptMessage.Role) -> MessageRole {
        switch role {
        case .user: return .user
        case .assistant: return .assistant
        case .tool: return .tool
        case .system: return .system
        }
    }
}

/// Public host that mounts the real Osaurus chat surface inside the Epistemos
/// app, skinned from Epistemos theme tokens at the Osaurus source. The hosted
/// view is the genuine Osaurus `ChatView` — same code that runs in standalone
/// Osaurus — so behaviour matches the working app rather than a partial
/// re-integration.
public struct EpistemosOsaurusChatHost: View {
    /// Owned so the window/session state is stable across SwiftUI re-renders.
    /// `ChatView(windowState:)` wraps this in an `ObservedObject`; the owner of
    /// the lifetime must therefore be a `@StateObject` here, not a freshly
    /// constructed value on each `body` evaluation.
    @StateObject private var windowState: ChatWindowState
    private let requestedSessionId: UUID?
    private let initialPrompt: String?
    private let initialPromptId: UUID?
    private let themeTokens: EpistemosOsaurusThemeTokens
    private let onSessionChanged: ((UUID?) -> Void)?
    private let onInitialPromptConsumed: (() -> Void)?
    @State private var submittedInitialPromptId: UUID?

    /// - Parameters:
    ///   - windowId: stable identity for this chat window. Defaults to a fresh
    ///     UUID; pass a persisted id to reattach an existing window.
    ///   - agentId: the agent to bind. Defaults to Osaurus's built-in default
    ///     agent (`Agent.defaultId`).
    ///   - sessionId: optional existing Osaurus session to open immediately.
    ///   - themeTokens: resolved Epistemos preset/custom theme tokens for this
    ///     mount. The default is a fallback only for previews/tests; the app
    ///     passes its live selected theme.
    public init(
        windowId: UUID = UUID(),
        agentId: UUID? = nil,
        sessionId: UUID? = nil,
        initialPrompt: String? = nil,
        initialPromptId: UUID? = nil,
        themeTokens: EpistemosOsaurusThemeTokens = .fallback,
        onSessionChanged: ((UUID?) -> Void)? = nil,
        onInitialPromptConsumed: (() -> Void)? = nil
    ) {
        self.requestedSessionId = sessionId
        self.initialPrompt = initialPrompt
        self.initialPromptId = initialPromptId
        self.themeTokens = themeTokens
        self.onSessionChanged = onSessionChanged
        self.onInitialPromptConsumed = onInitialPromptConsumed
        // Apply the owner's active Epistemos theme to the cloned Osaurus source
        // before ChatView renders. This is not a persisted Osaurus theme.
        Self.applyEpistemosSourceSkin(themeTokens)
        let sessionData = sessionId.flatMap { ChatSessionStore.load(id: $0) }
        let resolvedAgentId = sessionData?.agentId ?? agentId ?? Agent.defaultId
        let state = ChatWindowState(
            windowId: windowId,
            agentId: resolvedAgentId,
            sessionData: sessionData
        )
        // Act owns recent chats through Epistemos's single toolbar popover; the
        // Osaurus session rail stays hidden in Epistemos mode. The side-panel
        // graft is the right-hand context inspector inside ChatView.
        state.showSidebar = false
        _windowState = StateObject(wrappedValue: state)
    }

    public var body: some View {
        ChatView(windowState: windowState)
            // GRAFT 3 — SCROLL-BLUR (owner must-keep 2026-06-22): a soft top-edge progressive
            // blur so content dissolves as it scrolls up — the loved Epistemos scroll interaction
            // brought onto the Osaurus surface. Purely additive overlay (no change to Osaurus's
            // ChatView): a thin material band, strongest at the very top and fading to clear, that
            // blurs whatever scrolls under it. Never intercepts input.
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            colors: [Color.black, Color.black.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 34)
                    .allowsHitTesting(false)
            }
            .onChange(of: themeTokens) { _, newTokens in
                Self.applyEpistemosSourceSkin(newTokens)
            }
            .onChange(of: requestedSessionId) { _, newSessionId in
                loadRequestedSession(newSessionId)
            }
            .onChange(of: initialPromptId) { _, _ in
                sendInitialPromptIfNeeded()
            }
            .onReceive(windowState.session.$sessionId) { sessionId in
                onSessionChanged?(sessionId)
            }
            .task {
                Self.bootstrapAndThemeOnce()
                Self.applyEpistemosSourceSkin(themeTokens)
                onSessionChanged?(windowState.session.sessionId)
                loadRequestedSession(requestedSessionId)
                sendInitialPromptIfNeeded()
            }
    }

    @MainActor
    private func loadRequestedSession(_ sessionId: UUID?) {
        guard let sessionId else { return }
        guard windowState.session.sessionId != sessionId else { return }
        guard let sessionData = ChatSessionStore.load(id: sessionId) else {
            windowState.refreshSessions()
            return
        }
        windowState.loadSession(sessionData)
        windowState.showSidebar = false
    }

    @MainActor
    private func sendInitialPromptIfNeeded() {
        guard requestedSessionId == nil else { return }
        guard let initialPromptId, submittedInitialPromptId != initialPromptId else { return }
        let prompt = initialPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else { return }
        submittedInitialPromptId = initialPromptId
        windowState.startNewChat()
        windowState.session.send(prompt)
        onInitialPromptConsumed?()
    }

    // MARK: - Epistemos bootstrap + reskin

    @MainActor private static var didBootstrap = false

    /// Run once when the Osaurus surface first appears inside Epistemos:
    /// (1) the launch-time registration standalone Osaurus does in its own
    /// `AppDelegate` — which Epistemos's `AppDelegate` never runs — so the chat
    /// has its agent configuration domains + document adapters. Both calls are
    /// idempotent (internal latches) and side-effect-free (NO local server, NO
    /// Sparkle/login-item — the chat generates in-process via `ChatEngine` →
    /// `MLXService`, so the HTTP server is not needed).
    @MainActor
    private static func bootstrapAndThemeOnce() {
        guard !didBootstrap else { return }
        didBootstrap = true
        ConfigurationDomainBootstrap.registerBuiltIns()
        DocumentAdaptersBootstrap.registerBuiltIns()
        seedOwnerDefaultModelOnce()
    }

    @MainActor private static var appliedThemeSignature: String?

    /// Apply the owner's selected Epistemos preset/custom theme to the cloned
    /// Osaurus source surface. Runtime-only: no Osaurus active-theme
    /// persistence, no fixed palette masquerading as the user's settings.
    @MainActor
    private static func applyEpistemosSourceSkin(_ tokens: EpistemosOsaurusThemeTokens) {
        guard appliedThemeSignature != tokens.signature else { return }
        appliedThemeSignature = tokens.signature
        EpistemosOsaurusSourceSkin.shared.apply(tokens)
    }

    /// Owner 2026-06-22 (#1 concern — "send works with MY models"): the new Osaurus act
    /// surface picks its default model from the default agent (Osaurus's), so the owner's
    /// first send would use Osaurus's default rather than their own model. Seed the default
    /// agent's model to the owner's first registered model so the FIRST send uses the owner's
    /// model. Guarded by a PERSISTENT flag (not just the per-process `didBootstrap`) so this
    /// runs exactly ONCE ever and NEVER re-clobbers the owner's later picker choice (which
    /// auto-persists into the agent settings). Honest no-op when no owner model is registered.
    @MainActor
    private static func seedOwnerDefaultModelOnce() {
        let seededKey = "epistemos.act.didSeedOwnerDefaultModel.v1"
        guard let model = ownerModelToSeed(
            alreadySeeded: UserDefaults.standard.bool(forKey: seededKey),
            ownerModels: EpistemosModelBridge.providedModelIds()
        ) else { return }
        AgentManager.shared.updateDefaultModel(for: Agent.defaultId, model: model)
        // Mark seeded ONLY after a successful seed — so if the model bridge isn't registered yet
        // at first mount (no owner models), we DON'T latch, and a later mount retries once the
        // owner's models are available. (The earlier version latched before the model check,
        // which could permanently skip seeding on an unlucky first-mount race.)
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    /// Pure decision for `seedOwnerDefaultModelOnce` — testable without globals. Returns the model
    /// to seed as the default-agent model, or nil to skip: nil when already seeded (never re-clobber
    /// the owner's later picker choice) OR when no owner model is registered yet (skip WITHOUT
    /// latching, so a later mount retries).
    static func ownerModelToSeed(alreadySeeded: Bool, ownerModels: [String]) -> String? {
        guard !alreadySeeded else { return nil }
        return ownerModels.first
    }

}
