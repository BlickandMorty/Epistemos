#if EPISTEMOS_BASE_JUNE
import Darwin
import Foundation

nonisolated enum JuneSkillDocumentReader {
    private static let maxSkillFileBytes = 1024 * 1024

    static func readSkillMarkdown(vaultPath: String, skillName: String) -> String? {
        let vaultURL = URL(fileURLWithPath: vaultPath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let manifestURL = vaultURL
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent(skillName, isDirectory: true)
            .appendingPathComponent("SKILL.md", isDirectory: false)
            .standardizedFileURL
        let resolvedParent = manifestURL.deletingLastPathComponent().resolvingSymlinksInPath()
        let vaultPrefix = vaultURL.path.hasSuffix("/") ? vaultURL.path : vaultURL.path + "/"
        guard resolvedParent.path.hasPrefix(vaultPrefix) else { return nil }

        let descriptor = manifestURL.path.withCString {
            open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard descriptor >= 0 else { return nil }
        defer { _ = close(descriptor) }

        var status = stat()
        guard fstat(descriptor, &status) == 0,
              (status.st_mode & S_IFMT) == S_IFREG,
              status.st_nlink == 1,
              status.st_size >= 0,
              UInt64(status.st_size) <= UInt64(maxSkillFileBytes) else {
            return nil
        }

        var data = Data()
        data.reserveCapacity(Int(status.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes {
                read(descriptor, $0.baseAddress, $0.count)
            }
            guard count >= 0 else { return nil }
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
            guard data.count <= maxSkillFileBytes else { return nil }
        }
        return String(data: data, encoding: .utf8)
    }
}
#endif
