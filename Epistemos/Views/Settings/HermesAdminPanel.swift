import SwiftUI

struct HermesAdminPanel: View {
    @Bindable var viewModel: HermesAdminViewModel
    @State private var selectedTab: AdminTab = .marketplace

    enum AdminTab: String, CaseIterable, Identifiable {
        case marketplace = "Marketplace"
        case skills = "Skills"
        case mcp = "MCP Servers"
        case tools = "Tools"
        case cron = "Cron Jobs"
        case config = "Config"
        case diagnostics = "Diagnostics"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .marketplace: "storefront"
            case .cron: "clock.arrow.circlepath"
            case .mcp: "server.rack"
            case .tools: "wrench.and.screwdriver"
            case .config: "slider.horizontal.3"
            case .skills: "sparkles.rectangle.stack"
            case .diagnostics: "stethoscope"
            }
        }
    }

    var body: some View {
        if viewModel.isSubprocessRunning {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text("Hermes Runtime Admin")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Refresh All") {
                        viewModel.refreshAll()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Picker("Section", selection: $selectedTab) {
                    ForEach(AdminTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                if let error = viewModel.lastError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Dismiss") { viewModel.lastError = nil }
                            .buttonStyle(.plain)
                            .font(.caption)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }

                Divider()

                switch selectedTab {
                case .marketplace: MarketplaceSection(viewModel: viewModel)
                case .cron: CronJobsSection(viewModel: viewModel)
                case .mcp: MCPServersSection(viewModel: viewModel)
                case .tools: ToolsSection(viewModel: viewModel)
                case .config: ConfigSection(viewModel: viewModel)
                case .skills: SkillsSection(viewModel: viewModel)
                case .diagnostics: DiagnosticsSection(viewModel: viewModel)
                }
            }
            .task {
                if viewModel.isSubprocessRunning {
                    viewModel.refreshAll()
                }
            }
        } else {
            ContentUnavailableView(
                "Hermes Runtime Offline",
                systemImage: "bolt.horizontal.circle",
                description: Text("The Hermes runtime is not connected. Start an agent session to activate the runtime.")
            )
        }
    }
}

// MARK: - Marketplace

private struct MarketplaceSection: View {
    @Bindable var viewModel: HermesAdminViewModel

    private var installedMCPNames: Set<String> {
        Set(viewModel.mcpServers.map(\.name))
    }

    private var featuredSkills: [HubSkillEntry] {
        let names = Set(viewModel.featuredSkillNames)
        return viewModel.availableSkills.filter { names.contains($0.name) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Featured MCP Servers
                if !viewModel.featuredMCPServers.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundStyle(.blue)
                            Text("MCP Servers")
                                .font(.headline)
                            Spacer()
                            Text("One-click install")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Extend your agent with tools from the MCP ecosystem")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                        ], spacing: 12) {
                            ForEach(viewModel.featuredMCPServers) { server in
                                MarketplaceMCPCard(
                                    server: server,
                                    isInstalled: installedMCPNames.contains(server.name),
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                }

                Divider()

                // Featured Skills
                if !featuredSkills.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkles.rectangle.stack")
                                .foregroundStyle(.purple)
                            Text("Featured Skills")
                                .font(.headline)
                            Spacer()
                        }

                        Text("Curated skills for common workflows")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(featuredSkills) { skill in
                            AvailableSkillRow(skill: skill, viewModel: viewModel)
                                .padding(.vertical, 4)
                        }
                    }
                }

                Divider()

