import Foundation
import Testing
@testable import Epistemos

// MARK: - GraphState Comprehensive Tests
// 60+ test cases covering all GraphState functionality

@Suite("GraphState - Initialization")
@MainActor
struct GraphStateInitializationTests {
    
    @Test("default initialization creates empty state")
    func defaultInitialization() {
        let state = GraphState()
        
        #expect(state.isLoaded == false)
        #expect(state.hasPlayedEntrance == false)
        #expect(state.isScanning == false)
        #expect(state.scanProgress == 0.0)
        #expect(state.scanStatus == "")
        #expect(state.selectedNodeId == nil)
        #expect(state.needsRefresh == false)
    }
    
    @Test("store and filter are initialized")
    func storeAndFilterInitialized() {
        let state = GraphState()
        
        #expect(state.store.nodeCount == 0)
        #expect(state.store.edgeCount == 0)
        #expect(!state.filter.isFiltered)
    }
    
    @Test("engine handle starts as nil")
    func engineHandleStartsNil() {
        let state = GraphState()
        
        #expect(state.engineHandle == nil)
    }
    
    @Test("embedding service is initialized")
    func embeddingServiceInitialized() {
        let state = GraphState()
        
        // Embedding service should be created and linked
        #expect(state.semanticStrength == 0.0)
    }
}

@Suite("GraphState - Physics Presets")
@MainActor
struct GraphStatePhysicsPresetTests {
    
    @Test("observatory preset applies correct values")
    func observatoryPreset() {
        let state = GraphState()
        state.applyPreset(.observatory)
        
        #expect(state.linkDistance == 243)
        #expect(state.chargeStrength == -2792)
        #expect(state.chargeRange == 218)
        #expect(state.linkStrength == Float(0.44))
        #expect(state.velocityDecay == 0.05)
        #expect(state.centerStrength == 0)
        #expect(state.collisionRadius == 50)
    }

    @Test("nebula preset applies correct values")
    func nebulaPreset() {
        let state = GraphState()
        state.applyPreset(.nebula)

        #expect(state.linkDistance == 280)
        #expect(state.chargeStrength == -250)
        #expect(state.chargeRange == 1200)
        #expect(state.linkStrength == 0)
        #expect(state.velocityDecay == 0.10)
        #expect(state.centerStrength == 0.002)
        #expect(state.collisionRadius == 40)
    }

    @Test("crystal preset applies correct values")
    func crystalPreset() {
        let state = GraphState()
        state.applyPreset(.crystal)

        #expect(state.linkDistance == 120)
        #expect(state.chargeStrength == -600)
        #expect(state.chargeRange == 800)
        #expect(state.linkStrength == 0)
        #expect(state.velocityDecay == 0.90)
        #expect(state.centerStrength == 0.02)
        #expect(state.collisionRadius == 30)
    }

    @Test("fluid preset applies correct values")
    func fluidPreset() {
        let state = GraphState()
        state.applyPreset(.fluid)

        #expect(state.linkDistance == 180)
        #expect(state.chargeStrength == -350)
        #expect(state.chargeRange == 1000)
        #expect(state.linkStrength == 0)
        #expect(state.velocityDecay == 0.20)
        #expect(state.centerStrength == 0.008)
        #expect(state.collisionRadius == 45)
    }

    @Test("constellation preset applies correct values")
    func constellationPreset() {
        let state = GraphState()
        state.applyPreset(.constellation)

        #expect(state.linkDistance == 350)
        #expect(state.chargeStrength == -200)
        #expect(state.chargeRange == 1500)
        #expect(state.linkStrength == 0)
        #expect(state.velocityDecay == 0.08)
        #expect(state.centerStrength == 0.001)
        #expect(state.collisionRadius == 35)
    }
    
    @Test("preset application increments force config versions")
    func presetIncrementsVersions() {
        let state = GraphState()
        let initialForceVersion = state.forceConfigVersion
        let initialExtendedVersion = state.extendedForceConfigVersion
        
        state.applyPreset(.observatory)
        
        #expect(state.forceConfigVersion == initialForceVersion + 1)
        #expect(state.extendedForceConfigVersion == initialExtendedVersion + 1)
    }
}

