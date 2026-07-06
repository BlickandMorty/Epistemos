import Darwin
import Foundation

struct WorkProvisionedSkill: Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let description: String
}

// W-R4 skills provisioning (audit wm2xomprr): OpenCode/OpenWork discover skills from `<workspace>/.opencode/skills/`
// (+ .claude/skills + global ~/.config/opencode/skills etc.). Our embed provisions NONE → the Skills panel is empty
// by construction. This copies skills INTO `<workspace>/.opencode/skills/` so they work out-of-the-box, with no
// manual setup. COPY (not symlink): OpenWork's fs.watch on `.opencode` reloads, and symlinked dirs confuse it.
//
// Two honest sources, both no-ops when absent:
//  • the workspace's own `skills/` (the EPISTEMOS vault convention `<vault>/skills/<name>/SKILL.md`) → exposed as
//    `.opencode/skills/` so the user's real Epistemos skills appear when Work is rooted at the vault.
//  • a bundled default set at `Resources/openwork-skills/` (once staged) → baseline skills on any workspace.
// Idempotent: never clobbers a skill already present in the destination (so user/manual skills survive).
enum WorkSkillsProvisioner {
    private static let maxSkillManifestBytes = 256 * 1024

    /// The dir OpenCode reads project skills from.
    nonisolated static func skillsDestination(workspace: URL) -> URL {
        workspace.appendingPathComponent(".opencode/skills", isDirectory: true)
    }

