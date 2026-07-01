import SwiftUI

struct SkillsDetailView: View {
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(UIState.self) private var ui

    @State private var skills: [SkillInventoryEntry] = []
    @State private var discoveredSkills: [SkillDiscoveryEntry] = []
    @State private var isLoading = false
    @State private var createTitle: String = ""
    @State private var createDescription: String = ""
    @State private var createCategory: String = "general"
    @State private var createTags: String = ""
    @State private var createInstructionSheet: String = ""
    @State private var installURL: String = ""
    @State private var installSource: SkillInstallSource = .defaultSource
    @State private var searchQuery: String = ""
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var discoveryPhases: [String: SkillDiscoveryActionPhase] = [:]

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }
    private var successTint: Color { ui.theme.resolved.accent.color }
    private var infoTint: Color { ui.theme.resolved.headingAccent.color }
    private var warningTint: Color { ui.theme.resolved.headingAccent.color }
    private var mutedTint: Color { ui.theme.resolved.mutedForeground.color }
    private var tertiaryTint: Color { ui.theme.resolved.mutedForeground.color.opacity(0.78) }
    private var statusTint: Color { statusIsError ? warningTint : successTint }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                discoveryCard(vaultPath: vaultSync.vaultURL?.path)

                if let vaultPath = vaultSync.vaultURL?.path {
                    createCard(vaultPath: vaultPath)
                    installCard(vaultPath: vaultPath)
                    inventoryCard
                } else {
                    SettingsSurfaceCard {
                        ContentUnavailableView(
                            "No vault configured",
                            systemImage: "folder.badge.questionmark",
                            description: Text("Attach a vault before installing or managing skills. Discovery still works so you can stage what to import next.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .topLeading)
        }
        .task(id: vaultSync.vaultURL?.path) {
            await refreshSkills()
            refreshDiscovery()
        }
    }

    private var headerCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Skill Hub")
                    .font(.title2.weight(.semibold))

                Text("Local skills are already a real substrate in Epistemos. This panel turns them into a discoverable operator surface with install flow, usage stats, and room for an agentskills-style marketplace without changing the backend trust boundary.")
                    .foregroundStyle(mutedTint)

                SettingsDescriptionCard(
                    title: "Trust Boundary",
                    systemImage: "shield.lefthalf.filled",
                    text: "Installs still land in the managed skills directory and flow through the existing quarantine and validation path in the Rust skill manager."
                )

                SettingsDescriptionCard(
                    title: "Discovery Sources",
                    systemImage: "sparkles.rectangle.stack",
                    text: "The discovery feed surfaces bundled and local Codex-compatible skills first, then routes import through the same quarantine → promote flow used by GitHub and raw URL installs."
                )
            }
        }
    }

    @ViewBuilder
    private func discoveryCard(vaultPath: String?) -> some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Discovery")
                        .font(.headline)
                    Spacer()
                    ToolbarCapsuleButton(
                        title: nil,
                        systemImage: "arrow.clockwise",
                        role: .toolbarUtility,
                        chromePolicy: .bareUntilPressed,
                        helpText: "Refresh discovered skills",
                        accessibilityLabel: "Refresh discovered skills"
                    ) {
                        refreshDiscovery()
                    }
                }

                TextField("Search discovered and installed skills", text: $searchQuery)
                    .settingsFlatInputChrome(theme: theme, maxWidth: 360)

                if filteredDiscoveredSkills.isEmpty {
                    Text(discoveredSkills.isEmpty ? "No discovery sources found yet." : "No discovery matches this search.")
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                } else {
                    ForEach(filteredDiscoveredSkills.prefix(18)) { skill in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                IntegrationBrandMarkView(
                                    brand: .skillDiscovery(
                                        source: skill.source.rawValue,
                                        identifier: skill.identifier,
                                        category: skill.category
                                    ),
                                    size: 24
                                )
                                .foregroundStyle(mutedTint)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(skill.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(skill.description)
                                        .font(.caption)
                                        .foregroundStyle(mutedTint)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                ChannelStatusPill(title: skill.source.title, tint: infoTint)
                                ChannelStatusPill(title: skill.category.capitalized, tint: mutedTint)
                            }

                            if !skill.tags.isEmpty {
                                Text(skill.tags.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundStyle(tertiaryTint)
                            }

                            HStack(spacing: 10) {
                                ToolbarCapsuleButton(
                                    title: discoveryActionLabel(for: skill),
                                    systemImage: discoveryActionSystemImage(for: skill),
                                    role: .toolbarUtility,
                                    chromePolicy: .bareUntilPressed,
                                    helpText: "\(discoveryActionLabel(for: skill)) \(skill.title)",
                                    accessibilityLabel: "\(discoveryActionLabel(for: skill)) \(skill.title)"
                                ) {
                                    guard let vaultPath else { return }
                                    Task { await installDiscoveredSkill(skill, vaultPath: vaultPath) }
                                }
                                .disabled(vaultPath == nil || isDiscoveredSkillInstalled(skill))

                                Text(skill.sourcePath)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(tertiaryTint)
                                    .lineLimit(1)
                            }
                        }

                        if skill.id != filteredDiscoveredSkills.prefix(18).last?.id {
                            skillSettingsRowGap()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func createCard(vaultPath: String) -> some View {
        let draft = SkillAuthoringDraft(
            title: createTitle,
            description: createDescription,
            category: createCategory,
            tagsText: createTags,
            instructionSheet: createInstructionSheet
        )

        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    IntegrationBrandMarkView(brand: .skillRepo, size: 26)
                        .foregroundStyle(mutedTint)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Skill")
                            .font(.headline)
                        Text("Write a reusable instruction sheet straight into your vault's managed skills directory. This is the real skill substrate the local agent can follow; tool creation still needs runtime registration work.")
                            .font(.caption)
                            .foregroundStyle(mutedTint)
                    }
                    Spacer()
                    if !draft.identifier.isEmpty {
                        ChannelStatusPill(title: draft.identifier, tint: infoTint)
                    }
                }

                TextField("Skill title", text: $createTitle)
                    .settingsFlatInputChrome(theme: theme)

                TextField("Short description", text: $createDescription)
                    .settingsFlatInputChrome(theme: theme)

                HStack(spacing: 12) {
                    TextField("Category", text: $createCategory)
                        .settingsFlatInputChrome(theme: theme)
                    TextField("Tags (comma separated)", text: $createTags)
                        .settingsFlatInputChrome(theme: theme)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Instruction Sheet")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $createInstructionSheet)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .settingsFlatInputChrome(theme: theme, minHeight: 180)
                }

                HStack(spacing: 10) {
                    ToolbarCapsuleButton(
                        title: "Create Skill",
                        systemImage: "plus.circle",
                        role: .primaryAction,
                        chromePolicy: .alwaysSurface,
                        helpText: "Create skill",
                        accessibilityLabel: "Create skill"
                    ) {
                        Task { await createSkill(vaultPath: vaultPath) }
                    }
                    .disabled(
                        draft.identifier.isEmpty
                        || createDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || createInstructionSheet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    Text("Creates `skills/\(draft.identifier.isEmpty ? "skill-name" : draft.identifier)/SKILL.md`")
                        .font(.caption.monospaced())
                        .foregroundStyle(tertiaryTint)
                        .lineLimit(1)
                }

                if !draft.tags.isEmpty {
                    Text(draft.tags.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(tertiaryTint)
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(statusTint)
                }
            }
        }
    }

    @ViewBuilder
    private func installCard(vaultPath: String) -> some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    IntegrationBrandMarkView(
                        brand: .skillInstallSource(rawValue: installSource.rawValue),
                        size: 24
                    )
                    .foregroundStyle(mutedTint)
                    Text("Install Skill")
                        .font(.headline)
                }

                Picker("Source", selection: $installSource) {
                    ForEach(SkillInstallSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                TextField(installSource.placeholder, text: $installURL)
                    .settingsFlatInputChrome(theme: theme)

                if let proLockedMessage = installSource.proLockedMessage {
                    Label(proLockedMessage, systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(warningTint)
                }

                HStack(spacing: 10) {
                    ToolbarCapsuleButton(
                        title: "Install",
                        systemImage: "square.and.arrow.down",
                        role: .primaryAction,
                        chromePolicy: .alwaysSurface,
                        helpText: "Install skill",
                        accessibilityLabel: "Install skill"
                    ) {
                        Task { await installSkill(vaultPath: vaultPath) }
                    }
                    .disabled(
                        installURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !installSource.isUnlockedInCurrentBuild
                    )

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(statusTint)
                }
            }
        }
    }

    private var inventoryCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Installed Skills")
                        .font(.headline)
                    Spacer()
                    if isLoading {
                        ProgressView().controlSize(.small)
                    }
                    ToolbarCapsuleButton(
                        title: nil,
                        systemImage: "arrow.clockwise",
                        role: .toolbarUtility,
                        chromePolicy: .bareUntilPressed,
                        helpText: "Refresh installed skills",
                        accessibilityLabel: "Refresh installed skills"
                    ) {
                        Task { await refreshSkills() }
                    }
                }

                TextField("Search skills", text: $searchQuery)
                    .settingsFlatInputChrome(theme: theme, maxWidth: 320)

                if filteredSkills.isEmpty {
                    Text(skills.isEmpty ? "No skills registered yet." : "No skills match this search.")
                        .font(.caption)
                        .foregroundStyle(mutedTint)
                } else {
                    ForEach(filteredSkills) { skill in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 12) {
                                IntegrationBrandMarkView(
                                    brand: .skillInventory(
                                        identifier: skill.name,
                                        description: skill.description
                                    ),
                                    size: 24
                                )
                                .foregroundStyle(mutedTint)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(skill.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(skill.description)
                                        .font(.caption)
                                        .foregroundStyle(mutedTint)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                ChannelStatusPill(title: skill.version, tint: mutedTint)
                                ChannelStatusPill(title: "\(skill.useCount) runs", tint: infoTint)
                                ChannelStatusPill(
                                    title: skill.successRateLabel,
                                    tint: skill.successRate >= 0.8 ? successTint : warningTint
                                )
                            }
                            if skill.id != filteredSkills.last?.id {
                                skillSettingsRowGap()
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredSkills: [SkillInventoryEntry] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return skills }
        return skills.filter { skill in
            let blob = "\(skill.name) \(skill.description) \(skill.version)"
            return blob.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var filteredDiscoveredSkills: [SkillDiscoveryEntry] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return discoveredSkills }
        return discoveredSkills.filter { skill in
            let blob = [
                skill.identifier,
                skill.description,
                skill.category,
                skill.tags.joined(separator: " "),
                skill.source.title,
            ].joined(separator: " ")
            return blob.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private func refreshSkills() async {
        guard let vaultPath = vaultSync.vaultURL?.path else {
            skills = []
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            skills = try await loadSkills(vaultPath: vaultPath)
            statusMessage = nil
            statusIsError = false
        } catch {
            statusMessage = SkillsSettingsStatus.message(for: error, fallback: "Could not refresh skills.")
            statusIsError = true
        }
    }

    private func refreshDiscovery() {
        // Settings is the authoritative skill-management surface: force a fresh
        // disk walk so it always reflects ground truth, and repopulate the
        // app-side SkillDiscoveryCache the command-center hot path serves from.
        discoveredSkills = SkillDiscoveryCatalog.discoverSkillEntries(forceRefresh: true)
    }

    private func installSkill(vaultPath: String) async {
        let trimmedURL = installURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        guard installSource.isUnlockedInCurrentBuild else {
            statusMessage = installSource.proLockedMessage
            statusIsError = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let payload = try installSource.payload(url: trimmedURL)
            let response = try await callSkillManager(payload: payload, vaultPath: vaultPath)
            let outcome = SkillInstallOutcome(responseJSON: response)
            statusMessage = outcome.message
            statusIsError = !outcome.success
            if outcome.success {
                installURL = ""
                skills = try await loadSkills(vaultPath: vaultPath)
            }
        } catch {
            statusMessage = SkillsSettingsStatus.message(for: error, fallback: "Could not install skill.")
            statusIsError = true
        }
    }

    private func createSkill(vaultPath: String) async {
        let draft = SkillAuthoringDraft(
            title: createTitle,
            description: createDescription,
            category: createCategory,
            tagsText: createTags,
            instructionSheet: createInstructionSheet
        )

        isLoading = true
        defer { isLoading = false }

        do {
            let payload = try draft.createPayload()
            let response = try await callSkillManager(payload: payload, vaultPath: vaultPath)
            let outcome = SkillInstallOutcome(responseJSON: response)
            statusMessage = outcome.success
                ? SkillsSettingsStatus.message("Created \(draft.identifier).", fallback: "Skill created.")
                : outcome.message
            statusIsError = !outcome.success
            if outcome.success {
                resetCreateForm()
                skills = try await loadSkills(vaultPath: vaultPath)
                refreshDiscovery()
            }
        } catch {
            statusMessage = SkillsSettingsStatus.message(for: error, fallback: "Could not create skill.")
            statusIsError = true
        }
    }

    private func installDiscoveredSkill(_ skill: SkillDiscoveryEntry, vaultPath: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let payload: [String: Any] = [
                "action": "install_from_local_path",
                "path": skill.sourcePath,
                "name": skill.identifier,
                "approve": discoveryPhases[skill.id] == .quarantined,
            ]
            let response = try await callSkillManager(payload: payload, vaultPath: vaultPath)
            let outcome = SkillInstallOutcome(responseJSON: response)
            statusMessage = outcome.message
            statusIsError = !outcome.success
            if outcome.success {
                switch outcome.status {
                case "quarantined", "already_quarantined":
                    discoveryPhases[skill.id] = .quarantined
                default:
                    discoveryPhases[skill.id] = .installed
                    skills = try await loadSkills(vaultPath: vaultPath)
                }
            }
        } catch {
            statusMessage = SkillsSettingsStatus.message(for: error, fallback: "Could not import skill.")
            statusIsError = true
        }
    }

    private func discoveryActionLabel(for skill: SkillDiscoveryEntry) -> String {
        if isDiscoveredSkillInstalled(skill) {
            return "Installed"
        }
        switch discoveryPhases[skill.id] ?? .ready {
        case .ready:
            return "Import"
        case .quarantined:
            return "Promote"
        case .installed:
            return "Installed"
        }
    }

    private func discoveryActionSystemImage(for skill: SkillDiscoveryEntry) -> String {
        if isDiscoveredSkillInstalled(skill) {
            return "checkmark.circle"
        }
        switch discoveryPhases[skill.id] ?? .ready {
        case .ready:
            return "square.and.arrow.down"
        case .quarantined:
            return "arrow.up.doc"
        case .installed:
            return "checkmark.circle"
        }
    }

    private func isDiscoveredSkillInstalled(_ skill: SkillDiscoveryEntry) -> Bool {
        let installedNames = Set(skills.map(\.name))
        return installedNames.contains(skill.identifier)
    }

    private func resetCreateForm() {
        createTitle = ""
        createDescription = ""
        createCategory = "general"
        createTags = ""
        createInstructionSheet = ""
    }

    @ViewBuilder
    private func skillSettingsRowGap() -> some View {
        Color.clear.frame(height: 6)
    }
}

nonisolated enum SkillsSettingsStatus {
    static let maxStatusMessageCharacters = 360
    private static let maxDomainCharacters = 96
    private static let domainAllowedPunctuation = CharacterSet(charactersIn: "._-")

    static func message(_ value: String, fallback: String) -> String {
        let bounded = String(value.prefix(maxStatusMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = trimmed.isEmpty ? fallback : trimmed
        guard message.count > maxStatusMessageCharacters else {
            return message
        }
        return String(message.prefix(maxStatusMessageCharacters - 3)) + "..."
    }

    static func message(for error: Error, fallback: String) -> String {
        if let error = error as? SkillsSettingsError {
            return error.statusMessage(fallback: fallback)
        }
        let nsError = error as NSError
        let domain = safeDomain(nsError.domain)
        return message("\(fallback) (domain=\(domain) code=\(nsError.code))", fallback: fallback)
    }

    static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLikeCharacters = CharacterSet(charactersIn: "/\\:")
        guard trimmed.rangeOfCharacter(from: pathLikeCharacters) == nil else {
            return "Error"
        }
        let value = trimmed.isEmpty ? "Error" : trimmed
        guard value.unicodeScalars.allSatisfy({ scalar in
            CharacterSet.alphanumerics.contains(scalar) || domainAllowedPunctuation.contains(scalar)
        }) else {
            return "Error"
        }
        let clamped = String(value.prefix(maxDomainCharacters))
        return clamped.isEmpty ? "Error" : clamped
    }
}

private enum SkillInstallSource: String, CaseIterable, Identifiable {
    case github
    case rawURL
    case localPath

    var id: String { rawValue }

    static var defaultSource: SkillInstallSource {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        return .localPath
        #else
        return .github
        #endif
    }

    var title: String {
        switch self {
        case .github: "GitHub Repo"
        case .rawURL: "Raw SKILL.md"
        case .localPath: "Local Folder"
        }
    }

    var isUnlockedInCurrentBuild: Bool {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        switch self {
        case .github, .rawURL:
            return false
        case .localPath:
            return true
        }
        #else
        return true
        #endif
    }

    var proLockedMessage: String? {
        guard !isUnlockedInCurrentBuild else { return nil }
        return "Remote skill installs unlock in Pro. Local skill import remains available."
    }

    var placeholder: String {
        switch self {
        case .github: "https://github.com/org/repo"
        case .rawURL: "https://example.com/SKILL.md"
        case .localPath: "/path/to/skill-folder"
        }
    }

    func payload(url: String) throws -> [String: Any] {
        switch self {
        case .github:
            [
                "action": "install_from_github",
                "git_url": url,
            ]
        case .rawURL:
            [
                "action": "install_from_url",
                "url": url,
                "name": SkillDiscoveryCatalog.derivedIdentifier(forRemoteLocation: url),
            ]
        case .localPath:
            [
                "action": "install_from_local_path",
                "path": url,
                "name": SkillDiscoveryCatalog.derivedIdentifier(forLocalPath: url),
            ]
        }
    }
}

private enum SkillDiscoveryActionPhase {
    case ready
    case quarantined
    case installed
}

private struct SkillInventoryEntry: Identifiable, Hashable {
    let name: String
    let description: String
    let version: String
    let useCount: Int
    let successRate: Double

    var id: String { name }

    var successRateLabel: String {
        guard successRate.isFinite else { return "0%" }
        return "\(Int((successRate * 100).rounded()))%"
    }
}

private struct SkillInstallOutcome {
    let success: Bool
    let message: String
    let status: String?

    init(responseJSON: String) {
        guard let data = responseJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            self.success = false
            self.message = "Invalid skill manager response."
            self.status = nil
            return
        }

        let success = root["success"] as? Bool ?? false
        self.success = success
        self.status = root["status"] as? String
        if let error = root["error"] as? String, !error.isEmpty {
            self.message = SkillsSettingsStatus.message(error, fallback: "Skill install failed.")
        } else if let name = root["name"] as? String, !name.isEmpty {
            self.message = SkillsSettingsStatus.message(
                success ? "Installed \(name)." : "Failed to install \(name).",
                fallback: success ? "Skill installed." : "Skill install failed."
            )
        } else if let status = root["status"] as? String, status == "quarantined" || status == "already_quarantined" {
            let action = status == "already_quarantined" ? "ready to promote" : "imported to quarantine"
            self.message = "Skill \(action). Review it, then run the install again to promote it."
        } else if let message = root["message"] as? String, !message.isEmpty {
            self.message = SkillsSettingsStatus.message(message, fallback: success ? "Skill installed." : "Skill install failed.")
        } else {
            self.message = success ? "Skill installed." : "Skill install failed."
        }
    }
}

private func loadSkills(vaultPath: String) async throws -> [SkillInventoryEntry] {
    #if canImport(agent_coreFFI)
    return listRegisteredSkills(vaultPath: vaultPath).map { entry in
        SkillInventoryEntry(
            name: entry.name,
            description: entry.description,
            version: entry.version,
            useCount: Int(entry.useCount),
            successRate: entry.successRate
        )
    }
    #else
    return listRegisteredSkillsLocal(vaultPath: vaultPath).map { entry in
        SkillInventoryEntry(
            name: entry.name,
            description: entry.description,
            version: entry.version,
            useCount: Int(entry.useCount),
            successRate: entry.successRate
        )
    }
    #endif
}

private func callSkillManager(payload: [String: Any], vaultPath: String) async throws -> String {
    #if canImport(agent_coreFFI)
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    let inputJSON = String(data: data, encoding: .utf8) ?? "{}"
    let result = try await executeToolCall(
        vaultPath: vaultPath,
        tier: "agent",
        toolName: "skill_manage",
        inputJson: inputJSON
    )
    if let error = result.error, !error.isEmpty {
        throw SkillsSettingsError.toolError(error)
    }
    if !result.success {
        throw SkillsSettingsError.toolError("Skill manager failed.")
    }
    return result.outputJson
    #else
    throw SkillsSettingsError.bindingsUnavailable
    #endif
}

private enum SkillsSettingsError: LocalizedError {
    case bindingsUnavailable
    case toolError(String)

    var errorDescription: String? {
        switch self {
        case .bindingsUnavailable:
            "agent_core bindings unavailable"
        case .toolError(let message):
            message
        }
    }

    func statusMessage(fallback: String) -> String {
        switch self {
        case .bindingsUnavailable:
            return SkillsSettingsStatus.message("agent_core bindings unavailable", fallback: fallback)
        case .toolError(let message):
            return SkillsSettingsStatus.message(message, fallback: fallback)
        }
    }
}
