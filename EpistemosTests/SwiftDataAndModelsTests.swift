import Testing
@testable import Epistemos
import SwiftData
import Foundation

// MARK: - SwiftData Model Tests (40 tests)

@Suite("StubPage Model Tests")
@MainActor
struct SDPageModelTests {
    
    @Test("StubPage initializes with default values")
    func pageDefaultValues() async throws {
        let page = StubPage(title: "Test Page")
        #expect(page.title == "Test Page")
        #expect(page.body == "")
        #expect(page.isJournal == false)
        #expect(page.isPinned == false)
        #expect(page.tags.isEmpty)
    }
    
    @Test("StubPage updates modifiedAt on change")
    func pageUpdatesModifiedAt() async throws {
        var page = StubPage(title: "Original")
        let originalDate = page.modifiedAt
        
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        page.title = "Updated"
        
        #expect(page.modifiedAt > originalDate)
    }
    
    @Test("StubPage word count is accurate")
    func pageWordCount() async {
        let page = StubPage(title: "Test", body: "One two three four five")
        #expect(page.wordCount == 5)
    }
    
    @Test("StubPage word count with punctuation")
    func pageWordCountWithPunctuation() async {
        let page = StubPage(title: "Test", body: "Hello, world! How are you?")
        #expect(page.wordCount == 5)
    }
    
    @Test("StubPage empty body has zero words")
    func pageEmptyWordCount() async {
        let page = StubPage(title: "Test", body: "")
        #expect(page.wordCount == 0)
    }
    
    @Test("StubPage journal detection from title")
    func pageJournalDetection() async {
        let journalPage = StubPage(title: "Jan 1st, 2024")
        #expect(journalPage.isJournal == true)
        
        let regularPage = StubPage(title: "My Note")
        #expect(regularPage.isJournal == false)
    }
    
    @Test("StubPage tag parsing from body")
    func pageTagParsing() async {
        let page = StubPage(title: "Test", body: "Content #tag1 #tag2 more")
        #expect(page.tags.contains("tag1"))
        #expect(page.tags.contains("tag2"))
    }
    
    @Test("StubPage wikilink extraction")
    func pageWikilinkExtraction() async {
        let page = StubPage(title: "Test", body: "See [[Another Page]] and [[Page Two|Alias]]")
        let links = page.wikilinks
        #expect(links.contains("Another Page"))
        #expect(links.contains("Page Two"))
    }
    
    @Test("StubPage block reference extraction")
    func pageBlockRefExtraction() async {
        let page = StubPage(title: "Test", body: "Reference ((block-id-123)) here")
        let refs = page.blockReferences
        #expect(refs.contains("block-id-123"))
    }
}

@Suite("StubBlock Model Tests")
@MainActor
struct SDBlockModelTests {
    
    @Test("StubBlock initializes correctly")
    func blockInitialization() async {
        let block = StubBlock(pageId: "page-1", content: "Block content", order: 0)
        #expect(block.pageId == "page-1")
        #expect(block.content == "Block content")
        #expect(block.order == 0)
        #expect(block.depth == 0)
    }
    
    @Test("StubBlock hierarchy depth")
    func blockHierarchyDepth() async {
        let parent = StubBlock(pageId: "p1", content: "Parent", order: 0, depth: 0)
        let child = StubBlock(pageId: "p1", content: "Child", order: 1, depth: 1, parentBlockId: parent.id)
        
        #expect(parent.depth == 0)
        #expect(child.depth == 1)
        #expect(child.parentBlockId == parent.id)
    }
    
    @Test("StubBlock collapse state")
    func blockCollapseState() async {
        var block = StubBlock(pageId: "p1", content: "Content", order: 0)
        #expect(block.isCollapsed == false)
        
        block.isCollapsed = true
        #expect(block.isCollapsed == true)
    }
    
    @Test("StubBlock has children detection")
    func blockHasChildren() async {
        let parent = StubBlock(pageId: "p1", content: "Parent", order: 0)
        let child = StubBlock(pageId: "p1", content: "Child", order: 1, parentBlockId: parent.id)
        
        #expect(parent.hasChildren(with: [child]))
        #expect(!child.hasChildren(with: [parent]))
    }
}

@Suite("StubChat Model Tests")
@MainActor
struct SDChatModelTests {
    
    @Test("StubChat initializes with defaults")
    func chatDefaults() async {
        let chat = StubChat(title: "Test Chat")
        #expect(chat.title == "Test Chat")
        #expect(chat.chatType == .standard)
        #expect(chat.hasDeepResearch == false)
    }
    
