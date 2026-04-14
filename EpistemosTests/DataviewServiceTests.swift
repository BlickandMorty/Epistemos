import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("Dataview Service")
struct DataviewServiceTests {
    @MainActor
    @Test("execute excludes archived pages from folder queries")
    func executeExcludesArchivedPagesFromFolderQueries() throws {
        let container = try ModelContainer(
            for: Schema(EpistemosSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let activePage = SDPage(title: "Active Project")
        activePage.subfolder = "Projects"
        activePage.filePath = "/tmp/Projects/active-project.md"
        activePage.isArchived = false
        context.insert(activePage)

        let archivedPage = SDPage(title: "Archived Project")
        archivedPage.subfolder = "Projects"
        archivedPage.filePath = "/tmp/Projects/archived-project.md"
        archivedPage.isArchived = true
        context.insert(archivedPage)

        try context.save()

        let service = DataviewService()
        let query = try #require(service.parse(#"TABLE file.name FROM "Projects""#))

        let result = service.execute(query, context: context)

        #expect(result.totalCount == 1)
        #expect(result.rows.count == 1)
        #expect(result.rows.first?["file.name"] == "Active Project")
    }
}
