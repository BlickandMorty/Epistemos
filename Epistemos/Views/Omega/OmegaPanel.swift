import SwiftUI

// MARK: - Agent Runtime Panel

struct AgentRuntimePermissionRequirements: Equatable, Sendable {
    let needsAccessibility: Bool
    let needsScreenRecording: Bool
    let needsAutomation: Bool

    var requiresAny: Bool {
        needsAccessibility || needsScreenRecording || needsAutomation
    }

    static func forContext(taskDescription: String, plannedSteps: [AgentStep]) -> AgentRuntimePermissionRequirements {
        if !plannedSteps.isEmpty {
            return fromToolNames(plannedSteps.map(\.toolName))
        }
        return fromTaskDescription(taskDescription)
    }

    private static func fromToolNames(_ toolNames: [String]) -> AgentRuntimePermissionRequirements {
        let names = Set(toolNames.map { $0.lowercased() })
        let needsAccessibility = !names.intersection(accessibilityTools).isEmpty
        let needsScreenRecording = !names.intersection(screenRecordingTools).isEmpty
        let needsAutomation = !names.intersection(automationTools).isEmpty

        return AgentRuntimePermissionRequirements(
            needsAccessibility: needsAccessibility,
            needsScreenRecording: needsScreenRecording,
            needsAutomation: needsAutomation
        )
    }

    private static func fromTaskDescription(_ taskDescription: String) -> AgentRuntimePermissionRequirements {
        let lower = taskDescription.lowercased()
        guard !lower.isEmpty else {
            return AgentRuntimePermissionRequirements(
                needsAccessibility: false,
                needsScreenRecording: false,
                needsAutomation: false
            )
        }

        let mentionsScreenCapture = containsAny(lower, matches: [
            "screenshot", "screen shot", "screen capture", "capture screen",
            "read the screen", "analyze the screen", "vision", "ocr"
        ])
        let mentionsAutomation = containsAny(lower, matches: [
            "click ", "press ", "type ", "select ", "toggle ", "open menu",
            "menu bar", "button", "window", "shortcut", "hotkey", "ui automation"
        ])
        let mentionsAccessibilityOnly = containsAny(lower, matches: [
            "ui tree", "ax tree", "accessibility tree"
        ])

        return AgentRuntimePermissionRequirements(
            needsAccessibility: mentionsAutomation || mentionsAccessibilityOnly,
            needsScreenRecording: mentionsScreenCapture,
            needsAutomation: mentionsAutomation
        )
    }

    private static func containsAny(_ text: String, matches: [String]) -> Bool {
        matches.contains { text.contains($0) }
    }

    private static let accessibilityTools: Set<String> = [
        "get_ui_tree", "click_element", "type_text", "press_key"
    ]

    private static let screenRecordingTools: Set<String> = [
        "screenshot", "capture_screen", "screen_ocr", "screen_capture"
    ]

    private static let automationTools: Set<String> = [
        "click_element", "type_text", "press_key", "run_shortcut"
    ]
}

/// Top-level local agent runtime interface. Shows task input, execution progress, and history.
struct AgentRuntimePanel: View {
    @Environment(OrchestratorState.self) private var orchestrator

    @State private var taskInput = ""
    @State private var permissions = OmegaPermissions()

    private var permissionRequirements: AgentRuntimePermissionRequirements {
        AgentRuntimePermissionRequirements.forContext(
            taskDescription: orchestrator.currentTaskDescription,
            plannedSteps: orchestrator.taskGraph.steps
        )
    }