    /// The bundled default skills source (`Resources/openwork-skills`), if staged; nil → nothing to provision.
    nonisolated static func bundledSkillsSource(bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "openwork-skills", withExtension: nil)
    }

    /// Copy each top-level skill directory from `source` into `<workspace>/.opencode/skills/`, skipping any already
    /// present (idempotent, non-clobbering). A valid skill must be a directory containing `SKILL.md`; other source
    /// entries are ignored so random vault files do not become OpenCode skills. Best-effort: per-skill failures are
    /// skipped, never thrown. Returns the count newly copied. No-op (returns 0) if `source` doesn't exist.
    @discardableResult
    nonisolated static func provisionSkills(from source: URL, into workspace: URL,
                                            fileManager: FileManager = .default) -> Int {
        guard directoryExists(source, fileManager: fileManager),
              let dest = ensureSkillsDestination(workspace: workspace, fileManager: fileManager) else {
            return 0
        }
        guard let entries = try? fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return 0 }
        var copied = 0
        for entry in entries {
            guard isSkillDirectory(entry, fileManager: fileManager) else { continue }
            let target = dest.appendingPathComponent(entry.lastPathComponent)
            if fileStatus(target, followSymlinks: false) != nil { continue } // don't clobber existing/user skills
            let stagedTarget = dest.appendingPathComponent(".\(entry.lastPathComponent).\(UUID().uuidString).tmp")
            do {
                try copySkillDirectory(from: entry, to: stagedTarget, fileManager: fileManager)
                try fileManager.moveItem(at: stagedTarget, to: target)
                copied += 1
            } catch {
                try? fileManager.removeItem(at: stagedTarget)
            }
        }
        return copied
    }

    /// Expose the workspace's own `skills/` (Epistemos vault convention) as `.opencode/skills/`. No-op if the
    /// workspace has no `skills/` (e.g. a scratch workspace). Returns the count newly copied.
    @discardableResult
    nonisolated static func provisionVaultSkills(workspace: URL, fileManager: FileManager = .default) -> Int {
        provisionSkills(from: workspace.appendingPathComponent("skills", isDirectory: true),
                        into: workspace, fileManager: fileManager)
    }

    /// Expose the active Epistemos app vault's `skills/` in the Work runtime workspace. This covers the primary
    /// OpenGUI path where `workspace` is a managed scratch dir but the user's real skills live in the app vault.
    @discardableResult
    nonisolated static func provisionAppVaultSkills(
        vaultRoot: URL?, into workspace: URL, fileManager: FileManager = .default
    ) -> Int {
        guard let vaultRoot else { return 0 }
        let workspacePath = workspace.standardizedFileURL.path
        let vaultPath = vaultRoot.standardizedFileURL.path
        guard workspacePath != vaultPath else { return 0 }
        return provisionSkills(
            from: vaultRoot.appendingPathComponent("skills", isDirectory: true),
            into: workspace,
            fileManager: fileManager)
    }

    /// Provision the workspace's own `skills/`, optionally the active app vault's `skills/`, and bundled defaults.
    /// User/workspace sources run first and all copies are non-clobbering, so bundled skills only fill missing names.
    @discardableResult
    nonisolated static func provisionAll(workspace: URL, vaultRoot: URL? = nil, bundle: Bundle = .main,
                                         fileManager: FileManager = .default) -> Int {
        var copied = 0
        copied += provisionVaultSkills(workspace: workspace, fileManager: fileManager)
        copied += provisionAppVaultSkills(vaultRoot: vaultRoot, into: workspace, fileManager: fileManager)
        if let source = bundledSkillsSource(bundle: bundle) {
            copied += provisionSkills(from: source, into: workspace, fileManager: fileManager)
        }
        return copied
    }

    nonisolated static func isSkillDirectory(_ url: URL, fileManager: FileManager = .default) -> Bool {
        guard directoryExists(url, fileManager: fileManager) else { return false }
        return regularSingleLinkFileExists(url.appendingPathComponent("SKILL.md", isDirectory: false))
    }

    nonisolated static func provisionedSkills(
        workspace: URL,
        fileManager: FileManager = .default
    ) -> [WorkProvisionedSkill] {
        let root = skillsDestination(workspace: workspace)
        guard directoryExists(root, fileManager: fileManager),
              let entries = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return entries.compactMap { entry -> WorkProvisionedSkill? in
            guard isSkillDirectory(entry, fileManager: fileManager) else { return nil }
            guard let content = safeSkillManifestContent(
                entry.appendingPathComponent("SKILL.md", isDirectory: false)
            ) else {
                return nil
            }
            let frontmatter = parseFrontmatter(content)
            let identifier = entry.lastPathComponent
            return WorkProvisionedSkill(
                id: identifier,
                title: cleanDisplayText(frontmatter["name"]) ?? humanizedIdentifier(identifier),
                description: cleanDisplayText(frontmatter["description"])
                    ?? firstMeaningfulMarkdownLine(in: content)
                    ?? "No description provided."
            )
        }
        .sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private nonisolated static func directoryExists(_ url: URL, fileManager: FileManager) -> Bool {
        guard let status = fileStatus(url, followSymlinks: false) else { return false }
        return (status.st_mode & S_IFMT) == S_IFDIR
    }

    private nonisolated static func ensureSkillsDestination(
        workspace: URL,
        fileManager: FileManager
    ) -> URL? {
        guard directoryExists(workspace, fileManager: fileManager) else { return nil }
        let opencode = workspace.appendingPathComponent(".opencode", isDirectory: true)
        guard ensureDirectoryExists(opencode, fileManager: fileManager) else { return nil }
        let destination = skillsDestination(workspace: workspace)
        guard ensureDirectoryExists(destination, fileManager: fileManager) else { return nil }
        return destination
    }

    private nonisolated static func ensureDirectoryExists(_ url: URL, fileManager: FileManager) -> Bool {
        if fileStatus(url, followSymlinks: false) == nil {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
            } catch {
                return false
            }
        }
        return directoryExists(url, fileManager: fileManager)
    }

    private nonisolated static func regularSingleLinkFileExists(_ url: URL) -> Bool {
        guard let status = fileStatus(url, followSymlinks: false) else { return false }
        return (status.st_mode & S_IFMT) == S_IFREG && status.st_nlink == 1
    }

    private nonisolated static func safeSkillManifestContent(_ url: URL) -> String? {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else { return nil }

        var status = stat()
        guard fstat(fd, &status) == 0,
              (status.st_mode & S_IFMT) == S_IFREG,
              status.st_nlink == 1,
              status.st_size >= 0,
              status.st_size <= maxSkillManifestBytes else {
            close(fd)
            return nil
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              data.count <= maxSkillManifestBytes else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private nonisolated static func parseFrontmatter(_ content: String) -> [String: String] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else { return [:] }

        var values: [String: String] = [:]
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" { break }
            let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "name" || key == "description" {
                values[key] = value
            }
        }
        return values
    }

    private nonisolated static func firstMeaningfulMarkdownLine(in content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var startIndex = lines.startIndex
        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
            startIndex = lines.index(after: lines.startIndex)
            while startIndex < lines.endIndex {
                let trimmed = lines[startIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                startIndex = lines.index(after: startIndex)
                if trimmed == "---" { break }
            }
        }

        for line in lines[startIndex...] {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("#"),
                  !trimmed.hasPrefix("---") else {
                continue
            }
            return cleanDisplayText(trimmed)
        }
        return nil
    }

    private nonisolated static func cleanDisplayText(_ rawValue: String?) -> String? {
        let bounded = String((rawValue ?? "").prefix(180))
        var normalized = ""
        normalized.reserveCapacity(bounded.count)
        var previousWasSpace = false
        for scalar in bounded.unicodeScalars where !CharacterSet.controlCharacters.contains(scalar) {
            let isWhitespace = CharacterSet.whitespacesAndNewlines.contains(scalar)
            if isWhitespace {
                if !previousWasSpace {
                    normalized.append(" ")
                    previousWasSpace = true
                }
            } else {
                normalized.unicodeScalars.append(scalar)
                previousWasSpace = false
            }
        }
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func humanizedIdentifier(_ identifier: String) -> String {
        let words = identifier
            .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "." })
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
        let title = words.joined(separator: " ")
        return title.isEmpty ? identifier : title
    }

    private nonisolated static func copySkillDirectory(
        from source: URL,
        to destination: URL,
        fileManager: FileManager
    ) throws {
        guard directoryExists(source, fileManager: fileManager) else { throw CocoaError(.fileReadUnknown) }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)
        guard let enumerator = fileManager.enumerator(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants]
        ) else {
            throw CocoaError(.fileReadUnknown)
        }

        for case let sourceItem as URL in enumerator {
            let relativePath = try relativeChildPath(sourceItem, under: source)
            let destinationItem = destination.appendingPathComponent(relativePath, isDirectory: false)
            guard let status = fileStatus(sourceItem, followSymlinks: false) else {
                throw CocoaError(.fileReadUnknown)
            }
            switch status.st_mode & S_IFMT {
            case S_IFDIR:
                try fileManager.createDirectory(at: destinationItem, withIntermediateDirectories: false)
            case S_IFREG where status.st_nlink == 1:
                try copyRegularFile(from: sourceItem, to: destinationItem, sourceMode: status.st_mode)
            default:
                throw CocoaError(.fileReadUnknown)
            }
        }
    }

    private nonisolated static func relativeChildPath(_ child: URL, under root: URL) throws -> String {
        let rootPath = root.standardizedFileURL.path
        let childPath = child.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        guard childPath.hasPrefix(prefix) else { throw CocoaError(.fileReadUnknown) }
        let relativePath = String(childPath.dropFirst(prefix.count))
        guard !relativePath.isEmpty,
              !relativePath.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw CocoaError(.fileReadUnknown)
        }
        return relativePath
    }

    private nonisolated static func copyRegularFile(from source: URL, to destination: URL, sourceMode: mode_t) throws {
        let sourceFD = source.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard sourceFD >= 0 else { throw CocoaError(.fileReadUnknown) }
        defer { _ = close(sourceFD) }

        var sourceStatus = stat()
        guard fstat(sourceFD, &sourceStatus) == 0,
              (sourceStatus.st_mode & S_IFMT) == S_IFREG,
              sourceStatus.st_nlink == 1 else {
            throw CocoaError(.fileReadUnknown)
        }

        let permissions = sourceMode & 0o777
        let destinationFD = destination.path.withCString { path in
            open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, permissions)
        }
        guard destinationFD >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { _ = close(destinationFD) }

        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let readCount = buffer.withUnsafeMutableBytes { rawBuffer in
                read(sourceFD, rawBuffer.baseAddress, rawBuffer.count)
            }
            guard readCount >= 0 else { throw CocoaError(.fileReadUnknown) }
            guard readCount > 0 else { break }

            var offset = 0
            while offset < readCount {
                let written = buffer.withUnsafeBytes { rawBuffer in
                    write(
                        destinationFD,
                        rawBuffer.baseAddress?.advanced(by: offset),
                        readCount - offset
                    )
                }
                guard written > 0 else { throw CocoaError(.fileWriteUnknown) }
                offset += written
            }
        }
        _ = fchmod(destinationFD, permissions)
    }

    private nonisolated static func fileStatus(_ url: URL, followSymlinks: Bool) -> stat? {
        var status = stat()
        let result = url.path.withCString { path in
            followSymlinks ? stat(path, &status) : lstat(path, &status)
        }
        return result == 0 ? status : nil
    }
}
