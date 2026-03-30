import Testing
@testable import Epistemos

@Suite("AXSemanticSelector")
@MainActor
struct AXSemanticSelectorTests {

    // MARK: - Parsing

    @Test("Parses simple role selector")
    func parseSimpleRole() {
        let segments = AXSemanticSelector.parse("//AXButton")
        #expect(segments.count == 1)
        #expect(segments[0].role == "AXButton")
        #expect(segments[0].predicates.isEmpty)
    }

    @Test("Parses role with equals predicate")
    func parseRoleWithEquals() {
        let segments = AXSemanticSelector.parse("//AXButton[@AXTitle='New Tab']")
        #expect(segments.count == 1)
        #expect(segments[0].role == "AXButton")
        #expect(segments[0].predicates.count == 1)
        if case .equals(let attr, let value) = segments[0].predicates[0] {
            #expect(attr == "AXTitle")
            #expect(value == "New Tab")
        } else {
            Issue.record("Expected .equals predicate")
        }
    }

    @Test("Parses role with contains predicate")
    func parseRoleWithContains() {
        let segments = AXSemanticSelector.parse("//AXStaticText[contains(@AXValue,'hello')]")
        #expect(segments.count == 1)
        #expect(segments[0].role == "AXStaticText")
        if case .contains(let attr, let substring) = segments[0].predicates[0] {
            #expect(attr == "AXValue")
            #expect(substring == "hello")
        } else {
            Issue.record("Expected .contains predicate")
        }
    }

    @Test("Parses chained multi-segment selector")
    func parseChainedSelector() {
        let segments = AXSemanticSelector.parse("//AXApplication[@AXTitle='Safari']//AXButton[@AXTitle='New Tab']")
        #expect(segments.count == 2)
        #expect(segments[0].role == "AXApplication")
        #expect(segments[1].role == "AXButton")
    }

    @Test("Parses selector with multiple predicates")
    func parseMultiplePredicates() {
        let segments = AXSemanticSelector.parse("//AXButton[@AXTitle='OK'][@AXDescription='Confirm']")
        #expect(segments.count == 1)
        #expect(segments[0].predicates.count == 2)
    }

    @Test("Empty selector returns empty segments")
    func parseEmpty() {
        let segments = AXSemanticSelector.parse("")
        #expect(segments.isEmpty)
    }

    @Test("Selector with only slashes returns empty")
    func parseOnlySlashes() {
        let segments = AXSemanticSelector.parse("//")
        #expect(segments.isEmpty)
    }

    // MARK: - Resolution

    @Test("Resolves matching element from AX tree JSON")
    func resolveMatch() {
        let axTree = """
        {"elements": [
            {"role": "AXButton", "title": "Save", "description": "", "is_interactive": true},
            {"role": "AXButton", "title": "Cancel", "description": "", "is_interactive": true},
            {"role": "AXStaticText", "title": "Hello", "description": "", "is_interactive": false}
        ]}
        """
        let matches = AXSemanticSelector.resolve(selector: "//AXButton[@AXTitle='Save']", axTreeJson: axTree)
        #expect(matches.count == 1)
        #expect(matches[0].title == "Save")
        #expect(matches[0].isInteractive)
    }

    @Test("Resolves multiple matches")
    func resolveMultipleMatches() {
        let axTree = """
        {"elements": [
            {"role": "AXButton", "title": "A", "description": "", "is_interactive": true},
            {"role": "AXButton", "title": "B", "description": "", "is_interactive": true},
            {"role": "AXStaticText", "title": "C", "description": "", "is_interactive": false}
        ]}
        """
        let matches = AXSemanticSelector.resolve(selector: "//AXButton", axTreeJson: axTree)
        #expect(matches.count == 2)
    }

    @Test("No match returns empty")
    func resolveNoMatch() {
        let axTree = """
        {"elements": [
            {"role": "AXStaticText", "title": "Hello", "description": "", "is_interactive": false}
        ]}
        """
        let matches = AXSemanticSelector.resolve(selector: "//AXButton[@AXTitle='Missing']", axTreeJson: axTree)
        #expect(matches.isEmpty)
    }

    @Test("resolveBest prefers interactive element")
    func resolveBestPrefersInteractive() {
        let axTree = """
        {"elements": [
            {"role": "AXButton", "title": "Click", "description": "", "is_interactive": false},
            {"role": "AXButton", "title": "Click", "description": "", "is_interactive": true}
        ]}
        """
        let best = AXSemanticSelector.resolveBest(selector: "//AXButton[@AXTitle='Click']", axTreeJson: axTree)
        #expect(best != nil)
        #expect(best?.isInteractive == true)
    }

    @Test("Invalid JSON returns empty matches")
    func resolveInvalidJson() {
        let matches = AXSemanticSelector.resolve(selector: "//AXButton", axTreeJson: "not json")
        #expect(matches.isEmpty)
    }

    // MARK: - Build Selector

    @Test("Builds selector from role and title")
    func buildSelectorWithTitle() {
        let selector = AXSemanticSelector.buildSelector(role: "AXButton", title: "Save")
        #expect(selector == "//AXButton[@AXTitle='Save']")
    }

    @Test("Builds selector with role only")
    func buildSelectorRoleOnly() {
        let selector = AXSemanticSelector.buildSelector(role: "AXMenuItem")
        #expect(selector == "//AXMenuItem")
    }

    @Test("Builds selector with title and description")
    func buildSelectorWithBoth() {
        let selector = AXSemanticSelector.buildSelector(role: "AXButton", title: "OK", description: "Confirm action")
        #expect(selector == "//AXButton[@AXTitle='OK'][@AXDescription='Confirm action']")
    }

    // MARK: - Contains predicate resolution

    @Test("Contains predicate matches substring")
    func resolveContainsPredicate() {
        let axTree = """
        {"elements": [
            {"role": "AXStaticText", "title": "Hello World", "description": "", "is_interactive": false},
            {"role": "AXStaticText", "title": "Goodbye", "description": "", "is_interactive": false}
        ]}
        """
        let matches = AXSemanticSelector.resolve(
            selector: "//AXStaticText[contains(@AXTitle,'World')]",
            axTreeJson: axTree
        )
        #expect(matches.count == 1)
        #expect(matches[0].title == "Hello World")
    }
}
