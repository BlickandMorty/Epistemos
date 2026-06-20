import Testing
import Foundation

@testable import Epistemos

// SS-LS 1b brick 2 — the KTO data-prep, unit-witnessed without a model. Parses the
// feedback JSONL (FeedbackLogger.exportToJSONL format) into typed KTO examples for
// the native loop. KTOTrainer's Python path is untouched by this brick.
@Suite("Native KTO data-prep (SS-LS 1b)")
struct NativeKTODataPrepTests {

    @Test("parses {prompt, completion, label} lines into typed examples, preserving order + labels")
    func parsesValidRows() {
        let jsonl = """
        {"completion":"yes","label":true,"prompt":"a"}
        {"completion":"no","label":false,"prompt":"b"}
        """
        let examples = NativeKTODataPrep.parseFeedbackJSONL(jsonl)
        #expect(examples == [
            KTOExample(prompt: "a", completion: "yes", desirable: true),
            KTOExample(prompt: "b", completion: "no", desirable: false),
        ])
    }

    @Test("skips malformed / blank / field-missing lines but keeps the valid ones")
    func skipsBadRows() {
        let jsonl = """
        {"prompt":"a","completion":"x","label":true}

        not json at all
        {"prompt":"b","completion":"y"}
        {"prompt":"c","completion":"z","label":false}
        """
        let examples = NativeKTODataPrep.parseFeedbackJSONL(jsonl)
        // The blank line, the non-JSON line, and the label-missing line are skipped.
        #expect(examples == [
            KTOExample(prompt: "a", completion: "x", desirable: true),
            KTOExample(prompt: "c", completion: "z", desirable: false),
        ])
    }

    @Test("empty input yields no examples")
    func emptyInput() {
        #expect(NativeKTODataPrep.parseFeedbackJSONL("").isEmpty)
        #expect(NativeKTODataPrep.parseFeedbackJSONL("\n  \n").isEmpty)
    }

    @Test("loadFeedbackExamples reads a JSONL file; an unreadable path yields []")
    func loadsFromFile() throws {
        let fm = FileManager.default
        let url = fm.temporaryDirectory.appendingPathComponent("kto-\(UUID().uuidString).jsonl")
        defer { try? fm.removeItem(at: url) }
        try #"{"prompt":"p","completion":"c","label":true}"#.write(to: url, atomically: true, encoding: .utf8)
        #expect(NativeKTODataPrep.loadFeedbackExamples(at: url)
            == [KTOExample(prompt: "p", completion: "c", desirable: true)])

        let missing = fm.temporaryDirectory.appendingPathComponent("nope-\(UUID().uuidString).jsonl")
        #expect(NativeKTODataPrep.loadFeedbackExamples(at: missing).isEmpty)
    }

    @Test("partition splits desirable from undesirable")
    func partitions() {
        let examples = [
            KTOExample(prompt: "a", completion: "x", desirable: true),
            KTOExample(prompt: "b", completion: "y", desirable: false),
            KTOExample(prompt: "c", completion: "z", desirable: true),
        ]
        let (desirable, undesirable) = NativeKTODataPrep.partition(examples)
        #expect(desirable.count == 2)
        #expect(undesirable.count == 1)
        #expect(undesirable.first?.prompt == "b")
    }
}
