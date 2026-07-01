import Testing

@testable import Epistemos

@Suite("Plan 2 wikilink navigation")
struct WikilinkNavigationPlan2Tests {
    @Test("wikilink navigation uses the canonical resolver for aliases headings and paths")
    func wikilinkNavigationUsesCanonicalResolver() throws {
        #expect(WikilinkResolver.canonicalDestination("Research/Target Note.md#Evidence|the target") == "research/target note")
        #expect(WikilinkResolver.canonicalDestination("./Research/Target Note.md#Evidence|the target") == "research/target note")
        #expect(WikilinkResolver.extractDestinations(from: "See [Target](./Research/Target%20Note.md#Evidence)") == ["research/target note"])
        #expect(WikilinkResolver.displayTitle(forDestination: "Research/Target Note.md#Evidence|the target") == "Target Note")
        #expect(WikilinkResolver.displayTitle(forDestination: "Folder/My%20Note#Part") == "My Note")
        #expect(WikilinkResolver.displayTitle(forDestination: "#Local Heading") == nil)
        #expect(WikilinkResolver.localHeadingTitle(forDestination: "#Local%20Heading|here") == "Local Heading")
        #expect(WikilinkResolver.localHeadingTitle(forDestination: "Research/Target#Heading") == nil)

        let workspace = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let prose = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        #expect(workspace.contains("scrollToLocalWikilinkHeading(localHeading)"))
        #expect(workspace.contains("TOCParser.parse(body)"))
        #expect(workspace.contains("scrollEditorTo(charOffset: target.charOffset)"))
        #expect(workspace.contains("WikilinkResolver.canonicalDestination(trimmed)"))
        #expect(workspace.contains("WikilinkResolver.displayTitle(forDestination: trimmed)"))
        #expect(workspace.contains("WikilinkResolver.lookupKeys(forDestination: destination)"))
        #expect(workspace.contains("private func pageMatchingWikilinkDestination(targetKeys: [String], pages: [SDPage]) -> SDPage?"))
        #expect(workspace.contains("for key in targetKeys"))
        #expect(workspace.contains("vaultRelativePath: page.vaultRelativeNotePath"))
        #expect(workspace.contains("title: displayTitle"))
        #expect(!workspace.contains("title: trimmed,\n                    allowVaultSelectionPrompt: true"))
        #expect(prose.contains("scrollToLocalWikilinkHeading(localHeading)"))
        #expect(prose.contains("TOCParser.parse(bodyText)"))
        #expect(prose.contains("ProseTextView2.scrollToOffsetNotification"))
        #expect(prose.contains("WikilinkResolver.canonicalDestination(trimmed)"))
        #expect(prose.contains("WikilinkResolver.displayTitle(forDestination: trimmed)"))
        #expect(prose.contains("existingPageForWikilink(destination: destination, displayTitle: displayTitle)"))
        #expect(prose.contains("WikilinkResolver.lookupKeys(forDestination: destination)"))
        #expect(prose.contains("title: displayTitle,\n                    allowVaultSelectionPrompt: true"))
        #expect(!prose.contains("title: trimmed,\n                    allowVaultSelectionPrompt: true"))
    }
}
