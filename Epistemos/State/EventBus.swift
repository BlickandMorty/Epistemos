import Foundation
import Observation

// MARK: - App Event

enum AppEvent: Sendable {
    case signalUpdate(SignalUpdate)
    case stageComplete(PipelineStage)
    case pipelineComplete
    case soarEvent(SOAREvent)
    case error(String)
    case toast(String, ToastType)
    case vaultChanged
    case vaultPageChanged(pageId: String)
    case vaultPageDeleted(pageId: String)

    // Learning events
    case custom(name: String, payload: AnySendable?)

    // Chat lifecycle events
    case querySubmitted(chatId: ChatId, query: String)
    case queryCompleted(chatId: ChatId, messageId: MessageId)
    case chatCleared(chatId: ChatId)
}

enum ToastType: String, Sendable {
    case success
    case error
    case info
    case warning
}

// MARK: - Event Bus

@MainActor @Observable
final class EventBus {

    typealias EventHandler = (AppEvent) -> Void

    private var handlers: [String: EventHandler] = [:]
    private var continuations: [String: AsyncStream<AppEvent>.Continuation] = [:]

    // MARK: - Subscribe

    func subscribe(id: String, handler: @escaping EventHandler) {
        handlers[id] = handler
    }

    func unsubscribe(id: String) {
        handlers.removeValue(forKey: id)
    }

    // MARK: - Async Stream

    func events() -> AsyncStream<AppEvent> {
        let id = UUID().uuidString
        return AsyncStream { continuation in
            self.continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations.removeValue(forKey: id)
                }
            }
        }
    }

    // MARK: - Emit

    func emit(_ event: AppEvent) {
        // Snapshot before iterating — a handler could trigger subscribe/unsubscribe
        // which would mutate the dictionary during iteration (runtime crash).
        let handlerSnapshot = Array(handlers.values)
        let continuationSnapshot = Array(continuations.values)
        for handler in handlerSnapshot {
            handler(event)
        }
        for continuation in continuationSnapshot {
            continuation.yield(event)
        }
    }

    // MARK: - Convenience

    func emitToast(_ message: String, type: ToastType = .info) {
        emit(.toast(message, type))
    }

    func emitError(_ message: String) {
        emit(.toast(message, .error))
    }
}

// MARK: - AnySendable

enum AnySendable: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case probe(LearnabilityProbe)
    case array([AnySendable])
    case dictionary([String: AnySendable])
}
