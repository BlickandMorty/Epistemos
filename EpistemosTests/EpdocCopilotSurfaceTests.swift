import Foundation
import Testing

@testable import Epistemos

@Suite("Epdoc Copilot surface")
nonisolated struct EpdocCopilotSurfaceTests {
    @Test("prompt router maps doc requests to bounded transforms")
    func promptRouterMapsRequestsToTransforms() {
        #expect(EpdocCopilotTransform.resolve(prompt: "make this into a graph") == .visualMap)
        #expect(EpdocCopilotTransform.resolve(prompt: "add YAML front matter") == .frontmatter)
        #expect(EpdocCopilotTransform.resolve(prompt: "make a scatterplot of the evidence") == .scatterplot)
        #expect(EpdocCopilotTransform.resolve(prompt: "turn this into a study callout") == .studyCallout)
        #expect(EpdocCopilotTransform.resolve(prompt: "what is the argument?") == nil)
    }

    @Test("transform commands use concrete epdoc editor actions")
    func transformCommandsAreConcrete() {
        #expect(EpdocCopilotTransform.visualMap.command == .runCommand(
            name: "requestHTMLWorkspace",
            argsJSON: Data("[]".utf8)
        ))
        #expect(EpdocCopilotTransform.scatterplot.command == .insertSlashChoice(blockType: "chart-scatter"))
        #expect(EpdocCopilotTransform.studyCallout.command == .insertSlashChoice(blockType: "callout-tip"))

        guard case let .runCommand(name, argsJSON) = EpdocCopilotTransform.frontmatter.command else {
            Issue.record("Frontmatter must be a concrete JS command so the dock does not insert inert UI chrome.")
            return
        }
        #expect(name == "insertEpdocFrontmatter")
        #expect(argsJSON == Data("[]".utf8))
    }

    @Test("AI diff review draft maps only to bounded review commands")
    func aiDiffReviewDraftCommandsAreBounded() throws {
        let request = try #require(EpdocAIDiffStageRequest(
            markdown: "# Revised\n\nSettled body.",
            claimId: "claim-review",
            batchId: "batch-review"
        ))
        let draft = EpdocAIDiffReviewDraft(request: request)

        #expect(draft.previewCommand == .stageAIDiff(request: request))
        #expect(draft.acceptCommand == .acceptAIDiff)
        #expect(draft.rejectCommand == .rejectAIDiff)
    }

    @Test("June suggestion review draft maps to tracked suggestion commands")
    func juneSuggestionReviewDraftCommandsAreBounded() {
        let payload = EpdocSuggestionSpanPayload(
            id: "june-span",
            author: "june",
            turnID: "turn-1",
            kind: "replacement",
            from: 5,
            to: 16,
            mapVersion: 1,
            before: "old claim",
            after: "revised claim",
            rationale: "Tighten wording.",
            sourceCitation: "source:alpha",
            claimID: "claim-alpha"
        )
        let draft = EpdocSuggestionReviewDraft(payload: payload)

        #expect(draft.stageCommand == .applySuggestion(payload: payload))
        #expect(draft.acceptCommand == .acceptSuggestion(id: "june-span"))
        #expect(draft.rejectCommand == .rejectSuggestion(id: "june-span"))
    }

    @Test("epdoc chrome mounts native bottom document actions")
    func chromeMountsNativeCopilotDock() throws {
        let chrome = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let dock = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocCopilotDockView.swift")
        let surface = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let inbound = try loadMirroredSourceTextFile("js-editor/src/bridge/inbound.ts")

        #expect(chrome.contains("EpdocCopilotDockView("),
                "Epdoc must expose the document actions directly in the native editor chrome.")
        #expect(chrome.contains(".overlay(alignment: .bottomTrailing)"),
                "The document actions should stay in bottom native chrome, not inside the WebKit document body.")
        #expect(chrome.contains("assistContextProvider"))
        #expect(surface.contains("JuneEpdocAssistContext(")
                && surface.contains("vaultRelativePath: noteRelativePath")
                && surface.contains("selection: JuneEpdocAssistSelection(coordinator.controller.latestSelection)"),
                "The Epdoc dock must receive a bounded note-scoped MAS-June assist context.")
        #expect(dock.contains("ForEach([EpdocCopilotTransform.frontmatter])"))
        #expect(!dock.contains("ForEach([EpdocCopilotTransform.visualMap, .frontmatter])"),
                "The bottom page dock should not expose an HTML Workspace quick action.")
        #expect(dock.contains("JuneEpdocAssistContext"))
        #expect(dock.contains("submitAssist"))
        #expect(dock.contains("stageAssistSuggestion"))
        #expect(dock.contains("TextField(\"Ask June\""))
        #expect(dock.contains("message.badge.waveform"))
        #expect(dock.contains("Stage June suggestion"))
        #expect(dock.contains("Accept June suggestion"))
        #expect(dock.contains("Reject June suggestion"))
        #expect(dock.contains("Add frontmatter"))
        #expect(dock.contains("Review edit"))
        #expect(dock.contains("Accept AI edit"))
        #expect(dock.contains("Reject AI edit"))
        #expect(!dock.contains("EpdocCopilotMessageBubble"))
        #expect(dock.contains(".regularMaterial"))
        #expect(!dock.contains("WKWebView"),
                "The document action dock is native SwiftUI chrome; the document body stays the only WebKit surface.")
        #expect(inbound.contains("requestHTMLWorkspace"))
        #expect(inbound.contains("insertEpdocFrontmatter"))
        #expect(inbound.contains("function insertEpdocFrontmatter(editor: Editor): boolean"))
    }

    @Test("epdoc dock routes free-form prompt through MAS June instead of parked runtimes")
    func freeformPromptRoutesThroughMASJune() throws {
        let dock = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocCopilotDockView.swift")
        let assist = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneEpdocAssist.swift")
        let gateway = try loadMirroredSourceTextFile("Epistemos/JuneAgent/JuneAgentGateway.swift")

        #expect(!dock.contains("I sent that to the document agent hook"),
                "The .epdoc document window should route free-form prompts through MAS June, not a parked document-agent hook.")
        #expect(!dock.contains("Free-form document editing is not wired yet"),
                "The Epdoc window should route free-form note context to MAS June, not show stale deferred copy.")
        #expect(dock.contains("submitAssistPrompt()"))
        #expect(assist.contains("#if EPISTEMOS_APP_STORE"))
        #expect(assist.contains("JuneAgentSurfaceHolder.shared"))
        #expect(assist.contains("June Epdoc Assist is available in the Mac App Store build."))
        #expect(gateway.contains("func submitEpdocAssist(")
                && gateway.contains("startTurn(")
                && gateway.contains("context.promptPacket(userPrompt: trimmedPrompt)"),
                "Epdoc assist submissions must reuse the existing June gateway/session stream path.")
        #expect(assist.contains("latestNoteSuggestion(")
                && gateway.contains("func latestEpdocAssistNoteSuggestion(")
                && assist.contains("JuneEpdocAssistNoteSuggestionParser"),
                "Epdoc assist suggestion staging must read June's persisted assistant reply and parse it natively.")
        #expect(!assist.contains("Kindred"))
        #expect(!assist.contains("sub_chats"))
        #expect(!assist.contains("Process("))
        #expect(!dock.contains("WKWebView"))
    }

    @Test("June Epdoc assist context is bounded and carries note location")
    func juneEpdocAssistContextIsBoundedAndScoped() {
        let selection = JuneEpdocAssistSelection(
            from: 5,
            to: 20,
            text: String(repeating: "s", count: JuneEpdocAssistContext.maxSelectedTextCharacters + 50)
        )
        let markdown = """
        # Claim

        Body with dataset:metrics.dataset.md and claim:alpha.

        ## Evidence
        \(String(repeating: "x", count: JuneEpdocAssistContext.maxMarkdownExcerptCharacters + 50))
        """
        let context = JuneEpdocAssistContext(
            noteID: "note-1",
            title: "  Research Note  ",
            vaultRelativePath: "notes/research.md",
            activeLens: "document",
            markdown: markdown,
            selection: selection
        )
        let packet = context.promptPacket(userPrompt: "Please tighten the evidence.")

        #expect(context.noteID == "note-1")
        #expect(context.title == "Research Note")
        #expect(context.vaultRelativePath == "notes/research.md")
        #expect(context.selection?.text?.count == JuneEpdocAssistContext.maxSelectedTextCharacters)
        #expect(context.markdownExcerpt.count <= JuneEpdocAssistContext.maxMarkdownExcerptCharacters + 3)
        #expect(context.visibleHeadings == ["Claim", "Evidence"])
        #expect(context.datasetRefs.contains("dataset:metrics.dataset.md"))
        #expect(context.provenanceContext.contains { $0.contains("claim:alpha") })
        #expect(packet.contains("Do not directly mutate notes, vault files, or dataset cells."))
        #expect(packet.contains("For note edits, propose a structured Markdown revision"))
        #expect(packet.contains("```epdoc-note-suggestion"))
        #expect(packet.contains("vault_relative_path: notes/research.md"))
    }

    @Test("June Epdoc assist parses only matching current-selection suggestions")
    func juneEpdocAssistParsesMatchingSelectionSuggestion() throws {
        let context = JuneEpdocAssistContext(
            noteID: "note-1",
            title: "Claim",
            vaultRelativePath: "notes/claim.md",
            activeLens: "document",
            markdown: "Tighten this claim.",
            selection: JuneEpdocAssistSelection(from: 2, to: 12, text: "old claim")
        )
        let reply = """
        I would stage this for review.

        ```epdoc-note-suggestion
        {"id":"model span 1","from":2,"to":12,"before":"old claim","after":"revised claim","rationale":"Tighter wording.","sourceCitation":"source:alpha","claimId":"claim-alpha"}
        ```
        """

        guard case let .staged(draft) = JuneEpdocAssistNoteSuggestionParser.parseLatestReply(
            reply,
            sessionID: "session-1",
            context: context
        ) else {
            Issue.record("matching selection suggestion should stage")
            return
        }

        #expect(draft.payload.id == "modelspan1")
        #expect(draft.payload.author == "june")
        #expect(draft.payload.turnID == "session-1")
        #expect(draft.payload.kind == "replacement")
        #expect(draft.payload.from == 2)
        #expect(draft.payload.to == 12)
        #expect(draft.payload.before == "old claim")
        #expect(draft.payload.after == "revised claim")
        #expect(draft.payload.rationale == "Tighter wording.")
        #expect(draft.payload.sourceCitation == "source:alpha")
        #expect(draft.payload.claimID == "claim-alpha")
    }

    @Test("June Epdoc assist refuses stale or blind suggestions")
    func juneEpdocAssistRefusesStaleOrBlindSuggestions() {
        let context = JuneEpdocAssistContext(
            noteID: "note-1",
            title: "Claim",
            vaultRelativePath: "notes/claim.md",
            activeLens: "document",
            markdown: "Tighten this claim.",
            selection: JuneEpdocAssistSelection(from: 2, to: 12, text: "old claim")
        )
        let staleReply = """
        ```epdoc-note-suggestion
        {"from":2,"to":12,"before":"different text","after":"revised claim"}
        ```
        """
        let blindContext = JuneEpdocAssistContext(
            noteID: "note-1",
            title: "Claim",
            vaultRelativePath: "notes/claim.md",
            activeLens: "document",
            markdown: "Tighten this claim."
        )

        #expect(JuneEpdocAssistNoteSuggestionParser.parseLatestReply(
            staleReply,
            sessionID: "session-1",
            context: context
        ) == .unavailable("June's suggestion does not match the selected text."))
        #expect(JuneEpdocAssistNoteSuggestionParser.parseLatestReply(
            staleReply,
            sessionID: "session-1",
            context: blindContext
        ) == .unavailable("Select note text before staging a June suggestion."))
    }
}
