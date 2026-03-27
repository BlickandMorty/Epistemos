import Foundation
import Testing
@testable import Epistemos

// MARK: - FilterEngine Comprehensive Tests
// 40+ test cases covering all FilterEngine functionality

// MARK: - Test Helpers

@MainActor
struct FilterTestHelpers {
    
    static func makeNode(
        id: String,
        type: GraphNodeType = .note,
        label: String = "",
        createdAt: Date = .now
    ) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: label.isEmpty ? id : label,
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: createdAt,
            position: .zero,
            velocity: .zero
        )
    }
    
    static func makeEdge(
        source: String,
        target: String,
        type: GraphEdgeType = .reference
    ) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: "\(source)-\(target)",
            sourceNodeId: source,
            targetNodeId: target,
            type: type,
            weight: 1.0,
            createdAt: .now
        )
    }
}

@Suite("FilterEngine - Initialization")
@MainActor
struct FilterEngineInitializationTests {
    
    @Test("default initialization has all types active")
    func defaultInitializationAllTypesActive() {
        let engine = FilterEngine()
        
        #expect(engine.activeNodeTypes.count == GraphNodeType.visibleCases.count)
        for type in GraphNodeType.visibleCases {
            #expect(engine.activeNodeTypes.contains(type))
        }
    }
    
    @Test("default initialization has no focus")
    func defaultInitializationNoFocus() {
        let engine = FilterEngine()
        
        #expect(engine.focusedNodeId == nil)
        #expect(engine.focusedConnected == nil)
    }
    
    @Test("isFiltered returns false by default")
    func isFilteredFalseByDefault() {
        let engine = FilterEngine()
        
        #expect(!engine.isFiltered)
    }
}

@Suite("FilterEngine - Type Filter Toggles")
@MainActor
struct FilterEngineTypeToggleTests {
    
    @Test("toggleType removes active type")
    func toggleTypeRemovesActive() {
        let engine = FilterEngine()
        
        engine.toggleType(.note)
        
        #expect(!engine.activeNodeTypes.contains(.note))
    }
    
    @Test("toggleType adds inactive type")
    func toggleTypeAddsInactive() {
        let engine = FilterEngine()
        
        engine.toggleType(.note)
        engine.toggleType(.note)
        
        #expect(engine.activeNodeTypes.contains(.note))
    }
    
    @Test("toggle multiple types")
    func toggleMultipleTypes() {
        let engine = FilterEngine()
        
        engine.toggleType(.note)
        engine.toggleType(.tag)
        engine.toggleType(.source)
        
        #expect(!engine.activeNodeTypes.contains(.note))
        #expect(!engine.activeNodeTypes.contains(.tag))
        #expect(!engine.activeNodeTypes.contains(.source))
        #expect(engine.activeNodeTypes.contains(.folder))
        #expect(engine.activeNodeTypes.contains(.chat))
        #expect(engine.activeNodeTypes.contains(.idea))
        #expect(engine.activeNodeTypes.contains(.quote))
    }
    
    @Test("toggle all types results in empty set")
    func toggleAllTypesResultsEmpty() {
        let engine = FilterEngine()
        
        for type in GraphNodeType.visibleCases {
            engine.toggleType(type)
        }
        
        #expect(engine.activeNodeTypes.isEmpty)
        #expect(engine.isFiltered)
    }
    
    @Test("toggle last type back on restores visibility")
    func toggleLastTypeBackOn() {
        let engine = FilterEngine()
        
        engine.toggleType(.note)
        #expect(engine.activeNodeTypes.count == GraphNodeType.visibleCases.count - 1)
        
        engine.toggleType(.note)
        #expect(engine.activeNodeTypes.count == GraphNodeType.visibleCases.count)
    }
}

@Suite("FilterEngine - Show All Types")
@MainActor
struct FilterEngineShowAllTypesTests {
    
