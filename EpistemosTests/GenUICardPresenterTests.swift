import Foundation
import Testing
@testable import Epistemos

/// B.8 2/N — GenUICardPresenter integration tests.
///
/// Verifies the full round-trip from `ClarifyPromptPresentation` →
/// host-surface callback receives `GenUIPayload.clarify` →
/// `Notification.Name.clarifyCardResolved` fires →
/// `ClarifyPromptAnswer` returns with the canonical wire-format JSON.
///
/// Each test uses a fresh `NotificationCenter` instance (not `.default`)
/// so concurrent test runs don't interfere with one another.
@Suite("GenUICardPresenter (B.8 2/N) — round-trip with notification subscription")
@MainActor
struct GenUICardPresenterTests {
    @Test("Choice-tap notification resolves the presenter with choice text + index")
    func choiceTapResolvesPresenterWithChoiceTextAndIndex() async throws {
        let nc = NotificationCenter()
        var capturedPayload: GenUIPayload?
        let presenter = GenUICardPresenter(notificationCenter: nc) { payload in
            capturedPayload = payload
        }

        // Kick off the presenter on a background Task — we need to
        // fire the resolution notification AFTER the host callback
        // has captured the payload id, so we await the payload first.
        let task = Task {
            await presenter.present(
                ClarifyPromptPresentation(
                    question: "Which provider should handle this turn?",
                    choices: ["OpenAI", "Anthropic", "Local Qwen"]
                )
            )
        }

        // Poll briefly for the capturedPayload — the synchronous
        // callback runs inside present() before it suspends on the
        // continuation, so it should arrive immediately.
        for _ in 0..<50 {
            if capturedPayload != nil { break }
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        let payload = try #require(capturedPayload, "host-surface callback must receive the clarify payload before the presenter suspends")
        #expect(payload.schema == .clarify)

        // Fire the resolution notification with the payload id.
        nc.post(
            name: .clarifyCardResolved,
            object: nil,
            userInfo: [
                ClarifyCardNotificationKey.payloadID: payload.id,
                ClarifyCardNotificationKey.response: "Anthropic",
                ClarifyCardNotificationKey.choiceIndex: 1,
            ]
        )

        let answer = await task.value
        #expect(answer.response == "Anthropic")
        #expect(answer.choiceIndex == 1)
        #expect(answer.cancelled == false)
    }

    @Test("Free-text notification resolves with response + nil choiceIndex")
    func freeTextNotificationResolvesWithNilChoiceIndex() async throws {
        let nc = NotificationCenter()
        var capturedPayload: GenUIPayload?
        let presenter = GenUICardPresenter(notificationCenter: nc) { payload in
            capturedPayload = payload
        }

        let task = Task {
            await presenter.present(
                ClarifyPromptPresentation(question: "Anything you want to add?", choices: nil)
            )
        }

        for _ in 0..<50 {
            if capturedPayload != nil { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let payload = try #require(capturedPayload)

        // Free-text path: nil choiceIndex
        nc.post(
            name: .clarifyCardResolved,
            object: nil,
            userInfo: [
                ClarifyCardNotificationKey.payloadID: payload.id,
                ClarifyCardNotificationKey.response: "skip the search; just give me a summary",
            ]
        )

        let answer = await task.value
        #expect(answer.response == "skip the search; just give me a summary")
        #expect(answer.choiceIndex == nil)
        #expect(answer.cancelled == false)
    }

    @Test("Unrelated notification with different payloadID is ignored")
    func unrelatedNotificationIsIgnored() async throws {
        let nc = NotificationCenter()
        var capturedPayload: GenUIPayload?
        let presenter = GenUICardPresenter(notificationCenter: nc) { payload in
            capturedPayload = payload
        }

        let task = Task {
            await presenter.present(
                ClarifyPromptPresentation(question: "Q?", choices: ["A"])
            )
        }

        for _ in 0..<50 {
            if capturedPayload != nil { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let payload = try #require(capturedPayload)

        // Fire a notification with a DIFFERENT payload id — must be ignored.
        nc.post(
            name: .clarifyCardResolved,
            object: nil,
            userInfo: [
                ClarifyCardNotificationKey.payloadID: "some-other-card-id",
                ClarifyCardNotificationKey.response: "wrong answer",
            ]
        )

        // Brief sleep to let the spurious notification deliver if it would.
        try await Task.sleep(nanoseconds: 5_000_000) // 5ms
        #expect(!task.isCancelled, "presenter must NOT have resumed yet")

        // Now fire the correct notification.
        nc.post(
            name: .clarifyCardResolved,
            object: nil,
            userInfo: [
                ClarifyCardNotificationKey.payloadID: payload.id,
                ClarifyCardNotificationKey.response: "A",
                ClarifyCardNotificationKey.choiceIndex: 0,
            ]
        )

        let answer = await task.value
        #expect(answer.response == "A", "presenter must resolve with the MATCHING notification only")
    }

    @Test("Empty response is treated as cancelled")
    func emptyResponseIsCancelled() async throws {
        let nc = NotificationCenter()
        var capturedPayload: GenUIPayload?
        let presenter = GenUICardPresenter(notificationCenter: nc) { payload in
            capturedPayload = payload
        }

        let task = Task {
            await presenter.present(
                ClarifyPromptPresentation(question: "Q?", choices: nil)
            )
        }

        for _ in 0..<50 {
            if capturedPayload != nil { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let payload = try #require(capturedPayload)

        nc.post(
            name: .clarifyCardResolved,
            object: nil,
            userInfo: [
                ClarifyCardNotificationKey.payloadID: payload.id,
                ClarifyCardNotificationKey.response: "",
            ]
        )

        let answer = await task.value
        #expect(answer.response == "")
        #expect(answer.cancelled == true,
                "empty response must surface as cancelled so the agent loop falls back to its no-answer path")
    }

    @Test("Card surface callback receives a well-formed clarify payload")
    func cardSurfaceCallbackReceivesWellFormedPayload() async throws {
        let nc = NotificationCenter()
        var captured: GenUIPayload?
        let presenter = GenUICardPresenter(notificationCenter: nc) { payload in
            captured = payload
        }

        let task = Task {
            await presenter.present(
                ClarifyPromptPresentation(
                    question: "Which provider?",
                    choices: ["OpenAI", "Anthropic"]
                )
            )
        }

        for _ in 0..<50 {
            if captured != nil { break }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let payload = try #require(captured)
        #expect(payload.schema == .clarify)
        guard case let .clarify(question, choices, allowFreeText) = payload.body else {
            Issue.record("expected .clarify body")
            // Resolve the task so it doesn't hang.
            nc.post(
                name: .clarifyCardResolved,
                object: nil,
                userInfo: [
                    ClarifyCardNotificationKey.payloadID: payload.id,
                    ClarifyCardNotificationKey.response: "x",
                ]
            )
            _ = await task.value
            return
        }
        #expect(question == "Which provider?")
        #expect(choices == ["OpenAI", "Anthropic"])
        #expect(
            allowFreeText == false,
            "when choices are supplied, the presenter MUST disable free-text by default (cleaner UX)"
        )

        // Clean up: resolve the task so it doesn't leak.
        nc.post(
            name: .clarifyCardResolved,
            object: nil,
            userInfo: [
                ClarifyCardNotificationKey.payloadID: payload.id,
                ClarifyCardNotificationKey.response: "OpenAI",
                ClarifyCardNotificationKey.choiceIndex: 0,
            ]
        )
        _ = await task.value
    }
}
