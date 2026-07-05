#if EPISTEMOS_EXPERIMENTAL
import AppKit
import SwiftUI

// Phase-2 Task 3 (DoD-3): native SwiftUI chrome over the web transcript.
// The §1.11 split, honored exactly:
//  · NATIVE-SAFE (pure tRPC/DB): the chat-list sidebar + New Chat + the
//    settings entry — driven by direct HTTP tRPC reads of the same backend.
//  · INTENT-BRIDGE: the model/provider picker + chat selection — every write
//    goes through ExperimentalStateBridge into the renderer's own Jotai atoms
//    (the send transport reads those atoms live at send time; native-only
//    state would silently desync the chat).
//  · The transcript/terminal/editor stay web; nothing here reloads the URL.

// MARK: - Minimal tRPC-over-HTTP client (superjson envelope)

enum ExperimentalTRPC {
    /// GET query: /trpc/<path>?input={"json":<input>} → decoded result.data.json
    static func query(baseURL: URL, path: String, input: Any) async -> Any? {
        guard let inputData = try? JSONSerialization.data(
            withJSONObject: ["json": input], options: [.fragmentsAllowed]
        ), let inputText = String(data: inputData, encoding: .utf8),
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("trpc/\(path)"),
            resolvingAgainstBaseURL: false
        ) else { return nil }
        comps.queryItems = [URLQueryItem(name: "input", value: inputText)]
        guard let url = comps.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = obj["result"] as? [String: Any],
              let dataObj = result["data"] as? [String: Any] else { return nil }
        return dataObj["json"]
    }
}

// MARK: - Chrome data model

@MainActor
@Observable
final class ExperimentalChromeModel {
    struct ChatRow: Identifiable {
        let id: String
        let name: String
    }

    struct CatalogModel: Identifiable {
        let id: String
        let name: String
        let free: Bool
    }

    struct ProviderGroup: Identifiable {
        let id: String       // backend provider key
        let title: String    // display name
        var models: [CatalogModel]
    }

    /// The six engines of §5/DoD-5, in display order.
    static let providers: [(key: String, title: String)] = [
        ("claude", "Claude Code"),
        ("codex", "Codex"),
        ("kimi", "Kimi"),
        ("glm", "GLM"),
        ("gemini", "Gemini"),
        ("opencode", "OpenCode (free Zen)"),
    ]

    var chats: [ChatRow] = []
    var catalog: [ProviderGroup] = []
    var selectedModelLabel: String = "Model"

    func refresh(baseURL: URL) async {
        // Chat list (NATIVE-SAFE: same DB the web sidebar reads).
        if let rows = await ExperimentalTRPC.query(
            baseURL: baseURL, path: "chats.list", input: [String: Any]()
        ) as? [[String: Any]] {
            chats = rows.compactMap { row in
                guard let id = row["id"] as? String else { return nil }
                return ChatRow(id: id, name: (row["name"] as? String) ?? "Untitled")
            }
        }
        // Live catalog, all six providers (§5) — sequential to keep it gentle.
        var groups: [ProviderGroup] = []
        for provider in Self.providers {
            var group = ProviderGroup(id: provider.key, title: provider.title, models: [])
            if let payload = await ExperimentalTRPC.query(
                baseURL: baseURL, path: "epistemosCatalog.list",
                input: ["provider": provider.key]
            ) as? [String: Any],
               let models = payload["models"] as? [[String: Any]] {
                group.models = models.prefix(12).compactMap { m in
                    guard let id = m["id"] as? String else { return nil }
                    return CatalogModel(
                        id: id,
                        name: (m["name"] as? String) ?? id,
                        free: (m["free"] as? Bool) ?? false
                    )
                }
            }
            groups.append(group)
        }
        catalog = groups
    }
}

// MARK: - Chrome bar (model picker + settings + sidebar toggle)

struct ExperimentalChromeBar: View {
    let baseURL: URL
    @State private var model = ExperimentalChromeModel()
    @Binding var sidebarShown: Bool

    var body: some View {
        HStack(spacing: 8) {
            ToolbarCapsuleButton(
                title: "Chats",
                systemImage: "sidebar.leading",
                role: .secondaryGhost,
                helpText: "Native chat list",
                accessibilityLabel: "Toggle native chat sidebar"
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    sidebarShown.toggle()
                }
            }

            // INTENT-BRIDGE model/provider picker: writes the per-subChat model
            // atom + lastSelected so the live transport sees the change.
            Menu {
                ForEach(model.catalog) { group in
                    Section(group.title) {
                        if group.models.isEmpty {
                            Text("No models (add a key in Settings)")
                        }
                        ForEach(group.models) { m in
                            if Self.pendingAdapterProviders.contains(group.id) {
                                // HONEST gating: these engines need their §5
                                // adapter (Gemini API-key / OpenCode Zen) before
                                // a selection would actually chat — list, don't lie.
                                Text("\(m.name) — engine adapter pending")
                            } else {
                                Button {
                                    selectModel(m, provider: group.id)
                                } label: {
                                    Text(m.free ? "\(m.name) · free" : m.name)
                                }
                            }
                        }
                    }
                }
            } label: {
                Label(model.selectedModelLabel, systemImage: "cpu")
                    .font(.system(size: 11, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.ultraThinMaterial))

            // Settings entry (NATIVE-SAFE: opens the SPA settings dialog and
            // deep-links tabs via the settings atoms).
            Menu {
                settingsLink("Preferences", tab: "preferences")
                settingsLink("Models & Providers", tab: "models")
                settingsLink("MCP Servers", tab: "mcp")
                settingsLink("Skills", tab: "skills")
                settingsLink("Projects", tab: "projects")
                settingsLink("Keyboard", tab: "keyboard")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(.ultraThinMaterial))
        }
        .task { await model.refresh(baseURL: baseURL) }
    }