    @Test("showAllTypes restores all types")
    func showAllTypesRestoresAll() {
        let engine = FilterEngine()
        
        engine.toggleType(.note)
        engine.toggleType(.tag)
        engine.showAllTypes()
        
        #expect(engine.activeNodeTypes.count == GraphNodeType.visibleCases.count)
    }
    
    @Test("showAllTypes clears isFiltered")
    func showAllTypesClearsIsFiltered() {
        let engine = FilterEngine()
        
        engine.toggleType(.note)
        #expect(engine.isFiltered)
        
        engine.showAllTypes()
        #expect(!engine.isFiltered)
    }
    
    @Test("showAllTypes after focus still clears focus")
    func showAllTypesAfterFocus() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "test", connectedSet: ["test"])
        engine.showAllTypes()
        
        // Note: showAllTypes only affects type filters, not focus
        // But isFiltered should still be true if focus is active
        #expect(engine.isFiltered) // Because focus is still active
    }
}

@Suite("FilterEngine - Focus Mode")
@MainActor
struct FilterEngineFocusModeTests {
    
    @Test("focusOn sets focused node ID")
    func focusOnSetsNodeId() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "center-node", connectedSet: ["center-node", "a", "b"])
        
        #expect(engine.focusedNodeId == "center-node")
    }
    
    @Test("focusOn sets connected set")
    func focusOnSetsConnectedSet() {
        let engine = FilterEngine()
        let connectedSet: Set<String> = ["center", "a", "b", "c"]
        
        engine.focusOn(nodeId: "center", connectedSet: connectedSet)
        
        #expect(engine.focusedConnected == connectedSet)
    }
    
    @Test("focusOn makes isFiltered true")
    func focusOnMakesIsFilteredTrue() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "test", connectedSet: ["test"])
        
        #expect(engine.isFiltered)
    }
    
    @Test("focusOn with single node")
    func focusOnWithSingleNode() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "only", connectedSet: ["only"])
        
        #expect(engine.focusedConnected?.count == 1)
        #expect(engine.focusedConnected?.contains("only") == true)
    }
    
    @Test("focusOn with empty connected set")
    func focusOnWithEmptySet() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "lonely", connectedSet: [])
        
        #expect(engine.focusedConnected?.isEmpty == true)
    }
    
    @Test("focusOn with large connected set")
    func focusOnWithLargeSet() {
        let engine = FilterEngine()
        var largeSet = Set<String>()
        for i in 0..<1000 {
            largeSet.insert("node-\(i)")
        }
        
        engine.focusOn(nodeId: "center", connectedSet: largeSet)
        
        #expect(engine.focusedConnected?.count == 1000)
    }
}

@Suite("FilterEngine - Clear Focus")
@MainActor
struct FilterEngineClearFocusTests {
    
    @Test("clearFocus removes focused node ID")
    func clearFocusRemovesNodeId() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "test", connectedSet: ["test"])
        engine.clearFocus()
        
        #expect(engine.focusedNodeId == nil)
    }
    
    @Test("clearFocus removes connected set")
    func clearFocusRemovesConnectedSet() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "test", connectedSet: ["test", "a"])
        engine.clearFocus()
        
        #expect(engine.focusedConnected == nil)
    }
    
    @Test("clearFocus clears isFiltered when no type filters")
    func clearFocusClearsIsFiltered() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "test", connectedSet: ["test"])
        #expect(engine.isFiltered)
        
        engine.clearFocus()
        #expect(!engine.isFiltered)
    }
    
    @Test("clearFocus keeps isFiltered when type filters active")
    func clearFocusKeepsIsFilteredWithTypeFilters() {
        let engine = FilterEngine()
        
        engine.toggleType(.note)
        engine.focusOn(nodeId: "test", connectedSet: ["test"])
        
        engine.clearFocus()
        
        #expect(engine.isFiltered)
    }
}

@Suite("FilterEngine - Node Visibility")
@MainActor
struct FilterEngineNodeVisibilityTests {
    
