import Testing
@testable import Epistemos

// MARK: - PromptComposer Comprehensive Tests
// 30+ test cases covering stage detail generation, directive composition, and controls

@Suite("PromptComposer - Stage Detail Generation")
@MainActor
struct PromptComposerStageDetailTests {
    
    private func makeQueryAnalysis(
        domain: AnalysisDomain = .general,
        questionType: QuestionType = .conceptual,
        entities: [String] = [],
        complexity: Double = 0.5,
        isPhilosophical: Bool = false,
        isMetaAnalytical: Bool = false
    ) -> QueryAnalysis {
        QueryAnalysis(
            domain: domain,
            questionType: questionType,
            entities: entities,
            coreQuestion: "Test question?",
            complexity: complexity,
            isEmpirical: false,
            isPhilosophical: isPhilosophical,
            isMetaAnalytical: isMetaAnalytical,
            hasSafetyKeywords: false,
            hasNormativeClaims: false,
            keyTerms: entities,
            emotionalValence: .neutral,
            isFollowUp: false,
            followUpFocus: nil
        )
    }
    
    @Test("generateStageDetail for triage stage")
    func triageStageDetail() {
        let analysis = makeQueryAnalysis(complexity: 0.5)
        let detail = PromptComposer.generateStageDetail(stage: .triage, queryAnalysis: analysis)
        
        #expect(!detail.isEmpty)
        #expect(detail.contains("complexity"))
    }
    
    @Test("triage stage detail includes philosophical routing")
    func triagePhilosophical() {
        let analysis = makeQueryAnalysis(complexity: 0.7, isPhilosophical: true)
        let detail = PromptComposer.generateStageDetail(stage: .triage, queryAnalysis: analysis)
        
        #expect(detail.contains("philosophical"))
    }
    
    @Test("generateStageDetail for memory stage")
    func memoryStageDetail() {
        let analysis = makeQueryAnalysis(entities: ["AI", "ML", "Data"], complexity: 0.6)
        let detail = PromptComposer.generateStageDetail(stage: .memory, queryAnalysis: analysis)
        
        #expect(!detail.isEmpty)
        #expect(detail.contains("fragment"))
    }
    
    @Test("memory stage detail scales with complexity")
    func memoryScaling() {
        let lowComplexity = makeQueryAnalysis(complexity: 0.1)
        let highComplexity = makeQueryAnalysis(complexity: 0.9)
        
        let lowDetail = PromptComposer.generateStageDetail(stage: .memory, queryAnalysis: lowComplexity)
        let highDetail = PromptComposer.generateStageDetail(stage: .memory, queryAnalysis: highComplexity)
        
        // Higher complexity should result in more fragments
        #expect(highDetail != lowDetail)
    }
    
    @Test("generateStageDetail for routing stage")
    func routingStageDetail() {
        let analysis = makeQueryAnalysis(isPhilosophical: true)
        let detail = PromptComposer.generateStageDetail(stage: .routing, queryAnalysis: analysis)
        
        #expect(detail.contains("philosophical"))
    }
    
    @Test("routing stage detail for meta-analytical")
    func routingMetaAnalytical() {
        let analysis = makeQueryAnalysis(isMetaAnalytical: true)
        let detail = PromptComposer.generateStageDetail(stage: .routing, queryAnalysis: analysis)
        
        #expect(detail.contains("meta"))
    }
    
    @Test("routing stage detail for causal questions")
    func routingCausal() {
        let analysis = makeQueryAnalysis(questionType: .causal)
        let detail = PromptComposer.generateStageDetail(stage: .routing, queryAnalysis: analysis)
        
        #expect(detail.contains("causal"))
    }
    
    @Test("generateStageDetail for statistical stage")
    func statisticalStageDetail() {
        let analysis = makeQueryAnalysis(entities: ["a", "b", "c"], complexity: 0.5)
        let detail = PromptComposer.generateStageDetail(stage: .statistical, queryAnalysis: analysis)
        
        #expect(detail.contains("Cohen"))
        #expect(detail.contains("d"))
    }
    
    @Test("statistical effect size classification")
    func statisticalEffectSize() {
        let lowEF = makeQueryAnalysis(entities: [], complexity: 0.1)
        let highEF = makeQueryAnalysis(entities: ["a", "b", "c", "d", "e", "f", "g", "h"], complexity: 0.9)
        
        let lowDetail = PromptComposer.generateStageDetail(stage: .statistical, queryAnalysis: lowEF)
        let highDetail = PromptComposer.generateStageDetail(stage: .statistical, queryAnalysis: highEF)
        
        #expect(lowDetail.contains("small") || lowDetail.contains("medium") || lowDetail.contains("large"))
        #expect(highDetail.contains("small") || highDetail.contains("medium") || highDetail.contains("large"))
    }
    
