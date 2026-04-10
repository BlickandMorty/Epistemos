import Foundation
import Testing
@testable import Epistemos

// MARK: - Privacy Test

/// Verifies privacy protections for the Knowledge Fusion subsystem.
/// Per ANCHOR 3, GAP 4: adapter .safetensors files contain dense
/// representations of personal data — PII must be redacted before storage.
///
/// Per ANCHOR 3, GAP 5: safety alignment — PTST strategy at inference.
@Suite("Privacy and Safety")
struct PrivacyTest {

    // MARK: - PII Redaction Coverage

    @Test("Email addresses are redacted from feedback")
    func redactsEmails() async throws {
        let dbPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-privacy-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbPath) }

        let logger = FeedbackLogger(databasePath: dbPath)
        try await logger.open()
        defer { Task { await logger.close() } }

        try await logger.log(
            prompt: "Send an email to ceo@company.com about the project",
            completion: "I'll draft an email to marketing@brand.org right away",
            desirable: true,
            feedbackType: .acceptGhost
        )

        let signals = try await logger.fetchSignals(since: Date().addingTimeInterval(-60))
        #expect(signals.count == 1)
        #expect(!signals[0].prompt.contains("ceo@company.com"))
        #expect(!signals[0].completion.contains("marketing@brand.org"))
        #expect(signals[0].prompt.contains("[REDACTED_EMAIL]"))
        #expect(signals[0].completion.contains("[REDACTED_EMAIL]"))
    }

    @Test("Phone numbers are redacted from feedback")
    func redactsPhones() async throws {
        let dbPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-privacy-phone-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbPath) }

        let logger = FeedbackLogger(databasePath: dbPath)
        try await logger.open()
        defer { Task { await logger.close() } }

        try await logger.log(
            prompt: "Call me at (555) 123-4567",
            completion: "I'll schedule a call to 800-555-0199",
            desirable: false,
            feedbackType: .rejectEdit
        )

        let signals = try await logger.fetchSignals(since: Date().addingTimeInterval(-60))
        #expect(!signals[0].prompt.contains("555"))
        #expect(!signals[0].completion.contains("800"))
    }

    @Test("SSN patterns are redacted")
    func redactsSSN() {
        let redactor = PIIRedactor()
        let text = "My SSN is 123-45-6789 and his is 987-65-4321"
        let result = redactor.redact(text)
        #expect(!result.contains("123-45-6789"))
        #expect(!result.contains("987-65-4321"))
        #expect(result.components(separatedBy: "[REDACTED_SSN]").count == 3)
    }

    @Test("Credit card patterns are redacted")
    func redactsCC() {
        let redactor = PIIRedactor()
        let text = "Card ending in 4111-1111-1111-1111, backup 5500 0000 0000 0004"
        let result = redactor.redact(text)
        #expect(!result.contains("4111"))
        #expect(!result.contains("5500"))
    }

    @Test("Multiple PII types redacted simultaneously")
    func multipleTypes() {
        let redactor = PIIRedactor()
        let text = "Contact john@doe.com at 555-123-4567, SSN 111-22-3333"
        let result = redactor.redact(text)
        #expect(!result.contains("john@doe.com"))
        #expect(!result.contains("555-123-4567"))
        #expect(!result.contains("111-22-3333"))
    }

    @Test("Non-PII text is preserved exactly")
    func preservesNonPII() {
        let redactor = PIIRedactor()
        let text = "The quick brown fox jumps over the lazy dog. Quantum computing uses qubits."
        #expect(redactor.redact(text) == text)
    }

    // MARK: - KTO JSONL Export Privacy

    @Test("Exported KTO JSONL contains redacted data only")
    func exportedDataRedacted() async throws {
        let dbPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-privacy-export-\(UUID().uuidString).db")
        let exportPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-privacy-export-\(UUID().uuidString).jsonl")
        defer {
            try? FileManager.default.removeItem(at: dbPath)
            try? FileManager.default.removeItem(at: exportPath)
        }

        let logger = FeedbackLogger(databasePath: dbPath)
        try await logger.open()
        defer { Task { await logger.close() } }

        // Log feedback with PII
        try await logger.log(
            prompt: "Email alice@secret.com about the meeting",
            completion: "Sure, I'll contact alice@secret.com at 555-999-8888",
            desirable: true,
            feedbackType: .acceptGhost
        )

        let count = try await logger.exportToJSONL(since: Date().addingTimeInterval(-60), outputPath: exportPath)
        #expect(count == 1)

        let content = try String(contentsOf: exportPath, encoding: .utf8)
        #expect(!content.contains("alice@secret.com"))
        #expect(!content.contains("555-999-8888"))
        #expect(content.contains("[REDACTED_EMAIL]"))
        #expect(content.contains("[REDACTED_PHONE]"))
    }

    // MARK: - Adapter Export Privacy

    @Test("Exported adapter bundle excludes raw training data")
    func adapterExportExcludesTrainingData() throws {
        let adapterDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-privacy-adapter-\(UUID().uuidString)")
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-privacy-export-bundle-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: adapterDir)
            try? FileManager.default.removeItem(at: outputDir)
        }

        try FileManager.default.createDirectory(at: adapterDir, withIntermediateDirectories: true)
        try Data([0x00]).write(to: adapterDir.appendingPathComponent("adapter_weights.safetensors"))
        try "{}".write(to: adapterDir.appendingPathComponent("adapter_config.json"), atomically: true, encoding: .utf8)

        // Simulate training data in same directory
        try "private vault content".write(
            to: adapterDir.appendingPathComponent("training_data.jsonl"),
            atomically: true, encoding: .utf8
        )

        let metaJSON = """
        {"adapter_type":"knowledge","source_vault":"test","lora_rank":32,"lora_alpha":64,\
        "target_modules":["q_proj"],"learning_rate":0.00002,"num_examples":100,"num_iters":50,\
        "training_duration_seconds":30.0,"created_at":"2026-03-23T00:00:00Z","base_model":"test","quality_score":null}
        """
        let metaPath = adapterDir.appendingPathComponent("training_metadata.json")
        try metaJSON.write(to: metaPath, atomically: true, encoding: .utf8)

        let record = AdapterRecord(
            id: UUID(), name: "PrivacyTest", type: .knowledge,
            adapterPath: adapterDir, metadataPath: metaPath,
            sourceVault: "private_vault", createdAt: Date(),
            qualityScore: nil, isActive: false, baseModel: "test",
            loraRank: 32, parameterCount: 1000, trainingExamples: 100
        )

        let exporter = AdapterExporter()
        let bundlePath = try exporter.export(record: record, outputDirectory: outputDir)

        // Verify bundle exists
        #expect(FileManager.default.fileExists(atPath: bundlePath.path))

        // Extract and verify NO training data leaked
        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-privacy-extract-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: extractDir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", bundlePath.path, extractDir.path]
        try process.run()
        process.waitUntilExit()

        // training_data.jsonl should NOT be in the bundle
        let extractedFiles = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
        #expect(!extractedFiles.contains("training_data.jsonl"),
               "Training data should not be included in exported bundle")
    }

    // MARK: - Script Safety

    @Test("No DPO in any training script")
    func noDPO() throws {
        let scriptsBase = try sourceMirrorURL(for: "Epistemos/KnowledgeFusion")

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: scriptsBase, includingPropertiesForKeys: nil) else { return }

        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "py" else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(!content.contains("dpo_loss"), "Found DPO loss in \(url.lastPathComponent)")
            #expect(!content.contains("DirectPreference"), "Found DPO class in \(url.lastPathComponent)")
        }
    }

    @Test("No adapter fusion in any Python script")
    func noFusion() throws {
        let scriptsBase = try sourceMirrorURL(for: "Epistemos/KnowledgeFusion")

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: scriptsBase, includingPropertiesForKeys: nil) else { return }

        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "py" else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(!content.contains("merge_weights=True"), "Found fusion in \(url.lastPathComponent)")
            #expect(!content.contains("merge_adapter("), "Found merge_adapter in \(url.lastPathComponent)")
        }
    }
}
