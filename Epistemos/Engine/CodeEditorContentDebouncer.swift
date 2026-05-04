import Combine
import Foundation

// MARK: - CodeEditorContentDebouncer (T+8 Phase-S item 2)
//
// Per `docs/CODE_EDITOR_POLISH_SCOPE.md` Phase-S item 2:
//   "Binding<String> debouncing (2 hrs) — 300 ms quiet window"
//
// `CodeEditorView` fires its host's `onContentChange` on every
// keystroke synchronously. For hosts whose downstream action is
// expensive (semantic search, vault index update, MutationEnvelope
// emission, NSDocument autosave), every keystroke re-runs that work
// even though only the final result matters. This helper coalesces
// rapid keystrokes into a single delivery after a 300 ms quiet
// window.
//
// Mirrors the pattern of `EpdocEditorSavePipeline`
// (`Epistemos/Engine/EpdocEditorBridge.swift:350`) which serves the
// same role for ProseMirror JSON on the Document editor side.
//
// Usage:
//   let debouncer = CodeEditorContentDebouncer { latestText in
//       // expensive: vault save, semantic recall, etc.
//       performExpensiveWork(latestText)
//   }
//   CodeEditorView(content: text, language: lang) { newText in
//       text = newText                  // immediate state sync
//       debouncer.enqueue(newText)      // debounced expensive call
//   }
//
// Thread safety: `@MainActor` because the typical caller is a
// SwiftUI view's body / @State callback. The internal Combine
// subscription drains on the main scheduler so `process(_:)` always
// runs on `MainActor`.

@MainActor
public final class CodeEditorContentDebouncer {

    /// Default quiet window. Per polish-scope doc: "300 ms quiet
    /// window" — long enough to coalesce rapid typing, short enough
    /// that perceived save latency stays sub-second.
    nonisolated public static let defaultQuietWindowMs: Int = 300

    private let subject = PassthroughSubject<String, Never>()
    private var subscription: AnyCancellable?

    /// Build a debouncer with a 300 ms quiet window by default.
    /// `process` runs on `@MainActor` after the user stops typing
    /// for `quietWindow` (.milliseconds default 300).
    public init(
        quietWindow: DispatchQueue.SchedulerTimeType.Stride =
            .milliseconds(CodeEditorContentDebouncer.defaultQuietWindowMs),
        process: @escaping @Sendable @MainActor (String) -> Void
    ) {
        self.subscription = subject
            .debounce(for: quietWindow, scheduler: DispatchQueue.main)
            .sink { latest in
                MainActor.assumeIsolated {
                    process(latest)
                }
            }
    }

    /// Forward the latest text. Each call resets the 300 ms timer;
    /// only the final `latest` after the quiet window fires the
    /// `process` closure.
    public func enqueue(_ latest: String) {
        subject.send(latest)
    }

    /// Tear down the Combine subscription. The deinit handles this
    /// automatically; callers only need to invoke explicitly when
    /// the debouncer's `process` closure has captured a strong
    /// reference to a soon-to-be-destroyed object and they want to
    /// be sure the closure stops firing immediately.
    public func detach() {
        subscription?.cancel()
        subscription = nil
    }
}