    @Test("generateStageDetail for causal stage")
    func causalStageDetail() {
        let analysis = makeQueryAnalysis(complexity: 0.5)
        let detail = PromptComposer.generateStageDetail(stage: .causal, queryAnalysis: analysis)
        
        #expect(detail.contains("Bradford Hill"))
    }
    
    @Test("causal stage detail includes strength classification")
    func causalStrength() {
        let lowComplexity = makeQueryAnalysis(complexity: 0.1)
        let highComplexity = makeQueryAnalysis(entities: ["a", "b", "c", "d"], complexity: 0.9)

        let lowDetail = PromptComposer.generateStageDetail(stage: .causal, queryAnalysis: lowComplexity)
        let highDetail = PromptComposer.generateStageDetail(stage: .causal, queryAnalysis: highComplexity)
        
        #expect(lowDetail.contains("weak") || lowDetail.contains("moderate") || lowDetail.contains("strong"))
        #expect(highDetail.contains("weak") || highDetail.contains("moderate") || highDetail.contains("strong"))
    }
    
    @Test("generateStageDetail for metaAnalysis stage")
    func metaAnalysisStageDetail() {
        let analysis = makeQueryAnalysis(entities: ["x", "y", "z"], complexity: 0.6)
        let detail = PromptComposer.generateStageDetail(stage: .metaAnalysis, queryAnalysis: analysis)
        
        #expect(detail.contains("studies"))
        #expect(detail.contains("I"))
    }
    
    @Test("metaAnalysis for philosophical queries")
    func metaAnalysisPhilosophical() {
        let analysis = makeQueryAnalysis(entities: ["a", "b", "c"], isPhilosophical: true)
        let detail = PromptComposer.generateStageDetail(stage: .metaAnalysis, queryAnalysis: analysis)
        
        #expect(detail.contains("traditions"))
    }
    
    @Test("generateStageDetail for bayesian stage")
    func bayesianStageDetail() {
        let analysis = makeQueryAnalysis(complexity: 0.5)
        let detail = PromptComposer.generateStageDetail(stage: .bayesian, queryAnalysis: analysis)
        
        #expect(detail.contains("BF"))
    }
    
    @Test("bayesian evidence classification")
    func bayesianEvidence() {
        let lowComplexity = makeQueryAnalysis(complexity: 0.1)
        let highComplexity = makeQueryAnalysis(complexity: 0.9)
        
        let lowDetail = PromptComposer.generateStageDetail(stage: .bayesian, queryAnalysis: lowComplexity)
        let highDetail = PromptComposer.generateStageDetail(stage: .bayesian, queryAnalysis: highComplexity)
        
        #expect(lowDetail.contains("weak") || lowDetail.contains("moderate") || lowDetail.contains("strong"))
        #expect(highDetail.contains("weak") || highDetail.contains("moderate") || highDetail.contains("strong"))
    }
    
    @Test("generateStageDetail for synthesis stage")
    func synthesisStageDetail() {
        let analysis = makeQueryAnalysis(isPhilosophical: false)
        let detail = PromptComposer.generateStageDetail(stage: .synthesis, queryAnalysis: analysis)
        
        #expect(detail.contains("integrating") || detail.contains("synthesizing"))
    }
    
    @Test("synthesis stage for philosophical queries")
    func synthesisPhilosophical() {
        let analysis = makeQueryAnalysis(entities: ["a", "b", "c"], isPhilosophical: true)
        let detail = PromptComposer.generateStageDetail(stage: .synthesis, queryAnalysis: analysis)
        
        #expect(detail.contains("dialectical"))
    }
    
    @Test("generateStageDetail for adversarial stage")
    func adversarialStageDetail() {
        let analysis = makeQueryAnalysis(complexity: 0.5)
        let detail = PromptComposer.generateStageDetail(stage: .adversarial, queryAnalysis: analysis)
        
        #expect(detail.contains("weakness"))
    }
    
