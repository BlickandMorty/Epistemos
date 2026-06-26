import Foundation

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
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDir), isDir.boolValue else { return 0 }
        let dest = skillsDestination(workspace: workspace)
        try? fileManager.createDirectory(at: dest, withIntermediateDirectories: true)
        guard let entries = try? fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return 0 }
        var copied = 0
        for entry in entries {
            guard isSkillDirectory(entry, fileManager: fileManager) else { continue }
            let target = dest.appendingPathComponent(entry.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) { continue } // don't clobber existing/user skills
            if (try? fileManager.copyItem(at: entry, to: target)) != nil { copied += 1 }
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
        return fileManager.fileExists(atPath: url.appendingPathComponent("SKILL.md").path)
    }

    private nonisolated static func directoryExists(_ url: URL, fileManager: FileManager) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
