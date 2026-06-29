import SwiftData
import SwiftUI

@MainActor
struct MeetingNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var voiceInput: LiveVoiceInputService
    @State private var service: MeetingNoteCaptureService
    @State private var isSaving = false
    @State private var showingDiscardConfirmation = false

    init(voiceInput: LiveVoiceInputService = .shared) {
        _voiceInput = State(initialValue: voiceInput)
        _service = State(initialValue: MeetingNoteCaptureService(voiceInput: voiceInput))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            ScrollView {
                Text(transcriptDisplayText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(service.transcriptText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.72))

            Divider()

            footer
        }
        .frame(minWidth: 520, minHeight: 420)
        .onChange(of: voiceInput.partialTranscript) { _, _ in
            service.refreshFromVoiceInput()
        }
        .onChange(of: voiceInput.finalTranscript) { _, _ in
            service.refreshFromVoiceInput()
        }
        .onDisappear {
            service.stop()
        }
        .confirmationDialog(
            "Discard meeting transcript?",
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Transcript", role: .destructive) {
                service.discard()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the current transcript without creating a meeting note.")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            IntegrationBrandMarkView(brand: .meetingNote, size: 20)
                .foregroundStyle(.secondary)
            Text("Meeting Note")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(stateLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Button {
                toggleRecording()
            } label: {
                Label(recordingButtonTitle, systemImage: isRecording ? "stop.circle.fill" : "mic.circle")
            }
            .disabled(isSaving || isFinalizing)
            Button {
                save()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(isSaving || service.transcriptText.isEmpty)
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
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                showingDiscardConfirmation = true
            } label: {
                Label("Discard", systemImage: "trash")
            }
            .disabled(isSaving || service.transcriptText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var transcriptDisplayText: String {
        service.transcriptText.isEmpty ? "Transcript will appear here." : service.transcriptText
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

    private var recordingButtonTitle: String {
        isRecording ? "Stop" : "Start"
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
        case .saved:
            return "Saved"
        case .error(let message):
            return message
        }
    }

    private var durationLabel: String {
        let seconds = service.durationSeconds
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func toggleRecording() {
        if isRecording {
            service.stop()
        } else {
            Task {
                await service.start()
            }
        }
    }

    private func save() {
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
        .frame(width: 700, height: 560)
}
#endif