    private func settingsLink(_ title: String, tab: String) -> some View {
        Button(title) {
            let bridge = ExperimentalStateBridge.shared
            bridge.setAtom("agentsSettingsDialogActiveTabAtom", value: tab)
            bridge.setAtom("agentsSettingsDialogOpenAtom", value: true)
        }
    }

    /// Engines whose §5 adapter hasn't landed yet — listed but not selectable.
    static let pendingAdapterProviders: Set<String> = ["gemini", "opencode"]

    /// §5 verified harness base URLs (Kimi/GLM ride the claude engine).
    private static let harnessBaseURL: [String: String] = [
        "kimi": "https://api.moonshot.ai/anthropic",
        "glm": "https://api.z.ai/api/anthropic",
    ]

    private func selectModel(_ m: ExperimentalChromeModel.CatalogModel, provider: String) {
        model.selectedModelLabel = m.name
        let bridge = ExperimentalStateBridge.shared
        guard let webView = bridge.webView else { return }
        // Key writes off the renderer's OWN active subChat (§1.11) — read it
        // live, then write the atoms the send transport actually reads.
        webView.evaluateJavaScript(
            "window.__epistemosState ? window.__epistemosState.getActiveSubChatId() : null"
        ) { result, _ in
            MainActor.assumeIsolated {
                let subChatId = (result as? String).flatMap { $0.isEmpty ? nil : $0 }
                switch provider {
                case "codex":
                    bridge.setAtom("lastSelectedAgentIdAtom", value: "codex")
                    bridge.setAtom("lastSelectedCodexModelIdAtom", value: m.id)
                    if let subChatId {
                        bridge.setAtom("subChatCodexModelIdAtomFamily", value: m.id, subChatId: subChatId)
                    }
                case "kimi", "glm":
                    // Claude engine + ANTHROPIC_BASE_URL harness. Token stays
                    // backend-side (Keychain→env→harnessTokenFromEnv); the
                    // renderer config carries ONLY baseUrl+model (§14).
                    bridge.setAtom("lastSelectedAgentIdAtom", value: "claude-code")
                    bridge.setAtom("customClaudeConfigAtom", value: [
                        "model": m.id,
                        "token": "",
                        "baseUrl": Self.harnessBaseURL[provider] ?? "",
                    ])
                    bridge.setAtom("lastSelectedModelIdAtom", value: m.id)
                default: // claude
                    bridge.setAtom("lastSelectedAgentIdAtom", value: "claude-code")
                    // Direct Anthropic: clear any lingering harness config so the
                    // transport doesn't route through a stale base URL.
                    bridge.setAtom("customClaudeConfigAtom", value: [
                        "model": "", "token": "", "baseUrl": "",
                    ])
                    if let subChatId {
                        bridge.setAtom("subChatModelIdAtomFamily", value: m.id, subChatId: subChatId)
                    }
                    bridge.setAtom("lastSelectedModelIdAtom", value: m.id)
                }
            }
        }
    }
}

// MARK: - Native sidebar (chat list + New Chat)

struct ExperimentalNativeSidebar: View {
    let baseURL: URL
    @State private var model = ExperimentalChromeModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Epistemos")
                .font(.custom("ChonkyPixels", size: 15))
                .padding(.top, 44)
                .padding(.horizontal, 14)

            Button {
                let bridge = ExperimentalStateBridge.shared
                bridge.setAtom("showNewChatFormAtom", value: true)
                bridge.setAtom("desktopViewAtom", value: NSNull())
            } label: {
                Label("New Chat", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 12)

            List(model.chats) { chat in
                Button {
                    select(chat)
                } label: {
                    Text(chat.name)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 220)
        .background(.thinMaterial)
        .task { await model.refresh(baseURL: baseURL) }
    }

    /// §1.11 sidebar-selection protocol — the full 5-atom tuple + claimChat.
    /// Omitting chatSourceModeAtom loads the transcript from the wrong backend.
    private func select(_ chat: ExperimentalChromeModel.ChatRow) {
        let bridge = ExperimentalStateBridge.shared
        bridge.action("claimChat", args: [chat.id])
        bridge.setAtom("selectedAgentChatIdAtom", value: chat.id)
        bridge.setAtom("selectedChatIsRemoteAtom", value: false)
        bridge.setAtom("chatSourceModeAtom", value: "local")
        bridge.setAtom("showNewChatFormAtom", value: false)
        bridge.setAtom("desktopViewAtom", value: NSNull())
        bridge.action("setChatId", args: [chat.id])
    }
}
#endif
