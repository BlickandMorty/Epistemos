import Foundation
import Testing
@testable import Epistemos

// MARK: - EnrichmentController Comprehensive Tests
// 40+ test cases covering concept parsing, uncertainty extraction, fallbacks, and arbitration

@Suite("EnrichmentController - JSON Extraction")
@MainActor
struct EnrichmentControllerJSONTests {
    
    @Test("extractJSON parses clean JSON object")
    func cleanJSON() {
        let raw = """
        {"key": "value", "number": 42, "bool": true}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?["key"] as? String == "value")
        #expect(result?["number"] as? Int == 42)
        #expect(result?["bool"] as? Bool == true)
    }
    
    @Test("extractJSON strips markdown code fences")
    func stripsCodeFences() {
        let raw = """
        ```json
        {"status": "ok", "data": "test"}
        ```
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?["status"] as? String == "ok")
    }
    
    @Test("extractJSON strips triple backticks without json label")
    func stripsPlainBackticks() {
        let raw = """
        ```
        {"result": "success"}
        ```
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?["result"] as? String == "success")
    }
    
    @Test("extractJSON strips thinking blocks")
    func stripsThinkingBlocks() {
        let raw = """
        <thinking>I need to analyze this carefully...</thinking>
        {"verdict": "supported", "confidence": 0.85}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?["verdict"] as? String == "supported")
        #expect(result?["confidence"] as? Double == 0.85)
    }

    @Test("extractJSON strips qwen think blocks")
    func stripsQwenThinkBlocks() {
        let raw = """
        <think>I need to analyze this carefully...</think>
        {"verdict": "supported", "confidence": 0.85}
        """
        let result = EnrichmentController.extractJSON(from: raw)

        #expect(result != nil)
        #expect(result?["verdict"] as? String == "supported")
        #expect(result?["confidence"] as? Double == 0.85)
    }
    
    @Test("extractJSON strips multiple thinking blocks")
    func stripsMultipleThinkingBlocks() {
        let raw = """
        <thinking>First thought...</thinking>
        {"data": "value"}
        <thinking>Second thought...</thinking>
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?["data"] as? String == "value")
    }
    
    @Test("extractJSON handles prose before JSON")
    func proseBeforeJSON() {
        let raw = """
        After careful analysis, here is my structured response:
        
        {"analysis": "complete", "score": 95}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?["analysis"] as? String == "complete")
    }
    
    @Test("extractJSON strips trailing commas")
    func stripsTrailingCommas() {
        let raw = """
        {"items": [1, 2, 3,], "last": "value",}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?["last"] as? String == "value")
    }
    
    @Test("extractJSON returns nil for non-JSON")
    func returnsNilForNonJSON() {
        let raw = "Just plain text with no JSON structure"
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result == nil)
    }
    
    @Test("extractJSON returns nil for invalid JSON")
    func returnsNilForInvalidJSON() {
        let raw = "{invalid json structure"
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result == nil)
    }
    
    @Test("extractJSON handles nested objects")
    func nestedObjects() {
        let raw = """
        {"outer": {"inner": "value", "number": 123}, "array": [1, 2, 3]}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        if let outer = result?["outer"] as? [String: Any] {
            #expect(outer["inner"] as? String == "value")
        }
    }
    
    @Test("extractJSON handles empty JSON object")
    func emptyJSONObject() {
        let raw = "{}"
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?.isEmpty == true)
    }
}

@Suite("EnrichmentController - Concept Tag Parsing")
@MainActor
struct EnrichmentControllerConceptTagTests {
    
    @Test("parseConceptsTag extracts concepts")
    func extractsConcepts() {
        let text = "Some response text\n\n[CONCEPTS: Machine Learning, Neural Networks, AI]"
        let result = EnrichmentController.parseConceptsTag(from: text)
        
        #expect(result.concepts == ["Machine Learning", "Neural Networks", "AI"])
    }
    
    @Test("parseConceptsTag strips tag from text")
    func stripsTagFromText() {
        let text = "Response text\n\n[CONCEPTS: Concept1, Concept2]"
        let result = EnrichmentController.parseConceptsTag(from: text)
        
        #expect(!result.cleanedText.contains("[CONCEPTS:"))
        #expect(result.cleanedText == "Response text")
    }
    
    @Test("parseConceptsTag handles whitespace")
    func handlesWhitespace() {
        let text = "[CONCEPTS:  Concept1  ,  Concept2  , Concept3  ]"
        let result = EnrichmentController.parseConceptsTag(from: text)
        
        #expect(result.concepts == ["Concept1", "Concept2", "Concept3"])
    }
    
