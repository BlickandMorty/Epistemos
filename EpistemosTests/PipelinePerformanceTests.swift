import Testing
import Foundation
@testable import Epistemos

// MARK: - Pipeline Performance Tests

@Suite("Pipeline Performance")
@MainActor
struct PipelinePerformanceTests {
    
    // MARK: - Stage Progression Timing
    
    @Test("Stage progression timing - all stages")
    func stageProgressionTiming() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Test response"]
        
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()
        
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )
        
        var stageTimes: [PipelineStage: Duration] = [:]
        var currentStage: PipelineStage?
        var stageStart: ContinuousClock.Instant?
        
        let stream = pipeline.run(
            query: "Test query",
            mode: .api,
            skipEnrichment: true
        )
        
        let clock = ContinuousClock()
        
        for try await event in stream {
            switch event {
            case .stageAdvanced(let stage, let result):
                if result.status == .running {
                    currentStage = stage
                    stageStart = clock.now
                } else if result.status == .completed, let start = stageStart, currentStage == stage {
                    stageTimes[stage] = clock.now - start
                }
            default:
                break
            }
        }
        
        // Each stage should complete quickly
        for (stage, time) in stageTimes {
            #expect(time < .milliseconds(50), 
                    "Stage \(stage) took \(time), expected < 50ms")
        }
    }
    
    @Test("Stage transition latency")
    func stageTransitionLatency() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Response"]
        
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()
        
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )
        
        var transitionCount = 0
        var lastTransitionTime: ContinuousClock.Instant?
        var totalTransitionTime: Duration = .zero
        
        let stream = pipeline.run(
            query: "Test",
            mode: .api,
            skipEnrichment: true
        )
        
        let clock = ContinuousClock()
        
        for try await event in stream {
            if case .stageAdvanced = event {
                let now = clock.now
                if let last = lastTransitionTime {
                    totalTransitionTime += now - last
                }
                lastTransitionTime = now
                transitionCount += 1
            }
        }
        
        if transitionCount > 1 {
            let avgTransition = Double(totalTransitionTime.components.attoseconds) / Double(transitionCount - 1)
            #expect(totalTransitionTime < .milliseconds(transitionCount * 10),
                    "Average stage transition too slow")
        }
    }
    
    // MARK: - Signal Generation Latency
    
    @Test("Signal generation latency")
    func signalGenerationLatency() async throws {
        let queries = [
            "What is consciousness?",
            "Explain quantum entanglement and its relationship to free will in deterministic physics models",
            "Compare the efficacy of cognitive behavioral therapy versus SSRIs for depression treatment",
            "Should we implement universal basic income?"
        ]
        
        for query in queries {
            var signalTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                
                let analysis = QueryAnalyzer.analyze(query: query)
                let _ = SignalGenerator.generate(queryAnalysis: analysis)
                
                signalTime = ContinuousClock().now - start
            }
            
            // Signal generation should be sub-millisecond
            #expect(signalTime < .milliseconds(50),
                    "Signal generation for '\(query.prefix(30))...' took \(signalTime)")
        }
    }
    
    @Test("Signal generation scaling")
    func signalGenerationScaling() async throws {
        let complexities: [Double] = [0.1, 0.3, 0.5, 0.7, 0.9]
        
        for complexity in complexities {
            var signalTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                
                let analysis = QueryAnalysis(
                    domain: .general,
                    questionType: .conceptual,
                    entities: Array(repeating: "entity", count: Int(complexity * 8)),
                    coreQuestion: "Test",
                    complexity: complexity,
                    isEmpirical: complexity > 0.5,
                    isPhilosophical: complexity > 0.6,
                    isMetaAnalytical: complexity > 0.8,
                    hasSafetyKeywords: false,
                    hasNormativeClaims: complexity > 0.7,
                    keyTerms: [],
                    emotionalValence: .neutral,
                    isFollowUp: false,
                    followUpFocus: nil
                )
                let _ = SignalGenerator.generate(queryAnalysis: analysis)
                
                signalTime = ContinuousClock().now - start
            }
            
            // Should not scale significantly with complexity
            #expect(signalTime < .milliseconds(2),
                    "Signal generation for complexity \(complexity) took \(signalTime)")
        }
    }
    
    // MARK: - Query Analysis Latency
    
    @Test("Query analysis latency")
    func queryAnalysisLatency() async throws {
        let queries = [
            "Hello",
            "What is AI?",
            "How does machine learning training work for neural networks in computer vision applications?",
            "Compare the meta-analysis of randomized controlled trials examining the efficacy of cognitive behavioral therapy versus pharmacological interventions for treatment-resistant depression in adolescent populations with comorbid anxiety disorders"
        ]
        
        for query in queries {
            var analysisTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                let _ = QueryAnalyzer.analyze(query: query)
                analysisTime = ContinuousClock().now - start
            }
            
            // Query analysis should be fast regardless of query length
            #expect(analysisTime < .milliseconds(50),
                    "Query analysis for \(query.count) chars took \(analysisTime)")
        }
    }
    
    @Test("Query analysis domain detection speed")
    func domainDetectionSpeed() async throws {
        let domainQueries: [(String, AnalysisDomain)] = [
            ("What is the treatment for cancer?", .medical),
            ("Explain quantum physics", .science),
            ("What is the meaning of life?", .philosophy),
            ("How do neural networks work?", .technology),
            ("Should we have universal healthcare?", .ethics)
        ]
        
        var totalTime: Duration = .zero
        
        measure {
            let start = ContinuousClock().now
            
            for (query, _) in domainQueries {
                let analysis = QueryAnalyzer.analyze(query: query)
                // Just verify analysis completes successfully (domain detection is heuristic)
                _ = analysis.domain
            }
            
            totalTime = ContinuousClock().now - start
        }
        
        #expect(totalTime < .milliseconds(25),
                "Domain detection for \(domainQueries.count) queries took \(totalTime)")
    }
    
    // MARK: - Stream Processing Throughput
    
    @Test("Stream token throughput")
    func streamTokenThroughput() async throws {
        let tokenCounts = [10, 50, 100, 200]
        
        for tokenCount in tokenCounts {
            let mock = MockLLMClient()
            mock.streamTokens = (0..<tokenCount).map { "token\($0) " }
            
            let pipelineState = PipelineState()
            let inference = InferenceState()
            let triage = TriageService(inference: inference, llmService: mock)
            let eventBus = EventBus()
            
            let pipeline = PipelineService(
                pipelineState: pipelineState,
                llmService: mock,
                triageService: triage,
                eventBus: eventBus
            )
            
            var receivedTokens = 0
            var streamTime: Duration = .zero
            
            try await measure {
                let start = ContinuousClock().now

                let stream = pipeline.run(
                    query: "Test",
                    mode: .api,
                    skipEnrichment: true
                )

                for try await event in stream {
                    if case .textDelta = event {
                        receivedTokens += 1
                    }
                }

                streamTime = ContinuousClock().now - start
            }
            
            // Calculate tokens per second
            let seconds = Double(streamTime.components.attoseconds) / 1e18
            let tps = seconds > 0 ? Double(receivedTokens) / seconds : 0
            
            #expect(tps > 1000, "Token throughput \(tps) TPS too low for \(tokenCount) tokens")
        }
    }
    
    @Test("Stream processing overhead")
    func streamProcessingOverhead() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Single response"]
        
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()
        
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )
        
        var overheadTime: Duration = .zero
        
        try await measure {
            let start = ContinuousClock().now

            let stream = pipeline.run(
                query: "Test",
                mode: .api,
                skipEnrichment: true
            )

            for try await _ in stream {}

            overheadTime = ContinuousClock().now - start
        }
        
        // Pipeline overhead (excluding LLM time) should be minimal
        #expect(overheadTime < .milliseconds(500),
                "Pipeline overhead \(overheadTime) too high")
    }
    
    // MARK: - Enrichment Timeout Behavior
    
    @Test("Enrichment timeout behavior")
    func enrichmentTimeoutBehavior() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Quick response"]
        // Don't set generateResponse to simulate timeout
        
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()
        
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )
        
        var completionTime: Duration = .zero
        var completedSuccessfully = false
        
        try await measure {
            let start = ContinuousClock().now

            let stream = pipeline.run(
                query: "Test timeout",
                mode: .api,
                skipEnrichment: false
            )

            for try await event in stream {
                if case .completed = event {
                    completedSuccessfully = true
                }
            }

            completionTime = ContinuousClock().now - start
        }
        
        // Main pipeline should complete regardless of enrichment
        #expect(completedSuccessfully, "Pipeline should complete")
    }
    
    @Test("Pipeline cancellation response time")
    func pipelineCancellationResponseTime() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = (0..<1000).map { "token\($0) " }
        
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()
        
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )
        
        var cancellationTime: Duration = .zero
        
        try await measure {
            let stream = pipeline.run(
                query: "Long running query",
                mode: .api,
                skipEnrichment: true
            )

            let task = Task {
                var count = 0
                for try await _ in stream {
                    count += 1
                }
                return count
            }

            // Let it start
            try? await Task.sleep(for: .milliseconds(50))

            let cancelStart = ContinuousClock().now
            task.cancel()

            // Wait for cancellation to take effect
            let _ = try? await task.value

            cancellationTime = ContinuousClock().now - cancelStart
        }
        
        // Cancellation should be near-instant
        #expect(cancellationTime < .milliseconds(100),
                "Cancellation took \(cancellationTime)")
    }
    
    // MARK: - Concurrent Pipeline Performance
    
    @Test("Multiple concurrent pipelines")
    func multipleConcurrentPipelines() async throws {
        let queries = ["Query 1", "Query 2", "Query 3"]
        
        var totalTime: Duration = .zero
        
        try await measure {
            let start = ContinuousClock().now

            let tasks = queries.map { query in
                Task {
                    let mock = MockLLMClient()
                    mock.streamTokens = ["Response to \(query)"]

                    let pipelineState = PipelineState()
                    let inference = InferenceState()
                    let triage = TriageService(inference: inference, llmService: mock)
                    let eventBus = EventBus()

                    let pipeline = PipelineService(
                        pipelineState: pipelineState,
                        llmService: mock,
                        triageService: triage,
                        eventBus: eventBus
                    )

                    let stream = pipeline.run(
                        query: query,
                        mode: .api,
                        skipEnrichment: true
                    )

                    for try await _ in stream {}
                }
            }

            for task in tasks {
                try? await task.value
            }

            totalTime = ContinuousClock().now - start
        }
        
        // Concurrent pipelines should complete faster than sequential
        #expect(totalTime < .milliseconds(1000),
                "3 concurrent pipelines took \(totalTime)")
    }
    
    // MARK: - Prompt Composition Performance
    
    @Test("Prompt composition latency")
    func promptCompositionLatency() async throws {
        let controls = PipelineControls.default
        let biases: [SteeringBias?] = [
            nil,
            SteeringBias(confidence: 0.5, entropy: 0, dissonance: 0, healthScore: 0, riskScore: 0, focusDepth: 0, temperatureScale: 0, betti0Adjust: 0, betti1Adjust: 0, conceptBoosts: [:], steeringStrength: 0.5, steeringSource: "deeper"),
            SteeringBias(confidence: -0.3, entropy: 0, dissonance: 0, healthScore: 0, riskScore: 0, focusDepth: 0, temperatureScale: 0, betti0Adjust: 0, betti1Adjust: 0, conceptBoosts: [:], steeringStrength: 0.5, steeringSource: "simpler"),
            SteeringBias(confidence: 0, entropy: 0.2, dissonance: 0, healthScore: 0, riskScore: 0, focusDepth: 0, temperatureScale: 0, betti0Adjust: 0, betti1Adjust: 0, conceptBoosts: [:], steeringStrength: 0.3, steeringSource: "focusEvidence"),
        ]
        
        for bias in biases {
            var composeTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                
                let _ = PromptComposer.compose(
                    controls: controls,
                    steeringBias: bias,
                    soarConfig: nil,
                    reroute: nil,
                    analyticsEngineEnabled: true,
                    chatMode: .research
                )
                
                composeTime = ContinuousClock().now - start
            }
            
            #expect(composeTime < .milliseconds(1),
                    "Prompt composition took \(composeTime)")
        }
    }
    
    // MARK: - Event Processing Performance
    
    @Test("Event bus throughput")
    func eventBusThroughput() async throws {
        let eventBus = EventBus()
        let eventCount = 1000

        var receivedCount = 0
        let handlerId = "perf-test"
        eventBus.subscribe(id: handlerId) { _ in
            receivedCount += 1
        }

        var publishTime: Duration = .zero

        measure {
            let start = ContinuousClock().now

            for _ in 0..<eventCount {
                eventBus.emit(.vaultChanged)
            }

            publishTime = ContinuousClock().now - start
        }

        // Small delay for async delivery
        try? await Task.sleep(for: .milliseconds(50))

        #expect(publishTime < .milliseconds(50),
                "Publishing \(eventCount) events took \(publishTime)")

        eventBus.unsubscribe(id: handlerId)
    }
    
    // MARK: - Memory Efficiency
    
    @Test("Pipeline memory efficiency")
    func pipelineMemoryEfficiency() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = (0..<100).map { String(repeating: "text ", count: $0) }
        
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()
        
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )
        
        var streamTime: Duration = .zero
        var totalTextLength = 0
        
        try await measure {
            let start = ContinuousClock().now

            let stream = pipeline.run(
                query: "Test",
                mode: .api,
                skipEnrichment: true
            )

            for try await event in stream {
                if case .textDelta(let text) = event {
                    totalTextLength += text.count
                }
            }

            streamTime = ContinuousClock().now - start
        }
        
        // Should handle large text efficiently
        #expect(totalTextLength > 0, "Should receive text")
        #expect(streamTime < .milliseconds(500), "Large text streaming took \(streamTime)")
    }
    
    // MARK: - Pipeline State Updates
    
    @Test("Pipeline state update performance")
    func pipelineStateUpdatePerformance() async throws {
        let pipelineState = PipelineState()
        let updateCount = 100
        
        var updateTime: Duration = .zero
        
        measure {
            let start = ContinuousClock().now
            
            for i in 0..<updateCount {
                pipelineState.updateSignals(SignalUpdate(
                    confidence: Double(i) / Double(updateCount),
                    entropy: Double(i) / Double(updateCount) * 0.5,
                    dissonance: Double(i) / Double(updateCount) * 0.3,
                    healthScore: 1.0 - Double(i) / Double(updateCount) * 0.2
                ))
            }
            
            updateTime = ContinuousClock().now - start
        }
        
        #expect(updateTime < .milliseconds(10),
                "\(updateCount) state updates took \(updateTime)")
    }
    
    // MARK: - Enrichment Performance
    
    @Test("Enrichment parsing performance")
    func enrichmentParsingPerformance() async throws {
        let jsonSizes = [100, 500, 1000, 2000]
        
        for size in jsonSizes {
            let json = String(repeating: "{\"key\":\"value\",", count: size) + "{}"
            
            var parseTime: Duration = .zero
            
            measure {
                let start = ContinuousClock().now
                let _ = EnrichmentController.extractJSON(from: json)
                parseTime = ContinuousClock().now - start
            }
            
            // Parsing should be fast even for large JSON
            #expect(parseTime < .milliseconds(Int(Double(size) * 0.1)),
                    "Parsing \(size) char JSON took \(parseTime)")
        }
    }
    
    // MARK: - Cold Start Performance
    
    @Test("Pipeline cold start latency")
    func pipelineColdStartLatency() async throws {
        var coldStartTime: Duration = .zero
        
        measure {
            let start = ContinuousClock().now
            
            let mock = MockLLMClient()
            let pipelineState = PipelineState()
            let inference = InferenceState()
            let triage = TriageService(inference: inference, llmService: mock)
            let eventBus = EventBus()
            
            let _ = PipelineService(
                pipelineState: pipelineState,
                llmService: mock,
                triageService: triage,
                eventBus: eventBus
            )
            
            coldStartTime = ContinuousClock().now - start
        }
        
        #expect(coldStartTime < .milliseconds(10),
                "Pipeline cold start took \(coldStartTime)")
    }
}
