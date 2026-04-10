import SwiftUI

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

    @State private var contacts: [IMessageContact] = []
    @State private var isLoading: Bool = false
    @State private var showAddSheet: Bool = false
    @State private var editingContact: IMessageContact?
    @State private var errorMessage: String?

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

                if let error = driver.lastError {
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
                Text("When enabled, Epistemos polls Messages.app for new iMessages from allowlisted contacts and routes each one to the assigned model. Requires Full Disk Access (for reading chat.db) and Automation permission (for sending replies via Messages).")
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
                            ContactRow(contact: contact)
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

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddSheet) {
            ContactEditorSheet(
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
            ContactEditorSheet(
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
            await refreshContacts()
        }
    }

    private func refreshContacts() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            contacts = try await IMessageContactsStore.list(vaultPath: vaultPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteContact(at offsets: IndexSet) {
        let doomed = offsets.map { contacts[$0] }
        Task {
            for contact in doomed {
                try? await IMessageContactsStore.remove(handle: contact.handle, vaultPath: vaultPath)
            }
            await refreshContacts()
        }
    }
}

// MARK: - Contact Row

private struct ContactRow: View {
    let contact: IMessageContact

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

// MARK: - Contact Editor Sheet

private struct ContactEditorSheet: View {
    let contact: IMessageContact?
    let vaultPath: String
    let onSaved: () -> Void
    let onCancelled: () -> Void

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

    /// Single-model presets shown in the picker. Local short names map onto
    /// `LocalTextModelID` via `IMessageDriverService.localTextModelID(forShortName:)`.
    /// To assign a *group* of models to a contact, type a comma-separated list
    /// in the model field (e.g. "qwen-4b,claude-sonnet-4-6") — the driver
    /// fans out to all listed models sequentially and labels each reply with
    /// the model name.
    private var modelOptions: [String] {
        IMessageDriverService.modelPresetOptions
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Handle (phone, email, chat id)", text: $handle)
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
                        .help("Type any model alias, full LocalTextModelID, or a comma-separated list to fan out to multiple models in parallel.")
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
                    Toggle("Allow this contact", isOn: $allowed)
                    Toggle("Auto-reply", isOn: $autoReply)
                        .disabled(!allowed)
                    Toggle("Auto-approve writes", isOn: $autoApprove)
                        .disabled(!allowed || !autoReply)
                    if autoApprove {
                        Label("Auto-approve lets the agent modify files, run scheduled jobs, and write to the vault without prompting. Enable only for contacts you fully trust.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(contact == nil ? "Add Contact" : "Edit Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancelled)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(handle.isEmpty || model.isEmpty || isSaving)
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
            try await IMessageContactsStore.upsert(
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

// MARK: - Data model + Store

struct IMessageContact: Identifiable, Hashable, Sendable {
    var id: String { handle }
    let handle: String
    let displayName: String?
    let model: String
    let toolTier: String
    let promptMode: String
    let allowed: Bool
    let autoReply: Bool
    let autoApprove: Bool
    let notes: String?
}

enum IMessageContactsStoreError: LocalizedError {
    case bindingsUnavailable
    case invalidResponse(String)
    case toolError(String)

    var errorDescription: String? {
        switch self {
        case .bindingsUnavailable: "agent_core bindings unavailable"
        case .invalidResponse(let s): "Invalid response: \(s)"
        case .toolError(let s): s
        }
    }
}

enum IMessageContactsStore {
    static func list(vaultPath: String) async throws -> [IMessageContact] {
        let result = try await call(
            payload: ["action": "list"],
            vaultPath: vaultPath
        )
        guard let data = result.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = root["contacts"] as? [[String: Any]] else {
            throw IMessageContactsStoreError.invalidResponse(result)
        }
        return arr.compactMap(parseContact)
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
        _ = try await call(payload: payload, vaultPath: vaultPath)
    }

    static func remove(handle: String, vaultPath: String) async throws {
        _ = try await call(
            payload: ["action": "remove", "handle": handle],
            vaultPath: vaultPath
        )
    }

    private static func call(payload: [String: Any], vaultPath: String) async throws -> String {
        #if canImport(agent_coreFFI)
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let jsonStr = String(data: jsonData, encoding: .utf8) ?? "{}"
        let result = try await executeToolCall(
            vaultPath: vaultPath,
            tier: "agent",
            toolName: "imessage_contacts",
            inputJson: jsonStr
        )
        guard result.success else {
            throw IMessageContactsStoreError.toolError(result.error ?? "unknown")
        }
        return result.outputJson
        #else
        throw IMessageContactsStoreError.bindingsUnavailable
        #endif
    }

    private static func parseContact(_ dict: [String: Any]) -> IMessageContact? {
        guard let handle = dict["handle"] as? String,
              let model = dict["model"] as? String else { return nil }
        return IMessageContact(
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
