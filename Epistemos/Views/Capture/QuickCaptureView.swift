import SwiftData
import SwiftUI

// MARK: - Phase 6.5: Quick Capture View
//
// Keyboard-first app-scoped capture sheet that routes text through TextCapturePipeline.
// Summoned via the Epistemos ⌘⇧N command. Produces structured note, entities,
// tasks, graph writes, source spans, evidence, and trace events.
//
// Design: Glass-effect sheet, minimal chrome, focus on the text field.
// After submit: brief confirmation card showing title, entity/task counts,
// with explicit buttons to open the note or dismiss the sheet.

@MainActor
struct QuickCaptureView: View {
    @Environment(TextCapturePipeline.self) private var pipeline
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var captureText = ""
    @State private var isProcessing = false
    @State private var captureResult: CaptureResult?
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    @State private var audioRecorder = AudioRecorder()
    @State private var transcriber = AudioTranscriber()
    @State private var isTranscribing = false
    @State private var isTraceInspectorPresented = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .opacity(0.3)

            // Content
            if let result = captureResult {
                confirmationCard(result)
            } else {
                captureForm
            }
        }
        .frame(width: 520, height: captureResult != nil ? 340 : 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
        .onAppear {
            isTextFieldFocused = true
        }
        .sheet(isPresented: $isTraceInspectorPresented) {
            TraceInspectorView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "sparkles.text.rectangle")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Quick Capture")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            #if DEBUG
            // Internal capture-trace inspector is a developer debug surface
            // (shows pipeline lifecycle events like GRAPH_WRITE_ATTEMPTED).
            // Hidden from Release builds — users shouldn't see "gimmick"
            // debug diagnostics from their capture window.
            Button {
                isTraceInspectorPresented = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("View Trace & Run History (debug)")
            .padding(.trailing, 4)
            #endif

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Capture Form

    private var captureForm: some View {
        VStack(spacing: 16) {
            // Text input
            TextEditor(text: $captureText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.background.opacity(0.5))
                )
                .focused($isTextFieldFocused)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    if captureText.isEmpty {
                        Text("Capture a thought, meeting note, idea...")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 17)
                            .padding(.top, 20)
                            .allowsHitTesting(false)
                    }
                }

            // Error message
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Action bar
            HStack {
                Text("\(captureText.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .monospacedDigit()

                Spacer()

                // Audio Capture Button
                Button {
                    Task { await toggleAudioRecording() }
                } label: {
                    HStack(spacing: 6) {
                        if isTranscribing {
                            ProgressView().controlSize(.small)
                            Text("Transcribing...")
                        } else if audioRecorder.isRecording {
                            Image(systemName: "stop.circle.fill").foregroundStyle(.red)
                            Text("Stop")
                        } else {
                            Image(systemName: "mic.circle.fill")
                            Text("Dictate")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.2))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || isTranscribing)

                Button {
                    Task { await submitCapture() }
                } label: {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        Text("Capture")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.accentColor.opacity(0.3)
                                : Color.accentColor)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Confirmation Card

    private func confirmationCard(_ result: CaptureResult) -> some View {
        VStack(spacing: 16) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
                .padding(.top, 8)

            // Title
            Text(result.title)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Stats grid
            HStack(spacing: 24) {
                statBadge(
                    icon: "person.2",
                    count: result.entities.count,
                    label: "Entities"
                )
                statBadge(
                    icon: "checklist",
                    count: result.tasks.count,
                    label: "Tasks"
                )
                statBadge(
                    icon: "link",
                    count: result.sourceSpans.count,
                    label: "Spans"
                )
                statBadge(
                    icon: result.graphWriteSummary.noteNodeCreated
                        ? "point.3.connected.trianglepath.dotted"
                        : "xmark.circle",
                    count: result.graphWriteSummary.edgesCreated,
                    label: "Graph"
                )
            }
            .padding(.vertical, 8)

            // Evidence Chips
            if !result.entities.isEmpty || !result.tasks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(result.entities, id: \.text) { entity in
                            evidenceChip(text: entity.text, icon: "tag.fill", role: entity.sourceSpan.role)
                        }
                        ForEach(result.tasks, id: \.text) { task in
                            taskActionChip(task: task)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxHeight: 40)
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                if let noteId = result.createdNoteID {
                    Button {
                        NoteWindowManager.shared.open(pageId: noteId)
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text("Open Note")
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func evidenceChip(text: String, icon: String, role: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .lineLimit(1)
            Text(role)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private func taskActionChip(task: ExtractedTask) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")
                .font(.system(size: 10))
            Text(task.text)
                .lineLimit(1)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Stat Badge

    private func statBadge(icon: String, count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Submit

    private func submitCapture() async {
        let trimmed = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isProcessing = true
        errorMessage = nil

        do {
            let result = try await pipeline.run(
                rawText: captureText,
                modelContext: modelContext
            )
            guard result.createdNoteID != nil else {
                throw TextCaptureError.persistenceFailed(
                    result.graphWriteSummary.skippedReason ?? "note was not persisted"
                )
            }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
                captureResult = result
            }
        } catch let error as TextCaptureError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Capture failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    // MARK: - Audio Processing
    private func toggleAudioRecording() async {
        if audioRecorder.isRecording {
            guard let url = audioRecorder.stopRecording() else { return }
            isTranscribing = true
            errorMessage = nil
            do {
                let transcription = try await transcriber.transcribe(audioURL: url)
                let result = try await pipeline.runFromAudio(transcription: transcription, modelContext: modelContext)
                guard result.createdNoteID != nil else {
                    throw TextCaptureError.persistenceFailed(
                        result.graphWriteSummary.skippedReason ?? "note was not persisted"
                    )
                }
                withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
                    captureResult = result
                }
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
            }
            isTranscribing = false
        } else {
            if !audioRecorder.isMicrophoneAuthorized {
                let granted = await audioRecorder.requestPermission()
                if !granted {
                    errorMessage = "Microphone access is required to dictate."
                    return
                }
            }
            do {
                try audioRecorder.startRecording()
            } catch {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
}
