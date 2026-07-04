import AppKit
import SwiftData
import SwiftUI

nonisolated enum QuickCaptureDiagnostics {
    static let maxStatusMessageCharacters = 240
    private static let maxDomainCharacters = 80

    static func statusMessage(for error: Error, fallback: String = "Capture failed") -> String {
        if let captureError = error as? TextCaptureError {
            return statusMessage(for: captureError, fallback: fallback)
        }

        let nsError = error as NSError
        return statusMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func statusMessage(for error: TextCaptureError, fallback: String = "Capture failed") -> String {
        switch error {
        case .emptyCapture:
            return statusMessage("Capture text is empty after cleaning.", fallback: fallback)
        case .persistenceFailed:
            return statusMessage("Note persistence failed.", fallback: fallback)
        case .graphUnavailable:
            return statusMessage("Graph write unavailable.", fallback: fallback)
        }
    }

    static func statusMessage(_ message: String, fallback: String = "Capture failed") -> String {
        let bounded = String(message.prefix(maxStatusMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxStatusMessageCharacters else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(
            trimmed.startIndex,
            offsetBy: max(0, maxStatusMessageCharacters - suffix.count)
        )
        return String(trimmed[..<end]) + suffix
    }

    private static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= maxDomainCharacters else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: maxDomainCharacters)
            return String(trimmed[..<end])
        }
        return trimmed
    }
}

// MARK: - Phase 6.5: Quick Capture View
//
// Keyboard-first landing command overlay that routes text through TextCapturePipeline.
// Summoned via the Epistemos ⌘⇧N command. Produces structured note, entities,
// tasks, graph writes, source spans, evidence, and trace events.
//
// Design: pixel-panel overlay, minimal chrome, focus on the text field.
// After submit: brief confirmation card showing title, entity/task counts,
// with explicit buttons to open the note or dismiss the overlay.

@MainActor
struct QuickCaptureView: View {
    @Environment(UIState.self) private var ui
    @Environment(TextCapturePipeline.self) private var pipeline
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool

