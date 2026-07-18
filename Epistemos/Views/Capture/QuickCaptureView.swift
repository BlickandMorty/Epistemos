import AppKit
import Foundation
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

nonisolated enum QuickCapturePresentationSlot: String, Codable, Sendable {
    case rootOverlay = "root-overlay"
    case landingInline = "landing-inline"
}

extension Notification.Name {
    static let requestQuickCaptureDismissal = Notification.Name("epistemos.requestQuickCaptureDismissal")
}

nonisolated enum QuickCaptureDraftStore {
    static let maxDraftCharacters = 2_000_000
    private static let maxEncodedDraftBytes = (maxDraftCharacters * 8) + 4_096
    private static let legacySessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    struct Draft: Codable, Equatable, Sendable {
        let slot: QuickCapturePresentationSlot
        let sessionID: UUID
        let committedText: String
        let partialTranscript: String
        let revision: UInt64

        init(
            slot: QuickCapturePresentationSlot,
            sessionID: UUID = legacySessionID,
            committedText: String,
            partialTranscript: String,
            revision: UInt64
        ) {
            self.slot = slot
            self.sessionID = sessionID
            self.committedText = committedText
            self.partialTranscript = partialTranscript
            self.revision = revision
        }

        private enum CodingKeys: String, CodingKey {
            case slot
            case sessionID
            case committedText
            case partialTranscript
            case revision
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            slot = try container.decode(QuickCapturePresentationSlot.self, forKey: .slot)
            sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID) ?? legacySessionID
            committedText = try container.decode(String.self, forKey: .committedText)
            partialTranscript = try container.decode(String.self, forKey: .partialTranscript)
            revision = try container.decode(UInt64.self, forKey: .revision)
        }

        var isEmpty: Bool {
            committedText.isEmpty && partialTranscript.isEmpty
        }
    }

    private static let directoryName = "Epistemos/QuickCaptureDrafts"
    private static let fileName = "active.json"
    private static let fileLock = NSLock()

    static func restoredCommittedText(from draft: Draft) -> String {
        draft.committedText
    }

    static func recoveredPartialTranscript(from draft: Draft) -> String {
        draft.partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func claim(
        slot: QuickCapturePresentationSlot,
        sessionID: UUID,
        baseDirectory: URL? = nil
    ) -> Draft? {
        guard let url = draftURL(
            for: slot,
            createDirectory: true,
            baseDirectory: baseDirectory
        ) else {
            return nil
        }
        return fileLock.withLock {
            let existing = decodeDraft(at: url, expectedSlot: slot)
            let nextRevision: UInt64
            if let existing, existing.revision < .max {
                nextRevision = existing.revision + 1
            } else {
                nextRevision = existing?.revision ?? 1
            }
            let claimed = Draft(
                slot: slot,
                sessionID: sessionID,
                committedText: existing?.committedText ?? "",
                partialTranscript: existing?.partialTranscript ?? "",
                revision: nextRevision
            )
            return persist(claimed, at: url) ? claimed : nil
        }
    }

    @discardableResult
    static func write(_ draft: Draft, baseDirectory: URL? = nil) -> Bool {
        guard isWithinBounds(draft) else {
            Log.notes.error("quick capture crash-draft exceeds its recovery limit")
            return false
        }
        guard let url = draftURL(
            for: draft.slot,
            createDirectory: true,
            baseDirectory: baseDirectory
        ) else {
            return false
        }
        return fileLock.withLock {
            if let existing = decodeDraft(at: url, expectedSlot: draft.slot) {
                guard existing.sessionID == draft.sessionID else { return false }
                if existing.revision >= draft.revision {
                    return existing == draft
                }
            }
            return persist(draft, at: url)
        }
    }

    static func load(
        slot: QuickCapturePresentationSlot,
        baseDirectory: URL? = nil
    ) -> Draft? {
        guard let url = draftURL(
            for: slot,
            createDirectory: false,
            baseDirectory: baseDirectory
        ) else {
            return nil
        }
        return fileLock.withLock { decodeDraft(at: url, expectedSlot: slot) }
    }

    @discardableResult
    static func deleteIfMatching(
        _ expectedDraft: Draft,
        baseDirectory: URL? = nil
    ) -> Bool {
        guard let url = draftURL(
            for: expectedDraft.slot,
            createDirectory: false,
            baseDirectory: baseDirectory
        ) else {
            return false
        }
        return fileLock.withLock {
            guard decodeDraft(at: url, expectedSlot: expectedDraft.slot) == expectedDraft else {
                return false
            }
            let tombstone = Draft(
                slot: expectedDraft.slot,
                sessionID: expectedDraft.sessionID,
                committedText: "",
                partialTranscript: "",
                revision: expectedDraft.revision
            )
            return persist(tombstone, at: url)
        }
    }

    private static func decodeDraft(
        at url: URL,
        expectedSlot: QuickCapturePresentationSlot
    ) -> Draft? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let encodedSize = values.fileSize,
              encodedSize >= 0,
              encodedSize <= maxEncodedDraftBytes,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count <= maxEncodedDraftBytes,
              let draft = try? JSONDecoder().decode(Draft.self, from: data),
              draft.slot == expectedSlot,
              isWithinBounds(draft) else {
            return nil
        }
        return draft
    }

    private static func isWithinBounds(_ draft: Draft) -> Bool {
        let committedCount = draft.committedText.count
        guard committedCount <= maxDraftCharacters else { return false }
        return draft.partialTranscript.count <= maxDraftCharacters - committedCount
    }

    private static func persist(_ draft: Draft, at url: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(draft)
            guard data.count <= maxEncodedDraftBytes else {
                Log.notes.error("quick capture crash-draft exceeds its encoded recovery limit")
                return false
            }
            try AtomicVaultWriter.writeSynchronously(data, to: url)
            return true
        } catch {
            Log.notes.error("quick capture crash-draft write failed — recovery may be unavailable")
            return false
        }
    }

    private static func draftURL(
        for slot: QuickCapturePresentationSlot,
        createDirectory: Bool,
        baseDirectory: URL?
    ) -> URL? {
        let base = baseDirectory ?? FoundationSafety.userApplicationSupportDirectory()
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if createDirectory {
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            } catch {
                Log.notes.error("quick capture crash-draft directory is unavailable")
                return nil
            }
        }
        return directory.appendingPathComponent("\(slot.rawValue)-\(fileName)", isDirectory: false)
    }
}