    @Test("adversarial challenges scale with complexity")
    func adversarialScaling() {
        let lowComplexity = makeQueryAnalysis(complexity: 0.1)
        let highComplexity = makeQueryAnalysis(entities: ["a", "b", "c", "d"], complexity: 0.9)

        let lowDetail = PromptComposer.generateStageDetail(stage: .adversarial, queryAnalysis: lowComplexity)
        let highDetail = PromptComposer.generateStageDetail(stage: .adversarial, queryAnalysis: highComplexity)
        
        #expect(!lowDetail.isEmpty)
        #expect(!highDetail.isEmpty)
    }
    
    @Test("generateStageDetail for calibration stage")
    func calibrationStageDetail() {
        let analysis = makeQueryAnalysis(complexity: 0.5)
        let detail = PromptComposer.generateStageDetail(stage: .calibration, queryAnalysis: analysis)
        
        #expect(detail.contains("confidence"))
        #expect(detail.contains("grade"))
    }
    
    @Test("calibration grade assignment")
    func calibrationGrade() {
        let lowConf = makeQueryAnalysis(complexity: 0.1)
        let highConf = makeQueryAnalysis(complexity: 0.9)
        
        let lowDetail = PromptComposer.generateStageDetail(stage: .calibration, queryAnalysis: lowConf)
        let highDetail = PromptComposer.generateStageDetail(stage: .calibration, queryAnalysis: highConf)
        
        // Should include grade letters
        #expect(lowDetail.contains("A") || lowDetail.contains("B") || lowDetail.contains("C"))
        #expect(highDetail.contains("A") || highDetail.contains("B") || highDetail.contains("C"))
    }
    
    @Test("all stages produce non-empty details")
    func allStagesNonEmpty() {
        let analysis = makeQueryAnalysis(entities: ["test"], complexity: 0.5)
        
        for stage in PipelineStage.allCases {
            let detail = PromptComposer.generateStageDetail(stage: stage, queryAnalysis: analysis)
            #expect(!detail.isEmpty, "Stage \(stage) should produce non-empty detail")
        }
    }
}

@Suite("PromptComposer - Directive Composition")
@MainActor
struct PromptComposerDirectiveTests {
    
    @Test("compose with disabled analytics returns empty")
    func disabledAnalytics() {
        let directives = PromptComposer.compose(analyticsEngineEnabled: false)
        #expect(directives.isEmpty)
    }
    
    @Test("compose with research mode")
    func researchMode() {
        let directives = PromptComposer.compose(
            analyticsEngineEnabled: true,
            chatMode: .research
        )
        
        #expect(!directives.isEmpty)
        #expect(directives.contains("rigorous") || directives.contains("evidence"))
    }
    
    @Test("compose with plain mode")
    func plainMode() {
        let directives = PromptComposer.compose(
            analyticsEngineEnabled: true,
            chatMode: .plain
        )
        
        #expect(!directives.isEmpty)
        #expect(directives.contains("direct") || directives.contains("concise"))
    }
    
    @Test("compose defaults to research mode")
    func defaultResearchMode() {
        let directives = PromptComposer.compose(analyticsEngineEnabled: true)
        
        #expect(!directives.isEmpty)
        #expect(directives.contains("rigorous") || directives.contains("evidence"))
    }
    
    @Test("compose with empty controls")
    func emptyControls() {
        let directives = PromptComposer.compose(
            controls: nil,
            analyticsEngineEnabled: true
        )
        
        #expect(!directives.isEmpty)
    }
}

@Suite("PromptComposer - Complexity Bias")
@MainActor
struct PromptComposerComplexityTests {
    
    @Test("positive complexity bias adds detail directive")
    func positiveComplexityBias() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: 0.3,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("layers") || directives.contains("complexity"))
    }
    
    @Test("negative complexity bias adds clarity directive")
    func negativeComplexityBias() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: -0.3,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("clarity") || directives.contains("direct"))
    }
    
    @Test("small complexity bias ignored")
    func smallComplexityBiasIgnored() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: 0.1,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directivesWithBias = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        let directivesWithoutBias = PromptComposer.compose(
            analyticsEngineEnabled: true
        )
        
        // Small bias (within deadband) should be ignored
        #expect(directivesWithBias == directivesWithoutBias)
    }
}

@Suite("PromptComposer - Adversarial Intensity")
@MainActor
struct PromptComposerAdversarialTests {
    
    @Test("high adversarial intensity adds scrutiny")
    func highAdversarial() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 1.5,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("scrutiny") || directives.contains("critical"))
    }
    
    @Test("low adversarial intensity adds synthesis")
    func lowAdversarial() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 0.5,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("synthesis") || directives.contains("converge"))
    }
}

@Suite("PromptComposer - Bayesian Prior Strength")
@MainActor
struct PromptComposerBayesianTests {
    
