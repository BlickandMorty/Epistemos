import Darwin
import Foundation

nonisolated enum SkillVaultFileIO {
    static let maxSkillFileBytes = 1024 * 1024
    private static let maxPathComponentCharacters = 128

    static func topLevelSkillDirectories(vaultPath: String, fileManager: FileManager = .default) -> [URL] {
        let vaultURL = URL(fileURLWithPath: vaultPath, isDirectory: true)
        let skillsRoot = vaultURL.appendingPathComponent("skills", isDirectory: true)
        guard Plan3VaultPath.resolvesInsideVault(skillsRoot, in: vaultURL),
              directoryExists(skillsRoot),
              let entries = try? fileManager.contentsOfDirectory(
                at: skillsRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return entries.filter { entry in
            guard isSafePathComponent(entry.lastPathComponent),
                  directoryExists(entry),
                  let manifestURL = skillManifestURL(vaultPath: vaultPath, skillName: entry.lastPathComponent) else {
                return false
            }
            return regularSingleLinkFileExists(manifestURL)
        }
    }

    static func readSkillMarkdown(vaultPath: String, skillName: String) -> String? {
        guard let manifestURL = skillManifestURL(vaultPath: vaultPath, skillName: skillName) else {
            return nil
        }
        return readRegularSingleLinkTextFile(manifestURL)
    }

    static func ensureSkillDirectory(vaultPath: String, skillName: String) throws -> URL {
        guard let skillDirectory = skillDirectory(vaultPath: vaultPath, skillName: skillName) else {
            throw SkillVaultFileIOError.invalidPath
        }
        let skillsRoot = skillDirectory.deletingLastPathComponent()
        try ensureDirectoryExists(skillsRoot)
        try ensureDirectoryExists(skillDirectory)
        return skillDirectory
    }

    static func ensureVersionsDirectory(skillDirectory: URL) throws -> URL {
        let versionsDirectory = skillDirectory.appendingPathComponent("versions", isDirectory: true)
        try ensureDirectoryExists(versionsDirectory)
        return versionsDirectory
    }

    static func versionFileURL(in versionsDirectory: URL, version: String, pathExtension: String) -> URL? {
        guard isSafePathComponent(version),
              isSafePathComponent(pathExtension) else {
            return nil
        }
        return versionsDirectory.appendingPathComponent("\(version).\(pathExtension)", isDirectory: false)
    }

    static func diffFileURL(in versionsDirectory: URL, oldVersion: String, newVersion: String) -> URL? {
        guard isSafePathComponent(oldVersion),
              isSafePathComponent(newVersion) else {
            return nil
        }
        return versionsDirectory.appendingPathComponent("\(oldVersion)-\(newVersion).diff", isDirectory: false)
    }

    static func writeText(_ text: String, to url: URL) throws {
        try writeData(Data(text.utf8), to: url)
    }

    private static func skillManifestURL(vaultPath: String, skillName: String) -> URL? {
        skillDirectory(vaultPath: vaultPath, skillName: skillName)?
            .appendingPathComponent("SKILL.md", isDirectory: false)
    }

    private static func skillDirectory(vaultPath: String, skillName: String) -> URL? {
        guard isSafePathComponent(skillName) else { return nil }
        let vaultURL = URL(fileURLWithPath: vaultPath, isDirectory: true)
        let skillDirectory = vaultURL
            .appendingPathComponent("skills", isDirectory: true)
            .appendingPathComponent(skillName, isDirectory: true)
        guard Plan3VaultPath.resolvesInsideVault(skillDirectory, in: vaultURL) else {
            return nil
        }
        return skillDirectory
    }

    private static func isSafePathComponent(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.count <= maxPathComponentCharacters,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines),
              value != ".",
              value != "..",
              !value.hasPrefix(".") else {
            return false
        }
        return value.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x2F, 0x5C, 0x3A:
                return false
            default:
                return !CharacterSet.controlCharacters.contains(scalar)
            }
        }
    }

    private static func readRegularSingleLinkTextFile(_ url: URL) -> String? {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else { return nil }
        defer { _ = close(fd) }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0,
              (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_nlink == 1,
              fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxSkillFileBytes) else {
            return nil
        }

        var data = Data()
        data.reserveCapacity(Int(fileStatus.st_size))
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let readCount = buffer.withUnsafeMutableBytes { rawBuffer in
                read(fd, rawBuffer.baseAddress, rawBuffer.count)
            }
            guard readCount >= 0 else { return nil }
            guard readCount > 0 else { break }
            data.append(contentsOf: buffer.prefix(readCount))
            guard data.count <= maxSkillFileBytes else { return nil }
        }
        return String(data: data, encoding: .utf8)
    }

    private static func writeData(_ data: Data, to url: URL) throws {
        guard data.count <= maxSkillFileBytes,
              directoryExists(url.deletingLastPathComponent()) else {
            throw SkillVaultFileIOError.invalidPath
        }
        if let status = fileStatus(url) {
            guard (status.st_mode & S_IFMT) == S_IFREG,
                  status.st_nlink == 1 else {
                throw SkillVaultFileIOError.invalidPath
            }
        }

        let tempURL = url
            .deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp", isDirectory: false)
        var didRename = false
        defer {
            if !didRename {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }

        let fd = tempURL.path.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        }
        guard fd >= 0 else { throw SkillVaultFileIOError.invalidPath }
        defer { _ = close(fd) }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let written = write(fd, baseAddress.advanced(by: offset), rawBuffer.count - offset)
                guard written > 0 else { throw SkillVaultFileIOError.invalidPath }
                offset += written
            }
        }
        guard rename(tempURL.path, url.path) == 0 else {
            throw SkillVaultFileIOError.invalidPath
        }
        didRename = true
    }

    private static func ensureDirectoryExists(_ url: URL) throws {
        if fileStatus(url) == nil {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
        guard directoryExists(url) else {
            throw SkillVaultFileIOError.invalidPath
        }
    }

    private static func directoryExists(_ url: URL) -> Bool {
        guard let status = fileStatus(url) else { return false }
        return (status.st_mode & S_IFMT) == S_IFDIR
    }

    private static func regularSingleLinkFileExists(_ url: URL) -> Bool {
        guard let status = fileStatus(url) else { return false }
        return (status.st_mode & S_IFMT) == S_IFREG && status.st_nlink == 1
    }

    private static func fileStatus(_ url: URL) -> stat? {
        var fileStatus = stat()
        let result = url.path.withCString { path in
            lstat(path, &fileStatus)
        }
        return result == 0 ? fileStatus : nil
    }
}

nonisolated enum SkillVaultFileIOError: Error {
    case invalidPath
}
