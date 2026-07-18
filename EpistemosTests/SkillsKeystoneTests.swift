import Testing
import Foundation
@testable import Epistemos

/// SS-H keystone (owner's #2 priority): local chat must SEE the skills catalog even
/// when it can't drive the tool loop, and a non-agent model's tool-needing queries
/// must route to a fitting agent-capable model instead of silently degrading to a
/// tool-less / skill-less stream.
@Suite("Skills keystone (SS-H)")
struct SkillsKeystoneTests {

    @Test("the direct (tool-loop-less) stream injects the ChatLite skills catalog")
    func directStreamInjectsCatalog() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
        // A skills-catalog block is built + appended to the direct-stream systemParts.
        #expect(src.contains("chatLiteSkillsCatalogBlock(operatingMode: operatingMode)"))
        #expect(src.contains("Skills available to Epistemos"))
    }

    @Test("a non-agent model routes tool-needing queries to a fitting agent model, not toolless")
    func nonAgentRoutesToFittingAgentModel() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")
        // PART 2: the no-execution-plan non-agent branch checks for a fitting agent
        // model + tool-need before degrading. fittingLocalAgentTextModelID only
        // returns a model that fits memory (no OOM swap).
        #expect(src.contains("if Self.autoToolRouteArmed, inference.fittingLocalAgentTextModelID != nil"))
        #expect(src.contains("Self.autoRouteNeedsTools(query: query, tools: candidateTools) == true"))
    }

    @Test("skills settings status bounds and redacts external failures")
    func skillsSettingsStatusBoundsAndRedactsExternalFailures() {
        let privatePath = "/private/var/folders/skills/install.json"
        let error = NSError(
            domain: privatePath,
            code: 17,
            userInfo: [NSLocalizedDescriptionKey: "failed to open \(privatePath)"]
        )
        let message = SkillsSettingsStatus.message(for: error, fallback: "Could not install skill.")
        let oversized = String(
            repeating: "s",
            count: SkillsSettingsStatus.maxStatusMessageCharacters + 40
        )

        #expect(message.contains("Could not install skill."))
        #expect(message.contains("domain=Error"))
        #expect(message.contains("code=17"))
        #expect(message.count <= SkillsSettingsStatus.maxStatusMessageCharacters)
        #expect(!message.contains(privatePath))
        #expect(!message.contains("failed to open"))
        #expect(
            SkillsSettingsStatus.message(oversized, fallback: "Skill install failed.")
                .count == SkillsSettingsStatus.maxStatusMessageCharacters
        )
        #expect(
            SkillsSettingsStatus.message("Installed\nskill\tname\u{0007}", fallback: "Skill installed.")
                == "Installed skill name"
        )
    }

    @Test("skill discovery reads only single-link regular SKILL.md files")
    func skillDiscoveryReadsOnlySingleLinkRegularSkillFiles() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("skill-discovery-safe-read-\(UUID().uuidString)")
        let skillsRoot = root.appendingPathComponent("skills", isDirectory: true)
        let validSkill = skillsRoot.appendingPathComponent("valid", isDirectory: true)
        let symlinkSkill = skillsRoot.appendingPathComponent("symlinked", isDirectory: true)
        let hardlinkSkill = skillsRoot.appendingPathComponent("hardlinked", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        for directory in [validSkill, symlinkSkill, hardlinkSkill, outside] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try Self.writeSkill(
            name: "Valid Skill",
            to: validSkill.appendingPathComponent("SKILL.md", isDirectory: false)
        )
        let outsideSkill = outside.appendingPathComponent("SKILL.md", isDirectory: false)
        try Self.writeSkill(name: "Outside Skill", to: outsideSkill)
        try fm.createSymbolicLink(
            at: symlinkSkill.appendingPathComponent("SKILL.md", isDirectory: false),
            withDestinationURL: outsideSkill
        )
        do {
            try fm.linkItem(
                at: outsideSkill,
                to: hardlinkSkill.appendingPathComponent("SKILL.md", isDirectory: false)
            )
        } catch {
            return
        }

        let entries = SkillDiscoveryCatalog.discoverSkillEntries(
            inRoots: [SkillDiscoveryRoot(url: skillsRoot, source: .codex)],
            forceRefresh: true
        )

        #expect(entries.map(\.identifier) == ["valid-skill"])
    }

    @Test("skill registry reads only safe top-level vault skill manifests")
    func skillRegistryReadsOnlySafeTopLevelVaultSkillManifests() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("skill-registry-safe-read-\(UUID().uuidString)")
        let skillsRoot = root.appendingPathComponent("skills", isDirectory: true)
        let validSkill = skillsRoot.appendingPathComponent("valid", isDirectory: true)
        let symlinkSkill = skillsRoot.appendingPathComponent("symlinked", isDirectory: true)
        let hardlinkSkill = skillsRoot.appendingPathComponent("hardlinked", isDirectory: true)
        let nestedSkill = skillsRoot
            .appendingPathComponent("parent", isDirectory: true)
            .appendingPathComponent("nested", isDirectory: true)
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        let outsideSkillDirectory = outside.appendingPathComponent("outside-skill", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        for directory in [validSkill, symlinkSkill, hardlinkSkill, nestedSkill, outsideSkillDirectory] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try Self.writeSkill(
            name: "Valid Skill",
            to: validSkill.appendingPathComponent("SKILL.md", isDirectory: false)
        )
        let outsideSkill = outsideSkillDirectory.appendingPathComponent("SKILL.md", isDirectory: false)
        try Self.writeSkill(name: "Outside Skill", to: outsideSkill)
        try Self.writeSkill(
            name: "Nested Skill",
            to: nestedSkill.appendingPathComponent("SKILL.md", isDirectory: false)
        )
        try fm.createSymbolicLink(
            at: symlinkSkill.appendingPathComponent("SKILL.md", isDirectory: false),
            withDestinationURL: outsideSkill
        )
        try fm.createSymbolicLink(
            at: skillsRoot.appendingPathComponent("linked-dir", isDirectory: true),
            withDestinationURL: outsideSkillDirectory
        )
        let hardlinkWasCreated = (try? fm.linkItem(
            at: outsideSkill,
            to: hardlinkSkill.appendingPathComponent("SKILL.md", isDirectory: false)
        )) != nil

        let registered = listRegisteredSkillsLocal(vaultPath: root.path)
        #expect(registered.map(\.name) == ["valid"])
        #expect(SkillVaultFileIO.readSkillMarkdown(vaultPath: root.path, skillName: "valid") != nil)
        #expect(SkillVaultFileIO.readSkillMarkdown(vaultPath: root.path, skillName: "../outside") == nil)
        #expect(SkillVaultFileIO.readSkillMarkdown(vaultPath: root.path, skillName: "bad/name") == nil)
        #expect(SkillVaultFileIO.readSkillMarkdown(vaultPath: root.path, skillName: "symlinked") == nil)
        if hardlinkWasCreated {
            #expect(SkillVaultFileIO.readSkillMarkdown(vaultPath: root.path, skillName: "hardlinked") == nil)
        }
    }

    private static func writeSkill(name: String, to url: URL) throws {
        try Data("""
        ---
        name: \(name)
        description: Test skill.
        ---
        # \(name)
        """.utf8).write(to: url)
    }
}
