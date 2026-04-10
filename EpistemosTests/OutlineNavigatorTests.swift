import Testing
@testable import Epistemos

@Suite("Outline Navigator")
struct OutlineNavigatorTests {
    @Test("outline parser preserves nested hierarchy for top-level symbols and members")
    func outlineParserPreservesNestedHierarchy() throws {
        let content = """
        struct AppBootstrap {
            // MARK: - Infrastructure
            func startupAutoDiscovery() {}

            struct Loader {
                func begin() {}
            }
        }
        """

        let items = OutlineParser.parse(content: content, language: "swift")

        let root = try #require(items.first)
        #expect(root.title == "AppBootstrap")
        #expect(root.children.contains(where: { $0.title == "Infrastructure" }))
        #expect(root.children.contains(where: { $0.title == "startupAutoDiscovery" }))

        let loader = try #require(root.children.first(where: { $0.title == "Loader" }))
        #expect(loader.children.contains(where: { $0.title == "begin" }))
    }

    @Test("outline parser keeps stable identities when line numbers shift")
    func outlineParserKeepsStableIdentitiesAcrossLineShifts() throws {
        let original = """
        struct AppBootstrap {
            func startupAutoDiscovery() {}

            struct Loader {
                func begin() {}
            }
        }
        """
        let shifted = """

        \(original)
        """

        let firstItems = OutlineParser.parse(content: original, language: "swift")
        let secondItems = OutlineParser.parse(content: shifted, language: "swift")

        let firstRoot = try #require(firstItems.first)
        let secondRoot = try #require(secondItems.first)
        let firstLoader = try #require(firstRoot.children.first(where: { $0.title == "Loader" }))
        let secondLoader = try #require(secondRoot.children.first(where: { $0.title == "Loader" }))

        #expect(firstRoot.outlineIdentity == secondRoot.outlineIdentity)
        #expect(firstLoader.outlineIdentity == secondLoader.outlineIdentity)
    }
}