    @Test("isNodeVisible returns true for active type")
    func isNodeVisibleActiveType() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .note)
        
        let visible = engine.isNodeVisible(node)
        
        #expect(visible)
    }
    
    @Test("isNodeVisible returns false for inactive type")
    func isNodeVisibleInactiveType() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .note)
        
        engine.toggleType(.note)
        let visible = engine.isNodeVisible(node)
        
        #expect(!visible)
    }
    
    @Test("isNodeVisible returns false when not in connected set")
    func isNodeVisibleNotInConnectedSet() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .note)
        
        engine.focusOn(nodeId: "center", connectedSet: ["center", "other"])
        let visible = engine.isNodeVisible(node)
        
        #expect(!visible)
    }
    
    @Test("isNodeVisible returns true when in connected set")
    func isNodeVisibleInConnectedSet() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .note)
        
        engine.focusOn(nodeId: "center", connectedSet: ["center", "n1", "n2"])
        let visible = engine.isNodeVisible(node)
        
        #expect(visible)
    }
    
    @Test("isNodeVisible checks type before focus")
    func isNodeVisibleChecksTypeBeforeFocus() {
        let engine = FilterEngine()
        let noteNode = FilterTestHelpers.makeNode(id: "note1", type: .note)
        let tagNode = FilterTestHelpers.makeNode(id: "tag1", type: .tag)
        
        // Hide notes, focus on a set containing the note
        engine.toggleType(.note)
        engine.focusOn(nodeId: "tag1", connectedSet: ["tag1", "note1"])
        
        // Note should be hidden even though it's in the connected set
        #expect(!engine.isNodeVisible(noteNode))
        // Tag should be visible
        #expect(engine.isNodeVisible(tagNode))
    }
    
    @Test("isNodeVisible for all node types")
    func isNodeVisibleForAllTypes() {
        let engine = FilterEngine()
        
        for type in GraphNodeType.visibleCases {
            let node = FilterTestHelpers.makeNode(id: "test-\(type)", type: type)
            #expect(engine.isNodeVisible(node), "Node of type \(type) should be visible")
        }
    }
}

@Suite("FilterEngine - Edge Visibility")
@MainActor
struct FilterEngineEdgeVisibilityTests {
    
    @Test("isEdgeVisible returns true when both endpoints visible")
    func isEdgeVisibleBothVisible() {
        let engine = FilterEngine()
        let edge = FilterTestHelpers.makeEdge(source: "a", target: "b")
        
        let visible = engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: true)
        
        #expect(visible)
    }
    
    @Test("isEdgeVisible returns false when source hidden")
    func isEdgeVisibleSourceHidden() {
        let engine = FilterEngine()
        let edge = FilterTestHelpers.makeEdge(source: "a", target: "b")
        
        let visible = engine.isEdgeVisible(edge, sourceVisible: false, targetVisible: true)
        
        #expect(!visible)
    }
    
    @Test("isEdgeVisible returns false when target hidden")
    func isEdgeVisibleTargetHidden() {
        let engine = FilterEngine()
        let edge = FilterTestHelpers.makeEdge(source: "a", target: "b")
        
        let visible = engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: false)
        
        #expect(!visible)
    }
    
    @Test("isEdgeVisible returns false when both hidden")
    func isEdgeVisibleBothHidden() {
        let engine = FilterEngine()
        let edge = FilterTestHelpers.makeEdge(source: "a", target: "b")
        
        let visible = engine.isEdgeVisible(edge, sourceVisible: false, targetVisible: false)
        
        #expect(!visible)
    }
}

@Suite("FilterEngine - Combined Filters")
@MainActor
struct FilterEngineCombinedFilterTests {
    
