import Testing
@testable import Epistemos

struct CommandInputParserTests {

    // MARK: - Empty Input

    @Test func emptyInput() {
        let result = CommandInputParser.parse("")
        #expect(result.slashToken == nil)
        #expect(result.mentions.isEmpty)
        #expect(result.cleanedQuery == "")
        #expect(result.suggestionState == .hidden)
    }

    @Test func whitespaceOnly() {
        let result = CommandInputParser.parse("   \n  ")
        #expect(result.slashToken == nil)
        #expect(result.mentions.isEmpty)
        #expect(result.cleanedQuery == "")
        #expect(result.suggestionState == .hidden)
    }

    // MARK: - Builtin Slash Commands

    @Test func exactBuiltinSlashCommand() {
        let result = CommandInputParser.parse("/ask what is Swift?")
        #expect(result.slashToken == .builtinMode(.ask))
        #expect(result.cleanedQuery == "what is Swift?")
    }

    @Test func debugSlashCommand() {
        let result = CommandInputParser.parse("/debug why does this crash")
        #expect(result.slashToken == .builtinMode(.debug))
        #expect(result.cleanedQuery == "why does this crash")
    }

    @Test func planSlashCommand() {
        let result = CommandInputParser.parse("/plan build a REST API")
        #expect(result.slashToken == .builtinMode(.plan))
    }

    @Test func researchSlashCommand() {
        let result = CommandInputParser.parse("/research state space models")
        #expect(result.slashToken == .builtinMode(.research))
    }

    @Test func slashCommandOnly() {
        let result = CommandInputParser.parse("/ask")
        #expect(result.slashToken == .builtinMode(.ask))
    }

    // MARK: - Partial Slash (Suggestion State)

    @Test func partialSlashProducesSuggestion() {
        let result = CommandInputParser.parse("/de")
        #expect(result.slashToken == nil)
        #expect(result.suggestionState == .slashMenu(filter: "de"))
    }

    @Test func slashAloneShowsAllSuggestions() {
        let result = CommandInputParser.parse("/")
        #expect(result.slashToken == nil)
        #expect(result.suggestionState == .slashMenu(filter: ""))
    }

    @Test func partialSlashNoMatch() {
        let result = CommandInputParser.parse("/zzzzz")
        #expect(result.slashToken == nil)
        #expect(result.suggestionState == .slashMenu(filter: "zzzzz"))
    }

    // MARK: - Skill Slash Commands

    @Test func exactSkillMatch() {
        let codeReview = SkillDiscoveryEntry(
            identifier: "code-review",
            description: "Review code for issues",
            category: "engineering",
            tags: ["code"],
            source: .bundled,
            sourcePath: "/skills/code-review"
        )

        let result = CommandInputParser.parse(
            "/code-review fix the memory leak",
            availableSkills: [codeReview]
        )
        #expect(result.slashToken == .skill(codeReview))
        #expect(result.cleanedQuery == "fix the memory leak")
    }

    @Test func skillVsBuiltinDisambiguation() {
        let skill = SkillDiscoveryEntry(
            identifier: "custom-ask",
            description: "Custom ask skill",
            category: "custom",
            tags: [],
            source: .codex,
            sourcePath: "/skills/custom-ask"
        )

        let result = CommandInputParser.parse("/ask hello", availableSkills: [skill])
        #expect(result.slashToken == .builtinMode(.ask))
    }

    // MARK: - @Mentions (Bracketed)

    @Test func bracketedMention() {
        let providers = [
            ACCContextProvider(id: "note:My Note", token: "My Note", category: .openNote)
        ]
        let result = CommandInputParser.parse("summarize @[My Note]", contextProviders: providers)
        #expect(result.mentions.count == 1)
        #expect(result.mentions.first?.token == "My Note")
        #expect(result.mentions.first?.mentionType == .openNote)
    }

    // MARK: - @Mentions (Single Word)

    @Test func singleWordMention() {
        let providers = [
            ACCContextProvider(id: "agent:safari", token: "Safari", category: .agent)
        ]
        let result = CommandInputParser.parse("search @Safari for docs", contextProviders: providers)
        #expect(result.mentions.count == 1)
        #expect(result.mentions.first?.token == "Safari")
        #expect(result.mentions.first?.mentionType == .agent)
    }

    @Test func partialMentionSuggestion() {
        let providers = [
            ACCContextProvider(id: "agent:safari", token: "Safari", category: .agent)
        ]
        let result = CommandInputParser.parse("search @Saf", contextProviders: providers)
        #expect(result.suggestionState == .contextMentions(filter: "Saf"))
    }

    // MARK: - Mixed Input

    @Test func slashPlusMention() {
        let providers = [
            ACCContextProvider(id: "agent:safari", token: "Safari", category: .agent)
        ]
        let result = CommandInputParser.parse("/research @Safari how does WebKit work", contextProviders: providers)
        #expect(result.slashToken == .builtinMode(.research))
        #expect(result.mentions.count == 1)
        #expect(result.mentions.first?.token == "Safari")
    }

    // MARK: - Cleaned Query

    @Test func cleanedQueryStripsTokens() {
        let providers = [
            ACCContextProvider(id: "agent:safari", token: "Safari", category: .agent)
        ]
        let result = CommandInputParser.parse("/ask @Safari what is WebKit?", contextProviders: providers)
        #expect(result.slashToken == .builtinMode(.ask))
        #expect(!result.cleanedQuery.contains("@Safari"))
        #expect(result.cleanedQuery.contains("what is WebKit?"))
    }

    // MARK: - Case Insensitivity

    @Test func caseInsensitiveSlash() {
        let result = CommandInputParser.parse("/ASK hello")
        #expect(result.slashToken == .builtinMode(.ask))
    }

    @Test func caseInsensitiveMention() {
        let providers = [
            ACCContextProvider(id: "agent:safari", token: "Safari", category: .agent)
        ]
        let result = CommandInputParser.parse("@safari search", contextProviders: providers)
        #expect(result.mentions.count == 1)
        #expect(result.mentions.first?.token == "Safari")
    }

    // MARK: - Plain Text (No Tokens)

    @Test func plainText() {
        let result = CommandInputParser.parse("just a normal question about Swift")
        #expect(result.slashToken == nil)
        #expect(result.mentions.isEmpty)
        #expect(result.cleanedQuery == "just a normal question about Swift")
        #expect(result.suggestionState == .hidden)
    }

    // MARK: - Read Branch

    @Test func readBranchCommand() {
        let result = CommandInputParser.parse("/read-branch main")
        #expect(result.slashToken == .builtinMode(.readBranch))
        #expect(result.cleanedQuery == "main")
    }
}
