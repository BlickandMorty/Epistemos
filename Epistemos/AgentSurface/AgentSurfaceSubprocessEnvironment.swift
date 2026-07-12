#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)
import Foundation

enum AgentSurfaceSubprocessEnvironment {
    nonisolated static let maxSubprocessEnvironmentValueCharacters = 4_096
    nonisolated static let maxSubprocessPathCharacters = 8_192
    nonisolated static let maxSubprocessPathEntryCharacters = 4_096
    nonisolated static let maxSubprocessPathEntries = 64

    nonisolated private static let subprocessEnvironmentAllowlist: Set<String> = [
        "PATH", "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TERM", "TZ",
    ]
    nonisolated private static let canonicalToolPathDirectories: [String] = [
        "/opt/homebrew/bin", "/opt/homebrew/sbin",
        "/usr/local/bin", "/usr/local/sbin",
        "/usr/bin", "/bin", "/usr/sbin", "/sbin",
    ]

    nonisolated static func childEnvironment(
        binaryDirectories: [URL],
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env: [String: String] = [:]
        for (key, value) in base where subprocessEnvironmentAllowlist.contains(key) {
            let safeValue: String?
            switch key {
            case "HOME", "TMPDIR":
                safeValue = safePathEntry(value)
            default:
                safeValue = safeEnvironmentValue(value)
            }
            guard let safeValue else { continue }
            env[key] = safeValue
        }
        let pathEntries = binaryDirectories.map(\.path)
            + inheritedPathComponents(base["PATH"])
            + canonicalToolPathDirectories
            + userToolPathDirectories(home: base["HOME"])
        env["PATH"] = boundedPath(from: pathEntries)
        return env
    }

    nonisolated static func userToolPathDirectories(home: String?) -> [String] {
        guard let home = safePathEntry(home) else { return [] }
        return ["\(home)/.local/bin", "\(home)/bin"]
    }

    nonisolated static func withUserToolPath(_ env: [String: String]) -> [String: String] {
        var out = env
        let home = env["HOME"] ?? ProcessInfo.processInfo.environment["HOME"]
        let userDirs = userToolPathDirectories(home: home)
        guard !userDirs.isEmpty else { return out }
        out["PATH"] = boundedPath(from: userDirs + inheritedPathComponents(out["PATH"]))
        return out
    }

    nonisolated private static func safeEnvironmentValue(_ value: String?) -> String? {
        guard let value,
              value.utf8.count <= maxSubprocessEnvironmentValueCharacters,
              !value.utf8.contains(0) else {
            return nil
        }
        return value
    }

    nonisolated private static func inheritedPathComponents(_ path: String?) -> [String] {
        guard let path = safeEnvironmentValue(path) else { return [] }
        return path
            .split(separator: ":", omittingEmptySubsequences: true)
            .prefix(maxSubprocessPathEntries)
            .compactMap { safePathEntry(String($0)) }
    }

    nonisolated private static func safePathEntry(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.hasPrefix("/"),
              trimmed.utf8.count <= maxSubprocessPathEntryCharacters,
              !trimmed.utf8.contains(0) else {
            return nil
        }
        return trimmed
    }

    nonisolated private static func boundedPath(from candidates: [String]) -> String {
        var entries: [String] = []
        var seen: Set<String> = []
        var length = 0
        for candidate in candidates {
            guard entries.count < maxSubprocessPathEntries else { break }
            guard let entry = safePathEntry(candidate),
                  seen.insert(entry).inserted else { continue }
            let projectedLength = length + entry.utf8.count + (entries.isEmpty ? 0 : 1)
            guard projectedLength <= maxSubprocessPathCharacters else { break }
            entries.append(entry)
            length = projectedLength
        }
        return entries.joined(separator: ":")
    }
}
#endif