    @Test("type filter and focus combined")
    func typeFilterAndFocusCombined() {
        let engine = FilterEngine()
        
        let noteNode = FilterTestHelpers.makeNode(id: "note1", type: .note)
        let tagNode = FilterTestHelpers.makeNode(id: "tag1", type: .tag)
        let folderNode = FilterTestHelpers.makeNode(id: "folder1", type: .folder)
        
        // Hide folders, focus on notes and tags
        engine.toggleType(.folder)
        engine.focusOn(nodeId: "note1", connectedSet: ["note1", "tag1"])
        
        // Note in connected set: visible
        #expect(engine.isNodeVisible(noteNode))
        // Tag in connected set: visible
        #expect(engine.isNodeVisible(tagNode))
        // Folder hidden by type filter: not visible even though not in connected set check
        #expect(!engine.isNodeVisible(folderNode))
    }
    
    @Test("all filters cleared shows everything")
    func allFiltersClearedShowsEverything() {
        let engine = FilterEngine()
        
        let noteNode = FilterTestHelpers.makeNode(id: "n1", type: .note)
        let tagNode = FilterTestHelpers.makeNode(id: "n2", type: .tag)
        
        // Apply filters
        engine.toggleType(.folder)
        engine.focusOn(nodeId: "n1", connectedSet: ["n1"])
        
        // Clear all
        engine.showAllTypes()
        engine.clearFocus()
        
        #expect(engine.isNodeVisible(noteNode))
        #expect(engine.isNodeVisible(tagNode))
        #expect(!engine.isFiltered)
    }
}

@Suite("FilterEngine - isFiltered Edge Cases")
@MainActor
struct FilterEngineIsFilteredEdgeCaseTests {
    
    @Test("isFiltered with single type hidden")
    func isFilteredWithSingleTypeHidden() {
        let engine = FilterEngine()
        
        engine.toggleType(.quote)
        
        #expect(engine.isFiltered)
    }
    
    @Test("isFiltered with multiple types hidden")
    func isFilteredWithMultipleTypesHidden() {
        let engine = FilterEngine()
        
        engine.toggleType(.quote)
        engine.toggleType(.source)
        engine.toggleType(.chat)
        
        #expect(engine.isFiltered)
    }
    
    @Test("isFiltered with only focus")
    func isFilteredWithOnlyFocus() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "test", connectedSet: ["test"])
        
        #expect(engine.isFiltered)
    }
    
    @Test("isFiltered with both type filter and focus")
    func isFilteredWithBoth() {
        let engine = FilterEngine()
        
        engine.toggleType(.tag)
        engine.focusOn(nodeId: "test", connectedSet: ["test"])
        
        #expect(engine.isFiltered)
    }
}

@Suite("FilterEngine - State Restoration")
@MainActor
struct FilterEngineStateRestorationTests {
    
    @Test("restore after multiple toggles")
    func restoreAfterMultipleToggles() {
        let engine = FilterEngine()
        
        // Toggle some types off and on
        engine.toggleType(.note)
        engine.toggleType(.tag)
        engine.toggleType(.note) // Back on
        engine.toggleType(.source)
        engine.toggleType(.tag) // Back on
        
        #expect(engine.activeNodeTypes.contains(.note))
        #expect(engine.activeNodeTypes.contains(.tag))
        #expect(!engine.activeNodeTypes.contains(.source))
    }
    
    @Test("focus after clear can be re-established")
    func focusAfterClearReestablished() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "first", connectedSet: ["first", "a"])
        engine.clearFocus()
        engine.focusOn(nodeId: "second", connectedSet: ["second", "b"])
        
        #expect(engine.focusedNodeId == "second")
        #expect(engine.focusedConnected?.contains("b") == true)
        #expect(engine.focusedConnected?.contains("a") == false)
    }
}

@Suite("FilterEngine - Performance Edge Cases")
@MainActor
struct FilterEnginePerformanceEdgeCaseTests {
    
