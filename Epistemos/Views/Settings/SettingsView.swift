import AppKit
import AVFoundation
import os
import SwiftUI
import UniformTypeIdentifiers

private let settingsViewLogger = Logger(subsystem: "Epistemos", category: "SettingsView")

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
    @State private var selection: SettingsSection? = .general
    /// Single source of truth for the Authority & Installs panel in this
    /// settings window. Owned here so the store survives view redraws while
    /// the user navigates between sidebar rows. Uses the file-backed
    /// persistence so user allow/ask/deny decisions survive a relaunch —
    /// prior to 2026-04-19 this defaulted to in-memory and silently
    /// dropped the user's settings on quit.
    @State private var sharedAuthorityStore: AgentAuthorityStore

    init(authorityStore: AgentAuthorityStore? = nil) {
        let resolvedStore = authorityStore
            ?? AppBootstrap.shared?.agentAuthorityStore
            ?? AgentAuthorityStore(persistence: FileBackedAgentAuthorityPersistence())
        _sharedAuthorityStore = State(initialValue: resolvedStore)
    }

    // MARK: - Settings Categories (Phase 7 Step 7)
    //
    // Phase 7 simplifies the sidebar from 12 flat sections into 6 calm
    // categories. The underlying `SettingsSection` enum is unchanged so
    // every existing detail view stays reachable — only the sidebar
    // grouping and row subtitles are new. Each section declares its
    // `category` and a `description` sentence that appears as a caption
    // under the sidebar label.

    enum SettingsCategory: String, CaseIterable, Identifiable {
        case capture      = "Capture"
        case models       = "Models"
        case graph        = "Graph"
        case automation   = "Automation"
        case privacyStore = "Privacy & Storage"
        case advanced     = "Advanced"

        var id: String { rawValue }

        /// Display order in the sidebar, top to bottom.
        static var orderedCases: [SettingsCategory] {
            var categories: [SettingsCategory] = [
                .capture,
                .models,
                .graph,
            ]
            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            categories.append(.automation)
            #endif
            categories += [
                .privacyStore,
                .advanced,
            ]
            return categories
        }
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case ambientFrequencies = "Ambient Frequencies"
        case channels = "Channels"
        case cognitive = "Cognitive"
        case inference = "Inference"
        case knowledgeFusion = "Knowledge Fusion (Experimental)"
        case modelVaults = "Model Vaults"
        case iMessageDriver = "iMessage Driver"
        case skills = "Skills"
        /// Consolidated agent surface. Hosts Agent Control + Authority +
        /// Overseer as sub-tabs inside a single detail view.
        case agent = "Agent"
        /// Retained for direct-deep-link paths (e.g., notifications that
        /// opened Agent Control before consolidation). Not visible in the
        /// sidebar. Renders the same AgentSectionDetailView.
        case agentControl = "Agent Control (legacy)"
        case authority = "Authority & Installs (legacy)"
        case overseer = "Overseer (legacy)"
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
        // HELIOS research scaffold. Preserved for source guards and
        // deep-link compatibility, but not listed in v1 visible settings:
        // HELIOS is frozen as research/doctrine/guardrails until its WRV
        // gates are actually satisfied.
        case heliosV5 = "HELIOS V5"

        var id: String { rawValue }

        /// Sidebar-visible sections. The three legacy agent entries
        /// (agentControl, authority, overseer) roll up under .agent and
        /// are hidden from the sidebar to reduce nav clutter.
        static var visibleSections: [SettingsSection] {
            var sections: [SettingsSection] = [
                .general,
                .ambientFrequencies,
            ]
            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            sections.append(.channels)
            #endif
            sections += [
                .cognitive,
                .inference,
            ]
            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            sections.append(.knowledgeFusion)
            #endif
            sections.append(.modelVaults)
            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            sections += [
                .iMessageDriver,
                .skills,
            ]
            #endif
            sections += [
                .agent,
                .landing,
                .appearance,
                .vault,
                .privacy,
                .provenance,
            ]
            return sections
        }

        static func safeDetailSelection(for section: SettingsSection?) -> SettingsSection? {
            #if EPISTEMOS_APP_STORE || MAS_SANDBOX
            switch section {
            case .channels, .knowledgeFusion, .iMessageDriver, .skills:
                return .general
            case .agent, .agentControl, .authority, .overseer:
                return .authority
            default:
                return section
            }
            #else
            return section
            #endif
        }

        var icon: String {
            switch self {
            case .general: "gearshape"
            case .ambientFrequencies: "waveform.path"
            case .channels: "point.3.connected.trianglepath.dotted"
            case .cognitive: "brain"
            case .inference: "cpu"
            case .knowledgeFusion: "brain.head.profile.fill"
            case .modelVaults: "tray.2.fill"
            case .iMessageDriver: "message.badge.fill"
            case .skills: "shippingbox.fill"
            case .agent: "cpu.fill"
            case .agentControl: "slider.horizontal.3"
            case .authority: "checkmark.shield.fill"
            case .overseer: "brain.head.profile"
            case .landing: "sparkles.rectangle.stack"
            case .appearance: "paintpalette"
            case .vault: "folder"
            case .privacy: "hand.raised.fill"
            case .provenance: "list.bullet.rectangle.portrait"
            case .heliosV5: "sparkles"
            }
        }

        /// Which simplified Phase 7 category this section belongs under.
        var category: SettingsCategory {
            switch self {
            case .landing,
                 .ambientFrequencies: .capture
            case .cognitive,
                 .inference,
                 .modelVaults,
                 .knowledgeFusion: .models
            case .appearance:     .graph
            case .agent:
                #if EPISTEMOS_APP_STORE || MAS_SANDBOX
                .advanced
                #else
                .automation
                #endif
            case .channels,
                 .iMessageDriver,
                 .skills,
                 .agentControl,
                 .authority,
                 .overseer:       .automation
            case .vault:          .privacyStore
            case .privacy:        .privacyStore
            case .provenance:     .privacyStore
            case .general:        .advanced
            case .heliosV5:       .advanced
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
            case .channels:
                "Outbound routing: Slack, webhooks, Matrix, email, SMS."
            case .cognitive:
                "Reasoning profile, local/cloud routing, temperature."
            case .inference:
                "Runtime preferences and model selection across lanes."
            case .knowledgeFusion:
                "Experimental: ingest, adapters, training, feedback."
            case .modelVaults:
                "Per-model vault isolation and active model profiles."
            case .iMessageDriver:
                "Route a trusted iMessage contact to the local agent."
            case .skills:
                "Installed skills, activation rules, and manifests."
            case .agent:
                "Tools, permissions, and routing — one place for everything agent-related."
            case .agentControl:
                "Agent tool permissions, limits, and approval tiers."
            case .authority:
                "What the agent can do without asking you first."
            case .overseer:
                "Read-only audit trail of the routing + mask decisions the Overseer makes per turn."
            case .landing:
                "Greeting, quick capture, and landing canvas behavior."
            case .appearance:
                "Theme, graph visuals, physics presets, display mode."
            case .vault:
                "Vault path, sync service, and retrieval indexes."
            case .privacy:
                "What stays on this Mac, what leaves it, and the App Privacy fields."
            case .provenance:
                "Read-only audit trail for agent, graph, and mutation projections."
            case .heliosV5:
                "Research-only HELIOS scaffold; v1 runtime controls are deferred."
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsCategory.orderedCases) { category in
                    let sections = SettingsSection.visibleSections
                        .filter { $0.category == category }
                    if !sections.isEmpty {
                        Section(category.rawValue) {
                            ForEach(sections) { section in
                                SettingsSidebarRow(section: section)
                                    .tag(section)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background {
                SettingsSidebarBackdrop(theme: ui.theme)
                    .ignoresSafeArea()
            }
            .navigationSplitViewColumnWidth(min: 196, ideal: 212, max: 260)
        } detail: {
            settingsDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(SettingsDetailBackdrop(theme: ui.theme))
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onReceive(NotificationCenter.default.publisher(for: .showIMessageDriverSettings)) { _ in
            #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
            selection = .iMessageDriver
            #endif
        }
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

    @ViewBuilder
    private var settingsDetail: some View {
        switch SettingsSection.safeDetailSelection(for: selection) {
        case .heliosV5: HELIOSv5SettingsView()
        case .general: GeneralDetailView()
        case .ambientFrequencies: AmbientFrequencySettingsView()
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        case .channels, .knowledgeFusion, .iMessageDriver, .skills:
            GeneralDetailView()
        #else
        case .channels: ChannelsDetailView()
        #endif
        case .cognitive: CognitiveSettingsSection()
        case .inference: InferenceDetailView()
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .knowledgeFusion: KnowledgeFusionDetailView()
        #endif
        case .modelVaults: ModelVaultsSettingsView()
        #if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
        case .iMessageDriver: iMessageDriverDetailView()
        case .skills: SkillsDetailView()
        #endif
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        case .agent, .agentControl, .authority, .overseer:
            AuthoritySettingsView(store: sharedAuthorityStore)
        #else
        case .agent:
            AgentSectionDetailView(authorityStore: sharedAuthorityStore)
        case .agentControl:
            AgentSectionDetailView(authorityStore: sharedAuthorityStore, initialTab: .control)
        case .authority:
            AgentSectionDetailView(authorityStore: sharedAuthorityStore, initialTab: .authority)
        case .overseer:
            AgentSectionDetailView(authorityStore: sharedAuthorityStore, initialTab: .overseer)
        #endif
        case .landing: LandingDetailView()
        case .appearance: AppearanceDetailView()
        case .vault: VaultDetailView()
        case .privacy: PrivacyDetailView()
        case .provenance: ProvenanceConsoleView()
        case nil: GeneralDetailView()
        }
    }

    private func toggleSidebar() {
        NSApp.sendAction(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            to: nil,
            from: nil
        )
    }
}

private struct SettingsSidebarRow: View {
    let section: SettingsView.SettingsSection

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: section.icon)
                .frame(width: 18, alignment: .center)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.rawValue)
                    .font(.footnote.weight(.medium))
                Text(section.rowDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct SettingsSidebarBackdrop: View {
    let theme: EpistemosTheme

    var body: some View {
        Rectangle()
            .fill(theme.card.opacity(theme.isDark ? 0.92 : 0.97))
            .overlay {
                if theme.usesNativeWindowBlur {
                    Rectangle()
                        .fill(.white.opacity(0.001))
                        .glassEffect(.regular.interactive(), in: Rectangle())
                }
            }
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
        Rectangle()
            .fill(theme.resolved.background.color.opacity(theme.isDark ? 0.94 : 0.985))
            .overlay {
                if theme.usesNativeWindowBlur {
                    Rectangle()
                        .fill(.white.opacity(0.001))
                        .glassEffect(.regular.interactive(), in: Rectangle())
                }
            }
            .ignoresSafeArea()
    }
}

extension Notification.Name {
    static let showIMessageDriverSettings = Notification.Name("epistemos.showIMessageDriverSettings")
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
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                SettingsDescriptionText(text: text)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        let raw = UserDefaults.standard.string(forKey: "epistemos.summaryInterval") ?? "15m"
        return WorkspaceSummaryService.SummaryInterval(rawValue: raw) ?? .fifteenMinutes
    }()
    @State private var workspaces: [SDWorkspace] = []
    @State private var renamingWorkspace: SDWorkspace?
    @State private var renameText = ""
    @State private var showResetAlert = false

    var body: some View {
        Form {
            Section("Power") {
                SettingsDescriptionText(
                    text: "Eco Mode disables background services (NightBrain, agent heartbeat, screen capture, vault maintenance timers, health checks) to save battery. Low Power Mode adds a 60fps render cap and is activated automatically by the system."
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
                    text: "Workspace summaries are short on-device recaps of recent notes, chats, and work context so you can resume without reloading everything mentally."
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
                LabeledContent("Local models") {
                    Text("Stored in Application Support")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                LabeledContent("Apple Intelligence") {
                    Text("On-device only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Sandbox") {
                    Text("Enabled")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section("Performance") {
                SettingsDescriptionText(
                    text: "Tune how aggressively the app warms on launch and how much memory it holds when idle. Default is Instant Launch + Keep Warm — fastest open, but ~1–2 GB resident. Switch to Prepared Launch if cold open feels chaotic, or Low Memory if you want the app to shed graph/MLX/search state after 30 seconds of no interaction."
                )
                PerformanceSettingsSection()
            }
            // 2026-05-20 UX fix: graph performance moved to Settings → Graph
            // (AppearanceDetailView) where users naturally look for graph settings.

            Section("Diagnostics") {
                SettingsDescriptionText(
                    text: "Read-only health probes for the local stack. Runtime truth shows the single source-of-truth answer to “what's actually running right now?” — mode + provider + tool-loop + capability tier. Editor bundle confirms the Tiptap WKWebView assets ship with the app; Shadow Search shows live Halo backend health and degraded failure classes without exposing backend details; Background Indexing shows the current vault crawl; Process Memory reports resident footprint and pressure state without claiming allocation root cause; Shared Arena reports the app-group arena path and bridge budgets without claiming runtime authority; Agent Events reports durable tool provenance visibility; Search Fusion shows live latency + per-source hit distribution for the cross-index RRF query; Cognitive DAG reports node/edge counts + content-hash root; AnswerPacket reports the V6.2 audit channel — every chat-turn emits a packet with attention mode + interrupt-score bucket, surfaced here as live counts + per-mode + per-bucket histograms."
                )
                // RCA-P1-004 + RCA-P1-005 + RCA-P1-017 + RCA13-P1-002
                // (2026-05-13): canonical "what is running now" row.
                // Placed first because every other diagnostic answers a
                // narrower question; this one is the single map between
                // mode/provider/tool-loop the user actually needs to
                // reason about every turn.
                RuntimeTruthHealthRow()
                EditorBundleHealthRow()
                ShadowSearchHealthRow()
                BackgroundIndexingHealthRow()
                ProcessMemoryHealthRow()
                ArenaHealthRow()
                OpLogProjectionHealthRow()
                AgentEventVisibilityRow()
                GraphEventVisibilityRow()
                SearchFusionHealthRow()
                CognitiveDagHealthRow()
                // V6.2 first-rendered surface for the AnswerPacket
                // audit channel. Read-only window onto the bounded
                // ring buffer in `AnswerPacketEmitter.shared` — counts,
                // ring depth, latest packet's attention_mode +
                // interruptBucket + uiLabel + last-emit age. Refresh
                // is event-driven via `didEmitNotification`. Per
                // docs/audits/V6_2_LAPTOP_MANUAL_AUDIT_CHECKLIST_2026_05_07.md.
                AnswerPacketHealthRow()
                // ISSUE-2026-05-10-002 follow-up: per-provider cloud
                // access visibility. Read-only, never displays credential values.
                // Helps users diagnose "agents don't work" by showing
                // at a glance which providers have account/API-key access.
                APIKeysHealthRow()
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
                Text("Clear all saved data, conversations, local model state, and settings. Vault files on disk are preserved.")
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
            Text("This will delete all conversations, notes data, local model state, and model preferences. Vault files on disk and appearance settings are preserved. This cannot be undone.")
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
                    text: "Quick Capture is the app-scoped capture sheet for fast text or voice intake. Open it with ⌘⇧N, or launch it below and use the Dictate button inside the sheet. Siri and Shortcuts use the same App Intents integration."
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

// MARK: - Inference Detail

private struct InferenceDetailView: View {
    @Environment(UIState.self) private var ui
    @Environment(InferenceState.self) private var inference
    @Environment(LocalModelManager.self) private var localModelManager

    @AppStorage("epistemos.inferenceAdvancedSettingsEnabled") private var showsAdvancedSettings = false

    @State private var showLocalModelManager = false
    @State private var tokenCapEnabled = false
    @State private var tokenCapDraft: Int = 2000
    @State private var cloudAPIKeyDrafts: [CloudModelProvider: String] = [:]
    @State private var firecrawlKey = ""
    @State private var showCloudSetupHint = false
    @State private var googleOAuthProjectID = ""
    @State private var googleOAuthClientConfigData: Data?
    @State private var googleOAuthClientFilename = ""
    @State private var googleOAuthClientStatusMessage: String?
    @State private var googleOAuthClientStatusIsSuccess = false
    @State private var accountActionInFlightProvider: CloudModelProvider?
    @State private var openAIDeviceAuthorization: OpenAIDeviceAuthorization?
    @State private var providerNativeReasoningPreviewModes: [CloudModelProvider: EpistemosOperatingMode] = [:]
    @State private var showSettingsModeHint = false
    @State private var showRoutingHint = false
    @State private var showLocalAIHint = false
    @State private var showOtherCloudProvidersHint = false
    @State private var showResponseTokensHint = false

    private var theme: EpistemosTheme { ui.theme }
    private var activeLocalModelDisplayName: String {
        return inference.activeLocalTextModelDisplayName
    }
    private var activeCloudWorkspaceProvider: CloudModelProvider {
        if let activeProvider = inference.activeCloudProvider,
           CloudModelProvider.preferredOrder.contains(activeProvider) {
            return activeProvider
        }
        return inference.preferredAutoRouteCloudProvider ?? .openAI
    }
    private var otherCloudProviders: [CloudModelProvider] {
        CloudModelProvider.preferredOrder.filter { $0 != activeCloudWorkspaceProvider }
    }
    private var releaseSelectableLocalDescriptors: [LocalModelDescriptor] {
        let selectableIDs = Set(inference.releaseSelectableInstalledLocalTextModelIDs)
        return localModelManager.textDescriptors.filter { selectableIDs.contains($0.id) }
    }
    private var cloudModelsEnabledBinding: Binding<Bool> {
        Binding(
            get: { inference.cloudModelsEnabled },
            set: { inference.setCloudModelsEnabled($0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Settings Mode", selection: $showsAdvancedSettings) {
                    Text("Regular").tag(false)
                    Text("Advanced").tag(true)
                }
                .pickerStyle(.segmented)

                SettingsDescriptionText(
                    text: showsAdvancedSettings
                        ? "Advanced exposes legacy credential editors, provider diagnostics, and extra runtime utilities."
                        : "Regular keeps routing, local models, and the active cloud workspace focused on the essentials."
                )
            } header: {
                SettingsHelpHeader(title: "Settings Mode", isPresented: $showSettingsModeHint) {
                    CloudHintPopover(
                        title: "Regular vs Advanced",
                        bulletPoints: [
                            "Regular keeps the main routing, local model, and active cloud controls visible.",
                            "Advanced reveals legacy API key editors, provider verification tools, and utility keys.",
                            "You can switch modes any time without changing your saved providers or models.",
                        ],
                        footnote: "Use Advanced when you need deeper setup or recovery controls.",
                        onRemindLater: { showSettingsModeHint = false },
                        onGotIt: { showSettingsModeHint = false }
                    )
                }
            }

            Section {
                SettingsDescriptionText(
                    text: "Routing decides which local path handles each request. The prepared or installed local runtime stays primary, while Apple Intelligence remains an optional explicit fallback when you want it."
                )
                Picker(
                    "Routing Mode",
                    selection: Binding(
                        get: { inference.routingMode },
                        set: { inference.setRoutingMode($0) }
                    )
                ) {
                    ForEach(LocalRoutingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(inference.routingMode.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    inference.refreshAppleIntelligenceAvailability()
                } label: {
                    Label("Check Apple Intelligence", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)

                if inference.appleIntelligenceAvailable {
                    Label(
                        "Apple Intelligence available as an optional on-device fallback",
                        systemImage: "apple.intelligence"
                    )
                    .font(.caption)
                    .foregroundStyle(theme.success)
                } else if let reason = inference.appleIntelligenceUnavailableReason, !reason.isEmpty {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.warning)
                }
            } header: {
                SettingsHelpHeader(title: "Routing", isPresented: $showRoutingHint) {
                    CloudHintPopover(
                        title: "Routing",
                        bulletPoints: [
                            "Auto keeps the prepared or installed local runtime primary for normal chat and generation work.",
                            "Apple Intelligence still appears as an explicit choice when it is available on this Mac.",
                            "Local Only bypasses Apple Intelligence and keeps every request on your prepared or installed local runtime.",
                            "Cloud enablement is separate and lives below in the cloud workspace controls.",
                        ],
                        footnote: "Routing changes the local path first; cloud can still be disabled entirely.",
                        onRemindLater: { showRoutingHint = false },
                        onGotIt: { showRoutingHint = false }
                    )
                }
            }

            Section {
                Toggle(isOn: Binding(
                    get: { inference.cloudAutoFallback },
                    set: { inference.setCloudAutoFallback($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-route on failure")
                        Text("When off, cloud requests use only the selected model and show errors instead of falling back to other models silently.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Cloud Routing")
            }

            Section {
                SettingsDescriptionText(
                    text: "Sets how much reasoning / thinking the model does per turn. Applies to OpenAI reasoning models, Anthropic adaptive thinking, and Gemini 2.5 / 3.x thinking modes. Non-reasoning models ignore this setting. Provider-native runtimes can expose a fuller ladder in Pro / Tools too, like Codex Extra High or Claude Code Max."
                )
                Picker(
                    selection: Binding(
                        get: { inference.chatReasoningTier },
                        set: { inference.setChatReasoningTier($0) }
                    )
                ) {
                    // Full taxonomy lives at the Settings level; per-
                    // mode composer pickers filter down via
                    // `EpistemosOperatingMode.availableReasoningTiers`.
                    ForEach(ChatReasoningTier.allCases, id: \.self) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                } label: {
                    Text("Reasoning")
                }
                .pickerStyle(.menu)

                SettingsDescriptionText(text: inference.chatReasoningTier.summary)
            } header: {
                Text("Reasoning")
            }

            Section {
                SettingsDescriptionText(
                    text: "Local AI manages the on-device models installed on this Mac, shows the active local tier, and lets you choose which local runtime the chat surfaces should prefer."
                )
                LabeledContent("Hardware") {
                    Text(localModelManager.hardwareSummary)
                        .font(.system(.caption, design: .monospaced))
                }
                LabeledContent("Availability") {
                    Text(inference.localModelInstallStateSummary.displayName)
                        .font(.caption.weight(.medium))
                }
                LabeledContent("Runtime Status") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(inference.localRuntimeStatusSummary)
                            .font(.caption.weight(.medium))
                        if let detail = inference.localRuntimeStatusDetail {
                            Text(detail)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let lastRunSummary = inference.localRuntimeLastRunSummary {
                    LabeledContent("Last Local Run") {
                        Text(lastRunSummary)
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
                LabeledContent("Storage") {
                    Text(ByteCountFormatter.string(fromByteCount: localModelManager.totalInstalledStorageBytes, countStyle: .file))
                        .font(.system(.caption, design: .monospaced))
                }

                Picker(
                    "Active Local Model",
                    selection: Binding(
                        get: { inference.activeLocalTextModelID ?? inference.preferredLocalTextModelID },
                        set: { inference.setPreferredLocalTextModelID($0) }
                    )
                ) {
                    ForEach(releaseSelectableLocalDescriptors, id: \.id) { descriptor in
                        Text(inference.localModelPickerDisplayName(for: descriptor.id)).tag(descriptor.id)
                    }
                }
                .disabled(releaseSelectableLocalDescriptors.isEmpty)

                if releaseSelectableLocalDescriptors.isEmpty {
                    SettingsDescriptionText(
                        text: inference.releaseHiddenInstalledLocalTextModelCount > 0
                            ? "Installed local models that are not release-ready yet are hidden from the release picker. Use Manage Local Models to review them."
                            : "Install a release-validated local model to enable an on-device fallback here."
                    )
                }

                if let fallback = localModelManager.missingConstrainedFallbackDescriptor {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Install \(fallback.displayName) as a lighter fallback for constrained conditions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Install Constrained Fallback") {
                            Task {
                                do {
                                    try await localModelManager.install(modelID: fallback.id)
                                } catch {
                                    settingsViewLogger.error("Failed to install constrained fallback model \(fallback.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Button("Manage Local Models") {
                    showLocalModelManager = true
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.resolved.accent.color)
                .controlSize(.small)
            } header: {
                SettingsHelpHeader(title: "Local AI", isPresented: $showLocalAIHint) {
                    CloudHintPopover(
                        title: "Local AI",
                        bulletPoints: [
                            "Your active local model is the on-device fallback and the full local-only path.",
                            "Manage Local Models opens installs, deletes, and constrained fallback options.",
                            "Cloud controls never remove local-only mode.",
                        ],
                        footnote: "If you turn cloud models off, these local settings stay in charge.",
                        onRemindLater: { showLocalAIHint = false },
                        onGotIt: { showLocalAIHint = false }
                    )
                }
            }

            Section {
                Toggle("Enable Cloud Models", isOn: cloudModelsEnabledBinding)

                SettingsDescriptionText(
                    text: inference.cloudModelsEnabled
                        ? "OpenAI is the default cloud workspace for chat and coding. Switch providers any time while keeping Local Only available."
                        : "Cloud models are hidden. Epistemos stays local-only until you turn cloud models back on."
                )

                if inference.cloudModelsEnabled {
                    activeCloudWorkspace
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        CloudProviderGuidanceRow(
                            text: "Cloud models are currently disabled, so chat and coding stay on-device until you re-enable cloud models.",
                            theme: theme,
                            systemImage: "memorychip.fill",
                            tint: theme.resolved.accent.color
                        )

                        Button("Re-enable OpenAI Cloud") {
                            inference.setCloudModelsEnabled(true)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                SettingsHelpHeader(title: "Active Cloud", isPresented: $showCloudSetupHint) {
                    cloudSetupHintPopover
                }
            }

            if inference.cloudModelsEnabled {
                Section("Cloud Access Health") {
                    SettingsDescriptionText(
                        text: "Read-only credential status. This tells you whether Epistemos can see a saved account session or manual API key for each provider, without exposing the key value."
                    )
                    ForEach(CloudModelProvider.preferredOrder, id: \.rawValue) { provider in
                        CloudProviderAccessHealthRow(
                            provider: provider,
                            hasAPIKey: inference.apiKey(for: provider) != nil,
                            hasOAuthSession: inference.oauthCredential(for: provider) != nil,
                            validationState: inference.cloudValidationState(for: provider),
                            isActive: inference.activeAIProvider == AIProviderSelection(cloudProvider: provider),
                            theme: theme
                        )
                    }
                }
            }

            if inference.cloudModelsEnabled {
                Section {
                    ForEach(otherCloudProviders, id: \.rawValue) { provider in
                        otherCloudProviderRow(provider: provider)
                    }
                } header: {
                    SettingsHelpHeader(title: "Other Cloud Providers", isPresented: $showOtherCloudProvidersHint) {
                        CloudHintPopover(
                            title: "Other Cloud Providers",
                            bulletPoints: [
                                "This section stays condensed so the active provider gets the larger workspace.",
                                "Choose Open Setup to focus the main workspace on another provider.",
                                "Make Active promotes a configured provider without reopening the rest of settings.",
                            ],
                            footnote: "Use Advanced mode if you want the manual credential path visible while switching providers.",
                            onRemindLater: { showOtherCloudProvidersHint = false },
                            onGotIt: { showOtherCloudProvidersHint = false }
                        )
                    }
                }
            }

            if showsAdvancedSettings {
                Section("Research Tools") {
                    firecrawlKeyRow
                }
            }

            if showsAdvancedSettings {
                Section {
                    SettingsDescriptionText(
                        text: "Use a response cap when you want shorter answers, lower token usage, or a tighter guardrail for long generations."
                    )
                    LabeledContent("Cap") {
                        HStack(spacing: 8) {
                            Toggle("", isOn: $tokenCapEnabled)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            Text(tokenCapEnabled ? "\(tokenCapDraft)" : "Unlimited")
                                .font(.caption)
                                .foregroundStyle(tokenCapEnabled ? .primary : .secondary)
                            if tokenCapEnabled {
                                Stepper("", value: $tokenCapDraft, in: 500...32000, step: 500)
                                    .labelsHidden()
                            }
                        }
                    }
                    .onChange(of: tokenCapEnabled) { _, enabled in
                        inference.setChatOutputTokens(enabled ? tokenCapDraft : 0)
                    }
                    .onChange(of: tokenCapDraft) { _, value in
                        if tokenCapEnabled { inference.setChatOutputTokens(value) }
                    }
                } header: {
                    SettingsHelpHeader(title: "Response Tokens", isPresented: $showResponseTokensHint) {
                        CloudHintPopover(
                            title: "Response Tokens",
                            bulletPoints: [
                                "Use a cap when you want shorter cloud or local answers.",
                                "Leave it unlimited to let the active model decide its normal response size.",
                                "This is an advanced guardrail, not a required setup step.",
                            ],
                            footnote: nil,
                            onRemindLater: { showResponseTokensHint = false },
                            onGotIt: { showResponseTokensHint = false }
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            Task { @MainActor in
                let saved = inference.chatOutputTokens
                tokenCapEnabled = saved > 0
                if saved > 0 { tokenCapDraft = saved }
                loadCloudAPIKeyDrafts()
                googleOAuthClientConfigData = CloudProviderSetupAutomation.loadGoogleOAuthClientConfigData()
                googleOAuthClientFilename = CloudProviderSetupAutomation.loadGoogleOAuthClientFilename()
                googleOAuthProjectID = inference.oauthCredential(for: .google)?.projectID
                    ?? CloudProviderSetupAutomation.loadGoogleOAuthProjectIDDraft()
                firecrawlKey = inference.firecrawlAPIKey() ?? ""
                showCloudSetupHint = inference.shouldShowCloudSetupHint
            }
        }
        .onChange(of: googleOAuthProjectID) { _, newValue in
            CloudProviderSetupAutomation.persistGoogleOAuthProjectIDDraft(newValue)
        }
        .sheet(isPresented: $showLocalModelManager) {
            LocalModelManagerSheet()
                .frame(minWidth: 620, minHeight: 480)
        }
        .sheet(item: $openAIDeviceAuthorization) { authorization in
            OpenAIDeviceAuthorizationSheet(
                authorization: authorization,
                onDismiss: { openAIDeviceAuthorization = nil }
            )
        }
    }

    private var activeCloudWorkspace: some View {
        VStack(alignment: .leading, spacing: 12) {
            cloudProviderAccessRow(provider: activeCloudWorkspaceProvider)

            if inference.hasConfiguredCloudAccess(for: activeCloudWorkspaceProvider) {
                Picker(
                    "Cloud Model",
                    selection: activeCloudModelBinding(for: activeCloudWorkspaceProvider)
                ) {
                    ForEach(inference.cloudModels(for: activeCloudWorkspaceProvider), id: \.rawValue) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)

                SettingsDescriptionText(
                    text: "\(activeCloudWorkspaceProvider.displayName) model choices stay here so chat and coding follow one focused cloud workspace at a time."
                )
            } else {
                CloudProviderGuidanceRow(
                    text: "Finish setup and run a live access check before activating a \(activeCloudWorkspaceProvider.displayName) cloud model.",
                    theme: theme
                )
            }

            if inference.activeAIProvider != .localOnly {
                providerNativeControls
            }
        }
        .padding(.vertical, 4)
    }

    private func otherCloudProviderRow(
        provider: CloudModelProvider
    ) -> some View {
        let validationState = inference.cloudValidationState(for: provider)
        let hasConfiguredAccess = inference.hasConfiguredCloudAccess(for: provider)
        let canPromoteToActive = hasConfiguredAccess && validationState.isVerified
        let isActionInFlight = accountActionInFlightProvider == provider

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label(provider.displayName, systemImage: provider.systemImage)
                    .font(.body.weight(.semibold))
                if provider == .openAI {
                    Text("OpenAI Recommended")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.resolved.accent.color.opacity(0.12), in: Capsule())
                        .foregroundStyle(theme.resolved.accent.color)
                }
                Spacer()
                statusBadge(for: provider)
            }

            SettingsDescriptionText(text: provider.accountSetupHelpText)

            HStack(spacing: 6) {
                if canPromoteToActive {
                    Button("Make Active") {
                        inference.setCloudModelsEnabled(true)
                        inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    Button("Open Setup") {
                        inference.setCloudModelsEnabled(true)
                        inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if showsAdvancedSettings, hasConfiguredAccess {
                    Button(validationState.isVerified ? "Re-check Access" : "Check Access") {
                        Task { _ = await inference.validateCloudAccess(for: provider) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(validationState.isChecking || isActionInFlight)
                }

                if showsAdvancedSettings, let url = provider.documentationURL {
                    Button(provider.documentationActionTitle) {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Text("Available models: \(provider.modelSummary)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if hasConfiguredAccess {
                providerNativeControls(for: provider)
            }
        }
        .padding(.vertical, 4)
    }

    private func activeCloudModelBinding(
        for provider: CloudModelProvider
    ) -> Binding<CloudTextModelID> {
        Binding(
            get: {
                if case .cloud(let model) = inference.preferredChatModelSelection,
                   model.provider == provider {
                    return model
                }
                return inference.preferredCloudModel(for: provider)
            },
            set: { model in
                inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
                inference.setPreferredCloudModel(model)
            }
        )
    }

    private func dismissCloudSetupHintPermanently() {
        inference.markCloudSetupHintShown()
        showCloudSetupHint = false
    }

    private func cloudProviderAccessRow(
        provider: CloudModelProvider
    ) -> some View {
        let text = cloudAPIKeyDraftBinding(for: provider)
        let validationState = inference.cloudValidationState(for: provider)
        let oauthCredential = inference.oauthCredential(for: provider)
        let hasOAuthSession = oauthCredential != nil
        let hasSavedAPIKey = normalizedCredentialDraft(inference.apiKey(for: provider) ?? "") != nil
        let accountConnectionSummary = provider.accountConnectionSummary(
            oauthCredential: oauthCredential,
            hasSavedAPIKey: hasSavedAPIKey,
            validationState: validationState
        )
        let isActionInFlight = accountActionInFlightProvider == provider
        let isActiveWorkspace = inference.activeAIProvider == AIProviderSelection(cloudProvider: provider)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label(provider.displayName, systemImage: provider.systemImage)
                    .font(.body.weight(.semibold))
                if provider == .openAI {
                    Text("OpenAI Recommended")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.resolved.accent.color.opacity(0.12), in: Capsule())
                        .foregroundStyle(theme.resolved.accent.color)
                }
                Spacer()
                statusBadge(for: provider)
            }

            SettingsDescriptionText(text: provider.setupHelpText)

            HStack(spacing: 6) {
                primaryAccessButtons(for: provider, isActionInFlight: isActionInFlight)

                if hasOAuthSession || hasSavedAPIKey {
                    Button(validationState.isVerified ? "Re-check Access" : "Check Access") {
                        Task { _ = await inference.validateCloudAccess(for: provider) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(validationState.isChecking || isActionInFlight)
                }

                if showsAdvancedSettings, let url = provider.documentationURL {
                    Button(provider.documentationActionTitle) {
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if !isActiveWorkspace {
                    Button("Make Active") {
                        inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!validationState.isVerified)
                    .help(
                        validationState.isVerified
                            ? "Make this the active cloud provider."
                            : "Verify live access before making this provider active."
                    )
                }
            }

            if provider == .google {
                VStack(alignment: .leading, spacing: 8) {
                    // Quick sign-in button (uses embedded or stored OAuth config)
                    if !hasOAuthSession {
                        let hasConfig = CloudProviderSetupAutomation.storedGoogleOAuthClientConfiguration() != nil
                            || GoogleOAuthClientConfiguration.embeddedDefault != nil

                        if hasConfig {
                            Button(action: { signInWithGoogleQuick() }) {
                                Label("Sign in with Google", systemImage: "person.badge.key")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    // Advanced OAuth setup (project ID + JSON file picker)
                    if showsAdvancedSettings || !hasOAuthSession {
                        DisclosureGroup("Google OAuth Setup") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Google Cloud project ID (not project number)", text: $googleOAuthProjectID)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 220)
                                Text(
                                    googleOAuthClientFilename.isEmpty
                                        ? "Choose the OAuth client JSON you downloaded from Google Cloud Console after creating an OAuth client ID for a Desktop app."
                                        : "OAuth client JSON: \(googleOAuthClientFilename)"
                                )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let googleOAuthClientStatusMessage {
                        CloudProviderGuidanceRow(
                            text: googleOAuthClientStatusMessage,
                            theme: theme,
                            systemImage: googleOAuthClientStatusIsSuccess
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill",
                            tint: googleOAuthClientStatusIsSuccess
                                ? theme.success
                                : theme.warning
                        )
                    }
                }
            }

            if let accountConnectionSummary {
                CloudProviderAccountConnectionRow(
                    summary: accountConnectionSummary,
                    theme: theme,
                    actionTitle: hasOAuthSession ? "Disconnect Account" : nil,
                    action: hasOAuthSession ? {
                        _ = inference.setOAuthCredential(nil, for: provider)
                    } : nil
                )
            }

            if provider.supportsAccountConnection {
                DisclosureGroup("API Key (manual)") {
                    manualCredentialEditor(
                        for: provider,
                        text: text,
                        validationState: validationState,
                        hasOAuthSession: hasOAuthSession
                    )
                }
            } else if !provider.supportsAccountConnection {
                manualCredentialEditor(
                    for: provider,
                    text: text,
                    validationState: validationState,
                    hasOAuthSession: hasOAuthSession
                )
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: validationState.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(for: validationState))
                    .frame(width: 14, height: 14)
                Text(validationState.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let guidanceText = accountGuidanceText(
                for: provider,
                validationState: validationState,
                hasOAuthSession: hasOAuthSession
            ) {
                CloudProviderGuidanceRow(
                    text: guidanceText,
                    theme: theme
                )
            }

            if provider == .openAI, case .invalid = validationState {
                Button("Retry OpenAI Sign In") {
                    Task { await runAccountAction(for: .openAI) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isActionInFlight)
            }

            if provider == .anthropic, case .invalid = validationState {
                Button("Retry Claude Code Import") {
                    Task { await runAccountAction(for: .anthropic) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isActionInFlight)
            }

            if provider == .google, case .invalid = validationState {
                Button("Retry Google OAuth") {
                    Task { await runAccountAction(for: .google) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isActionInFlight)
            }

            Text("Available models: \(provider.modelSummary)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private struct CloudProviderAccessHealthRow: View {
        let provider: CloudModelProvider
        let hasAPIKey: Bool
        let hasOAuthSession: Bool
        let validationState: CloudProviderValidationState
        let isActive: Bool
        let theme: EpistemosTheme

        private var accessLabel: String {
            switch (hasOAuthSession, hasAPIKey) {
            case (true, true):
                return "Account + API key saved"
            case (true, false):
                return "Account session saved"
            case (false, true):
                return "API key saved"
            case (false, false):
                return "No saved access"
            }
        }

        private var accessIcon: String {
            (hasOAuthSession || hasAPIKey) ? "key.fill" : "key.slash"
        }

        private var accessTint: Color {
            if validationState.isVerified {
                return theme.success
            }
            return (hasOAuthSession || hasAPIKey) ? theme.warning : .secondary
        }

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: accessIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accessTint)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .font(.caption.weight(.semibold))
                        if isActive {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.resolved.accent.color.opacity(0.12), in: Capsule())
                                .foregroundStyle(theme.resolved.accent.color)
                        }
                    }

                    Text("\(accessLabel) · \(validationState.statusBadge)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func primaryAccessButtons(
        for provider: CloudModelProvider,
        isActionInFlight: Bool
    ) -> some View {
        switch provider {
        case .openAI:
            Button("Sign In") {
                Task { await runAccountAction(for: .openAI) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isActionInFlight)

            Button("Import Codex CLI") {
                Task { await runAccountAction(for: .openAI, importExistingSession: true) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isActionInFlight)
        case .anthropic:
            Button("Import Claude Code") {
                Task { await runAccountAction(for: .anthropic) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isActionInFlight)
        case .google:
            Button(googleOAuthClientConfigData == nil ? "Choose Google OAuth JSON" : "Replace Google OAuth JSON") {
                chooseGoogleOAuthClientFile()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if googleOAuthClientConfigData != nil {
                Button("Clear Google OAuth JSON") {
                    clearGoogleOAuthClientFile()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button("Connect Google OAuth") {
                Task { await runAccountAction(for: .google) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(
                isActionInFlight
                    || googleOAuthClientConfigData == nil
                    || googleOAuthProjectID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        case .zai, .kimi, .minimax, .deepseek:
            if let url = provider.credentialManagementURL {
                Button(provider.accountActionTitle) {
                    inference.setActiveAIProvider(AIProviderSelection(cloudProvider: provider))
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func manualCredentialEditor(
        for provider: CloudModelProvider,
        text: Binding<String>,
        validationState: CloudProviderValidationState,
        hasOAuthSession: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SecureField(provider.apiKeyPlaceholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)
                Button("Paste Key") {
                    pasteProviderKey(for: provider, fromClipboardInto: text)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Save") {
                    saveProviderKey(text.wrappedValue, for: provider, field: text)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 6) {
                Button("Paste + Save") {
                    Task {
                        await pasteAndSaveProviderKey(fromClipboardInto: text, provider: provider)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button("Check Access") {
                    Task { _ = await inference.validateCloudAccess(for: provider) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(validationState.isChecking || (!hasOAuthSession && (inference.apiKey(for: provider)?.isEmpty ?? true)))
                Button(provider.supportsAccountConnection ? "Clear Legacy Key" : "Clear Key") {
                    text.wrappedValue = ""
                    _ = inference.setAPIKey("", for: provider)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            SettingsDescriptionText(text: provider.automationHintText, tertiary: true)
        }
    }

    private func providerNativeReasoningModes(for model: CloudTextModelID) -> [EpistemosOperatingMode] {
        model.nativeReasoningModes
    }

    private func defaultProviderNativeReasoningMode(for model: CloudTextModelID) -> EpistemosOperatingMode {
        let modes = providerNativeReasoningModes(for: model)
        if modes.contains(.thinking) {
            return .thinking
        }
        if modes.contains(.pro) {
            return .pro
        }
        return modes.first ?? .fast
    }

    private func providerNativeReasoningMode(for model: CloudTextModelID) -> EpistemosOperatingMode {
        let modes = providerNativeReasoningModes(for: model)
        guard !modes.isEmpty else { return .fast }
        let stored = providerNativeReasoningPreviewModes[model.provider]
            ?? defaultProviderNativeReasoningMode(for: model)
        return modes.contains(stored) ? stored : defaultProviderNativeReasoningMode(for: model)
    }

    private func providerNativeReasoningModeBinding(
        for model: CloudTextModelID
    ) -> Binding<EpistemosOperatingMode> {
        Binding(
            get: { providerNativeReasoningMode(for: model) },
            set: { mode in
                providerNativeReasoningPreviewModes[model.provider] = mode
                inference.setChatReasoningTier(
                    model.sanitizedReasoningTier(inference.chatReasoningTier, for: mode)
                )
            }
        )
    }

    private func providerNativeReasoningTierBinding(
        for model: CloudTextModelID
    ) -> Binding<ChatReasoningTier> {
        Binding(
            get: {
                let mode = providerNativeReasoningMode(for: model)
                return model.sanitizedReasoningTier(inference.chatReasoningTier, for: mode)
            },
            set: { tier in
                let mode = providerNativeReasoningMode(for: model)
                inference.setChatReasoningTier(model.sanitizedReasoningTier(tier, for: mode))
            }
        )
    }

    @ViewBuilder
    private func providerReasoningEffortControls(
        for model: CloudTextModelID,
        description: String
    ) -> some View {
        if model.supportsNativeReasoningEffortControl {
            let modes = providerNativeReasoningModes(for: model)
            let selectedMode = providerNativeReasoningMode(for: model)

            SettingsDescriptionText(text: description)

            if modes.count > 1 {
                Picker(
                    "Reasoning Mode",
                    selection: providerNativeReasoningModeBinding(for: model)
                ) {
                    ForEach(modes, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Picker(
                "Reasoning Effort",
                selection: providerNativeReasoningTierBinding(for: model)
            ) {
                ForEach(model.availableReasoningTiers(for: selectedMode), id: \.self) { tier in
                    Text(model.reasoningTierLabel(for: tier, operatingMode: selectedMode)).tag(tier)
                }
            }
            .pickerStyle(.menu)

            SettingsDescriptionText(
                text: "\(selectedMode.displayName) uses \(model.reasoningTierLabel(for: model.sanitizedReasoningTier(inference.chatReasoningTier, for: selectedMode), operatingMode: selectedMode)) right now."
            )
        }
    }

    @ViewBuilder
    private var providerNativeControls: some View {
        if let provider = inference.activeAIProvider.cloudProvider {
            providerNativeControls(for: provider)
        }
    }

    @ViewBuilder
    private func providerNativeControls(
        for provider: CloudModelProvider
    ) -> some View {
        let model = inference.preferredCloudModel(for: provider)

        switch provider {
        case .openAI:
            VStack(alignment: .leading, spacing: 10) {
                Label("\(inference.runtimeControlTitle(for: .openAI)) Runtime Controls", systemImage: CloudModelProvider.openAI.systemImage)
                    .font(.body.weight(.semibold))
                providerReasoningEffortControls(
                    for: model,
                    description: "OpenAI exposes native reasoning effort on GPT-5.x models. When Epistemos is using the Codex account runtime, Thinking, Pro, and Tools keep the full Low-to-Extra-High ladder on supported models."
                )
                SettingsDescriptionText(
                    text: "Enable built-in OpenAI tools for the selected OpenAI model. These apply to cloud requests sent through the Responses API."
                )
                Toggle(
                    "Enable Web Search",
                    isOn: Binding(
                        get: { inference.openAIWebSearchEnabled },
                        set: { inference.setOpenAIWebSearchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Code Interpreter",
                    isOn: Binding(
                        get: { inference.openAICodeInterpreterEnabled },
                        set: { inference.setOpenAICodeInterpreterEnabled($0) }
                    )
                )
                Divider().padding(.vertical, 2)
                Toggle(
                    "Force JSON output (cross-provider)",
                    isOn: Binding(
                        get: { inference.structuredJSONOutputEnabled },
                        set: { inference.setStructuredJSONOutputEnabled($0) }
                    )
                )
                SettingsDescriptionText(
                    text: "Guarantees valid JSON on every reply. Attaches `text.format: json_object` for OpenAI Responses, `responseMimeType: application/json` for Gemini, and a JSON-only instruction for Anthropic."
                )
            }
            .padding(.vertical, 4)

        case .anthropic:
            VStack(alignment: .leading, spacing: 10) {
                Label("\(inference.runtimeControlTitle(for: .anthropic)) Runtime Controls", systemImage: CloudModelProvider.anthropic.systemImage)
                    .font(.body.weight(.semibold))
                providerReasoningEffortControls(
                    for: model,
                    description: "Anthropic's Claude models use adaptive thinking with provider-native Low, Medium, High, and Max effort levels on supported modes, including Claude Code-backed tools work."
                )
                SettingsDescriptionText(
                    text: "Adaptive Thinking uses Anthropic's native thinking configuration. Server-side tools (web search, web fetch, code execution) run inside Anthropic's sandbox and are billed per use."
                )
                Toggle(
                    "Enable Web Search",
                    isOn: Binding(
                        get: { inference.anthropicWebSearchEnabled },
                        set: { inference.setAnthropicWebSearchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Web Fetch (single URL)",
                    isOn: Binding(
                        get: { inference.anthropicWebFetchEnabled },
                        set: { inference.setAnthropicWebFetchEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Code Execution (Python sandbox)",
                    isOn: Binding(
                        get: { inference.anthropicCodeExecutionEnabled },
                        set: { inference.setAnthropicCodeExecutionEnabled($0) }
                    )
                )
                Toggle(
                    "Enable Adaptive Thinking",
                    isOn: Binding(
                        get: { inference.anthropicAdaptiveThinkingEnabled },
                        set: { inference.setAnthropicAdaptiveThinkingEnabled($0) }
                    )
                )
            }
            .padding(.vertical, 4)

        case .google:
            VStack(alignment: .leading, spacing: 10) {
                Label("Google Runtime Controls", systemImage: CloudModelProvider.google.systemImage)
                    .font(.body.weight(.semibold))
                providerReasoningEffortControls(
                    for: model,
                    description: "Gemini models that expose native thinking let you pick the effort level here. Flash-class models still show grounding even when they stay on faster defaults."
                )
                SettingsDescriptionText(
                    text: "Grounding enables Gemini's Google Search tool so the model can search live web results when it decides that search will improve the answer."
                )
                Toggle(
                    "Enable Grounding with Google Search",
                    isOn: Binding(
                        get: { inference.googleGroundingEnabled },
                        set: { inference.setGoogleGroundingEnabled($0) }
                    )
                )
            }
            .padding(.vertical, 4)

        case .zai, .kimi, .minimax, .deepseek:
            EmptyView()
        }
    }

    private var firecrawlKeyRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label("Firecrawl", systemImage: "flame.fill")
                    .font(.body.weight(.semibold))
                Spacer()
            }

            SettingsDescriptionText(
                text: "Optional web extraction key for deep research tooling."
            )

            HStack(spacing: 6) {
                SecureField("fc-...", text: $firecrawlKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)
                Button("Save") {
                    let didSave = inference.setFirecrawlAPIKey(firecrawlKey)
                    if didSave {
                        firecrawlKey = inference.firecrawlAPIKey() ?? ""
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Clear") {
                    firecrawlKey = ""
                    _ = inference.setFirecrawlAPIKey("")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusBadge(for provider: CloudModelProvider) -> some View {
        let validationState = inference.cloudValidationState(for: provider)

        Label(validationState.statusBadge, systemImage: validationState.systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor(for: validationState).opacity(0.10), in: Capsule())
            .foregroundStyle(statusColor(for: validationState))
    }

    private func statusColor(for validationState: CloudProviderValidationState) -> Color {
        switch validationState.tintColor {
        case .accent:
            theme.resolved.accent.color
        case .secondary:
            .secondary
        case .success:
            theme.success
        case .warning:
            theme.warning
        }
    }

    private func accountGuidanceText(
        for provider: CloudModelProvider,
        validationState: CloudProviderValidationState,
        hasOAuthSession: Bool
    ) -> String? {
        if provider == .google,
           !hasOAuthSession,
           (googleOAuthClientConfigData == nil || normalizedCredentialDraft(googleOAuthProjectID) == nil) {
            return "Choose a Google Desktop OAuth client JSON file and enter a project ID before connecting your account."
        }

        if let providerGuidance = provider.accountGuidanceText(validationState: validationState) {
            return providerGuidance
        }

        if inference.activeAIProvider != AIProviderSelection(cloudProvider: provider),
           !validationState.isVerified {
            return "Verify live access before making this provider active."
        }

        return nil
    }

    private var cloudSetupHintPopover: some View {
        CloudHintPopover(
            title: "Cloud Workspace",
            bulletPoints: [
                "OpenAI is the default cloud workspace for chat and coding in Epistemos.",
                "Turn off Enable Cloud Models any time to stay local-only.",
                "Other providers stay compact until you make one active.",
            ],
            footnote: "Account-first setup stays primary where the provider supports it.",
            onRemindLater: { showCloudSetupHint = false },
            onGotIt: { dismissCloudSetupHintPermanently() }
        )
    }

    private func clipboardKeyCandidate() -> String? {
        CloudProviderSetupAutomation.clipboardKeyCandidate()
    }

    private func pasteProviderKey(
        for provider: CloudModelProvider,
        fromClipboardInto field: Binding<String>
    ) {
        guard let clipboardValue = clipboardKeyCandidate() else {
            _ = inference.recordCloudProviderValidationFailure(
                for: provider,
                message: provider.missingClipboardCredentialMessage
            )
            return
        }
        field.wrappedValue = clipboardValue
    }

    private func pasteAndSaveProviderKey(
        fromClipboardInto field: Binding<String>,
        provider: CloudModelProvider
    ) async {
        let didSave = await CloudProviderSetupAutomation.pasteAndSave(
            provider: provider,
            inference: inference
        )
        field.wrappedValue = inference.apiKey(for: provider) ?? ""
        if didSave {
            showCloudSetupHint = false
        }
    }

    private func saveProviderKey(
        _ value: String,
        for provider: CloudModelProvider,
        field: Binding<String>
    ) {
        guard normalizedCredentialDraft(value) != nil else {
            _ = inference.recordCloudProviderValidationFailure(
                for: provider,
                message: provider.missingManualCredentialMessage
            )
            return
        }
        let didSave = inference.setAPIKey(value, for: provider)
        field.wrappedValue = inference.apiKey(for: provider) ?? ""
        if didSave {
            Task { _ = await inference.validateCloudAccess(for: provider) }
        }
    }

    private func chooseGoogleOAuthClientFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else {
            return
        }

        guard let url = panel.url else {
            googleOAuthClientStatusMessage = "Couldn't resolve the selected Google OAuth client file."
            googleOAuthClientStatusIsSuccess = false
            _ = inference.recordCloudProviderValidationFailure(
                for: .google,
                message: "Couldn't resolve the selected Google OAuth client JSON file."
            )
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            settingsViewLogger.error("Failed to read Google OAuth client file at \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
            googleOAuthClientStatusMessage = "Couldn't read the selected Google OAuth client JSON file."
            googleOAuthClientStatusIsSuccess = false
            _ = inference.recordCloudProviderValidationFailure(
                for: .google,
                message: "Couldn't read the selected Google OAuth client JSON file."
            )
            return
        }

        do {
            let parsedConfiguration = try GoogleOAuthClientConfiguration.parse(from: data)
            guard CloudProviderSetupAutomation.persistGoogleOAuthClientConfig(
                data: data,
                filename: url.lastPathComponent
            ) else {
                googleOAuthClientStatusMessage = "Couldn't store the Google OAuth client file securely in the Apple Keychain."
                googleOAuthClientStatusIsSuccess = false
                _ = inference.recordCloudProviderValidationFailure(
                    for: .google,
                    message: "Couldn't store the Google OAuth client file securely in the Apple Keychain."
                )
                return
            }

            googleOAuthClientConfigData = data
            googleOAuthClientFilename = url.lastPathComponent
            if !parsedConfiguration.projectID.isEmpty {
                googleOAuthProjectID = parsedConfiguration.projectID
                googleOAuthClientStatusMessage = "Google OAuth client JSON verified. Project ID loaded from the file."
            } else if normalizedCredentialDraft(googleOAuthProjectID) != nil {
                googleOAuthClientStatusMessage = "Google OAuth client JSON verified. Using your current Google Cloud project ID."
            } else {
                googleOAuthClientStatusMessage = "Google OAuth client JSON verified. Enter the Google Cloud project ID for the same Gemini-enabled project."
            }
            googleOAuthClientStatusIsSuccess = true
            inference.resetCloudProviderValidationState(for: .google)
        } catch {
            googleOAuthClientStatusMessage = error.localizedDescription
            googleOAuthClientStatusIsSuccess = false
            _ = inference.recordCloudProviderValidationFailure(
                for: .google,
                message: error.localizedDescription
            )
        }
    }

    /// Quick sign-in using stored or embedded Google OAuth credentials.
    private func signInWithGoogleQuick() {
        Task {
            accountActionInFlightProvider = .google
            defer { accountActionInFlightProvider = nil }

            // Try stored config first, then embedded fallback
            let config: GoogleOAuthClientConfiguration?
            config = CloudProviderSetupAutomation.storedGoogleOAuthClientConfiguration(
                projectIDOverride: normalizedCredentialDraft(googleOAuthProjectID)
            ) ?? GoogleOAuthClientConfiguration.embeddedDefault

            guard let config else {
                googleOAuthClientStatusMessage = "No Google OAuth credentials found. Load an OAuth client JSON in the setup section below, or get an API key from aistudio.google.com."
                googleOAuthClientStatusIsSuccess = false
                return
            }

            // Use project ID from config or from the text field
            let projectID = normalizedCredentialDraft(googleOAuthProjectID)
                ?? normalizedCredentialDraft(config.projectID)
                ?? config.projectID

            let finalConfig = GoogleOAuthClientConfiguration(
                clientID: config.clientID,
                clientSecret: config.clientSecret,
                projectID: projectID
            )

            googleOAuthClientStatusMessage = nil
            let result = await inference.signInToGoogle(configuration: finalConfig)

            if result.success {
                googleOAuthClientStatusMessage = "Connected to Google successfully."
                googleOAuthClientStatusIsSuccess = true
            } else {
                googleOAuthClientStatusMessage = result.message
                googleOAuthClientStatusIsSuccess = false
            }
        }
    }

    private func clearGoogleOAuthClientFile() {
        CloudProviderSetupAutomation.clearGoogleOAuthClientConfig()
        googleOAuthClientConfigData = nil
        googleOAuthClientFilename = ""
        googleOAuthClientStatusMessage = "Removed the saved Google OAuth client JSON."
        googleOAuthClientStatusIsSuccess = true
        inference.resetCloudProviderValidationState(for: .google)
    }

    private func runAccountAction(
        for provider: CloudModelProvider,
        importExistingSession: Bool = false
    ) async {
        accountActionInFlightProvider = provider
        defer { accountActionInFlightProvider = nil }

        let result: ConnectionTestResult
        switch provider {
        case .openAI:
            if importExistingSession {
                result = await inference.importOpenAIAccount()
            } else {
                openAIDeviceAuthorization = nil
                result = await inference.signInToOpenAI { authorization in
                    openAIDeviceAuthorization = authorization
                }
                openAIDeviceAuthorization = nil
            }
        case .anthropic:
            result = await inference.importAnthropicAccount()
        case .google:
            guard let configData = googleOAuthClientConfigData else {
                googleOAuthClientStatusMessage = "Choose the Google OAuth client JSON you downloaded from Google Cloud Console for a Desktop app before connecting Google OAuth."
                googleOAuthClientStatusIsSuccess = false
                result = inference.recordCloudProviderValidationFailure(
                    for: .google,
                    message: "Choose the Google OAuth client JSON you downloaded from Google Cloud Console for a Desktop app before connecting Google OAuth."
                )
                break
            }
            do {
                let parsedConfiguration = try GoogleOAuthClientConfiguration.parse(from: configData)
                guard let projectID = normalizedCredentialDraft(googleOAuthProjectID)
                    ?? normalizedCredentialDraft(parsedConfiguration.projectID) else {
                    googleOAuthClientStatusMessage = "Enter the Google Cloud project ID for the same project where Gemini API is enabled before connecting Google OAuth."
                    googleOAuthClientStatusIsSuccess = false
                    result = inference.recordCloudProviderValidationFailure(
                        for: .google,
                        message: "Enter the Google Cloud project ID for the same project where Gemini API is enabled before connecting Google OAuth."
                    )
                    break
                }
                let configuration = GoogleOAuthClientConfiguration(
                    clientID: parsedConfiguration.clientID,
                    clientSecret: parsedConfiguration.clientSecret,
                    projectID: projectID
                )
                googleOAuthClientStatusMessage = nil
                result = await inference.signInToGoogle(configuration: configuration)
            } catch {
                googleOAuthClientStatusMessage = error.localizedDescription
                googleOAuthClientStatusIsSuccess = false
                result = inference.recordCloudProviderValidationFailure(
                    for: .google,
                    message: error.localizedDescription
                )
            }
        case .zai, .kimi, .minimax, .deepseek:
            if let url = provider.credentialManagementURL {
                NSWorkspace.shared.open(url)
            }
            return
        }

        if result.success {
            showCloudSetupHint = false
        }
    }

    private func normalizedCredentialDraft(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func loadCloudAPIKeyDrafts() {
        for provider in CloudModelProvider.preferredOrder {
            cloudAPIKeyDrafts[provider] = inference.apiKey(for: provider) ?? ""
        }
    }

    private func cloudAPIKeyDraftBinding(for provider: CloudModelProvider) -> Binding<String> {
        Binding(
            get: {
                cloudAPIKeyDrafts[provider] ?? inference.apiKey(for: provider) ?? ""
            },
            set: { newValue in
                cloudAPIKeyDrafts[provider] = newValue
            }
        )
    }
}

private struct LocalModelManagerSheet: View {
    @Environment(LocalModelManager.self) private var localModelManager
    @Environment(UIState.self) private var ui

    private var curatedBaselineDescriptors: [LocalModelDescriptor] {
        localModelManager.curatedBaselineDescriptors
    }

    private var optionalBaselineDescriptors: [LocalModelDescriptor] {
        localModelManager.optionalBaselineDescriptors
    }

    private var legacyInstalledDescriptors: [LocalModelDescriptor] {
        localModelManager.legacyInstalledDescriptors
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = localModelManager.lastErrorMessage, !error.isEmpty {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(ui.theme.warning)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Install a stable baseline first")
                            .font(.headline)
                        Text("Recommended: Qwen 3 4B + DeepSeek R1 7B + Qwen 2.5 Coder 7B. Optional roles: Bonsai 4B/8B for tiny fast fallback, LocalAgent 4.3 36B for local tool use, and Qwen 3.6 35B A3B for high-memory Macs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button("Install Recommended Baseline") {
                                Task {
                                    try? await localModelManager.installRecommendedBaselineModels()
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Refresh") {
                                localModelManager.refreshFromDisk()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Recommended Baseline") {
                    ForEach(curatedBaselineDescriptors, id: \.id) { descriptor in
                        LocalModelRow(descriptor: descriptor)
                    }
                }

                if !optionalBaselineDescriptors.isEmpty {
                    Section("Optional Flagship + Fallbacks") {
                        ForEach(optionalBaselineDescriptors, id: \.id) { descriptor in
                            LocalModelRow(descriptor: descriptor)
                        }
                    }
                }

                if !legacyInstalledDescriptors.isEmpty {
                    Section("Legacy Installed") {
                        Text("These older local models stay on disk until you delete them, but Epistemos no longer promotes them for new installs or normal routing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(legacyInstalledDescriptors, id: \.id) { descriptor in
                            LocalModelRow(descriptor: descriptor)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Local Models")
        }
    }
}

private struct LocalModelRow: View {
    @Environment(LocalModelManager.self) private var localModelManager
    @Environment(InferenceState.self) private var inference

    let descriptor: LocalModelDescriptor

    private var state: LocalModelPresentationState {
        localModelManager.presentationState(for: descriptor)
    }

    var body: some View {
        // Stacked fallback when actions push leading content too narrow.
        // `.fixedSize` on the leading column's intrinsic-width markers
        // (in `leadingColumn`) is what makes ViewThatFits actually trip
        // here; without it, Text inside the compact HStack would silently
        // wrap and the fallback would be decorative.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                leadingColumn
                Spacer(minLength: 0)
                actionsView
            }
            VStack(alignment: .leading, spacing: 12) {
                leadingColumn
                actionsView
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var leadingColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title + badges row.
            // Compact HStack uses `.fixedSize(horizontal: true, vertical: false)`
            // so it reports its single-line natural width; ViewThatFits
            // then trips reliably to the stacked fallback at large
            // Dynamic Type. The fallback ALSO wraps the inner badges row
            // in a second ViewThatFits because three inline badges + a
            // state title can themselves overflow at extreme sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    titleAndBadges
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.displayName)
                        .font(.footnote.weight(.semibold))
                    badgesAndStateRow
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(titleAndBadgesAccessibilityLabel)

            Text(descriptor.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Footer meta row: compact HStack pinned to its natural
            // width, stacked fallback at large sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    metaItems
                }
                .fixedSize(horizontal: true, vertical: false)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 2) {
                    metaItems
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(metaAccessibilityLabel)

            if case .installing(let progress) = state {
                ProgressView(value: progress)
                    .controlSize(.small)
                    .frame(maxWidth: 200)
                    .accessibilityLabel("\(descriptor.displayName) install progress")
                    .accessibilityValue("\(safePercent(progress)) percent")
            } else if case .prepared = state {
                Text("Prepared runtime assets are already available for this tier. Install the snapshot only if you want a separate fallback copy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if case .blocked(let reason) = state {
                Text(blockedGuidance(for: reason))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var titleAndBadges: some View {
        Text(descriptor.displayName)
            .font(.footnote.weight(.semibold))
        badgesAndState
    }

    // Compact-or-stacked badges + state title. Used inside the
    // leadingColumn's stacked fallback so badges themselves can wrap
    // to their own column at extreme Dynamic Type.
    @ViewBuilder
    private var badgesAndStateRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                badgesAndState
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 2) {
                badgesAndState
            }
        }
    }

    @ViewBuilder
    private var badgesAndState: some View {
        if descriptor.id == localModelManager.recommendedTextModelID {
            Text("Recommended")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        if descriptor.id == localModelManager.constrainedFallbackTextModelID {
            Text("Fallback")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        if let model = LocalTextModelID(rawValue: descriptor.id),
           model.isExperimentalForEpistemos {
            Text("Experimental")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
        }
        Text(state.title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var metaItems: some View {
        Text(descriptor.familyName)
        Text(descriptor.approximateDownloadLabel)
        if case .installed(let record) = state {
            Text("Installed \(installedStorageLabel(for: record))")
        }
        if let model = LocalTextModelID(rawValue: descriptor.id) {
            Text("Chat \(model.minimumRecommendedInteractiveMemoryGB) GB")
        } else {
            Text("Min \(descriptor.minimumRecommendedMemoryGB) GB")
        }
    }

    private var titleAndBadgesAccessibilityLabel: String {
        var parts: [String] = [descriptor.displayName]
        if descriptor.id == localModelManager.recommendedTextModelID {
            parts.append("Recommended")
        }
        if descriptor.id == localModelManager.constrainedFallbackTextModelID {
            parts.append("Fallback")
        }
        if let model = LocalTextModelID(rawValue: descriptor.id),
           model.isExperimentalForEpistemos {
            parts.append("Experimental")
        }
        parts.append(state.title)
        return parts.joined(separator: ", ")
    }

    private var metaAccessibilityLabel: String {
        var parts: [String] = [descriptor.familyName, descriptor.approximateDownloadLabel]
        if case .installed(let record) = state {
            parts.append("Installed footprint \(installedStorageLabel(for: record))")
        }
        if let model = LocalTextModelID(rawValue: descriptor.id) {
            parts.append("Chat minimum \(model.minimumRecommendedInteractiveMemoryGB) gigabytes")
        } else {
            parts.append("Minimum \(descriptor.minimumRecommendedMemoryGB) gigabytes")
        }
        return parts.joined(separator: ", ")
    }

    private func installedStorageLabel(for record: LocalModelInstallRecord) -> String {
        ByteCountFormatter.string(fromByteCount: record.sizeBytes, countStyle: .file)
    }

    // Guards isFinite — Int(Double) traps on NaN/Infinity.
    private func safePercent(_ progress: Double) -> Int {
        guard progress.isFinite else { return 0 }
        let clamped = min(max(progress, 0), 1)
        return Int((clamped * 100).rounded())
    }

    @ViewBuilder
    private var actionsView: some View {
        switch state {
        case .installed:
            HStack(spacing: 6) {
                Button("Reinstall") {
                    do {
                        try localModelManager.uninstall(modelID: descriptor.id)
                    } catch {
                        settingsViewLogger.error("Failed to uninstall local model \(descriptor.id, privacy: .public) before reinstall: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    Task {
                        do {
                            try await localModelManager.install(modelID: descriptor.id)
                        } catch {
                            settingsViewLogger.error("Failed to reinstall local model \(descriptor.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Reinstall \(descriptor.displayName)")
                .accessibilityHint("Removes and re-downloads this local model.")
                Button("Delete") {
                    do {
                        try localModelManager.uninstall(modelID: descriptor.id)
                    } catch {
                        settingsViewLogger.error("Failed to delete local model \(descriptor.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Delete \(descriptor.displayName)")
                .accessibilityHint("Removes the installed local model files from disk.")
            }
        case .prepared:
            Button("Install Snapshot") {
                Task {
                    do {
                        try await localModelManager.install(modelID: descriptor.id)
                    } catch {
                        settingsViewLogger.error("Failed to install prepared local model snapshot \(descriptor.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Install snapshot of \(descriptor.displayName)")
            .accessibilityHint("Adds a separate fallback copy alongside prepared runtime assets.")
        case .installing:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Installing \(descriptor.displayName)")
        case .blocked:
            blockedAction
        case .available:
            Button("Install") {
                Task {
                    do {
                        try await localModelManager.install(modelID: descriptor.id)
                    } catch {
                        settingsViewLogger.error("Failed to install local model \(descriptor.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel("Install \(descriptor.displayName)")
            .accessibilityHint("Downloads and prepares this local model.")
        }
    }

    @ViewBuilder
    private var blockedAction: some View {
        if localModelManager.installErrors[descriptor.id] != nil {
            Button("Retry") {
                Task {
                    do {
                        try await localModelManager.install(modelID: descriptor.id)
                    } catch {
                        settingsViewLogger.error("Failed to retry local model install \(descriptor.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else if !inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor) {
            Label("Unsupported", systemImage: "exclamationmark.triangle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func blockedGuidance(for reason: String) -> String {
        if let installError = localModelManager.installErrors[descriptor.id] {
            return Self.userFacingInstallError(installError, fallback: reason)
        }
        if !inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor) {
            return "\(reason). \(localModelManager.hardwareSummary)."
        }
        return reason
    }

    /// Converts noisy HuggingFace / URLSession / filesystem errors into
    /// actionable user guidance so the settings row explains the real
    /// problem instead of leaking stack-level jargon.
    private static func userFacingInstallError(_ raw: String, fallback: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("hostname") || lower.contains("huggingface.co") || lower.contains("could not be found")
            || lower.contains("offline") || lower.contains("network connection") {
            return "Couldn't reach Hugging Face. Check your internet connection and try again — this is the host the model download uses."
        }
        if lower.contains("403") || lower.contains("forbidden") || lower.contains("unauthorized") || lower.contains("401") {
            return "The model is gated. Sign in to Hugging Face in your browser, accept the model's license, and retry."
        }
        if lower.contains("404") || lower.contains("not found") {
            return "This model isn't available at the expected path anymore. It may have been renamed on Hugging Face — try the prepared snapshot instead."
        }
        if lower.contains("incomplete or corrupted") || lower.contains("corrupted manifest") || lower.contains("corrupted") {
            return "This local model snapshot looks incomplete or corrupted. Retry the install and Epistemos will restage the snapshot from scratch."
        }
        if lower.contains("disk") || lower.contains("space") || lower.contains("no such file") {
            return "Ran out of space or the staging directory is unavailable. Free up disk and try again."
        }
        if lower.contains("timed out") || lower.contains("timeout") {
            return "The download timed out. Try again — if your connection is slow, start it once and leave the window open while it completes."
        }
        return raw.isEmpty ? fallback : raw
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

    private var appearanceForm: some View {
        Form {
            AppearanceThemePairSection(ui: ui, theme: theme)
            AppearanceTypographySection(ui: ui)
            AppearanceGraphNodeVisibilitySection()
            AppearanceGraphPerformanceSection()
            AppearanceShapedGraphSection(ui: ui)
            AppearanceEditorSection()
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

    var body: some View {
        Section {
            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
                ForEach(ThemePair.allCases, id: \.self) { pair in
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

                ThemePairCinematicPreview(pair: pair)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .background(cardBackground)
            .overlay(cardBorder)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(pair.displayName) theme pair"))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                isSelected
                    ? theme.resolved.accent.color.opacity(theme.isDark ? 0.20 : 0.14)
                    : theme.resolved.card.color.opacity(theme.isDark ? 0.42 : 0.72)
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(
                isSelected
                    ? theme.resolved.accent.color.opacity(0.72)
                    : theme.resolved.border.color.opacity(theme.isDark ? 0.42 : 0.58),
                lineWidth: isSelected ? 1.4 : 1
            )
    }
}

/// Cinematic duotone preview pane for a ThemePair. Renders the light
/// + dark variants side by side at a poster scale (rather than two
/// tiny color swatches), with a hero "GREETINGS" sample in the pair's
/// display font and faint chat-line ghost rows below it so the user
/// gets a live feel for the typography + palette before applying it.
private struct ThemePairCinematicPreview: View {
    let pair: ThemePair

    private static let cornerRadius: CGFloat = 8
    private static let height: CGFloat = 78

    var body: some View {
        HStack(spacing: 0) {
            ThemePairCinematicHalf(theme: pair.lightTheme, accentSide: .left)
            ThemePairCinematicHalf(theme: pair.darkTheme, accentSide: .right)
        }
        .frame(height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .overlay(
            // Razor-thin divider between the two halves to keep the
            // duotone seam crisp even on tightly-matched palettes.
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1)
        )
    }
}

private struct ThemePairCinematicHalf: View {
    enum AccentSide { case left, right }

    let theme: EpistemosTheme
    let accentSide: AccentSide

    var body: some View {
        let resolved = theme.resolved
        // ALL-CAPS for Classic per the user direction; other themes
        // keep mixed case so each pair shows off its actual feel.
        let heroText = theme.prefersUppercaseDisplay ? "GREETINGS" : "Greetings"
        let heroFont = AppDisplayTypography.headingFont(size: 12, weight: .bold, theme: theme)
        let heroColor = Color(hex: resolved.headingAccentHex)
        let bodyColor = Color(hex: resolved.foregroundHex).opacity(0.55)
        let ghostLineColor = Color(hex: resolved.foregroundHex).opacity(0.18)
        return ZStack {
            // Background gradient — biases the brighter end of the
            // palette to the inner seam so the duotone feels lit.
            LinearGradient(
                colors: [
                    resolved.background.color,
                    resolved.background.color.opacity(0.92),
                    resolved.muted.color.opacity(0.55)
                ],
                startPoint: accentSide == .left ? .topTrailing : .topLeading,
                endPoint: accentSide == .left ? .bottomLeading : .bottomTrailing
            )

            // Faint scanlines on dark variants only — evokes the OLED
            // / Platinum dark look without committing pixels.
            if theme.isDark {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                resolved.accent.color.opacity(0.0),
                                resolved.accent.color.opacity(0.10),
                                resolved.accent.color.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.5)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(heroText)
                    .font(heroFont)
                    .foregroundStyle(heroColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                // Two ghost lines simulating chat bubbles — quick read
                // of the body type contrast against background.
                Capsule()
                    .fill(ghostLineColor)
                    .frame(width: 56, height: 4)
                Capsule()
                    .fill(ghostLineColor)
                    .frame(width: 40, height: 4)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(bodyColor)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AppearanceEditorSection: View {
    // Same key as the per-editor View Options menu in CodeEditorView so
    // toggling either surface reflects in the other immediately.
    @AppStorage("epistemos.codeEditor.showLineGutter") private var showLineGutter = true

    var body: some View {
        Section {
            Toggle("Show Line Numbers", isOn: $showLineGutter)
                .toggleStyle(.switch)
            Text("Adds a subtle right-side gutter to the code editor. Numbers track the active theme and Dynamic Type.")
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
        } header: {
            Text("Typography")
        }
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
                    text: "Your vault is the on-disk markdown workspace Epistemos reads from and writes to. Connecting a vault enables note sync, search indexing, and vault-backed editing."
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
                        text: "The search index is the fast local lookup database built from your vault. Rebuild it if search feels stale after large external edits or imports."
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

// MARK: - Knowledge Fusion Detail

private struct KnowledgeFusionDetailView: View {
    private var vm: KnowledgeFusionViewModel { .shared }

    var body: some View {
        Form {
            Section("Train") {
                SettingsDescriptionCard(
                    title: "Knowledge Fusion",
                    systemImage: "brain.head.profile.fill",
                    text: "Knowledge Fusion trains adapters on top of your local model. It does not replace the base model. Think of it as personalization for your installed local base model, not a brand new proprietary model."
                )
                TrainOnVaultView()
            }

            Section("Training Configuration") {
                SettingsDescriptionText(
                    text: "These controls tune adapter capacity, memory usage, and training time. Higher values can improve specialization, but they also increase runtime cost."
                )
                KFTrainingConfigSection()
            }

            Section("Adapters") {
                SettingsDescriptionText(
                    text: "Adapters are lightweight add-ons you can activate on top of the base local model. This section lets you inspect what is active and switch between trained variants."
                )
                HStack {
                    Text("Active Adapter")
                    Spacer()
                    AdapterSelectorView()
                }
                TrainingHistoryView()
            }

            Section("Feedback") {
                SettingsDescriptionText(
                    text: "Feedback tracks accepts and rejects from adapter-assisted output. Those signals can later be used for optional overnight preference training if you enable it."
                )
                FeedbackIndicatorView()
                if let stats = vm.feedbackStats {
                    LabeledContent("Accepts this week", value: "\(stats.totalAccepts)")
                    LabeledContent("Rejects this week", value: "\(stats.totalRejects)")
                }
            }
        }
        .formStyle(.grouped)
        .environment(vm)
        .task {
            if let bootstrap = AppBootstrap.shared {
                vm.configure(triageService: bootstrap.triageService)
            }
            await vm.loadState()
            vm.autoConfigureForHardware()
        }
    }
}

// MARK: - Training Configuration Section

private struct KFTrainingConfigSection: View {
    @Environment(KnowledgeFusionViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: 12) {
            // Hardware
            HStack {
                Image(systemName: "memorychip")
                    .foregroundStyle(.secondary)
                Text("Detected: \(vm.systemMemoryGB) GB unified memory")
                    .font(.caption.weight(.medium))
                Spacer()
                Button("Auto Configure") { vm.autoConfigureForHardware() }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }

            // Settings grid
            kfSettingRow(
                title: "Training Iterations",
                value: $vm.trainingIterations,
                range: 20...2000, step: 20,
                desc: "More = better quality, slower. 200 for quick test, 500-1000 for thorough training."
            )
            kfSettingRow(
                title: "LoRA Rank",
                value: $vm.loraRank,
                range: 4...64, step: 4,
                desc: "Adapter capacity. 8 = style only. 16 = balanced. 32+ = deep knowledge. Higher needs more memory."
            )
            kfSettingRow(
                title: "LoRA Alpha",
                value: $vm.loraAlpha,
                range: 8...128, step: 8,
                desc: "Learning magnitude (usually 2x rank). Controls how strongly new knowledge overrides the base model."
            )
            kfSettingRow(
                title: "Batch Size",
                value: $vm.batchSize,
                range: 1...8, step: 1,
                desc: "Examples per step. 1 for 16GB, 2 for 32GB, 4 for 64GB+."
            )
            kfSettingRow(
                title: "Max Sequence Length",
                value: $vm.maxSeqLength,
                range: 256...4096, step: 256,
                desc: "Token window per example. 1024 for 16GB, 2048 for 32GB+. Longer = more context per note."
            )

            // Hardware guide
            Divider().opacity(0.3)
            Text("Hardware Guide")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                kfHardwareRow("16 GB (M1/M2/M3)", "rank 8-16, batch 1, seq 1024")
                kfHardwareRow("24 GB (M2/M3 Pro)", "rank 16-32, batch 2, seq 1024")
                kfHardwareRow("32 GB (M1/M2/M3 Max)", "rank 32, batch 2, seq 2048")
                kfHardwareRow("64 GB+ (M2/M3/M4 Max)", "rank 32-64, batch 4, seq 2048")
                kfHardwareRow("128 GB (M4 Ultra)", "rank 64, batch 8, seq 4096")
            }
        }
    }

    private func kfSettingRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.caption.weight(.medium))
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 40, alignment: .trailing)
                Stepper("", value: value, in: range, step: step).labelsHidden()
            }
            Text(desc).font(.caption2).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func kfHardwareRow(_ machine: String, _ config: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Text(machine)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 160, alignment: .leading)
                Text(config)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 0) {
                Text(machine)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(config)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