    @State private var captureText = ""
    /// GAP-27: clipboard text detected on appear (opt-in paste); nil when empty/too long.
    @State private var clipboardText: String?
    @State private var isProcessing = false
    @State private var captureResult: CaptureResult?
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    @State private var audioRecorder = AudioRecorder()
    @State private var transcriber = AudioTranscriber()
    @State private var isTranscribing = false
    @State private var isTraceInspectorPresented = false
    @State private var appearFrame = 0
    // SS-QC (D) auto read-back: debounce task + last-spoken dedup (so a paused-typing
    // sentence is read once, never repeatedly). Only active when the pref is .auto.
    @State private var readBackTask: Task<Void, Never>?
    @State private var lastSpokenSentence = ""
    private var theme: EpistemosTheme { ui.theme }

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
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Don't discard an in-progress capture on a stray click
                    // outside the 540pt panel — a typed brain-dump would be lost
                    // with no draft/undo. Empty captures dismiss freely; the
                    // explicit Esc / close button remains the deliberate cancel.
                    if captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        close()
                    }
                }

            VStack(spacing: 0) {
                header

                Divider()
                    .opacity(0.3)

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
            .pixelPanel(theme: theme)
            .pixelStepAppear(frame: appearFrame)
            .foregroundStyle(theme.resolved.foreground.color)

            #if DEBUG
            if isTraceInspectorPresented {
                traceInspectorOverlay
                    .transition(.scale(scale: 0.97).combined(with: .opacity))
                    .zIndex(3)
            }
            #endif
        }
        .background {
            Button(action: { close() }) {}
                .keyboardShortcut(.escape, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .animation(reduceMotion ? .none : .smooth(duration: 0.32), value: captureResult != nil)
        .animation(reduceMotion ? .none : .smooth(duration: 0.24), value: isTraceInspectorPresented)
        .onAppear {
            Task { @MainActor in
                await PixelStepMotion.play(reduceMotion: reduceMotion) { frame in
                    appearFrame = frame
                }
            }
            isTextFieldFocused = true
            // GAP-27: detect clipboard text once, for the opt-in paste affordance.
            if let clip = NSPasteboard.general.string(forType: .string),
               !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               clip.count <= 20_000 {
                clipboardText = clip
            } else {
                clipboardText = nil
            }
        }
        .onDisappear {
            cleanupTransientCaptureState()
        }
        .onChange(of: captureText) { _, newValue in
            scheduleQuickCaptureReadBack(for: newValue)
        }
    }

    #if DEBUG
    private var traceInspectorOverlay: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    isTraceInspectorPresented = false
                }

            TraceInspectorView(theme: theme, onDismiss: {
                isTraceInspectorPresented = false
            })
            .frame(width: 470, height: 330)
        }
    }
    #endif

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            PixelGlyph(kind: .capture, accent: theme.resolved.accent.color)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 0) {
                PixelPanelTitle(text: "Quick Capture", theme: theme, size: 15)
                Text(headerSubtitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
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
                close()
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
                .background {
                    ZStack {
                        Rectangle()
                            .fill(.regularMaterial)
                        Rectangle()
                            .fill(PixelPanelBackground.actionSurface(for: theme).opacity(theme.isDark ? 0.76 : 0.82))
                    }
                }
                .overlay {
                    Rectangle()
                        .stroke(theme.textTertiary.opacity(theme.isDark ? 0.28 : 0.34), lineWidth: 1)
                }
                .focused($isTextFieldFocused)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    if captureText.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Capture a thought, meeting note, idea...")
                                .foregroundStyle(.tertiary)
                                .allowsHitTesting(false)
                            // GAP-27 (audit 2026-07-03): opt-in clipboard paste (no auto-seed,
                            // no preview) — turns "copy anywhere → Quick Capture" into a note.
                            if let clip = clipboardText {
                                Button {
                                    captureText = clip
                                    isTextFieldFocused = true
                                } label: {
                                    Label("Paste clipboard", systemImage: "doc.on.clipboard")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 17)
                        .padding(.top, 14)
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
                    .background {
                        ZStack {
                            Rectangle()
                                .fill(.regularMaterial)
                            Rectangle()
                                .fill(audioRecorder.isRecording
                                      ? Color.red.opacity(0.16)
                                      : PixelPanelBackground.actionSurface(for: theme).opacity(0.84))
                        }
                    }
                    .overlay {
                        Rectangle()
                            .stroke(theme.border.opacity(theme.isDark ? 0.24 : 0.34), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || isTranscribing)

                // Plan 3 owner update 2026-06-30: TTS is Kokoro-only. The
                // read-aloud affordance remains visible but disabled until
                // native Kokoro synthesis is wired; no Apple voice picker or
                // AVSpeech fallback is surfaced here.
                ReadAloudButton(
                    text: EpistemosSpeechSynthesizer.plainTextForSpeech(fromMarkdown: captureText),
                    style: .iconWithProgress
                )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background {
                        Rectangle()
                            .fill(PixelPanelBackground.actionSurface(for: theme).opacity(0.84))
                    }
                    .overlay {
                        Rectangle()
                            .stroke(theme.border.opacity(theme.isDark ? 0.24 : 0.34), lineWidth: 1)
                    }
                    .help("Read the captured text aloud")

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
                    .background {
                        ZStack {
                            Rectangle()
                                .fill(.regularMaterial)
                            Rectangle()
                                .fill(captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.accentColor.opacity(0.30)
                                    : Color.accentColor.opacity(0.92))
                        }
                    }
                    .overlay {
                        Rectangle()
                            .stroke(Color.white.opacity(theme.isDark ? 0.10 : 0.22), lineWidth: 1)
                    }
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
                    close()
                }
                .keyboardShortcut(.escape, modifiers: [])

                if let noteId = result.createdNoteID {
                    Button {
                        NoteWindowManager.shared.open(pageId: noteId)
                        close(restoreHomeFocus: false)
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

    private func close(restoreHomeFocus: Bool = true) {
        cleanupTransientCaptureState()
        isTextFieldFocused = false
        isPresented = false
        if restoreHomeFocus {
            HomeWindowInputFocus.restoreAfterOverlayDismiss()
        }
    }

    private func cleanupTransientCaptureState() {
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
        readBackTask?.cancel()
        EpistemosSpeechSynthesizer.shared.stop()
        isTextFieldFocused = false
        isTraceInspectorPresented = false
    }

    /// SS-QC (D) auto read-back: when the user opts in (pref `.auto`), speak the sentence they
    /// JUST completed once they pause typing. Opt-in (default manual) + debounce (750 ms) + dedup
    /// (never re-speak the same sentence) keep it calm — never a stutter of half-typed fragments.
    private func scheduleQuickCaptureReadBack(for text: String) {
        guard VoicePreferences.shared.quickCaptureReadBack == .auto else { return }
        guard EpistemosSpeechSynthesizer.isTextToSpeechAvailable() else { return }
        readBackTask?.cancel()
        readBackTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled,
                  let sentence = QuickCaptureReadBack.lastCompletedSentence(in: text),
                  sentence != lastSpokenSentence else { return }
            lastSpokenSentence = sentence
            _ = EpistemosSpeechSynthesizer.shared.speak(sentence)
        }
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
        .clipShape(Rectangle())
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
        .clipShape(Rectangle())
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
            Rectangle()
                .fill(tint.opacity(0.15))
                .overlay(Rectangle().stroke(tint.opacity(0.30), lineWidth: 0.5))
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
        // Reentrancy guard: isProcessing is only set inside this async body, so
        // two fast Cmd-Return events (key auto-repeat / double-press) can both
        // enter before it flips — each would run the pipeline and mint a
        // duplicate note without this early-out.
        guard !isProcessing else { return }
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
            // Note is durably saved (createdNoteID set above); a miss on the
            // SECONDARY mutation-envelope audit-log write (EventStore is optional
            // and returns false on a nil store or a transient SQLite error) must
            // NOT report failure — else the user retries a saved capture and mints
            // a duplicate note. Benign audit degradation (result.mutationEnvelopePersisted).
            withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
                captureResult = result
            }
        } catch {
            errorMessage = QuickCaptureDiagnostics.statusMessage(for: error)
        }

        isProcessing = false
    }

    // MARK: - Audio Processing
    private func toggleAudioRecording() async {
        // Reentrancy guard: a second toggle while a prior transcription+persist
        // is still in flight (isTranscribing flips async) could double-process
        // one recording into duplicate notes.
        guard !isTranscribing else { return }
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
                // Note is durably saved (createdNoteID set above); a miss on the
                // SECONDARY mutation-envelope audit-log write must NOT report
                // failure — else the user retries a saved capture and mints a
                // duplicate note. Benign audit degradation.
                withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) {
                    captureResult = result
                }
            } catch {
                errorMessage = QuickCaptureDiagnostics.statusMessage(
                    for: error,
                    fallback: "Transcription failed"
                )
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
                errorMessage = QuickCaptureDiagnostics.statusMessage(
                    for: error,
                    fallback: "Failed to start recording"
                )
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
