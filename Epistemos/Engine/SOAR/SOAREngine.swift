import Foundation

// MARK: - SOAR Engine
// Main orchestrator matching lib/engine/soar/engine.ts

actor SOAREngine {

    // MARK: - Dependencies

    private let llmService: LLMService?
    private let teacher: SOARTeacher

    init(llmService: LLMService? = nil) {
        self.llmService = llmService
        self.teacher = SOARTeacher()
    }

    // MARK: - Run SOAR

    func runSOAR(
        query: String,
        queryAnalysis: QueryAnalysis,
        baselineSignals: BaselineSignals,
        inferenceMode: InferenceMode,
        config: SOARConfig,
        onEvent: (@Sendable (SOAREvent) -> Void)? = nil
    ) async -> SOARSession {
        let sessionId = generateSessionId()
        let startTime = Date()

        // Get mode-specific limitations
        let limitations = getSOARLimitations(for: inferenceMode)
        let maxIterations = min(config.maxIterations, limitations.maxIterations)
        let maxStones = min(config.stonesPerCurriculum, limitations.maxStonesPerCurriculum)

        // Step 1: Probe learnability
        let probe = SOARDetector.probeLearnability(
            queryAnalysis: queryAnalysis,
            priorSignals: baselineSignals,
            thresholds: config.thresholds
        )

        emit(onEvent, type: .probeComplete, sessionId: sessionId, iteration: 0, data: [
            "probe": .probe(probe),
            "atEdge": .bool(probe.atEdge),
            "difficulty": .double(probe.estimatedDifficulty)
        ])

        // Initialize session
        var session = SOARSession(
            id: sessionId,
            targetQuery: query,
            probe: probe,
            curricula: [],
            attempts: [],
            finalAttempts: [],
            rewards: [],
            contradictionScan: nil,
            baselineSignals: baselineSignals,
            finalSignals: nil,
            iterationsCompleted: 0,
            maxIterations: maxIterations,
            overallImproved: false,
            totalDurationMs: 0,
            inferenceMode: inferenceMode,
            startedAt: startTime,
            completedAt: nil,
            status: .probing
        )

        // If not at edge and auto-detect is on, skip SOAR
        if !probe.atEdge && config.autoDetect {
            session.status = .complete
            session.completedAt = Date()
            session.totalDurationMs = Date().timeIntervalSince(startTime) * 1000

            emit(onEvent, type: .sessionComplete, sessionId: sessionId, iteration: 0, data: [
                "reason": .string("Not at edge of learnability"),
                "probe": .probe(probe)
            ])

            return session
        }

        // Use recommended depth if auto-detecting
        let targetIterations = config.autoDetect
            ? min(probe.recommendedDepth, maxIterations)
            : maxIterations

        guard targetIterations > 0 else {
            session.status = .complete
            session.completedAt = Date()
            session.totalDurationMs = Date().timeIntervalSince(startTime) * 1000
            return session
        }

        // Track running signals for reward computation
        var currentSignals = baselineSignals
        var previousReward: SOARReward? = nil

        // Step 2-5: SOAR iteration loop
        for iteration in 0..<targetIterations {
            // 2. Teach: Generate curriculum
            session.status = .teaching
            emit(onEvent, type: .teachingStart, sessionId: sessionId, iteration: iteration, data: [
                "stonesRequested": .int(maxStones)
            ])

            let curriculum = await teacher.generateCurriculum(
                query: query,
                queryAnalysis: queryAnalysis,
                numStones: maxStones,
                iteration: iteration,
                previousReward: previousReward,
                llmService: llmService
            )

            // Assess structural quality of each stone
            var updatedStones = curriculum.stones
            for i in updatedStones.indices {
                updatedStones[i].structuralQuality = SOARRewardCalculator.assessStructuralQuality(
                    stoneQuestion: updatedStones[i].question,
                    targetQuery: query
                )
            }

            let updatedCurriculum = Curriculum(
                id: curriculum.id,
                targetQuery: curriculum.targetQuery,
                stones: updatedStones,
                generationTimeMs: curriculum.generationTimeMs,
                iteration: curriculum.iteration,
                teacherRationale: curriculum.teacherRationale
            )

            session.curricula.append(updatedCurriculum)

            emit(onEvent, type: .teachingComplete, sessionId: sessionId, iteration: iteration, data: [
                "curriculumId": .string(curriculum.id),
                "numStones": .int(curriculum.stones.count),
                "rationale": .string(curriculum.teacherRationale)
            ])

            // 3. Learn: Student works through stepping stones
            session.status = .learning
            var iterationAttempts: [StoneAttempt] = []

            for stone in updatedCurriculum.stones {
                emit(onEvent, type: .stoneStart, sessionId: sessionId, iteration: iteration, data: [
                    "stoneId": .string(stone.id),
                    "skill": .string(stone.targetSkill),
                    "difficulty": .double(stone.relativeDifficulty)
                ])

                let attempt = await SOARStudent.attemptStone(
                    stone: stone,
                    previousAttempts: iterationAttempts,
                    targetQuery: query,
                    llmService: llmService
                )

                iterationAttempts.append(attempt)
                session.attempts.append(attempt)

                emit(onEvent, type: .stoneComplete, sessionId: sessionId, iteration: iteration, data: [
                    "stoneId": .string(stone.id),
                    "confidence": .double(attempt.confidenceAfter),
                    "entropy": .double(attempt.entropyAfter),
                    "contributed": .bool(attempt.contributedToContext)
                ])
            }

            // 4. Evaluate: Student re-attempts target problem
            session.status = .evaluating
            emit(onEvent, type: .finalAttemptStart, sessionId: sessionId, iteration: iteration, data: [:])

            let finalAttempt = await SOARStudent.attemptTarget(
                query: query,
                queryAnalysis: queryAnalysis,
                curriculum: updatedCurriculum,
                attempts: iterationAttempts,
                llmService: llmService
            )
            session.finalAttempts.append(finalAttempt)

            emit(onEvent, type: .finalAttemptComplete, sessionId: sessionId, iteration: iteration, data: [
                "confidence": .double(finalAttempt.confidence),
                "entropy": .double(finalAttempt.entropy),
                "dissonance": .double(finalAttempt.dissonance),
                "healthScore": .double(finalAttempt.healthScore)
            ])

            // Compute reward
            let newSignals = BaselineSignals(
                confidence: finalAttempt.confidence,
                entropy: finalAttempt.entropy,
                dissonance: finalAttempt.dissonance,
                healthScore: finalAttempt.healthScore,
                persistenceEntropy: currentSignals.persistenceEntropy * (1 - 0.05 * Double(iteration + 1))
            )

            let reward = SOARRewardCalculator.computeReward(
                baseline: currentSignals,
                current: newSignals,
                weights: config.rewardWeights
            )
            session.rewards.append(reward)
            previousReward = reward

            // Mark stones as useful/not based on reward
            for i in session.curricula[iteration].stones.indices {
                session.curricula[iteration].stones[i].wasUseful = reward.improved
            }

            emit(onEvent, type: .rewardComputed, sessionId: sessionId, iteration: iteration, data: [
                "composite": .double(reward.composite),
                "improved": .bool(reward.improved),
                "deltaConfidence": .double(reward.deltaConfidence),
                "deltaEntropy": .double(reward.deltaEntropy),
                "deltaDissonance": .double(reward.deltaDissonance)
            ])

            // Update running signals for next iteration
            if reward.improved {
                currentSignals = newSignals
            }

            session.iterationsCompleted = iteration + 1

            let cumulativeReward = session.rewards.reduce(0) { $0 + $1.composite }
            emit(onEvent, type: .iterationComplete, sessionId: sessionId, iteration: iteration, data: [
                "iterationsCompleted": .int(iteration + 1),
                "totalIterations": .int(targetIterations),
                "cumulativeReward": .double(cumulativeReward)
            ])

            // 5. Continue or stop?
            if !reward.improved && iteration > 0 {
                break
            }
        }

        // Step 6: OOLONG Contradiction scan
        if config.contradictionDetection,
           let lastAttempt = session.finalAttempts.last {
            emit(onEvent, type: .contradictionScanStart, sessionId: sessionId, iteration: session.iterationsCompleted, data: [:])

            let scan = await ContradictionDetector.scanForContradictions(
                analysis: lastAttempt.analysis,
                maxClaims: config.maxContradictionClaims,
                llmService: llmService
            )
            session.contradictionScan = scan

            emit(onEvent, type: .contradictionScanComplete, sessionId: sessionId, iteration: session.iterationsCompleted, data: [
                "totalClaims": .int(scan.totalClaims),
                "totalComparisons": .int(scan.totalComparisons),
                "contradictionsFound": .int(scan.contradictions.count),
                "computedDissonance": .double(scan.computedDissonance)
            ])

            // Adjust final dissonance with contradiction-grounded signal
            if scan.computedDissonance > 0,
               let lastIndex = session.finalAttempts.indices.last {
                let blendedDissonance = session.finalAttempts[lastIndex].dissonance * 0.6 + scan.computedDissonance * 0.4
                session.finalAttempts[lastIndex].dissonance = blendedDissonance
            }
        }

        // Finalize session
        let bestFinal = session.finalAttempts.max(by: { $0.confidence < $1.confidence })

        if let best = bestFinal {
            session.finalSignals = BaselineSignals(
                confidence: best.confidence,
                entropy: best.entropy,
                dissonance: best.dissonance,
                healthScore: best.healthScore,
                persistenceEntropy: currentSignals.persistenceEntropy
            )
        }

        let totalReward = session.rewards.reduce(0) { $0 + $1.composite }
        session.overallImproved = totalReward > 0.01
        session.status = .complete
        session.completedAt = Date()
        session.totalDurationMs = Date().timeIntervalSince(startTime) * 1000

        emit(onEvent, type: .sessionComplete, sessionId: sessionId, iteration: session.iterationsCompleted, data: [
            "overallImproved": .bool(session.overallImproved),
            "totalReward": .double(totalReward),
            "iterationsCompleted": .int(session.iterationsCompleted),
            "finalConfidence": .double(bestFinal?.confidence ?? 0),
            "baselineConfidence": .double(baselineSignals.confidence),
            "contradictionsFound": .int(session.contradictionScan?.contradictions.count ?? 0)
        ])

        return session
    }

    // MARK: - Helpers

    private func generateSessionId() -> String {
        "soar_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16))"
    }

    private func emit(
        _ callback: (@Sendable (SOAREvent) -> Void)?,
        type: SOAREventType,
        sessionId: String,
        iteration: Int,
        data: [String: AnySendable]
    ) {
        callback?(SOAREvent(
            type: type,
            sessionId: sessionId,
            iteration: iteration,
            data: data,
            timestamp: Date()
        ))
    }
}
