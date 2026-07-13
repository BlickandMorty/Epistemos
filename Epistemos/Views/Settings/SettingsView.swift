import AppKit
import AVFoundation
import os
import SwiftUI
import UniformTypeIdentifiers
#if canImport(agent_coreFFI)
import agent_coreFFI
#endif

private let settingsViewLogger = Logger(subsystem: "Epistemos", category: "SettingsView")

enum SettingsDetailNavigationPolicy {
    static let debounceMilliseconds = 120
}

enum SettingsViewDestructiveActionSovereignGate {
    enum Target: Equatable {
        case savedWorkspace(name: String)
        case vaultDisconnect(name: String)
        case resetEverything
    }

    static func requirement(for target: Target) -> SovereignGateRequirement {
        switch target {
        case .savedWorkspace:
            return .deviceOwnerAuthentication
        case .vaultDisconnect:
            return .deviceOwnerAuthentication
        case .resetEverything:
            return .deviceOwnerAuthentication
        }
    }

    static func reason(for target: Target) -> String {
        switch target {
        case .savedWorkspace(let name):
            return "Delete saved workspace \"\(safeName(name))\"."
        case .vaultDisconnect(let name):
            return "Disconnect vault \"\(safeName(name))\"."
        case .resetEverything:
            return "Reset Everything and delete saved data."
        }
    }

    private static func safeName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Workspace" : trimmed
    }
}

// MARK: - Settings View
// Mirrors macOS System Settings: NavigationSplitView sidebar → detail pane.
// The window itself handles sizing; this view provides the split layout + chrome.

struct SettingsView: View {
    @Environment(UIState.self) private var ui
    @State private var selection: SettingsSection?
    @State private var detailSelection: SettingsSection?
    @State private var settingsSearchQuery = ""

    init(initialSelection: SettingsSection? = .general) {
        let safeSelection = SettingsSection.safeDetailSelection(for: initialSelection)
        _selection = State(initialValue: safeSelection)
        _detailSelection = State(initialValue: safeSelection)
    }

    // MARK: - Settings Categories (Phase 7 Step 7)
    //
    // Phase 7 simplifies the sidebar into calm categories. Retired
    // agent/model/research-only settings stay out of `visibleSections`
    // instead of remaining as hidden UI debt.

    enum SettingsCategory: String, CaseIterable, Identifiable {
        case capture      = "Capture"
        case graph        = "Graph"
        case automation   = "Automation"
        case privacyStore = "Privacy & Storage"
        case advanced     = "Advanced"

        var id: String { rawValue }

        /// Display order in the sidebar, top to bottom.
        static var orderedCases: [SettingsCategory] {
            let categories: [SettingsCategory] = [
                .capture,
                .graph,
                .automation,
                .privacyStore,
                .advanced,
            ]
            return categories
        }
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case ambientFrequencies = "Ambient Frequencies"
        case voice = "Voice"
        case skills = "Extensions"
        case cloudModels = "Cloud Models"
        case landing = "Landing"
        case appearance = "Appearance"
        case vault = "Vault"
        /// Phase S.6 transparency pane. Reads from PrivacyInfo.xcprivacy
        /// and surfaces what stays on the Mac, what leaves it, and the
        /// fields the App Store App Privacy questionnaire mirrors. Visible
        /// in both MAS and Pro because the privacy posture is the same in
        /// both deployment profiles.
        case privacy = "Privacy"
        case provenance = "Provenance Console"
        case substrateHealth = "Epistemos Foundation"

        var id: String { rawValue }

        var displayTitle: String {
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            switch self {
            case .cloudModels: "June Models"
            default: rawValue
            }
            #else
            rawValue
            #endif
        }

        /// Sidebar-visible sections. Deleted agent/model-stack entries are
        /// intentionally absent rather than hidden behind deep links.
        static var visibleSections: [SettingsSection] {
            var sections: [SettingsSection] = [
                .general,
                .ambientFrequencies,
                .voice,
            ]
            if ProductCapabilityPolicy.isAvailable(.models) {
                sections.append(.cloudModels)
            }
            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            sections.insert(.skills, at: 3)
            #endif
            sections += [
                .landing,
                .appearance,
                .vault,
                .privacy,
                .provenance,
                .substrateHealth,
            ]
            return sections
        }

        static func safeDetailSelection(for section: SettingsSection?) -> SettingsSection? {
            if section == .cloudModels, !ProductCapabilityPolicy.isAvailable(.models) {
                return .general
            }
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            if section == .skills {
                return .general
            }
            #endif
            return section
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .ambientFrequencies: "waveform.path"
            case .voice: "waveform.and.mic"
            case .skills: "puzzlepiece.extension"
            case .cloudModels: "cloud"
            case .landing: "sparkles.rectangle.stack"
            case .appearance: "paintpalette"
            case .vault: "folder"
            case .privacy: "hand.raised.fill"
            case .provenance: "list.bullet.rectangle.portrait"
            case .substrateHealth: "waveform.path.ecg.rectangle"
            }
        }

        var sidebarBrand: IntegrationBrand? {
            switch self {
            case .voice:
                .voice
            case .skills:
                .extensions
            case .vault:
                .vault
            case .provenance:
                .provenance
            default:
                nil
            }
        }

        /// Which simplified Phase 7 category this section belongs under.
        var category: SettingsCategory {
            switch self {
            case .landing,
                 .ambientFrequencies,
                 .voice: .capture
            case .appearance:     .graph
            case .skills,
                 .cloudModels:    .automation
            case .vault:          .privacyStore
            case .privacy:        .privacyStore
            case .provenance:     .privacyStore
            case .substrateHealth: .advanced
            case .general:        .advanced
            }
        }

        /// One-line explanation shown as a caption under the sidebar label.
        /// Describes what the row changes and why it matters — deliberately
        /// short so the sidebar stays scannable.
        var rowDescription: String {
            switch self {
            case .general:
                "Power, session, workspace summaries, data protection, reset."
            case .ambientFrequencies:
                "Generate precise local WAV frequency presets for ambient sessions."
            case .voice:
                "Speech, dictation, read-aloud, and premium voice defaults."
            case .skills:
                #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                "App Store builds manage agent capabilities through MAS June."
                #else
                "Skills, MCP servers, connectors, and presets."
                #endif
            case .cloudModels:
                #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                "OpenAI and Anthropic models connected to MAS June."
                #else
                "Provider accounts, API keys, and GPT, Claude, Gemini, GLM, Kimi models."
                #endif
            case .landing:
                "Greeting, quick capture, and landing canvas behavior."
            case .appearance:
                "Theme, graph visuals, physics presets, display mode."
            case .vault:
                "Vault path, sync service, and retrieval indexes."
            case .privacy:
                "What stays on this Mac, what leaves it, and the App Privacy fields."
            case .provenance:
                "Read-only audit trail for graph, tool, and mutation projections."
            case .substrateHealth:
                #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                "Native foundation: search, import tools, provenance, and safety."
                #else
                "Native foundation IP: search, tools, MCP, provenance, and safety."
                #endif
            }
        }

        var searchKeywords: [String] {
            switch self {
            case .general:
                ["session", "workspace", "restore", "reset", "retention", "privacy", "data"]
            case .ambientFrequencies:
                ["audio", "sound", "frequency", "frequencies", "wav", "ambient", "binaural", "music"]
            case .voice:
                ["voice", "speech", "dictation", "read aloud", "tts", "stt", "microphone", "premium"]
            case .skills:
                ["skills", "manifest", "activation", "plugin", "tools"]
            case .cloudModels:
                #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                ["june", "cloud", "models", "provider", "openai", "gpt", "anthropic", "claude", "api key"]
                #else
                ["cloud", "models", "provider", "openai", "gpt", "anthropic", "claude", "google", "gemini", "glm", "zai", "kimi", "moonshot", "oauth", "api key"]
                #endif
            case .landing:
                ["landing", "greeting", "quick capture", "home", "welcome"]
            case .appearance:
                ["theme", "custom", "font", "graph", "platinum", "classic", "dark", "color"]
            case .vault:
                ["vault", "folder", "sync", "path", "index", "retrieval", "notes"]
            case .privacy:
                ["privacy", "local", "cloud", "app privacy", "permissions", "security"]
            case .provenance:
                ["provenance", "event", "run", "mutation", "audit", "console"]
            case .substrateHealth:
                #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                ["foundation", "june", "tools", "eidos", "halo", "search", "provenance", "answerpacket", "safety"]
                #else
                ["foundation", "ip", "tools", "mcp", "eidos", "halo", "search", "provenance", "answerpacket", "safety"]
                #endif
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SettingsSearchField(text: $settingsSearchQuery)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                List(selection: $selection) {
                    ForEach(SettingsCategory.orderedCases) { category in
                        let sections = sidebarSections(in: category)
                        if !sections.isEmpty {
                            Section(category.rawValue) {
                                ForEach(sections) { section in
                                    SettingsSidebarRow(
                                        section: section,
                                        searchQuery: normalizedSettingsSearchQuery
                                    )
                                    .tag(section)
                                }
                            }
                        }
                    }

                    if !normalizedSettingsSearchQuery.isEmpty && filteredVisibleSections.isEmpty {
                        SettingsSearchEmptyRow(query: settingsSearchQuery)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .background {
                SettingsSidebarBackdrop(theme: ui.theme)
                    .ignoresSafeArea()
            }
            .navigationSplitViewColumnWidth(min: 196, ideal: 212, max: 260)
        } detail: {
            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background {
                    SettingsDetailBackdrop(theme: ui.theme)
                }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onAppear {
            Task { @MainActor in
                selection = SettingsSection.safeDetailSelection(for: selection)
            }
        }
        .onChange(of: selection) { _, newSelection in
            let safeSelection = SettingsSection.safeDetailSelection(for: newSelection)
            if safeSelection != newSelection {
                selection = safeSelection
            }
        }
        .task(id: selection) {
            let nextSelection = SettingsSection.safeDetailSelection(for: selection)
            guard nextSelection != detailSelection else { return }
            do {
                try await Task.sleep(
                    for: .milliseconds(SettingsDetailNavigationPolicy.debounceMilliseconds)
                )
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                detailSelection = nextSelection
            }
        }
        .onChange(of: settingsSearchQuery) { _, _ in
            normalizeSelectionForVisibleSearchResults()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectSettingsSection)) { notification in
            guard
                let rawSection = notification.userInfo?[SettingsView.sectionUserInfoKey] as? String,
                let section = SettingsSection(rawValue: rawSection)
            else {
                return
            }
            selection = SettingsSection.safeDetailSelection(for: section)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
                // `.help` is hover-only on macOS; VoiceOver needs an
                // explicit label since this is icon-only.
                .accessibilityLabel("Toggle sidebar")
            }
        }
    }

    private var normalizedSettingsSearchQuery: String {
        settingsSearchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var filteredVisibleSections: [SettingsSection] {
        let query = normalizedSettingsSearchQuery
        guard !query.isEmpty else {
            return SettingsSection.visibleSections
        }
        return SettingsSection.visibleSections.filter { section in
            section.matchesSettingsSearch(query)
        }
    }

    private func sidebarSections(in category: SettingsCategory) -> [SettingsSection] {
        filteredVisibleSections.filter { $0.category == category }
    }

    private func normalizeSelectionForVisibleSearchResults() {
        guard !normalizedSettingsSearchQuery.isEmpty else { return }
        let safeSelection = SettingsSection.safeDetailSelection(for: selection)
        if let safeSelection, filteredVisibleSections.contains(safeSelection) {
            return
        }
        selection = filteredVisibleSections.first ?? safeSelection ?? .general
    }

    private var settingsDetail: some View {
        Group {
            switch SettingsSection.safeDetailSelection(for: detailSelection) {
            case .general: GeneralDetailView()
            case .ambientFrequencies: AmbientFrequencySettingsView()
            case .voice: VoiceSettingsDetailView()
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            case .skills: GeneralDetailView()
            #else
            case .skills: ExtensionsDetailView()
            #endif
            case .cloudModels: CloudModelsSettingsView()
            case .landing: LandingDetailView()
            case .appearance: AppearanceDetailView()
            case .vault: VaultDetailView()
            case .privacy: PrivacyDetailView()
            case .provenance: ProvenanceConsoleView()
            case .substrateHealth: SubstrateHealthPanel()
            case nil: GeneralDetailView()
            }
        }
        .settingsThemedBlurPage(theme: ui.theme.surfaceVariant(.other))
    }

    private func toggleSidebar() {
        NSApp.sendAction(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            to: nil,
            from: nil
        )
    }
}

extension SettingsView {
    nonisolated static let sectionUserInfoKey = "section"
}

extension Notification.Name {
    static let selectSettingsSection = Notification.Name("epistemos.selectSettingsSection")
}

private extension SettingsView.SettingsSection {
    func matchesSettingsSearch(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let haystack = ([displayTitle, rowDescription, category.rawValue] + searchKeywords)
            .joined(separator: " ")
            .lowercased()
        let tokens = query
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "/" })
            .map(String.init)
        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy { haystack.localizedStandardContains($0) }
    }
}

