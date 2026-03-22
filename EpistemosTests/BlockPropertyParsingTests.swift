import Foundation
import Testing
@testable import Epistemos

@Suite("BlockPropertyParser")
struct BlockPropertyParsingTests {

    @Test("parses two trailing properties")
    func twoTrailingProperties() {
        let result = BlockPropertyParser.parse("Some claim text @type=claim @confidence=0.7")
        #expect(result.count == 2)
        #expect(result["type"] == .string("claim"))
        #expect(result["confidence"] == .float(0.7))
    }

    @Test("no properties in plain text")
    func noProperties() {
        let result = BlockPropertyParser.parse("Just a normal line of text")
        #expect(result.isEmpty)
    }

    @Test("boolean property true")
    func boolTrue() {
        let result = BlockPropertyParser.parse("Pin this block @pinned=true")
        #expect(result["pinned"] == .bool(true))
    }

    @Test("boolean property false")
    func boolFalse() {
        let result = BlockPropertyParser.parse("@archived=false")
        #expect(result["archived"] == .bool(false))
    }

    @Test("float property")
    func floatProperty() {
        let result = BlockPropertyParser.parse("Claim @confidence=0.7")
        #expect(result["confidence"] == .float(0.7))
    }

    @Test("integer property")
    func integerProperty() {
        let result = BlockPropertyParser.parse("Priority item @priority=3")
        #expect(result["priority"] == .int(3))
    }

    @Test("empty line returns empty dict")
    func emptyLine() {
        let result = BlockPropertyParser.parse("")
        #expect(result.isEmpty)
    }

    @Test("ignores mid-sentence email-like @mentions")
    func ignoresMidSentence() {
        let result = BlockPropertyParser.parse("Email user@example.com about the meeting")
        #expect(result.isEmpty)
    }

    @Test("trailing properties after mid-sentence @mention")
    func trailingAfterMention() {
        let result = BlockPropertyParser.parse("Email user@example.com @status=done")
        #expect(result.count == 1)
        #expect(result["status"] == .string("done"))
    }

    @Test("string property value")
    func stringProperty() {
        let result = BlockPropertyParser.parse("Block @type=claim")
        #expect(result["type"] == .string("claim"))
    }

    @Test("parseValue standalone - float")
    func parseValueFloat() {
        #expect(BlockPropertyParser.parseValue("0.85") == .float(0.85))
    }

    @Test("parseValue standalone - int")
    func parseValueInt() {
        #expect(BlockPropertyParser.parseValue("42") == .int(42))
    }

    @Test("parseValue standalone - bool")
    func parseValueBool() {
        #expect(BlockPropertyParser.parseValue("true") == .bool(true))
        #expect(BlockPropertyParser.parseValue("false") == .bool(false))
    }

    @Test("parseValue standalone - string fallback")
    func parseValueString() {
        #expect(BlockPropertyParser.parseValue("hello") == .string("hello"))
    }

    @Test("whitespace-only line returns empty dict")
    func whitespaceOnly() {
        let result = BlockPropertyParser.parse("   ")
        #expect(result.isEmpty)
    }

    @Test("single property at end of line")
    func singleTrailing() {
        let result = BlockPropertyParser.parse("This is a block @type=evidence")
        #expect(result.count == 1)
        #expect(result["type"] == .string("evidence"))
    }

    @Test("property-only line")
    func propertyOnlyLine() {
        let result = BlockPropertyParser.parse("@status=active @priority=1")
        #expect(result.count == 2)
        #expect(result["status"] == .string("active"))
        #expect(result["priority"] == .int(1))
    }
}