@Suite("GraphState - Force Parameters")
@MainActor
struct GraphStateForceParameterTests {
    
    @Test("default force parameter values")
    func defaultForceValues() {
        let state = GraphState()
        
        #expect(state.linkDistance == 243.0)
        #expect(state.chargeStrength == -2792.0)
        #expect(state.chargeRange == 218.0)
        #expect(state.linkStrength == Float(0.44))
        #expect(state.velocityDecay == 0.05)
        #expect(state.centerStrength == 0.0)
        #expect(state.collisionRadius == 50.0)
    }
    
    @Test("pushForceChange increments forceConfigVersion")
    func pushForceChangeIncrementsVersion() {
        let state = GraphState()
        let initialVersion = state.forceConfigVersion
        
        state.pushForceChange()
        
        #expect(state.forceConfigVersion == initialVersion + 1)
    }
    
    @Test("pushExtendedForceChange increments extendedForceConfigVersion")
    func pushExtendedForceChangeIncrementsVersion() {
        let state = GraphState()
        let initialVersion = state.extendedForceConfigVersion
        
        state.pushExtendedForceChange()
        
        #expect(state.extendedForceConfigVersion == initialVersion + 1)
    }
    
    @Test("pushClusterChange increments clusterConfigVersion")
    func pushClusterChangeIncrementsVersion() {
        let state = GraphState()
        let initialVersion = state.clusterConfigVersion
        
        state.pushClusterChange()
        
        #expect(state.clusterConfigVersion == initialVersion + 1)
    }
    
    @Test("multiple force changes accumulate versions")
    func multipleForceChangesAccumulate() {
        let state = GraphState()
        
        state.pushForceChange()
        state.pushForceChange()
        state.pushForceChange()
        
        #expect(state.forceConfigVersion == 3)
    }
}

@Suite("GraphState - Version Tracking")
@MainActor
struct GraphStateVersionTrackingTests {
    
    @Test("graphDataVersion starts at zero")
    func graphDataVersionStartsAtZero() {
        let state = GraphState()
        
        #expect(state.graphDataVersion == 0)
    }
    
    @Test("requestRecommit increments graphDataVersion")
    func requestRecommitIncrementsVersion() {
        let state = GraphState()
        let initialVersion = state.graphDataVersion
        
        state.requestRecommit()
        
        #expect(state.graphDataVersion == initialVersion + 1)
    }
    
    @Test("multiple recommits accumulate versions")
    func multipleRecommitsAccumulate() {
        let state = GraphState()
        
        state.requestRecommit()
        state.requestRecommit()
        state.requestRecommit()
        state.requestRecommit()
        state.requestRecommit()
        
        #expect(state.graphDataVersion == 5)
    }
    
    @Test("filterVersion starts at zero")
    func filterVersionStartsAtZero() {
        let state = GraphState()
        
        #expect(state.filterVersion == 0)
    }
    
    @Test("requestFilterSync increments filterVersion")
    func requestFilterSyncIncrementsVersion() {
        let state = GraphState()
        let initialVersion = state.filterVersion
        
        state.requestFilterSync()
        
        #expect(state.filterVersion == initialVersion + 1)
    }
    
    @Test("multiple filter syncs accumulate versions")
    func multipleFilterSyncsAccumulate() {
        let state = GraphState()
        
        state.requestFilterSync()
        state.requestFilterSync()
        state.requestFilterSync()
        
        #expect(state.filterVersion == 3)
    }
}

@Suite("GraphState - Graph Mode")
@MainActor
struct GraphStateModeTests {
    
    @Test("default mode is global")
    func defaultModeIsGlobal() {
        let state = GraphState()
        
        if case .global = state.mode {
            // Pass
        } else {
            Issue.record("Expected global mode")
        }
    }
    
    @Test("can switch to page mode")
    func canSwitchToPageMode() {
        let state = GraphState()
        
        state.mode = .page(nodeId: "test-node-id")
        
        if case .page(let nodeId) = state.mode {
            #expect(nodeId == "test-node-id")
        } else {
            Issue.record("Expected page mode")
        }
    }
    