                // Registries
                if !viewModel.mcpRegistries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.teal)
                            Text("Discover More")
                                .font(.headline)
                            Spacer()
                        }

                        Text("Browse community registries for thousands of MCP servers and tools")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(viewModel.mcpRegistries) { registry in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(registry.name)
                                        .font(.body.weight(.medium))
                                    Text(registry.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let destination = URL(string: registry.url) {
                                    Link(destination: destination) {
                                        Label("Open", systemImage: "arrow.up.right.square")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                } else {
                                    Label("Invalid URL", systemImage: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Empty state
                if viewModel.featuredMCPServers.isEmpty && featuredSkills.isEmpty {
                    ContentUnavailableView(
                        "Marketplace Loading",
                        systemImage: "storefront",
                        description: Text("Start an agent session to load the marketplace catalog.")
                    )
                }
            }
            .padding(20)
        }
    }
}

private struct MarketplaceMCPCard: View {
    let server: FeaturedMCPServer
    let isInstalled: Bool
    let viewModel: HermesAdminViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(server.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if server.isOfficial {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            Text(server.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxHeight: .infinity, alignment: .top)

            HStack {
                Text(server.category)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
                    .foregroundStyle(.secondary)
                Spacer()
                if isInstalled {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Button("Add") {
                        viewModel.installFeaturedMCPServer(server)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
    }
}

// MARK: - Cron Jobs

private struct CronJobsSection: View {
    @Bindable var viewModel: HermesAdminViewModel
    @State private var showCreateSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(viewModel.cronJobs.count) jobs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Label("New Job", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            List {
                ForEach(viewModel.cronJobs) { job in
                    CronJobRow(job: job, viewModel: viewModel)
                }

                if viewModel.cronJobs.isEmpty {
                    ContentUnavailableView(
                        "No Cron Jobs",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Create a scheduled job to run tasks automatically.")
                    )
                }
            }
            .listStyle(.inset)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCronJobSheet(viewModel: viewModel, isPresented: $showCreateSheet)
        }
    }
}

private struct CronJobRow: View {
    let job: CronJobEntry
    let viewModel: HermesAdminViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text(job.state)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(job.enabled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12))
                    )
                    .foregroundStyle(job.enabled ? .green : .secondary)
            }
            Text(job.schedule)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(job.prompt)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .contextMenu {
            if job.enabled {
                Button("Pause") { viewModel.pauseCronJob(id: job.id) }
            } else {
                Button("Resume") { viewModel.resumeCronJob(id: job.id) }
            }
            Button("Run Now") { viewModel.runCronJob(id: job.id) }
            Divider()
            Button("Remove", role: .destructive) { viewModel.removeCronJob(id: job.id) }
        }
    }
}

private struct CreateCronJobSheet: View {
    let viewModel: HermesAdminViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var schedule = "daily"
    @State private var prompt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Cron Job")
                .font(.headline)

            TextField("Name", text: $name)
            TextField("Schedule (cron or 'daily', 'hourly', etc.)", text: $schedule)
            TextField("Prompt", text: $prompt, axis: .vertical)
                .lineLimit(3...6)

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                Button("Create") {
                    viewModel.createCronJob(name: name, schedule: schedule, prompt: prompt)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
    }
}

// MARK: - MCP Servers

private struct MCPServersSection: View {
    @Bindable var viewModel: HermesAdminViewModel
    @State private var showAddSheet = false

    private var installedNames: Set<String> {
        Set(viewModel.mcpServers.map(\.name))
    }

