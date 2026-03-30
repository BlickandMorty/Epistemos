import SwiftUI

struct HermesAdminPanel: View {
    @Bindable var viewModel: HermesAdminViewModel
    @State private var selectedTab: AdminTab = .cron

    enum AdminTab: String, CaseIterable, Identifiable {
        case cron = "Cron Jobs"
        case mcp = "MCP Servers"
        case tools = "Tools"
        case config = "Config"
        case skills = "Skills"
        case diagnostics = "Diagnostics"

        var id: String { rawValue }

        var icon: String {
            switch self {
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
            case .cron: CronJobsSection(viewModel: viewModel)
            case .mcp: MCPServersSection(viewModel: viewModel)
            case .tools: ToolsSection(viewModel: viewModel)
            case .config: ConfigSection(viewModel: viewModel)
            case .skills: SkillsSection(viewModel: viewModel)
            case .diagnostics: DiagnosticsSection(viewModel: viewModel)
            }
        }
        .task {
            viewModel.refreshAll()
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(viewModel.mcpServers.count) servers")
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
                ForEach(viewModel.mcpServers) { server in
                    MCPServerRow(server: server, viewModel: viewModel)
                }

                if viewModel.mcpServers.isEmpty {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(viewModel.installedSkills.count) skills")
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

        List {
            ForEach(viewModel.installedSkills) { skill in
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.body.weight(.medium))
                    Text(skill.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contextMenu {
                    Button("Remove", role: .destructive) {
                        viewModel.removeSkill(name: skill.name)
                    }
                }
            }

            if viewModel.installedSkills.isEmpty {
                ContentUnavailableView(
                    "No Skills Installed",
                    systemImage: "sparkles.rectangle.stack",
                    description: Text("Skills extend Hermes with reusable capabilities. Install them via the runtime.")
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

private struct InstallSkillSheet: View {
    let viewModel: HermesAdminViewModel
    @Binding var isPresented: Bool
    @State private var skillName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install Skill")
                .font(.headline)
            TextField("Skill name or path", text: $skillName)
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                Button("Install") {
                    viewModel.installSkill(name: skillName)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(skillName.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
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
