import Testing
@testable import Epistemos

@Suite("ChatCapability intent classifier")
struct ChatCapabilityIntentTests {

    @Test("vault lookup verbs predict agent intent on cloud providers")
    func lookupVerbsPredictAgentOnCloud() {
        let prompts = [
            "find the note titled all things must go",
            "look up my project status notes",
            "search for notes about bell hooks",
            "locate the note where i wrote about epistemology",
            "show me the note from last tuesday",
            "open the note 'daily brief'",
            "which note has my weekly plan",
            "summarize my note about trauma",
            "what am i working on",
            "what am i currently working on",
            "what's in my note called Q&A",
            "read my note about testing",
        ]
        for prompt in prompts {
            let prediction = ChatCapability.predictIntent(text: prompt, isCloudProvider: true)
            #expect(
                prediction.predicted == .agent,
                "\"\(prompt)\" should predict .agent on cloud but got \(prediction.predicted)"
            )
            #expect(prediction.needsCloud == false)
        }
    }

    @Test("vault lookup verbs keep local users on the overseer tool path")
    func lookupVerbsStayLocalToolCapable() {
        let prediction = ChatCapability.predictIntent(
            text: "find the note about scheduling",
            isCloudProvider: false
        )
        #expect(prediction.predicted == .agent)
        #expect(prediction.needsCloud == false)
    }

    @Test("essay and draft vault lookup verbs predict agent intent")
    func essayAndDraftLookupVerbsPredictAgentIntent() {
        let prompts = [
            "read my essay on determinism and summarize it",
            "find the essay where i mentioned psychoneuroimmunology a few weeks ago",
            "rewrite my draft on determinism",
            "review the draft where i wrote about trauma",
        ]

        for prompt in prompts {
            let local = ChatCapability.predictIntent(text: prompt, isCloudProvider: false)
            let cloud = ChatCapability.predictIntent(text: prompt, isCloudProvider: true)

            #expect(local.predicted == .agent, "\"\(prompt)\" should predict .agent locally")
            #expect(local.needsCloud == false)
            #expect(cloud.predicted == .agent, "\"\(prompt)\" should predict .agent on cloud")
            #expect(cloud.needsCloud == false)
        }
    }

    @Test("local note-writing verbs stay tool-capable without forcing cloud")
    func localNoteWritingSignalsUseResearchPrediction() {
        let prediction = ChatCapability.predictIntent(
            text: "create a note called migration plan and save today's outline",
            isCloudProvider: false
        )
        #expect(prediction.predicted == .agent)
        #expect(prediction.needsCloud == false)
    }

    @Test("file-write requests predict tool-capable agent intent")
    func fileWriteRequestsPredictAgentIntent() {
        let prompts = [
            "write this to a file called references.md",
            "save this as a file in the vault",
            "create a file named todo.md and put this list in it",
            "edit the file called roadmap.md with these changes",
        ]

        for prompt in prompts {
            let local = ChatCapability.predictIntent(text: prompt, isCloudProvider: false)
            let cloud = ChatCapability.predictIntent(text: prompt, isCloudProvider: true)

            #expect(local.predicted == .agent, "\"\(prompt)\" should predict .agent locally")
            #expect(local.needsCloud == false)
            #expect(cloud.predicted == .agent, "\"\(prompt)\" should predict .agent on cloud")
            #expect(cloud.needsCloud == false)
        }
    }

    @Test("file-read requests predict tool-capable agent intent")
    func fileReadRequestsPredictAgentIntent() {
        let prompts = [
            "read the file called references.md",
            "open the file roadmap.md",
            "show me the file where I saved the release checklist",
            "what's in the file notes/today.md",
            "use tools to read the local file /tmp/epistemos-audit/out_of_vault_read.txt and tell me the first line exactly",
        ]

        for prompt in prompts {
            let local = ChatCapability.predictIntent(text: prompt, isCloudProvider: false)
            let cloud = ChatCapability.predictIntent(text: prompt, isCloudProvider: true)

            #expect(local.predicted == .agent, "\"\(prompt)\" should predict .agent locally")
            #expect(local.needsCloud == false)
            #expect(cloud.predicted == .agent, "\"\(prompt)\" should predict .agent on cloud")
            #expect(cloud.needsCloud == false)
        }
    }

    @Test("plain ask still falls through to the default capability")
    func plainAskFallsThrough() {
        let local = ChatCapability.predictIntent(
            text: "explain what the fibonacci sequence is",
            isCloudProvider: false
        )
        #expect(local.predicted == .local)

        let cloud = ChatCapability.predictIntent(
            text: "explain what the fibonacci sequence is",
            isCloudProvider: true
        )
        #expect(cloud.predicted == .cloud)
    }

    @Test("explicit web-search phrasing predicts agent on cloud and research on local")
    func explicitWebSearchSignalsUseToolCapablePredictions() {
        let cloud = ChatCapability.predictIntent(
            text: "search up hegemony",
            isCloudProvider: true
        )
        #expect(cloud.predicted == .agent)
        #expect(cloud.needsCloud == false)

        let local = ChatCapability.predictIntent(
            text: "search up hegemony",
            isCloudProvider: false
        )
        #expect(local.predicted == .agent)
        #expect(local.needsCloud == false)
    }

    @Test("active tool turns surface tools even on local runtimes")
    func activeToolTurnsSurfaceToolsOnLocalRuntimes() {
        let capability = ChatCapability.classify(
            isCloudProvider: false,
            isAgentExecuting: true,
            isResearchMode: false,
            isThinkingMode: false
        )

        #expect(capability == .agent)
        #expect(capability.displayName == "Tools")
    }

    @Test("current-info prompts predict research without forcing cloud agent mode")
    func currentInfoPromptsUseResearchPrediction() {
        let cloud = ChatCapability.predictIntent(
            text: "What's the weather in Chicago today?",
            isCloudProvider: true
        )
        #expect(cloud.predicted == .research)
        #expect(cloud.needsCloud == false)

        let local = ChatCapability.predictIntent(
            text: "What's the weather in Chicago today?",
            isCloudProvider: false
        )
        #expect(local.predicted == .research)
        #expect(local.needsCloud == false)
    }
}
