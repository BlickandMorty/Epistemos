//  EpistemosOsaurusChatHost.swift
//  OsaurusCore — EPISTEMOS HOST SEAM
//
//  Owner directive 2026-06-22 ("ACT = OSAURUS IS THE CHAT"): the Epistemos
//  "act" surface must BE the real Osaurus chat UI — the genuine vendored
//  surface, reskinned to the Epistemos look — not the old Epistemos `ChatView`
//  with an engine swap behind a toggle. The Osaurus `ChatView` /
//  `ChatWindowState` are `internal` to this package, so the Epistemos module
//  cannot reference them directly even though it links `OsaurusCore`.
//
//  This file is the ONE public entry point that closes that gap. It is purely
//  additive: it modifies no existing Osaurus type and changes no Osaurus
//  behaviour. It owns a stable `ChatWindowState` (held as `@StateObject` so the
//  window/session survive re-renders) and renders the genuine Osaurus
//  `ChatView`, then reskins it to the Epistemos cream/monospace palette by
//  applying an Epistemos `CustomTheme` through the existing `ThemeManager`
//  (which every Osaurus view already reads). The reskin is runtime-only
//  (`persist: false` — no write to Osaurus's theme storage).

import SwiftUI

/// Public host that mounts the real Osaurus chat surface inside the Epistemos
/// app, reskinned to the Epistemos look. The hosted view is the genuine Osaurus
/// `ChatView` — same code that runs in standalone Osaurus — so behaviour matches
/// the working app rather than a partial re-integration.
public struct EpistemosOsaurusChatHost: View {
    /// Owned so the window/session state is stable across SwiftUI re-renders.
    /// `ChatView(windowState:)` wraps this in an `ObservedObject`; the owner of
    /// the lifetime must therefore be a `@StateObject` here, not a freshly
    /// constructed value on each `body` evaluation.
    @StateObject private var windowState: ChatWindowState

    /// - Parameters:
    ///   - windowId: stable identity for this chat window. Defaults to a fresh
    ///     UUID; pass a persisted id to reattach an existing window.
    ///   - agentId: the agent to bind. Defaults to Osaurus's built-in default
    ///     agent (`Agent.defaultId`).
    public init(windowId: UUID = UUID(), agentId: UUID? = nil) {
        _windowState = StateObject(
            wrappedValue: ChatWindowState(windowId: windowId, agentId: agentId ?? Agent.defaultId)
        )
    }

    public var body: some View {
        ChatView(windowState: windowState)
            .task { Self.bootstrapAndThemeOnce() }
    }

    // MARK: - Epistemos bootstrap + reskin

    @MainActor private static var didBootstrap = false

    /// Run once when the Osaurus surface first appears inside Epistemos:
    /// (1) the launch-time registration standalone Osaurus does in its own
    /// `AppDelegate` — which Epistemos's `AppDelegate` never runs — so the chat
    /// has its agent configuration domains + document adapters. Both calls are
    /// idempotent (internal latches) and side-effect-free (NO local server, NO
    /// Sparkle/login-item — the chat generates in-process via `ChatEngine` →
    /// `MLXService`, so the HTTP server is not needed). (2) Apply the Epistemos
    /// cream/monospace palette runtime-only (`persist: false`); every Osaurus
    /// view reads `ThemeManager.shared.currentTheme`, so this reskins the whole
    /// surface (thread, composer, sidebar, model picker).
    @MainActor
    private static func bootstrapAndThemeOnce() {
        guard !didBootstrap else { return }
        didBootstrap = true
        ConfigurationDomainBootstrap.registerBuiltIns()
        DocumentAdaptersBootstrap.registerBuiltIns()
        ThemeManager.shared.applyCustomTheme(epistemosCreamTheme, persist: false, animated: false)
    }

    /// The Epistemos palette as an Osaurus `CustomTheme`. Mirrors the Epistemos
    /// `.systemLight` tokens (near-black text `#1C1C1E`, muted `#6E6E73`,
    /// monochrome ink accent, warm-cream surfaces, dark user bubbles) plus the
    /// monospace body font the owner's aesthetic uses. Colours are hex strings
    /// (Osaurus `ThemeColors`), so no SwiftUI `Color` crosses the boundary.
    static let epistemosCreamTheme: CustomTheme = CustomTheme(
        metadata: ThemeMetadata(
            id: UUID(uuidString: "E9150305-0000-0000-0000-000000000001")!,
            name: "Epistemos",
            version: "1.0",
            author: "Epistemos"
        ),
        colors: ThemeColors(
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
            successColor: "#34c759",
            warningColor: "#ff9f0a",
            errorColor: "#ff3b30",
            infoColor: "#1c1c1e",
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
            placeholderText: "#a8a8ad"
        ),
        background: .default,
        glass: ThemeGlass(enabled: false),
        typography: ThemeTypography(primaryFont: "SF Mono", monoFont: "SF Mono"),
        isBuiltIn: false,
        isDark: false
    )
}
