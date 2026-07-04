import Foundation

/// RES-2 (audit 2026-07-03): `LiteParsePDFImporter.importToMarkdown` is a *synchronous*,
/// uncancellable FFI (the liteparse/unpdf parser stack). Structured concurrency cannot bound
/// it — a task group or `task.value` awaits its child at scope exit, so a truly-stuck parse
/// (a malformed / pathological PDF) would still hang the caller forever. This helper runs the
/// conversion on a detached task and races it against a wall-clock deadline; on timeout it
/// STOPS AWAITING and surfaces `TimedOut`, ABANDONING the detached task (which finishes later
/// and has its result discarded) — freeing the ingest/UI instead of hanging. Task cancellation
/// is honored the same way. See DECISIONS.md (D-RES2) for the `@unchecked Sendable` latch.
nonisolated enum LiteParsePDFConversion {
    /// Generous "something is wrong" ceiling — text extraction of even a large PDF is seconds.
    static let defaultTimeout: Duration = .seconds(120)

    struct TimedOut: Error {}

    /// Convert `pdfPath` to markdown via `importer`, but never wait longer than `timeout`.
    /// Returns the importer's `LiteParseImportResult` if it finishes in time; throws `TimedOut`
    /// if the deadline wins (the conversion is abandoned, not cancelled — the FFI can't be
    /// interrupted); throws `CancellationError` if the calling task is cancelled.
    static func importToMarkdown(
        using importer: LiteParsePDFImporter,
        pdfPath: String,
        timeout: Duration = defaultTimeout
    ) async throws -> LiteParseImportResult {
        let gate = Gate()
        let work = Task.detached(priority: .userInitiated) {
            let result = importer.importToMarkdown(pdfPath: pdfPath)
            gate.finish(.success(result))
        }
        let timer = Task {
            try? await Task.sleep(for: timeout)
            gate.finish(.failure(TimedOut()))
        }
        defer { timer.cancel() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.attach(continuation)
            }
        } onCancel: {
            gate.finish(.failure(CancellationError()))
            work.cancel()
        }
    }

    /// Single-resume race latch. `@unchecked Sendable` justification: all mutable state
    /// (`settled`, `continuation`, `delivered`) is accessed only under `lock`. The class exists
    /// solely to resume a `CheckedContinuation` exactly once, from whichever of
    /// {conversion, timeout, cancellation} settles first, delivering correctly regardless of
    /// whether `attach` or `finish` runs first. `CheckedContinuation` is not `Sendable` and
    /// cannot cross an actor/task boundary directly, so an `NSLock`-guarded class is the
    /// sanctioned pattern here. See DECISIONS.md (D-RES2).
    nonisolated private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var settled: Result<LiteParseImportResult, Error>?
        private var continuation: CheckedContinuation<LiteParseImportResult, Error>?
        private var delivered = false

        func attach(_ continuation: CheckedContinuation<LiteParseImportResult, Error>) {
            lock.lock()
            if let settled, !delivered {
                delivered = true
                lock.unlock()
                continuation.resume(with: settled)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }

        func finish(_ result: Result<LiteParseImportResult, Error>) {
            lock.lock()
            guard settled == nil else {
                lock.unlock()
                return
            }
            settled = result
            if let continuation, !delivered {
                delivered = true
                self.continuation = nil
                lock.unlock()
                continuation.resume(with: result)
            } else {
                lock.unlock()
            }
        }
    }
}