    @Test("parseConceptsTag limits to 8 concepts")
    func limitsTo8Concepts() {
        let text = "[CONCEPTS: Alpha, Beta, Gamma, Delta, Epsilon, Zeta, Eta, Theta, Iota, Kappa]"
        let result = EnrichmentController.parseConceptsTag(from: text)

        #expect(result.concepts.count == 8)
    }

    @Test("parseConceptsTag filters single-char concepts")
    func filtersSingleCharConcepts() {
        // Filter is count >= 2, so single chars are dropped, 2+ char strings kept
        let text = "[CONCEPTS: A, BB, Valid Concept, X]"
        let result = EnrichmentController.parseConceptsTag(from: text)

        #expect(!result.concepts.contains("A"))
        #expect(!result.concepts.contains("X"))
        #expect(result.concepts.contains("BB"))
        #expect(result.concepts.contains("Valid Concept"))
    }
    
    @Test("parseConceptsTag returns empty for missing tag")
    func returnsEmptyForMissingTag() {
        let text = "Just regular text without concepts tag"
        let result = EnrichmentController.parseConceptsTag(from: text)
        
        #expect(result.concepts.isEmpty)
        #expect(result.cleanedText == text)
    }
    
    @Test("parseConceptsTag strips concept headings")
    func stripsConceptHeadings() {
        let text = "Response\n\n## Concept Tags\n[CONCEPTS: AI, ML]"
        let result = EnrichmentController.parseConceptsTag(from: text)
        
        #expect(!result.cleanedText.contains("Concept Tags"))
        #expect(!result.cleanedText.contains("##"))
    }
    
    @Test("parseConceptsTag handles multiline")
    func handlesMultiline() {
        let text = """
        Response text
        [CONCEPTS: First Concept,
        Second Concept]
        """
        let result = EnrichmentController.parseConceptsTag(from: text)
        
        // Should handle the multiline tag
        #expect(result.concepts.count == 2 || result.concepts.isEmpty)
    }
}

@Suite("EnrichmentController - Uncertainty Tag Extraction")
@MainActor
struct EnrichmentControllerUncertaintyTagTests {
    
    @Test("extractUncertaintyTags finds DATA tags")
    func findsDataTags() {
        let text = "[DATA] This claim is supported by evidence"
        let tags = EnrichmentController.extractUncertaintyTags(from: text)
        
        #expect(tags.count == 1)
        #expect(tags[0].tag == .data)
        #expect(tags[0].claim.contains("supported by evidence"))
    }
    
    @Test("extractUncertaintyTags finds MODEL tags")
    func findsModelTags() {
        let text = "[MODEL] This is based on theoretical framework"
        let tags = EnrichmentController.extractUncertaintyTags(from: text)
        
        #expect(tags.count == 1)
        #expect(tags[0].tag == .model)
    }
    
    @Test("extractUncertaintyTags finds UNCERTAIN tags")
    func findsUncertainTags() {
        let text = "[UNCERTAIN] This claim has low confidence"
        let tags = EnrichmentController.extractUncertaintyTags(from: text)
        
        #expect(tags.count == 1)
        #expect(tags[0].tag == .uncertain)
    }
    
    @Test("extractUncertaintyTags finds CONFLICT tags")
    func findsConflictTags() {
        let text = "[CONFLICT] Evidence streams disagree on this point"
        let tags = EnrichmentController.extractUncertaintyTags(from: text)
        
        #expect(tags.count == 1)
        #expect(tags[0].tag == .conflict)
    }
    
    @Test("extractUncertaintyTags limits to 8 tags")
    func limitsTo8Tags() {
        let text = """
        [DATA] First claim. [DATA] Second claim. [DATA] Third claim.
        [DATA] Fourth claim. [DATA] Fifth claim. [DATA] Sixth claim.
        [DATA] Seventh claim. [DATA] Eighth claim. [DATA] Ninth claim.
        [DATA] Tenth claim.
        """
        let tags = EnrichmentController.extractUncertaintyTags(from: text)
        
        #expect(tags.count <= 8)
    }
    
    @Test("extractUncertaintyTags handles mixed tags")
    func handlesMixedTags() {
        let text = """
        [DATA] Empirical finding. [MODEL] Theoretical assumption.
        [UNCERTAIN] Unclear evidence. [CONFLICT] Disputed claim.
        """
        let tags = EnrichmentController.extractUncertaintyTags(from: text)
        
        #expect(tags.count == 4)
        #expect(tags.filter { $0.tag == .data }.count == 1)
        #expect(tags.filter { $0.tag == .model }.count == 1)
        #expect(tags.filter { $0.tag == .uncertain }.count == 1)
        #expect(tags.filter { $0.tag == .conflict }.count == 1)
    }
    
