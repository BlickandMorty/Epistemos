import Foundation
import Testing
@testable import Epistemos

// MARK: - FeedbackLogger Tests

@Suite("FeedbackLogger")
struct FeedbackLoggerTests {

    private func makeTempDB() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-feedback-\(UUID().uuidString).db")
    }

    @Test("Log and fetch feedback signals")
    func logAndFetch() async throws {
        let dbPath = makeTempDB()
        defer { try? FileManager.default.removeItem(at: dbPath) }

        let logger = FeedbackLogger(databasePath: dbPath)
        try await logger.open()
        defer { Task { await logger.close() } }

        // Log positive signal
        try await logger.log(
            prompt: "Help me write about AI",
            completion: "Here's a draft about artificial intelligence...",
            desirable: true,
            feedbackType: .acceptGhost,
            contextSummary: "Note editor"
        )

        // Log negative signal
        try await logger.log(
            prompt: "Summarize this document",
            completion: "The document discusses...",
            desirable: false,
            feedbackType: .rejectEdit
        )

        let signals = try await logger.fetchSignals(since: Date().addingTimeInterval(-60))
        #expect(signals.count == 2)
        #expect(signals[0].desirable == true)
        #expect(signals[1].desirable == false)
    }

    @Test("PII redaction removes emails and phone numbers")
    func piiRedaction() async throws {
        let dbPath = makeTempDB()
        defer { try? FileManager.default.removeItem(at: dbPath) }

        let logger = FeedbackLogger(databasePath: dbPath)
        try await logger.open()
        defer { Task { await logger.close() } }

        try await logger.log(
            prompt: "Send email to john@example.com about meeting",
            completion: "Call me at 555-123-4567 or email jane@test.org",
            desirable: true,
            feedbackType: .acceptGhost
        )

        let signals = try await logger.fetchSignals(since: Date().addingTimeInterval(-60))
        #expect(signals.count == 1)

        // PII should be redacted
        #expect(!signals[0].prompt.contains("john@example.com"))
        #expect(signals[0].prompt.contains("[REDACTED_EMAIL]"))
        #expect(!signals[0].completion.contains("555-123-4567"))
        #expect(signals[0].completion.contains("[REDACTED_PHONE]"))
        #expect(!signals[0].completion.contains("jane@test.org"))
    }

    @Test("Count signals works correctly")
    func countSignals() async throws {
        let dbPath = makeTempDB()
        defer { try? FileManager.default.removeItem(at: dbPath) }

        let logger = FeedbackLogger(databasePath: dbPath)
        try await logger.open()
        defer { Task { await logger.close() } }

        let before = Date()
        for i in 0..<5 {
            try await logger.log(
                prompt: "Q\(i)", completion: "A\(i)",
                desirable: i % 2 == 0,
                feedbackType: i % 2 == 0 ? .acceptGhost : .rejectEdit
            )
        }

        let count = try await logger.countSignals(since: before)
        #expect(count == 5)
    }

    @Test("Export to KTO JSONL format")
    func exportJSONL() async throws {
        let dbPath = makeTempDB()
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-kto-export-\(UUID().uuidString).jsonl")
        defer {
            try? FileManager.default.removeItem(at: dbPath)
            try? FileManager.default.removeItem(at: outputPath)
        }

        let logger = FeedbackLogger(databasePath: dbPath)
        try await logger.open()
        defer { Task { await logger.close() } }

        try await logger.log(prompt: "Q1", completion: "A1", desirable: true, feedbackType: .acceptGhost)
        try await logger.log(prompt: "Q2", completion: "A2", desirable: false, feedbackType: .rejectEdit)

        let count = try await logger.exportToJSONL(since: Date().addingTimeInterval(-60), outputPath: outputPath)
        #expect(count == 2)

        // Validate JSONL format
        let content = try String(contentsOf: outputPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == 2)

        for line in lines {
            let data = line.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json?["prompt"] != nil)
            #expect(json?["completion"] != nil)
            #expect(json?["label"] != nil)
        }

        // First should be positive (label: true)
        let first = try JSONSerialization.jsonObject(with: lines[0].data(using: .utf8)!) as! [String: Any]
        #expect(first["label"] as? Bool == true)
    }

    @Test("Stats reports accepts and rejects")
    func feedbackStats() async throws {
        let dbPath = makeTempDB()
        defer { try? FileManager.default.removeItem(at: dbPath) }

        let logger = FeedbackLogger(databasePath: dbPath)
        try await logger.open()
        defer { Task { await logger.close() } }

        for _ in 0..<7 {
            try await logger.log(prompt: "Q", completion: "A", desirable: true, feedbackType: .acceptGhost)
        }
        for _ in 0..<3 {
            try await logger.log(prompt: "Q", completion: "A", desirable: false, feedbackType: .rejectEdit)
        }

        let stats = try await logger.stats()
        #expect(stats.totalAccepts == 7)
        #expect(stats.totalRejects == 3)
        #expect(stats.totalThisWeek == 10)
    }
}