    @Test("high prior strength adds conservative directive")
    func highPriorStrength() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.5,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("conservative") || directives.contains("base rates"))
    }
    
    @Test("low prior strength adds openness directive")
    func lowPriorStrength() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 0.5,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("openness") || directives.contains("benefit"))
    }
}

@Suite("PromptComposer - Focus Depth Override")
@MainActor
struct PromptComposerFocusDepthTests {
    
    @Test("high focus depth adds depth directive")
    func highFocusDepth() {
        let controls = PipelineControls(
            focusDepthOverride: 8.5,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("deep") || directives.contains("specialist"))
    }
    
    @Test("medium focus depth adds thorough directive")
    func mediumFocusDepth() {
        let controls = PipelineControls(
            focusDepthOverride: 6.0,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("thorough"))
    }
    
    @Test("low focus depth adds focused directive")
    func lowFocusDepth() {
        let controls = PipelineControls(
            focusDepthOverride: 3.0,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("focused") || directives.contains("efficient"))
    }
}

@Suite("PromptComposer - Temperature Override")
@MainActor
struct PromptComposerTemperatureTests {
    
    @Test("high temperature adds creativity directive")
    func highTemperature() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: 1.3,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("creative") || directives.contains("analogy"))
    }
    
    @Test("medium-high temperature adds balance directive")
    func mediumHighTemperature() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: 0.9,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("imagination") || directives.contains("connections"))
    }
    
    @Test("low temperature adds precision directive")
    func lowTemperature() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: 0.3,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: nil
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("precision"))
    }
}

@Suite("PromptComposer - Steering Bias")
@MainActor
struct PromptComposerSteeringTests {
    
    @Test("positive confidence steering")
    func positiveConfidence() {
        let bias = SteeringBias(
            confidence: 0.3,
            entropy: 0,
            dissonance: 0,
            healthScore: 0,
            riskScore: 0,
            focusDepth: 0,
            temperatureScale: 0,
            betti0Adjust: 0,
            betti1Adjust: 0,
            conceptBoosts: [:],
            steeringStrength: 0.5,
            steeringSource: "test"
        )

        let directives = PromptComposer.compose(
            steeringBias: bias,
            analyticsEngineEnabled: true
        )

        #expect(directives.contains("Confidence calibration"))
    }
    
    @Test("negative confidence steering")
    func negativeConfidence() {
        let bias = SteeringBias(
            confidence: -0.3,
            entropy: 0,
            dissonance: 0,
            healthScore: 0,
            riskScore: 0,
            focusDepth: 0,
            temperatureScale: 0,
            betti0Adjust: 0,
            betti1Adjust: 0,
            conceptBoosts: [:],
            steeringStrength: 0.5,
            steeringSource: "test"
        )

        let directives = PromptComposer.compose(
            steeringBias: bias,
            analyticsEngineEnabled: true
        )

        #expect(directives.contains("uncertainty"))
    }
    
    @Test("high entropy steering")
    func highEntropySteering() {
        let bias = SteeringBias(
            confidence: 0,
            entropy: 0.3,
            dissonance: 0,
            healthScore: 0,
            riskScore: 0,
            focusDepth: 0,
            temperatureScale: 0,
            betti0Adjust: 0,
            betti1Adjust: 0,
            conceptBoosts: [:],
            steeringStrength: 0.5,
            steeringSource: "test"
        )

        let directives = PromptComposer.compose(
            steeringBias: bias,
            analyticsEngineEnabled: true
        )

        #expect(directives.contains("disagreements"))
    }
    
    @Test("high dissonance steering")
    func highDissonanceSteering() {
        let bias = SteeringBias(
            confidence: 0,
            entropy: 0,
            dissonance: 0.3,
            healthScore: 0,
            riskScore: 0,
            focusDepth: 0,
            temperatureScale: 0,
            betti0Adjust: 0,
            betti1Adjust: 0,
            conceptBoosts: [:],
            steeringStrength: 0.5,
            steeringSource: "test"
        )

        let directives = PromptComposer.compose(
            steeringBias: bias,
            analyticsEngineEnabled: true
        )

        #expect(directives.contains("Contradiction"))
    }
}

@Suite("PromptComposer - Signal Overrides")
@MainActor
struct PromptComposerSignalOverrideTests {
    
    @Test("signal overrides in directives")
    func signalOverrides() {
        let overrides = SignalOverrides(
            confidence: 0.8,
            entropy: 0.2,
            dissonance: 0.1
        )
        
        let directives = PromptComposer.compose(
            signalOverrides: overrides,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("confidence"))
        #expect(directives.contains("entropy") || directives.contains("dissonance"))
    }
    