    private var suggestedServers: [FeaturedMCPServer] {
        viewModel.featuredMCPServers.filter { !installedNames.contains($0.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(viewModel.mcpServers.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            List {
                if !viewModel.mcpServers.isEmpty {
                    Section("Active Servers") {
                        ForEach(viewModel.mcpServers) { server in
                            MCPServerRow(server: server, viewModel: viewModel)
                        }
                    }
                }

                if !suggestedServers.isEmpty {
                    Section("Suggested") {
                        ForEach(suggestedServers) { server in
                            SuggestedMCPRow(server: server, viewModel: viewModel)
                        }
                    }
                }

                if viewModel.mcpServers.isEmpty && suggestedServers.isEmpty {
                    ContentUnavailableView(
                        "No MCP Servers",
                        systemImage: "server.rack",
                        description: Text("Add MCP servers to extend Hermes with external tools.")
                    )
                }
            }
            .listStyle(.inset)
        }
        .sheet(isPresented: $showAddSheet) {
            AddMCPServerSheet(viewModel: viewModel, isPresented: $showAddSheet)
        }
    }
}

private struct SuggestedMCPRow: View {
    let server: FeaturedMCPServer
    let viewModel: HermesAdminViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(server.displayName)
                        .font(.body.weight(.medium))
                    if server.isOfficial {
                        Text("Official")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                            .foregroundStyle(.green)
                    }
                }
                Text(server.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let env = server.envHint {
                    Text("Requires \(env)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Button("Add") {
                viewModel.installFeaturedMCPServer(server)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

private struct MCPServerRow: View {
    let server: MCPServerEntry
    let viewModel: HermesAdminViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(server.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text(server.transportType)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
                    .foregroundStyle(.blue)
            }
            if let command = server.command {
                Text(command)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let url = server.url {
                Text(url)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button("Remove", role: .destructive) {
                viewModel.removeMCPServer(name: server.name)
            }
        }
    }
}

private struct AddMCPServerSheet: View {
    let viewModel: HermesAdminViewModel
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var transportType = "stdio"
    @State private var command = ""
    @State private var url = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add MCP Server")
                .font(.headline)

            TextField("Server Name", text: $name)

            Picker("Transport", selection: $transportType) {
                Text("stdio").tag("stdio")
                Text("HTTP").tag("http")
            }
            .pickerStyle(.segmented)

            if transportType == "stdio" {
                TextField("Command (e.g. npx -y @modelcontextprotocol/server-filesystem)", text: $command)
            } else {
                TextField("URL (e.g. https://my-mcp-server.example.com/mcp)", text: $url)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                Button("Add") {
                    if transportType == "stdio" {
                        let parts = command.components(separatedBy: " ")
                        let cmd = parts.first ?? command
                        let args = parts.count > 1 ? Array(parts.dropFirst()) : []
                        viewModel.addMCPServer(name: name, command: cmd, args: args)
                    } else {
                        viewModel.addMCPServer(name: name, url: url)
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || (transportType == "stdio" ? command.isEmpty : url.isEmpty))
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}

// MARK: - Tools

private struct ToolsSection: View {
    @Bindable var viewModel: HermesAdminViewModel

    var body: some View {
        List {
            ForEach(viewModel.toolsets) { toolset in
                HStack {
                    Text(toolset.name)
                        .font(.body)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { toolset.enabled },
                        set: { viewModel.toggleToolset(name: toolset.name, enabled: $0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }

            if viewModel.toolsets.isEmpty {
                ContentUnavailableView(
                    "No Toolsets",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Tool configuration will appear here once the runtime loads.")
                )
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Config

private struct ConfigSection: View {
    @Bindable var viewModel: HermesAdminViewModel

    var body: some View {
        List {
            ForEach(viewModel.configEntries) { entry in
                HStack {
                    Text(entry.key)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.value)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }

            if viewModel.configEntries.isEmpty {
                ContentUnavailableView(
                    "No Config",
                    systemImage: "slider.horizontal.3",
                    description: Text("Configuration will load once the Hermes runtime connects.")
                )
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Skills

private struct SkillsSection: View {
    @Bindable var viewModel: HermesAdminViewModel
    @State private var showInstallSheet = false
    @State private var searchText = ""
    @State private var selectedCategory = "all"

    private var categories: [String] {
        let cats = Set(viewModel.availableSkills.map(\.category))
        return ["all"] + cats.sorted()
    }

    private var filteredSkills: [HubSkillEntry] {
        var skills = viewModel.availableSkills
        if selectedCategory != "all" {
            skills = skills.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            skills = skills.filter {
                $0.name.localizedCaseInsensitiveContains(q) ||
                $0.description.localizedCaseInsensitiveContains(q) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(q) }
            }
        }
        return skills
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(viewModel.installedSkills.count) installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(viewModel.availableSkillsTotal) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showInstallSheet = true
                } label: {
                    Label("Install Skill", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Search + category filter
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search skills...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat == "all" ? "All" : cat.replacingOccurrences(of: "-", with: " ").capitalized)
                                .font(.caption.weight(selectedCategory == cat ? .bold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(selectedCategory == cat ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 8)

            List {
                if !viewModel.installedSkills.isEmpty && searchText.isEmpty && selectedCategory == "all" {
                    Section("Installed") {
                        ForEach(viewModel.installedSkills) { skill in
                            InstalledSkillRow(skill: skill, viewModel: viewModel)
                        }
                    }
                }

                let available = filteredSkills.filter { !$0.installed }
                if !available.isEmpty {
                    Section("Available (\(available.count))") {
                        ForEach(available) { skill in
                            AvailableSkillRow(skill: skill, viewModel: viewModel)
                        }
                    }
                }

                let installed = filteredSkills.filter(\.installed)
                if !installed.isEmpty && (searchText.isEmpty == false || selectedCategory != "all") {
                    Section("Installed (\(installed.count))") {
                        ForEach(installed) { skill in
                            AvailableSkillRow(skill: skill, viewModel: viewModel)
                        }
                    }
                }

                if filteredSkills.isEmpty && viewModel.installedSkills.isEmpty {
                    ContentUnavailableView(
                        "No Skills Found",
                        systemImage: "sparkles.rectangle.stack",
                        description: Text("Start an agent session to load the skills catalog.")
                    )
                }
            }
            .listStyle(.inset)
        }
        .sheet(isPresented: $showInstallSheet) {
            InstallSkillSheet(viewModel: viewModel, isPresented: $showInstallSheet)
        }
    }
}

private struct InstalledSkillRow: View {
    let skill: HermesSkillEntry
    let viewModel: HermesAdminViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.body.weight(.medium))
                    if !skill.version.isEmpty {
                        Text("v\(skill.version)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.12)))
                            .foregroundStyle(.blue)
                    }
                }
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { skill.enabled },
                set: { viewModel.toggleSkill(name: skill.name, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .contextMenu {
            Button("Remove", role: .destructive) {
                viewModel.removeSkill(name: skill.name)
            }
        }
    }
}

private struct AvailableSkillRow: View {
    let skill: HubSkillEntry
    let viewModel: HermesAdminViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.body.weight(.medium))
                    Text(skill.sourceLabel)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(sourceColor(skill.source).opacity(0.12)))
                        .foregroundStyle(sourceColor(skill.source))
                }
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !skill.tags.isEmpty {
                    Text(skill.tags.prefix(4).joined(separator: " \u{00B7} "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if skill.installed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Install") {
                    viewModel.installSkill(name: skill.name)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private func sourceColor(_ source: String) -> Color {
        switch source {
        case "bundled": .green
        case "optional": .blue
        case "user": .purple
        default: .secondary
        }
    }
}

private struct InstallSkillSheet: View {
    let viewModel: HermesAdminViewModel
    @Binding var isPresented: Bool

    enum InstallType: String, CaseIterable, Identifiable {
        case name = "Name"
        case url = "GitHub URL"
        case localPath = "Local Path"

        var id: String { rawValue }
    }

    @State private var installType: InstallType = .name
    @State private var skillName = ""
    @State private var gitURL = ""
    @State private var localPath = ""

    private var canInstall: Bool {
        switch installType {
        case .name: !skillName.isEmpty
        case .url: !gitURL.isEmpty
        case .localPath: !localPath.isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install Skill")
                .font(.headline)

            Picker("Install From", selection: $installType) {
                ForEach(InstallType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            switch installType {
            case .name:
                TextField("Skill name (e.g. web-search, code-review)", text: $skillName)
            case .url:
                TextField("Git URL (e.g. https://github.com/org/hermes-skill-example.git)", text: $gitURL)
            case .localPath:
                TextField("Local path (e.g. ~/hermes-skills/my-skill)", text: $localPath)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                Button("Install") {
                    switch installType {
                    case .name:
                        viewModel.installSkill(name: skillName)
                    case .url:
                        viewModel.installSkillFromURL(url: gitURL)
                    case .localPath:
                        viewModel.installSkillFromURL(url: localPath)
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canInstall)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}

// MARK: - Diagnostics

private struct DiagnosticsSection: View {
    @Bindable var viewModel: HermesAdminViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Update status
                GroupBox("Update") {
                    if let status = viewModel.updateStatus {
                        HStack {
                            Image(systemName: status.updateAvailable ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(status.updateAvailable ? .blue : .green)
                            Text(status.updateAvailable
                                 ? "Update available (\(status.commitsBehind) commits behind)"
                                 : "Up to date")
                            Spacer()
                            Text("v\(status.hermesVersion)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Not checked")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Check") { viewModel.checkForUpdates() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }

                // Doctor results
                if let diag = viewModel.diagnostics {
                    GroupBox("Runtime") {
                        VStack(alignment: .leading, spacing: 6) {
                            diagRow("Python", "\(diag.pythonVersion)")
                            diagRow("Hermes", "v\(diag.hermesVersion)")
                            diagRow("Git", diag.gitRevision)
                            diagRow("Home", diag.hermesHome)
                            if let free = diag.diskFreeGB {
                                diagRow("Disk Free", "\(free) GB")
                            }
                        }
                    }

                    GroupBox("State Directories") {
                        VStack(alignment: .leading, spacing: 6) {
                            stateRow("Config", diag.configExists)
                            stateRow("Skills (\(diag.skillCount))", diag.skillsDirExists)
                            stateRow("Memories", diag.memoriesDirExists)
                            stateRow("Sessions", diag.sessionsDirExists)
                            stateRow("Cron (\(diag.cronJobCount) jobs)", diag.cronDirExists)
                            stateRow("MCP (\(diag.mcpServerCount) servers)", true)
                        }
                    }

                    GroupBox("Dependencies") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(diag.dependencies.sorted(by: { $0.key < $1.key }), id: \.key) { dep, ok in
                                HStack {
                                    Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(ok ? .green : .red)
                                        .font(.caption)
                                    Text(dep)
                                        .font(.caption.monospaced())
                                    Spacer()
                                }
                            }
                        }
                    }
                } else {
                    GroupBox("Doctor") {
                        HStack {
                            Text("Run diagnostics to inspect the Hermes runtime.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }

                // Logs
                GroupBox("Recent Logs") {
                    if viewModel.recentLogs.isEmpty {
                        HStack {
                            Text("No logs loaded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Fetch") { viewModel.fetchLogs() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.recentLogs.suffix(30).enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Run Diagnostics") { viewModel.runDiagnostics() }
                        .buttonStyle(.borderedProminent)
                    Button("Fetch Logs") { viewModel.fetchLogs() }
                        .buttonStyle(.bordered)
                    Button("Check Updates") { viewModel.checkForUpdates() }
                        .buttonStyle(.bordered)
                    Spacer()
                }
            }
            .padding(20)
        }
    }

    private func diagRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func stateRow(_ label: String, _ exists: Bool) -> some View {
        HStack {
            Image(systemName: exists ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(exists ? .green : .orange)
                .font(.caption)
            Text(label)
                .font(.caption)
            Spacer()
        }
    }
}
