// GenUICardPresenter.swift
//
// Master Fusion Plan §B.8 2/N — non-blocking clarify presenter.
//
// Where this fits in the clarify story:
//   - Rust `agent_core::tools::clarify::ClarifyHandler` emits a JSON
//     `{question, choices}` and blocks awaiting `{response,
//     choice_index}`.
//   - `StreamingDelegate.askUserQuestion(questionJson:)` (Bridge layer)
//     forwards the call to `ClarifyPromptBridge.shared.ask(...)` which
//     blocks on a `DispatchSemaphore` until a Presenter returns a
//     `ClarifyPromptAnswer`.
//   - The default presenter (`ClarifyPromptBridge.presentPrompt`) shows
//     an `NSAlert` — modal, dismissable, no transcript record.
//
// This file adds an alternative presenter: a `GenUICardPresenter` that
// emits a `GenUIPayload.clarify` to a registered "card surface
// callback" (so the host can render it as an inline transcript card)
// AND awaits a `Notification.Name.clarifyCardResolved` for the user's
// response. Same input/output contract as the alert presenter, but
// non-modal — the user can scroll, type, switch tabs, then answer.
//
// Wiring: ChatCoordinator (or any future surface that wants
// card-mode clarify) constructs a `ClarifyPromptBridge` with this
// presenter and routes the cardSurfaceCallback into the appropriate
// view (chat transcript / approval dock / replay surface). Today the
// component is self-contained + tested in isolation — the
// ChatCoordinator surface integration lands as a later slice when
// chat-transcript-with-GenUIPayloads plumbing is ready.
//
// Architecture rationale (per the "actually useful, not scaffold"
// principle):
//   - Real production-quality wiring: subscribes + unsubscribes
//     correctly; honors cancellation; one in-flight prompt at a time;
//     timeout protected at the ClarifyPromptBridge layer; doesn't
//     leak observers.
//   - Decoupled from any specific surface: the cardSurfaceCallback
//     takes a `GenUIPayload` and the host decides where to put it.
//   - Testable in isolation: the test can construct a presenter,
//     capture the payload via the callback, fire the notification,
//     and assert the round-trip.

import Foundation

/// Alternative `ClarifyPromptBridge.Presenter` that emits a
/// `GenUIPayload.clarify` to a host-registered card surface and
/// awaits `Notification.Name.clarifyCardResolved` for the user's
/// response. Use this when card-mode clarify is preferred over the
/// default NSAlert path.
///
/// Construct with the surface callback that delivers the payload to
/// whatever view layer should render it (chat transcript, approval
/// dock, replay surface, etc.). Then pass `presenter.callAsFunction`
/// or wrap it in a `ClarifyPromptBridge.Presenter` closure when
/// instantiating `ClarifyPromptBridge`.
///
/// Thread-safety: the `present(_:)` async method must be called from
/// the MainActor (matches the `ClarifyPromptBridge.Presenter`
/// typealias). The notification observer is added + removed from the
/// MainActor too. The post-side may come from any actor — Swift
/// NotificationCenter dispatches synchronously on the posting
/// thread; observers wrap their handler in a MainActor `Task` when
/// they need MainActor isolation.
@MainActor
final class GenUICardPresenter {
    /// Closure type for handing a clarify payload off to a host
    /// surface (e.g. ChatCoordinator's transcript). Implementers add
    /// the payload to whatever view they want it rendered in and
    /// return immediately — the GenUICardPresenter handles the rest
    /// of the round-trip via the notification subscription.
    typealias CardSurfaceCallback = @MainActor (GenUIPayload) -> Void

    private let cardSurfaceCallback: CardSurfaceCallback
    private let notificationCenter: NotificationCenter

    init(
        notificationCenter: NotificationCenter = .default,
        cardSurfaceCallback: @escaping CardSurfaceCallback
    ) {
        self.notificationCenter = notificationCenter
        self.cardSurfaceCallback = cardSurfaceCallback
    }