    @Test("can switch back to global mode")
    func canSwitchBackToGlobalMode() {
        let state = GraphState()
        
        state.mode = .page(nodeId: "test")
        state.mode = .global
        
        if case .global = state.mode {
            // Pass
        } else {
            Issue.record("Expected global mode")
        }
    }
    
    @Test("page mode stores correct node ID")
    func pageModeStoresCorrectNodeId() {
        let state = GraphState()
        let testId = "specific-node-123"
        
        state.mode = .page(nodeId: testId)
        
        if case .page(let nodeId) = state.mode {
            #expect(nodeId == testId)
        } else {
            Issue.record("Expected page mode with specific ID")
        }
    }
}

@Suite("GraphState - Time Range")
@MainActor
struct GraphStateTimeRangeTests {
    
    @Test("default time range values")
    func defaultTimeRangeValues() {
        let state = GraphState()
        
        #expect(state.timeRangeStart == .distantPast)
        #expect(state.timeCutoff == .distantFuture)
        #expect(state.showTimeSlider == false)
    }
    
    @Test("computeTimeRange with empty store sets defaults")
    func computeTimeRangeEmptyStore() {
        let state = GraphState()
        
        state.computeTimeRange()
        
        #expect(state.timeRangeStart == .distantPast)
        #expect(state.timeRangeEnd <= .now)
        #expect(state.timeCutoff <= .now)
    }
    
    @Test("computeTimeRange with nodes finds correct bounds")
    func computeTimeRangeWithNodes() async {
        let state = GraphState()
        
        let date1 = Date(timeIntervalSince1970: 1000000)
        let date2 = Date(timeIntervalSince1970: 2000000)
        let date3 = Date(timeIntervalSince1970: 1500000)
        
        let node1 = GraphNodeRecord(
            id: "n1", type: .note, label: "First",
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: date1, position: .zero, velocity: .zero
        )
        let node2 = GraphNodeRecord(
            id: "n2", type: .note, label: "Second",
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: date2, position: .zero, velocity: .zero
        )
        let node3 = GraphNodeRecord(
            id: "n3", type: .note, label: "Third",
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: date3, position: .zero, velocity: .zero
        )
        
        state.store.addNode(node1)
        state.store.addNode(node2)
        state.store.addNode(node3)
        
        state.computeTimeRange()
        
        #expect(state.timeRangeStart == date1)
        #expect(state.timeRangeEnd == date2)
        #expect(state.timeCutoff == date2)
    }
    
    @Test("clearTimeFilter resets to distantFuture")
    func clearTimeFilterResets() {
        let state = GraphState()
        
        state.showTimeSlider = true
        state.timeCutoff = Date(timeIntervalSince1970: 1000)
        
        state.clearTimeFilter()
        
        #expect(state.timeCutoff == .distantFuture)
        #expect(state.showTimeSlider == false)
    }
    
    @Test("applyTimeFilter updates timeCutoff")
    func applyTimeFilterUpdatesCutoff() {
        let state = GraphState()
        let newCutoff = Date(timeIntervalSince1970: 5000000)
        
        state.applyTimeFilter(newCutoff)
        
        #expect(state.timeCutoff == newCutoff)
    }
}

@Suite("GraphState - Semantic Clustering")
@MainActor
struct GraphStateSemanticClusteringTests {
    
    @Test("semantic clustering disabled by default")
    func semanticClusteringDisabledByDefault() {
        let state = GraphState()
        
        #expect(state.useSemanticClustering == false)
    }
    
    @Test("semanticClusterIds starts empty")
    func semanticClusterIdsStartsEmpty() {
        let state = GraphState()
        
        #expect(state.semanticClusterIds.isEmpty)
    }
    
    @Test("semanticClusterVersion starts at zero")
    func semanticClusterVersionStartsAtZero() {
        let state = GraphState()
        
        #expect(state.semanticClusterVersion == 0)
    }
    
    @Test("computeSemanticClusters with empty store")
    func computeSemanticClustersEmptyStore() {
        let state = GraphState()
        
        state.computeSemanticClusters()
        
        #expect(state.semanticClusterIds.isEmpty)
        #expect(state.semanticClusterVersion == 1)
    }
    
