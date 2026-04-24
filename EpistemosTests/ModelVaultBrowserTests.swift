import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("Model Vault Browser")
struct ModelVaultBrowserTests {

    private func encodeMetadata(_ metadata: ModelVaultMetadata) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(metadata)
    }

    private func makeTempDirectory(_ prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makePageContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeChatContainer() throws -> ModelContainer {
        let schema = Schema([SDChat.self, SDMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("browser hides internal dotfiles unless requested")
    func browserHidesInternalDotfilesUnlessRequested() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Instructions".write(
            to: root.appendingPathComponent("instructions.md"),
            atomically: true,
            encoding: .utf8
        )
        try "{}".write(
            to: root.appendingPathComponent("meta.json"),
            atomically: true,
            encoding: .utf8
        )
        try "secret".write(
            to: root.appendingPathComponent(".claude-system.md"),
            atomically: true,
            encoding: .utf8
        )

        let visibleEntries = ModelVaultBrowserStore.loadEntries(rootURL: root, includeHidden: false)
        #expect(visibleEntries.map(\.relativePath) == ["instructions.md", "meta.json"])

        let allEntries = ModelVaultBrowserStore.loadEntries(rootURL: root, includeHidden: true)
        #expect(allEntries.map(\.relativePath).contains(".claude-system.md"))
    }

    @Test("browser keeps curated vault documents at the top of the file list")
    func browserKeepsCuratedVaultDocumentsAtTopOfFileList() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-order-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let files = [
            "notes.md",
            "knowledge_profile.md",
            "concept_index.md",
            "active_context.md",
            "instructions.md",
            "meta.json",
        ]

        for file in files {
            try file.write(
                to: root.appendingPathComponent(file),
                atomically: true,
                encoding: .utf8
            )
        }

        let entries = ModelVaultBrowserStore.loadEntries(rootURL: root)
        #expect(Array(entries.map(\.relativePath).prefix(5)) == [
            "instructions.md",
            "knowledge_profile.md",
            "concept_index.md",
            "active_context.md",
            "meta.json",
        ])
    }

    @Test("browser recognizes text files that can be edited inline")
    func browserRecognizesEditableTextFiles() {
        #expect(ModelVaultBrowserStore.isEditableTextFile(URL(fileURLWithPath: "/tmp/instructions.md")))
        #expect(ModelVaultBrowserStore.isEditableTextFile(URL(fileURLWithPath: "/tmp/meta.json")))
        #expect(ModelVaultBrowserStore.isEditableTextFile(URL(fileURLWithPath: "/tmp/internal.toml")))
        #expect(!ModelVaultBrowserStore.isEditableTextFile(URL(fileURLWithPath: "/tmp/archive.bin")))
    }

    @Test("known models keep their curated display names even when vault metadata is stale")
    func knownModelsKeepCuratedDisplayNamesWhenMetadataIsStale() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-metadata-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let metadata = ModelVaultMetadata(
            modelID: "gemini-3-flash-preview",
            displayName: "Gemini 3 Flash Preview",
            compiledAt: Date(timeIntervalSince1970: 0),
            noteCount: 1,
            conceptCount: 1,
            activeNoteCount: 1,
            tokenEstimate: 256
        )
        let metadataData = try encodeMetadata(metadata)
        try metadataData.write(to: root.appendingPathComponent("meta.json"))

        let entry = ModelVaultEntry(url: root)
        #expect(entry.id == "gemini-3-flash-preview")
        #expect(entry.displayName == "Gemini 3 Flash")
    }

    @Test("cloud vault entries accept both vendor and legacy authored model ids")
    func cloudVaultEntriesAcceptVendorAndLegacyAuthoredModelIDs() {
        let entry = ModelVaultEntry(
            url: URL(fileURLWithPath: "/tmp/gpt-5.4", isDirectory: true)
        )

        #expect(entry.id == "gpt-5.4")
        #expect(entry.acceptedAuthoredModelIDs.contains("gpt-5.4"))
        #expect(entry.acceptedAuthoredModelIDs.contains("openai:gpt-5.4"))
    }

    @Test("cloud metadata raw ids canonicalize to the curated vendor model id")
    func cloudMetadataRawIDsCanonicalizeToVendorModelID() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-cloud-raw-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let metadata = ModelVaultMetadata(
            modelID: "openai:gpt-5.4",
            displayName: "GPT-5.4",
            compiledAt: Date(timeIntervalSince1970: 0),
            noteCount: 2,
            conceptCount: 5,
            activeNoteCount: 1,
            tokenEstimate: 128
        )
        let metadataData = try encodeMetadata(metadata)
        try metadataData.write(to: root.appendingPathComponent("meta.json"))

        let entry = ModelVaultEntry(url: root)
        #expect(entry.id == "gpt-5.4")
        #expect(entry.acceptedAuthoredModelIDs.contains("openai:gpt-5.4"))
    }

    @Test("browser can create and delete model vault text files")
    func browserCanCreateAndDeleteModelVaultTextFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-create-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let created = try #require(
            ModelVaultBrowserStore.createTextFile(
                named: "notes",
                rootURL: root,
                relativeDirectory: "contexts/swift"
            )
        )
        #expect(created.relativePath == "contexts/swift/notes.md")
        #expect(FileManager.default.fileExists(atPath: created.url.path))

        let loaded = try ModelVaultBrowserStore.readText(at: created.url)
        #expect(loaded == "")

        #expect(ModelVaultBrowserStore.deleteItem(at: created.url))
        #expect(!FileManager.default.fileExists(atPath: created.url.path))
    }

    @Test("browser keeps empty model vault folders visible in the tree")
    func browserKeepsEmptyModelVaultFoldersVisibleInTheTree() throws {
        let root = try makeTempDirectory("model-vault-browser-directories")
        defer { try? FileManager.default.removeItem(at: root) }

        let emptyFolder = root.appendingPathComponent("contexts/swift", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
        try "print(\"hello\")\n".write(
            to: root.appendingPathComponent("main.swift"),
            atomically: true,
            encoding: .utf8
        )

        let entries = ModelVaultBrowserStore.loadEntries(rootURL: root)
        let byPath = Dictionary(uniqueKeysWithValues: entries.map { ($0.relativePath, $0) })

        #expect(byPath["contexts"]?.isDirectory == true)
        #expect(byPath["contexts/swift"]?.isDirectory == true)
        #expect(byPath["main.swift"]?.isDirectory == false)
    }

    @Test("browser lists newly created model vault folders even before they contain files")
    func browserListsNewlyCreatedModelVaultFoldersBeforeTheyContainFiles() throws {
        let root = try makeTempDirectory("model-vault-browser-empty-folder")
        defer { try? FileManager.default.removeItem(at: root) }

        let created = try #require(
            ModelVaultBrowserStore.createDirectory(
                named: "contexts",
                rootURL: root
            )
        )
        #expect(FileManager.default.fileExists(atPath: created.path))

        let entries = ModelVaultBrowserStore.loadEntries(rootURL: root)
        #expect(entries.contains { $0.relativePath == "contexts" && $0.isDirectory })
    }

    @Test("browser creates and refreshes real file-backed workspace pages for model vault files")
    @MainActor
    func browserCreatesAndRefreshesWorkspacePagesForModelVaultFiles() throws {
        let storageRoot = try makeTempDirectory("model-vault-browser-storage")
        let root = try makeTempDirectory("model-vault-browser-pages")
        defer {
            try? FileManager.default.removeItem(at: storageRoot)
            try? FileManager.default.removeItem(at: root)
        }

        let markdownURL = root.appendingPathComponent("instructions.md")
        try """
        ---
        title: Instructions
        ---

        Current body
        """.write(to: markdownURL, atomically: true, encoding: .utf8)

        try NoteFileStorage.withStorageDirectoryOverrideForTesting(storageRoot) {
            let container = try makePageContainer()
            let context = ModelContext(container)
            let document = try #require(
                ModelVaultBrowserStore.loadEntries(rootURL: root)
                    .first(where: { $0.relativePath == "instructions.md" })
            )

            let firstPageID = try #require(
                ModelVaultBrowserStore.ensureWorkspacePage(for: document, modelContext: context)
            )
            let initialFetch = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.id == firstPageID }
            )
            let page = try #require(try context.fetch(initialFetch).first)

            #expect(page.filePath == markdownURL.standardizedFileURL.path)
            #expect(page.loadBody() == "Current body")
            #expect(page.lastSyncedBodyHash == SDPage.bodyHash("Current body"))
            #expect(page.needsVaultSync == false)

            page.saveBody("Stale cached body")
            page.lastSyncedBodyHash = SDPage.bodyHash("Stale cached body")
            page.needsVaultSync = false
            try context.save()

            try """
            ---
            title: Instructions
            ---

            Refreshed body
            """.write(to: markdownURL, atomically: true, encoding: .utf8)

            let secondPageID = try #require(
                ModelVaultBrowserStore.ensureWorkspacePage(for: document, modelContext: context)
            )
            let allPages = try context.fetch(FetchDescriptor<SDPage>())

            #expect(secondPageID == firstPageID)
            #expect(allPages.count == 1)
            #expect(page.loadBody() == "Refreshed body")
            #expect(page.lastSyncedBodyHash == SDPage.bodyHash("Refreshed body"))
            #expect(page.needsVaultSync == false)
        }
    }

    @Test("notes sidebar keeps model vault-backed pages out of the primary notes tree")
    func notesSidebarKeepsModelVaultBackedPagesOutOfThePrimaryNotesTree() throws {
        let modelVaultRoot = try makeTempDirectory("model-vault-sidebar-filter")
        defer { try? FileManager.default.removeItem(at: modelVaultRoot) }

        let modelVaultPage = SDPage(title: "Instructions")
        modelVaultPage.filePath = modelVaultRoot
            .appendingPathComponent("gpt-5.4/instructions.md")
            .path

        let nativePage = SDPage(title: "Native Note")
        nativePage.filePath = "/tmp/My mind/native-note.md"

        let scratchPage = SDPage(title: "Scratch")

        #expect(
            !NotesSidebar.shouldDisplayInPrimaryTree(
                modelVaultPage,
                modelVaultRootURL: modelVaultRoot
            )
        )
        #expect(
            NotesSidebar.shouldDisplayInPrimaryTree(
                nativePage,
                modelVaultRootURL: modelVaultRoot
            )
        )
        #expect(
            NotesSidebar.shouldDisplayInPrimaryTree(
                scratchPage,
                modelVaultRootURL: modelVaultRoot
            )
        )
    }

    @Test("model vault markdown title sync keeps the curated filename stable")
    @MainActor
    func modelVaultMarkdownTitleSyncKeepsTheCuratedFilenameStable() throws {
        let container = try makePageContainer()
        let context = ModelContext(container)
        let page = SDPage(title: "instructions.md")
        page.filePath = ModelVaultsSidebarSection.modelVaultsRootURL()
            .appendingPathComponent("gpt-5.4/instructions.md")
            .path
        context.insert(page)
        try context.save()

        var renameRequest: (String, String)?
        let changed = ProseEditorView.syncNoteTitleIfNeeded(
            from: "# Instructions\n\nBody",
            for: page,
            modelContext: context
        ) { pageID, newTitle in
            renameRequest = (pageID, newTitle)
        }

        #expect(changed)
        #expect(page.title == "Instructions")
        #expect(renameRequest == nil)
    }

    @Test("model vault surfaces share one master storage root")
    func modelVaultSurfacesShareOneMasterStorageRoot() async throws {
        let root = ModelVaultsSidebarSection.modelVaultsRootURL()
        let store = KnowledgeProfileStore()
        let modelDirectory = await store.modelVaultDirectoryURL(for: "gpt-5.4")

        #expect(modelDirectory.deletingLastPathComponent().standardizedFileURL == root)
    }

    @Test("model vault sidebar keeps extra storage directories visible outside the curated model set")
    func modelVaultSidebarKeepsExtraStorageDirectoriesVisibleOutsideTheCuratedModelSet() throws {
        let root = try makeTempDirectory("model-vault-sidebar-partition")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("gpt-5.4", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("shared-scratch", isDirectory: true),
            withIntermediateDirectories: true
        )

        let entries = ModelVaultsSidebarSection.loadModelVaults(rootURL: root)
        let byDirectory = Dictionary(uniqueKeysWithValues: entries.map { ($0.directoryName, $0) })
        let compiledVault = try #require(byDirectory["gpt-5.4"])
        let extraStorage = try #require(byDirectory["shared-scratch"])

        let partition = ModelVaultsSidebarSection.partitionModelVaults(
            [compiledVault, extraStorage],
            visibleModelIDs: ["gpt-5.4"]
        )

        #expect(partition.visible == [compiledVault])
        #expect(partition.additional == [extraStorage])
    }

    @Test("deleting a model vault folder also removes its workspace-backed pages")
    @MainActor
    func deletingModelVaultFoldersRemovesWorkspacePages() throws {
        let storageRoot = try makeTempDirectory("model-vault-delete-storage")
        let root = try makeTempDirectory("model-vault-delete-pages")
        defer {
            try? FileManager.default.removeItem(at: storageRoot)
            try? FileManager.default.removeItem(at: root)
        }

        let folderURL = root.appendingPathComponent("contexts/swift", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let sourceURL = folderURL.appendingPathComponent("main.swift")
        try "print(\"hello\")\n".write(to: sourceURL, atomically: true, encoding: .utf8)

        try NoteFileStorage.withStorageDirectoryOverrideForTesting(storageRoot) {
            let container = try makePageContainer()
            let context = ModelContext(container)
            let document = try #require(
                ModelVaultBrowserStore.loadEntries(rootURL: root)
                    .first(where: { $0.relativePath == "contexts/swift/main.swift" })
            )
            let pageID = try #require(
                ModelVaultBrowserStore.ensureWorkspacePage(for: document, modelContext: context)
            )

            #expect(NoteFileStorage.bodyExists(pageId: pageID))

            let removedPageIDs = ModelVaultBrowserStore.removeWorkspacePages(
                backingDeletedItemAt: root.appendingPathComponent("contexts"),
                modelContext: context
            )
            let remainingPages = try context.fetch(FetchDescriptor<SDPage>())

            #expect(Set(removedPageIDs) == Set([pageID]))
            #expect(remainingPages.isEmpty)
            #expect(!NoteFileStorage.bodyExists(pageId: pageID))
        }
    }

    @Test("model vault workspace persistence exposes SwiftData failures")
    func modelVaultWorkspacePersistenceExposesSwiftDataFailures() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ModelVaultBrowserSheet.swift")

        #expect(!source.contains("if let existing = try? modelContext.fetch(descriptor).first"))
        #expect(!source.contains("let allPages = (try? modelContext.fetch(FetchDescriptor<SDPage>())) ?? []"))
        #expect(!source.contains("let insight = try? modelContext.fetch(insightDescriptor).first"))
        #expect(!source.contains("try? modelContext.save()"))
        #expect(source.contains("ModelVaultBrowserStore: failed to fetch workspace page"))
        #expect(source.contains("ModelVaultBrowserStore: failed to fetch workspace pages for deletion"))
        #expect(source.contains("ModelVaultBrowserStore: failed to persist refreshed workspace page"))
    }

    @Test("model involvement contribution fetches report failures instead of dropping history silently")
    func modelInvolvementContributionFetchesReportFailures() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ModelInvolvementSheet.swift")

        #expect(!source.contains("guard let fetched = try? modelContext.fetch(descriptor) else { continue }"))
        #expect(source.contains("ModelInvolvementContent: failed to fetch contributions"))
    }

    @Test("gpt_5_4_sidebar_shows_full_history")
    @MainActor
    func gpt_5_4_sidebar_shows_full_history() throws {
        let container = try makeChatContainer()
        let context = ModelContext(container)

        let chat = SDChat(title: "GPT-5.4 Contributions")
        context.insert(chat)

        let currentMessage = SDMessage(role: "assistant", content: "Current vendor id")
        currentMessage.chat = chat
        currentMessage.authoredByProviderID = "openai"
        currentMessage.authoredByModelID = "gpt-5.4"
        currentMessage.createdAt = Date(timeIntervalSince1970: 2)
        context.insert(currentMessage)

        let legacyMessage = SDMessage(role: "assistant", content: "Legacy raw id")
        legacyMessage.chat = chat
        legacyMessage.authoredByProviderID = "openai"
        legacyMessage.authoredByModelID = "openai:gpt-5.4"
        legacyMessage.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(legacyMessage)

        let unrelatedMessage = SDMessage(role: "assistant", content: "Other model")
        unrelatedMessage.chat = chat
        unrelatedMessage.authoredByProviderID = "anthropic"
        unrelatedMessage.authoredByModelID = "claude-opus-4-7"
        unrelatedMessage.createdAt = Date(timeIntervalSince1970: 3)
        context.insert(unrelatedMessage)

        try context.save()

        let contributions = ModelInvolvementContent.loadContributions(
            modelIDs: ModelVaultEntry.acceptedModelIDs(for: "gpt-5.4"),
            in: context
        )

        #expect(contributions.map(\.id) == [currentMessage.id, legacyMessage.id])
    }

    @Test("model involvement summarizes reasoning notes and structured work by session")
    @MainActor
    func modelInvolvementSummarizesReasoningNotesAndStructuredWorkBySession() throws {
        let container = try makeChatContainer()
        let context = ModelContext(container)

        let notesChat = SDChat(title: "Design Thread", chatType: "notes")
        notesChat.linkedPageId = "page-1"
        context.insert(notesChat)

        let reasonedMessage = SDMessage(role: "assistant", content: "Reasoned note answer")
        reasonedMessage.chat = notesChat
        reasonedMessage.authoredByProviderID = "openai"
        reasonedMessage.authoredByModelID = "gpt-5.4"
        reasonedMessage.createdAt = Date(timeIntervalSince1970: 3)
        reasonedMessage.thinkingTrace = "Thought trace"
        reasonedMessage.thinkingDurationSeconds = 7
        reasonedMessage.updatePresentationSnapshot(
            attachments: [
                FileAttachment(
                    id: "attachment-1",
                    name: "brief.md",
                    type: .text,
                    uri: "file:///brief.md",
                    size: 128,
                    mimeType: "text/markdown",
                    preview: "Brief"
                )
            ],
            loadedNoteTitles: ["Design Brief"],
            contextAttachments: [
                ContextAttachment(kind: .note, targetId: "page-1", title: "Design Brief")
            ]
        )
        context.insert(reasonedMessage)

        let workerChat = SDChat(title: "Automation Pass", chatType: "worker")
        context.insert(workerChat)

        let structuredMessage = SDMessage(role: "assistant", content: "Generated structured patch")
        structuredMessage.chat = workerChat
        structuredMessage.authoredByProviderID = "openai"
        structuredMessage.authoredByModelID = "openai:gpt-5.4"
        structuredMessage.createdAt = Date(timeIntervalSince1970: 2)
        structuredMessage.setArtifacts([
            Artifact(kind: .json, title: "Patch Plan", content: "{}")
        ])
        context.insert(structuredMessage)

        let followUpMessage = SDMessage(role: "assistant", content: "Follow-up answer")
        followUpMessage.chat = workerChat
        followUpMessage.authoredByProviderID = "openai"
        followUpMessage.authoredByModelID = "gpt-5.4"
        followUpMessage.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(followUpMessage)

        try context.save()

        let messages = ModelInvolvementContent.loadContributions(
            modelIDs: ModelVaultEntry.acceptedModelIDs(for: "gpt-5.4"),
            in: context
        )
        let contributions = ModelInvolvementContent.makeContributionRecords(from: messages)
        let summary = ModelInvolvementContent.summarize(contributions)
        let sessions = ModelInvolvementContent.groupedContributions(contributions)
        let structuredOnly = ModelInvolvementContent.groupedContributions(
            contributions,
            filter: .structured
        )

        #expect(summary.totalContributions == 3)
        #expect(summary.threadCount == 2)
        #expect(summary.reasoningCount == 1)
        #expect(summary.noteLinkedCount == 1)
        #expect(summary.structuredCount == 1)

        #expect(sessions.map(\.title) == ["Design Thread", "Automation Pass"])
        #expect(sessions[0].contributions.count == 1)
        #expect(sessions[0].contributions[0].hasThinkingTrace)
        #expect(sessions[0].contributions[0].isNoteLinked)
        #expect(sessions[1].contributions.map(\.id) == [structuredMessage.id, followUpMessage.id])
        #expect(sessions[1].contributions[0].artifactCount == 1)

        #expect(structuredOnly.map(\.title) == ["Automation Pass"])
        #expect(structuredOnly[0].contributions.map(\.id) == [structuredMessage.id])
    }

    @Test("model involvement tracks tool use separately from note work and outputs")
    @MainActor
    func modelInvolvementTracksToolUseSeparatelyFromNoteWorkAndOutputs() throws {
        let container = try makeChatContainer()
        let context = ModelContext(container)

        let workerChat = SDChat(title: "Agent Thread", chatType: "worker")
        context.insert(workerChat)

        let toolMessage = SDMessage(role: "assistant", content: "")
        toolMessage.chat = workerChat
        toolMessage.authoredByProviderID = "openai"
        toolMessage.authoredByModelID = "gpt-5.4"
        toolMessage.createdAt = Date(timeIntervalSince1970: 2)
        toolMessage.setContentBlocks([
            .toolUse(id: "tool-1", name: "write_file", input: [
                "path": .string("/tmp/output.md")
            ]),
            .toolResult(toolUseId: "tool-1", content: "Saved output.md", isError: false),
        ])
        context.insert(toolMessage)

        let outputMessage = SDMessage(role: "assistant", content: "Generated plan")
        outputMessage.chat = workerChat
        outputMessage.authoredByProviderID = "openai"
        outputMessage.authoredByModelID = "gpt-5.4"
        outputMessage.createdAt = Date(timeIntervalSince1970: 1)
        outputMessage.setArtifacts([
            Artifact(kind: .json, title: "Plan", content: "{}")
        ])
        context.insert(outputMessage)

        try context.save()

        let messages = ModelInvolvementContent.loadContributions(
            modelIDs: ModelVaultEntry.acceptedModelIDs(for: "gpt-5.4"),
            in: context
        )
        let contributions = ModelInvolvementContent.makeContributionRecords(from: messages)
        let summary = ModelInvolvementContent.summarize(contributions)
        let toolOnly = ModelInvolvementContent.groupedContributions(
            contributions,
            filter: .tools
        )

        #expect(summary.totalContributions == 2)
        #expect(summary.toolingCount == 1)
        #expect(summary.structuredCount == 1)

        let toolContribution = try #require(contributions.first { $0.hasTooling })
        #expect(toolContribution.preview == "Saved output.md")
        #expect(toolContribution.toolCallCount == 1)
        #expect(toolContribution.toolResultCount == 1)
        #expect(toolContribution.toolNames == ["write file"])
        #expect(!toolContribution.isStructured)

        #expect(toolOnly.map(\.title) == ["Agent Thread"])
        #expect(toolOnly[0].contributions.map(\.id) == [toolMessage.id])
    }
}
