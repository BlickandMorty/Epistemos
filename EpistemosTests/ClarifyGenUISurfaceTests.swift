import Foundation
import Testing
@testable import Epistemos

/// B.8 1/N — Clarify GenUI surface tests.
///
/// Master Fusion Plan §B.8 acceptance: a `GenUISchema.clarify` payload
/// must (a) round-trip through `GenUIDispatcher.shared`, (b) on user
/// resolution emit `Notification.Name.clarifyCardResolved` with the
/// canonical `{payloadID, response, choiceIndex}` userInfo shape, so
/// ChatCoordinator (B.8 2/N) can subscribe + thread the response back
/// into the running agent loop. This file pins both the schema/body
/// shape and the wire format of the notification.
@Suite("Clarify GenUI surface (B.8 1/N)")
struct ClarifyGenUISurfaceTests {
    @Test("GenUISchema includes the clarify case so producers can emit clarify payloads")
    func schemaIncludesClarifyCase() throws {
        let allRawValues = GenUISchema.allCases.map(\.rawValue)
        #expect(
            allRawValues.contains("clarify"),
            "GenUISchema.clarify case MUST be exported so producers can emit clarify payloads. Got cases: \(allRawValues)"
        )
    }

    @Test("Dispatcher registers the clarify schema in its sorted registeredSchemas")
    func dispatcherRegistersClarifySchema() throws {
        let registered = GenUIDispatcher.shared.registeredSchemas
        #expect(registered.contains(.clarify),
                "GenUIDispatcher.shared.registeredSchemas MUST include .clarify; got \(registered.map(\.rawValue))")
    }

    @Test("Convenience constructor builds a well-formed clarify payload")
    func convenienceConstructorBuildsWellFormedPayload() throws {
        let payload = GenUIPayload.clarify(
            question: "Which provider should handle this turn?",
            choices: ["OpenAI", "Anthropic", "Local Qwen"],
            allowFreeText: true
        )
        #expect(payload.schema == .clarify)
        guard case let .clarify(q, choices, allowFreeText) = payload.body else {
            Issue.record("expected .clarify body, got \(payload.body)")
            return
        }
        #expect(q == "Which provider should handle this turn?")
        #expect(choices == ["OpenAI", "Anthropic", "Local Qwen"])
        #expect(allowFreeText == true)
        #expect(payload.schema.canonicalBody(payload.body),
                "canonicalBody MUST return true for matching schema↔body pair")
    }

    @Test("Canonical body mapping rejects non-clarify body on clarify schema")
    func canonicalBodyMappingRejectsMismatch() throws {
        let mismatch = GenUIPayload(schema: .clarify, title: "", body: .raw("not a clarify body"))
        #expect(!mismatch.schema.canonicalBody(mismatch.body),
                "GenUISchema.clarify MUST reject .raw body (deny drift early)")
    }

    @Test("Clarify body case carries the expected default values")
    func clarifyBodyCarriesDefaultValues() throws {
        let payload = GenUIPayload.clarify(question: "Free-form question?")
        guard case let .clarify(_, choices, allowFreeText) = payload.body else {
            Issue.record("expected .clarify body")
            return
        }
        #expect(choices.isEmpty, "default choices array must be empty")
        #expect(allowFreeText == true, "default allowFreeText must be true (free-form question)")
    }

    @Test("Notification.Name.clarifyCardResolved name is stable for the FFI contract")
    func notificationNameIsStable() throws {
        // ChatCoordinator (B.8 2/N) will subscribe to this exact name.
        // Pin it so a future rename trips this test before the
        // ChatCoordinator subscription silently breaks.
        #expect(Notification.Name.clarifyCardResolved.rawValue == "EpistemosClarifyCardResolved")
    }

    @Test("Clarify notification userInfo keys match the Rust ClarifyHandler return shape")
    func notificationUserInfoKeysMatchRustContract() throws {
        // Rust returns: { question, response, choice_index }
        // Swift posts: payloadID + response + choiceIndex (no question,
        // since the payload itself is the question and the consumer
        // already has the payload by id).
        #expect(ClarifyCardNotificationKey.payloadID == "payloadID")
        #expect(ClarifyCardNotificationKey.response == "response")
        #expect(ClarifyCardNotificationKey.choiceIndex == "choiceIndex")
    }
}
