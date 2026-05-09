import AppKit
import os
import SwiftUI

private let iMessageDriverSettingsLogger = Logger(subsystem: "Epistemos", category: "IMessageDriverSettingsView")

/// Environment-bound adapter that pulls `IMessageDriverService` and the
/// current vault path out of environment so the detail view matches the
/// signature of the other settings sections (no constructor args).
struct iMessageDriverDetailView: View {
    @Environment(IMessageDriverService.self) private var driver
    @Environment(VaultSyncService.self) private var vaultSync

    var body: some View {
        if let vaultPath = vaultSync.vaultURL?.path {
            IMessageDriverSettingsView(driver: driver, vaultPath: vaultPath)
        } else {
            ContentUnavailableView(
                "No vault configured",
                systemImage: "folder.badge.questionmark",
                description: Text("Set up a vault in Settings → Vault before enabling the iMessage driver.")
            )
        }
    }
}

/// Settings pane for the iMessage-as-main-driver UX. Lets the user:
///
/// - Toggle the polling driver on/off (master switch)
/// - See the polling interval + last poll time
/// - Add/edit/delete per-contact routing rules
/// - Pick per-contact model, tool tier, prompt mode, and safety flags
///
/// All persistence happens via the Rust `imessage_contacts` tool executed
/// through `ToolTierBridge.executeToolCall`.
struct IMessageDriverSettingsView: View {
    @Bindable var driver: IMessageDriverService
    let vaultPath: String

    @Environment(ChannelRegistryState.self) private var registry
    @State private var contacts: [IMessageContact] = []
    @State private var recentThreads: [DriverChannelThreadSummary] = []
    @State private var recentAuditEntries: [DriverChannelAuditEntry] = []
    @State private var isLoading: Bool = false
    @State private var showAddSheet: Bool = false
    @State private var editingContact: IMessageContact?
    @State private var errorMessage: String?
    @State private var setupStatus = IMessageNativeSetupDoctor.currentStatus(probeAutomation: false)
    @State private var isRunningNativeSetup: Bool = false
    @State private var setupStatusMessage: String?

