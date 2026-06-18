import Testing
@testable import Epistemos

/// P2.6 — the Companion builder's output-structure JSON is real wired config
/// (stored on CompanionModel, injected into the agent's system prompt as a
/// response contract). These lock the validator that keeps a malformed schema
/// from being saved as a broken contract.
@Suite("Companion output-schema validation")
struct CompanionOutputSchemaValidationTests {

    @Test("empty is acceptable — the field is optional")
    func emptyIsAcceptable() {
        #expect(CompanionOutputSchemaValidation.validate("") == .empty)
        #expect(CompanionOutputSchemaValidation.validate("   \n ") == .empty)
        #expect(CompanionOutputSchemaValidation.validate("").isAcceptable)
    }

    @Test("a schema-shaped JSON object is valid")
    func schemaObjectIsValid() {
        #expect(CompanionOutputSchemaValidation.validate(#"{"type":"object","properties":{"x":{"type":"string"}}}"#) == .valid)
        // `properties` alone (no top-level type) still reads as a schema.
        #expect(CompanionOutputSchemaValidation.validate(#"{"properties":{"y":{}}}"#) == .valid)
        #expect(CompanionOutputSchemaValidation.validate(#"{"type":"array"}"#).isAcceptable)
    }

    @Test("malformed JSON is rejected (not saved as a broken contract)")
    func malformedJSONRejected() {
        let result = CompanionOutputSchemaValidation.validate(#"{"type":"object",}"#) // trailing comma
        #expect(!result.isAcceptable)
        #expect(result.errorMessage != nil)
    }

    @Test("a non-object JSON value is rejected")
    func nonObjectRejected() {
        #expect(!CompanionOutputSchemaValidation.validate(#""just a string""#).isAcceptable)
        #expect(!CompanionOutputSchemaValidation.validate("[1,2,3]").isAcceptable)
        #expect(!CompanionOutputSchemaValidation.validate("42").isAcceptable)
    }

    @Test("a JSON object that isn't schema-shaped is rejected with guidance")
    func nonSchemaObjectRejected() {
        let result = CompanionOutputSchemaValidation.validate(#"{"hello":"world"}"#)
        #expect(!result.isAcceptable)
        #expect(result.errorMessage?.contains("type") == true)
    }
}
