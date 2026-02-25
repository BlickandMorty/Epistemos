import Foundation
import os

// MARK: - Enrichment Controller
// Namespace for all enrichment passes (2-6) and their helpers.
// Every method is static and nonisolated — no instance state, no Sendable concerns.

nonisolated enum EnrichmentController {

    // MARK: - Shared Preambles (slim identity + epistemic contract)

    /// Slim preamble — identity + epistemic contract only. No math, no methodology.
    /// Every pass gets this. Pass-specific math is injected where needed.
    static let systemPreamble = """
        You are Epistemos, a research-grade analytical reasoning engine built on a 10-stage internal pipeline followed by 6-pass enrichment. Each pass serves a distinct purpose — follow the specific instructions for THIS pass precisely.

        EPISTEMIC CONTRACT (applies to every pass):
        - Distinguish what is known vs. assumed vs. modeled vs. genuinely uncertain — and say which.
        - Never present weak evidence with strong-evidence confidence.
        - Prefer being honestly uncertain over being confidently wrong.
        - Write as if your reader is an intelligent skeptic who will challenge every unsupported claim.
        """

    /// Evidence hierarchy — injected only into passes that perform primary evidence analysis (Passes 1 & 2).
    static let evidenceHierarchy = """

        EVIDENCE HIERARCHY (weight claims accordingly):
        Tier 1: Systematic reviews, meta-analyses, Cochrane reviews, pre-registered replications
        Tier 2: Large-N RCTs (N>500), prospective cohort studies with adequate follow-up
        Tier 3: Small RCTs, case-control studies, cross-sectional surveys, well-designed observational studies
        Tier 4: Case series, expert consensus (Delphi), clinical guidelines
        Tier 5: Case reports, mechanistic reasoning, expert opinion, model-based inference, analogy
        Always state which tier your key claims rest on. Never present Tier 4-5 evidence with Tier 1-2 confidence.
        """

    /// Full epistemic standards + analytical math — injected only into Pass 2 (the primary analytical pass).
    private static let analyticsMath = """

        EPISTEMIC STANDARDS:
        - Calibrate: 90%+ requires Tier 1-2 with consistent replication; 60-89% requires Tier 2-3; below 60% for contested/unreplicated/Tier 4-5
        - Consider ≥3 competing frameworks for any non-trivial claim
        - Distinguish correlation from causation; name confounders; assess directionality
        - Reference effect sizes (Cohen's d, r, OR, RR, NNT) with 95% CI — not just p-values
        - Assess practical significance (MCID) separately from statistical significance
        - Apply base rate reasoning before interpreting conditional probabilities
        - Flag publication bias, file-drawer effects, p-hacking risk, HARKing
        - Note replication status: independently replicated? Failed replication? Never tested?
        - Assess temporal stability: recent finding or decades-old consensus?

        COGNITIVE BIAS GUARD — check for: confirmation bias, anchoring, availability bias, survivorship bias, narrative fallacy, and Dunning-Kruger overconfidence.
        """

    // MARK: - Pass 2: Raw Analysis (non-throwing wrapper)

    static func generateRawAnalysisAsync(
        query: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        controls: PipelineControls,
        steeringBias: SteeringBias?,
        soarConfig: SOARConfig?,
        llm: LLMSnapshot
    ) async -> String {
        do {
            return try await generateRawAnalysis(
                query: query,
                queryAnalysis: queryAnalysis,
                signals: signals,
                controls: controls,
                steeringBias: steeringBias,
                soarConfig: soarConfig,
                llm: llm
            )
        } catch {
            Log.pipeline.info(
                "🔬 Pass 2 HTTP ERROR — \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }

    private static func generateRawAnalysis(
        query: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        controls: PipelineControls,
        steeringBias: SteeringBias?,
        soarConfig: SOARConfig?,
        llm: LLMSnapshot
    ) async throws -> String {
        let directives = PromptComposer.compose(
            controls: controls,
            steeringBias: steeringBias,
            soarConfig: soarConfig,
            analyticsEngineEnabled: true,
            chatMode: .research
        )

        let methodologySection: String
        switch queryAnalysis.questionType {
        case .causal:
            methodologySection = """
                CAUSAL ANALYSIS FRAMEWORK:
                1. Bradford Hill criteria — systematically evaluate all 9: strength of association (effect size), consistency (replication across populations), specificity (one cause → one effect?), temporality (exposure precedes outcome?), biological gradient (dose-response?), plausibility (mechanism known?), coherence (fits broader knowledge?), experiment (interventional evidence?), analogy (similar causal pairs exist?). Score each as strong/moderate/weak/absent.
                2. Causal DAG — construct a directed acyclic graph narrative. Name every plausible confounder, mediator, and collider. Distinguish direct from indirect effects. Identify which confounders are measured vs. unmeasured.
                3. Counterfactual reasoning — what would the outcome distribution look like absent the proposed cause? Is the counterfactual testable or purely theoretical?
                4. Competing causal models — propose ≥2 alternative causal structures that could explain the same observed data. What evidence would discriminate between them?
                5. Temporal dynamics — is the causal relationship immediate, delayed, cumulative, or threshold-dependent? Does reverse causation remain plausible?
                """
        case .empirical:
            methodologySection = """
                EMPIRICAL ANALYSIS FRAMEWORK:
                1. Effect sizes — report Cohen's d, odds ratios (OR), risk ratios (RR), hazard ratios (HR), or number needed to treat (NNT) as appropriate. Always include 95% confidence intervals. Note whether the CI crosses the minimal clinically important difference (MCID) or practical significance threshold.
                2. Study landscape — reference specific landmark studies by name, first author, year, and sample size. Map the full evidence landscape: how many studies, what designs (RCT vs. observational vs. case-control), what populations, what follow-up durations?
                3. Replication audit — has the core finding been independently replicated? By how many groups? In what populations? Note any failed replications and their methodological differences.
                4. Statistical rigor — distinguish p-values from effect sizes. Flag any studies relying solely on p < 0.05 without reporting effect magnitude. Note multiple comparison corrections (Bonferroni, FDR). Assess power: were studies adequately powered to detect the claimed effect?
                5. Generalizability — WEIRD bias (Western, Educated, Industrialized, Rich, Democratic samples)? Selection effects? How does the study population map to the population of interest?
                """
        case .metaAnalytical:
            methodologySection = """
                META-ANALYTICAL FRAMEWORK:
                1. Heterogeneity assessment — report I², τ², and Q-statistic with p-value. I² > 75% = substantial heterogeneity requiring subgroup analysis or random-effects modeling.
                2. Publication bias — assess funnel plot asymmetry, Egger's regression test, trim-and-fill estimates. How many null studies would be needed to nullify the result (fail-safe N)? Is the field prone to positive-result bias?
                3. Study quality — evaluate using GRADE (certainty of evidence), RoB2 (risk of bias for RCTs), or ROBINS-I (non-randomized studies). Downgrade for serious risk of bias, inconsistency, indirectness, imprecision, or reporting bias.
                4. Moderator analysis — what variables (population, dose, duration, measurement method, study design) explain heterogeneity? Are there meaningful subgroups where the effect reverses or disappears?
                5. Temporal trends — do effect sizes shrink over time (decline effect)? Are newer, more rigorous studies finding smaller effects than older ones? What does this imply about the true effect?
                """
        case .conceptual:
            methodologySection = """
                CONCEPTUAL ANALYSIS FRAMEWORK:
                1. Framework pluralism — analyze through minimum 4 competing theoretical frameworks. For each: state its core axioms, what it predicts, what it cannot explain, and what evidence would falsify it.
                2. Genealogy of positions — trace the intellectual lineage of each framework. Who originated it? How has it evolved? What were the key debates that shaped it?
                3. Genuine conflict vs. talking past — distinguish where frameworks truly contradict each other (same phenomenon, incompatible predictions) vs. where they address different aspects or use different definitions.
                4. Conceptual dependencies — what hidden assumptions does each position rest on? What would need to be true about the world for each framework to be correct? Are these assumptions empirically testable?
                5. Synthesis potential — can frameworks be partially integrated? Is there a meta-framework that preserves the strengths of each while resolving contradictions? Or is genuine theoretical pluralism the most honest position?
                """
        default:
            methodologySection = """
                GENERAL ANALYTICAL FRAMEWORK:
                1. Evidence mapping — reference specific studies, researchers, institutions, and dates wherever possible. Distinguish peer-reviewed findings from pre-prints, expert opinion, and institutional reports.
                2. Statistical vs. practical significance — a statistically significant result (p < 0.05) may be trivially small in practice. Always ask: is the effect large enough to matter for decisions?
                3. Confound analysis — for any observational claim, name ≥3 plausible confounders. Assess whether available studies controlled for them. Note the direction of potential bias.
                4. Mechanism vs. correlation — is there a known causal mechanism, or only statistical association? How strong is the mechanistic evidence?
                5. Temporal and contextual stability — is this finding stable across decades, or recent and potentially unreplicated? Does it hold across cultures, populations, and contexts? What boundary conditions limit its applicability?
                """
        }

        let systemPrompt = """
            \(systemPreamble)
            \(evidenceHierarchy)
            \(analyticsMath)

            \(directives.isEmpty ? "" : directives + "\n\n")Generate a raw analytical output for the query below. Embed epistemic tags throughout your analysis:
            - [DATA] for claims grounded in empirical evidence or established facts
            - [MODEL] for claims based on theoretical models, frameworks, or assumptions
            - [UNCERTAIN] for claims where confidence is genuinely low or evidence is mixed
            - [CONFLICT] for claims where evidence streams actively disagree

            QUERY CONTEXT:
            - Core question: "\(queryAnalysis.coreQuestion.prefix(120))"
            - Domain: \(queryAnalysis.domain.rawValue)
            - Question type: \(queryAnalysis.questionType.rawValue)
            - Complexity: \(String(format: "%.2f", queryAnalysis.complexity))
            - Key entities: \(queryAnalysis.entities.prefix(6).joined(separator: ", "))

            PIPELINE SIGNALS:
            - Confidence: \(String(format: "%.2f", signals.confidence))
            - Entropy: \(String(format: "%.2f", signals.entropy))
            - Dissonance: \(String(format: "%.2f", signals.dissonance))
            - Focus depth: \(String(format: "%.2f", signals.focusDepth))

            RESEARCH METHODOLOGY: \(methodologySection)

            DEPTH REQUIREMENTS:
            - Write \(queryAnalysis.complexity > 0.6 ? "10-14" : "7-10") paragraphs of dense, expert-level analytical prose
            - Each paragraph introduces a distinct analytical angle, evidence stream, or counterargument
            - Include competing interpretations: at least 3-4 genuinely different ways experts interpret the evidence
            - Cross-disciplinary synthesis: draw on ≥2 adjacent fields that illuminate the question from unexpected angles
            - Temporal evolution: how has expert understanding of this topic changed over the past 10-20 years? What caused the shifts?
            - Base rate awareness: before diving into specifics, establish the prior probability or baseline context
            - End with genuine open questions: what remains unknown, contested, or unstudied? What research would resolve the key uncertainties?

            INTELLECTUAL HONESTY:
            - If the evidence points somewhere uncomfortable, follow it. Then contextualize it. Never sanitize data to avoid discomfort.
            - For any behavioral or social phenomenon, trace the causal chain: what systemic, historical, or structural inputs produced this output? Do not stop at surface-level description.
            - Name the thing people avoid saying. Then analyze why they avoid it and whether the avoidance itself is informative.
            - When frameworks contradict each other, sit in the tension. Do not resolve it prematurely. Genuine intellectual conflict is more honest than forced synthesis.
            - Distinguish what the data says from the narratives built around the data. Both are worth analyzing.
            - If your analysis contains a performative tension (e.g., claiming objectivity from a situated perspective), acknowledge it — that meta-awareness strengthens rather than weakens the analysis.

            FORMAT: Do NOT use markdown headers or bullet lists — write flowing analytical prose. Embed [DATA], [MODEL], [UNCERTAIN], [CONFLICT] tags inline within sentences. Every claim tagged [DATA] must reference a specific study, dataset, or established finding. Every [MODEL] tag must name the framework or theory.

            CITATION INTEGRITY: Do NOT fabricate citations. If you reference a study, you must be confident it exists — include real author names, approximate year, and journal/source. If a claim rests on broad scientific consensus rather than a specific paper, say "broad scientific consensus" or "established finding in [field]" instead of inventing a reference. It is better to cite fewer real sources than many plausible-sounding fake ones.
            """

        let userPrompt =
            "Analyze this query through the full Epistemos pipeline: \"\(queryAnalysis.coreQuestion)\""

        // Research mode always uses cloud API — never Apple Intelligence.
        // Apple Intelligence is too limited for deep analytical prose.
        // Uses nonisolated static generate to avoid MainActor deadlock in enrichment.
        // Pass 2 is the heaviest pass (6000 tokens, massive system prompt).
        // Observed: 84.1s for 4000 tokens with Opus 4.6 (~21ms/token).
        // 6000 tokens ≈ 126s typical; timeout=200s covers slow API days.
        // Previous cap of 4000 tokens caused mid-sentence truncation — downstream
        // passes (3-6) diagnosed the cut-off and flagged it in their output.
        return try await LLMService.generate(
            snapshot: llm,
            prompt: userPrompt,
            systemPrompt: systemPrompt,
            maxTokens: 6000,
            timeout: 600
        )
    }

    // MARK: - Pass 3: Layman Summary

    static func generateLaymanSummary(
        query: String,
        rawAnalysis: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        llm: LLMSnapshot
    ) async -> LaymanSummary {
        let (label1, label2, label3, label4, label5): (String, String, String, String, String)
        switch queryAnalysis.questionType {
        case .causal:
            (label1, label2, label3, label4, label5) = (
                "Causal analysis", "Probable relationship", "Causal certainty",
                "Alternative explanations", "Decision relevance"
            )
        case .empirical:
            (label1, label2, label3, label4, label5) = (
                "Methodology", "Key findings", "Evidence strength", "Limitations & gaps",
                "Applicability"
            )
        case .conceptual:
            (label1, label2, label3, label4, label5) = (
                "Conceptual landscape", "Most defensible position", "Epistemic status",
                "Key objections", "Who this matters to"
            )
        case .comparative:
            (label1, label2, label3, label4, label5) = (
                "Comparison framework", "Key differences", "Confidence in comparison",
                "What changes the verdict", "Context dependency"
            )
        default:
            (label1, label2, label3, label4, label5) = (
                "Approach taken", "Most likely true", "Confidence level", "What could change this",
                "Who should use this"
            )
        }

        let systemPrompt = """
            \(systemPreamble)

            Based on the raw analytical output below, generate a 5-section structured summary that translates expert analysis into accessible insight. Reply with ONLY valid JSON, no markdown fences.

            QUERY: \(query)
            DOMAIN: \(queryAnalysis.domain.rawValue) | COMPLEXITY: \(String(format: "%.2f", queryAnalysis.complexity))

            RAW ANALYSIS:
            \(rawAnalysis.prefix(8000))

            SECTION GUIDANCE:

            1. "\(label1)" (whatWasTried) — 4-6 sentences. Describe the analytical approach: what evidence was examined, which methodologies were applied, what frameworks were tested against each other. Name specific techniques (e.g., "Bradford Hill causal criteria", "meta-analytic pooling", "Bayesian updating"). The reader should understand HOW the analysis was conducted, not just WHAT was found.

            2. "\(label2)" (whatIsLikelyTrue) — 8-15 sentences with markdown formatting. This is the MAIN ANSWER. Lead with the strongest conclusion, then build supporting evidence. Use concrete examples and analogies to make abstract findings tangible. Quantify where possible ("roughly 2x more likely", "affects ~30% of cases"). Acknowledge what the evidence does NOT support, not just what it does. End with the single most important takeaway.

            3. "\(label3)" (confidenceExplanation) — 4-6 sentences. Map confidence to everyday decision-making: "confident enough to act on" vs. "interesting but preliminary" vs. "genuinely uncertain — reasonable experts disagree." Explain WHAT DRIVES the confidence level (replication, effect size, mechanistic understanding) rather than just stating a number. Name the single biggest source of uncertainty.

            4. "\(label4)" (whatCouldChange) — 4-6 sentences. Be specific: name the type of study, finding, or event that would shift the conclusion. Distinguish between "would strengthen" vs. "would weaken" vs. "would overturn." Include both empirical possibilities (new RCT, failed replication) and conceptual shifts (new framework, paradigm change).

            5. "\(label5)" (whoShouldTrust) — 4-6 sentences. Help the reader calibrate: who can safely act on this analysis? Who should wait for more evidence? What decisions does this analysis inform vs. which ones need additional domain-specific context? Note any populations, contexts, or use cases where the conclusions may not apply.

            IMPORTANT: Generate fields in EXACTLY this order. The first field ("whatWasTried") is your reasoning scaffold — think through the methodology BEFORE committing to conclusions in later fields. LLMs produce better answers when they reason before concluding.

            OUTPUT FORMAT (JSON only):
            {
              "whatWasTried": "\(label1) section — write this FIRST as your reasoning foundation",
              "whatIsLikelyTrue": "\(label2) section with markdown — the main answer, informed by the reasoning above",
              "confidenceExplanation": "\(label3) section",
              "whatCouldChange": "\(label4) section",
              "whoShouldTrust": "\(label5) section"
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt:
                    "Synthesize the raw analysis into a structured, accessible 5-section summary for: \"\(queryAnalysis.coreQuestion)\"",
                systemPrompt: systemPrompt,
                maxTokens: 2000,
                timeout: 270
            )
            guard let obj = extractJSON(from: raw) else {
                Log.pipeline.info(
                    "🔬 Pass 3 JSON PARSE FAILED — raw length=\(raw.count) first100=\(String(raw.prefix(100)))"
                )
                return fallbackLaymanSummary(queryAnalysis: queryAnalysis, signals: signals)
            }
            let fallback = fallbackLaymanSummary(queryAnalysis: queryAnalysis, signals: signals)
            return LaymanSummary(
                whatWasTried: obj["whatWasTried"] as? String ?? fallback.whatWasTried,
                whatIsLikelyTrue: obj["whatIsLikelyTrue"] as? String ?? fallback.whatIsLikelyTrue,
                confidenceExplanation: obj["confidenceExplanation"] as? String
                    ?? fallback.confidenceExplanation,
                whatCouldChange: obj["whatCouldChange"] as? String ?? fallback.whatCouldChange,
                whoShouldTrust: obj["whoShouldTrust"] as? String ?? fallback.whoShouldTrust,
                sectionLabels: SectionLabels(
                    whatWasTried: label1, whatIsLikelyTrue: label2,
                    confidenceExplanation: label3, whatCouldChange: label4, whoShouldTrust: label5
                )
            )
        } catch {
            Log.pipeline.info("🔬 Pass 3 HTTP ERROR — \(error.localizedDescription)")
            return fallbackLaymanSummary(queryAnalysis: queryAnalysis, signals: signals)
        }
    }

    // MARK: - Pass 4: Reflection (adversarial self-critique)

    static func generateReflection(
        query: String,
        rawAnalysis: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        llm: LLMSnapshot
    ) async -> ReflectionResult {
        let systemPrompt = """
            \(systemPreamble)

            You are now in ADVERSARIAL SELF-CRITIQUE mode. Your sole purpose is to find weaknesses, gaps, and overstatements in the analysis below. Adopt the mindset of a hostile peer reviewer whose reputation depends on finding flaws.

            QUERY: \(query)
            DOMAIN: \(queryAnalysis.domain.rawValue) | COMPLEXITY: \(String(format: "%.2f", queryAnalysis.complexity))

            PIPELINE SIGNALS:
            - Confidence: \(String(format: "%.2f", signals.confidence)) | Entropy: \(String(format: "%.2f", signals.entropy)) | Dissonance: \(String(format: "%.2f", signals.dissonance))

            RAW ANALYSIS:
            \(rawAnalysis.prefix(6000))

            ADVERSARIAL TECHNIQUES TO APPLY:
            1. Steel-man test — construct the STRONGEST possible counterargument to the main conclusion. If you can build a compelling case against it, the analysis needs qualification.
            2. Reductio ad absurdum — push the analysis's logic to its extreme. Does it lead to absurd conclusions at the margins? If so, where does the reasoning break down?
            3. Edge case analysis — identify 2-3 scenarios where the conclusion would fail, reverse, or become meaningless. How common are these edge cases?
            4. Missing evidence audit — what evidence SHOULD have been discussed but wasn't? What studies or data would a domain expert expect to see cited?
            5. Survivorship bias check — is the analysis only considering successful/visible examples? What about the failures, null results, or unreported cases?
            6. Anchoring detection — did the analysis anchor on the first piece of evidence and insufficiently update? Would the conclusion change if evidence were considered in a different order?

            COGNITIVE BIAS CHECKLIST — flag if any are present in the analysis:
            □ Confirmation bias (seeking only supporting evidence)
            □ Availability bias (overweighting memorable/recent examples)
            □ Authority bias (accepting claims because of source prestige)
            □ Narrative fallacy (imposing a coherent story on messy data)
            □ Precision bias (false specificity beyond what evidence supports)
            □ Status quo bias (defaulting to conventional wisdom without testing it)

            Reply with ONLY valid JSON:
            {
              "selfCriticalQuestions": ["5-7 pointed questions that expose genuine weaknesses — each should be specific enough that it could change the conclusion if answered differently"],
              "adjustments": ["3-5 specific confidence adjustments — format each as: 'CLAIM: [specific claim] → ADJUSTMENT: [direction and magnitude] → REASON: [why]'"],
              "leastDefensibleClaim": "The single claim most vulnerable to challenge — explain exactly WHY it is weak and what evidence would be needed to strengthen it",
              "precisionVsEvidenceCheck": "A thorough assessment: does the analysis claim more precision than the evidence warrants? Are confidence intervals appropriate? Are qualitative claims dressed up as quantitative ones?",
              "biasesDetected": ["List any cognitive biases detected from the checklist above, with specific examples from the analysis"],
              "whatWouldChangeMyMind": "Name 1-3 specific findings, studies, or pieces of evidence that — if they existed — would substantially change the analysis's conclusions"
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt:
                    "Perform adversarial self-critique on the analysis. Be ruthlessly honest about weaknesses.",
                systemPrompt: systemPrompt,
                maxTokens: 3000,
                timeout: 270
            )
            guard let obj = extractJSON(from: raw) else {
                Log.pipeline.info(
                    "🔬 Pass 4 JSON PARSE FAILED — raw length=\(raw.count) first100=\(String(raw.prefix(100)))"
                )
                return fallbackReflection(signals: signals)
            }
            let fallback = fallbackReflection(signals: signals)
            return ReflectionResult(
                selfCriticalQuestions: obj["selfCriticalQuestions"] as? [String]
                    ?? fallback.selfCriticalQuestions,
                adjustments: obj["adjustments"] as? [String] ?? [],
                leastDefensibleClaim: obj["leastDefensibleClaim"] as? String
                    ?? fallback.leastDefensibleClaim,
                precisionVsEvidenceCheck: obj["precisionVsEvidenceCheck"] as? String
                    ?? fallback.precisionVsEvidenceCheck
            )
        } catch {
            Log.pipeline.info("🔬 Pass 4 HTTP ERROR — \(error.localizedDescription)")
            return fallbackReflection(signals: signals)
        }
    }

    // MARK: - Pass 5: Arbitration (multi-engine vote)

    static func generateArbitration(
        query: String,
        rawAnalysis: String,
        queryAnalysis: QueryAnalysis,
        signals: GeneratedSignals,
        llm: LLMSnapshot
    ) async -> ArbitrationResult {
        let systemPrompt = """
            \(systemPreamble)

            You are in MULTI-ENGINE ARBITRATION mode. Simulate a panel of 5 independent analytical engines, each with a distinct epistemological lens. Each engine must evaluate the analysis INDEPENDENTLY — do not let engines agree by default. Genuine disagreement is valuable.

            QUERY: \(query)
            DOMAIN: \(queryAnalysis.domain.rawValue) | COMPLEXITY: \(String(format: "%.2f", queryAnalysis.complexity))
            SIGNALS: confidence=\(String(format: "%.2f", signals.confidence)), entropy=\(String(format: "%.2f", signals.entropy)), dissonance=\(String(format: "%.2f", signals.dissonance))

            RAW ANALYSIS:
            \(rawAnalysis.prefix(6000))

            ENGINE PERSONAS — each engine has a distinct analytical identity:

            1. STATISTICAL ENGINE — thinks in distributions, sample sizes, and effect magnitudes. Asks: "What does the data actually show when analyzed rigorously?" Demands: adequate power, appropriate tests, reported effect sizes with CIs, correction for multiple comparisons. Suspicious of: small samples, p-hacking, garden of forking paths. Confidence calibration: high only for well-powered, pre-registered, replicated findings.

            2. CAUSAL ENGINE — thinks in mechanisms, counterfactuals, and DAGs. Asks: "Does this establish causation, or merely association?" Demands: temporal precedence, plausible mechanism, control for confounders, ideally interventional evidence. Suspicious of: reverse causation, omitted variable bias, ecological fallacy. Confidence calibration: high only when causal pathway is established through experiment or strong quasi-experimental design.

            3. BAYESIAN ENGINE — thinks in priors, updating, and probability distributions. Asks: "How should a rational agent update their beliefs given this evidence?" Demands: explicit priors, likelihood ratios, posterior distributions. Considers base rates before interpreting new evidence. Suspicious of: base rate neglect, failure to update, overweighting single studies. Confidence calibration: posterior probability given reasonable prior and evidence strength.

            4. META-ANALYSIS ENGINE — thinks in synthesis, heterogeneity, and evidence aggregation. Asks: "What does the totality of evidence say when all studies are considered together?" Demands: systematic search, quality assessment, heterogeneity analysis, publication bias tests. Suspicious of: cherry-picked studies, narrative reviews masquerading as systematic ones, vote-counting instead of pooling. Confidence calibration: high only for well-conducted meta-analyses with low heterogeneity.

            5. ADVERSARIAL ENGINE — thinks in failure modes, steel-manned objections, and worst-case scenarios. Asks: "What is the strongest argument AGAINST the conclusion?" Demands: every major objection addressed, edge cases considered, failure modes mapped. Suspicious of: unfalsifiable claims, consensus without dissent, arguments from authority. Confidence calibration: deliberately lower than other engines — anchors the group toward caution.

            CONSENSUS RULES:
            - Consensus = true ONLY if ≥4 engines agree on position (supports/opposes/neutral)
            - If exactly 3 agree, consensus = false — note the split
            - Each engine's confidence must reflect its own epistemological standards, NOT the group average
            - The adversarial engine should RARELY agree with the majority — if it does, the evidence is genuinely strong

            Each engine's "reasoning" must be 2-4 sentences explaining its position FROM ITS OWN epistemological framework. No engine should reference what another engine thinks.

            Reply with ONLY valid JSON:
            {
              "consensus": true or false,
              "votes": [
                {"engine": "statistical", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences from statistical perspective", "confidence": 0.0-1.0},
                {"engine": "causal", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences from causal perspective", "confidence": 0.0-1.0},
                {"engine": "bayesian", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences from Bayesian perspective", "confidence": 0.0-1.0},
                {"engine": "meta_analysis", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences from meta-analytic perspective", "confidence": 0.0-1.0},
                {"engine": "adversarial", "position": "supports|opposes|neutral", "reasoning": "2-4 sentences — strongest counterargument", "confidence": 0.0-1.0}
              ],
              "disagreements": ["2-4 specific points where engines disagree, naming which engines and why"],
              "resolution": "2-4 sentence synthesis: given the panel's votes, what is the most defensible overall position? How should the disagreements be weighted?"
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt:
                    "Convene the 5-engine arbitration panel. Each engine must reason independently from its own epistemological framework.",
                systemPrompt: systemPrompt,
                maxTokens: 3000,
                timeout: 270
            )
            guard let obj = extractJSON(from: raw),
                let votesRaw = obj["votes"] as? [[String: Any]]
            else {
                Log.pipeline.info(
                    "🔬 Pass 5 JSON PARSE FAILED — raw length=\(raw.count) first100=\(String(raw.prefix(100)))"
                )
                return fallbackArbitration(signals: signals)
            }

            let votes: [EngineVote] = votesRaw.compactMap { v in
                guard let engineStr = v["engine"] as? String,
                    let posStr = v["position"] as? String,
                    let reasoning = v["reasoning"] as? String,
                    let confidence = v["confidence"] as? Double
                else { return nil }
                let stage = PipelineStage(rawValue: engineStr.uppercased()) ?? .statistical
                let position: VotePosition =
                    posStr == "supports" ? .supports : posStr == "opposes" ? .opposes : .neutral
                return EngineVote(
                    engine: stage, position: position, reasoning: reasoning, confidence: confidence)
            }

            let fallback = fallbackArbitration(signals: signals)
            return ArbitrationResult(
                consensus: obj["consensus"] as? Bool ?? (signals.confidence > 0.65),
                votes: votes.isEmpty ? fallback.votes : votes,
                disagreements: obj["disagreements"] as? [String] ?? [],
                resolution: obj["resolution"] as? String ?? fallback.resolution
            )
        } catch {
            Log.pipeline.info("🔬 Pass 5 HTTP ERROR — \(error.localizedDescription)")
            return fallbackArbitration(signals: signals)
        }
    }

    // MARK: - Pass 6: Truth Assessment

    static func generateTruthAssessment(
        query: String,
        rawAnalysis: String,
        signals: GeneratedSignals,
        reflection: ReflectionResult,
        arbitration: ArbitrationResult,
        llm: LLMSnapshot
    ) async -> TruthAssessment {
        let tagCounts = countEpistemicTags(in: rawAnalysis)

        // Build arbitration vote summary for truth assessment context
        let voteSummary = arbitration.votes.map { v in
            "\(v.engine.rawValue.lowercased()): \(v.position == .supports ? "supports" : v.position == .opposes ? "opposes" : "neutral") (conf: \(String(format: "%.2f", v.confidence)))"
        }.joined(separator: " | ")

        // Compute DINCO-lite divergence metric from arbitration votes
        let voteConfidences = arbitration.votes.map(\.confidence)
        let avgConf =
            voteConfidences.isEmpty
            ? 0.5 : voteConfidences.reduce(0, +) / Double(voteConfidences.count)
        let confVariance =
            voteConfidences.isEmpty
            ? 0.0
            : voteConfidences.map { ($0 - avgConf) * ($0 - avgConf) }.reduce(0, +)
                / Double(voteConfidences.count)
        let supportCount = arbitration.votes.filter { $0.position == .supports }.count
        let opposeCount = arbitration.votes.filter { $0.position == .opposes }.count
        let neutralCount = arbitration.votes.filter { $0.position == .neutral }.count

        let systemPrompt = """
            \(systemPreamble)

            You are in FINAL TRUTH CALIBRATION mode. This is Pass 6 of 6 — the terminal pass. All prior analysis, critique, and arbitration feeds into your assessment. Your job: produce an honest, well-calibrated confidence estimate that a domain expert would respect.

            ═══════════════════════════════════════════════════════════
            TECHNIQUE: REASON FIRST, THEN COMMIT (CoT-then-Confidence)
            ═══════════════════════════════════════════════════════════

            DO NOT pick a number first and rationalize it. Instead:
            1. Review ALL evidence streams below
            2. Identify what pushes confidence UP vs. DOWN
            3. Weigh the competing forces
            4. THEN — and only then — commit to overallTruthLikelihood

            This is critical because LLMs systematically default to 0.6-0.8 out of hedging instinct. Override that instinct by reasoning explicitly.

            ═══════════════════════════════════════════════════════════
            CALIBRATION ANCHORS (from calibration research)
            ═══════════════════════════════════════════════════════════

            0.90-0.95 — NEAR-CERTAIN
            Requirements: Tier 1-2 evidence, independently replicated ≥3 times, strong mechanism understood, expert consensus with no serious dissent. Domain: established for decades.
            Examples: "smoking causes lung cancer", "vaccines prevent measles", "aspirin inhibits COX enzymes"
            If you rate 0.90+, you are claiming THIS level of certainty. Most questions don't qualify.

            0.70-0.89 — PROBABLE
            Requirements: Tier 2-3 evidence, partially replicated, plausible mechanism, majority expert agreement. Some debate on magnitude/boundaries but not direction.
            Examples: "Mediterranean diet reduces cardiovascular risk", "sleep deprivation impairs cognitive function"

            0.50-0.69 — UNCERTAIN-LEANING
            Requirements: Mixed evidence, active expert debate. Tier 3-4 evidence, limited or no replication. Competing explanations remain plausible. Direction seems right, magnitude unclear.
            Examples: "moderate alcohol consumption is cardioprotective" (heavily debated), "social media causes depression in teens" (correlational)

            0.30-0.49 — GENUINELY UNCERTAIN
            Requirements: Evidence is thin, conflicting, or the domain is too new. Reasonable experts hold opposing views. Multiple unfalsified competing models.
            Examples: Questions about emerging technologies, contested social science, mechanisms not yet established.

            0.05-0.29 — UNLIKELY AS STATED
            Requirements: Evidence actively contradicts the claim, OR claim rests on Tier 5 evidence only, OR extraordinary claim without extraordinary evidence.

            ═══════════════════════════════════════════════════════════
            EVIDENCE STREAMS TO INTEGRATE
            ═══════════════════════════════════════════════════════════

            STREAM 1 — PIPELINE SIGNALS (computational):
            - Raw confidence: \(String(format: "%.2f", signals.confidence))
            - Entropy: \(String(format: "%.2f", signals.entropy)) (higher = more uncertainty)
            - Dissonance: \(String(format: "%.2f", signals.dissonance)) (higher = more internal contradiction)
            - Health score: \(String(format: "%.2f", signals.healthScore))

            STREAM 2 — EPISTEMIC TAG DISTRIBUTION (from Pass 2 analysis):
            - [DATA] claims: \(tagCounts.data) | [MODEL] claims: \(tagCounts.model) | [UNCERTAIN] claims: \(tagCounts.uncertain) | [CONFLICT] claims: \(tagCounts.conflict)
            - Data-grounding ratio: \(tagCounts.data + tagCounts.model > 0 ? String(format: "%.0f%%", Double(tagCounts.data) / Double(tagCounts.data + tagCounts.model) * 100) : "N/A")
            - Interpretation: High [DATA] with low [CONFLICT] → higher confidence. High [UNCERTAIN]/[CONFLICT] → lower confidence.

            STREAM 3 — SELF-CRITIQUE (from Pass 4 — adversarial reflection):
            - Critical questions raised: \(reflection.selfCriticalQuestions.joined(separator: " | "))
            - Least defensible claim: \(reflection.leastDefensibleClaim)
            - Precision-vs-evidence check: \(reflection.precisionVsEvidenceCheck)
            - If the self-critique found serious issues, LOWER your confidence. If critique was mostly minor, this supports the analysis.

            STREAM 4 — ARBITRATION PANEL (from Pass 5 — 5-engine vote):
            - Consensus reached: \(arbitration.consensus)
            - Vote breakdown: supports=\(supportCount), opposes=\(opposeCount), neutral=\(neutralCount)
            - Engine votes: \(voteSummary)
            - Vote confidence variance: \(String(format: "%.3f", confVariance)) (higher = more engine disagreement)
            - Average engine confidence: \(String(format: "%.2f", avgConf))
            - Disagreements: \(arbitration.disagreements.joined(separator: "; ").ifEmpty("none"))
            - Panel resolution: \(arbitration.resolution)

            STREAM 5 — DINCO-LITE CROSS-CHECK (distractor-normalized coherence):
            The arbitration panel functions as a multi-hypothesis test. Each engine that opposes or rates low confidence is a "distractor" — a plausible alternative assessment that the evidence should be weaker.
            - If all 5 engines agree (variance < 0.01): evidence is genuinely strong OR the question is easy. Check: is it actually easy, or are the engines just defaulting to agreement?
            - If adversarial engine agrees with majority: unusually strong evidence (this engine is designed to dissent)
            - If ≥2 engines oppose: the claim has serious vulnerabilities regardless of majority support
            - Normalized confidence = (supporting engine avg conf) / (supporting avg + opposing avg). Use this as a cross-check against your final number.

            ═══════════════════════════════════════════════════════════
            OVERPOWERED REASONING ENGINE: META-ANALYTICAL COACHING
            ═══════════════════════════════════════════════════════════
            Your goal is to make the user an "Accurate Thinker" by auditing their knowledge.
            1. AUDIT COMPLEXITY: Identify if the note is a "Surface Summary" vs "Deep Insight".
            2. DETECT DISSONANCE: Find logical gaps or contradictions within the note itself or between the note and known data.
            3. RECOMMEND STUDY PATHS: Based on low-confidence areas or high entropy, tell the user EXACTLY what to research next.
            4. NOTE-TAKING REFINEMENT: Suggest how to restructure the note (e.g., "Use a more comparative framework here", "Link to concept Y to resolve Z").

            Treat "improvements" and "recommendedActions" as a COGNITIVE COACHING layer.

            ═══════════════════════════════════════════════════════════
            HARD CALIBRATION RULES (override hedging instinct)
            ═══════════════════════════════════════════════════════════

            Rule 1: NO CONSENSUS → cap at 0.70 (unless only the adversarial engine dissented)
            Rule 2: [CONFLICT] ≥ [DATA] → cap at 0.60
            Rule 3: ≥2 engines oppose → cap at 0.55 regardless of other signals
            Rule 4: Entropy > 0.7 AND dissonance > 0.5 → cap at 0.50
            Rule 5: If ALL evidence is Tier 4-5 (no empirical studies cited) → cap at 0.45
            Rule 6: If the self-critique identified ≥3 serious unresolved questions → reduce by 0.10
            Rule 7: Do NOT round to convenient numbers (0.50, 0.70, 0.80). Use precise values like 0.63, 0.47, 0.82.

            ═══════════════════════════════════════════════════════════
            OUTPUT FORMAT — REASONING FIRST, THEN NUMBER
            ═══════════════════════════════════════════════════════════

            CRITICAL: Generate fields in EXACTLY this order. The signalInterpretation field comes FIRST — this is where you reason through all 5 evidence streams BEFORE committing to a number. Research shows this ordering produces better-calibrated estimates.

            ⚠️ OUTPUT RULE: Your response MUST begin with the opening brace `{`. Do NOT write any prose, preamble, or explanation before the JSON object. Do NOT use markdown code fences. Your chain-of-thought reasoning goes INSIDE the "signalInterpretation" field — that is the correct place for it.

            Reply with ONLY valid JSON — start your response with `{`:
            {
              "signalInterpretation": "4-6 sentences. Walk through each evidence stream: what pushes confidence UP? What pushes it DOWN? Which stream carries the most weight and why? Name the single most influential factor. This is your reasoning — do it thoroughly BEFORE deciding the number below.",
              "overallTruthLikelihood": 0.05-0.95,
              "weaknesses": ["3-5 specific, actionable weaknesses — not generic statements like 'more research needed' but specific gaps like 'no RCTs on this population' or 'effect size unreplicated outside original lab'"],
              "improvements": ["3-5 specific improvements — name the exact type of study, evidence, or analysis that would move the needle"],
              "blindSpots": ["2-4 areas the analysis may have missed entirely — populations not considered, timeframes ignored, adjacent fields not consulted"],
              "confidenceCalibration": "2-3 sentences: Cross-check your number against the calibration anchors above. Would a domain expert in \(query.prefix(30)) agree? What would they push back on? Is there a reference class of similar questions where the typical accuracy is known?",
              "dataVsModelBalance": "X% data-driven, Y% model-based, Z% heuristic — must sum to 100%. 'Data' = grounded in specific cited findings. 'Model' = derived from theoretical frameworks. 'Heuristic' = based on expert judgment, analogy, or reasoning without direct evidence.",
              "recommendedActions": ["3-5 next steps, each prefixed with one of: [ACT NOW], [WAIT], or [INVESTIGATE] to indicate urgency level"]
            }
            """

        do {
            let raw = try await LLMService.generate(
                snapshot: llm,
                prompt:
                    "Perform final truth calibration using CoT-then-Confidence: reason through all 5 evidence streams first, THEN commit to a calibrated number. Do not default to 0.5-0.7.",
                systemPrompt: systemPrompt,
                maxTokens: 3000,
                timeout: 270
            )
            guard let obj = extractJSON(from: raw) else {
                Log.pipeline.info(
                    "🔬 Pass 6 JSON PARSE FAILED — raw length=\(raw.count) first100=\(String(raw.prefix(100)))"
                )
                return fallbackTruthAssessment(signals: signals)
            }

            let fallback = fallbackTruthAssessment(signals: signals)
            let likelihood = min(
                0.95, max(0.05, obj["overallTruthLikelihood"] as? Double ?? signals.confidence))
            return TruthAssessment(
                overallTruthLikelihood: likelihood,
                signalInterpretation: obj["signalInterpretation"] as? String
                    ?? fallback.signalInterpretation,
                weaknesses: obj["weaknesses"] as? [String] ?? fallback.weaknesses,
                improvements: obj["improvements"] as? [String] ?? fallback.improvements,
                blindSpots: obj["blindSpots"] as? [String] ?? fallback.blindSpots,
                confidenceCalibration: obj["confidenceCalibration"] as? String
                    ?? fallback.confidenceCalibration,
                dataVsModelBalance: obj["dataVsModelBalance"] as? String
                    ?? fallback.dataVsModelBalance,
                recommendedActions: obj["recommendedActions"] as? [String]
                    ?? fallback.recommendedActions
            )
        } catch {
            Log.pipeline.info("🔬 Pass 6 HTTP ERROR — \(error.localizedDescription)")
            return fallbackTruthAssessment(signals: signals)
        }
    }

    // MARK: - Helpers

    /// Extracts the outermost JSON object from a string.
    /// Handles: markdown code fences (```json...```), <thinking> blocks,
    /// and prose-before-JSON (model writes reasoning before the JSON object).
    private static func extractJSON(from text: String) -> [String: Any]? {
        // 1. Strip <thinking> blocks (extended thinking models)
        var cleaned = text.replacingOccurrences(
            of: "<thinking>[\\s\\S]*?</thinking>",
            with: "",
            options: .regularExpression
        )
        // 2. Strip markdown code fences — LLMs commonly wrap JSON in ```json ... ```
        //    This is the #1 cause of JSON parse failures (observed in Passes 4, 5).
        cleaned = cleaned.replacingOccurrences(
            of: "```json", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Find the outermost { ... } — using balanced counting to handle
        //    prose-before-JSON (model writes text then produces JSON block).
        //    We scan forward from each '{' and check if it produces valid JSON.
        guard let firstBrace = cleaned.firstIndex(of: "{"),
            let lastBrace = cleaned.lastIndex(of: "}")
        else {
            Log.pipeline.info(
                "🔬 extractJSON: no braces in \(cleaned.count) chars — first80=\(String(cleaned.prefix(80)))"
            )
            return nil
        }
        let jsonStr = String(cleaned[firstBrace...lastBrace])
        guard let data = jsonStr.data(using: .utf8) else {
            Log.pipeline.info("🔬 extractJSON: UTF-8 encoding failed")
            return nil
        }
        do {
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Log.pipeline.info("🔬 extractJSON: not [String:Any] — jsonLen=\(jsonStr.count)")
                return nil
            }
            return obj
        } catch {
            // Log first 200 chars of the attempted JSON so we can see exactly what failed
            Log.pipeline.info(
                "🔬 extractJSON FAILED — \(error.localizedDescription, privacy: .public) jsonLen=\(jsonStr.count) first200=\(String(jsonStr.prefix(200)))"
            )
            return nil
        }
    }

    private struct TagCounts {
        var data = 0
        var model = 0
        var uncertain = 0
        var conflict = 0
    }

    private static func countEpistemicTags(in text: String) -> TagCounts {
        var counts = TagCounts()
        counts.data = text.components(separatedBy: "[DATA]").count - 1
        counts.model = text.components(separatedBy: "[MODEL]").count - 1
        counts.uncertain = text.components(separatedBy: "[UNCERTAIN]").count - 1
        counts.conflict = text.components(separatedBy: "[CONFLICT]").count - 1
        return counts
    }

    static func extractUncertaintyTags(from text: String) -> [UncertaintyTag] {
        var tags: [UncertaintyTag] = []
        let pattern =
            #"\[(UNCERTAIN|CONFLICT|MODEL|DATA)\]\s*(.{15,200}?)(?=\s*\[(?:UNCERTAIN|CONFLICT|MODEL|DATA)\]|\z)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        for match in matches.prefix(8) {
            guard let tagRange = Range(match.range(at: 1), in: text),
                let claimRange = Range(match.range(at: 2), in: text)
            else { continue }
            let tagStr = String(text[tagRange])
            let claim = String(text[claimRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tag: UncertaintyTagType =
                tagStr == "UNCERTAIN"
                ? .uncertain : tagStr == "CONFLICT" ? .conflict : tagStr == "MODEL" ? .model : .data
            tags.append(UncertaintyTag(claim: claim, tag: tag))
        }
        return tags
    }

    // MARK: - LLM Concept Tag Parsing

    /// Parses [CONCEPTS: concept1, concept2, ...] from the end of an LLM response.
    /// Returns the parsed concepts and the response text with the tag stripped.
    /// If no tag found, returns empty concepts and original text.
    static func parseConceptsTag(from text: String) -> (
        concepts: [String], cleanedText: String
    ) {
        // Match [CONCEPTS: ...] anywhere (typically at the end)
        guard
            let regex = try? NSRegularExpression(
                pattern: #"\[CONCEPTS:\s*(.+?)\]\s*$"#,
                options: [.anchorsMatchLines]
            )
        else {
            return ([], text)
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        guard let match = regex.firstMatch(in: text, range: range),
            let conceptsRange = Range(match.range(at: 1), in: text)
        else {
            return ([], text)
        }

        // Parse comma-separated concepts
        let rawConcepts = String(text[conceptsRange])
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count >= 2 }
            .prefix(8)

        // Strip the tag line from displayed text
        guard let fullRange = Range(match.range, in: text) else {
            return (Array(rawConcepts), text)
        }
        var cleaned = String(text[text.startIndex..<fullRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Also strip "## Concept Tag" / "### Concept Tag" headings that the LLM
        // sometimes generates before the [CONCEPTS: ...] tag. Without this, the
        // heading remains with nothing after it — showing an empty "Concept Tag" label.
        if let headingRegex = try? NSRegularExpression(
            pattern: #"(?m)^#{1,4}\s*Concept\s*Tags?\s*\n*$"#,
            options: [.caseInsensitive]
        ) {
            cleaned = headingRegex.stringByReplacingMatches(
                in: cleaned,
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (Array(rawConcepts), cleaned)
    }

    // MARK: - Concept Extraction (Fallback)

    /// Fallback: extracts domain concepts via regex heuristics when the LLM
    /// doesn't include a [CONCEPTS: ...] tag.
    static func extractResponseConcepts(
        from text: String,
        queryEntities: [String]
    ) -> [String] {
        var conceptCandidates: [String: Int] = [:]

        // 1. Capitalized multi-word phrases (e.g., "Bayesian Inference", "Criminal Justice System")
        let capitalizedPattern = #"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)\b"#
        if let regex = try? NSRegularExpression(pattern: capitalizedPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range, in: text) else { continue }
                let phrase = String(text[r]).trimmingCharacters(in: .whitespaces)
                if phrase.count >= 4 && phrase.count <= 40 {
                    conceptCandidates[phrase, default: 0] += 2
                }
            }
        }

        // 2. Quoted terms (e.g., "recidivism", "moral desert")
        let quotedPattern = #"["""]([^"""]{3,30})["""]"#
        if let regex = try? NSRegularExpression(pattern: quotedPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let term = String(text[r]).trimmingCharacters(in: .whitespaces)
                if term.count >= 3 {
                    conceptCandidates[term, default: 0] += 2
                }
            }
        }

        // 3. Frequency-based domain words (appear ≥ 2 times, not stop words)
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 4 && !QueryAnalyzer.stopWords.contains($0) }
        var freq: [String: Int] = [:]
        for w in words { freq[w, default: 0] += 1 }
        for (word, count) in freq where count >= 2 {
            let titleCased = word.prefix(1).uppercased() + word.dropFirst()
            conceptCandidates[titleCased, default: 0] += count
        }

        // 4. Boost query entities that appear in the response
        let lowerText = text.lowercased()
        for entity in queryEntities where lowerText.contains(entity.lowercased()) {
            let titleCased = entity.prefix(1).uppercased() + entity.dropFirst()
            conceptCandidates[titleCased, default: 0] += 3
        }

        // Sort by score, deduplicate case-insensitively, limit to 8
        let sorted =
            conceptCandidates
            .sorted { $0.value > $1.value }
            .map(\.key)

        var seen: Set<String> = []
        var result: [String] = []
        for concept in sorted {
            let key = concept.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(concept)
            if result.count >= 8 { break }
        }
        return result
    }

    // MARK: - Fallbacks

    static func fallbackLaymanSummary(
        queryAnalysis: QueryAnalysis, signals: GeneratedSignals
    ) -> LaymanSummary {
        LaymanSummary(
            whatWasTried:
                "Structured meta-analytical reasoning was applied to \"\(queryAnalysis.coreQuestion.prefix(80))\".",
            whatIsLikelyTrue: queryAnalysis.isPhilosophical
                ? "This is a genuinely contested question where thoughtful people disagree for good reasons."
                : "The evidence converges on some key points. See the Raw answer for the full analytical response.",
            confidenceExplanation:
                "Confidence is \(Int(signals.confidence * 100))% based on evidence coherence and domain complexity.",
            whatCouldChange:
                "New data, unconsidered perspectives, or methodological improvements could shift this analysis.",
            whoShouldTrust:
                "This analysis is most reliable for informed decision-making in the relevant domain.",
            sectionLabels: nil
        )
    }

    static func fallbackReflection(signals: GeneratedSignals) -> ReflectionResult {
        ReflectionResult(
            selfCriticalQuestions: [
                "Did we adequately consider reverse causation or unmeasured confounders?",
                "Is the sample representativeness assumption justified here?",
                "Have we confused statistical significance with practical significance?",
                "Are we over-relying on published findings that may reflect positive-result bias?",
            ],
            adjustments: ["Confidence calibrated to domain complexity and signal quality"],
            leastDefensibleClaim: "Any causal claim extrapolated from correlational observations",
            precisionVsEvidenceCheck: "Precision is bounded by the quality of available evidence"
        )
    }

    static func fallbackArbitration(signals: GeneratedSignals) -> ArbitrationResult {
        ArbitrationResult(
            consensus: signals.confidence > 0.65,
            votes: [
                EngineVote(
                    engine: .statistical, position: signals.confidence > 0.6 ? .supports : .neutral,
                    reasoning: "Confidence score: \(Int(signals.confidence * 100))%",
                    confidence: signals.confidence),
                EngineVote(
                    engine: .bayesian, position: signals.entropy < 0.5 ? .supports : .neutral,
                    reasoning: "Entropy: \(Int(signals.entropy * 100))%",
                    confidence: 1 - signals.entropy),
                EngineVote(
                    engine: .causal, position: signals.dissonance < 0.4 ? .supports : .opposes,
                    reasoning: "Dissonance: \(Int(signals.dissonance * 100))%",
                    confidence: 1 - signals.dissonance),
            ],
            disagreements: signals.dissonance > 0.4
                ? ["Signal dissonance detected — interpret with caution"] : [],
            resolution: signals.confidence > 0.65
                ? "Analytical engines broadly agree." : "Treat as indicative, not definitive."
        )
    }

    static func fallbackTruthAssessment(signals: GeneratedSignals) -> TruthAssessment {
        TruthAssessment(
            overallTruthLikelihood: min(0.95, max(0.05, signals.confidence)),
            signalInterpretation:
                "Confidence \(Int(signals.confidence * 100))%, entropy \(Int(signals.entropy * 100))%, dissonance \(Int(signals.dissonance * 100))%.",
            weaknesses: ["Limited access to real-time data", "Cannot conduct original research"],
            improvements: ["Integrate more primary sources", "Apply stronger adversarial testing"],
            blindSpots: [
                "Recent publications may be missing", "Non-English sources not fully covered",
            ],
            confidenceCalibration: signals.confidence > 0.7
                ? "Well-calibrated"
                : signals.confidence > 0.5 ? "Moderately calibrated" : "Underconfident",
            dataVsModelBalance: signals.confidence > 0.6
                ? "~60% data-driven, ~30% model-based, ~10% heuristic"
                : "~40% data-driven, ~45% model-based, ~15% heuristic",
            recommendedActions: [
                "Cross-check with primary sources", "Seek domain expert validation",
            ]
        )
    }
}
