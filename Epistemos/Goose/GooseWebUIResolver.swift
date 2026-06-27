import Foundation

enum GooseWebUIResolver {
    nonisolated static let explicitIndexEnvironmentKey = "EPISTEMOS_GOOSE_UI_INDEX"
    nonisolated static let explicitDirectoryEnvironmentKey = "EPISTEMOS_GOOSE_UI_DIR"
    nonisolated static let artifactManifestFileName = ".epistemos-goose-webui.json"

    nonisolated static func indexURL(
        bundle: Bundle? = .main,
        fileManager: FileManager = .default,
        appSupportDirectory: URL? = defaultAppSupportDirectory(fileManager: .default),
        currentDirectory: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        for candidate in candidateIndexURLs(
            bundle: bundle,
            appSupportDirectory: appSupportDirectory,
            currentDirectory: currentDirectory,
            environment: environment
        ) where isACPModeArtifact(indexURL: candidate, fileManager: fileManager) {
            return candidate
        }
        return nil
    }

    nonisolated private static func candidateIndexURLs(
        bundle: Bundle?,
        appSupportDirectory: URL?,
        currentDirectory: String,
        environment: [String: String]
    ) -> [URL] {
        var candidates: [URL] = []

        if let explicitIndex = environment[explicitIndexEnvironmentKey],
           !explicitIndex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidates.append(fileURL(explicitIndex))
        }

        if let explicitDirectory = environment[explicitDirectoryEnvironmentKey],
           !explicitDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidates.append(fileURL(explicitDirectory).appendingPathComponent("index.html"))
        }

        if let bundled = bundle?.url(forResource: "goose-desktop/index", withExtension: "html") {
            candidates.append(bundled)
        }

        if let appSupportDirectory {
            candidates.append(appSupportDirectory.appendingPathComponent("Epistemos/GooseWebUI/index.html"))
        }

        candidates.append(
            URL(fileURLWithPath: currentDirectory)
                .appendingPathComponent(".research-clones/work/goose/ui/desktop/dist/index.html")
        )

        return candidates
    }

    nonisolated private static func defaultAppSupportDirectory(fileManager: FileManager) -> URL? {
        try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
    }

    nonisolated private static func fileURL(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    nonisolated private static func isACPModeArtifact(
        indexURL: URL,
        fileManager: FileManager
    ) -> Bool {
        guard fileManager.fileExists(atPath: indexURL.path) else { return false }
        let manifestURL = indexURL.deletingLastPathComponent()
            .appendingPathComponent(artifactManifestFileName)
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(ArtifactManifest.self, from: data) else {
            return false
        }
        return manifest.acpMode
    }

    nonisolated private struct ArtifactManifest: Decodable {
        let acpMode: Bool
    }
}