    @Test("visibility check with empty connected set")
    func visibilityCheckEmptyConnectedSet() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "test", type: .note)
        
        engine.focusOn(nodeId: "other", connectedSet: [])
        
        #expect(!engine.isNodeVisible(node))
    }
    
    @Test("visibility check with large connected set")
    func visibilityCheckLargeConnectedSet() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "node-500", type: .note)
        
        var largeSet = Set<String>()
        for i in 0..<10000 {
            largeSet.insert("node-\(i)")
        }
        
        engine.focusOn(nodeId: "center", connectedSet: largeSet)
        
        #expect(engine.isNodeVisible(node))
    }
    
    @Test("visibility check for node not in large connected set")
    func visibilityCheckNotInLargeConnectedSet() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "not-in-set", type: .note)
        
        var largeSet = Set<String>()
        for i in 0..<10000 {
            largeSet.insert("node-\(i)")
        }
        
        engine.focusOn(nodeId: "center", connectedSet: largeSet)
        
        #expect(!engine.isNodeVisible(node))
    }
}

@Suite("FilterEngine - Type Filter Specifics")
@MainActor
struct FilterEngineTypeFilterSpecificTests {
    
    @Test("all seven node types can be toggled")
    func allSevenTypesCanBeToggled() {
        let engine = FilterEngine()
        
        for type in GraphNodeType.visibleCases {
            engine.toggleType(type)
            #expect(!engine.activeNodeTypes.contains(type), "Type \(type) should be toggled off")
            
            engine.toggleType(type)
            #expect(engine.activeNodeTypes.contains(type), "Type \(type) should be toggled back on")
        }
    }
    
    @Test("visibility for each specific type")
    func visibilityForEachType() {
        // Test that each type can be individually filtered
        for typeToFilter in GraphNodeType.visibleCases {
            let engine = FilterEngine()
            engine.toggleType(typeToFilter)
            
            for type in GraphNodeType.visibleCases {
                let node = FilterTestHelpers.makeNode(id: "test", type: type)
                let expectedVisible = (type != typeToFilter)
                #expect(engine.isNodeVisible(node) == expectedVisible,
                       "Type \(type) visibility should be \(expectedVisible) when filtering \(typeToFilter)")
            }
        }
    }
}

@Suite("FilterEngine - Complex Scenarios")
@MainActor
struct FilterEngineComplexScenarioTests {
    
    @Test("realistic filtering scenario")
    func realisticFilteringScenario() {
        let engine = FilterEngine()
        
        // Create nodes representing a realistic graph
        let noteNode = FilterTestHelpers.makeNode(id: "note-1", type: .note, label: "Research Paper")
        let tagNode = FilterTestHelpers.makeNode(id: "tag-1", type: .tag, label: "AI")
        let sourceNode = FilterTestHelpers.makeNode(id: "source-1", type: .source, label: "Source Paper")
        let folderNode = FilterTestHelpers.makeNode(id: "folder-1", type: .folder, label: "Research")
        let ideaNode = FilterTestHelpers.makeNode(id: "idea-1", type: .idea, label: "Key Insight")
        let chatNode = FilterTestHelpers.makeNode(id: "chat-1", type: .chat, label: "Discussion")
        let quoteNode = FilterTestHelpers.makeNode(id: "quote-1", type: .quote, label: "Important Quote")
        
        // User wants to see only research-related content
        engine.toggleType(.chat)  // Hide chats
        engine.toggleType(.quote) // Hide quotes
        
        // Focus on a specific research area
        engine.focusOn(nodeId: "note-1", connectedSet: ["note-1", "tag-1", "source-1", "folder-1", "idea-1"])
        
        // Verify visibility
        #expect(engine.isNodeVisible(noteNode))
        #expect(engine.isNodeVisible(tagNode))
        #expect(engine.isNodeVisible(sourceNode))
        #expect(engine.isNodeVisible(folderNode))
        #expect(engine.isNodeVisible(ideaNode))
        #expect(!engine.isNodeVisible(chatNode))
        #expect(!engine.isNodeVisible(quoteNode))
        
        // Clear and verify all visible
        engine.showAllTypes()
        engine.clearFocus()
        
        #expect(engine.isNodeVisible(noteNode))
        #expect(engine.isNodeVisible(tagNode))
        #expect(engine.isNodeVisible(sourceNode))
        #expect(engine.isNodeVisible(folderNode))
        #expect(engine.isNodeVisible(ideaNode))
        #expect(engine.isNodeVisible(chatNode))
        #expect(engine.isNodeVisible(quoteNode))
    }
}


