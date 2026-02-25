import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Message Rating

private enum MessageRating { case up, down }

// MARK: - Shared Helpers

/// Builds markdown sections from a LaymanSummary, used by both export and inline rendering.
private func laymanSummarySections(_ ls: LaymanSummary) -> [String] {
    let l = ls.sectionLabels
    let pairs: [(String, String, String)] = [
        (ls.whatWasTried, l?.whatWasTried ?? "What Was Tried", "Approach"),
        (ls.whatIsLikelyTrue, l?.whatIsLikelyTrue ?? "What Is Likely True", "What is likely true"),
        (ls.confidenceExplanation, l?.confidenceExplanation ?? "Confidence Explanation", "Confidence"),
        (ls.whatCouldChange, l?.whatCouldChange ?? "What Could Change This", "What could change this"),
        (ls.whoShouldTrust, l?.whoShouldTrust ?? "Who Should Trust This", "Who should trust this"),
    ]
    return pairs.compactMap { content, label, _ in
        content.isEmpty ? nil : "### \(label)\n\n\(content)"
    }
}

/// Strips non-epistemic bracket tags (e.g. [CAUSAL INFERENCE]) from response text.
/// Preserves [DATA], [MODEL], [UNCERTAIN], [CONFLICT] for TaggedMarkdownTextView.
private func stripBracketTags(_ text: String) -> String {
    text.replacingOccurrences(of: "\\[[A-Z][A-Z ]+\\]", with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Full Export Builder

private func buildFullExport(message: ChatMessage) -> String {
    var sections: [String] = []

    sections.append(stripBracketTags(message.content))

    if let dual = message.dualMessage {
        if let ls = dual.laymanSummary {
            sections.append("\n---\n\n## Layman Summary")
            sections.append(contentsOf: laymanSummarySections(ls))
        }

        if !dual.rawAnalysis.isEmpty {
            sections.append("\n---\n\n## Research Analysis\n\(dual.rawAnalysis)")
        }

        if let ref = dual.reflection {
            if !ref.selfCriticalQuestions.isEmpty {
                sections.append("\n---\n\n## Reflection")
                sections.append(
                    "### Self-Critical Questions\n"
                        + ref.selfCriticalQuestions.map { "- \($0)" }.joined(separator: "\n"))
                if !ref.adjustments.isEmpty {
                    sections.append(
                        "### Adjustments\n"
                            + ref.adjustments.map { "- \($0)" }.joined(separator: "\n"))
                }
                if !ref.leastDefensibleClaim.isEmpty {
                    sections.append("### Least Defensible Claim\n\(ref.leastDefensibleClaim)")
                }
                if !ref.precisionVsEvidenceCheck.isEmpty {
                    sections.append("### Precision vs Evidence\n\(ref.precisionVsEvidenceCheck)")
                }
            }
        }

        if let arb = dual.arbitration {
            sections.append("\n---\n\n## Arbitration")
            sections.append("**Consensus:** \(arb.consensus ? "Yes" : "No")")
            if !arb.resolution.isEmpty {
                sections.append("**Resolution:** \(arb.resolution)")
            }
            if !arb.votes.isEmpty {
                sections.append("### Engine Votes")
                for v in arb.votes {
                    sections.append(
                        "- **\(v.engine.rawValue)** — \(v.position) (\(Int(v.confidence * 100))%): \(v.reasoning)"
                    )
                }
            }
            if !arb.disagreements.isEmpty {
                sections.append(
                    "### Disagreements\n"
                        + arb.disagreements.map { "- \($0)" }.joined(separator: "\n"))
            }
        }

        if !dual.uncertaintyTags.isEmpty {
            sections.append("\n---\n\n## Uncertainty Tags")
            for t in dual.uncertaintyTags {
                sections.append("- **[\(t.tag.rawValue.uppercased())]** \(t.claim)")
            }
        }

        if !dual.modelVsDataFlags.isEmpty {
            sections.append("\n---\n\n## Data vs Model Flags")
            for f in dual.modelVsDataFlags {
                sections.append("- **\(f.source.rawValue)**: \(f.claim)")
            }
        }
    }

    if let conf = message.confidence {
        sections.append("\n---\n\n**Confidence:** \(Int(conf * 100))%")
        if let grade = message.evidenceGrade {
            sections.append("**Evidence Grade:** \(grade.rawValue)")
        }
    }

    return sections.joined(separator: "\n\n")
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @State private var copied = false
    @State private var isHovered = false
    @State private var rating: MessageRating? = nil

    private var theme: EpistemosTheme { ui.theme }
    private var isUser: Bool { message.role == .user }

    /// Live message from ChatState — ensures enrichment updates trigger re-render.
    /// Falls back to the snapshot passed via init (for safety).
    private var liveMessage: ChatMessage {
        chat.messages.first(where: { $0.id == message.id }) ?? message
    }

    /// Research results use full-width layout (no avatar, no right spacer).
    private var isResearchLayout: Bool { liveMessage.isResearchResult }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 200) }

            if isUser {
                userBubble
            } else if message.isError {
                errorBubble
            } else if isResearchLayout {
                researchBubble
            } else {
                assistantBubble
            }

            // No right spacer for assistant messages — content fills the 760px column
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - User Bubble

    private var userDisplayContent: String {
        message.content
            .replacingOccurrences(
                of: #"^\[[A-Z ]+MODE\]\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            Text(userDisplayContent)
                .font(.epBody)
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, 12)
                .background(theme.userBubbleBg, in: UserBubbleShape())

            if !message.attachments.isEmpty {
                HStack(spacing: 6) {
                    ForEach(message.attachments) { att in
                        AttachmentBadge(attachment: att)
                    }
                }
            }
        }
    }

    // MARK: - Error Bubble

    private var errorBubble: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.epTitle)
                .foregroundStyle(theme.error)
                .frame(width: 28, height: 28)

            Text(message.content)
                .font(.epBody)
                .foregroundStyle(theme.error)
                .textSelection(.enabled)
                .padding(Spacing.md)
                .background(theme.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(theme.error.opacity(0.2), lineWidth: 1)
                )
        }
    }

    // MARK: - Research Bubble (full-width, no avatar)
    // Shows the streaming answer immediately — no blocking "analyzing" gate.
    // Enrichment cards (layman summary, reflection, truth, consensus) appear
    // below the answer when background Passes 2-6 complete.

    private var researchBubble: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Research mode badge — visible proof this message went through research pipeline
            // with live enrichment timer that ticks every second.
            ResearchBadge(
                isEnriched: liveMessage.dualMessage?.laymanSummary != nil,
                researchDuration: liveMessage.researchDuration,
                theme: theme
            )

            // Thinking accordion — for completed messages with reasoning
            if let reasoning = message.reasoningText, !reasoning.isEmpty {
                ThinkingAccordion(
                    reasoningText: reasoning,
                    duration: message.reasoningDuration,
                    isLive: false
                )
            }

            // Response heading — auto-extracted topic
            if let heading = extractHeading(from: message.content) {
                Text(heading)
                    .font(.epBodyMedium)
                    .foregroundStyle(theme.foreground)
            }

            // Answer text — rendered instantly because streaming already provided
            // progressive reveal with haptics. TypewriterMarkdown here caused a
            // double-animation: text appeared during streaming, vanished on completion,
            // then re-animated character by character.
            TaggedMarkdownTextView(content: cleanedText, theme: theme)

            // Confidence bar — only shown after enrichment completes.
            // Pre-enrichment value is a placeholder 0.5 from Pass 1; not meaningful.
            if let confidence = liveMessage.confidence,
                liveMessage.dualMessage?.laymanSummary != nil
            {
                ConfidenceBar(confidence: confidence, evidenceGrade: liveMessage.evidenceGrade)
            }

            // Enrichment cards — non-blocking, fade in when background passes complete
            EpistemicLensPanel(messageId: message.id)

            // Toolbar
            MessageToolbar(
                message: message,
                copied: $copied,
                rating: $rating
            )
            .opacity(isHovered ? 1 : 0)
            .animation(Motion.quick, value: isHovered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Vault briefing header — Notes Mode auto-briefing indicator
            if message.isVaultBriefing {
                HStack(spacing: 6) {
                    Image(systemName: "book.pages.fill")
                        .font(.epCaption)
                        .foregroundStyle(theme.accent)
                    Text("Vault Briefing")
                        .font(.epCaption)
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(theme.accent.opacity(0.1), in: Capsule())
            }

            // Loaded note chips — show which notes were referenced
            if let titles = message.loadedNoteTitles, !titles.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(titles, id: \.self) { title in
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.epSmall)
                            Text(title)
                                .font(.epSmall)
                                .lineLimit(1)
                        }
                        .foregroundStyle(theme.accent.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accent.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(theme.accent.opacity(0.15), lineWidth: 0.5))
                    }
                }
            }

            // Thinking accordion — for completed messages with reasoning
            if let reasoning = message.reasoningText, !reasoning.isEmpty {
                ThinkingAccordion(
                    reasoningText: reasoning,
                    duration: message.reasoningDuration,
                    isLive: false
                )
            }

            // Response heading — auto-extracted topic
            if let heading = extractHeading(from: message.content) {
                Text(heading)
                    .font(.epBodyMedium)
                    .foregroundStyle(theme.foreground)
            }

            // Response content — regular mode display.
            // Research results are routed to researchBubble above.
            TaggedMarkdownTextView(content: cleanedText, theme: theme)
            if let confidence = liveMessage.confidence {
                ConfidenceBar(confidence: confidence, evidenceGrade: liveMessage.evidenceGrade)
            }
            if let dual = liveMessage.dualMessage, let arb = dual.arbitration {
                ConsensusReportCard(arbitration: arb, theme: theme)
            }

            // Toolbar — always rendered at fixed height, opacity-only transition
            MessageToolbar(
                message: message,
                copied: $copied,
                rating: $rating
            )
            .opacity(isHovered ? 1 : 0)
            .animation(Motion.quick, value: isHovered)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    // MARK: - Helpers

    private func extractHeading(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard
            let firstNonEmpty = lines.first(where: {
                !$0.trimmingCharacters(in: .whitespaces).isEmpty
            })
        else { return nil }
        if firstNonEmpty.trimmingCharacters(in: .whitespaces).hasPrefix("#") { return nil }
        let cleaned =
            firstNonEmpty
            .replacingOccurrences(
                of: "^(Sure|Certainly|Of course|Great question|Absolutely)[,!.]?\\s*",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\*\\*|\\*|`", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 10 else { return nil }
        return String(cleaned.prefix(50))
    }

    /// Content with non-epistemic brackets stripped.
    /// [DATA]/[MODEL]/[UNCERTAIN]/[CONFLICT] are preserved for TaggedMarkdownTextView
    /// to render as colored badges. Other orphan brackets like [CAUSAL INFERENCE] are
    /// stripped by TaggedMarkdownTextView's inlineMarkdown() safety-net regex.
    private var cleanedText: String {
        message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - User Bubble Shape

private struct UserBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 20
        let smallR: CGFloat = 6
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
            startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addArc(
            center: CGPoint(x: rect.maxX - smallR, y: rect.maxY - smallR), radius: smallR,
            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Confidence Bar

private struct ConfidenceBar: View {
    let confidence: Double
    let evidenceGrade: EvidenceGrade?

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var gradeColor: Color {
        switch evidenceGrade {
        case .a: return theme.success
        case .b: return .orange
        case .c, .d: return theme.error
        case .f, nil: return theme.mutedForeground
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(Int(confidence * 100))% confidence")
                .font(.epSmall)
                .foregroundStyle(theme.mutedForeground.opacity(0.7))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.mutedForeground.opacity(0.1))
                    Capsule()
                        .fill(gradeColor.opacity(0.6))
                        .frame(width: geo.size.width * confidence)
                }
            }
            .frame(width: 60, height: 4)

            if let grade = evidenceGrade {
                Text(grade.rawValue)
                    .font(.epSmall)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(gradeColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(gradeColor)
            }
        }
    }
}

// MARK: - Research Badge
// Shows research mode status with a live ticking timer during enrichment.

private struct ResearchBadge: View {
    let isEnriched: Bool
    let researchDuration: TimeInterval?
    let theme: EpistemosTheme

    @Environment(ChatState.self) private var chat

    /// Format seconds into "Xm Ys" or just "Xs".
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s >= 60 {
            return "\(s / 60)m \(s % 60)s"
        }
        return "\(s)s"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flask.fill")
                .font(.epSmall)
            Text("Research Mode")
                .font(.epSmall)

            if isEnriched {
                // Enrichment complete — show final duration
                if let dur = researchDuration {
                    Text("Pipeline Complete \(formatDuration(dur))")
                        .font(.epSmall)
                        .foregroundStyle(theme.emerald)
                } else {
                    Text("Pipeline Complete")
                        .font(.epSmall)
                        .foregroundStyle(theme.emerald)
                }
            } else if let start = chat.researchStartTime {
                // Enrichment in progress — live ticking timer
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    Text("Enriching \(formatDuration(elapsed))")
                        .font(.epMono)
                        .foregroundStyle(theme.accent.opacity(0.7))
                }
            } else {
                Text("Enriching...")
                    .font(.epSmall)
                    .foregroundStyle(theme.mutedForeground)
            }
        }
        .foregroundStyle(theme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(theme.accent.opacity(0.08), in: Capsule())
    }
}

// MARK: - Epistemic Lens Panel
// Non-blocking enrichment cards for research mode.
// Shows nothing while enrichment is running — the answer is already visible
// in the parent bubble. When Passes 2-6 complete, cards fade in below.

private struct EpistemicLensPanel: View {
    let messageId: String

    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    private var theme: EpistemosTheme { ui.theme }

    /// Live message from ChatState — ensures enrichment updates trigger re-render.
    private var message: ChatMessage? { chat.messages.first(where: { $0.id == messageId }) }

    /// Enrichment is complete once layman summary has been populated by Passes 2-6.
    private var isEnriched: Bool { message?.dualMessage?.laymanSummary != nil }

    /// Build a single flowing markdown string from the layman summary sections.
    private func buildResearchMarkdown(from ls: LaymanSummary) -> String {
        laymanSummarySections(ls).joined(separator: "\n\n")
    }

    @ViewBuilder
    var body: some View {
        // Only render when enrichment has completed — no spinner, no blocking.
        // Cards fade in seamlessly below the already-visible answer.
        if isEnriched, let dual = message?.dualMessage {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Structured summary — layman-friendly breakdown (Pass 3)
                if let ls = dual.laymanSummary {
                    TaggedMarkdownTextView(
                        content: buildResearchMarkdown(from: ls),
                        theme: theme
                    )
                }

                // Reflection — self-critique card (Pass 4)
                if let ref = dual.reflection {
                    ReflectionCard(reflection: ref, theme: theme)
                }

                // Truth Assessment — collapsible card (Pass 6)
                if let truth = message?.truthAssessment {
                    TruthAssessmentCard(assessment: truth, theme: theme)
                }

                // Arbitration — collapsible consensus card (Pass 5)
                if let arb = dual.arbitration {
                    ConsensusReportCard(arbitration: arb, theme: theme)
                }
            }
            .transition(.opacity)
            .animation(Motion.smooth, value: isEnriched)
        }
    }
}

// MARK: - Reflection Card
// Collapsible card showing the pipeline's self-critique (Pass 4).
// Shows self-critical questions, adjustments, least defensible claim,
// and precision vs evidence check. Collapsed by default.

private struct ReflectionCard: View {
    let reflection: ReflectionResult
    let theme: EpistemosTheme

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? Spacing.md : 0) {
            // Header — tap to toggle
            Button {
                withAnimation(Motion.quick) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.epBodyMedium)
                        .foregroundStyle(theme.accent.opacity(0.7))

                    Text("Self-Critique")
                        .font(.epCaption)
                        .foregroundStyle(theme.foreground.opacity(0.8))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.epSmall)
                        .foregroundStyle(theme.mutedForeground.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    // Self-critical questions
                    if !reflection.selfCriticalQuestions.isEmpty {
                        reflectionList(
                            "Self-Critical Questions",
                            items: reflection.selfCriticalQuestions,
                            icon: "questionmark.circle",
                            color: theme.warning
                        )
                    }

                    // Adjustments
                    if !reflection.adjustments.isEmpty {
                        reflectionList(
                            "Adjustments Made",
                            items: reflection.adjustments,
                            icon: "arrow.uturn.right.circle",
                            color: theme.info
                        )
                    }

                    // Least defensible claim
                    if !reflection.leastDefensibleClaim.isEmpty {
                        reflectionSection(
                            "Least Defensible Claim",
                            content: reflection.leastDefensibleClaim,
                            icon: "exclamationmark.triangle",
                            color: theme.error
                        )
                    }

                    // Precision vs evidence
                    if !reflection.precisionVsEvidenceCheck.isEmpty {
                        reflectionSection(
                            "Precision vs Evidence",
                            content: reflection.precisionVsEvidenceCheck,
                            icon: "scale.3d",
                            color: theme.accent
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.accent.opacity(0.03))
        )
        .animation(Motion.smooth, value: isExpanded)
    }

    private func reflectionSection(_ title: String, content: String, icon: String, color: Color)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            cardSectionHeader(title, icon: icon, color: color, accent: theme.accent)
            Text(content)
                .font(.epBody)
                .foregroundStyle(theme.foreground.opacity(0.8))
                .lineSpacing(2)
        }
    }

    private func reflectionList(_ title: String, items: [String], icon: String, color: Color)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            cardSectionHeader(title, icon: icon, color: color, accent: theme.accent)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{2022}")
                        .font(.epCaption)
                        .foregroundStyle(color.opacity(0.6))
                    Text(item)
                        .font(.epBody)
                        .foregroundStyle(theme.foreground.opacity(0.8))
                }
            }
        }
    }
}

// MARK: - Shared Card Section Builders

/// Section header used by ReflectionCard and TruthAssessmentCard.
/// Extracted to eliminate 4 identical implementations.
@ViewBuilder
private func cardSectionHeader(
    _ title: String, icon: String, color: Color, accent: Color
) -> some View {
    HStack(spacing: 5) {
        Image(systemName: icon)
            .font(.epSmall)
            .foregroundStyle(color.opacity(0.7))
        Text(title.uppercased())
            .font(.epMono)
            .fontWeight(.bold)
            .foregroundStyle(accent.opacity(0.5))
            .tracking(0.4)
    }
}

// MARK: - Truth Assessment Card
// Hover-reveal card showing truth likelihood + detailed assessment.
// Compact: shield icon + percentage. Expands on hover/tap to show full details.

private struct TruthAssessmentCard: View {
    let assessment: TruthAssessment
    let theme: EpistemosTheme

    @State private var isExpanded = false

    private var truthColor: Color {
        if assessment.overallTruthLikelihood > 0.6 { return theme.success }
        if assessment.overallTruthLikelihood > 0.35 { return theme.amber }
        return theme.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? Spacing.md : 0) {
            // Compact header — always visible
            Button {
                withAnimation(Motion.quick) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.epBodyMedium)
                        .foregroundStyle(truthColor)

                    Text("\(Int(assessment.overallTruthLikelihood * 100))%")
                        .font(.epHeading)
                        .foregroundStyle(truthColor)

                    Text("Truth Likelihood")
                        .font(.epCaption)
                        .foregroundStyle(theme.mutedForeground.opacity(0.7))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.epSmall)
                        .foregroundStyle(theme.mutedForeground.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail — hover / tap reveal
            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if !assessment.signalInterpretation.isEmpty {
                        assessmentSection(
                            "Signal Interpretation",
                            content: assessment.signalInterpretation,
                            icon: "waveform.path"
                        )
                    }
                    if !assessment.weaknesses.isEmpty {
                        assessmentList(
                            "Weaknesses",
                            items: assessment.weaknesses,
                            icon: "exclamationmark.triangle",
                            color: theme.warning
                        )
                    }
                    if !assessment.blindSpots.isEmpty {
                        assessmentList(
                            "Blind Spots",
                            items: assessment.blindSpots,
                            icon: "eye.slash",
                            color: theme.error
                        )
                    }
                    if !assessment.improvements.isEmpty {
                        assessmentList(
                            "Improvements",
                            items: assessment.improvements,
                            icon: "arrow.up.circle",
                            color: theme.success
                        )
                    }
                    if !assessment.confidenceCalibration.isEmpty {
                        assessmentSection(
                            "Confidence Calibration",
                            content: assessment.confidenceCalibration,
                            icon: "dial.low"
                        )
                    }
                    if !assessment.dataVsModelBalance.isEmpty {
                        assessmentSection(
                            "Data vs Model",
                            content: assessment.dataVsModelBalance,
                            icon: "scale.3d"
                        )
                    }
                    if !assessment.recommendedActions.isEmpty {
                        assessmentList(
                            "Recommended Actions",
                            items: assessment.recommendedActions,
                            icon: "arrow.right.circle",
                            color: theme.info
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.md)
        .background(truthColor.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .animation(Motion.smooth, value: isExpanded)
    }

    private func assessmentSection(_ title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            cardSectionHeader(title, icon: icon, color: theme.accent, accent: theme.accent)
            Text(content)
                .font(.epBody)
                .foregroundStyle(theme.foreground.opacity(0.8))
                .lineSpacing(2)
        }
    }

    private func assessmentList(_ title: String, items: [String], icon: String, color: Color)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            cardSectionHeader(title, icon: icon, color: color, accent: theme.accent)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{2022}")
                        .font(.epCaption)
                        .foregroundStyle(color.opacity(0.6))
                    Text(item)
                        .font(.epBody)
                        .foregroundStyle(theme.foreground.opacity(0.8))
                }
            }
        }
    }
}

// MARK: - Consensus Report Card
// Structured arbitration view with visual vote bars, consensus badge, and disagreement list.
// Replaces the flat text arbitration section in EpistemicLensPanel.

private struct ConsensusReportCard: View {
    let arbitration: ArbitrationResult
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header with consensus badge
            HStack(spacing: 8) {
                Text("ARBITRATION")
                    .font(.epMono)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.accent.opacity(0.5))
                    .tracking(0.6)

                Spacer()

                // Consensus badge
                HStack(spacing: 4) {
                    Image(
                        systemName: arbitration.consensus
                            ? "checkmark.seal.fill" : "xmark.seal.fill"
                    )
                    .font(.epSmall)
                    Text(arbitration.consensus ? "Consensus" : "Dissent")
                        .font(.epSmall)
                        .fontWeight(.bold)
                }
                .foregroundStyle(arbitration.consensus ? theme.success : theme.error)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    (arbitration.consensus ? theme.success : theme.error).opacity(0.1),
                    in: Capsule()
                )
            }

            // Resolution text
            if !arbitration.resolution.isEmpty {
                Text(arbitration.resolution)
                    .font(.epBody)
                    .foregroundStyle(theme.foreground.opacity(0.8))
                    .lineSpacing(2)
            }

            // Vote bars
            if !arbitration.votes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ENGINE VOTES")
                        .font(.epMono)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.accent.opacity(0.4))
                        .tracking(0.4)

                    ForEach(arbitration.votes, id: \.engine) { vote in
                        VoteBar(vote: vote, theme: theme)
                    }
                }
            }

            // Disagreements
            if !arbitration.disagreements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.epSmall)
                            .foregroundStyle(theme.warning.opacity(0.7))
                        Text("DISAGREEMENTS")
                            .font(.epMono)
                            .fontWeight(.bold)
                            .foregroundStyle(theme.accent.opacity(0.4))
                            .tracking(0.4)
                    }
                    ForEach(arbitration.disagreements, id: \.self) { point in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\u{2022}")
                                .font(.epSmall)
                                .foregroundStyle(theme.warning.opacity(0.6))
                            Text(point)
                                .font(.epCaption)
                                .foregroundStyle(theme.foreground.opacity(0.75))
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    arbitration.consensus ? theme.success.opacity(0.03) : theme.error.opacity(0.03))
        )
    }
}

// MARK: - Vote Bar
// Visual confidence bar for a single engine vote.

private struct VoteBar: View {
    let vote: EngineVote
    let theme: EpistemosTheme

    private var barColor: Color {
        if vote.confidence > 0.7 { return theme.success }
        if vote.confidence > 0.4 { return theme.amber }
        return theme.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(vote.engine.rawValue)
                    .font(.epMono)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.accent.opacity(0.7))
                    .frame(minWidth: 56, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.mutedForeground.opacity(0.08))
                        Capsule()
                            .fill(barColor.opacity(0.6))
                            .frame(width: geo.size.width * vote.confidence)
                    }
                }
                .frame(height: 6)

                Text("\(Int(vote.confidence * 100))%")
                    .font(.epMono)
                    .fontWeight(.semibold)
                    .foregroundStyle(barColor)
                    .frame(minWidth: 32, alignment: .trailing)
            }

            if !vote.reasoning.isEmpty {
                Text(vote.reasoning)
                    .font(.epSmall)
                    .foregroundStyle(theme.foreground.opacity(0.6))
                    .lineLimit(2)
                    .padding(.leading, 62)
            }
        }
    }
}

// MARK: - Message Toolbar

private struct MessageToolbar: View {
    let message: ChatMessage
    @Binding var copied: Bool
    @Binding var rating: MessageRating?

    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(ChatState.self) private var chat
    @Environment(PipelineState.self) private var pipeline
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 4) {
            // Copy — includes full DualMessage analysis if available
            Button {
                let fullContent = buildFullExport(message: message)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fullContent, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .milliseconds(1500))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? theme.success : .secondary)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help(copied ? "Copied" : "Copy to clipboard")
            .accessibilityLabel(copied ? "Copied" : "Copy to clipboard")

            // Send to Notes — full export via VaultSyncService, opens the new page
            Button {
                let fullContent = buildFullExport(message: message)
                let title = extractTitle(from: message.content)
                Task {
                    if let pageId = await vaultSync.createPage(title: title, body: fullContent) {
                        NoteWindowManager.shared.open(pageId: pageId)
                    }
                }
            } label: {
                Image(systemName: "note.text.badge.plus")
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Send to Notes")
            .accessibilityLabel("Send to Notes")

            // Export as .md file
            Button {
                let fullContent = buildFullExport(message: message)
                let panel = NSSavePanel()
                panel.nameFieldStringValue =
                    "message-\(ISO8601DateFormatter().string(from: message.createdAt).prefix(10)).md"
                panel.allowedContentTypes = [.plainText]
                panel.canCreateDirectories = true
                if panel.runModal() == .OK, let url = panel.url {
                    try? fullContent.write(to: url, atomically: true, encoding: .utf8)
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Export as Markdown")
            .accessibilityLabel("Export as Markdown")

            // Re-ask — resubmit the same query for a fresh analysis (hidden during streaming)
            if !pipeline.isProcessing {
                Button {
                    let query = findOriginalQuery()
                    chat.submitQuery(query)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(NativeToolbarButtonStyle())
                .help("Resubmit this query")
                .accessibilityLabel("Resubmit this query")
            }

            // Thumbs up
            Button {
                withAnimation(Motion.quick) {
                    rating = rating == .up ? nil : .up
                }
            } label: {
                Image(systemName: rating == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle(rating == .up ? theme.success : .secondary)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Good response")
            .accessibilityLabel("Good response")

            // Thumbs down
            Button {
                withAnimation(Motion.quick) {
                    rating = rating == .down ? nil : .down
                }
            } label: {
                Image(systemName: rating == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle(rating == .down ? theme.error : .secondary)
            }
            .buttonStyle(NativeToolbarButtonStyle())
            .help("Poor response")
            .accessibilityLabel("Poor response")
        }
    }

    private func extractTitle(from text: String) -> String {
        let firstLine =
            text.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "Chat Export"
        let cleaned =
            firstLine
            .replacingOccurrences(of: "\\*\\*|\\*|`|^#+\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(50))
    }

    /// Find the user query that preceded this assistant message.
    private func findOriginalQuery() -> String {
        let messages = chat.messages
        guard let idx = messages.firstIndex(where: { $0.id == message.id }),
            idx > 0,
            messages[idx - 1].role == .user
        else {
            return String(message.content.prefix(200))
        }
        return messages[idx - 1].content
    }
}

// MARK: - Attachment Badge

private struct AttachmentBadge: View {
    let attachment: FileAttachment

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var icon: String {
        switch attachment.type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        case .text, .other: return "paperclip"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.epSmall)
            Text(attachment.name)
                .font(.epSmall)
                .lineLimit(1)
        }
        .foregroundStyle(theme.mutedForeground.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.card, in: Capsule())
    }
}