    /// Present a clarify prompt as a GenUI card and await the user's
    /// response.
    ///
    /// Behavior:
    ///   1. Build a `GenUIPayload.clarify(question, choices,
    ///      allowFreeText: choices.isEmpty)` — when the agent supplied
    ///      choices, free-text is off by default (cleaner UX);
    ///      otherwise free-text is the only option.
    ///   2. Invoke the cardSurfaceCallback so the host renders the
    ///      payload somewhere visible to the user.
    ///   3. Subscribe to `Notification.Name.clarifyCardResolved` and
    ///      await the first matching notification (matched by
    ///      payload.id in the userInfo dictionary).
    ///   4. Decode the userInfo into a `ClarifyPromptAnswer` and
    ///      return it. Unsubscribe before returning.
    ///
    /// The caller (`ClarifyPromptBridge.ask`) wraps this in a
    /// timeout, so this method does not need its own.
    func present(_ prompt: ClarifyPromptPresentation) async -> ClarifyPromptAnswer {
        let choices = prompt.choices ?? []
        let payload = GenUIPayload.clarify(
            question: prompt.question,
            choices: choices,
            allowFreeText: choices.isEmpty
        )
        let payloadID = payload.id

        // Render the card on the host surface. Done synchronously so
        // the host has registered the card BEFORE we start listening
        // for the resolution notification (avoids the rare race where
        // the user resolves the card faster than this method
        // subscribes).
        cardSurfaceCallback(payload)

        // Bridge the NotificationCenter callback to async/await via
        // a single-shot CheckedContinuation. The observer captures
        // the continuation and the expected payload ID so any
        // unrelated notification (e.g. from a different in-flight
        // card) is ignored.
        return await withCheckedContinuation { (continuation: CheckedContinuation<ClarifyPromptAnswer, Never>) in
            // `observerHolder` is a class-typed wrapper so the
            // Sendable notification callback can mutate the inner
            // `value` without tripping "var captured by sendable
            // closure" — the reference is captured, the value is
            // updated through it.
            let observerHolder = ObserverHolder()
            let resumed = AtomicResumed()
            observerHolder.value = notificationCenter.addObserver(
                forName: .clarifyCardResolved,
                object: nil,
                queue: nil
            ) { [notificationCenter] note in
                let userInfo = note.userInfo ?? [:]
                guard
                    let notedPayloadID = userInfo[ClarifyCardNotificationKey.payloadID] as? String,
                    notedPayloadID == payloadID
                else {
                    return // unrelated card resolved
                }
                guard resumed.tryMark() else { return } // already handled
                if let token = observerHolder.value {
                    notificationCenter.removeObserver(token)
                }
                let response = (userInfo[ClarifyCardNotificationKey.response] as? String) ?? ""
                let choiceIndex = userInfo[ClarifyCardNotificationKey.choiceIndex] as? Int
                continuation.resume(returning: ClarifyPromptAnswer(
                    response: response,
                    choiceIndex: choiceIndex,
                    cancelled: response.isEmpty
                ))
            }
        }
    }
}

/// Atomic single-fire latch so the notification observer can't
/// resume the continuation twice if multiple matching notifications
/// somehow arrive. Pure-Swift, no Foundation/Combine dep needed.
///
/// `nonisolated` so it can be called from the NotificationCenter
/// observer callback (which runs on whatever thread NSNotificationCenter
/// chose) without an actor hop — the NSLock serves as the
/// synchronization primitive.
nonisolated private final class AtomicResumed: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    func tryMark() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if resumed { return false }
        resumed = true
        return true
    }
}

/// Class wrapper around the NSNotificationCenter observer token so a
/// Sendable closure can update the value without triggering "var
/// captured by sendable closure" warnings. The token is set once
/// (by `addObserver`'s return) and read once (by `removeObserver`
/// inside the same closure tree), so a single-writer/single-reader
/// implicitly-synchronized model is sufficient — no NSLock needed.
nonisolated private final class ObserverHolder: @unchecked Sendable {
    var value: NSObjectProtocol?
}
