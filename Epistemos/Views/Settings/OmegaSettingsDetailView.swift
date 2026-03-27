import SwiftUI

// MARK: - Omega Settings Detail View

/// Settings panel for the Omega agent system.
/// Configures: model routing, agent behavior, permissions, training preferences.
struct OmegaSettingsDetailView: View {
    @Environment(OrchestratorState.self) private var orchestrator

    @State private var permissions = OmegaPermissions()
    @AppStorage("omega.autoExecuteLowRisk") private var autoExecuteLowRisk = true
    @AppStorage("omega.maxRetries") private var maxRetries = 3
    @AppStorage("omega.screen2axEnabled") private var screen2axEnabled = true
    @AppStorage("omega.overnightTraining") private var overnightTraining = false
    @AppStorage("omega.terminalAllowList") private var terminalAllowList = "ls,cat,head,tail,grep,find,wc,echo,date,pwd,which"

    var body: some View {
        Form {
            // MARK: - Agent Behavior
            Section("Agent Behavior") {
                Toggle("Auto-execute low-risk actions", isOn: $autoExecuteLowRisk)
                    .help("When enabled, LOW risk tool calls execute without confirmation.")

                Stepper("Max retries per tool call: \(maxRetries)", value: $maxRetries, in: 1...10)
                    .help("Failed tool calls retry with exponential backoff (0.2s base).")
            }

            // MARK: - Terminal Safety
            Section("Terminal Agent") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allowed Commands")
                        .font(.subheadline.bold())
                    TextField("Comma-separated command allow-list", text: $terminalAllowList)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                    Text("Only these base commands can be executed. Empty = default safe list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Permissions
            Section("Permissions") {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    PermissionStatusBadge(granted: permissions.accessibilityGranted)
                    if !permissions.accessibilityGranted {
                        Button("Grant") { permissions.openAccessibilitySettings() }
                            .buttonStyle(.bordered).controlSize(.mini)
                    }
                }

                HStack {
                    Text("Screen Recording")
                    Spacer()
                    PermissionStatusBadge(granted: permissions.screenRecordingGranted)
                    if !permissions.screenRecordingGranted {
                        Button("Grant") { permissions.openScreenRecordingSettings() }
                            .buttonStyle(.bordered).controlSize(.mini)
                    }
                }

                Button("Refresh Permissions") {
                    Task { await permissions.refresh() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .task { await permissions.refresh() }

            // MARK: - Perception
            Section("Perception") {
                Toggle("Screen2AX Vision OCR enrichment", isOn: $screen2axEnabled)
                    .help("When AX tree is sparse (<10 interactive elements), enrich with Vision OCR.")
            }

            // MARK: - Training
            Section("Training") {
                Toggle("Overnight autoresearch", isOn: $overnightTraining)
                    .help("Run ~100 hyperparameter experiments overnight when idle and on power.")

                HStack {
                    Text("Execution traces logged")
                    Spacer()
                    Text("—") // Would show count from omega-mcp SQLite
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Agents
            Section("Registered Agents") {
                ForEach(Array(orchestrator.agents.keys.sorted()), id: \.self) { name in
                    if let agent = orchestrator.agents[name] {
                        HStack {
                            Image(systemName: agentIcon(name))
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text(name.capitalized)
                                    .font(.subheadline)
                                Text(agent.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(agent.toolNames.count) tools")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Omega")
    }

    private func agentIcon(_ name: String) -> String {
        switch name {
        case "safari": "safari"
        case "file": "folder"
        case "notes": "note.text"
        case "terminal": "terminal"
        case "automation": "gearshape.2"
        default: "cpu"
        }
    }
}

// MARK: - Permission Status Badge

private struct PermissionStatusBadge: View {
    let granted: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(granted ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(granted ? "Granted" : "Not Granted")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
