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
    /// Defaults to false — training never runs unless user explicitly opts in.
    @AppStorage("omega.overnightTraining") private var overnightTraining = false
    @AppStorage("omega.embodiedCapture") private var embodiedCapture = false
    @AppStorage("omega.terminalAllowList") private var terminalAllowList = "ls,cat,head,tail,grep,find,wc,echo,date,pwd,which"

    var body: some View {
        Form {
            SettingsDescriptionCard(
                title: "What Omega Does",
                systemImage: "cpu.fill",
                text: "Omega is the app's tool-using layer for research, browsing, notes, terminal tasks, and desktop actions. It does not run hidden background research by itself. Research starts when you explicitly ask for it or submit a task that routes into Omega."
            )

            // MARK: - Agent Behavior
            Section("Agent Behavior") {
                SettingsDescriptionText(
                    text: "These controls decide how independently Omega can act once you have already put it on a task."
                )
                Toggle("Auto-execute low-risk actions", isOn: $autoExecuteLowRisk)
                    .help("When enabled, LOW risk tool calls execute without confirmation.")

                SettingsDescriptionText(
                    text: "When enabled, Omega can continue through obviously safe steps without pausing on each one. Higher-risk actions should still require an explicit permission or confirmation boundary."
                )

                Stepper("Max retries per tool call: \(maxRetries)", value: $maxRetries, in: 1...10)
                    .help("Failed tool calls retry with exponential backoff (0.2s base).")

                SettingsDescriptionText(
                    text: "Retries help with flaky page loads, temporary UI misses, and short-lived tool failures. Raising this too far can make a bad plan loop longer before surfacing the error."
                )
            }

            // MARK: - Terminal Safety
            Section("Terminal Agent") {
                SettingsDescriptionText(
                    text: "Terminal access stays constrained by a base-command allow-list so Omega can do useful shell work without becoming unrestricted shell control."
                )
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
                SettingsDescriptionText(
                    text: "Omega uses standard macOS permissions for accessibility, screen understanding, and Apple Events automation. Grant only what you want the app to control."
                )
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

                HStack {
                    Text("Automation")
                    Spacer()
                    PermissionStatusBadge(granted: permissions.automationGranted)
                    if !permissions.automationGranted {
                        Button("Request") {
                            Task { await permissions.requestAutomationAccess() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Button("Settings") {
                            permissions.openAutomationSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }

                Text("Apple Events control of System Events for desktop automation. Safari browser automation may ask separately on first use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Refresh Permissions") {
                    Task { await permissions.refresh() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .task { await permissions.refresh() }

            // MARK: - Perception
            Section("Perception") {
                SettingsDescriptionText(
                    text: "Perception settings control how Omega sees the current app. Accessibility data stays the first choice; Vision OCR only fills gaps when UI structure is too sparse."
                )
                Toggle("Screen2AX Vision OCR enrichment", isOn: $screen2axEnabled)
                    .help("When AX tree is sparse (<10 interactive elements), enrich with Vision OCR.")

                SettingsDescriptionText(
                    text: "This is for better grounding during desktop tasks. It is not a hidden browser crawler or autonomous research system."
                )
            }

            // MARK: - Training
            Section("Training") {
                SettingsDescriptionText(
                    text: "These experimental switches affect adapter-improvement workflows and trace collection. They do not turn on an always-running autonomous research agent."
                )
                Toggle("Overnight adapter training (Experimental)", isOn: $overnightTraining)
                    .help("Run ~100 hyperparameter experiments overnight when idle and on power.")

                SettingsDescriptionText(
                    text: "Overnight adapter training uses collected preference signals to try small background training runs while the Mac is idle and on power. It is about adapter personalization, not automatic web research."
                )

                Toggle("Embodied data capture (Experimental)", isOn: $embodiedCapture)
                    .help("Capture AX tree snapshots and screenshots around Omega actions for experimental trace collection.")

                SettingsDescriptionText(
                    text: "Embodied capture records trace context around Omega actions so future automation and training can be debugged and improved more honestly."
                )

                HStack {
                    Text("Execution traces logged")
                    Spacer()
                    Text("\(orchestrator.mcpBridge?.executionCount ?? 0)")
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Agents
            Section("Registered Agents") {
                SettingsDescriptionText(
                    text: "These are the live specialist agents currently exposed through Omega. Tool counts show how much surface area each agent can control."
                )
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
