import Foundation

// MARK: - AdapterExporter

/// Exports and imports adapters as ".epistemos-adapter" skill pack bundles.
///
/// Export format: zip archive containing:
///   - adapter_weights.safetensors
///   - adapter_config.json
///   - training_metadata.json
///   - README.md (auto-generated)
///
/// Export EXCLUDES raw training data (privacy protection).
/// Only adapter weights are shared — NOT the vault content that produced them.
nonisolated struct AdapterExporter: Sendable {

    static let bundleExtension = "epistemos-adapter"

    // MARK: - Export

    func export(record: AdapterRecord, outputDirectory: URL) throws -> URL {
        let bundlePath = outputDirectory
            .appendingPathComponent(defaultBundleName(for: record))
            .appendingPathExtension(Self.bundleExtension)
        return try export(record: record, outputURL: bundlePath)
    }

    func export(record: AdapterRecord, outputURL: URL) throws -> URL {
        let fm = FileManager.default
        let bundlePath = normalizedExportURL(from: outputURL)
        let outputDirectory = bundlePath.deletingLastPathComponent()
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // Create staging directory
        let stagingDir = fm.temporaryDirectory.appendingPathComponent("kf-export-\(UUID().uuidString)")
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stagingDir) }

        // Copy adapter files
        let weightsSource = record.adapterPath.appendingPathComponent("adapter_weights.safetensors")
        let configSource = record.adapterPath.appendingPathComponent("adapter_config.json")

        if fm.fileExists(atPath: weightsSource.path) {
            try fm.copyItem(at: weightsSource, to: stagingDir.appendingPathComponent("adapter_weights.safetensors"))
        }
        if fm.fileExists(atPath: configSource.path) {
            try fm.copyItem(at: configSource, to: stagingDir.appendingPathComponent("adapter_config.json"))
        }

        // Copy metadata
        if fm.fileExists(atPath: record.metadataPath.path) {
            try fm.copyItem(at: record.metadataPath, to: stagingDir.appendingPathComponent("training_metadata.json"))
        }

        // Generate README
        let readme = generateReadme(record: record)
        try readme.write(to: stagingDir.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        // Create zip archive
        try createZip(from: stagingDir, to: bundlePath)

        return bundlePath
    }

    private func defaultBundleName(for record: AdapterRecord) -> String {
        "\(record.name.replacingOccurrences(of: " ", with: "_"))_\(record.type.rawValue)"
    }

    private func normalizedExportURL(from outputURL: URL) -> URL {
        guard outputURL.pathExtension != Self.bundleExtension else { return outputURL }
        return outputURL.deletingPathExtension().appendingPathExtension(Self.bundleExtension)
    }

    // MARK: - Import

    func importBundle(from bundlePath: URL, destinationDirectory: URL) throws -> ImportedAdapter {
        let fm = FileManager.default

        // Extract zip
        let extractDir = fm.temporaryDirectory.appendingPathComponent("kf-import-\(UUID().uuidString)")
        try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: extractDir) }

        try extractZip(from: bundlePath, to: extractDir)

        // Read metadata
        let metadataPath = extractDir.appendingPathComponent("training_metadata.json")
        guard fm.fileExists(atPath: metadataPath.path) else {
            throw AdapterExporterError.invalidBundle("Missing training_metadata.json")
        }
        let metadataData = try Data(contentsOf: metadataPath)
        let metadata = try JSONDecoder().decode(AdapterMetadata.self, from: metadataData)

        // Create destination
        let adapterId = UUID()
        let adapterDir = destinationDirectory.appendingPathComponent(adapterId.uuidString)
        try fm.createDirectory(at: adapterDir, withIntermediateDirectories: true)

        // Copy files to destination
        let weightsSource = extractDir.appendingPathComponent("adapter_weights.safetensors")
        if fm.fileExists(atPath: weightsSource.path) {
            try fm.copyItem(at: weightsSource, to: adapterDir.appendingPathComponent("adapter_weights.safetensors"))
        }

        let configSource = extractDir.appendingPathComponent("adapter_config.json")
        if fm.fileExists(atPath: configSource.path) {
            try fm.copyItem(at: configSource, to: adapterDir.appendingPathComponent("adapter_config.json"))
        }

        try metadataData.write(
            to: adapterDir.appendingPathComponent("training_metadata.json"),
            options: .atomic
        )

        return ImportedAdapter(
            id: adapterId,
            adapterPath: adapterDir,
            metadataPath: adapterDir.appendingPathComponent("training_metadata.json"),
            metadata: metadata
        )
    }

    // MARK: - Validation

    func validateBundle(at path: URL) -> Bool {
        let fm = FileManager.default
        let extractDir = fm.temporaryDirectory.appendingPathComponent("kf-validate-\(UUID().uuidString)")

        defer { try? fm.removeItem(at: extractDir) }

        do {
            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try extractZip(from: path, to: extractDir)

            // Must have at least metadata
            let metadataExists = fm.fileExists(atPath: extractDir.appendingPathComponent("training_metadata.json").path)
            let weightsExist = fm.fileExists(atPath: extractDir.appendingPathComponent("adapter_weights.safetensors").path)

            return metadataExists && weightsExist
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func generateReadme(record: AdapterRecord) -> String {
        """
        # Epistemos Adapter: \(record.name)

        Type: \(record.type.rawValue)
        Base Model: \(record.baseModel)
        LoRA Rank: \(record.loraRank)
        Training Examples: \(record.trainingExamples)
        Created: \(ISO8601DateFormatter().string(from: record.createdAt))
        Quality Score: \(record.qualityScore.map { String(format: "%.2f", $0) } ?? "Not evaluated")

        Generated by Epistemos Knowledge Fusion.
        """
    }

    private func createZip(from sourceDir: URL, to destination: URL) throws {
        #if !EPISTEMOS_APP_STORE
        let process = Process.init()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", sourceDir.path, destination.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AdapterExporterError.zipFailed
        }
        #else
        // The App Store sandbox cannot spawn /usr/bin/ditto. Adapter
        // export/import is a Pro/direct-only feature; AppBootstrap and
        // SettingsView already gate the KnowledgeFusion entry points
        // out of MAS, so this surgical body gate is defense-in-depth.
        _ = sourceDir
        _ = destination
        throw AdapterExporterError.zipFailed
        #endif
    }

    private func extractZip(from zipPath: URL, to destination: URL) throws {
        #if !EPISTEMOS_APP_STORE
        let process = Process.init()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipPath.path, destination.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AdapterExporterError.unzipFailed
        }
        #else
        // Same MAS rationale as createZip(...).
        _ = zipPath
        _ = destination
        throw AdapterExporterError.unzipFailed
        #endif
    }
}

// MARK: - Types

struct ImportedAdapter: Sendable {
    let id: UUID
    let adapterPath: URL
    let metadataPath: URL
    let metadata: AdapterMetadata
}

// MARK: - Errors

enum AdapterExporterError: Error, LocalizedError {
    case invalidBundle(String)
    case zipFailed
    case unzipFailed

    var errorDescription: String? {
        switch self {
        case .invalidBundle(let msg): return "Invalid adapter bundle: \(msg)"
        case .zipFailed: return "Failed to create zip archive"
        case .unzipFailed: return "Failed to extract zip archive"
        }
    }
}
