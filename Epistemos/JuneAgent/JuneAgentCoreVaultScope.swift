#if EPISTEMOS_APP_STORE
import Foundation

@MainActor
enum JuneAgentCoreVaultScope {
    static func vaultPathForAgentCore() -> String {
        if let selectedVaultPath = watchedVaultPathForAgentCore() {
            return selectedVaultPath
        }

        return agentCoreScratchURL().path
    }

    static func redactedVaultRootCandidates() -> [String] {
        var paths: [String] = []
        if let watched = watchedVaultPathForAgentCore() {
            paths.append(contentsOf: rootRedactionForms(for: URL(fileURLWithPath: watched)))
        }
        paths.append(contentsOf: rootRedactionForms(for: agentCoreScratchURL(createDirectory: false)))
        var seen = Set<String>()
        let unique = paths.filter { path in
            !path.isEmpty && seen.insert(path).inserted
        }
        return unique.sorted { left, right in
            left.count == right.count ? left < right : left.count > right.count
        }
    }

    private static func agentCoreScratchURL(createDirectory: Bool = true) -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: createDirectory
        )) ?? FileManager.default.temporaryDirectory
        let scratch = base
            .appendingPathComponent("Epistemos/JuneAgent/agent-core-scratch", isDirectory: true)
        if createDirectory {
            try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        }
        return scratch
    }

    private static func watchedVaultPathForAgentCore() -> String? {
        guard let vaultSync = AppBootstrap.shared?.vaultSync,
              vaultSync.isWatching,
              let vaultURL = vaultSync.vaultURL?.standardizedFileURL else {
            return nil
        }
        return vaultURL.path
    }

    private static func rootRedactionForms(for url: URL) -> [String] {
        let standardized = url.standardizedFileURL
        let resolved = standardized.resolvingSymlinksInPath()
        var forms = [standardized.path, standardized.absoluteString]
        if let encoded = standardized.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            forms.append(encoded)
        }
        if resolved.path != standardized.path {
            forms.append(resolved.path)
            forms.append(resolved.absoluteString)
            if let encoded = resolved.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                forms.append(encoded)
            }
        }
        return forms
    }
}
#endif