private struct SettingsSearchField: View {
    @Environment(UIState.self) private var ui
    @Binding var text: String
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search Settings", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear settings search")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(theme.resolved.card.color.opacity(theme.isDark ? 0.72 : 0.84))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(theme.border.opacity(theme.isDark ? 0.34 : 0.28), lineWidth: 0.75)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SettingsSearchEmptyRow: View {
    let query: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("No Settings Found")
                    .font(.footnote.weight(.medium))
                Text(query.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsSidebarRow: View {
    @Environment(UIState.self) private var ui
    let section: SettingsView.SettingsSection
    let searchQuery: String
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            sidebarBadge
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.displayTitle)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Text(section.rowDescription)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.resolved.mutedForeground.color)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var sidebarBadge: some View {
        if let brand = section.sidebarBrand {
            SettingsIntegrationBrandBadge(
                brand: brand,
                theme: theme,
                tint: iconTint,
                size: 24
            )
        } else {
            SettingsPixelGlyphBadge(
                systemImage: section.icon,
                theme: theme,
                tint: iconTint,
                size: 24
            )
        }
    }

    private var iconTint: Color {
        if searchQuery.isEmpty {
            return theme.resolved.accent.color
        }
        return section.matchesSettingsSearch(searchQuery)
            ? theme.resolved.accent.color
            : theme.textSecondary
    }
}

private struct SettingsSidebarBackdrop: View {
    let theme: EpistemosTheme

    var body: some View {
        SettingsThemedBlurBackdrop(theme: theme.surfaceVariant(.other), role: .sidebar)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(theme.border.opacity(theme.isDark ? 0.6 : 0.42))
                    .frame(width: 0.6)
            }
    }
}

private struct SettingsDetailBackdrop: View {
    let theme: EpistemosTheme

    var body: some View {
        SettingsThemedBlurBackdrop(theme: theme.surfaceVariant(.other), role: .page)
            .ignoresSafeArea()
    }
}

struct SettingsDescriptionText: View {
    let text: String
    var tertiary = false

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(tertiary ? .tertiary : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsDescriptionCard: View {
    @Environment(UIState.self) private var ui
    let title: String
    let systemImage: String
    let text: String
    private var settingsTheme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SettingsPixelGlyphBadge(
                systemImage: systemImage,
                theme: settingsTheme,
                tint: settingsTheme.resolved.accent.color,
                size: 18
            )
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                SettingsDescriptionText(text: text)
            }
        }
        .padding(9)
        .settingsAppleCardChrome(theme: settingsTheme, accent: settingsTheme.resolved.accent.color)
    }
}

private struct SettingsHelpHeader<PopoverContent: View>: View {
    let title: String
    @Binding var isPresented: Bool
    @ViewBuilder let popoverContent: () -> PopoverContent

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Button {
                isPresented = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                popoverContent()
            }
            .accessibilityLabel("Show help for \(title)")
            .accessibilityHint("Opens an explanation of this section.")
            Spacer(minLength: 0)
        }
    }
}

private struct CloudHintPopover: View {
    let title: String
    let bulletPoints: [String]
    let footnote: String?
    let onRemindLater: () -> Void
    let onGotIt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(Array(bulletPoints.enumerated()), id: \.offset) { index, point in
                Text("\(index + 1). \(point)")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button("Remind Me Later") {
                    onRemindLater()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Got It") {
                    onGotIt()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
    }
}

// MARK: - General Detail
// Consolidated: Session + Workspace Summaries + Security info + Reset

private struct CloudModelsSettingsView: View {
    @Environment(UIState.self) private var ui
    @State private var apiKeyDrafts: [CloudModelProvider: String] = [:]
    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    @State private var openAIDeviceAuthorization: OpenAIDeviceAuthorization?
    @State private var googleOAuthProjectID = CloudProviderSetupAutomation.loadGoogleOAuthProjectIDDraft()
    @State private var googleOAuthClientFilename = CloudProviderSetupAutomation.loadGoogleOAuthClientFilename()
    @State private var googleOAuthStatusMessage: String?
    #endif

    private var theme: EpistemosTheme {
        ui.theme.surfaceVariant(.other)
    }

