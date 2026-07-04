import Foundation
import Testing
@testable import Epistemos

/// RES-2: `LiteParsePDFConversion.importToMarkdown` must bound the synchronous, uncancellable
/// liteparse FFI — on timeout it abandons the stuck conversion and returns promptly, and it
/// still returns the real result when the conversion beats the deadline.
struct LiteParsePDFConversionTests {
    /// Stand-in importer whose synchronous `importToMarkdown` blocks, simulating a stuck FFI.
    nonisolated private struct BlockingImporter: LiteParsePDFImporter {
        let blockFor: TimeInterval
        func importToMarkdown(pdfPath: String) -> LiteParseImportResult {
            Thread.sleep(forTimeInterval: blockFor)
            return .markdown("late — should have been abandoned")
        }
    }

    nonisolated private struct FastImporter: LiteParsePDFImporter {
        func importToMarkdown(pdfPath: String) -> LiteParseImportResult { .markdown("ok") }
    }

    @Test func timesOutAndReturnsBeforeTheStuckConversionFinishes() async {
        let start = Date()
        await #expect(throws: LiteParsePDFConversion.TimedOut.self) {
            _ = try await LiteParsePDFConversion.importToMarkdown(
                using: BlockingImporter(blockFor: 1.0),
                pdfPath: "/dev/null",
                timeout: .milliseconds(100))
        }
        // The await returned on the ~100ms deadline, NOT after the importer's 1s block —
        // proving the stuck conversion was abandoned rather than awaited to completion.
        #expect(Date().timeIntervalSince(start) < 0.7)
    }

    @Test func returnsResultWhenConversionBeatsTheDeadline() async throws {
        let result = try await LiteParsePDFConversion.importToMarkdown(
            using: FastImporter(),
            pdfPath: "/dev/null",
            timeout: .seconds(5))
        #expect(result == .markdown("ok"))
    }
}