    private var shouldShowPermissionBanner: Bool {
        let requirements = permissionRequirements
        guard requirements.requiresAny else { return false }

        if requirements.needsAccessibility && !permissions.accessibilityGranted {
            return true
        }
        if requirements.needsScreenRecording && !permissions.screenRecordingGranted {
            return true
        }
        if requirements.needsAutomation && !permissions.automationGranted {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.blue)
                Text("Agent Runtime")
                    .font(.title2.bold())
                Spacer()
                statusBadge
                if orchestrator.isExecuting {
                    Button("Cancel") {
                        orchestrator.cancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()

            Divider()

            // Main content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Permission banner (shown when permissions are missing)
                    if shouldShowPermissionBanner {
                        permissionBanner
                    }

                    // Model loading indicator (cold start ~2-5s)
                    if orchestrator.isModelLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Loading AI model…")
                                    .font(.subheadline.bold())
                                Text("First inference takes 2-5 seconds")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Planning indicator
                    if orchestrator.isPlanning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 14, height: 14)
                            Text("Planning: \(orchestrator.currentTaskDescription)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Planning method badge
                    if !orchestrator.planningMethod.isEmpty && !orchestrator.isPlanning {
                        HStack(spacing: 6) {
                            Image(systemName: orchestrator.planningMethod.contains("AI") ? "brain" : "arrow.triangle.branch")
                                .font(.caption)
                            Text(orchestrator.planningMethod)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    // Planning error
                    if let error = orchestrator.planningError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if orchestrator.liveRuntime.hasContent {
                        liveRuntimeView
                    }

                    // Execution progress (when active or has results)
                    if orchestrator.isExecuting || !orchestrator.executionLog.isEmpty {
                        ExecutionProgressView()
                    }

                    // Confirmation sheet (when pending)
                    if orchestrator.confirmationGate.pendingConfirmation != nil {
                        ConfirmationSheet()
                    }

                    // Research pause (when active)
                    if orchestrator.researchPause.isPaused {
                        ResearchRequestView()
                    }

                    // Idle state
                    if !orchestrator.isExecuting && !orchestrator.isPlanning
                        && orchestrator.executionLog.isEmpty && orchestrator.planningError == nil {
                        idleView
                    }
                }
                .padding()
            }

            Divider()

            // Task input bar — pre-fill when returning from Edit Plan
            TaskInputBar(text: $taskInput) {
                guard !taskInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                let task = taskInput
                taskInput = ""
                Task {
                    await orchestrator.submitTask(task)
                }
            }
            .onChange(of: orchestrator.taskGraph.status) {
                // Pre-fill input when user taps "Edit Plan" (idle + preserved description)
                if orchestrator.taskGraph.status == .idle,
                   !orchestrator.currentTaskDescription.isEmpty,
                   taskInput.isEmpty {
                    taskInput = orchestrator.currentTaskDescription
                }
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let status = orchestrator.taskGraph.status
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text(status.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(_ status: TaskGraphStatus) -> Color {
        switch status {
        case .idle: .secondary
        case .planning: .orange
        case .awaitingConfirmation: .yellow
        case .executing: .blue
        case .completed: .green
        case .failed: .red
        case .paused: .purple
        }
    }

    @ViewBuilder
    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Agent Runtime")
                .font(.headline)
            Text("Enter a task below. The local agent runtime uses on-device AI to plan multi-step workflows and execute them through specialist agents.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Quick action suggestions
            VStack(spacing: 8) {
                Text("Try:")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                quickActionButton("Open Safari and go to apple.com")
                quickActionButton("List files in my vault")
                quickActionButton("Search the web for MLX benchmarks")
                quickActionButton("Create a new note")
                quickActionButton("research: transformer attention vs Mamba-2")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private var liveRuntimeView: some View {
        let currentPhase = orchestrator.liveRuntime.currentPhase

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: currentPhase?.kind.iconName ?? "waveform.path.ecg.rectangle")
                    .foregroundStyle(liveRuntimePhaseColor(currentPhase?.kind ?? .idle))
                Text("Live Runtime")
                    .font(.subheadline.bold())
                Spacer()
                if let currentPhase {
                    Text(currentPhase.kind.title)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(liveRuntimePhaseColor(currentPhase.kind).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let currentPhase, !currentPhase.detail.isEmpty {
                Text(currentPhase.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let turn = orchestrator.liveRuntime.lastTurn,
                      !turn.assistantText.isEmpty {
                Text(turn.assistantText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !orchestrator.liveRuntime.phaseHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(orchestrator.liveRuntime.phaseHistory.suffix(6))) { phase in
                            Text(phase.kind.title)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(liveRuntimePhaseColor(phase.kind).opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if !orchestrator.liveRuntime.transcriptPath.isEmpty {
                Text(orchestrator.liveRuntime.transcriptPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(liveRuntimePhaseColor(currentPhase?.kind ?? .idle).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func liveRuntimePhaseColor(_ kind: OmegaLiveRuntimeState.PhaseSnapshot.Kind) -> Color {
        switch kind {
        case .idle: .secondary
        case .planning: .orange
        case .thinking, .reasoning: .blue
        case .searching: .teal
        case .executing: .indigo
        case .awaitingApproval: .yellow
        case .responding: .mint
        case .complete: .green
        case .failed: .red
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        let requirements = permissionRequirements

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
                Text("Permissions Required")
                    .font(.subheadline.bold())
            }

            if requirements.needsAccessibility && !permissions.accessibilityGranted {
                permissionRow(
                    name: "Accessibility",
                    detail: "Required for UI automation and AX tree walking",
                    granted: false
                ) {
                    permissions.openAccessibilitySettings()
                }
            }

            if requirements.needsScreenRecording && !permissions.screenRecordingGranted {
                permissionRow(
                    name: "Screen Recording",
                    detail: "Required for screen capture and visual analysis",
                    granted: false
                ) {
                    permissions.openScreenRecordingSettings()
                }
            }

            if requirements.needsAutomation && !permissions.automationGranted {
                VStack(alignment: .leading, spacing: 6) {
                    permissionRow(
                        name: "Automation",
                        detail: "Apple Events control of System Events for desktop automation",
                        granted: false,
                        buttonTitle: "Request Access"
                    ) {
                        Task { await permissions.requestAutomationAccess() }
                    }

                    Text("Safari browser automation may ask separately on first use.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("Open Automation Settings") {
                        permissions.openAutomationSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }

            Button("Refresh") {
                Task { await permissions.refresh() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task { await permissions.refresh() }
    }

    private func permissionRow(
        name: String,
        detail: String,
        granted: Bool,
        buttonTitle: String = "Open Settings",
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption.bold())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(buttonTitle) {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
    }

    private func quickActionButton(_ text: String) -> some View {
        Button {
            taskInput = ""
            Task {
                await orchestrator.submitTask(text)
            }
        } label: {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