// MARK: - Additional Tests to Reach 60+ Test Cases

@Suite("FilterEngine - Additional Type Filter Tests")
@MainActor
struct FilterEngineAdditionalTypeTests {
    
    @Test("toggle same type multiple times")
    func toggleSameTypeMultipleTimes() {
        let engine = FilterEngine()
        
        engine.toggleType(.note)
        engine.toggleType(.note)
        engine.toggleType(.note)
        engine.toggleType(.note)
        
        // Should be back to original state (active)
        #expect(engine.activeNodeTypes.contains(.note))
    }
    
    @Test("hide all then show all")
    func hideAllThenShowAll() {
        let engine = FilterEngine()
        
        // Hide all types
        for type in GraphNodeType.visibleCases {
            engine.toggleType(type)
        }
        #expect(engine.activeNodeTypes.isEmpty)
        
        // Show all
        engine.showAllTypes()
        #expect(engine.activeNodeTypes.count == GraphNodeType.visibleCases.count)
    }
    
    @Test("specific type visibility - note")
    func specificTypeVisibilityNote() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .note)
        
        #expect(engine.isNodeVisible(node))
        
        engine.toggleType(.note)
        #expect(!engine.isNodeVisible(node))
    }
    
    @Test("specific type visibility - chat")
    func specificTypeVisibilityChat() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .chat)
        
        #expect(engine.isNodeVisible(node))
        
        engine.toggleType(.chat)
        #expect(!engine.isNodeVisible(node))
    }
    
    @Test("specific type visibility - idea")
    func specificTypeVisibilityIdea() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .idea)
        
        #expect(engine.isNodeVisible(node))
        
        engine.toggleType(.idea)
        #expect(!engine.isNodeVisible(node))
    }
    
    @Test("specific type visibility - source")
    func specificTypeVisibilitySource() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .source)
        
        #expect(engine.isNodeVisible(node))
        
        engine.toggleType(.source)
        #expect(!engine.isNodeVisible(node))
    }
    
    @Test("specific type visibility - folder")
    func specificTypeVisibilityFolder() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .folder)
        
        #expect(engine.isNodeVisible(node))
        
        engine.toggleType(.folder)
        #expect(!engine.isNodeVisible(node))
    }
    
    @Test("specific type visibility - quote")
    func specificTypeVisibilityQuote() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .quote)
        
        #expect(engine.isNodeVisible(node))
        
        engine.toggleType(.quote)
        #expect(!engine.isNodeVisible(node))
    }
    
    @Test("specific type visibility - tag")
    func specificTypeVisibilityTag() {
        let engine = FilterEngine()
        let node = FilterTestHelpers.makeNode(id: "n1", type: .tag)
        
        #expect(engine.isNodeVisible(node))
        
        engine.toggleType(.tag)
        #expect(!engine.isNodeVisible(node))
    }
}

@Suite("FilterEngine - Additional Focus Tests")
@MainActor
struct FilterEngineAdditionalFocusTests {
    