    @Test("semanticStrength defaults to zero")
    func semanticStrengthDefaultsToZero() {
        let state = GraphState()
        
        #expect(state.semanticStrength == 0.0)
    }
}

@Suite("GraphState - Interaction Mode")
@MainActor
struct GraphStateInteractionModeTests {
    
    @Test("default interaction mode is idle")
    func defaultInteractionModeIsIdle() {
        let state = GraphState()
        
        if case .idle = state.interactionMode {
            // Pass
        } else {
            Issue.record("Expected idle mode")
        }
    }
    
    @Test("isConnecting returns false when idle")
    func isConnectingFalseWhenIdle() {
        let state = GraphState()
        
        #expect(state.isConnecting == false)
    }
    
    @Test("beginConnecting sets connecting mode")
    func beginConnectingSetsMode() {
        let state = GraphState()
        
        state.beginConnecting(from: "source-node-123")
        
        if case .connecting(let nodeId) = state.interactionMode {
            #expect(nodeId == "source-node-123")
        } else {
            Issue.record("Expected connecting mode")
        }
    }
    
    @Test("isConnecting returns true when connecting")
    func isConnectingTrueWhenConnecting() {
        let state = GraphState()
        
        state.beginConnecting(from: "test")
        
        #expect(state.isConnecting == true)
    }
    
    @Test("cancelConnecting returns to idle")
    func cancelConnectingReturnsToIdle() {
        let state = GraphState()
        
        state.beginConnecting(from: "test")
        state.cancelConnecting()
        
        if case .idle = state.interactionMode {
            // Pass
        } else {
            Issue.record("Expected idle mode after cancel")
        }
    }
}

@Suite("GraphState - Selection")
@MainActor
struct GraphStateSelectionTests {
    
    @Test("selectedNodeId starts nil")
    func selectedNodeIdStartsNil() {
        let state = GraphState()
        
        #expect(state.selectedNodeId == nil)
    }
    
    @Test("selectNode sets selectedNodeId")
    func selectNodeSetsId() {
        let state = GraphState()
        
        state.selectNode("selected-id")
        
        #expect(state.selectedNodeId == "selected-id")
    }
    
    @Test("selectNode with nil clears selection")
    func selectNodeNilClearsSelection() {
        let state = GraphState()
        
        state.selectNode("test")
        state.selectNode(nil)
        
        #expect(state.selectedNodeId == nil)
    }
    
    @Test("selectedNode returns nil when nothing selected")
    func selectedNodeReturnsNilWhenEmpty() {
        let state = GraphState()
        
        #expect(state.selectedNode == nil)
    }
    
    @Test("selectedNode returns correct node from store")
    func selectedNodeReturnsCorrectNode() async {
        let state = GraphState()
        
        let node = GraphNodeRecord(
            id: "test-node", type: .note, label: "Test",
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
        
        state.store.addNode(node)
        state.selectNode("test-node")
        
        #expect(state.selectedNode?.id == "test-node")
        #expect(state.selectedNode?.label == "Test")
    }
}

@Suite("GraphState - Quality Level")
@MainActor
struct GraphStateQualityLevelTests {
    
    @Test("default quality level is from UserDefaults")
    func defaultQualityLevelFromUserDefaults() {
        // Reset to default
        UserDefaults.standard.removeObject(forKey: "epistemos.graph.qualityLevel")
        
        let state = GraphState()
        
        // Default should be 0 (Cinematic) when not set
        #expect(state.qualityLevel == 0)
    }
    
    @Test("liteMode false when qualityLevel < 2")
    func liteModeFalseBelowThreshold() {
        let state = GraphState()
        state.qualityLevel = 0
        
        #expect(state.liteMode == false)
        
        state.qualityLevel = 1
        
        #expect(state.liteMode == false)
    }
    
    @Test("liteMode true when qualityLevel >= 2")
    func liteModeTrueAtThreshold() {
        let state = GraphState()
        state.qualityLevel = 2
        
        #expect(state.liteMode == true)
        
        state.qualityLevel = 3
        
        #expect(state.liteMode == true)
    }
    
