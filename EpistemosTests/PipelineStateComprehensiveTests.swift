import Testing
@testable import Epistemos

// MARK: - PipelineState Comprehensive Tests
// 30+ test cases covering stage progression, signal updates, error handling, and state management

@Suite("PipelineState - Initialization")
@MainActor
struct PipelineStateInitializationTests {
    
    @Test("initial state has correct defaults")
    func initialStateDefaults() {
        let state = PipelineState()
        
        #expect(state.confidence == 0.5)
        #expect(state.entropy == 0)
        #expect(state.dissonance == 0)
        #expect(state.healthScore == 1.0)
        #expect(state.safetyState == .green)
        #expect(state.riskScore == 0)
        #expect(state.focusDepth == 3)
        #expect(state.temperatureScale == 1.0)
        #expect(state.activeConcepts.isEmpty)
        #expect(state.pipelineStages.isEmpty)
        #expect(state.activeStage == nil)
        #expect(state.isProcessing == false)
        #expect(state.currentError == nil)
        #expect(state.queriesProcessed == 0)
        #expect(state.totalTraces == 0)
        #expect(state.skillGapsDetected == 0)
        #expect(state.signalHistory.isEmpty)
    }
    
    @Test("initial progress is zero")
    func initialProgress() {
        let state = PipelineState()
        #expect(state.currentProgress == 0)
    }
}

@Suite("PipelineState - Stage Progression")
@MainActor
struct PipelineStateStageTests {
    
    private func makeStageResult(
        stage: PipelineStage,
        status: StageStatus = .pending,
        value: Double? = nil
    ) -> StageResult {
        StageResult(
            stage: stage,
            status: status,
            data: nil,
            durationMs: nil,
            error: nil,
            detail: "Test detail for \(stage.displayName)",
            value: value
        )
    }
    
    @Test("startProcessing initializes stages")
    func startProcessingInitializesStages() {
        let state = PipelineState()
        state.startProcessing()
        
        #expect(state.isProcessing == true)
        #expect(state.currentError == nil)
        #expect(state.pipelineStages.count == PipelineStage.allCases.count)
        
        for stage in state.pipelineStages {
            #expect(stage.status == .pending)
        }
    }
    
    @Test("advanceStage updates active stage")
    func advanceStageUpdatesActive() {
        let state = PipelineState()
        state.startProcessing()
        
        let result = makeStageResult(stage: .triage, status: .running)
        state.advanceStage(.triage, result: result)
        
        #expect(state.activeStage == .triage)
    }
    
    @Test("advanceStage adds new stage")
    func advanceStageAddsNew() {
        let state = PipelineState()
        state.startProcessing()
        
        let result = makeStageResult(stage: .triage, status: .completed)
        state.advanceStage(.triage, result: result)
        
        let triageStage = state.pipelineStages.first { $0.stage == .triage }
        #expect(triageStage != nil)
        #expect(triageStage?.status == .completed)
    }
    
    @Test("advanceStage updates existing stage")
    func advanceStageUpdatesExisting() {
        let state = PipelineState()
        state.startProcessing()
        
        let runningResult = makeStageResult(stage: .triage, status: .running)
        state.advanceStage(.triage, result: runningResult)
        
        let completedResult = makeStageResult(stage: .triage, status: .completed, value: 0.85)
        state.advanceStage(.triage, result: completedResult)
        
        let triageStages = state.pipelineStages.filter { $0.stage == .triage }
        #expect(triageStages.count == 1) // Should not duplicate
        #expect(triageStages.first?.status == .completed)
        #expect(triageStages.first?.value == 0.85)
    }
    
    @Test("advanceStage preserves stage order")
    func advanceStagePreservesOrder() {
        let state = PipelineState()
        state.startProcessing()
        
        // Advance stages out of order
        state.advanceStage(.synthesis, result: makeStageResult(stage: .synthesis, status: .completed))
        state.advanceStage(.triage, result: makeStageResult(stage: .triage, status: .completed))
        state.advanceStage(.bayesian, result: makeStageResult(stage: .bayesian, status: .completed))
        
        // All stages should still be present
        #expect(state.pipelineStages.count == PipelineStage.allCases.count)
    }
    