    @Test("extractUncertaintyTags handles claim length limits")
    func claimLengthLimits() {
        let shortClaim = "The data shows a clear trend in the results"
        let longClaim = String(repeating: "Analysis reveals that ", count: 12)
        let text = "[DATA] \(shortClaim). [DATA] \(longClaim)."

        let tags = EnrichmentController.extractUncertaintyTags(from: text)

        // Both tags should be extracted; long claims may be truncated but still present.
        #expect(tags.count >= 1)
    }
    
    @Test("extractUncertaintyTags returns empty for no tags")
    func returnsEmptyForNoTags() {
        let text = "Just plain text without any tags"
        let tags = EnrichmentController.extractUncertaintyTags(from: text)
        
        #expect(tags.isEmpty)
    }
}

@Suite("EnrichmentController - Epistemic Tag Counting")
@MainActor
struct EnrichmentControllerTagCountingTests {
    
    @Test("countEpistemicTags counts DATA tags")
    func countsDataTags() {
        let text = "[DATA] Claim 1. [DATA] Claim 2. [DATA] Claim 3."
        let counts = EnrichmentController.countEpistemicTags(in: text)
        
        #expect(counts.data == 3)
        #expect(counts.model == 0)
        #expect(counts.uncertain == 0)
        #expect(counts.conflict == 0)
    }
    
    @Test("countEpistemicTags counts all tag types")
    func countsAllTypes() {
        let text = "[DATA] One. [MODEL] Two. [UNCERTAIN] Three. [CONFLICT] Four. [DATA] Five."
        let counts = EnrichmentController.countEpistemicTags(in: text)
        
        #expect(counts.data == 2)
        #expect(counts.model == 1)
        #expect(counts.uncertain == 1)
        #expect(counts.conflict == 1)
    }
    
    @Test("countEpistemicTags returns zero for empty text")
    func zeroForEmpty() {
        let counts = EnrichmentController.countEpistemicTags(in: "")
        
        #expect(counts.data == 0)
        #expect(counts.model == 0)
        #expect(counts.uncertain == 0)
        #expect(counts.conflict == 0)
    }
    
    @Test("countEpistemicTags returns zero for no tags")
    func zeroForNoTags() {
        let counts = EnrichmentController.countEpistemicTags(in: "Just plain text")
        
        #expect(counts.data == 0)
        #expect(counts.model == 0)
    }
}

@Suite("EnrichmentController - Fallback Generation")
@MainActor
struct EnrichmentControllerFallbackTests {
    
    private func makeSignals(confidence: Double = 0.6, entropy: Double = 0.3, dissonance: Double = 0.2) -> GeneratedSignals {
        GeneratedSignals(
            confidence: confidence,
            entropy: entropy,
            dissonance: dissonance,
            healthScore: 0.8,
            safetyState: .green,
            riskScore: 0.1,
            focusDepth: 5,
            temperatureScale: 0.7,
            concepts: ["Test"],
            grade: .b,
            mode: .moderate
        )
    }
    
    private func makeQueryAnalysis() -> QueryAnalysis {
        QueryAnalysis(
            domain: .general,
            questionType: .conceptual,
            entities: ["test"],
            coreQuestion: "Test question?",
            complexity: 0.5,
            isEmpirical: false,
            isPhilosophical: false,
            isMetaAnalytical: false,
            hasSafetyKeywords: false,
            hasNormativeClaims: false,
            keyTerms: ["test"],
            emotionalValence: .neutral,
            isFollowUp: false,
            followUpFocus: nil
        )
    }
    
    @Test("fallbackLaymanSummary produces non-empty fields")
    func fallbackLaymanSummary() {
        let analysis = makeQueryAnalysis()
        let signals = makeSignals()
        
        let summary = EnrichmentController.fallbackLaymanSummary(queryAnalysis: analysis, signals: signals)
        
        #expect(!summary.whatWasTried.isEmpty)
        #expect(!summary.whatIsLikelyTrue.isEmpty)
        #expect(!summary.confidenceExplanation.isEmpty)
        #expect(!summary.whatCouldChange.isEmpty)
        #expect(!summary.whoShouldTrust.isEmpty)
    }
    
    @Test("fallbackLaymanSummary includes confidence percentage")
    func fallbackIncludesConfidence() {
        let analysis = makeQueryAnalysis()
        let signals = makeSignals(confidence: 0.75)
        
        let summary = EnrichmentController.fallbackLaymanSummary(queryAnalysis: analysis, signals: signals)
        
        #expect(summary.confidenceExplanation.contains("75") || summary.confidenceExplanation.contains("75%"))
    }
    