    var body: some View {
        Form {
            Section(providerSetupTitle) {
                SettingsDescriptionText(text: providerSetupDescription)

                ForEach(settingsProviders, id: \.self) { provider in
                    Group {
                        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                        CloudProviderSettingsRow(
                            provider: provider,
                            apiKeyDraft: apiKeyBinding(for: provider)
                        )
                        #else
                        CloudProviderSettingsRow(
                            provider: provider,
                            apiKeyDraft: apiKeyBinding(for: provider),
                            openAIDeviceAuthorization: $openAIDeviceAuthorization,
                            googleOAuthProjectID: $googleOAuthProjectID,
                            googleOAuthClientFilename: $googleOAuthClientFilename,
                            googleOAuthStatusMessage: $googleOAuthStatusMessage
                        )
                        #endif
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        .sheet(item: $openAIDeviceAuthorization) { authorization in
            OpenAIDeviceAuthorizationSheet(authorization: authorization) {
                openAIDeviceAuthorization = nil
            }
        }
        .onAppear {
            googleOAuthProjectID = CloudProviderSetupAutomation.loadGoogleOAuthProjectIDDraft()
            googleOAuthClientFilename = CloudProviderSetupAutomation.loadGoogleOAuthClientFilename()
        }
        #endif
    }

    private func apiKeyBinding(for provider: CloudModelProvider) -> Binding<String> {
        Binding(
            get: { apiKeyDrafts[provider] ?? "" },
            set: { apiKeyDrafts[provider] = $0 }
        )
    }

    private var settingsProviders: [CloudModelProvider] {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        CloudModelProvider.juneAgentProviders
        #else
        CloudModelProvider.preferredOrder
        #endif
    }

    private var providerSetupDescription: String {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        "Save an OpenAI or Anthropic API key in Apple Keychain for MAS June. Only providers connected to June appear here."
        #else
        "Connect account access where the provider supports it, or save an API key fallback for GPT/Codex, Claude, Gemini, GLM, and Kimi."
        #endif
    }

    private var providerSetupTitle: String {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        "June Provider Setup"
        #else
        "Cloud Provider Setup"
        #endif
    }
}

private struct CloudProviderSettingsRow: View {
    let provider: CloudModelProvider
    @Binding var apiKeyDraft: String
    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    @Binding var openAIDeviceAuthorization: OpenAIDeviceAuthorization?
    @Binding var googleOAuthProjectID: String
    @Binding var googleOAuthClientFilename: String
    @Binding var googleOAuthStatusMessage: String?
    #endif

    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    #if EPISTEMOS_APP_STORE || MAS_SANDBOX
    @State private var consentStore = AgentCloudConsentStore.shared
    #endif
    @State private var showAPIKeyTools: Bool
    @State private var isWorking = false
    @State private var actionResult: String?

    #if EPISTEMOS_APP_STORE || MAS_SANDBOX
    init(provider: CloudModelProvider, apiKeyDraft: Binding<String>) {
        self.provider = provider
        _apiKeyDraft = apiKeyDraft
        _showAPIKeyTools = State(initialValue: true)
    }
    #else
    init(
        provider: CloudModelProvider,
        apiKeyDraft: Binding<String>,
        openAIDeviceAuthorization: Binding<OpenAIDeviceAuthorization?>,
        googleOAuthProjectID: Binding<String>,
        googleOAuthClientFilename: Binding<String>,
        googleOAuthStatusMessage: Binding<String?>
    ) {
        self.provider = provider
        _apiKeyDraft = apiKeyDraft
        _openAIDeviceAuthorization = openAIDeviceAuthorization
        _googleOAuthProjectID = googleOAuthProjectID
        _googleOAuthClientFilename = googleOAuthClientFilename
        _googleOAuthStatusMessage = googleOAuthStatusMessage
        _showAPIKeyTools = State(initialValue: !provider.supportsAccountConnection)
    }
    #endif

    private var theme: EpistemosTheme {
        ui.theme.surfaceVariant(.other)
    }

    private var validationState: CloudProviderValidationState {
        inference.cloudValidationState(for: provider)
    }

    private var hasSavedAPIKey: Bool {
        inference.apiKey(for: provider) != nil
    }

    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    private var oauthCredential: CloudProviderOAuthCredential? {
        inference.oauthCredential(for: provider)
    }
    #endif

    private var accountActionTitle: String {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        provider.accountActionTitle
        #else
        switch provider {
        case .openAI:
            if case .invalid = validationState { return "Retry OpenAI Sign In" }
            return provider.accountActionTitle
        case .anthropic:
            if case .invalid = validationState { return "Retry Claude Code Import" }
            return provider.accountActionTitle
        case .google:
            if case .invalid = validationState { return "Retry Google OAuth" }
            return provider.accountActionTitle
        case .zai, .kimi, .minimax, .deepseek:
            return provider.accountActionTitle
        }
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            SettingsDescriptionText(text: provider.setupHelpText)

            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            cloudDataConsentControl
            #endif

            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            if let summary = provider.accountConnectionSummary(
                oauthCredential: oauthCredential,
                hasSavedAPIKey: hasSavedAPIKey,
                validationState: validationState
            ) {
                CloudProviderAccountConnectionRow(
                    summary: summary,
                    theme: theme,
                    actionTitle: accountActionTitle
                ) {
                    runAccountAction()
                }
            }

            if let guidance = provider.accountGuidanceText(validationState: validationState) {
                CloudProviderGuidanceRow(text: guidance, theme: theme)
            }
            #endif

            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            if provider == .kimi {
                CloudProviderGuidanceRow(
                    text: "Kimi Code OAuth is available in Kimi CLI, but the documented direct Kimi API route for Epistemos is still the Moonshot/Kimi API key path.",
                    theme: theme,
                    systemImage: "key.fill",
                    tint: theme.resolved.accent.color
                )
            }
            #endif

            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            if provider == .google {
                googleOAuthControls
            }
            #endif

            modelPicker

            actionButtons

            DisclosureGroup(isExpanded: $showAPIKeyTools) {
                apiKeyControls
            } label: {
                Label(provider.manualCredentialTitle, systemImage: "key")
                    .font(.subheadline.weight(.semibold))
            }

            activationControls

            if let actionResult {
                Text(actionResult)
                    .font(.caption)
                    .foregroundStyle(theme.resolved.mutedForeground.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.resolved.card.color.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.resolved.border.color.opacity(0.42), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: provider.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(provider.displayName)
                    .font(.headline)
                Text(provider.modelSummary)
                    .font(.caption)
                    .foregroundStyle(theme.resolved.mutedForeground.color)
            }

            Spacer(minLength: 10)

            CloudProviderStatusBadge(state: validationState, theme: theme)
        }
    }

    #if EPISTEMOS_APP_STORE || MAS_SANDBOX
    private var cloudDataConsentControl: some View {
        let descriptor = AgentCloudProviderDescriptor.descriptor(for: provider)
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(
                "Allow June to send prompts and selected context to \(provider.displayName)",
                isOn: Binding(
                    get: { consentStore.hasConsent(for: provider) },
                    set: { AgentCloudConsentStore.shared.setConsent($0, for: provider) }
                )
            )
            .toggleStyle(.switch)

            Text(
                "Off by default. When enabled, June may send the current prompt, bounded chat history, approved tool context, and selected vault context to \(descriptor.dataDestination). Your API key stays in macOS Keychain and is used only for that provider request. Turn this off anytime."
            )
            .font(.caption)
            .foregroundStyle(theme.resolved.mutedForeground.color)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.resolved.background.color.opacity(0.35))
        )
    }
    #endif

    private var modelPicker: some View {
        Picker("Default model", selection: Binding(
            get: { inference.preferredCloudModel(for: provider) },
            set: { inference.setPreferredCloudModel($0) }
        )) {
            ForEach(inference.cloudModels(for: provider), id: \.self) { model in
                Text(model.displayName).tag(model)
            }
        }
        .pickerStyle(.menu)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                runAccountAction()
            } label: {
                Label(
                    provider.supportsAccountConnection ? accountActionTitle : provider.accountActionTitle,
                    systemImage: provider.supportsAccountConnection ? "person.crop.circle.badge.plus" : "safari"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking)

            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            if provider == .openAI {
                Button("Import Codex CLI") {
                    runProviderAction {
                        await inference.importOpenAIAccount()
                    }
                }
                .disabled(isWorking)
            }
            #endif

            if let url = provider.documentationURL {
                Button(provider.documentationActionTitle) {
                    NSWorkspace.shared.open(url)
                }
                .disabled(isWorking)
            }
        }
    }

    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    private var googleOAuthControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(googleOAuthClientFilename.isEmpty ? "No Google OAuth JSON selected" : googleOAuthClientFilename)
                    .font(.caption)
                    .foregroundStyle(theme.resolved.mutedForeground.color)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                Button("Choose Google OAuth JSON") {
                    chooseGoogleOAuthJSON()
                }

                if !googleOAuthClientFilename.isEmpty {
                    Button("Clear Google OAuth JSON") {
                        CloudProviderSetupAutomation.clearGoogleOAuthClientConfig()
                        googleOAuthClientFilename = ""
                        googleOAuthStatusMessage = "Removed the saved Google OAuth client JSON."
                    }
                }
            }

            TextField("Google Cloud project ID (not project number)", text: $googleOAuthProjectID)
                .textFieldStyle(.roundedBorder)
                .onChange(of: googleOAuthProjectID) { _, newValue in
                    CloudProviderSetupAutomation.persistGoogleOAuthProjectIDDraft(newValue)
                }

            SettingsDescriptionText(
                text: "Choose the Google OAuth client JSON you downloaded from Google Cloud Console after creating an OAuth client ID for a Desktop app."
            )
            SettingsDescriptionText(
                text: "Enter the Google Cloud project ID for the same Gemini-enabled project."
            )

            if let googleOAuthStatusMessage {
                Text(googleOAuthStatusMessage)
                    .font(.caption)
                    .foregroundStyle(theme.resolved.mutedForeground.color)
            }
        }
    }
    #endif

    private var apiKeyControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField(provider.apiKeyPlaceholder, text: $apiKeyDraft)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Button("Paste + Save") {
                    runProviderAction {
                        let result = await CloudProviderSetupAutomation.pasteAndSave(
                            provider: provider,
                            inference: inference
                        )
                        return result
                    }
                }
                .disabled(isWorking)

                Button("Save Typed Key") {
                    saveTypedAPIKey()
                }
                .disabled(isWorking)

                if let url = provider.credentialManagementURL {
                    Button(provider.credentialActionTitle) {
                        NSWorkspace.shared.open(url)
                    }
                    .disabled(isWorking)
                }

                if hasSavedAPIKey {
                    Button("Clear API Key") {
                        _ = inference.setAPIKey("", for: provider)
                        actionResult = "\(provider.manualCredentialTitle) removed."
                    }
                    .disabled(isWorking)
                }
            }
        }
        .padding(.top, 6)
    }

    private var activationControls: some View {
        HStack(spacing: 8) {
            Button("Check Access") {
                runProviderAction {
                    await inference.validateCloudAccess(for: provider)
                }
            }
            .disabled(isWorking)

            Button("Use \(provider.displayName)") {
                inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
                inference.setPreferredChatModelSelection(.cloud(inference.preferredCloudModel(for: provider)))
                actionResult = "\(provider.displayName) is active for cloud chat."
            }
            .disabled(!validationState.isVerified)

            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            if provider.supportsAccountConnection, oauthCredential != nil {
                Button("Disconnect Account") {
                    _ = inference.setOAuthCredential(nil, for: provider)
                    actionResult = "\(provider.displayName) account disconnected."
                }
                .disabled(isWorking)
            }
            #endif
        }
        .overlay(alignment: .bottomLeading) {
            Text("Verify live access before making this provider active.")
                .font(.caption2)
                .foregroundStyle(theme.resolved.mutedForeground.color)
                .offset(y: 18)
        }
        .padding(.bottom, 16)
    }

    private func runAccountAction() {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        if let url = provider.credentialManagementURL {
            NSWorkspace.shared.open(url)
        }
        #else
        switch provider {
        case .openAI:
            runProviderAction {
                await inference.signInToOpenAI { authorization in
                    openAIDeviceAuthorization = authorization
                }
            }
        case .anthropic:
            runProviderAction {
                await inference.importAnthropicAccount()
            }
        case .google:
            connectGoogleOAuth()
        case .zai, .kimi, .minimax, .deepseek:
            if let url = provider.credentialManagementURL {
                NSWorkspace.shared.open(url)
            }
        }
        #endif
    }

    private func runProviderAction(
        _ operation: @escaping @MainActor () async -> ConnectionTestResult
    ) {
        guard !isWorking else { return }
        isWorking = true
        Task { @MainActor in
            let result = await operation()
            actionResult = result.message
            isWorking = false
        }
    }

    private func saveTypedAPIKey() {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let result = inference.recordCloudProviderValidationFailure(
                for: provider,
                message: provider.missingManualCredentialMessage
            )
            actionResult = result.message
            return
        }

        runProviderAction {
            inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
            guard inference.setAPIKey(trimmed, for: provider) else {
                return ConnectionTestResult(
                    success: false,
                    message: inference.cloudValidationState(for: provider).statusText
                )
            }
            return await inference.validateCloudAccess(for: provider)
        }
    }

    #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
    private func connectGoogleOAuth() {
        guard CloudProviderSetupAutomation.loadGoogleOAuthClientConfigData() != nil else {
            let result = inference.recordCloudProviderValidationFailure(
                for: .google,
                message: "Choose the Google OAuth client JSON you downloaded from Google Cloud Console for a Desktop app before connecting Google OAuth."
            )
            actionResult = result.message
            return
        }

        guard !googleOAuthProjectID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let result = inference.recordCloudProviderValidationFailure(
                for: .google,
                message: "Enter the Google Cloud project ID for the same project where Gemini API is enabled before connecting Google OAuth."
            )
            actionResult = result.message
            return
        }

        guard let configuration = CloudProviderSetupAutomation.storedGoogleOAuthClientConfiguration(
            projectIDOverride: googleOAuthProjectID
        ) else {
            let result = inference.recordCloudProviderValidationFailure(
                for: .google,
                message: "Couldn't read the selected Google OAuth client JSON file."
            )
            actionResult = result.message
            return
        }

        runProviderAction {
            await inference.signInToGoogle(configuration: configuration)
        }
    }

    private func chooseGoogleOAuthJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Choose Google OAuth JSON"
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            _ = try GoogleOAuthClientConfiguration.parse(from: data)
            guard CloudProviderSetupAutomation.persistGoogleOAuthClientConfig(
                data: data,
                filename: url.lastPathComponent
            ) else {
                googleOAuthStatusMessage = "Couldn't read the selected Google OAuth client JSON file."
                return
            }
            googleOAuthClientFilename = url.lastPathComponent
            googleOAuthStatusMessage = "Google OAuth client JSON verified."
        } catch {
            googleOAuthStatusMessage = "Couldn't read the selected Google OAuth client JSON file."
            _ = inference.recordCloudProviderValidationFailure(
                for: .google,
                message: "Couldn't read the selected Google OAuth client JSON file."
            )
        }
    }
    #endif
}

