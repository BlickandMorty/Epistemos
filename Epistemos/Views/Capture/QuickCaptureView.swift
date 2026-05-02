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

    /// Cheap client-side preview of what the AFM @Generable extraction
    /// will probably surface — counts hashtags, @-mentions, and lines
    /// starting with "- [ ]" so the user sees structured chips
    /// updating in real time as they type. The authoritative parse
    /// still happens in TextCapturePipeline on submit.
    private var previewSignals: PreviewSignals {
        PreviewSignals(text: captureText)
    }

    private var headerSubtitle: String {
        if isProcessing {
            return "Structuring your thought…"
        }
        if isTranscribing {
            return "Transcribing dictation…"
        }
        if audioRecorder.isRecording {
            return "Recording — speak naturally"
        }
        if captureText.isEmpty {
            return "Brain dump → structured note + entities + tasks"
        }
        let signals = previewSignals
        if signals.totalSignals > 0 {
            var parts: [String] = []
            if signals.hashtagCount > 0 { parts.append("\(signals.hashtagCount) tag\(signals.hashtagCount == 1 ? "" : "s")") }
            if signals.mentionCount > 0 { parts.append("\(signals.mentionCount) mention\(signals.mentionCount == 1 ? "" : "s")") }
            if signals.taskCount > 0 { parts.append("\(signals.taskCount) task\(signals.taskCount == 1 ? "" : "s")") }
            return "Detected · " + parts.joined(separator: " · ")
        }
        return "Cmd-Return to capture · Esc to cancel"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()
                .opacity(0.3)

            // Content
            if let result = captureResult {
                confirmationCard(result)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.97).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                captureForm
                    .transition(.opacity)
            }
        }
        .frame(width: 540, height: captureResult != nil ? 380 : 360)
        .background {
            // Layered backdrop: ultraThin material + subtle accent
            // wash + soft inner highlight. Gives the sheet a sense of
            // depth without crossing into App-Store-rejecting custom
            // chrome — every layer is a stock SwiftUI primitive.
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.12),
                            Color.accentColor.opacity(0.02),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .blendMode(.plusLighter)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.30), radius: 40, y: 14)
        .animation(reduceMotion ? .none : .smooth(duration: 0.32), value: captureResult != nil)
        .onAppear {
            isTextFieldFocused = true
        }
        .sheet(isPresented: $isTraceInspectorPresented) {
            TraceInspectorView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Animated SF Symbol with hierarchical rendering — pulses
            // gently on the accent color so the capture surface feels
            // alive without crossing into "demo gimmick" territory.
            Image(systemName: "sparkles.text.rectangle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .font(.title3)
                .symbolEffect(
                    .pulse.byLayer,
                    options: reduceMotion ? .nonRepeating : .repeating.speed(0.5)
                )

            VStack(alignment: .leading, spacing: 0) {
                Text("Quick Capture")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(headerSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.identity)
            }

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

            // Structured preview strip — surfaces what the AFM
            // @Generable extractor will likely produce, computed
            // client-side as the user types so the structuring
            // promise is visible BEFORE submit. Authoritative
            // extraction still happens in TextCapturePipeline on
            // submit (creates the SDPage, runs entity extraction,
            // graph writes). Empty when there's nothing to show.
            if !captureText.isEmpty {
                let signals = previewSignals
                if signals.totalSignals > 0 {
                    structuredPreviewStrip(signals)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            // Action bar
            HStack {
                Text("\(captureText.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .monospacedDigit()

                Spacer()

                // Audio Capture Button — pulses red while recording so
                // the user has an unmistakable visual signal beyond
                // text. SF Symbols' .symbolEffect(.pulse) ships native
                // on macOS 14+ so no custom CA work needed.
                Button {
                    Task { await toggleAudioRecording() }
                } label: {
                    HStack(spacing: 6) {
                        if isTranscribing {
                            ProgressView().controlSize(.small)
                            Text("Transcribing...")
                        } else if audioRecorder.isRecording {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundStyle(.red)
                                .symbolEffect(
                                    .variableColor.iterative.reversing,
                                    options: reduceMotion ? .nonRepeating : .repeating
                                )
                            Text("Stop")
                        } else {
                            Image(systemName: "mic.circle.fill")
                                .foregroundStyle(.tint)
                            Text("Dictate")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(audioRecorder.isRecording
                                  ? Color.red.opacity(0.15)
                                  : Color.secondary.opacity(0.2))
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

    // MARK: - Structured preview strip

    @ViewBuilder
    private func structuredPreviewStrip(_ signals: PreviewSignals) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if signals.taskCount > 0 {
                    structuredChip(icon: "checklist", text: "\(signals.taskCount) task\(signals.taskCount == 1 ? "" : "s")", tint: .orange)
                }
                if signals.hashtagCount > 0 {
                    structuredChip(icon: "tag.fill", text: "\(signals.hashtagCount) tag\(signals.hashtagCount == 1 ? "" : "s")", tint: .purple)
                }
                if signals.mentionCount > 0 {
                    structuredChip(icon: "at", text: "\(signals.mentionCount) mention\(signals.mentionCount == 1 ? "" : "s")", tint: .blue)
                }
                if signals.urlCount > 0 {
                    structuredChip(icon: "link", text: "\(signals.urlCount) URL\(signals.urlCount == 1 ? "" : "s")", tint: .teal)
                }
                if signals.dateHintCount > 0 {
                    structuredChip(icon: "calendar", text: "\(signals.dateHintCount) date hint\(signals.dateHintCount == 1 ? "" : "s")", tint: .green)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private func structuredChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tint.opacity(0.15))
                .overlay(Capsule().strokeBorder(tint.opacity(0.30), lineWidth: 0.5))
        )
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
            guard result.mutationEnvelopePersisted else {
                throw TextCaptureError.persistenceFailed("mutation envelope was not persisted")
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
                guard result.mutationEnvelopePersisted else {
                    throw TextCaptureError.persistenceFailed("mutation envelope was not persisted")
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

// MARK: - PreviewSignals
//
// Cheap client-side scan that mirrors what the AFM @Generable
// extractor + entity extractor will likely emit. Surfaced as the
// vibrant chip strip above the action bar so the user sees the
// "structured note + entities + tasks" promise updating in real
// time while typing — instead of waiting for the post-submit
// confirmation card.

private struct PreviewSignals {
    let hashtagCount: Int
    let mentionCount: Int
    let taskCount: Int
    let urlCount: Int
    let dateHintCount: Int

    var totalSignals: Int { hashtagCount + mentionCount + taskCount + urlCount + dateHintCount }

    init(text: String) {
        guard !text.isEmpty else {
            self.hashtagCount = 0
            self.mentionCount = 0
            self.taskCount = 0
            self.urlCount = 0
            self.dateHintCount = 0
            return
        }
        // Scan once; count every signal in a single pass for efficiency
        // — typing-fast users hit this on every keystroke.
        var hashtags = 0
        var mentions = 0
        var tasks = 0
        var urls = 0
        var dateHints = 0
        let lower = text
        // Hashtags: \B#word OR start-of-string #word; cheap split on '#'.
        for (idx, comp) in lower.split(separator: "#").enumerated() where idx > 0 {
            if let first = comp.first, first.isLetter || first.isNumber {
                hashtags += 1
            }
        }
        for (idx, comp) in lower.split(separator: "@").enumerated() where idx > 0 {
            if let first = comp.first, first.isLetter {
                mentions += 1
            }
        }
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("* [ ]") || trimmed.hasPrefix("TODO") || trimmed.hasPrefix("[ ]") {
                tasks += 1
            }
        }
        // URL hint — substring "http" anywhere.
        var search = text[...]
        while let r = search.range(of: "http", options: .literal) {
            urls += 1
            search = search[r.upperBound...]
        }
        // Date hints — common natural-language dates.
        let dateNeedles = ["tomorrow", "today", "tonight", "next week", "monday", "tuesday",
                           "wednesday", "thursday", "friday", "saturday", "sunday",
                           "jan ", "feb ", "mar ", "apr ", "may ", "jun ",
                           "jul ", "aug ", "sep ", "oct ", "nov ", "dec "]
        let lowerCased = lower.lowercased()
        for needle in dateNeedles where lowerCased.contains(needle) {
            dateHints += 1
        }
        self.hashtagCount = hashtags
        self.mentionCount = mentions
        self.taskCount = tasks
        self.urlCount = urls
        self.dateHintCount = dateHints
    }
}