@MainActor
final class QuickCapturePresentationRegistry {
    static let shared = QuickCapturePresentationRegistry()

    private var activeOwnerID: UUID?

    init() {}

    func acquire(_ ownerID: UUID) -> Bool {
        guard let activeOwnerID else {
            self.activeOwnerID = ownerID
            return true
        }
        return activeOwnerID == ownerID
    }

    func owns(_ ownerID: UUID) -> Bool {
        activeOwnerID == ownerID
    }

    func release(_ ownerID: UUID) {
        guard activeOwnerID == ownerID else { return }
        activeOwnerID = nil
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
    private static let previewSignalQuietWindow: Duration = .milliseconds(120)
    private static let draftWriteQuietWindow: Duration = .milliseconds(350)

    @Environment(UIState.self) private var ui
    @Environment(TextCapturePipeline.self) private var pipeline
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool
    private let presentationSlot: QuickCapturePresentationSlot

    init(
        isPresented: Binding<Bool>,
        presentationSlot: QuickCapturePresentationSlot
    ) {
        _isPresented = isPresented
        self.presentationSlot = presentationSlot
    }

    @State private var captureText = ""
    /// GAP-27: clipboard text detected on appear (opt-in paste); nil when empty/too long.
    @State private var clipboardText: String?
    @State private var isProcessing = false
    @State private var captureResult: CaptureResult?
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool

    @State private var dictationPartial = ""
    @State private var recoveredDictationFragment = ""
    @State private var isDictationActive = false
    @State private var presentationOwnerID = UUID()
    @State private var ownsPresentation = false
    @State private var draftSessionReady = false
    @State private var voiceSessionHandle = VoiceInputSessionHandle()
    @State private var draftRevision: UInt64 = 0
    @State private var draftWriteTask: Task<Void, Never>?
    @State private var draftRestoreTask: Task<Void, Never>?
    @State private var draftFlushedForDismissal = false
    @State private var isDismissing = false
    @State private var isTraceInspectorPresented = false
    @State private var appearFrame = 0
    // SS-QC (D) auto read-back: debounce task + last-spoken dedup (so a paused-typing
    // sentence is read once, never repeatedly). Only active when the pref is .auto.
    @State private var readBackTask: Task<Void, Never>?
    @State private var lastSpokenSentence = ""
    @State private var previewSignals = PreviewSignals(text: "")
    @State private var previewSignalTask: Task<Void, Never>?
    private var theme: EpistemosTheme { ui.theme }

    private var headerSubtitle: String {
        if isProcessing {
            return "Structuring your thought…"
        }
        if !dictationPartial.isEmpty {
            return "Listening — speak naturally"
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
            draftFlushedForDismissal = false
            isDismissing = false
            ownsPresentation = false
            draftSessionReady = false
            presentationOwnerID = UUID()
            guard QuickCapturePresentationRegistry.shared.acquire(presentationOwnerID) else {
                errorMessage = "Quick Capture is already open in another window."
                isPresented = false
                return
            }
            ownsPresentation = true
            restoreQuickCaptureDraftIfNeeded()
            Task { @MainActor in
                await PixelStepMotion.play(reduceMotion: reduceMotion) { frame in
                    appearFrame = frame
                }
            }
        }
        .onDisappear {
            if let interruptedTranscript = voiceSessionHandle.interrupt() {
                recoverInterruptedDictation(interruptedTranscript)
            }
            // Prevent cleanup state changes from scheduling a newer recovery
            // snapshot after the disappearance snapshot has captured the last
            // committed and partial text.
            isDismissing = true
            if ownsPresentation {
                persistQuickCaptureDraftForDisappearance()
                EpistemosVisibleReadAloudRegistry.shared.unregister(.quickCapture)
            }
            cleanupTransientCaptureState()
        }
        .onChange(of: captureText) { _, newValue in
            registerQuickCaptureReadAloudProvider()
            scheduleQuickCaptureReadBack(for: newValue)
            schedulePreviewSignals(for: newValue)
            scheduleQuickCaptureDraftWrite()
        }
        .onChange(of: dictationPartial) { _, _ in
            scheduleQuickCaptureDraftWrite()
        }
        .onChange(of: recoveredDictationFragment) { _, _ in
            scheduleQuickCaptureDraftWrite()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestQuickCaptureDismissal)) { notification in
            guard let requestedSlot = notification.object as? QuickCapturePresentationSlot,
                  requestedSlot == presentationSlot else { return }
            close()
        }
    }