    var body: some View {
        Form {
            // MARK: - Master Toggle

            Section {
                Toggle("Let iMessage drive Epistemos", isOn: Binding(
                    get: { driver.isRunning },
                    set: { newValue in
                        if newValue { driver.start() } else { driver.stop() }
                    }
                ))
                .tint(.blue)

                HStack {
                    Text("Poll interval")
                    Spacer()
                    Stepper("\(driver.pollIntervalSeconds)s", value: $driver.pollIntervalSeconds, in: 2...60)
                        .frame(maxWidth: 160)
                }

                if let lastPoll = driver.lastPollAt {
                    HStack {
                        Text("Last poll")
                        Spacer()
                        Text(lastPoll, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Processed")
                    Spacer()
                    Text("\(driver.processedCount) messages")
                        .foregroundStyle(.secondary)
                }

                if let error = presentedDriverError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                Button("Poll now") {
                    Task { await driver.tickOnce() }
                }
                .disabled(!driver.isRunning)
            } header: {
                Text("iMessage Driver")
            } footer: {
                Text("When enabled, Epistemos polls the configured iMessage transport for new messages from allowlisted contacts and routes each one to the assigned model. Native mode requires Full Disk Access for chat.db reads and Automation permission for Messages replies.")
                    .font(.caption)
            }

            Section {
                HStack(spacing: 12) {
                    ChannelStatusPill(
                        title: setupStatus.pollingReady ? "Polling Ready" : "Polling Blocked",
                        tint: setupStatus.pollingReady ? Color.green : Color.orange
                    )
                    ChannelStatusPill(
                        title: setupStatus.replyReady ? "Replies Ready" : "Replies Blocked",
                        tint: setupStatus.replyReady ? Color.green : Color.orange
                    )
                }

                if let setupStatusMessage {
                    Label(setupStatusMessage, systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if isRunningNativeSetup {
                    ProgressView("Running native iMessage setup…")
                        .controlSize(.small)
                }

                ForEach(permissionChecks) { check in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(check.passed ? Color.green : Color.orange)
                            .font(.caption)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.title)
                                .font(.subheadline.weight(.medium))
                            Text(check.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button("Run Native Setup") {
                        Task { await runNativeSetup() }
                    }
                    .disabled(isRunningNativeSetup)

                    Button("Refresh setup status") {
                        Task { await refreshSetupStatus(probeAutomation: true) }
                    }
                    .disabled(isRunningNativeSetup)

                    Button("Open Full Disk Access") {
                        IMessageNativeSetupDoctor.openFullDiskAccessSettings()
                    }

                    Button("Open Automation Settings") {
                        IMessageNativeSetupDoctor.openAutomationSettings()
                    }

                    Button("Open Messages") {
                        IMessageNativeSetupDoctor.openMessagesApp()
                    }
                    .disabled(!setupStatus.messagesAppAvailable)

                    Button("Reveal This Epistemos") {
                        IMessageNativeSetupDoctor.revealCurrentApp()
                    }

                    Button("Relaunch Epistemos") {
                        Task { await IMessageNativeSetupDoctor.relaunchCurrentApp() }
                    }
                }

                Text(setupStatus.currentAppPath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text(setupStatus.messagesDatabasePath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            } header: {
                Text("Permission Doctor")
            } footer: {
                Text("If native iMessage polling cannot open chat.db, grant Full Disk Access to this exact Epistemos app copy, then relaunch it. If replies are blocked later, grant Automation access for Messages.app.")
                    .font(.caption)
            }

            // MARK: - Contacts

            Section {
                if contacts.isEmpty {
                    Text("No contacts configured yet.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(contacts) { contact in
                        Button {
                            editingContact = contact
                        } label: {
                            DriverRouteRow(contact: contact)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteContact)
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("Add contact", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Contacts")
                    Spacer()
                    if isLoading {
                        ProgressView().controlSize(.small)
                    }
                    Button {
                        Task { await refreshContacts() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                }
            } footer: {
                Text("Each contact is mapped to a model, tool tier, and safety flags. Auto-reply must be ON for the driver to reply automatically; otherwise messages are logged but ignored.")
                    .font(.caption)
            }

            Section {
                HStack(spacing: 12) {
                    ChannelStatusPill(title: registry.configuration(for: .imessage).pairingState.title, tint: .blue)
                    ChannelStatusPill(title: "\(contacts.count) contacts", tint: .secondary)
                    ChannelStatusPill(title: "\(contacts.filter(\.autoReply).count) auto-reply", tint: .green)
                    ChannelStatusPill(title: "\(contacts.filter(\.autoApprove).count) trusted", tint: .orange)
                }

                Text("Recent thread coverage")
                    .font(.subheadline.weight(.medium))

                if recentThreads.isEmpty {
                    Text("No recent iMessage threads found yet.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    Text("\(mappedRecentThreadCount) of the last \(recentThreads.count) threads are already mapped to a configured contact.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Button("Refresh thread continuity") {
                    Task { await refreshOperationalSurfaces() }
                }
            } header: {
                Text("Continuity")
            } footer: {
                Text("Pairing mode is configured in Settings → Channels. Native iMessage remains the flagship transport, and remote relay can now serve as the primary path with native fallback if you keep it armed.")
                    .font(.caption)
            }

            Section {
                if recentThreads.isEmpty {
                    Text("No recent threads available.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(recentThreads) { thread in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(thread.title)
                                        .font(.headline)
                                    if !thread.subtitle.isEmpty {
                                        Text(thread.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                ChannelStatusPill(
                                    title: isConfiguredThread(thread) ? "Mapped" : "Unmapped",
                                    tint: isConfiguredThread(thread) ? .green : .orange
                                )
                            }

                            if thread.lastActivityUnix > 0 {
                                Text(Date(timeIntervalSince1970: TimeInterval(thread.lastActivityUnix)), style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text("Recent Threads")
            } footer: {
                Text("This is driven by the native `imessage list_chats` read path, so it reflects what the Messages database can see locally.")
                    .font(.caption)
            }

            Section {
                if recentAuditEntries.isEmpty {
                    Text("No recent message audit entries available.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(recentAuditEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.senderID)
                                        .font(.subheadline.weight(.semibold))
                                    Text(entry.preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                ChannelStatusPill(title: entry.isFromMe ? "Outgoing" : "Incoming", tint: entry.isFromMe ? .blue : .green)
                            }

                            if entry.unix > 0 {
                                Text(Date(timeIntervalSince1970: TimeInterval(entry.unix)), style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Text("Recent Message Audit")
            } footer: {
                Text("This is a lightweight audit trail from the native iMessage read tool so you can sanity-check what the driver is seeing without leaving Epistemos.")
                    .font(.caption)
            }

            if let errorMessage {
                let guidance = Self.doctorGuidance(for: errorMessage)
                Section("Diagnosed issue") {
                    Label(guidance.headline, systemImage: guidance.systemImage)
                        .foregroundStyle(guidance.tint)
                    Text(guidance.hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !guidance.actions.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(guidance.actions, id: \.title) { action in
                                Button(action.title) { action.run() }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                    DisclosureGroup("Raw error") {
                        Text(errorMessage)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddSheet) {
            DriverRouteEditorSheet(
                channelID: .imessage,
                contact: nil,
                vaultPath: vaultPath,
                onSaved: {
                    showAddSheet = false
                    Task { await refreshContacts() }
                },
                onCancelled: { showAddSheet = false }
            )
        }
        .sheet(item: $editingContact) { contact in
            DriverRouteEditorSheet(
                channelID: .imessage,
                contact: contact,
                vaultPath: vaultPath,
                onSaved: {
                    editingContact = nil
                    Task { await refreshContacts() }
                },
                onCancelled: { editingContact = nil }
            )
        }
        .task {
            await refreshSetupStatus(probeAutomation: false)
            await refreshContacts()
        }
    }

    private func refreshContacts() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            contacts = try await IMessageContactsStore.list(vaultPath: vaultPath)
            await refreshOperationalSurfaces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshOperationalSurfaces() async {
        do {
            let adapter = registry.makeAdapter(for: .imessage)
            recentThreads = try await adapter.listThreads(vaultPath: vaultPath, limit: 8)
            recentAuditEntries = try await adapter.recentAuditEntries(vaultPath: vaultPath, limit: 8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteContact(at offsets: IndexSet) {
        let doomed = offsets.map { contacts[$0] }
        Task {
            for contact in doomed {
                do {
                    try await IMessageContactsStore.remove(handle: contact.handle, vaultPath: vaultPath)
                } catch {
                    iMessageDriverSettingsLogger.error("Failed to remove iMessage contact \(contact.handle, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            await refreshContacts()
            await refreshOperationalSurfaces()
        }
    }

    private var mappedRecentThreadCount: Int {
        recentThreads.filter(isConfiguredThread).count
    }

    private func isConfiguredThread(_ thread: DriverChannelThreadSummary) -> Bool {
        contacts.contains { contact in
            contact.handle == thread.subtitle || contact.handle == thread.title
        }
    }

    private var presentedDriverError: String? {
        IMessageNativeSetupDoctor.presentedDriverError(driver.lastError, status: setupStatus)
    }

    private var permissionChecks: [DriverSetupCheck] {
        [
            DriverSetupCheck(
                title: "Messages database present",
                detail: setupStatus.databaseFileExists
                    ? "chat.db exists on this Mac, so native history is available once TCC grants live reads."
                    : "chat.db has not appeared yet. Open Messages once on this Mac before enabling the native bridge.",
                passed: setupStatus.databaseFileExists
            ),
            DriverSetupCheck(
                title: "Current Epistemos build",
                detail: setupStatus.isDebugBuild
                    ? "This settings panel is running inside a Debug build at \(setupStatus.currentAppPath). Full Disk Access must be granted to this exact app copy."
                    : "This settings panel is running inside \(setupStatus.currentAppPath).",
                passed: true
            ),
            DriverSetupCheck(
                title: "Another Epistemos copy is also running",
                detail: setupStatus.hasMultipleEpistemosBuildsRunning
                    ? "Multiple Epistemos app copies are open right now:\n\(setupStatus.runningEpistemosAppPaths.joined(separator: "\n"))"
                    : "Only this Epistemos app copy is currently running, so privacy changes will apply to a single build once it relaunches.",
                passed: !setupStatus.hasMultipleEpistemosBuildsRunning
            ),
            DriverSetupCheck(
                title: "Messages database accessible",
                detail: setupStatus.databaseAccessible
                    ? "Epistemos can open chat.db for live sqlite reads, so native polling is ready."
                    : "chat.db exists, but macOS is still blocking actual database opens until Full Disk Access is granted to this exact app copy and it is relaunched.",
                passed: setupStatus.databaseAccessible
            ),
            DriverSetupCheck(
                title: "Messages automation ready",
                detail: setupStatus.messagesAutomationGranted
                    ? "Messages replies can be delivered because Apple Events access is already granted."
                    : "Replies are still blocked. Run Native Setup to trigger the Messages automation consent flow.",
                passed: setupStatus.messagesAutomationGranted
            ),
            DriverSetupCheck(
                title: "Messages app available",
                detail: setupStatus.messagesAppAvailable
                    ? "Messages.app is present for reply delivery and automation prompts."
                    : "Messages.app was not found at the default system path.",
                passed: setupStatus.messagesAppAvailable
            ),
        ]
    }

    private func refreshSetupStatus(probeAutomation: Bool = false) async {
        setupStatus = IMessageNativeSetupDoctor.currentStatus(probeAutomation: probeAutomation)
        if setupStatus.nativeBridgeReady {
            setupStatusMessage = "Native Messages bridge looks ready."
        } else if setupStatus.databaseAccessible {
            setupStatusMessage = "Polling is ready. Replies still need the Messages automation approval."
        } else if setupStatus.hasMultipleEpistemosBuildsRunning {
            setupStatusMessage = "Another Epistemos copy is also running. Grant Full Disk Access to the current build shown here, then relaunch that same copy."
        } else if setupStatus.isDebugBuild {
            setupStatusMessage = "This Debug build still cannot read chat.db. Grant Full Disk Access to this exact app copy, then relaunch it."
        } else {
            setupStatusMessage = "Full Disk Access is still the main blocker for native polling."
        }
    }

    private func runNativeSetup() async {
        isRunningNativeSetup = true
        setupStatusMessage = "Opening Messages and the required privacy panes…"
        defer { isRunningNativeSetup = false }

        setupStatus = await IMessageNativeSetupDoctor.runGuidedSetup()

        if setupStatus.databaseAccessible {
            if !driver.isRunning {
                driver.start()
            }
            await driver.tickOnce()
            await refreshOperationalSurfaces()
        }

        if setupStatus.nativeBridgeReady {
            setupStatusMessage = "Native setup finished and the iMessage driver ran a fresh poll."
        } else if setupStatus.databaseAccessible {
            setupStatusMessage = "Native polling is ready now. One Messages automation approval may still be needed for replies."
        } else if setupStatus.hasMultipleEpistemosBuildsRunning {
            setupStatusMessage = "System Settings opened, but another Epistemos copy is also running. Grant access to the current build shown here, then relaunch that same copy."
        } else if setupStatus.isDebugBuild {
            setupStatusMessage = "System Settings opened for Full Disk Access. Grant access to this Debug app copy, then relaunch it before polling again."
        } else {
            setupStatusMessage = "System Settings opened for Full Disk Access. After granting access to this Epistemos build, relaunch it, then come back here and press Refresh setup status."
        }
    }

    // MARK: - Doctor Guidance

    struct DoctorAction {
        let title: String
        let run: () -> Void
    }

    struct DoctorGuidance {
        let headline: String
        let hint: String
        let systemImage: String
        let tint: Color
        let actions: [DoctorAction]
    }

    static func doctorGuidance(for rawError: String) -> DoctorGuidance {
        let lower = rawError.lowercased()
        let fdaOpen = DoctorAction(title: "Open Full Disk Access") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        }
        let automationOpen = DoctorAction(title: "Open Automation Settings") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        }
        let relaunch = DoctorAction(title: "Relaunch Epistemos") {
            // Use NSWorkspace (sandbox-safe) instead of a subprocess
            // launch of /usr/bin/open. Works identically in Pro and
            // removes this one subprocess-launch symbol from the MAS
            // binary (see docs/PHASE_S_AUDIT.md section 6a for the
            // broader subprocess-launch audit; this change only
            // addresses the iMessage Doctor relaunch site, not the
            // other sites that remain by design for Pro workflows).
            // Matches the canonical relaunch pattern used elsewhere
            // (AppBootstrap.swift, IMessageNativeSetupDoctor.swift).
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(
                at: Bundle.main.bundleURL,
                configuration: configuration
            ) { _, _ in }
            NSApp.terminate(nil)
        }

        if lower.contains("chat.db") || lower.contains("database") || lower.contains("sqlite")
            || lower.contains("unable to open database") || lower.contains("authorization") {
            return DoctorGuidance(
                headline: "Messages database can't be opened",
                hint: "Grant Full Disk Access to the Epistemos build shown above, then relaunch it. If you have two Epistemos copies, make sure the one with FDA is the one actually running.",
                systemImage: "lock.shield",
                tint: .orange,
                actions: [fdaOpen, relaunch]
            )
        }
        if lower.contains("applescript") || lower.contains("automation") || lower.contains("messages.app") {
            return DoctorGuidance(
                headline: "Messages automation is blocked",
                hint: "System Settings → Privacy & Security → Automation. Enable Messages under Epistemos so the driver can fetch threads.",
                systemImage: "sparkles",
                tint: .orange,
                actions: [automationOpen, relaunch]
            )
        }
        if lower.contains("not found") || lower.contains("no thread") || lower.contains("no contact") {
            return DoctorGuidance(
                headline: "Thread or contact not found",
                hint: "Either nothing has been routed yet or the vault path is wrong. Double-check the vault at the top of this pane and try adding a contact.",
                systemImage: "questionmark.circle",
                tint: .blue,
                actions: []
            )
        }
        if lower.contains("network") || lower.contains("connection") || lower.contains("offline") {
            return DoctorGuidance(
                headline: "Network issue talking to the driver",
                hint: "The native iMessage driver is unreachable. Relaunch Epistemos and try again; if this persists, check that the omega-mcp process is running.",
                systemImage: "wifi.exclamationmark",
                tint: .orange,
                actions: [relaunch]
            )
        }
        return DoctorGuidance(
            headline: "iMessage driver reported an error",
            hint: "Expand the raw error below. If you see \"permission\" or \"denied\", try granting Full Disk Access to the currently running Epistemos and relaunching.",
            systemImage: "exclamationmark.triangle.fill",
            tint: .red,
            actions: [fdaOpen, relaunch]
        )
    }
}

private struct DriverSetupCheck: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let passed: Bool
}

// MARK: - Shared Sender Route UI

struct DriverRouteRow: View {
    let contact: ChannelRouteContact

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contact.displayName ?? contact.handle)
                        .font(.headline)
                    if !contact.allowed {
                        Image(systemName: "nosign")
                            .foregroundStyle(.red)
                    } else if !contact.autoReply {
                        Image(systemName: "pause.circle")
                            .foregroundStyle(.orange)
                    }
                }
                if contact.displayName != nil {
                    Text(contact.handle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Label(contact.model, systemImage: "cpu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(contact.toolTier, systemImage: "wrench.and.screwdriver")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct DriverRouteEditorSheet: View {
    let channelID: ChannelIdentity
    let contact: ChannelRouteContact?
    let vaultPath: String
    let onSaved: () -> Void
    let onCancelled: () -> Void

    @Environment(InferenceState.self) private var inference

    @State private var handle: String = ""
    @State private var displayName: String = ""
    @State private var model: String = IMessageDriverService.defaultContactModel
    @State private var toolTier: String = "chat_pro"
    @State private var promptMode: String = "general"
    @State private var allowed: Bool = true
    @State private var autoReply: Bool = true
    @State private var autoApprove: Bool = false
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private var modelOptions: [String] {
        IMessageDriverService.suggestedModelOptions(
            installedLocalModelIDs: inference.installedLocalTextModelIDs,
            configuredCloudProviders: inference.configuredCloudProviders
        )
    }

    private let tierOptions = [
        ("chat_lite", "Chat Lite — web + vault, no writes"),
        ("chat_pro", "Chat Pro — adds vision, TTS, media"),
        ("agent", "Agent — full tool surface, destructive ops"),
    ]

    private let promptModeOptions = [
        ("general", "General"),
        ("code", "Code"),
        ("research", "Research"),
    ]

    private var routeSectionTitle: String {
        channelID == .imessage ? "Contact" : "Sender Route"
    }

    private var navigationTitleText: String {
        if channelID == .imessage {
            return contact == nil ? "Add Contact" : "Edit Contact"
        }
        return contact == nil ? "Add Sender Route" : "Edit Sender Route"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(routeSectionTitle) {
                    TextField(channelID.senderRouteLabel, text: $handle)
                        .disabled(contact != nil)
                    TextField("Display name", text: $displayName)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("Model & Tools") {
                    Picker("Model preset", selection: $model) {
                        ForEach(modelOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    TextField("Model (or comma list)", text: $model)
                        .textFieldStyle(.roundedBorder)
                        .help("Type any model alias, full LocalTextModelID, or a comma-separated list to fan out to multiple models sequentially.")
                    Picker("Tool tier", selection: $toolTier) {
                        ForEach(tierOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                    Picker("Prompt mode", selection: $promptMode) {
                        ForEach(promptModeOptions, id: \.0) { option in
                            Text(option.1).tag(option.0)
                        }
                    }
                }

                Section("Safety") {
                    Toggle(channelID == .imessage ? "Allow this contact" : "Allow this sender", isOn: $allowed)
                    Toggle("Auto-reply", isOn: $autoReply)
                        .disabled(!allowed)
                    Toggle("Auto-approve writes", isOn: $autoApprove)
                        .disabled(!allowed || !autoReply)
                    if autoApprove {
                        Label("Auto-approve covers non-vault modification tools only. Sensitive local reads plus any vault or workspace writes still require on-device approval and will be denied in the headless driver.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section("Couldn't save this route") {
                        Label("Route save failed", systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                            .font(.caption.weight(.semibold))
                        Text("Check that the contact is valid and the vault path above is writable, then try Save again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DisclosureGroup("Raw error") {
                            Text(errorMessage)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(navigationTitleText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancelled)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isEmpty || isSaving)
                }
            }
            .task {
                guard let contact else { return }
                handle = contact.handle
                displayName = contact.displayName ?? ""
                model = contact.model.isEmpty ? IMessageDriverService.defaultContactModel : contact.model
                toolTier = contact.toolTier
                promptMode = contact.promptMode
                allowed = contact.allowed
                autoReply = contact.autoReply
                autoApprove = contact.autoApprove
                notes = contact.notes ?? ""
            }
        }
        .frame(minWidth: 440, idealWidth: 520, minHeight: 520)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            try await ChannelContactsStore.upsert(
                channelID: channelID,
                handle: handle,
                displayName: displayName.isEmpty ? nil : displayName,
                model: model,
                toolTier: toolTier,
                promptMode: promptMode,
                allowed: allowed,
                autoReply: autoReply,
                autoApprove: autoApprove,
                notes: notes.isEmpty ? nil : notes,
                vaultPath: vaultPath
            )
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared Sender Route Store

struct ChannelRouteContact: Identifiable, Hashable, Sendable {
    let channelID: String
    let handle: String
    let displayName: String?
    let model: String
    let toolTier: String
    let promptMode: String
    let allowed: Bool
    let autoReply: Bool
    let autoApprove: Bool
    let notes: String?

    var id: String { "\(channelID):\(handle)" }

    var channelIdentity: ChannelIdentity {
        ChannelIdentity(rawValue: channelID) ?? .imessage
    }

    static func fromToolPayload(
        _ dict: [String: Any],
        defaultChannelID: ChannelIdentity
    ) -> ChannelRouteContact? {
        guard let handle = dict["handle"] as? String,
              let model = dict["model"] as? String else {
            return nil
        }
        let resolvedChannelID: String
        if let channelID = dict["channel_id"] as? String {
            let trimmedChannelID = channelID.trimmingCharacters(in: .whitespacesAndNewlines)
            resolvedChannelID = trimmedChannelID.isEmpty ? defaultChannelID.rawValue : trimmedChannelID
        } else {
            resolvedChannelID = defaultChannelID.rawValue
        }
        return ChannelRouteContact(
            channelID: resolvedChannelID,
            handle: handle,
            displayName: dict["display_name"] as? String,
            model: model,
            toolTier: dict["tool_tier"] as? String ?? "chat_pro",
            promptMode: dict["prompt_mode"] as? String ?? "general",
            allowed: dict["allowed"] as? Bool ?? false,
            autoReply: dict["auto_reply"] as? Bool ?? false,
            autoApprove: dict["auto_approve"] as? Bool ?? false,
            notes: dict["notes"] as? String
        )
    }
}

typealias IMessageContact = ChannelRouteContact
typealias IMessageContactsStoreError = ChannelContactsStoreError

enum ChannelContactsStoreError: LocalizedError {
    case bindingsUnavailable
    case invalidResponse(String)
    case toolError(String)

    var errorDescription: String? {
        switch self {
        case .bindingsUnavailable: "agent_core bindings unavailable"
        case .invalidResponse(let result): "Invalid response: \(result)"
        case .toolError(let result): result
        }
    }
}

enum ChannelContactsStore {
    static func list(channelID: ChannelIdentity, vaultPath: String) async throws -> [ChannelRouteContact] {
        let result = try await call(
            channelID: channelID,
            payload: ["action": "list"],
            vaultPath: vaultPath
        )
        guard let data = result.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contacts = root["contacts"] as? [[String: Any]] else {
            throw ChannelContactsStoreError.invalidResponse(result)
        }
        return contacts.compactMap { ChannelRouteContact.fromToolPayload($0, defaultChannelID: channelID) }
    }

    static func upsert(
        channelID: ChannelIdentity,
        handle: String,
        displayName: String?,
        model: String,
        toolTier: String,
        promptMode: String,
        allowed: Bool,
        autoReply: Bool,
        autoApprove: Bool,
        notes: String?,
        vaultPath: String
    ) async throws {
        var payload: [String: Any] = [
            "action": "set",
            "handle": handle,
            "model": model,
            "tool_tier": toolTier,
            "prompt_mode": promptMode,
            "allowed": allowed,
            "auto_reply": autoReply,
            "auto_approve": autoApprove,
        ]
        if let displayName { payload["display_name"] = displayName }
        if let notes { payload["notes"] = notes }
        _ = try await call(channelID: channelID, payload: payload, vaultPath: vaultPath)
    }

    static func remove(
        channelID: ChannelIdentity,
        handle: String,
        vaultPath: String
    ) async throws {
        _ = try await call(
            channelID: channelID,
            payload: ["action": "remove", "handle": handle],
            vaultPath: vaultPath
        )
    }

    private static func scopedPayload(
        channelID: ChannelIdentity,
        payload: [String: Any]
    ) -> [String: Any] {
        guard channelID != .imessage else {
            return payload
        }
        var payload = payload
        payload["channel_id"] = channelID.rawValue
        return payload
    }

    private static func toolName(for channelID: ChannelIdentity) -> String {
        channelID == .imessage ? "imessage_contacts" : "channel_contacts"
    }

    private static func call(
        channelID: ChannelIdentity,
        payload: [String: Any],
        vaultPath: String
    ) async throws -> String {
        #if canImport(agent_coreFFI)
        let jsonData = try JSONSerialization.data(
            withJSONObject: scopedPayload(channelID: channelID, payload: payload)
        )
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"
        let result = try await executeToolCall(
            vaultPath: vaultPath,
            tier: "agent",
            toolName: toolName(for: channelID),
            inputJson: jsonStr
        )
        guard result.success else {
            throw ChannelContactsStoreError.toolError(result.error ?? "unknown")
        }
        return result.outputJson
        #else
        throw ChannelContactsStoreError.bindingsUnavailable
        #endif
    }
}

enum IMessageContactsStore {
    static func list(vaultPath: String) async throws -> [IMessageContact] {
        try await ChannelContactsStore.list(channelID: .imessage, vaultPath: vaultPath)
    }

    static func upsert(
        handle: String,
        displayName: String?,
        model: String,
        toolTier: String,
        promptMode: String,
        allowed: Bool,
        autoReply: Bool,
        autoApprove: Bool,
        notes: String?,
        vaultPath: String
    ) async throws {
        try await ChannelContactsStore.upsert(
            channelID: .imessage,
            handle: handle,
            displayName: displayName,
            model: model,
            toolTier: toolTier,
            promptMode: promptMode,
            allowed: allowed,
            autoReply: autoReply,
            autoApprove: autoApprove,
            notes: notes,
            vaultPath: vaultPath
        )
    }

    static func remove(handle: String, vaultPath: String) async throws {
        try await ChannelContactsStore.remove(
            channelID: .imessage,
            handle: handle,
            vaultPath: vaultPath
        )
    }
}
