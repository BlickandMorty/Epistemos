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
    stripBracketTags(message.content)
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let originalQuery: String?
    let displayContent: String
    let heading: String?
    let sourceReferences: [AssistantSourceReference]
    let allowsResubmit: Bool
    let onResubmit: (String) -> Void

    @Environment(UIState.self) private var ui
    @State private var copied = false
    @State private var isHovered = false
    @State private var rating: MessageRating? = nil

    private var theme: EpistemosTheme { ui.theme }
    private var isUser: Bool { message.role == .user }

    private var contextAttachments: [ContextAttachment] {
        message.contextAttachments ?? []
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 200) }

            if isUser {
                userBubble
            } else if message.isError {
                errorBubble
            } else {
                assistantBubble
            }

            // No right spacer for assistant messages — content fills the 760px column
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            TaggedMarkdownTextView(
                content: displayContent,
                theme: theme,
                rippleStyle: .none,
                foregroundOverride: theme.userBubbleText
            )
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(theme.userBubbleBg, in: UserBubbleShape())

            if !contextAttachments.isEmpty {
                ContextAttachmentBadgeRow(attachments: contextAttachments, alignment: .trailing)
            }

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

    private var assistantBubble: some View {
        assistantBubbleChrome {
            VStack(alignment: .leading, spacing: Spacing.md) {
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

                // Response heading — auto-extracted topic
                if let heading {
                    Text(heading)
                        .font(AppHeadingRole.h2.font)
                        .foregroundStyle(theme.fontAccent)
                }

                TaggedMarkdownTextView(content: displayContent, theme: theme)

                if !contextAttachments.isEmpty {
                    ContextAttachmentBadgeRow(attachments: contextAttachments)
                }

                AssistantSourcesFooter(sources: sourceReferences, theme: theme, style: .popoverPanel)

                // Toolbar — always rendered at fixed height, opacity-only transition
                MessageToolbar(
                    message: message,
                    originalQuery: originalQuery,
                    allowsResubmit: allowsResubmit,
                    onResubmit: onResubmit,
                    copied: $copied,
                    rating: $rating
                )
                .opacity(isHovered ? 1 : 0)
                .animation(Motion.quick, value: isHovered)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func assistantBubbleChrome<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if theme.assistantBubbleBackgroundHex != nil {
            content()
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(theme.assistantBubbleBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(theme.border.opacity(0.85), lineWidth: 0.8)
                )
        } else {
            content()
        }
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

// MARK: - Epistemic Lens Panel
// Non-blocking enrichment cards for persisted older messages.
// Shows nothing while enrichment is running — the answer is already visible
// in the parent bubble. When Passes 2-6 complete, cards fade in below.

private struct EpistemicLensPanel: View {
    let message: ChatMessage

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    /// Enrichment is complete once layman summary has been populated by Passes 2-6.
    private var isEnriched: Bool { message.dualMessage?.laymanSummary != nil }

    /// Build a single flowing markdown string from the layman summary sections.
    private func buildResearchMarkdown(from ls: LaymanSummary) -> String {
        laymanSummarySections(ls).joined(separator: "\n\n")
    }

    @ViewBuilder
    var body: some View {
        // Only render when enrichment has completed — no spinner, no blocking.
        // Cards fade in seamlessly below the already-visible answer.
        if isEnriched, let dual = message.dualMessage {
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
                if let truth = message.truthAssessment {
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
    let originalQuery: String?
    let allowsResubmit: Bool
    let onResubmit: (String) -> Void
    @Binding var copied: Bool
    @Binding var rating: MessageRating?

    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync
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
            if allowsResubmit {
                Button {
                    onResubmit(originalQuery ?? String(message.content.prefix(200)))
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

private struct ContextAttachmentBadgeRow: View {
    let attachments: [ContextAttachment]
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(attachments) { attachment in
                    ContextAttachmentBadge(attachment: attachment)
                }
            }
        }
    }
}

private struct ContextAttachmentBadge: View {
    let attachment: ContextAttachment

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var tint: Color {
        attachment.kind == .allNotes ? theme.accent : theme.mutedForeground.opacity(0.78)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: attachment.systemImageName)
                .font(.epSmall)
            Text(attachment.title)
                .font(.epSmall)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(attachment.kind == .allNotes ? theme.accent.opacity(0.10) : theme.card)
        )
        .overlay {
            Capsule()
                .strokeBorder(
                    attachment.kind == .allNotes
                        ? theme.accent.opacity(0.18)
                        : theme.border.opacity(0.55),
                    lineWidth: 0.7
                )
        }
        .help(attachment.subtitle ?? attachment.title)
    }
}
