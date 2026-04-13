import SwiftUI

struct SkillsDetailView: View {
    @Environment(VaultSyncService.self) private var vaultSync

    @State private var skills: [SkillInventoryEntry] = []
    @State private var discoveredSkills: [SkillDiscoveryEntry] = []
    @State private var isLoading = false
    @State private var installURL: String = ""
    @State private var installSource: SkillInstallSource = .github
    @State private var searchQuery: String = ""
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var discoveryPhases: [String: SkillDiscoveryActionPhase] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                discoveryCard(vaultPath: vaultSync.vaultURL?.path)

                if let vaultPath = vaultSync.vaultURL?.path {
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
                    .foregroundStyle(.secondary)

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
                    Button("Refresh") {
                        refreshDiscovery()
                    }
                }

                TextField("Search discovered and installed skills", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 360)

                if filteredDiscoveredSkills.isEmpty {
                    Text(discoveredSkills.isEmpty ? "No discovery sources found yet." : "No discovery matches this search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredDiscoveredSkills.prefix(18)) { skill in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(skill.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(skill.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                ChannelStatusPill(title: skill.source.title, tint: .blue)
                                ChannelStatusPill(title: skill.category.capitalized, tint: .secondary)
                            }

                            if !skill.tags.isEmpty {
                                Text(skill.tags.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            HStack(spacing: 10) {
                                Button(discoveryActionLabel(for: skill)) {
                                    guard let vaultPath else { return }
                                    Task { await installDiscoveredSkill(skill, vaultPath: vaultPath) }
                                }
                                .disabled(vaultPath == nil || isDiscoveredSkillInstalled(skill))

                                Text(skill.sourcePath)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }

                        if skill.id != filteredDiscoveredSkills.prefix(18).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func installCard(vaultPath: String) -> some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Install Skill")
                    .font(.headline)

                Picker("Source", selection: $installSource) {
                    ForEach(SkillInstallSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                TextField(installSource.placeholder, text: $installURL)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Button("Install") {
                        Task { await installSkill(vaultPath: vaultPath) }
                    }
                    .disabled(installURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(statusIsError ? .orange : .green)
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
                    Button {
                        Task { await refreshSkills() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }

                TextField("Search skills", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)

                if filteredSkills.isEmpty {
                    Text(skills.isEmpty ? "No skills registered yet." : "No skills match this search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredSkills) { skill in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(skill.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(skill.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                ChannelStatusPill(title: skill.version, tint: .secondary)
                                ChannelStatusPill(title: "\(skill.useCount) runs", tint: .blue)
                                ChannelStatusPill(
                                    title: skill.successRateLabel,
                                    tint: skill.successRate >= 0.8 ? .green : .orange
                                )
                            }
                            Divider()
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
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func refreshDiscovery() {
        discoveredSkills = SkillDiscoveryCatalog.discoverSkillEntries()
    }

    private func installSkill(vaultPath: String) async {
        let trimmedURL = installURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

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
            statusMessage = error.localizedDescription
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
            statusMessage = error.localizedDescription
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

    private func isDiscoveredSkillInstalled(_ skill: SkillDiscoveryEntry) -> Bool {
        let installedNames = Set(skills.map(\.name))
        return installedNames.contains(skill.identifier)
    }
}

private enum SkillInstallSource: String, CaseIterable, Identifiable {
    case github
    case rawURL
    case localPath

    var id: String { rawValue }

    var title: String {
        switch self {
        case .github: "GitHub Repo"
        case .rawURL: "Raw SKILL.md"
        case .localPath: "Local Folder"
        }
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
            self.message = error
        } else if let name = root["name"] as? String, !name.isEmpty {
            self.message = success ? "Installed \(name)." : "Failed to install \(name)."
        } else if let status = root["status"] as? String, status == "quarantined" || status == "already_quarantined" {
            let action = status == "already_quarantined" ? "ready to promote" : "imported to quarantine"
            self.message = "Skill \(action). Review it, then run the install again to promote it."
        } else if let message = root["message"] as? String, !message.isEmpty {
            self.message = message
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
}
