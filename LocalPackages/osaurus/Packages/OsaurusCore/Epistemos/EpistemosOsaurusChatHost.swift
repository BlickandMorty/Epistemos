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
        // RESKIN (owner 2026-06-22, "the reskin isn't working — I see raw Osaurus"): apply the
        // Epistemos cream theme HERE, BEFORE the window resolves its theme. The bug was that the
        // reskin ran in `.task` (AFTER ChatWindowState init already resolved to Osaurus's DEFAULT
        // theme from `currentTheme`), and `persist:false` didn't install it, so any re-resolution
        // fell back to default. ChatWindowState.loadTheme reads `ThemeManager.shared.currentTheme`,
        // so applying cream first makes the window — and every `@Environment(\.theme)` Osaurus view
        // (thread/composer/sidebar/picker) — read cream from the FIRST render.
        Self.installAndApplyEpistemosThemeOnce()
        let state = ChatWindowState(windowId: windowId, agentId: agentId ?? Agent.defaultId)
        // GRAFT — SIDE PANEL (owner must-keep 2026-06-22): Osaurus's ChatSessionSidebar defaults
        // to HIDDEN (showSidebar = false), so the act surface would open with no side panel. Show
        // it by default — the owner gets the loved Epistemos-style side panel (Osaurus's session
        // sidebar, reskinned to the cream/monospace look). Additive; the owner can still collapse it.
        state.showSidebar = true
        _windowState = StateObject(wrappedValue: state)
    }

    public var body: some View {
        ChatView(windowState: windowState)
            // GRAFT 3 — SCROLL-BLUR (owner must-keep 2026-06-22): a soft top-edge progressive
            // blur so content dissolves as it scrolls up — the loved Epistemos scroll interaction
            // brought onto the Osaurus surface. Purely additive overlay (no change to Osaurus's
            // ChatView): a thin material band, strongest at the very top and fading to clear, that
            // blurs whatever scrolls under it. Never intercepts input. (Owner refines depth on the
            // running app; the other 2 grafts — message bar, side panel — follow.)
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
        // (Theme is applied earlier — in init(), before the window resolves — not here.)
        seedOwnerDefaultModelOnce()
    }

    @MainActor private static var didApplyTheme = false

    /// Install + persist + apply the Epistemos cream/monospace reskin so it actually takes effect on
    /// the live Osaurus surface (owner 2026-06-22 — the prior `.task` + `persist:false` was a no-op
    /// the window never picked up). INSTALL it into `installedThemes` (so it's a real, resolvable
    /// theme), then `applyCustomTheme(persist: true)` so `ThemeManager.currentTheme` becomes cream AND
    /// it's saved as the active theme — surviving any re-resolution / relaunch. Runs once ever (latch).
    /// `ChatWindowState.theme` resolves from `currentTheme`, so this is the theme SOURCE the chat reads.
    @MainActor
    private static func installAndApplyEpistemosThemeOnce() {
        guard !didApplyTheme else { return }
        didApplyTheme = true
        ThemeManager.shared.saveTheme(epistemosCreamTheme)
        ThemeManager.shared.refreshInstalledThemes()
        ThemeManager.shared.applyCustomTheme(epistemosCreamTheme, persist: true, animated: false)
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