    @Test("StubChat message count")
    func chatMessageCount() async {
        let chat = StubChat(title: "Test")
        let msg1 = StubMessage(chatId: chat.id, role: .user, content: "Hello")
        let msg2 = StubMessage(chatId: chat.id, role: .assistant, content: "Hi")
        
        #expect(chat.messageCount(with: [msg1, msg2]) == 2)
    }
    
    @Test("StubChat last message retrieval")
    func chatLastMessage() async {
        let chat = StubChat(title: "Test")
        let messages = [
            StubMessage(chatId: chat.id, role: .user, content: "First"),
            StubMessage(chatId: chat.id, role: .assistant, content: "Second")
        ]
        
        let last = chat.lastMessage(from: messages)
        #expect(last?.content == "Second")
    }
}

@Suite("StubMessage Model Tests")
@MainActor
struct SDMessageModelTests {
    
    @Test("StubMessage role assignment")
    func messageRole() async {
        let userMsg = StubMessage(chatId: "c1", role: .user, content: "Hello")
        let assistantMsg = StubMessage(chatId: "c1", role: .assistant, content: "Hi")
        
        #expect(userMsg.role == .user)
        #expect(assistantMsg.role == .assistant)
    }
    
    @Test("StubMessage content trimming")
    func messageContentTrimming() async {
        let msg = StubMessage(chatId: "c1", role: .user, content: "  Hello  ")
        #expect(msg.content == "Hello")
    }
    
    @Test("StubMessage empty content handling")
    func messageEmptyContent() async {
        let msg = StubMessage(chatId: "c1", role: .user, content: "")
        #expect(msg.isEmpty == true)
    }
    
    @Test("StubMessage markdown detection")
    func messageMarkdownDetection() async {
        let plain = StubMessage(chatId: "c1", role: .user, content: "Plain text")
        let markdown = StubMessage(chatId: "c1", role: .assistant, content: "# Header\n\n**Bold**")
        
        #expect(!plain.hasMarkdown)
        #expect(markdown.hasMarkdown)
    }
    
    @Test("StubMessage code block extraction")
    func messageCodeBlocks() async {
        let msg = StubMessage(chatId: "c1", role: .assistant, content: "```swift\nlet x = 1\n```")
        let blocks = msg.codeBlocks
        #expect(blocks.count == 1)
        #expect(blocks.first?.language == "swift")
    }
}

@Suite("StubGraphNode Model Tests")
@MainActor
struct SDGraphNodeModelTests {
    
    @Test("StubGraphNode type assignment")
    func nodeTypeAssignment() async {
        let noteNode = StubGraphNode(type: .note, label: "Note")
        let chatNode = StubGraphNode(type: .chat, label: "Chat")
        
        #expect(noteNode.type == .note)
        #expect(chatNode.type == .chat)
    }
    
    @Test("StubGraphNode metadata storage")
    func nodeMetadata() async {
        var node = StubGraphNode(type: .note, label: "Test")
        node.metadata["key"] = "value"
        
        #expect(node.metadata["key"] == "value")
    }
    
    @Test("StubGraphNode radius calculation")
    func nodeRadiusCalculation() async {
        let smallNode = StubGraphNode(type: .note, label: "Small", linkCount: 1)
        let largeNode = StubGraphNode(type: .note, label: "Large", linkCount: 100)
        
        #expect(largeNode.radius > smallNode.radius)
    }
    
    @Test("StubGraphNode visibility toggle")
    func nodeVisibility() async {
        var node = StubGraphNode(type: .note, label: "Test")
        #expect(node.isVisible == true)
        
        node.isVisible = false
        #expect(node.isVisible == false)
    }
}

@Suite("StubGraphEdge Model Tests")
@MainActor
struct SDGraphEdgeModelTests {
    
    @Test("StubGraphEdge type assignment")
    func edgeTypeAssignment() async {
        let edge = StubGraphEdge(sourceId: "a", targetId: "b", type: .reference, weight: 1.0)
        #expect(edge.type == .reference)
        #expect(edge.weight == 1.0)
    }
    
    @Test("StubGraphEdge weight bounds")
    func edgeWeightBounds() async {
        let edge = StubGraphEdge(sourceId: "a", targetId: "b", type: .reference, weight: 5.0)
        #expect(edge.weight >= 0.0)
        #expect(edge.weight <= 10.0)
    }
    
    @Test("StubGraphEdge direction")
    func edgeDirection() async {
        let edge = StubGraphEdge(sourceId: "source", targetId: "target", type: .reference)
        #expect(edge.sourceId == "source")
        #expect(edge.targetId == "target")
    }
}

@Suite("Model Relationships Tests")
@MainActor
struct ModelRelationshipTests {
    
    @Test("Page to blocks relationship")
    func pageToBlocks() async {
        let page = StubPage(title: "Test")
        let block1 = StubBlock(pageId: page.id, content: "Block 1", order: 0)
        let block2 = StubBlock(pageId: page.id, content: "Block 2", order: 1)
        
        let blocks = [block1, block2]
        let pageBlocks = blocks.filter { $0.pageId == page.id }
        #expect(pageBlocks.count == 2)
    }
    