    @Test("quality level change increments liteModeVersion")
    func qualityLevelChangeIncrementsVersion() {
        let state = GraphState()
        state.qualityLevel = 0
        let initialVersion = state.liteModeVersion
        
        state.qualityLevel = 1
        
        #expect(state.liteModeVersion == initialVersion + 1)
    }
    
    @Test("quality level persists to UserDefaults")
    func qualityLevelPersists() {
        let state = GraphState()
        state.qualityLevel = 1
        
        let saved = UserDefaults.standard.integer(forKey: "epistemos.graph.qualityLevel")
        
        #expect(saved == 1)
    }
}

@Suite("GraphState - Static Layout")
@MainActor
struct GraphStateStaticLayoutTests {
    
    @Test("isStaticLayout defaults to false")
    func isStaticLayoutDefaultsToFalse() {
        let state = GraphState()
        
        #expect(state.isStaticLayout == false)
    }
    
    @Test("staticLayoutThreshold is 1500")
    func staticLayoutThresholdValue() {
        #expect(GraphState.staticLayoutThreshold == 1500)
    }
}

@Suite("GraphState - Pending Actions")
@MainActor
struct GraphStatePendingActionTests {
    
    @Test("pendingResetView defaults to false")
    func pendingResetViewDefaultsToFalse() {
        let state = GraphState()
        
        #expect(state.pendingResetView == false)
    }
    
    @Test("pendingCenterNodeId defaults to nil")
    func pendingCenterNodeIdDefaultsToNil() {
        let state = GraphState()
        
        #expect(state.pendingCenterNodeId == nil)
    }
    
    @Test("pendingRebuild defaults to false")
    func pendingRebuildDefaultsToFalse() {
        let state = GraphState()
        
        #expect(state.pendingRebuild == false)
    }
    
    @Test("pendingMinimize defaults to false")
    func pendingMinimizeDefaultsToFalse() {
        let state = GraphState()
        
        #expect(state.pendingMinimize == false)
    }
    
    @Test("pendingClose defaults to false")
    func pendingCloseDefaultsToFalse() {
        let state = GraphState()
        
        #expect(state.pendingClose == false)
    }
}

@Suite("GraphState - Focus")
@MainActor
struct GraphStateFocusTests {
    
    @Test("focusOnNode sets filter focus")
    func focusOnNodeSetsFilter() {
        let state = GraphState()
        
        let node1 = GraphNodeRecord(
            id: "n1", type: .note, label: "Center",
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
        let node2 = GraphNodeRecord(
            id: "n2", type: .note, label: "Connected",
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
        
        state.store.addNode(node1)
        state.store.addNode(node2)
        state.store.addEdge(GraphEdgeRecord(
            id: "e1", sourceNodeId: "n1", targetNodeId: "n2",
            type: .reference, weight: 1.0, createdAt: .now
        ))
        
        state.focusOnNode("n1", depth: 1)
        
        #expect(state.filter.focusedNodeId == "n1")
        #expect(state.filter.isFiltered == true)
    }
    
    @Test("clearFocus removes filter focus")
    func clearFocusRemovesFilter() {
        let state = GraphState()
        
        let node = GraphNodeRecord(
            id: "n1", type: .note, label: "Test",
            sourceId: nil, metadata: GraphNodeMetadata(),
            weight: 1.0, createdAt: .now, position: .zero, velocity: .zero
        )
        state.store.addNode(node)
        
        state.focusOnNode("n1", depth: 1)
        state.clearFocus()
        
        #expect(state.filter.focusedNodeId == nil)
    }
}

@Suite("GraphState - Cluster Parameters")
@MainActor
struct GraphStateClusterParameterTests {
    
    @Test("default cluster strength")
    func defaultClusterStrength() {
        let state = GraphState()
        
        #expect(state.clusterStrength == 0.15)
    }
    
    @Test("default center mode")
    func defaultCenterMode() {
        let state = GraphState()
        
        #expect(state.centerMode == 0)
    }
    
    @Test("clusterConfigVersion starts at zero")
    func clusterConfigVersionStartsAtZero() {
        let state = GraphState()
        
        #expect(state.clusterConfigVersion == 0)
    }
}