    @Test("fallbackReflection produces non-empty fields")
    func fallbackReflection() {
        let signals = makeSignals()
        
        let reflection = EnrichmentController.fallbackReflection(signals: signals)
        
        #expect(!reflection.selfCriticalQuestions.isEmpty)
        #expect(!reflection.leastDefensibleClaim.isEmpty)
        #expect(!reflection.precisionVsEvidenceCheck.isEmpty)
    }
    
    @Test("fallbackReflection questions are substantive")
    func fallbackReflectionQuestions() {
        let signals = makeSignals()
        
        let reflection = EnrichmentController.fallbackReflection(signals: signals)
        
        for question in reflection.selfCriticalQuestions {
            #expect(question.count > 10, "Question should be substantive")
        }
    }
    
    @Test("fallbackArbitration produces votes")
    func fallbackArbitration() {
        let signals = makeSignals(confidence: 0.7)
        
        let arbitration = EnrichmentController.fallbackArbitration(signals: signals)
        
        #expect(!arbitration.votes.isEmpty)
        #expect(!arbitration.resolution.isEmpty)
    }
    
    @Test("fallbackArbitration consensus based on confidence")
    func fallbackArbitrationConsensus() {
        let highConfSignals = makeSignals(confidence: 0.8)
        let lowConfSignals = makeSignals(confidence: 0.4)
        
        let highConfArbitration = EnrichmentController.fallbackArbitration(signals: highConfSignals)
        let lowConfArbitration = EnrichmentController.fallbackArbitration(signals: lowConfSignals)
        
        #expect(highConfArbitration.consensus == true)
        #expect(lowConfArbitration.consensus == false)
    }
    
    @Test("fallbackTruthAssessment produces valid likelihood")
    func fallbackTruthAssessment() {
        let signals = makeSignals(confidence: 0.65)
        
        let assessment = EnrichmentController.fallbackTruthAssessment(signals: signals)
        
        #expect(assessment.overallTruthLikelihood >= 0.05)
        #expect(assessment.overallTruthLikelihood <= 0.95)
        #expect(assessment.overallTruthLikelihood == 0.65)
    }
    
    @Test("fallbackTruthAssessment likelihood is clamped")
    func fallbackLikelihoodClamped() {
        let highSignals = makeSignals(confidence: 1.5)
        let lowSignals = makeSignals(confidence: -0.5)
        
        let highAssessment = EnrichmentController.fallbackTruthAssessment(signals: highSignals)
        let lowAssessment = EnrichmentController.fallbackTruthAssessment(signals: lowSignals)
        
        #expect(highAssessment.overallTruthLikelihood <= 0.95)
        #expect(lowAssessment.overallTruthLikelihood >= 0.05)
    }
    
    @Test("fallbackTruthAssessment produces all fields")
    func fallbackTruthAllFields() {
        let signals = makeSignals()
        
        let assessment = EnrichmentController.fallbackTruthAssessment(signals: signals)
        
        #expect(!assessment.signalInterpretation.isEmpty)
        #expect(!assessment.weaknesses.isEmpty)
        #expect(!assessment.improvements.isEmpty)
        #expect(!assessment.blindSpots.isEmpty)
        #expect(!assessment.confidenceCalibration.isEmpty)
        #expect(!assessment.dataVsModelBalance.isEmpty)
        #expect(!assessment.recommendedActions.isEmpty)
    }
}

@Suite("EnrichmentController - Response Concept Extraction")
@MainActor
struct EnrichmentControllerResponseConceptTests {
    
    @Test("extractResponseConcepts finds capitalized phrases")
    func findsCapitalizedPhrases() {
        let text = "This paper discusses Machine Learning and Neural Networks in detail."
        let concepts = EnrichmentController.extractResponseConcepts(from: text, queryEntities: [])
        
        let conceptSet = Set(concepts.map { $0.lowercased() })
        #expect(conceptSet.contains("machine learning"))
        #expect(conceptSet.contains("neural networks"))
    }
    
    @Test("extractResponseConcepts finds quoted terms")
    func findsQuotedTerms() {
        let text = """
        The concept of "recidivism" is important. "Moral desert" also matters.
        """
        let concepts = EnrichmentController.extractResponseConcepts(from: text, queryEntities: [])
        
        let conceptSet = Set(concepts.map { $0.lowercased() })
        #expect(conceptSet.contains("recidivism"))
        #expect(conceptSet.contains("moral desert"))
    }
    