    @Test("all pipeline stages can be advanced")
    func allStagesAdvancement() {
        let state = PipelineState()
        state.startProcessing()
        
        for stage in PipelineStage.allCases {
            let result = makeStageResult(stage: stage, status: .completed, value: Double.random(in: 0.5...1.0))
            state.advanceStage(stage, result: result)
            
            #expect(state.activeStage == stage)
        }
        
        #expect(state.pipelineStages.filter { $0.status == .completed }.count == PipelineStage.allCases.count)
    }
    
    @Test("completeProcessing finalizes state")
    func completeProcessingFinalizes() {
        let state = PipelineState()
        state.startProcessing()
        
        // Complete some stages
        state.advanceStage(.triage, result: makeStageResult(stage: .triage, status: .completed))
        state.advanceStage(.memory, result: makeStageResult(stage: .memory, status: .completed))
        
        let initialQueries = state.queriesProcessed
        state.completeProcessing()
        
        #expect(state.isProcessing == false)
        #expect(state.activeStage == nil)
        #expect(state.queriesProcessed == initialQueries + 1)
    }
    
    @Test("progress calculation with completed stages")
    func progressCalculation() {
        let state = PipelineState()
        state.startProcessing()
        
        #expect(state.currentProgress == 0)
        
        // Complete half the stages
        let halfCount = PipelineStage.allCases.count / 2
        for (index, stage) in PipelineStage.allCases.enumerated() {
            if index < halfCount {
                state.advanceStage(stage, result: makeStageResult(stage: stage, status: .completed))
            }
        }
        
        let expectedProgress = Double(halfCount) / Double(PipelineStage.allCases.count)
        #expect(abs(state.currentProgress - expectedProgress) < 0.01)
    }
    
    @Test("progress is 1 when all stages completed")
    func fullProgress() {
        let state = PipelineState()
        state.startProcessing()
        
        for stage in PipelineStage.allCases {
            state.advanceStage(stage, result: makeStageResult(stage: stage, status: .completed))
        }
        
        #expect(state.currentProgress == 1.0)
    }
}

@Suite("PipelineState - Signal Updates")
@MainActor
struct PipelineStateSignalTests {
    
    @Test("updateSignals updates confidence")
    func updateConfidence() {
        let state = PipelineState()
        let update = SignalUpdate(confidence: 0.75)
        
        state.updateSignals(update)
        
        #expect(state.confidence == 0.75)
    }
    
    @Test("updateSignals updates entropy")
    func updateEntropy() {
        let state = PipelineState()
        let update = SignalUpdate(entropy: 0.4)
        
        state.updateSignals(update)
        
        #expect(state.entropy == 0.4)
    }
    
    @Test("updateSignals updates dissonance")
    func updateDissonance() {
        let state = PipelineState()
        let update = SignalUpdate(dissonance: 0.3)
        
        state.updateSignals(update)
        
        #expect(state.dissonance == 0.3)
    }
    
    @Test("updateSignals updates health score")
    func updateHealthScore() {
        let state = PipelineState()
        let update = SignalUpdate(healthScore: 0.85)
        
        state.updateSignals(update)
        
        #expect(state.healthScore == 0.85)
    }
    
    @Test("updateSignals updates safety state")
    func updateSafetyState() {
        let state = PipelineState()
        let update = SignalUpdate(safetyState: .yellow)
        
        state.updateSignals(update)
        
        #expect(state.safetyState == .yellow)
    }
    
    @Test("updateSignals updates risk score")
    func updateRiskScore() {
        let state = PipelineState()
        let update = SignalUpdate(riskScore: 0.6)
        
        state.updateSignals(update)
        
        #expect(state.riskScore == 0.6)
    }
    
    @Test("updateSignals updates focus depth")
    func updateFocusDepth() {
        let state = PipelineState()
        let update = SignalUpdate(focusDepth: 7.5)
        
        state.updateSignals(update)
        
        #expect(state.focusDepth == 7.5)
    }
    
    @Test("updateSignals updates temperature scale")
    func updateTemperatureScale() {
        let state = PipelineState()
        let update = SignalUpdate(temperatureScale: 0.8)
        
        state.updateSignals(update)
        
        #expect(state.temperatureScale == 0.8)
    }
    