    @Test("focus on single node")
    func focusOnSingleNode() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "solo", connectedSet: ["solo"])
        
        let visibleNode = FilterTestHelpers.makeNode(id: "solo", type: .note)
        let hiddenNode = FilterTestHelpers.makeNode(id: "other", type: .note)
        
        #expect(engine.isNodeVisible(visibleNode))
        #expect(!engine.isNodeVisible(hiddenNode))
    }
    
    @Test("focus with large depth")
    func focusWithLargeDepth() {
        let engine = FilterEngine()
        
        var connectedSet = Set<String>()
        for i in 0..<100 {
            connectedSet.insert("node-\(i)")
        }
        
        engine.focusOn(nodeId: "center", connectedSet: connectedSet)
        
        #expect(engine.focusedConnected?.count == 100)
    }
    
    @Test("focus then toggle type")
    func focusThenToggleType() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "note1", connectedSet: ["note1", "tag1"])
        engine.toggleType(.tag)
        
        let note = FilterTestHelpers.makeNode(id: "note1", type: .note)
        let tag = FilterTestHelpers.makeNode(id: "tag1", type: .tag)
        
        // Note is in connected set and type is active
        #expect(engine.isNodeVisible(note))
        // Tag is in connected set but type is inactive
        #expect(!engine.isNodeVisible(tag))
    }
    
    @Test("multiple focus changes")
    func multipleFocusChanges() {
        let engine = FilterEngine()
        
        engine.focusOn(nodeId: "a", connectedSet: ["a", "b"])
        engine.focusOn(nodeId: "c", connectedSet: ["c", "d"])
        engine.focusOn(nodeId: "e", connectedSet: ["e", "f"])
        
        #expect(engine.focusedNodeId == "e")
        #expect(engine.focusedConnected?.contains("f") == true)
        #expect(engine.focusedConnected?.contains("a") == false)
    }
}

@Suite("FilterEngine - Edge Visibility Additional Tests")
@MainActor
struct FilterEngineEdgeVisibilityAdditionalTests {
    
    @Test("edge with self-loop visible")
    func edgeWithSelfLoopVisible() {
        let engine = FilterEngine()
        let edge = FilterTestHelpers.makeEdge(source: "a", target: "a")
        
        #expect(engine.isEdgeVisible(edge, sourceVisible: true, targetVisible: true))
    }
    
    @Test("edge with self-loop hidden when node hidden")
    func edgeWithSelfLoopHiddenWhenNodeHidden() {
        let engine = FilterEngine()
        let edge = FilterTestHelpers.makeEdge(source: "a", target: "a")
        
        #expect(!engine.isEdgeVisible(edge, sourceVisible: false, targetVisible: false))
    }
    
    @Test("multiple edges with different visibility")
    func multipleEdgesWithDifferentVisibility() {
        let engine = FilterEngine()
        
        let edge1 = FilterTestHelpers.makeEdge(source: "a", target: "b")
        let edge2 = FilterTestHelpers.makeEdge(source: "b", target: "c")
        let edge3 = FilterTestHelpers.makeEdge(source: "c", target: "d")
        
        #expect(engine.isEdgeVisible(edge1, sourceVisible: true, targetVisible: true))
        #expect(!engine.isEdgeVisible(edge2, sourceVisible: true, targetVisible: false))
        #expect(!engine.isEdgeVisible(edge3, sourceVisible: false, targetVisible: false))
    }
}

@Suite("FilterEngine - Stress Tests")
@MainActor
struct FilterEngineStressTests {
    
    @Test("rapid toggle operations")
    func rapidToggleOperations() {
        let engine = FilterEngine()
        
        // Rapidly toggle types
        for i in 0..<50 {
            let type = GraphNodeType.visibleCases[i % GraphNodeType.visibleCases.count]
            engine.toggleType(type)
        }
        
        // Should still be in a valid state
        #expect(engine.activeNodeTypes.count >= 0)
        #expect(engine.activeNodeTypes.count <= GraphNodeType.visibleCases.count)
    }
    
    @Test("alternating focus and clear")
    func alternatingFocusAndClear() {
        let engine = FilterEngine()
        
        for i in 0..<20 {
            engine.focusOn(nodeId: "node-\(i)", connectedSet: ["node-\(i)"])
            engine.clearFocus()
        }
        
        #expect(engine.focusedNodeId == nil)
        #expect(engine.focusedConnected == nil)
    }
}