private struct CloudProviderStatusBadge: View {
    let state: CloudProviderValidationState
    let theme: EpistemosTheme

    var body: some View {
        Label(state.statusBadge, systemImage: state.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tintColor.opacity(0.12))
            )
    }

    private var tintColor: Color {
        switch state.tintColor {
        case .accent:
            theme.resolved.accent.color
        case .secondary:
            theme.resolved.mutedForeground.color
        case .success:
            theme.success
        case .warning:
            theme.warning
        }
    }
}

private struct GeneralDetailView: View {
    @Environment(UIState.self) private var ui
    @State private var restoreLastSession = UserDefaults.standard.bool(
        forKey: "epistemos.restoreLastSession"
    )
    @State private var showSaveOnQuit: Bool = {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "epistemos.showSaveOnQuitDialog") == nil
            ? true : defaults.bool(forKey: "epistemos.showSaveOnQuitDialog")
    }()
    @State private var summaryInterval: WorkspaceSummaryService.SummaryInterval = {
        // SS-F: match WorkspaceSummaryService's truth (it defaults to .fiveMinutes,
        // WorkspaceSummaryService.swift:24-25). The picker previously defaulted to
        // 15m while the service actually summarized every 5m on a fresh install —
        // a real default-drift bug (the picker showed a value the service ignored).
        let raw = UserDefaults.standard.string(forKey: "epistemos.summaryInterval") ?? "5m"
        return WorkspaceSummaryService.SummaryInterval(rawValue: raw) ?? .fiveMinutes
    }()
    @State private var workspaces: [SDWorkspace] = []
    @State private var renamingWorkspace: SDWorkspace?
    @State private var renameText = ""
    @State private var showResetAlert = false
    @State private var retentionResultText: String?
    @AppStorage(AppDataRetentionPolicy.timeMachineRetentionDaysKey)
    private var timeMachineRetentionDays = AppDataRetentionPolicy.defaultTimeMachineRetentionDays
    @AppStorage(AppDataRetentionPolicy.timeMachineMaxSnapshotsKey)
    private var timeMachineMaxSnapshots = AppDataRetentionPolicy.defaultTimeMachineMaxSnapshots
    @AppStorage(AppDataRetentionPolicy.eventLogRetentionDaysKey)
    private var eventLogRetentionDays = AppDataRetentionPolicy.defaultEventLogRetentionDays
    @AppStorage(AppDataRetentionPolicy.captureArtifactRetentionDaysKey)
    private var captureArtifactRetentionDays = AppDataRetentionPolicy.defaultCaptureArtifactRetentionDays
    @AppStorage(AppDataRetentionPolicy.auditLogRetentionDaysKey)
    private var auditLogRetentionDays = AppDataRetentionPolicy.defaultAuditLogRetentionDays
    @AppStorage(AppDataRetentionPolicy.savedWorkspaceLimitKey)
    private var savedWorkspaceLimit = AppDataRetentionPolicy.defaultSavedWorkspaceLimit
    // friction.enabled gates FrictionMonitorService's per-keystroke editor
    // telemetry (read at FrictionMonitorService.swift:42); surfaced here so the
    // user can turn collection off — the FrictionHealthRow diagnostic shows what
    // it records.
    @AppStorage("friction.enabled") private var frictionEnabled = true
    // epistemos.liveNotes.enabled gates AppBootstrap's LiveNoteScheduler (scans the
    // vault on a timer to refresh live-note task blocks via the LLM; read at
    // AppBootstrap.refreshLiveNoteScheduler). The reader's own comment said "users
    // can flip the toggle in Settings" — but the toggle was never built. Off by
    // default (matches the raw UserDefaults.bool reader).
    @AppStorage("epistemos.liveNotes.enabled") private var liveNotesEnabled = false
    // epistemos.enableLaunchWelcomeBackModelRefresh gates whether the Landing
    // "Welcome Back" summary is REGENERATED on each launch vs. showing the last
    // saved one (read at AppBootstrap.refreshWelcomeBackSummary:2176). Default off.
    @AppStorage("epistemos.enableLaunchWelcomeBackModelRefresh") private var regenerateWelcomeBackOnLaunch = false
    // epistemos.fsrs.autoEnroll gates whether an imported paper (arXiv/PDF) is enrolled into FSRS
    // spaced-repetition review (read at ArxivIngestService after import save). Off by default —
    // auto-enrolling every import is a personal-workflow choice.
    @AppStorage("epistemos.fsrs.autoEnroll") private var fsrsAutoEnroll = false
    private var settingsTheme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        Form {
            Section("Power") {
                SettingsDescriptionText(
                    text: "Eco Mode quiets background indexing, screen capture, vault maintenance timers, and health checks to save battery. Low Power Mode adds a 60fps render cap and is activated automatically by the system."
                )
                Toggle("Eco Mode", isOn: Binding(
                    get: { PowerGuard.shared.ecoModeEnabled },
                    set: { PowerGuard.shared.ecoModeEnabled = $0 }
                ))
                HStack {
                    Text("Current mode:")
                        .foregroundStyle(.secondary)
                    Text(PowerGuard.shared.currentMode.label)
                        .fontWeight(.medium)
                    if PowerGuard.shared.systemLowPowerActive {
                        Text("(System LPM active)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
            }

            Section("Session") {
                SettingsDescriptionText(
                    text: "Choose how Epistemos restores workspace state and whether it asks for confirmation before quitting with unsaved UI context."
                )
                Toggle("Restore last session on launch", isOn: $restoreLastSession)
                    .onChange(of: restoreLastSession) { _, newValue in
                        AppBootstrap.shared?.workspaceService.restoreLastSession = newValue
                    }
                Toggle("Show save dialog on quit", isOn: $showSaveOnQuit)
                    .onChange(of: showSaveOnQuit) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "epistemos.showSaveOnQuitDialog")
                    }
            }

            Section("Workspace Summaries") {
                SettingsDescriptionText(
                    text: "Workspace summaries are short local recaps of recent notes, vault activity, and work context so you can resume without reloading everything mentally."
                )
                Picker("Auto-summarize interval", selection: $summaryInterval) {
                    ForEach(WorkspaceSummaryService.SummaryInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: summaryInterval) { _, newValue in
                    AppBootstrap.shared?.workspaceSummaryService.summaryInterval = newValue
                }
                Text("AI-generated summaries describe what you're working on. Runs entirely on-device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Refresh Welcome Back summary on launch", isOn: $regenerateWelcomeBackOnLaunch)
                SettingsDescriptionText(
                    text: "When on, the Landing \u{201C}Welcome Back\u{201D} summary is regenerated on each launch for freshness (a brief extra startup pass). Off (default) shows the last saved summary instantly."
                )
            }

            Section("Live Notes") {
                SettingsDescriptionText(
                    text: "Live notes keep task blocks in your notes up to date by scanning the vault on a timer and refreshing them with AI. Off by default — most vaults have no live-note blocks, so scanning would burn idle CPU for no benefit."
                )
                Toggle("Keep live notes up to date", isOn: $liveNotesEnabled)
                    .onChange(of: liveNotesEnabled) { _, _ in
                        AppBootstrap.shared?.refreshLiveNoteScheduler()
                    }
            }

            Section("Review") {
                SettingsDescriptionText(
                    text: "Add papers you import (arXiv, PDF) to spaced-repetition review, so they resurface in the Review queue over time. Off by default — enrollment is a personal-workflow choice."
                )
                Toggle("Add imported papers to review", isOn: $fsrsAutoEnroll)
            }

            Section("Data Retention") {
                SettingsFeaturedPixelPanel(theme: settingsTheme) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsDescriptionText(
                            text: "Choose how long local workspace history, activity logs, and captured context stay on this Mac. Vault files are not pruned here."
                        )
                        retentionDaysPicker("Time Machine history", selection: $timeMachineRetentionDays)
                        Stepper(value: $timeMachineMaxSnapshots, in: 5...500, step: 5) {
                            Text("Keep \(timeMachineMaxSnapshots) Time Machine snapshots")
                        }
                        retentionDaysPicker("Detailed event log", selection: $eventLogRetentionDays)
                        retentionDaysPicker("Ambient capture artifacts", selection: $captureArtifactRetentionDays)
                        retentionDaysPicker("Audit and graph event trail", selection: $auditLogRetentionDays)
                        Stepper(value: $savedWorkspaceLimit, in: 0...200, step: 5) {
                            Text("Saved workspaces: \(AppDataRetentionPolicy.savedWorkspaceLimitLabel(savedWorkspaceLimit))")
                        }
                        SettingsDescriptionText(
                            text: "Core mutation receipts are kept until Reset Everything so verified writes remain auditable."
                        )
                        Button("Apply Retention Now") {
                            applyRetentionNow()
                        }
                        .controlSize(.small)
                        if let retentionResultText {
                            Text(retentionResultText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Saved Workspaces") {
                SettingsDescriptionText(
                    text: "Saved workspaces preserve a working set of windows and context so you can reload an environment instead of rebuilding it by hand."
                )
                if workspaces.isEmpty {
                    Text("No saved workspaces yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workspaces, id: \.id) { workspace in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workspace.name)
                                    .font(.body)
                                Text(workspace.updatedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Load") {
                                AppBootstrap.shared?.workspaceService.loadWorkspace(workspace)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button("Rename") {
                                renameText = workspace.name
                                renamingWorkspace = workspace
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            Button(role: .destructive) {
                                Task { @MainActor in
                                    await requestSavedWorkspaceDeleteAuthorization(workspace)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .accessibilityLabel("Delete workspace \(workspace.name)")
                            .accessibilityHint("Permanently removes this saved workspace.")
                        }
                    }
                }
            }

            Section("Data Protection") {
                SettingsDescriptionText(
                    text: "This summarizes where key app data lives so you can see what stays local, what uses system services, and what is protected by macOS."
                )
                LabeledContent("Vault data") {
                    Text("Stored on this Mac")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                LabeledContent("Provider credentials") {
                    Text("Stored in Keychain when configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Sandbox") {
                    Text("Enabled")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Toggle("Record writing friction", isOn: $frictionEnabled)
                SettingsDescriptionText(
                    text: "Local editor telemetry — typing pauses, deletions, and revision bursts — powering the writing-friction diagnostic. Behavioral only (never your note text) and never leaves this Mac. Turn off to stop collection."
                )
            }

            Section("Performance") {
                SettingsDescriptionText(
                    text: "Tune how aggressively the app warms on launch and how much memory it keeps for vault, search, graph, and editor caches while idle."
                )
                PerformanceSettingsSection()
            }
            // 2026-05-20 UX fix: graph performance moved to Settings → Graph
            // (AppearanceDetailView) where users naturally look for graph settings.

            Section("Diagnostics") {
                SettingsDescriptionText(
                    text: "Read-only health probes for app storage, indexing, memory, graph projections, and import surfaces. Foundation IP lives in Epistemos Foundation."
                )
                VaultSaveHealthRow()
                ShadowSearchHealthRow()
                BackgroundIndexingHealthRow()
                ProcessMemoryHealthRow()
                ArenaHealthRow()
                OpLogProjectionHealthRow()
                KnowledgeCoreReadParityHealthRow()
                KnowledgeCoreRuntimeHealthRow()
                KnowledgeCoreOutlinePreview()
                GraphEventVisibilityRow()
                // SS-HW (owner 2026-06-20): honest HTML Workspace status — works as a renderer/editor
                // + agent-patch surface, but app-bridge/live-DOM/console/Python/regenerate are deferred.
                // The owner: "idk if its marked as such." Now it is. Read-only; no dead controls.
                HTMLWorkspaceHealthRow()
                // SS-M / Obscura (owner 2026-06-19): honest browser/scraper/privacy status — real HTTP
                // fetch/extract/crawl + private web views work; the Obscura stealth engine is a
                // NotConfigured stub (Pro, unbuilt). Read-only; no fake control.
                if ProductCapabilityPolicy.isAvailable(.browser) {
                    BrowserCapabilityHealthRow()
                }
                // RCA13 P1-021: deployment-profile honesty row.
                // Visible in BOTH profiles so users + auditors can see
                // at a glance whether this build is MAS or Pro and
                // which capabilities differ between them.
                DeploymentProfileHealthRow()
                #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
                // Pro-only: surface which agent_core passthrough CLIs
                // (claude / codex / gemini / kimi) are present on the
                // user's machine. The MAS sandbox blocks subprocess
                // execution outright, so this row would be misleading
                // there — kept Pro-side only per RCA13 P8.
                CLIDiscoveryHealthRow()
                #endif
            }

            Section("Reset") {
                Text("Clear saved app data, conversations, workspace history, and settings. Vault files on disk are preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset Everything", role: .destructive) {
                    showResetAlert = true
                }
                .controlSize(.small)
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshWorkspaces() }
        .alert("Rename Workspace", isPresented: Binding(
            get: { renamingWorkspace != nil },
            set: { if !$0 { renamingWorkspace = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let ws = renamingWorkspace {
                    AppBootstrap.shared?.workspaceService.renameWorkspace(ws, to: renameText)
                    refreshWorkspaces()
                }
                renamingWorkspace = nil
            }
            Button("Cancel", role: .cancel) { renamingWorkspace = nil }
        }
        .alert("Reset Everything?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task { @MainActor in
                    await requestResetEverythingAuthorization()
                }
            }
        } message: {
            Text("This will delete conversations, notes metadata, workspace history, and app settings. Vault files on disk and appearance settings are preserved. This cannot be undone.")
        }
    }

    @MainActor
    private func requestSavedWorkspaceDeleteAuthorization(_ workspace: SDWorkspace) async {
        let target = SettingsViewDestructiveActionSovereignGate.Target.savedWorkspace(name: workspace.name)
        let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
            SettingsViewDestructiveActionSovereignGate.requirement(for: target),
            reason: SettingsViewDestructiveActionSovereignGate.reason(for: target)
        ) ?? .denied(.authenticationFailed)

        guard outcome == .allowed else { return }
        deleteSavedWorkspace(workspace)
    }

    private func deleteSavedWorkspace(_ workspace: SDWorkspace) {
        AppBootstrap.shared?.workspaceService.deleteWorkspace(workspace)
        refreshWorkspaces()
    }

    @MainActor
    private func requestResetEverythingAuthorization() async {
        let target = SettingsViewDestructiveActionSovereignGate.Target.resetEverything
        let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
            SettingsViewDestructiveActionSovereignGate.requirement(for: target),
            reason: SettingsViewDestructiveActionSovereignGate.reason(for: target)
        ) ?? .denied(.authenticationFailed)

        guard outcome == .allowed else { return }
        await resetEverything()
    }

    @MainActor
    private func resetEverything() async {
        await AppBootstrap.shared?.resetAllData()
    }

    private func refreshWorkspaces() {
        workspaces = AppBootstrap.shared?.workspaceService.listWorkspaces() ?? []
    }

    private func retentionDaysPicker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(AppDataRetentionPolicy.dayOptions, id: \.self) { days in
                Text(AppDataRetentionPolicy.label(forDays: days)).tag(days)
            }
        }
        .pickerStyle(.menu)
    }

    private func applyRetentionNow() {
        let policy = AppDataRetentionPolicy.current()
        let eventSummary = EventStore.shared?.applyRetentionPolicy(policy.eventStorePolicy) ?? .empty
        let workspaceDeletes = AppBootstrap.shared?.workspaceService.enforceSavedWorkspaceLimit(policy.savedWorkspaceLimit) ?? 0
        retentionResultText = AppDataRetentionPolicy.summaryLabel(
            eventSummary: eventSummary,
            workspaceDeletes: workspaceDeletes
        )
        refreshWorkspaces()
    }
}

// MARK: - Landing Detail

private struct LandingDetailView: View {
    @Environment(UIState.self) private var ui

    var body: some View {
        @Bindable var ui = ui

        Form {
            Section("Greeting Behavior") {
                SettingsDescriptionText(
                    text: "Landing controls the welcome surface you see before diving into notes or chat. These settings shape that first-run and idle experience only."
                )
                Toggle("Animate typewriter", isOn: $ui.landingGreetingTypewriterEnabled)

                Picker("Greeting Sources", selection: $ui.landingGreetingSourceMode) {
                    ForEach(LandingGreetingSourceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Text(ui.landingGreetingSourceMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quick Capture & Siri") {
                SettingsDescriptionText(
                    text: "Quick Capture is the landing command overlay for fast text or voice intake. Open it with ⌘⇧N, or launch it below and use the Dictate button inside the overlay. Siri and Shortcuts use the same App Intents integration."
                )

                HStack(spacing: 10) {
                    Button("Open Quick Capture") {
                        NotificationCenter.default.post(name: .showQuickCapture, object: nil)
                    }

                    Button("Refresh Siri Shortcuts") {
                        EpistemosShortcutsProvider.updateAppShortcutParameters()
                    }

                    Button("Open Shortcuts") {
                        openShortcutsApp()
                    }
                    .disabled(NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") == nil)
                }

                HStack {
                    Text("Microphone access")
                    Spacer()
                    Text(microphoneAccessLabel)
                        .foregroundStyle(
                            microphoneAccessGranted ? Color.secondary : Color.orange
                        )
                }

                if !microphoneAccessGranted {
                    Button("Open Microphone Settings") {
                        openMicrophoneSettings()
                    }
                }
            }

            Section("Greeting Library") {
                SettingsDescriptionText(
                    text: "Add, reorder, and tune your custom landing greetings. Each entry can be enabled independently and shown for a specific duration."
                )
                if ui.landingCustomGreetings.isEmpty {
                    ContentUnavailableView(
                        "No Custom Greetings",
                        systemImage: "text.badge.plus",
                        description: Text("Add your own greetings and timing.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(ui.landingCustomGreetings) { greeting in
                        LandingGreetingEditorRow(
                            greeting: greeting,
                            isFirst: ui.landingCustomGreetings.first?.id == greeting.id,
                            isLast: ui.landingCustomGreetings.last?.id == greeting.id
                        )
                    }
                }

                Button {
                    ui.addLandingGreeting()
                } label: {
                    Label("Add Greeting", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var microphoneAccessGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private var microphoneAccessLabel: String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            "Ready"
        case .notDetermined:
            "Not requested yet"
        case .denied, .restricted:
            "Needs permission"
        @unknown default:
            "Unknown"
        }
    }

    private func openShortcutsApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") else {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct LandingGreetingEditorRow: View {
    @Environment(UIState.self) private var ui

    let greeting: LandingGreetingEntry
    let isFirst: Bool
    let isLast: Bool

    private var durationRange: ClosedRange<Double> {
        LandingGreetingEntry.minimumDurationSeconds...LandingGreetingEntry.maximumDurationSeconds
    }

    private var accessibilitySnippet: String {
        let trimmed = greeting.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "(empty)" }
        if trimmed.count <= 32 {
            return trimmed
        }
        return String(trimmed.prefix(32)) + "…"
    }

    private var formattedDurationSeconds: String {
        String(format: "%.1f", greeting.durationSeconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { greeting.isEnabled },
                        set: { ui.updateLandingGreetingEnabled(id: greeting.id, isEnabled: $0) }
                    )
                )
                .labelsHidden()
                .accessibilityLabel("Enable greeting \(accessibilitySnippet)")

                TextField(
                    "Greeting text",
                    text: Binding(
                        get: { greeting.text },
                        set: { ui.updateLandingGreetingText(id: greeting.id, text: $0) }
                    )
                )
                .accessibilityLabel("Greeting text")

                Button(action: { ui.moveLandingGreeting(id: greeting.id, by: -1) }) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(isFirst)
                .accessibilityLabel("Move greeting up")
                .accessibilityHint("Reorders \(accessibilitySnippet) one position earlier in the rotation.")

                Button(action: { ui.moveLandingGreeting(id: greeting.id, by: 1) }) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(isLast)
                .accessibilityLabel("Move greeting down")
                .accessibilityHint("Reorders \(accessibilitySnippet) one position later in the rotation.")

                Button(role: .destructive, action: { ui.removeLandingGreeting(id: greeting.id) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove greeting \(accessibilitySnippet)")
                .accessibilityHint("Deletes this greeting from the rotation.")
            }

            // Compact controls + status; stacked fallback at large sizes.
            // `.fixedSize` on the compact controls block trips ViewThatFits
            // when the labels would otherwise silently compress.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    durationControls
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    durationStatusText
                }
                VStack(alignment: .leading, spacing: 4) {
                    durationControls
                    durationStatusText
                }
            }
        }
        .padding(.vertical, 4)
    }

    // Explicit HStack rather than a `@ViewBuilder` that returned a TupleView
    // of four siblings. Returning a TupleView meant `.fixedSize(...)` applied
    // at the call site had ambiguous sibling-layout semantics inside the outer
    // HStack — the modifier wraps each child individually. With a real HStack
    // here, `.fixedSize(horizontal: true, vertical: false)` predictably
    // forces the whole control cluster to its intrinsic width, which is what
    // the outer ViewThatFits compact candidate needs to trip the fallback.
    private var durationControls: some View {
        HStack(spacing: 8) {
            Text("Duration")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(
                "",
                value: Binding(
                    get: { greeting.durationSeconds },
                    set: { ui.updateLandingGreetingDuration(id: greeting.id, durationSeconds: $0) }
                ),
                format: .number.precision(.fractionLength(1))
            )
            .frame(minWidth: 54, idealWidth: 64)
            .accessibilityLabel("Greeting duration")
            .accessibilityValue("\(formattedDurationSeconds) seconds")

            Text("s")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Stepper(
                "",
                value: Binding(
                    get: { greeting.durationSeconds },
                    set: { ui.updateLandingGreetingDuration(id: greeting.id, durationSeconds: $0) }
                ),
                in: durationRange,
                step: 0.2
            )
            .labelsHidden()
            .accessibilityLabel("Greeting duration stepper")
            .accessibilityValue("\(formattedDurationSeconds) seconds")
        }
    }

    @ViewBuilder
    private var durationStatusText: some View {
        Text(greeting.isEnabled ? "Enabled" : "Disabled")
            .font(.caption2.weight(.medium))
            .foregroundStyle(greeting.isEnabled ? .secondary : .tertiary)
    }
}

// MARK: - Appearance Detail

private struct AppearanceDetailView: View {
    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        AppearanceDetailContainer(
            ui: ui,
            theme: theme
        )
    }
}

private struct AppearanceDetailContainer: View {
    let ui: UIState
    let theme: EpistemosTheme

    var body: some View {
        configuredForm
    }

    private var configuredForm: some View {
        appearanceForm
            .formStyle(.grouped)
    }

    // P6.4 (item 3) — section order mirrors `AppearanceSection.canonical`
    // (locked by AppearanceSectionOrderTests): all look-and-feel sections
    // (theme, custom, typography, editor) grouped first, then the graph trio as
    // one contiguous block. Declutter only reorders — every real setting stays.
    private var appearanceForm: some View {
        Form {
            // Look & feel
            AppearanceThemePairSection(ui: ui, theme: theme)
            if ui.themeMode == .custom && ui.activePair == .custom {
                AppearanceCustomThemeSection(ui: ui)
            }
            AppearanceTypographySection(ui: ui)
            AppearanceEditorSection()
            // Graph visuals (contiguous block)
            AppearanceGraphNodeVisibilitySection()
            AppearanceGraphPerformanceSection()
            AppearanceShapedGraphSection(ui: ui)
        }
    }
}

// MARK: - Appearance: Graph performance (2026-05-20)
//
// Lives under Settings → Graph (AppearanceDetailView form) so users
// can find FPS-related toggles next to the other graph-visual
// settings (shaped graph, node visibility). The actual implementation
// lives in `GraphPerformanceSettingsSection` further down — this
// wrapper just adds the `Section` header + description.

private struct AppearanceGraphPerformanceSection: View {
    var body: some View {
        Section("Graph performance") {
            SettingsDescriptionText(
                text: "Frame rate cap controls how often the graph re-renders during interaction. Unlimited uses ProMotion adaptive (60–120 fps on a 14/16″ MacBook Pro). Lower caps save battery + GPU headroom. The FPS HUD shows a live readout in the bottom-right of the graph chrome — useful for tuning forces/physics or verifying the cap."
            )
            GraphPerformanceSettingsSection()
        }
    }
}

private struct AppearanceShapedGraphSection: View {
    let ui: UIState

    var body: some View {
        Section("Shaped Graph (experimental)") {
            Toggle(isOn: Binding(
                get: { ui.shapedGraphExperimental },
                set: { ui.shapedGraphExperimental = $0 }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frameless graph canvas")
                        .font(.body)
                    Text("Replaces the graph window chrome with a soft shape-blur that follows the active node cluster, then morphs into a rounded rectangle when a node is opened. Off by default — toggle on to preview.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
    }
}

// MARK: - Graph performance settings (2026-05-20)
//
// FPS cap + live HUD toggle for the hologram graph overlay. Reads/writes
// `graphState.graphMaxFPS` + `graphFPSHUDEnabled` (both persisted in
// UserDefaults via GraphState.didSet).

@MainActor
private struct GraphPerformanceSettingsSection: View {
    @Environment(GraphState.self) private var graphState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            viewLocationRow
            Divider()
            forceMaximumFPSRow
            Divider()
            fpsCapRow
            Divider()
            fpsHUDRow
            Divider()
            disclaimer
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    /// Phase 1 — Where the graph opens when the user presses ⌘G.
    /// `.miniPanel` keeps the existing floating panel. `.embedded`
    /// replaces the home greeting with the full graph chrome inline.
    private var viewLocationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "macwindow.on.rectangle")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text("Graph view location")
                    .font(.system(size: 13, weight: .medium))
            }
            Picker("", selection: Binding(
                get: { graphState.graphViewLocation },
                set: { graphState.graphViewLocation = $0 }
            )) {
                ForEach(GraphViewLocation.allCases) { location in
                    Text(location.displayName).tag(location)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(graphState.graphViewLocation.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var forceMaximumFPSRow: some View {
        Toggle(isOn: Binding(
            get: { graphState.graphForceMaximumFPS },
            set: { graphState.graphForceMaximumFPS = $0 }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                    Text("Force ProMotion 120 fps everywhere")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text("Override every cap, thermal-throttle tier, and ProcessInfo power-state on this app's display links. Graph + landing wave clamp to a tight 120/120/120 CAFrameRateRange. ON = max smoothness; trades battery + may throttle hardware to thermal-fair sooner on warm sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }

    private var fpsCapRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "speedometer")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text("Frame rate cap")
                    .font(.system(size: 13, weight: .medium))
            }
            Picker("", selection: Binding(
                get: { graphState.graphMaxFPS },
                set: { graphState.graphMaxFPS = $0 }
            )) {
                Text("Unlimited (ProMotion adaptive)").tag(0)
                Text("120 fps").tag(120)
                Text("60 fps").tag(60)
                Text("30 fps (battery)").tag(30)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Text("0 = Unlimited lets the OS pick between 60 and 120 fps based on GPU headroom. Pick 60 or 30 for steady battery use; pick 120 to force ProMotion's top rate even when the GPU could drop to 60.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var fpsHUDRow: some View {
        Toggle(isOn: Binding(
            get: { graphState.graphFPSHUDEnabled },
            set: { graphState.graphFPSHUDEnabled = $0 }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Show FPS HUD on graph")
                    .font(.system(size: 13, weight: .medium))
                Text("Live readout in the graph's bottom-right corner. Shows current fps + p99 frame interval. Green = meeting cap; yellow = ≥45 fps; red = dropping frames.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
    }

    private var disclaimer: some View {
        Text("FPS measured at the Swift display-link layer. The real per-frame cost is the Rust render call (`graph_engine_render`) plus the macOS 26 compositor — if p99 stays above 8.3 ms during sustained interaction, you'll cap at 60 fps even with the picker on 120.")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
    }
}

private struct AppearanceThemePairSection: View {
    let ui: UIState
    let theme: EpistemosTheme

    private let columns = [
        GridItem(.adaptive(minimum: 154), spacing: Spacing.sm, alignment: .top),
    ]

    @AppStorage("epistemos.theme.customExperimentalEnabled")
    private var customThemesExperimentalEnabled = false

    private var visibleThemePairs: [ThemePair] {
        // Custom is experimental + OFF by default (owner request 2026-07-03): hide it
        // from the picker until the user enables the experimental toggle below.
        ThemePair.allCases.filter { $0 != .custom || customThemesExperimentalEnabled }
    }

    var body: some View {
        Section {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                ForEach(visibleThemePairs, id: \.self) { pair in
                    ThemePairCard(
                        pair: pair,
                        theme: theme,
                        isSelected: ui.activePair == pair
                    ) {
                        ui.setPair(pair)
                        ui.setThemeMode(.custom)
                    }
                }
            }

            Toggle(isOn: $customThemesExperimentalEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom themes (experimental)")
                        .font(.callout.weight(.medium))
                    Text("Off by default. Enables a fully user-editable palette across native and web surfaces. Experimental — it is modular and may not render perfectly everywhere.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: customThemesExperimentalEnabled) { _, enabled in
                // Disabling the experiment while Custom is selected falls back to the
                // default theme so nothing renders half-custom.
                if !enabled, ui.activePair == .custom {
                    ui.setPair(.platinumViolet)
                }
            }

            Text("Theme pairs color native app surfaces and graph materials through semantic tokens. Window chrome stays native.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Themes")
        }
    }
}

private struct ThemePairCard: View {
    let pair: ThemePair
    let theme: EpistemosTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        // RCA finalization 2026-05-13: more cinematic theme preview.
        // Pulled the two tiny swatches down to a single, larger
        // duotone window — left half = light variant with a "GREETINGS"
        // hero sample in that pair's display font, right half = dark
        // variant with the same sample. Subtle gradient on each half
        // plus a faint scanline glow on the dark side mimics the live
        // OLED/Platinum dark look so the preview reads at a glance.
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.displayName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        Text(pair.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: Spacing.xs)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.resolved.accent.color)
                            .imageScale(.small)
                    }
                }

                // Owner 2026-06-18: palette preview for ALL themes (was gated to
                // custom only). Custom keeps its editable-slot swatch; every
                // other pair shows its resolved light/dark palette.
                if pair == .custom {
                    CustomThemePaletteSwatch()
                } else {
                    ThemePairPaletteSwatch(pair: pair)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .background(cardBackground)
            .overlay(cardBorder)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(pair.displayName) theme pair"))
    }

    // Pixel-art card chrome: hard rectangle, no rounding (owner P6.4b) — coherent
    // with the pixel-art palette swatch it frames.
    private var cardBackground: some View {
        Rectangle()
            .fill(
                isSelected
                    ? theme.resolved.accent.color.opacity(theme.isDark ? 0.20 : 0.14)
                    : theme.resolved.card.color.opacity(theme.isDark ? 0.42 : 0.72)
            )
    }

    private var cardBorder: some View {
        Rectangle()
            .stroke(
                isSelected
                    ? theme.resolved.accent.color.opacity(0.72)
                    : theme.resolved.border.color.opacity(theme.isDark ? 0.42 : 0.58),
                lineWidth: isSelected ? 1.6 : 1.2
            )
    }
}

/// Owner 2026-06-18 — palette preview for a ThemePair: the pair's key resolved
/// colors (background / card / accent / heading / foreground / border), light
/// then dark, as clean swatches. Replaces the busy "GREETINGS" mock-UI card so
/// every theme reads as "this is the palette" at a glance.
// Pixel-art palette swatch — hard rectangles, no rounding (owner P6.4b). Shows a
// ThemePair's key resolved colors (background / card / accent / heading / foreground
// / border), light then dark, so every theme reads as "this is the palette" at a
// glance, in the app's pixel-art identity.
private struct ThemePairPaletteSwatch: View {
    let pair: ThemePair

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            paletteRow(theme: pair.lightTheme, label: "Light")
            paletteRow(theme: pair.darkTheme, label: "Dark")
        }
        .padding(8)
        // Pixel-art: hard rectangular border, no rounding.
        .overlay(
            Rectangle()
                .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func paletteRow(theme: EpistemosTheme, label: String) -> some View {
        let resolved = theme.presetResolved
        let colors: [Color] = [
            resolved.background.color,
            resolved.card.color,
            resolved.accent.color,
            resolved.headingAccent.color,
            resolved.foreground.color,
            resolved.border.color,
        ]
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Rectangle()
                    .fill(color)
                    .frame(height: 22)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }
}

/// P6.4 — the custom-theme preview is a clean COLOR-PALETTE swatch (the theme's
/// key colors, light + dark) rather than a busy mock-UI card. Palette-only: it
/// shows exactly the editable slots so the preview reads as "this is the
/// palette", honest and pixel-art minimal.
// Pixel-art palette swatch — hard rectangles, no rounding (owner P6.4b). The custom
// theme's editable color slots (light + dark), so its preview reads as "this is the
// palette" exactly like the other pairs, in the app's pixel-art identity.
private struct CustomThemePaletteSwatch: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            paletteRow(isDark: false, label: "Light")
            paletteRow(isDark: true, label: "Dark")
        }
        .padding(8)
        // Pixel-art: hard rectangular border, no rounding.
        .overlay(
            Rectangle()
                .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func paletteRow(isDark: Bool, label: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            ForEach(AppCustomThemeColorSlot.allCases, id: \.rawValue) { slot in
                swatch(slot: slot, isDark: isDark)
            }
        }
    }

    @ViewBuilder
    private func swatch(slot: AppCustomThemeColorSlot, isDark: Bool) -> some View {
        let color = Color(hex: AppCustomTheme.hex(for: slot, isDark: isDark))
        Rectangle()
            .fill(color)
            .frame(height: 22)
            .overlay(
                Rectangle()
                    .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
            )
            .help(slot.title)
    }
}

private struct AppearanceCustomThemeSection: View {
    let ui: UIState
    @State private var editingDarkVariant = SystemAppearanceState.isDark()

    private let columns = [
        GridItem(.adaptive(minimum: 146), spacing: Spacing.sm, alignment: .top),
    ]

    var body: some View {
        Section {
            HStack(alignment: .center, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Custom theme")
                        .font(.caption.weight(.semibold))
                    Text("Editing \(editingDarkVariant ? "dark" : "light") Custom. Preset themes stay locked.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Variant", selection: $editingDarkVariant) {
                    Text("Light").tag(false)
                    Text("Dark").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 124)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                ForEach(AppCustomThemeColorSlot.allCases) { slot in
                    CustomThemeColorTile(
                        slot: slot,
                        color: colorBinding(slot: slot, isDark: editingDarkVariant)
                    )
                }
            }

            HStack {
                CustomThemeLivePreview(isDark: editingDarkVariant)
                    .frame(maxWidth: 260)
                Spacer()
                Button("Reset Custom Colors") {
                    AppCustomTheme.reset()
                    ui.refreshTypographySettings()
                }
                .controlSize(.small)
            }
        } header: {
            Text("Custom Appearance")
        }
        .onAppear {
            editingDarkVariant = ui.theme.presetResolved.isDark
        }
    }

    private func colorBinding(slot: AppCustomThemeColorSlot, isDark: Bool) -> Binding<Color> {
        Binding(
            get: {
                // SS-TC: inheriting slots show their parent's *current* value until set,
                // so the picker swatch matches the resolved theme (no jarring default jump).
                let hex: UInt32
                switch slot {
                case .noteSurface:
                    hex = AppCustomTheme.noteSurfaceHex(isDark: isDark)
                case .userBubbleText, .secondaryText:
                    hex = AppCustomTheme.inheritedHex(
                        for: slot, fallback: AppCustomTheme.hex(for: .text, isDark: isDark), isDark: isDark)
                case .link, .border:
                    hex = AppCustomTheme.inheritedHex(
                        for: slot, fallback: AppCustomTheme.hex(for: .accent, isDark: isDark), isDark: isDark)
                case .assistantBubbleBg:
                    hex = AppCustomTheme.inheritedHex(
                        for: slot, fallback: AppCustomTheme.hex(for: .card, isDark: isDark), isDark: isDark)
                default:
                    hex = AppCustomTheme.hex(for: slot, isDark: isDark)
                }
                return Color(hex: hex)
            },
            set: { color in
                guard let hex = color.rgbHex else { return }
                AppCustomTheme.setHex(hex, for: slot, isDark: isDark)
                ui.refreshTypographySettings()
            }
        )
    }
}

private struct CustomThemeColorTile: View {
    let slot: AppCustomThemeColorSlot
    @Binding var color: Color

    var body: some View {
        HStack(spacing: 8) {
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.title)
                    .font(.caption.weight(.semibold))
                Text(slot.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        // Pixel-art custom-theme editor (owner P6.4c): hard rectangle, no rounding.
        .background(.quaternary, in: Rectangle())
    }
}

private struct CustomThemeLivePreview: View {
    let isDark: Bool

    var body: some View {
        let resolved = AppCustomTheme.resolved(isDark: isDark)
        let noteSurface = EpistemosTheme.ResolvedColorToken
            .hex(AppCustomTheme.noteSurfaceHex(isDark: isDark))
        let fontName = AppDisplayTypography.storedHeadingFontOverride(level: 1)
            ?? AppDisplayTypography.matrixDisplayFontName
        return VStack(alignment: .leading, spacing: 8) {
            Text("Custom Preview")
                .font(.custom(fontName, size: 15).weight(.bold))
                .foregroundStyle(resolved.headingAccent.color)
            HStack(spacing: 6) {
                Rectangle()
                    .fill(resolved.accent.color)
                    .frame(width: 42, height: 7)
                Rectangle()
                    .fill(resolved.foreground.color.opacity(0.28))
                    .frame(width: 72, height: 7)
            }
            Text("Heading, text, note surfaces, panels, and chat stay together.")
                .font(.caption2)
                .foregroundStyle(resolved.foreground.color.opacity(0.82))
                .lineLimit(2)
            HStack(spacing: 6) {
                Rectangle()
                    .fill(noteSurface.color)
                    .frame(width: 52, height: 20)
                    .overlay(
                        Rectangle()
                            .stroke(resolved.border.color.opacity(0.7), lineWidth: 1)
                    )
                Text(isDark ? "Dark note surface" : "Light note surface")
                    .font(.caption2)
                    .foregroundStyle(resolved.foreground.color.opacity(0.74))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Pixel-art custom-theme live preview (owner P6.4c): hard rectangle frame.
        .background(resolved.background.color, in: Rectangle())
        .overlay(
            Rectangle()
                .stroke(resolved.border.color, lineWidth: 1)
        )
    }
}

private extension Color {
    var rgbHex: UInt32? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else {
            return nil
        }
        let red = UInt32((color.redComponent * 255).rounded()).clampedToByte
        let green = UInt32((color.greenComponent * 255).rounded()).clampedToByte
        let blue = UInt32((color.blueComponent * 255).rounded()).clampedToByte
        return (red << 16) | (green << 8) | blue
    }
}

private extension UInt32 {
    var clampedToByte: UInt32 {
        Swift.min(Swift.max(self, 0), 255)
    }
}

private struct AppearanceEditorSection: View {
    // Same key as the per-editor View Options menu in CodeEditorView so
    // toggling either surface reflects in the other immediately.
    @AppStorage("epistemos.codeEditor.showLineGutter") private var showLineGutter = true
    @AppStorage("codeEditor.useLegacyV1Editor") private var useLegacyV1Editor = false

    var body: some View {
        Section {
            Toggle("Show Line Numbers", isOn: $showLineGutter)
                .toggleStyle(.switch)
            Text("Adds a subtle right-side gutter to the code editor. Numbers track the active theme and Dynamic Type.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Use v1 Legacy Code Editor", isOn: $useLegacyV1Editor)
                .toggleStyle(.switch)
            Text("Keeps the old WebKit code editor available as an explicit fallback while MarkEdit CoreEditor remains the default.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Editor")
        }
    }
}

private struct AppearanceGraphNodeVisibilitySection: View {
    @Environment(GraphState.self) private var graphState

    var body: some View {
        Section {
            HStack {
                Button("Content Only") {
                    graphState.applyContentFocusedNodeVisibility()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Show All") {
                    graphState.showAllUserFilterableNodeTypes()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(GraphState.userFilterableNodeTypes, id: \.self) { type in
                Toggle(type.settingsDisplayName, isOn: Binding(
                    get: { graphState.isNodeTypeVisible(type) },
                    set: { graphState.setNodeTypeVisibility(type, isVisible: $0) }
                ))
                .toggleStyle(.switch)
            }

            Text("Hidden types stay in the vault and can be restored instantly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Graph Node Types")
        }
    }
}

private extension GraphNodeType {
    var settingsDisplayName: String {
        switch self {
        case .document:
            return "Epdoc"
        default:
            return displayName
        }
    }
}

private struct AppearanceTypographySection: View {
    let ui: UIState
    @State private var showsFontLibrary = false

    var body: some View {
        Section {
            Toggle("Readable fonts", isOn: Binding(
                get: { ui.readableFontsEnabled },
                set: { ui.setReadableFontsEnabled($0) }
            ))
                .toggleStyle(.switch)

            Text("Uses Avenir Next for app chrome, notes, chat, and document text. Landing-page display typography stays unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)

            DisclosureGroup(isExpanded: $showsFontLibrary) {
                FontLibraryPreviewGrid()
                    .padding(.top, 6)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Font Library")
                        .font(.caption.weight(.semibold))
                    Text("Every bundled display face is labeled with its own preview.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if ui.themeMode == .custom && ui.activePair == .custom {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Heading Typography")
                                .font(.caption.weight(.semibold))
                            Text("Heading font and scale apply only to Custom.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset") {
                            AppDisplayTypography.resetHeadingTypography()
                            ui.refreshTypographySettings()
                        }
                        .controlSize(.small)
                    }

                    ForEach([1, 2, 3], id: \.self) { level in
                        HeadingTypographyControlRow(
                            level: level,
                            fontSelection: headingFontBinding(level: level),
                            sizeScale: headingSizeScaleBinding(level: level),
                            previewFontName: selectedHeadingFontName(level: level),
                            previewSize: previewSize(level: level)
                        )
                    }
                }
                .padding(.top, 4)
            }
        } header: {
            Text("Typography")
        }
    }

    private func headingFontBinding(level: Int) -> Binding<String> {
        Binding(
            get: { AppDisplayTypography.storedHeadingFontOverride(level: level) ?? "" },
            set: { newValue in
                AppDisplayTypography.setHeadingFontOverride(newValue.isEmpty ? nil : newValue, level: level)
                ui.refreshTypographySettings()
            }
        )
    }

    private func headingSizeScaleBinding(level: Int) -> Binding<Double> {
        Binding(
            get: { Double(AppDisplayTypography.storedHeadingSizeScale(level: level)) },
            set: { newValue in
                AppDisplayTypography.setHeadingSizeScale(CGFloat(newValue), level: level)
                ui.refreshTypographySettings()
            }
        )
    }

    private func selectedHeadingFontName(level: Int) -> String {
        AppDisplayTypography.storedHeadingFontOverride(level: level)
            ?? ui.theme.headingFontName(level: level)
    }

    private func previewSize(level: Int) -> CGFloat {
        let base: CGFloat = switch level {
        case 1: 22
        case 2: 18
        default: 15
        }
        return base * AppDisplayTypography.storedHeadingSizeScale(level: level)
    }
}

private struct FontLibraryPreviewGrid: View {
    private let columns = [
        GridItem(.adaptive(minimum: 156), spacing: 8, alignment: .top),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(AppDisplayTypography.displayFontOptions) { option in
                FontLibraryPreviewTile(option: option)
            }
        }
    }
}

private struct FontLibraryPreviewTile: View {
    let option: AppBundledDisplayFont

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(option.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("EPST H1")
                .font(.custom(option.postScriptName, size: 17))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(option.postScriptName)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HeadingTypographyControlRow: View {
    let level: Int
    @Binding var fontSelection: String
    @Binding var sizeScale: Double
    let previewFontName: String
    let previewSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Text("H\(level)")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, alignment: .leading)
                Picker("Font", selection: $fontSelection) {
                    Text("Theme default").tag("")
                    ForEach(AppDisplayTypography.displayFontOptions) { option in
                        Text(option.displayName)
                            .font(.custom(option.postScriptName, size: 13))
                            .tag(option.postScriptName)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 240)

                Slider(
                    value: $sizeScale,
                    in: Double(AppDisplayTypography.minimumHeadingSizeScale)...Double(AppDisplayTypography.maximumHeadingSizeScale),
                    step: 0.05
                )
                .frame(minWidth: 120)

                Text("\(Int((sizeScale * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }

            Text("Heading \(level) Preview")
                .font(.custom(previewFontName, size: previewSize))
                .fontWeight(level == 1 ? .heavy : .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Vault Detail

private struct VaultDetailView: View {
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @State private var isVaultDisconnectAuthorizationInFlight = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Form {
            Section("Connection") {
                SettingsDescriptionText(
                    text: "Your vault is the on-disk markdown workspace Epistemos reads from and writes to. External edits from other apps are watched and reflected back into notes automatically."
                )
                if let url = vaultSync.vaultURL {
                    LabeledContent("Path") {
                        Text(url.path)
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    LabeledContent("Status") {
                        HStack(spacing: 4) {
                            if vaultSync.isIndexing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Circle()
                                .fill(vaultSync.isIndexing ? Color.orange : (vaultSync.isWatching ? Color.green : Color.red))
                                .frame(width: 8, height: 8)
                            Text(vaultSync.vaultActivityMessage ?? (vaultSync.isWatching ? "Connected" : "Disconnected"))
                                .font(.caption)
                        }
                    }
                    if let details = vaultSync.visibleVaultImportDetails {
                        VaultImportDiagnosticsView(
                            snapshot: details,
                            isActive: vaultSync.vaultImportProgress != nil
                        )
                    }
                    HStack(spacing: Spacing.md) {
                        Button("Change Vault") {
                            VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                        }
                        .controlSize(.small)
                        Button("Sync from Vault") {
                            Task { _ = await vaultSync.syncFromVault() }
                        }
                        .controlSize(.small)
                        Button("Disconnect", role: .destructive) {
                            Task { @MainActor in
                                await requestVaultDisconnectAuthorization(vaultURL: url)
                            }
                        }
                        .controlSize(.small)
                        .disabled(isVaultDisconnectAuthorizationInFlight)
                    }
                } else {
                    if let message = vaultSync.vaultActivityMessage {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let details = vaultSync.visibleVaultImportDetails {
                        VaultImportDiagnosticsView(
                            snapshot: details,
                            isActive: vaultSync.vaultImportProgress != nil
                        )
                    }
                    Text("No vault connected. Select a folder to sync your markdown notes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Cached local notes or graph rows may still be visible, but they are disconnected from disk until a vault is selected.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("Select Vault Folder") {
                        VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.resolved.accent.color)
                    .controlSize(.small)
                }
            }

            if vaultSync.vaultURL != nil {
                Section("Search Index") {
                    SettingsDescriptionText(
                        text: "The search index is the fast local lookup database built from your vault. Rebuild it if search feels stale after a large import or recovery."
                    )
                    HStack(spacing: 8) {
                        Button("Rebuild Index") {
                            vaultSync.rebuildIndex()
                        }
                        .disabled(vaultSync.isIndexing)
                        .controlSize(.small)

                        if vaultSync.isIndexing {
                            ProgressView()
                                .controlSize(.small)
                            Text("Rebuilding...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Vault Sync") {
                    SettingsDescriptionText(
                        text: "Auto-save controls how often in-memory note edits are flushed back to markdown files in the connected vault."
                    )
                    Picker(
                        "Auto-save to vault",
                        selection: Binding(
                            get: { autoSaveOption(from: vaultSync.autoSaveInterval) },
                            set: { vaultSync.autoSaveInterval = autoSaveSeconds(from: $0) }
                        )
                    ) {
                        Text("Off").tag(0)
                        Text("Every 5 seconds").tag(5)
                        Text("Every 15 seconds").tag(1)
                        Text("Every 30 seconds").tag(2)
                        Text("Every 60 seconds").tag(3)
                        Text("Every 5 minutes").tag(4)
                    }
                    .pickerStyle(.menu)

                    Text("When enabled, unsaved note changes are automatically written to vault .md files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @MainActor
    private func requestVaultDisconnectAuthorization(vaultURL: URL) async {
        guard !isVaultDisconnectAuthorizationInFlight else { return }
        isVaultDisconnectAuthorizationInFlight = true
        defer { isVaultDisconnectAuthorizationInFlight = false }

        let target = SettingsViewDestructiveActionSovereignGate.Target.vaultDisconnect(name: vaultURL.lastPathComponent)
        let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
            SettingsViewDestructiveActionSovereignGate.requirement(for: target),
            reason: SettingsViewDestructiveActionSovereignGate.reason(for: target)
        ) ?? .denied(.authenticationFailed)

        guard outcome == .allowed else { return }
        guard vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL else { return }

        VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)
    }

    private func autoSaveOption(from interval: TimeInterval) -> Int {
        switch interval {
        case 5: return 5
        case 15: return 1
        case 30: return 2
        case 60: return 3
        case 300: return 4
        default: return 0
        }
    }

    private func autoSaveSeconds(from option: Int) -> TimeInterval {
        switch option {
        case 5: return 5
        case 1: return 15
        case 2: return 30
        case 3: return 60
        case 4: return 300
        default: return 0
        }
    }
}

private struct VaultImportDiagnosticsView: View {
    let snapshot: VaultImportProgressSnapshot
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: isActive ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                    .foregroundStyle(isActive ? .orange : .green)
                Text(isActive ? snapshot.compactStatusMessage : snapshot.primarySummary)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
            }

            if let fraction = snapshot.progressFraction, isActive {
                ProgressView(value: fraction)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.inventorySummary)
                Text("Import result: \(snapshot.mutationSummary)")
                Text("Diagnostics: \(snapshot.issueSummary); \(snapshot.nonVaultPageCount) local-only/non-vault notes; \(snapshot.duplicateFileNameCount) duplicate file names on disk.")
                if !snapshot.topFileTypes().isEmpty {
                    Text("Imported file types: \(formatCounts(snapshot.topFileTypes()))")
                }
                if !snapshot.topUnsupportedFileTypes().isEmpty {
                    Text("Unsupported file types excluded: \(formatCounts(snapshot.topUnsupportedFileTypes()))")
                }
                if !snapshot.topSkippedPolicyReasons().isEmpty {
                    Text("Skipped folders/packages: \(formatCounts(snapshot.topSkippedPolicyReasons()))")
                }
                Text("Hidden files and package descendants are skipped by the system enumerator before import.")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    private func formatCounts(_ pairs: [(String, Int)]) -> String {
        pairs.map { "\($0.0) \($0.1)" }.joined(separator: ", ")
    }
}
