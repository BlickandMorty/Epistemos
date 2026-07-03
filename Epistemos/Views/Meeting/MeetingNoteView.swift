import SwiftData
import SwiftUI

@MainActor
struct MeetingNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UIState.self) private var ui
    @State private var voiceInput: LiveVoiceInputService
    @State private var service: MeetingNoteCaptureService
    @State private var isSaving = false
    @State private var showingDiscardConfirmation = false
    @State private var pendingStartAfterDiscardConfirmation = false
    @State private var showingHomeLeaveConfirmation = false

    init(voiceInput: LiveVoiceInputService = .shared) {
        _voiceInput = State(initialValue: voiceInput)
        _service = State(initialValue: MeetingNoteCaptureService(voiceInput: voiceInput))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            ScrollView {
                Text(transcriptDisplayText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(
                        service.transcriptText.isEmpty
                            ? ui.theme.resolved.mutedForeground.color
                            : ui.theme.resolved.foreground.color
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(transcriptSurfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 14)

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ui.theme.resolved.background.color.opacity(ui.theme.isDark ? 0.92 : 0.96))
        .onChange(of: voiceInput.partialTranscript) { _, _ in
            service.refreshFromVoiceInput()
        }
        .onChange(of: voiceInput.finalTranscript) { _, _ in
            service.refreshFromVoiceInput()
        }
        .onDisappear {
            service.tearDownCapture()
        }
        .confirmationDialog(
            "Discard meeting transcript?",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(discardConfirmationActionTitle, role: .destructive) {
                let shouldStart = pendingStartAfterDiscardConfirmation
                pendingStartAfterDiscardConfirmation = false
                service.discard()
                if shouldStart {
                    Task {
                        await service.start()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingStartAfterDiscardConfirmation = false
            }
        } message: {
            Text("This clears the current transcript without creating a meeting note.")
        }
        .onChange(of: showingDiscardConfirmation) { _, isPresented in
            if !isPresented {
                pendingStartAfterDiscardConfirmation = false
            }
        }
        .confirmationDialog(
            "Leave without saving?",
            isPresented: $showingHomeLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard & leave", role: .destructive) {
                service.discard()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                    ui.homeContent = .greeting
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This meeting has an unsaved transcript. Leaving clears it without creating a note.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            ToolbarCapsuleButton(
                title: nil,
                systemImage: "house",
                role: .secondaryGhost,
                helpText: "Back to home",
                accessibilityLabel: "Back to home"
            ) {
                goHome()
            }
            IntegrationBrandMarkView(brand: .meetingNote, size: 20)
                .foregroundStyle(ui.theme.resolved.mutedForeground.color)
            Text("Meeting Note")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(stateLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ui.theme.resolved.mutedForeground.color)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 220, alignment: .trailing)
                .help(stateLabel)
            ToolbarCapsuleButton(
                title: recordingButtonTitle,
                systemImage: recordingButtonSystemImage,
                role: isRecording ? .toolbarUtility : .primaryAction,
                chromePolicy: .alwaysSurface
            ) {
                toggleRecording()
            }
            .disabled(isSaving || isFinalizing || isPreparing)
            ToolbarCapsuleButton(
                title: "Save",
                systemImage: "square.and.arrow.down",
                role: .primaryAction,
                chromePolicy: .alwaysSurface
            ) {
                save()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let progress = service.modelDownloadProgress {
                ProgressView(value: progress)
                    .frame(width: 120)
            }
            Text(durationLabel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(ui.theme.resolved.mutedForeground.color)
            Spacer()
            ToolbarCapsuleButton(
                title: "Discard",
                systemImage: "trash",
                role: .secondaryGhost,
                chromePolicy: .bareUntilPressed
            ) {
                pendingStartAfterDiscardConfirmation = false
                showingDiscardConfirmation = true
            }
            .disabled(!canDiscard)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var transcriptDisplayText: String {
        service.transcriptText.isEmpty ? "Transcript will appear here." : service.transcriptText
    }

    private var transcriptSurfaceBackground: some ShapeStyle {
        ui.theme.resolved.foreground.color.opacity(ui.theme.isDark ? 0.055 : 0.035)
    }

    private var isRecording: Bool {
        if case .recording = service.state {
            return true
        }
        return false
    }

    private var isFinalizing: Bool {
        if case .finalizing = service.state {
            return true
        }
        return false
    }

    private var isPreparing: Bool {
        if case .preparing = service.state {
            return true
        }
        return false
    }

    private var isSaved: Bool {
        if case .saved = service.state {
            return true
        }
        return false
    }

    private var canSave: Bool {
        !isSaving && !isFinalizing && !isSaved && !service.transcriptText.isEmpty
    }

    private var canDiscard: Bool {
        !isSaving && !isFinalizing && !isSaved && !service.transcriptText.isEmpty
    }

    private var shouldConfirmBeforeStartingNewCapture: Bool {
        !isSaved && !service.transcriptText.isEmpty
    }

    private var discardConfirmationActionTitle: String {
        pendingStartAfterDiscardConfirmation ? "Discard and Start" : "Discard Transcript"
    }

    private var recordingButtonTitle: String {
        if isPreparing {
            return "Preparing"
        }
        return isRecording ? "Stop" : "Start"
    }

    private var recordingButtonSystemImage: String {
        if isPreparing {
            return "hourglass.circle"
        }
        return isRecording ? "stop.circle.fill" : "mic.circle"
    }

    private var stateLabel: String {
        switch service.state {
        case .idle:
            return "Ready"
        case .preparing:
            return "Preparing"
        case .recording:
            return "Recording"
        case .finalizing:
            return "Saving"
        case .saved(_, let title):
            return VoiceCapturePresentationBounds.statusMessage("Saved note: \(title)")
        case .error(let message):
            return message
        }
    }

    private var durationLabel: String {
        let seconds = service.durationSeconds
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func goHome() {
        if isRecording || canDiscard {
            showingHomeLeaveConfirmation = true
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                ui.homeContent = .greeting
            }
        }
    }

    private func toggleRecording() {
        guard !isPreparing else { return }
        if isRecording {
            service.stop()
        } else if shouldConfirmBeforeStartingNewCapture {
            pendingStartAfterDiscardConfirmation = true
            showingDiscardConfirmation = true
        } else {
            Task {
                await service.start()
            }
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                _ = try await service.finalize(modelContext: modelContext)
            } catch {
                // MeetingNoteCaptureService owns the user-facing error state.
            }
        }
    }
}

#if DEBUG
#Preview("MeetingNoteView") {
    MeetingNoteView()
        .modelContainer(for: [SDPage.self, SDGraphNode.self, SDGraphEdge.self, SDBlock.self], inMemory: true)
        .environment(UIState())
        .frame(width: 700, height: 560)
}
#endif
