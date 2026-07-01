import Foundation
import Testing
@testable import Epistemos

@Suite("Work skills provisioner — populate .opencode/skills from vault/bundled sources")
struct WorkSkillsProvisionerTests {
    private func tmp() -> URL {
        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("work-skills-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    private func makeSkill(_ root: URL, _ name: String, body: String? = nil) {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? (body ?? "# \(name)").write(
            to: dir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8)
    }

    @Test("skillsDestination is <workspace>/.opencode/skills")
    func destination() {
        let ws = URL(fileURLWithPath: "/w")
        #expect(WorkSkillsProvisioner.skillsDestination(workspace: ws).path == "/w/.opencode/skills")
    }

    @Test("provisionSkills copies new skills, is idempotent, and never clobbers existing ones")
    func copyIdempotentNonClobber() throws {
        let ws = tmp(); defer { try? FileManager.default.removeItem(at: ws) }
        let src = tmp(); defer { try? FileManager.default.removeItem(at: src) }
        makeSkill(src, "alpha"); makeSkill(src, "beta")
        // first run copies both
        #expect(WorkSkillsProvisioner.provisionSkills(from: src, into: ws) == 2)
        let dest = WorkSkillsProvisioner.skillsDestination(workspace: ws)
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("alpha/SKILL.md").path))
        // second run is idempotent (nothing new)
        #expect(WorkSkillsProvisioner.provisionSkills(from: src, into: ws) == 0)
        // a pre-existing dest skill is NOT clobbered (only the new one copies)
        makeSkill(src, "gamma")
        #expect(WorkSkillsProvisioner.provisionSkills(from: src, into: ws) == 1)
    }

    @Test("provisionSkills only copies valid skill directories with SKILL.md")
    func copiesOnlyValidSkillDirectories() throws {
        let ws = tmp(); defer { try? FileManager.default.removeItem(at: ws) }
        let src = tmp(); defer { try? FileManager.default.removeItem(at: src) }
        makeSkill(src, "real-skill")
        try "not a skill".write(
            to: src.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8)
        try FileManager.default.createDirectory(
            at: src.appendingPathComponent("folder-without-skill-md", isDirectory: true),
            withIntermediateDirectories: true)

        #expect(WorkSkillsProvisioner.provisionSkills(from: src, into: ws) == 1)
        let dest = WorkSkillsProvisioner.skillsDestination(workspace: ws)
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("real-skill/SKILL.md").path))
        #expect(!FileManager.default.fileExists(atPath: dest.appendingPathComponent("README.md").path))
        #expect(!FileManager.default.fileExists(atPath: dest.appendingPathComponent("folder-without-skill-md").path))
        #expect(WorkSkillsProvisioner.isSkillDirectory(src.appendingPathComponent("real-skill")))
        #expect(!WorkSkillsProvisioner.isSkillDirectory(src.appendingPathComponent("folder-without-skill-md")))
        #expect(!WorkSkillsProvisioner.isSkillDirectory(src.appendingPathComponent("README.md")))
    }

    @Test("provisionSkills skips linked skill directories and linked skill files")
    func skipsLinkedSkillDirectoriesAndFiles() throws {
        let ws = tmp(); defer { try? FileManager.default.removeItem(at: ws) }
        let src = tmp(); defer { try? FileManager.default.removeItem(at: src) }
        let outside = tmp(); defer { try? FileManager.default.removeItem(at: outside) }
        let fm = FileManager.default

        makeSkill(src, "safe")
        makeSkill(outside, "outside-skill")
        try fm.createSymbolicLink(
            at: src.appendingPathComponent("linked-dir", isDirectory: true),
            withDestinationURL: outside.appendingPathComponent("outside-skill", isDirectory: true)
        )

        let hardlinkedSkill = src.appendingPathComponent("hardlinked-skill", isDirectory: true)
        try fm.createDirectory(at: hardlinkedSkill, withIntermediateDirectories: true)
        try fm.linkItem(
            at: outside.appendingPathComponent("outside-skill/SKILL.md", isDirectory: false),
            to: hardlinkedSkill.appendingPathComponent("SKILL.md", isDirectory: false)
        )

        makeSkill(src, "nested-link")
        let secret = outside.appendingPathComponent("secret.md", isDirectory: false)
        try "secret".write(to: secret, atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(
            at: src.appendingPathComponent("nested-link/secret.md", isDirectory: false),
            withDestinationURL: secret
        )

        #expect(WorkSkillsProvisioner.provisionSkills(from: src, into: ws) == 1)
        let dest = WorkSkillsProvisioner.skillsDestination(workspace: ws)
        #expect(fm.fileExists(atPath: dest.appendingPathComponent("safe/SKILL.md").path))
        #expect(!fm.fileExists(atPath: dest.appendingPathComponent("linked-dir").path))
        #expect(!fm.fileExists(atPath: dest.appendingPathComponent("hardlinked-skill").path))
        #expect(!fm.fileExists(atPath: dest.appendingPathComponent("nested-link").path))
        #expect(!WorkSkillsProvisioner.isSkillDirectory(src.appendingPathComponent("linked-dir")))
        #expect(!WorkSkillsProvisioner.isSkillDirectory(hardlinkedSkill))
    }

    @Test("provisionSkills refuses symlinked destination directories")
    func refusesSymlinkedDestinationDirectories() throws {
        let ws = tmp(); defer { try? FileManager.default.removeItem(at: ws) }
        let src = tmp(); defer { try? FileManager.default.removeItem(at: src) }
        let outside = tmp(); defer { try? FileManager.default.removeItem(at: outside) }
        let fm = FileManager.default

        makeSkill(src, "safe")
        try fm.createDirectory(at: ws.appendingPathComponent(".opencode", isDirectory: true), withIntermediateDirectories: true)
        try fm.createSymbolicLink(
            at: WorkSkillsProvisioner.skillsDestination(workspace: ws),
            withDestinationURL: outside
        )

        #expect(WorkSkillsProvisioner.provisionSkills(from: src, into: ws) == 0)
        #expect(!fm.fileExists(atPath: outside.appendingPathComponent("safe/SKILL.md").path))
    }

    @Test("missing source is an honest no-op")
    func missingSource() {
        let ws = tmp(); defer { try? FileManager.default.removeItem(at: ws) }
        #expect(WorkSkillsProvisioner.provisionSkills(from: ws.appendingPathComponent("nope"), into: ws) == 0)
        // provisionVaultSkills on a workspace with no skills/ dir → 0
        #expect(WorkSkillsProvisioner.provisionVaultSkills(workspace: ws) == 0)
    }

    @Test("provisionVaultSkills exposes <workspace>/skills as .opencode/skills")
    func vaultConvention() {
        let ws = tmp(); defer { try? FileManager.default.removeItem(at: ws) }
        makeSkill(ws.appendingPathComponent("skills", isDirectory: true), "my-epistemos-skill")
        #expect(WorkSkillsProvisioner.provisionVaultSkills(workspace: ws) == 1)
        let dest = WorkSkillsProvisioner.skillsDestination(workspace: ws)
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("my-epistemos-skill/SKILL.md").path))
    }

    @Test("primary OpenGUI workspace can receive skills from the active Epistemos app vault")
    func activeAppVaultSkillsCopyIntoManagedWorkspace() {
        let ws = tmp(); defer { try? FileManager.default.removeItem(at: ws) }
        let vault = tmp(); defer { try? FileManager.default.removeItem(at: vault) }
        makeSkill(vault.appendingPathComponent("skills", isDirectory: true), "vault-skill")

        #expect(WorkSkillsProvisioner.provisionAppVaultSkills(vaultRoot: vault, into: ws) == 1)
        let dest = WorkSkillsProvisioner.skillsDestination(workspace: ws)
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("vault-skill/SKILL.md").path))
        #expect(WorkSkillsProvisioner.provisionAppVaultSkills(vaultRoot: vault, into: ws) == 0)
    }

    @Test("provisionAll prioritizes workspace skills over app-vault skills with the same name")
    func provisionAllPrefersWorkspaceSkillNames() throws {
        let ws = tmp(); defer { try? FileManager.default.removeItem(at: ws) }
        let vault = tmp(); defer { try? FileManager.default.removeItem(at: vault) }
        makeSkill(
            ws.appendingPathComponent("skills", isDirectory: true),
            "shared",
            body: "# workspace shared")
        makeSkill(
            vault.appendingPathComponent("skills", isDirectory: true),
            "shared",
            body: "# vault shared")
        makeSkill(vault.appendingPathComponent("skills", isDirectory: true), "vault-only")

        _ = WorkSkillsProvisioner.provisionAll(workspace: ws, vaultRoot: vault)
        let dest = WorkSkillsProvisioner.skillsDestination(workspace: ws)
        let shared = try String(
            contentsOf: dest.appendingPathComponent("shared/SKILL.md"),
            encoding: .utf8)
        #expect(shared == "# workspace shared")
        #expect(FileManager.default.fileExists(atPath: dest.appendingPathComponent("vault-only/SKILL.md").path))
    }

    @Test("primary native Work startup provisions skills before starting the OpenGUI runtime")
    func primaryNativeStartupProvisionsSkills() throws {
        let surface = try loadMirroredSourceTextFile("Epistemos/Work/WorkEngineSurfaceView.swift")
        #expect(surface.contains("WorkSkillsProvisioner.provisionAll("))
        #expect(surface.contains("vaultRoot: epistemosVaultRoot"))
        #expect(surface.contains("var context = refreshAppContext(nativeToolsAvailable: false)"))
        #expect(surface.contains("context: context"))
        #expect(surface.contains("WorkNativeMCPHost.shared.updateContext(snapshot)"))
        #expect(surface.contains("selectedEngine: selectedEngine"))
        #expect(surface.contains("queuedPromptCount: queue.count"))
        let provisioner = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenGUIProvisioner.swift")
        #expect(provisioner.contains("createDirectory(at: workspace, withIntermediateDirectories: true)"))
        let provisionCall = try #require(surface.range(of: "WorkSkillsProvisioner.provisionAll")?.lowerBound)
        let contextCall = try #require(surface.range(of: "refreshAppContext(nativeToolsAvailable: false)")?.lowerBound)
        let nativeMCPCall = try #require(surface.range(of: "WorkOpenGUIProvisioner.provisionNativeMCP")?.lowerBound)
        let runtimeStart = try #require(
            surface.range(of: "supervisor.start(repo: repo, harnesses: [\"opencode\"])")?.lowerBound)
        #expect(provisionCall < runtimeStart)
        #expect(provisionCall < contextCall)
        #expect(contextCall < nativeMCPCall)
        #expect(nativeMCPCall < runtimeStart)
    }
}
