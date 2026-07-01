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

    @Test("skills settings source routes status through bounded diagnostics")
    func skillsSettingsSourceRoutesStatusThroughBoundedDiagnostics() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SkillsSettingsView.swift")
        let surfaces = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsSurfaceComponents.swift")
        let codepack = try loadMirroredSourceTextFile("docs/research/PLAN_3_EXTENSIBILITY_CODEPACK_2026_06_28.md")
        let capabilities = try loadMirroredSourceTextFile("docs/research/PLAN_3_CAPABILITIES_2026_06_28.md")

        #expect(source.contains("nonisolated enum SkillsSettingsStatus"))
        #expect(source.contains("maxStatusMessageCharacters"))
        #expect(source.contains("SkillsSettingsStatus.message(for: error"))
        #expect(source.contains("String(value.prefix(maxStatusMessageCharacters + 32))"))
        #expect(source.contains("String(domain.prefix(maxDomainCharacters + 32))"))
        #expect(source.contains("normalizedDisplayText(bounded)"))
        #expect(source.contains("CharacterSet.controlCharacters"))
        #expect(source.contains("maxStatusMessageCharacters - 3"))
        #expect(source.contains("SkillsSettingsStatus.message(error, fallback: \"Skill install failed.\")"))
        #expect(source.contains("SkillsSettingsStatus.message(message, fallback: success ? \"Skill installed.\" : \"Skill install failed.\")"))
        #expect(source.contains("@Environment(UIState.self)"))
        #expect(source.contains("ToolbarCapsuleButton("))
        #expect(source.contains("skillSettingsRowGap()"))
        #expect(source.contains("ui.theme.resolved.mutedForeground.color"))
        #expect(source.contains("ui.theme.resolved.headingAccent.color"))
        #expect(source.contains("ui.theme.resolved.accent.color"))
        #expect(source.contains("private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }"))
        #expect(source.contains("settingsFlatInputChrome(theme: theme"))
        #expect(source.contains("scrollContentBackground(.hidden)"))
        #expect(surfaces.contains("struct SettingsFlatInputChrome"))
        #expect(surfaces.contains(".textFieldStyle(.plain)"))
        #expect(surfaces.contains("theme.resolved.card.color.opacity"))
        #expect(!source.contains("statusMessage = error.localizedDescription"))
        #expect(!source.contains("error.localizedDescription"))
        #expect(!source.contains("Button(\"Refresh\")"))
        #expect(!source.contains("Button(\"Create Skill\")"))
        #expect(!source.contains("Button(\"Install\")"))
        #expect(!source.contains(".buttonStyle(.plain)"))
        #expect(!source.contains(".foregroundStyle(.secondary)"))
        #expect(!source.contains(".foregroundStyle(.tertiary)"))
        #expect(!source.contains(".textFieldStyle(.roundedBorder)"))
        #expect(!source.contains("Divider()"))
        #expect(!source.contains(".fill(.thinMaterial)"))
        #expect(!source.contains("tint: .green"))
        #expect(!source.contains("tint: .orange"))
        #expect(codepack.contains("Skills settings status text"))
        #expect(codepack.contains("raw message/domain strings bounded and control/whitespace-normalized before trim/validation"))
        #expect(capabilities.contains("Skills settings status text"))
        #expect(capabilities.contains("raw message/domain\nstrings bounded and control/whitespace-normalized before trim/validation"))
    }
}