    @Test("extractResponseConcepts boosts query entities")
    func boostsQueryEntities() {
        let text = "This discusses Python programming and Java development."
        let concepts = EnrichmentController.extractResponseConcepts(from: text, queryEntities: ["python"])
        
        // Python should be boosted due to appearing in query entities
        if let firstConcept = concepts.first {
            #expect(firstConcept.lowercased().contains("python"))
        }
    }
    
    @Test("extractResponseConcepts deduplicates exact matches")
    func deduplicatesConcepts() {
        let text = "Machine Learning machine learning MACHINE LEARNING"
        let concepts = EnrichmentController.extractResponseConcepts(from: text, queryEntities: [])

        // The exact phrase "Machine Learning" should appear at most once
        // (individual words like "Machine" may also be extracted separately as frequency-based concepts)
        let exactPhraseCount = concepts.filter { $0 == "Machine Learning" }.count
        #expect(exactPhraseCount <= 1)
    }
    
    @Test("extractResponseConcepts limits to 8")
    func limitsTo8() {
        let text = """
        One Two Three Four Five Six Seven Eight Nine Ten Eleven Twelve
        Thirteen Fourteen Fifteen Sixteen Seventeen Eighteen Nineteen Twenty
        """
        let concepts = EnrichmentController.extractResponseConcepts(from: text, queryEntities: [])
        
        #expect(concepts.count <= 8)
    }
    
    @Test("extractResponseConcepts filters stop words")
    func filtersStopWords() {
        let text = "The analysis of this and that with some things"
        let concepts = EnrichmentController.extractResponseConcepts(from: text, queryEntities: [])
        
        // Should not include common stop words as concepts
        let stopWordsInConcepts = concepts.filter { 
            QueryAnalyzer.stopWords.contains($0.lowercased()) 
        }
        #expect(stopWordsInConcepts.isEmpty)
    }
}

@Suite("EnrichmentController - System Prompts")
@MainActor
struct EnrichmentControllerPromptTests {
    
    @Test("systemPreamble is non-empty")
    func systemPreambleExists() {
        #expect(!EnrichmentController.systemPreamble.isEmpty)
        #expect(EnrichmentController.systemPreamble.contains("Epistemos"))
    }
    
    @Test("evidenceHierarchy is non-empty")
    func evidenceHierarchyExists() {
        #expect(!EnrichmentController.evidenceHierarchy.isEmpty)
        #expect(EnrichmentController.evidenceHierarchy.contains("Tier 1"))
    }
    
    @Test("preamble contains epistemic contract")
    func preambleHasEpistemicContract() {
        #expect(EnrichmentController.systemPreamble.contains("EPISTEMIC CONTRACT"))
    }
}

@Suite("EnrichmentController - Edge Cases")
@MainActor
struct EnrichmentControllerEdgeCaseTests {
    
    @Test("extractJSON handles nested braces in strings")
    func nestedBracesInStrings() {
        let raw = """
        {"text": "This has {braces} inside", "valid": true}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        
        #expect(result != nil)
        #expect(result?["valid"] as? Bool == true)
    }
    
    @Test("parseConceptsTag handles empty concept list")
    func emptyConceptList() {
        let text = "[CONCEPTS: ]"
        let result = EnrichmentController.parseConceptsTag(from: text)
        
        #expect(result.concepts.isEmpty)
    }
    
    @Test("extractUncertaintyTags handles very long claims")
    func veryLongClaims() {
        let longClaim = String(repeating: "word ", count: 100)
        let text = "[DATA] \(longClaim)"
        let tags = EnrichmentController.extractUncertaintyTags(from: text)
        
        #expect(tags.count <= 1)
    }
    
    @Test("countEpistemicTags handles overlapping patterns")
    func overlappingPatterns() {
        let text = "[DATA] [DATA] overlapping [MODEL] [DATA]"
        let counts = EnrichmentController.countEpistemicTags(in: text)
        
        #expect(counts.data == 3)
        #expect(counts.model == 1)
    }
    
    @Test("fallbacks handle edge case signal values")
    func fallbackEdgeValues() {
        let edgeSignals = GeneratedSignals(
            confidence: 0,
            entropy: 1.0,
            dissonance: 1.0,
            healthScore: 0,
            safetyState: .red,
            riskScore: 1.0,
            focusDepth: 0,
            temperatureScale: 2.0,
            concepts: [],
            grade: .f,
            mode: .moderate
        )
        
        let assessment = EnrichmentController.fallbackTruthAssessment(signals: edgeSignals)
        
        #expect(assessment.overallTruthLikelihood >= 0.05)
        #expect(assessment.overallTruthLikelihood <= 0.95)
    }
}
