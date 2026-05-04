import Foundation
import SwiftUI
import Combine

// ---------------------------------------------------------------------------
// MARK: - CaptureSurfaceModel
// ---------------------------------------------------------------------------

/// Observable model for the quick-capture UI.
///
/// CaptureSurface is the **entry point to the entire system**:
/// one text field, Cmd-Enter commits, and a 60-second undo stack.
@MainActor
public final class CaptureSurfaceModel: ObservableObject {
    /// Current capture text.
    @Published public var text: String = ""

    /// The last committed capture (for display / confirmation).
    @Published public var lastCapture: String?

    /// Is a commit in flight?
    @Published public var isCommitting = false

    /// Last error surfaced from Rust.
    @Published public var lastError: String?

    /// Undo stack — captures committed in the last 60 seconds.
    @Published public var undoStack: [CaptureEntry] = []

    /// Maximum age of undoable captures (seconds).
    public let undoWindow: TimeInterval = 60.0

    private var pruneTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Prune expired undo entries every 10 seconds.
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pruneUndoStack()
            }
        }
    }

    deinit {
        pruneTimer?.invalidate()
    }

    // MARK: - Commit

    /// Commit the current text to the Rust runtime via UniFFI.
    ///
    /// In production this packages the text into an `Intent::CapturePlaced`
    /// and sends it through the orchestrator. For now it calls
    /// `run_ternary_prompt` as a stand-in for the capture pipeline.
    public func commit() async throws {
        guard !text.isEmpty else {
            throw CaptureError.emptyText
        }

        let payload = text
        await MainActor.run { isCommitting = true }
        defer { Task { @MainActor in isCommitting = false } }

        // Push onto undo stack before sending.
        let entry = CaptureEntry(text: payload, timestamp: Date())
        await MainActor.run {
            undoStack.append(entry)
            lastCapture = payload
        }

        // Call into Rust via UniFFI.
        let cfg = TernaryRunConfig(
            backend: "DenseMlx",
            max_tokens: 64,
            freeform: true,
            live_draft: false
        )

        do {
            _ = try await Task.detached(priority: .userInitiated) {
                helios_ffi.run_ternary_prompt(prompt: payload, cfg: cfg)
            }.value

            await MainActor.run {
                self.text = ""
                self.lastError = nil
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            throw error
        }
    }

    // MARK: - Undo

    /// Undo the most recent capture if it is within the undo window.
    public func undo() async throws {
        pruneUndoStack()
        guard let last = undoStack.popLast() else {
            throw CaptureError.nothingToUndo
        }

        // In production this emits an `Intent::UndoRequested { count: 1 }`
        // to the Rust runtime. Here we just restore the text for UX feedback.
        await MainActor.run {
            self.text = last.text
            self.lastCapture = nil
        }
    }

    /// Remove undo entries older than `undoWindow`.
    private func pruneUndoStack() {
        let cutoff = Date().addingTimeInterval(-undoWindow)
        undoStack.removeAll { $0.timestamp < cutoff }
    }

    /// Can the user undo right now?
    public var canUndo: Bool {
        pruneUndoStack()
        return !undoStack.isEmpty
    }
}

// ---------------------------------------------------------------------------
// MARK: - CaptureEntry
// ---------------------------------------------------------------------------

/// A single committed capture with metadata for undo.
public struct CaptureEntry: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let timestamp: Date
}

// ---------------------------------------------------------------------------
// MARK: - CaptureSurface (View)
// ---------------------------------------------------------------------------

public struct CaptureSurface: View {
    @StateObject private var model = CaptureSurfaceModel()
    @FocusState private var isFocused: Bool

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Capture")
                    .font(.headline)
                Spacer()
                if model.isCommitting {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.text)
                    .font(.body)
                    .focused($isFocused)
                    .frame(minHeight: 60, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2))
                    )
                if model.text.isEmpty {
                    Text("Type something …")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 6)
                }
            }

            HStack {
                Button(model.isCommitting ? "Committing …" : "Commit (⌘↩)") {
                    commit()
                }
                .disabled(model.isCommitting || model.text.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)

                Button("Undo") {
                    undo()
                }
                .disabled(!model.canUndo)
                .keyboardShortcut("z", modifiers: .command)

                Spacer()

                if let last = model.lastCapture {
                    Text("Last: \(last.prefix(24))…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .frame(minWidth: 360)
        .onAppear { isFocused = true }
    }

    private func commit() {
        Task {
            try? await model.commit()
        }
    }

    private func undo() {
        Task {
            try? await model.undo()
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - Errors
// ---------------------------------------------------------------------------

public enum CaptureError: Error, LocalizedError {
    case emptyText
    case nothingToUndo
    case rustCommitFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Cannot commit empty capture."
        case .nothingToUndo:
            return "Nothing to undo."
        case .rustCommitFailed(let msg):
            return "Rust commit failed: \(msg)"
        }
    }
}