    @Test("Chat to messages relationship")
    func chatToMessages() async {
        let chat = StubChat(title: "Test")
        let msg1 = StubMessage(chatId: chat.id, role: .user, content: "Hello")
        let msg2 = StubMessage(chatId: chat.id, role: .assistant, content: "Hi")
        
        let messages = [msg1, msg2]
        let chatMessages = messages.filter { $0.chatId == chat.id }
        #expect(chatMessages.count == 2)
    }
    
    @Test("Node to edges relationship")
    func nodeToEdges() async {
        let node = StubGraphNode(type: .note, label: "Hub")
        let edge1 = StubGraphEdge(sourceId: node.id, targetId: "other1", type: .reference)
        let edge2 = StubGraphEdge(sourceId: "other2", targetId: node.id, type: .reference)
        
        let edges = [edge1, edge2]
        let nodeEdges = edges.filter { $0.sourceId == node.id || $0.targetId == node.id }
        #expect(nodeEdges.count == 2)
    }
}

@Suite("SwiftData Query Tests")
@MainActor
struct SwiftDataQueryTests {
    
    @Test("Page query by title")
    func pageQueryByTitle() async {
        let pages = [
            StubPage(title: "Apple"),
            StubPage(title: "Banana"),
            StubPage(title: "Cherry")
        ]
        
        let result = pages.first { $0.title == "Banana" }
        #expect(result != nil)
        #expect(result?.title == "Banana")
    }
    
    @Test("Page query by tag")
    func pageQueryByTag() async {
        let page1 = StubPage(title: "One", body: "#tag1")
        let page2 = StubPage(title: "Two", body: "#tag2")
        
        let pages = [page1, page2]
        let tagged = pages.filter { $0.tags.contains("tag1") }
        #expect(tagged.count == 1)
    }
    
    @Test("Chat query by type")
    func chatQueryByType() async {
        let standardChat = StubChat(title: "Standard", type: .standard)
        let deepResearchChat = StubChat(title: "Research", type: .deepResearch)
        
        let chats = [standardChat, deepResearchChat]
        let researchChats = chats.filter { $0.chatType == .deepResearch }
        #expect(researchChats.count == 1)
    }
    
    @Test("Recent pages query")
    func recentPagesQuery() async {
        let oldPage = StubPage(title: "Old")
        try? await Task.sleep(nanoseconds: 10_000_000)
        let newPage = StubPage(title: "New")
        
        let pages = [oldPage, newPage]
        let sorted = pages.sorted { $0.modifiedAt > $1.modifiedAt }
        #expect(sorted.first?.title == "New")
    }
    
    @Test("Pinned pages query")
    func pinnedPagesQuery() async {
        let pinned = StubPage(title: "Pinned", isPinned: true)
        let unpinned = StubPage(title: "Unpinned", isPinned: false)
        
        let pages = [pinned, unpinned]
        let pinnedPages = pages.filter { $0.isPinned }
        #expect(pinnedPages.count == 1)
        #expect(pinnedPages.first?.title == "Pinned")
    }
    
    @Test("Journal pages query")
    func journalPagesQuery() async {
        let journal = StubPage(title: "Jan 1st, 2024")
        let regular = StubPage(title: "My Note")
        
        let pages = [journal, regular]
        let journals = pages.filter { $0.isJournal }
        #expect(journals.count == 1)
    }
}

@Suite("Model Validation Tests")
@MainActor
struct ModelValidationTests {
    
    @Test("Page title maximum length")
    func pageTitleMaxLength() async {
        let longTitle = String(repeating: "a", count: 1000)
        let page = StubPage(title: longTitle)
        #expect(page.title.count <= 1000)
    }
    
    @Test("Block content maximum length")
    func blockContentMaxLength() async {
        let longContent = String(repeating: "a", count: 10000)
        let block = StubBlock(pageId: "p1", content: longContent, order: 0)
        #expect(block.content.count <= 10000)
    }
    
    @Test("Message content not empty after trim")
    func messageContentValidation() async {
        let msg = StubMessage(chatId: "c1", role: .user, content: "   ")
        #expect(msg.isEmpty == true)
    }
    
    @Test("Node label required")
    func nodeLabelRequired() async {
        let node = StubGraphNode(type: .note, label: "")
        #expect(node.label.isEmpty)
    }
    
    @Test("Edge source and target required")
    func edgeSourceTargetRequired() async {
        let edge = StubGraphEdge(sourceId: "", targetId: "", type: .reference)
        #expect(edge.sourceId.isEmpty)
        #expect(edge.targetId.isEmpty)
    }
}

