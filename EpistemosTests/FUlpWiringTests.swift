import Foundation
import Testing
@testable import Epistemos

// Wiring #5 (T12 F-ULP → EML witness emission) Swift integration test.
//
// Verifies the WRV "Verified" bar:
//   - `FUlpBridge.run()` returns a decoded `FUlpWitness` when the
//     research feature is compiled in; otherwise the bridge records the
//     error gracefully without throwing.
//   - `FUlpMetrics.shared` records the run + last witness shape.
//   - `FUlpFlags` flag toggles via UserDefaults / env-var fallback.

@Suite("F-ULP Wiring #5")
struct FUlpWiringTests {

    @Test("FUlpBridge.run returns witness OR records research-only error gracefully")
    func fUlpBridgeRunCompletesWithoutThrowing() {
        FUlpMetrics.shared.reset()
        let witness = FUlpBridge.run()
        let snap = FUlpMetrics.shared.snapshot()
        // Either a witness was decoded OR an error was recorded.
        // No throw is the contract; the row degrades gracefully.
        if witness == nil {
            #expect(snap.lastErrorDescription != nil,
                    "If no witness, the error must surface on the snapshot")
        } else {
            #expect(snap.lastWitness != nil)
            #expect(snap.lastRunAt != nil)
            #expect(snap.totalRuns == 1)
        }
    }

    @Test("FUlpFlags reads UserDefaults + env-var fallback")
    func fUlpFlagsToggle() {
        let saved = UserDefaults.standard.bool(forKey: FUlpFlags.userDefaultsKey)
        defer { UserDefaults.standard.set(saved, forKey: FUlpFlags.userDefaultsKey) }

        UserDefaults.standard.set(false, forKey: FUlpFlags.userDefaultsKey)
        let envIsSet = ProcessInfo.processInfo.environment[FUlpFlags.userDefaultsKey] == "1"
        if !envIsSet {
            #expect(!FUlpFlags.isEnabled, "flag should default to OFF")
        }

        UserDefaults.standard.set(true, forKey: FUlpFlags.userDefaultsKey)
        #expect(FUlpFlags.isEnabled)
    }

    @Test("FUlpMetrics marshals change notifications onto the main actor")
    func fUlpMetricsNotificationsUseMainActor() async {
        let probe = NotificationThreadProbe(
            name: FUlpMetrics.didChangeNotification,
            object: FUlpMetrics.shared
        )

        await Task.detached {
            FUlpMetrics.shared.recordError(FUlpNotificationTestError.sample)
        }.value

        let postedOnMain = await probe.nextResult(timeoutNanoseconds: 2_000_000_000)
        #expect(postedOnMain == true)
    }
}

private enum FUlpNotificationTestError: Error {
    case sample
}

private final class NotificationThreadProbe: @unchecked Sendable {
    nonisolated(unsafe) private let stream: AsyncStream<Bool>
    nonisolated(unsafe) private let continuation: AsyncStream<Bool>.Continuation
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init(name: Notification.Name, object: AnyObject) {
        let streamPair = AsyncStream<Bool>.makeStream()
        stream = streamPair.stream
        continuation = streamPair.continuation
        observer = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: nil
        ) { [weak self] _ in
            self?.finish(Thread.isMainThread)
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    nonisolated func nextResult(timeoutNanoseconds: UInt64) async -> Bool? {
        await withTaskGroup(of: Bool?.self) { group in
            group.addTask { [stream] in
                var iterator = stream.makeAsyncIterator()
                return await iterator.next()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    nonisolated private func finish(_ value: Bool) {
        continuation.yield(value)
        continuation.finish()
    }
}