// MARK: - KTOTrainer Tests

@Suite("KTOTrainer")
struct KTOTrainerTests {

    @Test("Skips when insufficient feedback signals")
    func skipsInsufficientSignals() async throws {
        let feedbackPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-kto-skip-\(UUID().uuidString).jsonl")
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-kto-out-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: feedbackPath)
            try? FileManager.default.removeItem(at: outputPath)
        }

        // Write only 5 signals (below minimum of 20)
        let lines = (0..<5).map { i in
            "{\"prompt\":\"Q\(i)\",\"completion\":\"A\(i)\",\"label\":true}"
        }
        try lines.joined(separator: "\n").write(to: feedbackPath, atomically: true, encoding: .utf8)

        let trainer = KTOTrainer(minimumBatch: 20)
        let result = try await trainer.runKTOUpdate(
            modelPath: URL(fileURLWithPath: "/nonexistent"),
            adapterPath: nil,
            feedbackPath: feedbackPath,
            outputPath: outputPath
        )

        #expect(result.skipped == true)
        #expect(result.signalsUsed == 5)
        #expect(result.newAdapterPath == nil)
    }
}

// MARK: - PIIRedactor Tests

@Suite("PIIRedactor")
struct PIIRedactorTests {

    @Test("Redacts email addresses")
    func redactsEmails() {
        let redactor = PIIRedactor()
        let result = redactor.redact("Contact john@example.com for info")
        #expect(!result.contains("john@example.com"))
        #expect(result.contains("[REDACTED_EMAIL]"))
    }

    @Test("Redacts phone numbers")
    func redactsPhones() {
        let redactor = PIIRedactor()
        let result = redactor.redact("Call 555-123-4567 for info")
        #expect(!result.contains("555-123-4567"))
        #expect(result.contains("[REDACTED_PHONE]"))
    }

    @Test("Redacts SSN")
    func redactsSSN() {
        let redactor = PIIRedactor()
        let result = redactor.redact("SSN is 123-45-6789")
        #expect(!result.contains("123-45-6789"))
        #expect(result.contains("[REDACTED_SSN]"))
    }

    @Test("Redacts credit card numbers")
    func redactsCC() {
        let redactor = PIIRedactor()
        let result = redactor.redact("Card: 4111-1111-1111-1111")
        #expect(!result.contains("4111-1111-1111-1111"))
        #expect(result.contains("[REDACTED_CC]"))
    }

    @Test("Preserves non-PII text")
    func preservesNormal() {
        let redactor = PIIRedactor()
        let text = "The quick brown fox jumps over the lazy dog"
        #expect(redactor.redact(text) == text)
    }
}

// MARK: - KTO Script Compliance

@Suite("KTO Script Compliance")
struct KTOScriptComplianceTests {

    @Test("KTO script does not use DPO")
    func noDPO() throws {
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/KnowledgeFusion/Alignment/scripts/train_kto.py")

        guard FileManager.default.fileExists(atPath: sourcePath.path) else { return }
        let content = try String(contentsOf: sourcePath, encoding: .utf8)

        // ANCHOR 1 Subsystem 4: KTO ONLY, NOT DPO
        #expect(!content.contains("DirectPreference"))
        #expect(!content.contains("dpo_loss"))
        #expect(!content.contains("reference_model"))

        // Must contain KTO
        #expect(content.contains("KTO"))
        #expect(content.contains("KTO_BETA"))

        // Must have minimum batch check
        #expect(content.contains("MIN_FEEDBACK_BATCH"))
        #expect(content.contains("SKIPPED"))

        // No fusion
        #expect(!content.contains("merge_weights=True"))
        #expect(!content.contains("merge_adapter("))
    }

    @Test("KTO uses binary label format")
    func binaryLabels() throws {
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/KnowledgeFusion/Alignment/scripts/train_kto.py")

        guard FileManager.default.fileExists(atPath: sourcePath.path) else { return }
        let content = try String(contentsOf: sourcePath, encoding: .utf8)

        // KTO uses binary labels (true/false), not scores
        #expect(content.contains("\"label\""))
    }
}
