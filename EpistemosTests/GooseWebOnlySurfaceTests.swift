import Foundation
import Testing
@testable import Epistemos

// Goose web-only surface guards.
//
// Two layers:
//  1. Source invariants (pure, always run): prove the retired native-route router/toggles and
//     native route panels are gone after the owner cut the native rail and per-route panels.
//  2. Live parity (gated on a real Goose runtime): prove the Goose ACP provider/defaults data
//     source stays live-enumerated while the product path stays Goose WebView-only.

@Suite("Goose web-only surface source invariants")
@MainActor
struct GooseWebOnlySurfaceSourceTests {
    @Test("native Agent window keeps Goose primary and does not stack a second sidebar")
    func nativeAgentWindowKeepsGoosePrimary() throws {
        let sourceRoot = try sourceMirrorRootURL()
        #expect(!FileManager.default.fileExists(atPath: sourceRoot.appendingPathComponent(
            "Epistemos/Goose/GooseSurfaceRouter.swift",
            isDirectory: false
        ).path))
        #expect(!FileManager.default.fileExists(atPath: sourceRoot.appendingPathComponent(
            "Epistemos/Goose/GooseNativeModelsView.swift",
            isDirectory: false
        ).path))

        let root = try loadMirroredSourceTextFile("Epistemos/Agent/AgentSurfaceRootView.swift")
        #expect(root.contains("GooseWebSurfaceView(theme: theme)"))
        #expect(root.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        #expect(root.contains(".ignoresSafeArea()"))
        #expect(!root.contains("AgentRailDestination"))
        #expect(!root.contains("AgentNavigationRailView("))
        #expect(!root.contains("AgentLauncherPanelView("))
        #expect(!root.contains("routeShortcutButtons"))
        #expect(!root.contains(".keyboardShortcut(\"l\", modifiers: .command)"))
        #expect(!root.contains(".padding(.horizontal, 14)"))
        #expect(!root.contains(".clipShape(shape)"))
        #expect(!root.contains("shape.strokeBorder"))

        let window = try loadMirroredSourceTextFile("Epistemos/Agent/AgentSurfaceWindowController.swift")
        #expect(window.contains("window.titleVisibility = .hidden"))
        #expect(window.contains("window.backgroundColor = .clear"))
        #expect(window.contains("window.isOpaque = false"))
        #expect(window.contains("window.contentView = host"))
        #expect(window.contains("WindowThemeStyler.refreshChrome(of: window)"))
        #expect(!window.contains("WindowThemeStyler.themedContentView"))
        #expect(!window.contains("WindowThemeStyler.apply(to: window"))

        let fallbackWindow = try loadMirroredSourceTextFile("Epistemos/Goose/GooseSurfaceWindowController.swift")
        #expect(fallbackWindow.contains("window.titleVisibility = .hidden"))
        #expect(fallbackWindow.contains("window.backgroundColor = .clear"))
        #expect(fallbackWindow.contains("window.isOpaque = false"))
        #expect(fallbackWindow.contains("window.contentView = host"))
        #expect(fallbackWindow.contains("WindowThemeStyler.refreshChrome(of: window)"))
        #expect(!fallbackWindow.contains("WindowThemeStyler.themedContentView"))
        #expect(!fallbackWindow.contains("WindowThemeStyler.apply(to: window"))

        let webView = try loadMirroredSourceTextFile("Epistemos/Goose/GooseWebSurfaceView.swift")
        #expect(webView.contains("WebView(page)"))
        #expect(webView.contains("nativeACPOverlay"))
        #expect(webView.contains("private func setWebRoute"))
        #expect(webView.contains("route: activeWebRoute"))
        #expect(!webView.contains("GooseSurfaceRouter()"))
        #expect(!webView.contains("GooseNativeModelsView("))
        #expect(!webView.contains("nativeModelsRouteIsActive"))
        #expect(!webView.contains("router.isNative"))
        #expect(!webView.contains("detailsPanel"))
        #expect(!webView.contains("detailsButton"))
        #expect(!webView.contains("Label(\"Manage models\""))

        let reskin = try loadMirroredSourceTextFile("scripts/stage-goose-native-reskin.mjs")
        #expect(reskin.contains("epistemos-native-high-quality-flat-polish"))
        #expect(reskin.contains("epistemos-native-claude-pixel-polish"))
        #expect(reskin.contains("epistemos-native-claude-pixel-contract"))
        #expect(reskin.contains("Surfaces separate by spacing, tint, and state, not hard boxes."))
        #expect(reskin.contains("Visual target: Claude's calm single-sidebar app shell"))
        #expect(reskin.contains("Claude-like flat: single Goose sidebar, quiet canvas"))
        #expect(reskin.contains("--epistemos-claude-bg: var(--color-background-primary);"))
        #expect(reskin.contains("--epistemos-claude-sidebar: color-mix(in srgb, var(--color-background-secondary) 72%, var(--color-background-primary));"))
        #expect(reskin.contains("--epistemos-pixel-accent: var(--epistemos-accent);"))
        #expect(reskin.contains("--epistemos-pixel-font:"))
        #expect(reskin.contains(".ep-display"))
        #expect(reskin.contains(".ep-pixel"))
        #expect(reskin.contains(":is(h1, h2, h3, h4, h5, h6):not(.ep-display):not(.ep-pixel)"))
        #expect(reskin.contains("border-color: transparent !important;"))
        #expect(reskin.contains("border-width: 0 !important;"))
        #expect(reskin.contains("border-right-width: 0 !important;"))
        #expect(reskin.contains("box-shadow: none !important;"))
        #expect(reskin.contains("--tw-ring-shadow: 0 0 #0000 !important;"))
        #expect(reskin.contains("backdrop-filter: none !important;"))
        #expect(reskin.contains("background: var(--epistemos-claude-surface) !important;"))
        #expect(reskin.contains("box-shadow:"))
        #expect(reskin.contains("image-rendering: pixelated;"))
        #expect(reskin.contains("outline: none !important;"))
        #expect(reskin.contains("background: color-mix(in srgb, var(--epistemos-pixel-accent) 7%, var(--epistemos-claude-surface)) !important;"))
        #expect(reskin.contains("background: color-mix(in srgb, var(--epistemos-pixel-accent) 5%, var(--epistemos-claude-surface)) !important;"))
        #expect(reskin.contains(".goose-epistemos .goose-chat-input-card:focus-within"))
        #expect(reskin.contains("epistemos-native-final-flat-pixel-audit"))
        #expect(reskin.contains(".replaceAll('#0066cc', '#1d1d1f')"))
        #expect(reskin.contains(".replaceAll('#2997ff', '#ffffff')"))
        #expect(!reskin.contains("outline: 2px solid color-mix"))
        #expect(!reskin.contains("box-shadow: inset 0 0 0 1px var(--epistemos-claude-hairline)"))
        #expect(!reskin.contains("box-shadow: inset 0 0 0 1px var(--epistemos-flat-focus)"))

        let stageScript = try loadMirroredSourceTextFile("stage-goose-web-ui.sh")
        #expect(stageScript.contains("Goose Web UI staging still contains blue/ring/outline visual leftovers."))
        #expect(stageScript.contains("epistemos-native-claude-pixel-contract"))
        #expect(stageScript.contains("--tw-ring-shadow: 0 0 #0000 !important"))
        #expect(stageScript.contains("backdrop-filter: none !important"))
        #expect(stageScript.contains("epistemos-acp-session-mode-setting"))
        #expect(stageScript.contains("saveAcpSessionMode(sessionId, newMode)"))
        #expect(stageScript.contains("epistemos-acp-next-session-mode-default"))
        #expect(stageScript.contains("epistemos-acp-new-session-mode-default"))
        #expect(stageScript.contains("gooseMode: configuredGooseMode"))
        #expect(stageScript.contains("useChatContext()"))
        #expect(stageScript.contains("epistemos-acp-permission-tools-list"))
        #expect(stageScript.contains("listAcpSessionTools(sessionId, extensionName)"))
        #expect(stageScript.contains("epistemos-acp-permission-save-unavailable"))
        #expect(stageScript.contains("permissionEditingUnavailable"))
        #expect(stageScript.contains("epistemos-acp-mcp-resource-read"))
        #expect(stageScript.contains("epistemos-acp-mcp-tool-call"))
        #expect(stageScript.contains("readAcpSessionResource(sessionId, resourceUri, extensionName)"))
        #expect(stageScript.contains("callAcpSessionTool(sessionId, fullToolName, args || {})"))
        #expect(stageScript.contains("epistemos-acp-hide-rest-free-onboarding"))
        #expect(stageScript.contains("USE_ACP_CHAT ? OWN_PROVIDER : null"))
        #expect(stageScript.contains("!USE_ACP_CHAT && selectedPath === FREE_OPTIONS"))
        #expect(stageScript.contains("epistemos-acp-provider-modal-custom-delete"))
        #expect(stageScript.contains("epistemos-acp-dictation-config-ui"))
        #expect(stageScript.contains("epistemos-acp-dictation-secret-save-ui"))
        #expect(stageScript.contains("epistemos-acp-dictation-secret-delete-ui"))
        #expect(stageScript.contains("voice_dictation_provider: 'voiceDictationProvider'"))
        #expect(stageScript.contains("voice_dictation_preferred_mic: 'voiceDictationPreferredMic'"))
        #expect(stageScript.contains("epistemos-acp-dictation-models-list"))
        #expect(stageScript.contains("epistemos-acp-dictation-models-list-ui"))
        #expect(stageScript.contains("epistemos-acp-dictation-model-download-ui"))
        #expect(stageScript.contains("readAcpDictationModelDownloadProgress(modelId)"))
        #expect(stageScript.contains("epistemos-acp-dictation-model-delete-ui"))
        #expect(stageScript.contains("epistemos-acp-dictation-transcribe"))
        #expect(stageScript.contains("epistemos-acp-dictation-config-hook"))
        #expect(stageScript.contains("transcribeAcpDictation(base64, 'audio/wav', prov)"))
        #expect(stageScript.contains("epistemos-acp-huggingface-sign-in-prompt"))
        #expect(stageScript.contains("readAcpProviderConfigStatuses([HUGGINGFACE_PROVIDER])"))
        #expect(stageScript.contains("authenticateAcpProviderConfig(HUGGINGFACE_PROVIDER)"))
        #expect(stageScript.contains("epistemos-acp-disable-nostr-session-links"))
        #expect(stageScript.contains("const [nostrEnabled, setNostrEnabled] = useState(!USE_ACP_CHAT);"))
        #expect(stageScript.contains("setNostrEnabled(false); // epistemos-acp-disable-nostr-session-links"))
        #expect(stageScript.contains("epistemos-acp-hide-session-sharing"))
        #expect(stageScript.contains("const [tunnelDisabled, setTunnelDisabled] = useState(USE_ACP_CHAT);"))
        #expect(stageScript.contains("sharing: USE_ACP_CHAT ? 'models' : 'sharing'"))
        #expect(stageScript.contains("epistemos-acp-navigation-active-session"))
        #expect(stageScript.contains("export async function acpGetSessionListItem"))
        #expect(stageScript.contains("client.goose.sessionInfo_unstable({ sessionId })"))
        #expect(stageScript.contains("acpGetSessionListItem(activeSessionId)"))
        #expect(stageScript.contains("Goose Web UI navigation hook still calls REST getSession for active sessions."))
        #expect(stageScript.contains("epistemos-acp-session-details-route-to-chat"))
        #expect(stageScript.contains("epistemos-acp-hide-prompts-settings"))
        #expect(stageScript.contains("prompts: USE_ACP_CHAT ? 'models' : 'prompts'"))
        #expect(stageScript.contains("epistemos-acp-hide-session-history-sharing"))
        #expect(stageScript.contains("setCanShare(false); // epistemos-acp-hide-session-history-sharing"))
        #expect(stageScript.contains("epistemos-acp-stdio-extension-secret-env-values"))
        #expect(stageScript.contains("epistemos-acp-stdio-extension-server-env"))
        #expect(stageScript.contains("epistemos-acp-stdio-extension-secret-store-via-config"))
        #expect(stageScript.contains("epistemos-acp-block-http-extension-secret-env"))
        #expect(stageScript.contains("epistemos-acp-block-http-extension-secret-submit"))
        #expect(stageScript.contains("epistemos-acp-hide-security-settings"))
        #expect(stageScript.contains("epistemos-acp-hide-telemetry-settings"))
        #expect(stageScript.contains("epistemos-acp-hide-local-inference-settings"))
        #expect(stageScript.contains("epistemos-acp-hide-local-model-settings"))
        #expect(stageScript.contains("!USE_ACP_CHAT && currentProvider === 'local' && currentModel"))
        #expect(stageScript.contains("!USE_ACP_CHAT && isLocalModelSettingsOpen && currentModel"))
        #expect(stageScript.contains("epistemos-acp-hide-generic-config-settings"))
        #expect(stageScript.contains("epistemos-acp-defaults-reset-unavailable"))
        #expect(stageScript.contains("epistemos-acp-hide-reset-provider-settings"))

        let support = try loadMirroredSourceTextFile("Epistemos/Goose/GooseWebSurfaceSupport.swift")
        #expect(support.contains("nativeFeelScript(theme: theme)"))
        #expect(support.contains("--color-ring-primary: \\(accent) !important;"))
        #expect(support.contains("--epistemos-accent: \\(accent) !important;"))
        #expect(support.contains("document.documentElement.dataset.epistemosTheme"))
        #expect(!support.contains("EPISTEMOS_GOOSE_NATIVE_ROUTES"))
        #expect(!support.contains("epistemos.goose.nativeRoutes"))

    }
}