    @Test("updateSignals with nil values does not change state")
    func nilValuesNoChange() {
        let state = PipelineState()
        let initialConfidence = state.confidence
        let initialEntropy = state.entropy
        
        let update = SignalUpdate() // All nil
        state.updateSignals(update)
        
        #expect(state.confidence == initialConfidence)
        #expect(state.entropy == initialEntropy)
    }
    
    @Test("updateSignals partial update")
    func partialUpdate() {
        let state = PipelineState()
        let initialDissonance = state.dissonance
        
        let update = SignalUpdate(confidence: 0.9, entropy: 0.3)
        state.updateSignals(update)
        
        #expect(state.confidence == 0.9)
        #expect(state.entropy == 0.3)
        #expect(state.dissonance == initialDissonance) // Unchanged
    }
    
    @Test("updateSignals adds to signal history")
    func signalHistoryTracking() {
        let state = PipelineState()
        
        let update1 = SignalUpdate(confidence: 0.6, entropy: 0.2)
        state.updateSignals(update1)
        
        let update2 = SignalUpdate(confidence: 0.7, entropy: 0.3)
        state.updateSignals(update2)
        
        #expect(state.signalHistory.count == 2)
        
        // Check most recent entry
        if let lastEntry = state.signalHistory.last {
            #expect(lastEntry.confidence == 0.7)
            #expect(lastEntry.entropy == 0.3)
        }
    }
    
    @Test("signal history respects maximum size")
    func signalHistoryMaxSize() {
        let state = PipelineState()
        
        // Add more than 100 entries
        for i in 0..<110 {
            state.updateSignals(SignalUpdate(confidence: Double(i) / 100))
        }
        
        #expect(state.signalHistory.count <= 100)
    }
    
    @Test("signal history maintains order")
    func signalHistoryOrder() {
        let state = PipelineState()
        
        state.updateSignals(SignalUpdate(confidence: 0.1))
        state.updateSignals(SignalUpdate(confidence: 0.2))
        state.updateSignals(SignalUpdate(confidence: 0.3))
        
        let confidences = state.signalHistory.map { $0.confidence }
        #expect(confidences == [0.1, 0.2, 0.3])
    }
}

@Suite("PipelineState - Concept Management")
@MainActor
struct PipelineStateConceptTests {
    
    @Test("updateSignals adds concepts")
    func addConcepts() {
        let state = PipelineState()
        let update = SignalUpdate(concepts: ["Python", "Machine Learning"])
        
        state.updateSignals(update)
        
        #expect(state.activeConcepts.count == 2)
        #expect(state.activeConcepts.contains("Python"))
        #expect(state.activeConcepts.contains("Machine Learning"))
    }
    
    @Test("concepts accumulate across updates")
    func conceptsAccumulate() {
        let state = PipelineState()
        
        state.updateSignals(SignalUpdate(concepts: ["Python", "AI"]))
        state.updateSignals(SignalUpdate(concepts: ["Neural Networks", "Deep Learning"]))
        
        #expect(state.activeConcepts.count == 4)
    }
    
    @Test("duplicate concepts deduplicated")
    func conceptsDeduplicated() {
        let state = PipelineState()
        
        state.updateSignals(SignalUpdate(concepts: ["Python", "AI"]))
        state.updateSignals(SignalUpdate(concepts: ["python", "ai", "Rust"])) // Case-insensitive duplicates
        
        #expect(state.activeConcepts.count == 3) // Python, AI, Rust
    }
    
    @Test("concepts capped at 16")
    func conceptsCapped() {
        let state = PipelineState()
        
        // Add more than 16 concepts
        for i in 0..<20 {
            state.updateSignals(SignalUpdate(concepts: ["Concept\(i)"]))
        }
        
        #expect(state.activeConcepts.count <= 16)
    }
    
    @Test("concepts capped keeps most recent")
    func conceptsKeepRecent() {
        let state = PipelineState()
        
        // Add 20 concepts
        for i in 0..<20 {
            state.updateSignals(SignalUpdate(concepts: ["Concept\(i)"]))
        }
        
        // Should keep the last 16 (Concept4 through Concept19)
        #expect(state.activeConcepts.contains("Concept19"))
        #expect(!state.activeConcepts.contains("Concept0"))
    }
    