    private func registerQuickCaptureReadAloudProvider() {
        guard ownsPresentation,
              draftSessionReady,
              QuickCapturePresentationRegistry.shared.owns(presentationOwnerID) else { return }
        EpistemosVisibleReadAloudRegistry.shared.register(.quickCapture) {
            EpistemosSpeechSynthesizer.plainTextForSpeech(fromMarkdown: captureText)
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
            .disabled(isProcessing || isDismissing)
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
                .disabled(
                    isProcessing
                        || isDismissing
                        || !ownsPresentation
                        || !draftSessionReady
                )
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

            if !recoveredDictationFragment.isEmpty {
                recoveredDictationBanner
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

                VoiceInputButton(
                    style: .labeled,
                    purpose: .quickCapture,
                    sessionHandle: voiceSessionHandle,
                    onPartial: { partial in
                        dictationPartial = LiveVoiceInputService.boundedTranscript(partial)
                    },
                    onActivityChange: { isActive in
                        isDictationActive = isActive
                    },
                    onInterrupted: { transcript in
                        recoverInterruptedDictation(transcript)
                    },
                    onFinal: { transcript in
                        appendDictation(transcript)
                    }
                )
                .disabled(
                    isProcessing
                        || isDismissing
                        || !ownsPresentation
                        || !draftSessionReady
                        || !recoveredDictationFragment.isEmpty
                )

                // Plan 3 owner update 2026-06-30: TTS is Kokoro-only. The
                // read-aloud affordance remains visible and opens the Kokoro
                // installer when the checked runtime is unavailable; no Apple
                // voice picker or AVSpeech fallback is surfaced here.
                ReadAloudButton(
                    text: EpistemosSpeechSynthesizer.plainTextForSpeech(fromMarkdown: captureText),
                    style: .iconWithProgress,
                    surface: .quickCapture
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
                .disabled(
                    captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || isProcessing
                        || isDismissing
                        || !ownsPresentation
                        || !draftSessionReady
                        || isDictationActive
                        || !dictationPartial.isEmpty
                        || !recoveredDictationFragment.isEmpty
                )
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var recoveredDictationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.badge.exclamationmark")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Recovered unfinished dictation")
                    .font(.caption.weight(.semibold))
                Text(recoveredDictationFragment)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button("Discard") {
                recoveredDictationFragment = ""
            }
            .buttonStyle(.borderless)

            Button("Add to Draft") {
                let recovered = recoveredDictationFragment
                recoveredDictationFragment = ""
                appendDictation(recovered)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.orange.opacity(0.45), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
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
        guard !isProcessing else {
            errorMessage = "Wait for this capture to finish saving before closing."
            return
        }
        guard !isDictationActive else {
            errorMessage = "Stop dictation before closing so the final words can be preserved."
            return
        }
        guard !isDismissing else { return }
        isDismissing = true
        Task { @MainActor in
            let didPersist = await persistQuickCaptureDraftBeforeDismissal()
            guard didPersist else {
                errorMessage = "Quick Capture could not preserve this draft. Keep this window open and try again."
                isDismissing = false
                return
            }
            finishDismissal(restoreHomeFocus: restoreHomeFocus)
        }
    }

    private func finishDismissal(restoreHomeFocus: Bool) {
        draftFlushedForDismissal = true
        cleanupTransientCaptureState()
        isTextFieldFocused = false
        isPresented = false
        if restoreHomeFocus {
            HomeWindowInputFocus.restoreAfterOverlayDismiss()
        }
    }

    private func cleanupTransientCaptureState() {
        dictationPartial = ""
        isDictationActive = false
        draftWriteTask?.cancel()
        draftWriteTask = nil
        readBackTask?.cancel()
        previewSignalTask?.cancel()
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

    private func schedulePreviewSignals(for text: String) {
        previewSignalTask?.cancel()
        guard !text.isEmpty else {
            previewSignals = PreviewSignals(text: "")
            previewSignalTask = nil
            return
        }
        previewSignalTask = Task { @MainActor in
            try? await Task.sleep(for: Self.previewSignalQuietWindow)
            guard !Task.isCancelled else { return }
            let nextSignals = await Task.detached(priority: .utility) {
                PreviewSignals(text: text)
            }.value
            guard !Task.isCancelled, captureText == text else { return }
            previewSignals = nextSignals
            previewSignalTask = nil
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
        guard !isProcessing,
              !isDismissing,
              ownsPresentation,
              draftSessionReady,
              QuickCapturePresentationRegistry.shared.owns(presentationOwnerID),
              !isDictationActive,
              dictationPartial.isEmpty,
              recoveredDictationFragment.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }
        if let restoreTask = draftRestoreTask {
            await restoreTask.value
        }
        guard !isDictationActive,
              dictationPartial.isEmpty,
              recoveredDictationFragment.isEmpty,
              !captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        errorMessage = nil
        draftWriteTask?.cancel()
        draftWriteTask = nil
        advanceDraftRevision()
        let slot = presentationSlot
        let sessionID = presentationOwnerID
        let committedText = captureText
        let revision = draftRevision

        let submittedDraft = await Task.detached(priority: .utility) {
            let draft = QuickCaptureDraftStore.Draft(
                slot: slot,
                sessionID: sessionID,
                committedText: committedText,
                partialTranscript: "",
                revision: revision
            )
            return QuickCaptureDraftStore.write(draft) ? draft : nil
        }.value
        guard let submittedDraft else {
            errorMessage = "Quick Capture could not preserve this draft before saving. Reduce its size or try again."
            return
        }

        do {
            let result = try await pipeline.run(
                rawText: submittedDraft.committedText,
                modelContext: modelContext,
                maxBodyCharacters: QuickCaptureDraftStore.maxDraftCharacters
            )
            guard result.rawText == submittedDraft.committedText,
                  result.createdNoteID != nil else {
                throw TextCaptureError.persistenceFailed(
                    result.graphWriteSummary.skippedReason ?? "note was not persisted"
                )
            }
            let removedSubmittedDraft = await Task.detached(priority: .utility) {
                QuickCaptureDraftStore.deleteIfMatching(submittedDraft)
            }.value
            if !removedSubmittedDraft {
                Log.notes.notice("saved Quick Capture note retained a nonmatching recovery draft")
            }
            draftFlushedForDismissal = true
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
    }

    private func appendDictation(_ transcript: String) {
        guard ownsPresentation, draftSessionReady else { return }
        let cleaned = LiveVoiceInputService.cleanedFinalTranscript(transcript)
        guard !cleaned.isEmpty else { return }
        if captureText.isEmpty || captureText.last?.isWhitespace == true {
            captureText.append(cleaned)
        } else {
            captureText.append("\n")
            captureText.append(cleaned)
        }
        dictationPartial = ""
        isTextFieldFocused = true
    }

    private func recoverInterruptedDictation(_ transcript: String) {
        let cleaned = LiveVoiceInputService.cleanedFinalTranscript(transcript)
        guard !cleaned.isEmpty else {
            dictationPartial = ""
            isDictationActive = false
            return
        }
        if recoveredDictationFragment.isEmpty {
            recoveredDictationFragment = cleaned
        } else if recoveredDictationFragment != cleaned,
                  !recoveredDictationFragment.hasSuffix(cleaned) {
            recoveredDictationFragment.append("\n")
            recoveredDictationFragment.append(cleaned)
        }
        dictationPartial = ""
        isDictationActive = false
    }

    private func restoreQuickCaptureDraftIfNeeded() {
        draftRestoreTask?.cancel()
        let slot = presentationSlot
        let sessionID = presentationOwnerID
        draftSessionReady = false
        draftRestoreTask = Task { @MainActor in
            let draft = await Task.detached(priority: .utility) {
                QuickCaptureDraftStore.claim(slot: slot, sessionID: sessionID)
            }.value
            guard !Task.isCancelled,
                  !isDismissing,
                  ownsPresentation,
                  QuickCapturePresentationRegistry.shared.owns(sessionID),
                  let draft else {
                if !isDismissing {
                    errorMessage = "Quick Capture could not open its recovery draft."
                }
                draftRestoreTask = nil
                return
            }
            draftRevision = draft.revision
            captureText = QuickCaptureDraftStore.restoredCommittedText(from: draft)
            recoveredDictationFragment = QuickCaptureDraftStore.recoveredPartialTranscript(from: draft)
            dictationPartial = ""
            draftSessionReady = true
            registerQuickCaptureReadAloudProvider()
            if let clip = NSPasteboard.general.string(forType: .string),
               !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               clip.count <= 20_000 {
                clipboardText = clip
            } else {
                clipboardText = nil
            }
            isTextFieldFocused = true
            draftRestoreTask = nil
        }
    }

    private func scheduleQuickCaptureDraftWrite() {
        guard captureResult == nil,
              !draftFlushedForDismissal,
              !isDismissing,
              ownsPresentation,
              draftSessionReady,
              QuickCapturePresentationRegistry.shared.owns(presentationOwnerID) else { return }
        advanceDraftRevision()
        let slot = presentationSlot
        let sessionID = presentationOwnerID
        let committedText = captureText
        let partialTranscript = pendingPartialTranscriptForRecovery
        let revision = draftRevision
        draftWriteTask?.cancel()
        draftWriteTask = Task { @MainActor in
            try? await Task.sleep(for: Self.draftWriteQuietWindow)
            guard !Task.isCancelled else { return }
            let didWrite = await Task.detached(priority: .utility) {
                let draft = QuickCaptureDraftStore.Draft(
                    slot: slot,
                    sessionID: sessionID,
                    committedText: committedText,
                    partialTranscript: partialTranscript,
                    revision: revision
                )
                return QuickCaptureDraftStore.write(draft)
            }.value
            guard !Task.isCancelled, draftRevision == revision else { return }
            if didWrite {
                if errorMessage == "Quick Capture could not preserve its recovery draft." {
                    errorMessage = nil
                }
            } else {
                errorMessage = "Quick Capture could not preserve its recovery draft."
            }
            draftWriteTask = nil
        }
    }

    private func persistQuickCaptureDraftBeforeDismissal() async -> Bool {
        draftWriteTask?.cancel()
        draftWriteTask = nil
        guard captureResult == nil else { return true }
        if let restoreTask = draftRestoreTask {
            await restoreTask.value
        }
        guard ownsPresentation,
              QuickCapturePresentationRegistry.shared.owns(presentationOwnerID) else { return true }
        guard draftSessionReady else {
            return captureText.isEmpty && pendingPartialTranscriptForRecovery.isEmpty
        }
        advanceDraftRevision()
        let slot = presentationSlot
        let sessionID = presentationOwnerID
        let committedText = captureText
        let partialTranscript = pendingPartialTranscriptForRecovery
        let revision = draftRevision
        return await Task.detached(priority: .utility) {
            QuickCaptureDraftStore.write(
                QuickCaptureDraftStore.Draft(
                    slot: slot,
                    sessionID: sessionID,
                    committedText: committedText,
                    partialTranscript: partialTranscript,
                    revision: revision
                )
            )
        }.value
    }

    private func persistQuickCaptureDraftForDisappearance() {
        draftWriteTask?.cancel()
        draftWriteTask = nil
        let ownerID = presentationOwnerID
        let restoreTask = draftRestoreTask
        let snapshot: QuickCaptureDraftStore.Draft?
        if captureResult == nil, !draftFlushedForDismissal, draftSessionReady {
            advanceDraftRevision()
            snapshot = QuickCaptureDraftStore.Draft(
                slot: presentationSlot,
                sessionID: ownerID,
                committedText: captureText,
                partialTranscript: pendingPartialTranscriptForRecovery,
                revision: draftRevision
            )
        } else {
            snapshot = nil
        }
        Task { @MainActor in
            if let restoreTask {
                await restoreTask.value
            }
            if let snapshot {
                let didWrite = await Task.detached(priority: .utility) {
                    QuickCaptureDraftStore.write(snapshot)
                }.value
                if !didWrite {
                    Log.notes.error("Quick Capture disappeared before its recovery draft was preserved")
                }
            }
            QuickCapturePresentationRegistry.shared.release(ownerID)
        }
    }

    private var pendingPartialTranscriptForRecovery: String {
        recoveredDictationFragment.isEmpty ? dictationPartial : recoveredDictationFragment
    }

    private func advanceDraftRevision() {
        if draftRevision < .max {
            draftRevision += 1
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

private nonisolated struct PreviewSignals: Sendable {
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