@Suite("Goose provider/defaults ACP data-source parity", .serialized)
@MainActor
struct GooseProviderDefaultsLiveParityTests {
    /// Goose's product path is WebView-only, but provider/model/default data must still come from
    /// live ACP methods rather than a Swift-maintained roster.
    @Test("live ACP providers/list + defaults/read remain resolvable (no hardcoded roster)")
    func gooseProviderDefaultsReachLiveParity() async throws {
        try await withLiveGooseACPClient(proofName: "goose-provider-defaults-parity") { _, _, client, _ in
            _ = try await withLiveTimeout(
                seconds: 12,
                description: "ACP initialize for Goose provider/defaults parity",
                onTimeout: { await client.close() },
                operation: { try await client.initialize() }
            )

            let inventory = try await withLiveTimeout(
                seconds: 20,
                description: "providers/list inventory (Goose web Models source)",
                onTimeout: { await client.close() },
                operation: { try await client.listGooseProviderInventory() }
            )
            #expect(!inventory.isEmpty, "Goose provider inventory must not be empty.")
            #expect(inventory.contains { !$0.models.isEmpty },
                    "No provider exposes inline models through providers/list.")

            let defaults = try await withLiveTimeout(
                seconds: 20,
                description: "defaults/read (Goose current model selection)",
                onTimeout: { await client.close() },
                operation: { try await client.readGooseDefaults() }
            )
            if let defaultProviderId = defaults.providerId {
                #expect(inventory.contains { $0.providerId == defaultProviderId },
                        "Default provider \(defaultProviderId) is not present in providers/list inventory.")
            }
        }
    }
}