    @Test("clearConcepts removes all concepts")
    func clearConcepts() {
        let state = PipelineState()
        
        state.updateSignals(SignalUpdate(concepts: ["Python", "AI", "ML"]))
        #expect(!state.activeConcepts.isEmpty)
        
        state.clearConcepts()
        #expect(state.activeConcepts.isEmpty)
    }
}

@Suite("PipelineState - Error Handling")
@MainActor
struct PipelineStateErrorTests {
    
    @Test("setError updates error string")
    func setError() {
        let state = PipelineState()
        state.setError("Test error message")
        
        #expect(state.currentError == "Test error message")
    }
    
    @Test("setError with empty string")
    func setEmptyError() {
        let state = PipelineState()
        state.setError("")
        
        #expect(state.currentError == "")
    }
    
    @Test("startProcessing clears error")
    func startProcessingClearsError() {
        let state = PipelineState()
        state.setError("Previous error")
        
        state.startProcessing()
        
        #expect(state.currentError == nil)
    }
    
    @Test("error persists after completeProcessing")
    func errorPersistsAfterComplete() {
        let state = PipelineState()
        state.startProcessing()
        state.setError("Processing error")
        state.completeProcessing()
        
        #expect(state.currentError == "Processing error")
    }
}

@Suite("PipelineState - Reset Behavior")
@MainActor
struct PipelineStateResetTests {
    
    @Test("startProcessing resets pipeline stages")
    func startResetsStages() {
        let state = PipelineState()
        
        // First run
        state.startProcessing()
        state.advanceStage(.triage, result: StageResult(stage: .triage, status: .completed))
        state.completeProcessing()
        
        // Second run - should reset
        state.startProcessing()
        
        #expect(state.pipelineStages.allSatisfy { $0.status == .pending })
        #expect(state.isProcessing == true)
    }
    
    @Test("signals persist across processing cycles")
    func signalsPersistAcrossCycles() {
        let state = PipelineState()
        
        state.startProcessing()
        state.updateSignals(SignalUpdate(confidence: 0.8))
        state.completeProcessing()
        
        state.startProcessing()
        
        #expect(state.confidence == 0.8) // Persists
    }
    
    @Test("queriesProcessed increments")
    func queriesProcessedIncrements() {
        let state = PipelineState()
        
        state.startProcessing()
        state.completeProcessing()
        let afterFirst = state.queriesProcessed
        
        state.startProcessing()
        state.completeProcessing()
        
        #expect(state.queriesProcessed == afterFirst + 1)
    }
}

@Suite("PipelineState - Edge Cases")
@MainActor
struct PipelineStateEdgeCaseTests {
    
    @Test("advanceStage before startProcessing")
    func advanceBeforeStart() {
        let state = PipelineState()
        
        // Should not crash
        state.advanceStage(.triage, result: StageResult(stage: .triage, status: .completed))
        
        #expect(state.activeStage == .triage)
    }
    
    @Test("updateSignals with extreme values")
    func extremeSignalValues() {
        let state = PipelineState()
        
        state.updateSignals(SignalUpdate(confidence: 0))
        #expect(state.confidence == 0)
        
        state.updateSignals(SignalUpdate(confidence: 1.0))
        #expect(state.confidence == 1.0)
        
        state.updateSignals(SignalUpdate(entropy: -0.5))
        #expect(state.entropy == -0.5)
        
        state.updateSignals(SignalUpdate(entropy: 1.5))
        #expect(state.entropy == 1.5)
    }
    
    @Test("empty concepts update")
    func emptyConceptsUpdate() {
        let state = PipelineState()
        
        state.updateSignals(SignalUpdate(concepts: []))
        #expect(state.activeConcepts.isEmpty)
    }
    
    @Test("nil concepts does not clear existing")
    func nilConceptsNoClear() {
        let state = PipelineState()
        
        state.updateSignals(SignalUpdate(concepts: ["AI"]))
        state.updateSignals(SignalUpdate(confidence: 0.5)) // No concepts
        
        #expect(state.activeConcepts.contains("AI"))
    }
    
    @Test("concurrent signal updates")
    func concurrentUpdates() async {
        let state = PipelineState()
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { @MainActor in
                    state.updateSignals(SignalUpdate(confidence: Double(i) / 10))
                }
            }
        }
        
        // Should have exactly one history entry per update
        #expect(state.signalHistory.count == 10)
    }
}