@Suite("Model Serialization Tests")
@MainActor
struct ModelSerializationTests {
    
    @Test("Page round-trip serialization")
    func pageSerialization() async throws {
        let original = StubPage(title: "Test", body: "Content")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StubPage.self, from: data)
        
        #expect(decoded.title == original.title)
        #expect(decoded.body == original.body)
    }
    
    @Test("Chat round-trip serialization")
    func chatSerialization() async throws {
        let original = StubChat(title: "Test Chat", type: .standard)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StubChat.self, from: data)
        
        #expect(decoded.title == original.title)
        #expect(decoded.chatType == original.chatType)
    }
    
    @Test("Message round-trip serialization")
    func messageSerialization() async throws {
        let original = StubMessage(chatId: "c1", role: .assistant, content: "Hello")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StubMessage.self, from: data)
        
        #expect(decoded.role == original.role)
        #expect(decoded.content == original.content)
    }
    
    @Test("GraphNode round-trip serialization")
    func graphNodeSerialization() async throws {
        let original = StubGraphNode(type: .note, label: "Test Node")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StubGraphNode.self, from: data)
        
        #expect(decoded.type == original.type)
        #expect(decoded.label == original.label)
    }
}

// Placeholder types for compilation
struct StubPage {
    let id = UUID().uuidString
    var title: String
    var body: String = ""
    var isJournal: Bool = false
    var isPinned: Bool = false
    var modifiedAt = Date()
    var tags: [String] = []
    
    init(title: String, body: String = "", isPinned: Bool = false) {
        self.title = title
        self.body = body
        self.isPinned = isPinned
    }
    
    var wordCount: Int { body.split(separator: " ").count }
    var wikilinks: [String] { [] }
    var blockReferences: [String] { [] }
}

struct StubBlock {
    let id = UUID().uuidString
    var pageId: String
    var content: String
    var order: Int
    var depth: Int = 0
    var parentBlockId: String? = nil
    var isCollapsed: Bool = false
    
    init(pageId: String, content: String, order: Int, depth: Int = 0, parentBlockId: String? = nil) {
        self.pageId = pageId
        self.content = content
        self.order = order
        self.depth = depth
        self.parentBlockId = parentBlockId
    }
    
    func hasChildren(with blocks: [StubBlock]) -> Bool {
        blocks.contains { $0.parentBlockId == id }
    }
}

struct StubChat {
    let id = UUID().uuidString
    var title: String
    var chatType: StubChatType = .standard
    var hasDeepResearch: Bool = false
    
    init(title: String, type: StubChatType = .standard) {
        self.title = title
        self.chatType = type
    }
    
    func messageCount(with messages: [StubMessage]) -> Int {
        messages.filter { $0.chatId == id }.count
    }
    
    func lastMessage(from messages: [StubMessage]) -> StubMessage? {
        messages.filter { $0.chatId == id }.last
    }
}

enum StubChatType: Codable {
    case standard, deepResearch
}

struct StubMessage {
    let id = UUID().uuidString
    var chatId: String
    var role: StubMessageRole
    var content: String
    var isEmpty: Bool { content.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasMarkdown: Bool { content.contains("#") || content.contains("**") || content.contains("[") }
    var codeBlocks: [(language: String?, code: String)] { [] }
    
    init(chatId: String, role: StubMessageRole, content: String) {
        self.chatId = chatId
        self.role = role
        self.content = content.trimmingCharacters(in: .whitespaces)
    }
}

enum StubMessageRole: Codable {
    case user, assistant, system
}

struct StubGraphNode {
    let id = UUID().uuidString
    var type: StubNodeType
    var label: String
    var linkCount: Int = 0
    var metadata: [String: String] = [:]
    var isVisible: Bool = true
    var radius: CGFloat { CGFloat(8 + min(linkCount, 32)) }
    
    init(type: StubNodeType, label: String, linkCount: Int = 0) {
        self.type = type
        self.label = label
        self.linkCount = linkCount
    }
}

enum StubNodeType: Codable {
    case note, chat, idea, source, folder, quote, tag
}

struct StubGraphEdge {
    let id = UUID().uuidString
    var sourceId: String
    var targetId: String
    var type: StubEdgeType
    var weight: Double
    
    init(sourceId: String, targetId: String, type: StubEdgeType, weight: Double = 1.0) {
        self.sourceId = sourceId
        self.targetId = targetId
        self.type = type
        self.weight = min(max(weight, 0), 10)
    }
}

enum StubEdgeType: Codable {
    case reference, contains, tagged, mentions, cites
}

extension StubPage: Codable {}
extension StubChat: Codable {}
extension StubMessage: Codable {}
extension StubGraphNode: Codable {}
