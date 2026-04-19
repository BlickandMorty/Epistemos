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

    @Test("vault lookup verbs nudge local users toward cloud")
    func lookupVerbsRequestCloudOnLocal() {
        let prediction = ChatCapability.predictIntent(
            text: "find the note about scheduling",
            isCloudProvider: false
        )
        #expect(prediction.predicted == .cloud)
        #expect(prediction.needsCloud == true)
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
}