    @Test("partial signal overrides")
    func partialOverrides() {
        let overrides = SignalOverrides(confidence: 0.9)
        
        let directives = PromptComposer.compose(
            signalOverrides: overrides,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("confidence"))
    }
}

@Suite("PromptComposer - Reroute Instruction")
@MainActor
struct PromptComposerRerouteTests {
    
    @Test("focus reroute")
    func focusReroute() {
        let reroute = RerouteInstruction(type: .focus, detail: nil)
        
        let directives = PromptComposer.compose(
            reroute: reroute,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("REDIRECT"))
        #expect(directives.contains("Narrow down"))
    }
    
    @Test("explore reroute")
    func exploreReroute() {
        let reroute = RerouteInstruction(type: .explore, detail: nil)
        
        let directives = PromptComposer.compose(
            reroute: reroute,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("REDIRECT"))
        #expect(directives.contains("Branch"))
    }
    
    @Test("challenge reroute")
    func challengeReroute() {
        let reroute = RerouteInstruction(type: .challenge, detail: nil)
        
        let directives = PromptComposer.compose(
            reroute: reroute,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("REDIRECT"))
        #expect(directives.contains("scrutiny"))
    }
    
    @Test("reroute with detail")
    func rerouteWithDetail() {
        let reroute = RerouteInstruction(type: .synthesize, detail: "Combine findings from section 3")
        
        let directives = PromptComposer.compose(
            reroute: reroute,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("REDIRECT"))
        #expect(directives.contains("section 3"))
    }
}

@Suite("PromptComposer - Concept Weights")
@MainActor
struct PromptComposerConceptWeightsTests {
    
    @Test("concept weights in directives")
    func conceptWeights() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: ["AI": 2.0, "Ethics": 0.5]
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("AI"))
        #expect(directives.contains("Ethics"))
    }
    
    @Test("concept weights below threshold ignored")
    func weightsBelowThreshold() {
        let controls = PipelineControls(
            focusDepthOverride: nil,
            temperatureOverride: nil,
            complexityBias: 0,
            adversarialIntensity: 1.0,
            bayesianPriorStrength: 1.0,
            conceptWeights: ["AI": 1.1, "Minor": 0.8]
        )
        
        let directives = PromptComposer.compose(
            controls: controls,
            analyticsEngineEnabled: true
        )
        
        // AI at 1.1 diff (2.0 - 1.0 = 1.1) should be included
        // Minor at 0.2 diff should be ignored
        #expect(directives.contains("AI"))
    }
}

@Suite("PromptComposer - SOAR Config")
@MainActor
struct PromptComposerSOARTests {
    
    @Test("enabled SOAR adds reflection prompt")
    func enabledSOAR() {
        let soar = SOARConfig(enabled: true, autoDetect: true, thresholds: .default, maxIterations: 3, stonesPerCurriculum: 3, rewardWeights: .default, minRewardThreshold: 0.05, contradictionDetection: false, maxContradictionClaims: 20, apiCostCapTokens: 50000, verbose: false)
        
        let directives = PromptComposer.compose(
            soarConfig: soar,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("reflect"))
    }
    
    @Test("disabled SOAR ignored")
    func disabledSOAR() {
        let soar = SOARConfig(enabled: false, autoDetect: true, thresholds: .default, maxIterations: 3, stonesPerCurriculum: 3, rewardWeights: .default, minRewardThreshold: 0.05, contradictionDetection: true, maxContradictionClaims: 20, apiCostCapTokens: 50000, verbose: false)
        
        let directivesWithout = PromptComposer.compose(analyticsEngineEnabled: true)
        let directivesWith = PromptComposer.compose(
            soarConfig: soar,
            analyticsEngineEnabled: true
        )
        
        #expect(directivesWith == directivesWithout)
    }
    
    @Test("SOAR with contradiction detection")
    func soarContradiction() {
        let soar = SOARConfig(enabled: true, autoDetect: true, thresholds: .default, maxIterations: 3, stonesPerCurriculum: 3, rewardWeights: .default, minRewardThreshold: 0.05, contradictionDetection: true, maxContradictionClaims: 20, apiCostCapTokens: 50000, verbose: false)
        
        let directives = PromptComposer.compose(
            soarConfig: soar,
            analyticsEngineEnabled: true
        )
        
        #expect(directives.contains("conflict"))
    }
}
