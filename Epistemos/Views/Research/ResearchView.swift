import SwiftUI

// MARK: - Research Tool Views
// Shared components and tool tab views for the Research Hub (now embedded in LibraryView).
// PaperSearchTab, NoveltyCheckTab, PaperReviewTab, CitationSearchTab, IdeaGeneratorTab
// are all used by LibraryView's Research Tools tab.

// MARK: - Provider Capability Banner

struct ProviderCapabilityBanner: View {
    let note: String

    @Environment(UIState.self) private var ui
    @State private var dismissed = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        if !dismissed {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent.opacity(0.8))
                    .padding(.top, 1)

                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.foreground.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    withAnimation(Motion.quick) { dismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.mutedForeground.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.bottom, Spacing.sm)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Shared Components

struct ResearchLoadingView: View {
    let message: String
    var detail: String? = nil

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(theme.accent)
            Text(message)
                .font(.epBody)
                .foregroundStyle(theme.mutedForeground)
            if let detail {
                Text(detail)
                    .font(.epCaption)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
    }
}

struct ResearchErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)? = nil

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.error)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(theme.foreground.opacity(0.8))
                .lineLimit(3)

            Spacer()

            if let onRetry {
                Button("Retry") { onRetry() }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(Spacing.md)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct EmptyResearchState: View {
    let icon: String
    let title: String
    let subtitle: String

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(theme.mutedForeground.opacity(0.18))
                .symbolEffect(.pulse.wholeSymbol, options: .repeat(.periodic(delay: 3.0)))
            Text(title)
                .font(.epBody)
                .foregroundStyle(theme.mutedForeground)
            Text(subtitle)
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}

struct ScoreGauge: View {
    let label: String
    let value: Double
    let maxValue: Double
    var color: Color = .blue

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.mutedForeground)
                Spacer()
                Text(
                    maxValue <= 1.0
                        ? String(format: "%.0f%%", (value / maxValue) * 100)
                        : "\(Int(value))/\(Int(maxValue))"
                )
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.1))
                    Capsule()
                        .fill(color.opacity(0.7))
                        .frame(width: max(0, geo.size.width * CGFloat(value / maxValue)))
                }
            }
            .frame(height: 5)
            .clipShape(Capsule())
        }
    }
}

struct DecisionBadge: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .foregroundStyle(color)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct RatingBadge: View {
    let label: String
    let level: String

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var badgeColor: Color {
        switch level.lowercased() {
        case "high": theme.success
        case "medium": theme.warning
        default: theme.mutedForeground
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
            Text(level)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(badgeColor.opacity(0.1), in: Capsule())
        }
    }
}

// MARK: - Paper Search Tab

struct PaperSearchTab: View {
    @Environment(UIState.self) private var ui
    @Environment(ResearchState.self) private var research
    @Environment(ResearchService.self) private var researchService

    @State private var query = ""
    @State private var yearRange = ""
    @State private var isSearching = false
    @State private var results: [ResearchPaper] = []
    @State private var errorMessage: String?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            GlassSection(title: "Search Semantic Scholar") {
                HStack(spacing: Spacing.sm) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.mutedForeground.opacity(0.4))
                        TextField("Search for papers...", text: $query)
                            .font(.system(size: 13))
                            .textFieldStyle(.plain)
                            .onSubmit { performSearch() }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    TextField("Year range", text: $yearRange)
                        .font(.system(size: 13))
                        .textFieldStyle(.plain)
                        .frame(width: 100)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        performSearch()
                    } label: {
                        HStack(spacing: 6) {
                            if isSearching {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "magnifyingglass").font(.system(size: 12))
                            }
                            Text("Search").font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .hoverGlassCapsule(flatBackground: theme.card)
                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching
                    )
                }
            }

            if let error = errorMessage {
                ResearchErrorBanner(message: error) { performSearch() }
            }

            if results.isEmpty && !isSearching && errorMessage == nil {
                EmptyResearchState(
                    icon: "doc.text.magnifyingglass",
                    title: "Search for papers",
                    subtitle:
                        "Enter a query to search Semantic Scholar's database of academic papers"
                )
            } else if isSearching {
                ResearchLoadingView(message: "Searching papers...")
            } else {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(results) { paper in
                        SearchResultCard(paper: paper)
                    }
                }
            }
        }
        .onChange(of: research.pendingNotesContent) { _, prefill in
            if let prefill {
                query = prefill.title
                research.pendingNotesContent = nil
                performSearch()
            }
        }
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                results = try await researchService.searchPapers(
                    query: query,
                    yearRange: yearRange.isEmpty ? nil : yearRange
                )
            } catch {
                errorMessage = error.localizedDescription
                results = []
            }
            isSearching = false
        }
    }
}

// MARK: - Novelty Check Tab

struct NoveltyCheckTab: View {
    @Environment(UIState.self) private var ui
    @Environment(ResearchState.self) private var research
    @Environment(ResearchService.self) private var researchService

    @State private var title = ""
    @State private var description = ""
    @State private var hypothesis = ""
    @State private var keywords = ""
    @State private var isChecking = false
    @State private var result: NoveltyResult?
    @State private var errorMessage: String?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            GlassSection(title: "Check Research Novelty") {
                VStack(spacing: Spacing.md) {
                    LabeledField(label: "Research Title") {
                        TextField("Your research idea title...", text: $title)
                            .font(.epBody)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    LabeledField(label: "Description") {
                        TextEditor(text: $description)
                            .font(.epBody)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    LabeledField(label: "Hypothesis (optional)") {
                        TextField("Your main hypothesis...", text: $hypothesis)
                            .font(.epBody)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    LabeledField(label: "Keywords (optional, comma-separated)") {
                        TextField("meta-learning, neural networks, ...", text: $keywords)
                            .font(.epBody)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    HStack {
                        Spacer()
                        Button {
                            performNoveltyCheck()
                        } label: {
                            HStack(spacing: 6) {
                                if isChecking {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "sparkles").font(.system(size: 12))
                                }
                                Text(isChecking ? "Checking..." : "Check Novelty")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .hoverGlassCapsule(flatBackground: theme.card)
                            .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || description.isEmpty || isChecking)
                    }
                }
            }

            if let error = errorMessage {
                ResearchErrorBanner(message: error) { performNoveltyCheck() }
            }

            if isChecking {
                ResearchLoadingView(
                    message: "Evaluating novelty...",
                    detail: "Searching literature and comparing with existing work (up to 3 rounds)"
                )
            }

            if let result {
                NoveltyResultCard(result: result)
            }
        }
        .onChange(of: research.pendingNotesContent) { _, prefill in
            if let prefill {
                title = prefill.title
                description = String(prefill.content.prefix(3000))
                research.pendingNotesContent = nil
            }
        }
    }

    private func performNoveltyCheck() {
        guard !title.isEmpty, !description.isEmpty else { return }
        isChecking = true
        errorMessage = nil
        result = nil
        Task {
            do {
                let kw: [String]? =
                    keywords.isEmpty
                    ? nil
                    : keywords.components(separatedBy: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }.filter { !$0.isEmpty }
                result = try await researchService.checkNovelty(
                    title: title,
                    description: description,
                    hypothesis: hypothesis.isEmpty ? nil : hypothesis,
                    keywords: kw
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isChecking = false
        }
    }
}

// MARK: - Novelty Result Card

private struct NoveltyResultCard: View {
    let result: NoveltyResult

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                DecisionBadge(
                    text: result.isNovel ? "Novel" : "Not Novel",
                    icon: result.isNovel ? "checkmark.seal.fill" : "xmark.seal.fill",
                    color: result.isNovel ? theme.success : theme.error
                )

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(result.searchRounds) rounds")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                    Text("\(result.papersReviewed) papers reviewed")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            ScoreGauge(
                label: "Confidence",
                value: result.confidence,
                maxValue: 1.0,
                color: result.confidence > 0.7
                    ? theme.success : (result.confidence > 0.4 ? theme.warning : theme.error)
            )

            Text(result.summary)
                .font(.system(size: 13))
                .foregroundStyle(theme.foreground.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if !result.closestPapers.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Closest Papers")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.mutedForeground)

                    ForEach(result.closestPapers) { paper in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Circle()
                                .fill(theme.accent.opacity(0.3))
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(paper.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(theme.foreground)
                                    .lineLimit(2)
                                Text(
                                    "\(paper.authors.prefix(2).joined(separator: ", "))\(paper.authors.count > 2 ? " et al." : "") \(paper.year.map { "(\($0))" } ?? "")"
                                )
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.lg)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 14)
    }
}

// MARK: - Paper Review Tab

struct PaperReviewTab: View {
    @Environment(UIState.self) private var ui
    @Environment(ResearchService.self) private var researchService

    @State private var paperTitle = ""
    @State private var abstract = ""
    @State private var fullText = ""
    @State private var isReviewing = false
    @State private var result: ReviewResult?
    @State private var errorMessage: String?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            GlassSection(title: "AI Paper Review") {
                VStack(spacing: Spacing.md) {
                    LabeledField(label: "Paper Title") {
                        TextField("Paper title...", text: $paperTitle)
                            .font(.epBody)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    LabeledField(label: "Abstract") {
                        TextEditor(text: $abstract)
                            .font(.epBody)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    LabeledField(label: "Full Text (optional)") {
                        TextEditor(text: $fullText)
                            .font(.epBody)
                            .frame(minHeight: 50)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    HStack {
                        Spacer()
                        Button {
                            performReview()
                        } label: {
                            HStack(spacing: 6) {
                                if isReviewing {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "doc.text.magnifyingglass").font(
                                        .system(size: 12))
                                }
                                Text(isReviewing ? "Reviewing..." : "Review Paper")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .hoverGlassCapsule(flatBackground: theme.card)
                            .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(paperTitle.isEmpty || abstract.isEmpty || isReviewing)
                    }
                }
            }

            if let error = errorMessage {
                ResearchErrorBanner(message: error) { performReview() }
            }

            if isReviewing {
                ResearchLoadingView(
                    message: "Generating AI review...",
                    detail: "Evaluating originality, quality, clarity, and more")
            }

            if let result {
                ReviewResultCard(result: result)
            }
        }
    }

    private func performReview() {
        guard !paperTitle.isEmpty, !abstract.isEmpty else { return }
        isReviewing = true
        errorMessage = nil
        result = nil
        Task {
            do {
                result = try await researchService.reviewPaper(
                    title: paperTitle,
                    abstract: abstract,
                    fullText: fullText.isEmpty ? nil : fullText
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isReviewing = false
        }
    }
}

// MARK: - Review Result Card

private struct ReviewResultCard: View {
    let result: ReviewResult

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var decisionColor: Color {
        switch result.decision {
        case .strongAccept: theme.success
        case .weakAccept: theme.success.opacity(0.7)
        case .borderline: theme.warning
        case .weakReject: theme.error.opacity(0.7)
        case .strongReject: theme.error
        }
    }

    private var decisionIcon: String {
        switch result.decision {
        case .strongAccept, .weakAccept: "checkmark.circle.fill"
        case .borderline: "minus.circle.fill"
        case .weakReject, .strongReject: "xmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.md) {
                DecisionBadge(
                    text: result.decision.rawValue, icon: decisionIcon, color: decisionColor)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Overall")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                    Text(String(format: "%.1f", result.overallScore) + "/10")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(decisionColor)
                }
            }

            ScoreGauge(
                label: "Overall", value: result.overallScore, maxValue: 10, color: decisionColor)

            let scoreItems: [(String, Int)] = [
                ("Originality", result.scores.originality),
                ("Quality", result.scores.quality),
                ("Clarity", result.scores.clarity),
                ("Significance", result.scores.significance),
                ("Soundness", result.scores.soundness),
                ("Presentation", result.scores.presentation),
                ("Contribution", result.scores.contribution),
            ]

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm)
            {
                ForEach(scoreItems, id: \.0) { label, score in
                    ScoreGauge(
                        label: label,
                        value: Double(score),
                        maxValue: 4.0,
                        color: score >= 3
                            ? theme.success : (score >= 2 ? theme.warning : theme.error)
                    )
                }
            }

            if !result.strengths.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Strengths")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.success)
                    ForEach(result.strengths, id: \.self) { s in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.success)
                                .padding(.top, 2)
                            Text(s)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.foreground.opacity(0.85))
                        }
                    }
                }
            }

            if !result.weaknesses.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Weaknesses")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.error)
                    ForEach(result.weaknesses, id: \.self) { w in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.error)
                                .padding(.top, 2)
                            Text(w)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.foreground.opacity(0.85))
                        }
                    }
                }
            }

            Text(result.summary)
                .font(.system(size: 12))
                .foregroundStyle(theme.mutedForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 14)
    }
}

// MARK: - Citation Search Tab

struct CitationSearchTab: View {
    @Environment(UIState.self) private var ui
    @Environment(ResearchState.self) private var research
    @Environment(ResearchService.self) private var researchService

    @State private var researchText = ""
    @State private var context = ""
    @State private var isSearching = false
    @State private var result: CitationSearchResult?
    @State private var errorMessage: String?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            GlassSection(title: "Find Citations") {
                VStack(spacing: Spacing.md) {
                    LabeledField(label: "Your Research Text") {
                        TextEditor(text: $researchText)
                            .font(.epBody)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    LabeledField(label: "Context (optional)") {
                        TextField("Field or topic for better matching...", text: $context)
                            .font(.epBody)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    HStack {
                        Spacer()
                        Button {
                            performSearch()
                        } label: {
                            HStack(spacing: 6) {
                                if isSearching {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "book.fill").font(.system(size: 12))
                                }
                                Text(isSearching ? "Finding..." : "Find Citations")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .hoverGlassCapsule(flatBackground: theme.card)
                            .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(
                            researchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || isSearching)
                    }
                }
            }

            if let error = errorMessage {
                ResearchErrorBanner(message: error) { performSearch() }
            }

            if isSearching {
                ResearchLoadingView(
                    message: "Finding citations...",
                    detail: "Identifying claims, searching literature, and matching papers"
                )
            }

            if let result {
                CitationResultView(result: result)
            }
        }
        .onChange(of: research.pendingNotesContent) { _, prefill in
            if let prefill {
                researchText = String(prefill.content.prefix(5000))
                research.pendingNotesContent = nil
            }
        }
    }

    private func performSearch() {
        guard !researchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSearching = true
        errorMessage = nil
        result = nil
        Task {
            do {
                result = try await researchService.searchCitations(
                    text: researchText,
                    context: context.isEmpty ? nil : context
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
}

// MARK: - Citation Result View

private struct CitationResultView: View {
    let result: CitationSearchResult

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(spacing: Spacing.xl) {
                CitationStatPill(label: "Claims Found", value: "\(result.claimsFound)")
                CitationStatPill(label: "Papers Matched", value: "\(result.papersMatched)")
                CitationStatPill(label: "Unique References", value: "\(result.uniqueReferences)")
                Spacer()
            }

            if result.matches.isEmpty {
                Text("No citation matches found.")
                    .font(.epCaption)
                    .foregroundStyle(theme.textTertiary)
            } else {
                ForEach(result.matches) { match in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("\"\(match.claim)\"")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.foreground.opacity(0.9))
                            .italic()
                            .lineLimit(3)

                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.accent)
                            Text(match.paperTitle)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(2)
                        }

                        HStack {
                            Text(match.bibtexKey)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(theme.accent.opacity(0.7))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accent.opacity(0.08), in: Capsule())

                            Spacer()

                            ScoreGauge(
                                label: "Relevance",
                                value: match.relevanceScore,
                                maxValue: 1.0,
                                color: theme.accent
                            )
                            .frame(width: 120)
                        }
                    }
                    .padding(Spacing.md)
                    .background(
                        theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(Spacing.lg)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 14)
    }
}

private struct CitationStatPill: View {
    let label: String
    let value: String

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
        }
    }
}

// MARK: - Idea Generator Tab

struct IdeaGeneratorTab: View {
    @Environment(UIState.self) private var ui
    @Environment(ResearchService.self) private var researchService

    @State private var topic = ""
    @State private var ideaContext = ""
    @State private var constraints = ""
    @State private var ideaCount = 3
    @State private var isGenerating = false
    @State private var ideas: [ResearchIdea] = []
    @State private var errorMessage: String?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            GlassSection(title: "Generate Research Ideas") {
                VStack(spacing: Spacing.md) {
                    LabeledField(label: "Research Topic") {
                        TextField("e.g., meta-learning in neural networks", text: $topic)
                            .font(.epBody)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    LabeledField(label: "Context (optional)") {
                        TextField("Background, prior work, resources...", text: $ideaContext)
                            .font(.epBody)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    LabeledField(label: "Constraints (optional)") {
                        TextField("Budget, timeline, equipment...", text: $constraints)
                            .font(.epBody)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    HStack(spacing: Spacing.sm) {
                        Text("Number of ideas:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.mutedForeground)

                        ForEach([1, 2, 3, 5], id: \.self) { count in
                            Button {
                                ideaCount = count
                            } label: {
                                Text("\(count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(
                                        ideaCount == count ? theme.accent : theme.mutedForeground
                                    )
                                    .background(
                                        ideaCount == count
                                            ? theme.accent.opacity(0.12) : Color.clear,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()
                    }

                    HStack(spacing: Spacing.md) {
                        Spacer()

                        Button {
                            generateIdeas(count: 1)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill").font(.system(size: 12))
                                Text("Quick Idea").font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .hoverGlassCapsule(flatBackground: theme.card)
                            .foregroundStyle(theme.mutedForeground)
                        }
                        .buttonStyle(.plain)
                        .disabled(topic.isEmpty || isGenerating)

                        Button {
                            generateIdeas(count: ideaCount)
                        } label: {
                            HStack(spacing: 6) {
                                if isGenerating {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Image(systemName: "lightbulb.fill").font(.system(size: 12))
                                }
                                Text(isGenerating ? "Generating..." : "Generate Ideas")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .hoverGlassCapsule(flatBackground: theme.card)
                            .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(topic.isEmpty || isGenerating)
                    }
                }
            }

            if let error = errorMessage {
                ResearchErrorBanner(message: error) { generateIdeas(count: ideaCount) }
            }

            if isGenerating {
                ResearchLoadingView(
                    message: "Generating research ideas...",
                    detail: "Each idea is scored for feasibility, novelty, and interestingness"
                )
            }

            if !ideas.isEmpty {
                VStack(spacing: Spacing.sm) {
                    ForEach(ideas) { idea in
                        IdeaCard(idea: idea)
                    }
                }
            }
        }
    }

    private func generateIdeas(count: Int) {
        guard !topic.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let newIdeas = try await researchService.generateIdeas(
                    topic: topic,
                    context: ideaContext.isEmpty ? nil : ideaContext,
                    constraints: constraints.isEmpty ? nil : constraints,
                    count: count
                )
                if count == 1 {
                    ideas.append(contentsOf: newIdeas)
                } else {
                    ideas = newIdeas
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

// MARK: - Idea Card

private struct IdeaCard: View {
    let idea: ResearchIdea

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                Text(idea.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Spacer()
                Text(String(format: "%.0f", idea.score * 100))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        idea.score >= 0.7
                            ? theme.success : (idea.score >= 0.4 ? theme.warning : theme.error))
            }

            Text(idea.description)
                .font(.system(size: 12))
                .foregroundStyle(theme.foreground.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.md) {
                ScoreGauge(
                    label: "Score",
                    value: idea.score,
                    maxValue: 1.0,
                    color: idea.score >= 0.7
                        ? theme.success : (idea.score >= 0.4 ? theme.warning : theme.error)
                )

                Spacer()

                RatingBadge(label: "Feasibility", level: idea.feasibility)
                RatingBadge(label: "Novelty", level: idea.novelty)
                RatingBadge(label: "Interest", level: idea.interestingness)
            }
        }
        .padding(Spacing.lg)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 14)
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let paper: ResearchPaper

    @Environment(UIState.self) private var ui
    @Environment(ResearchState.self) private var research
    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var isSaved = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(paper.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.foreground)
                .lineLimit(isExpanded ? nil : 2)

            Text(
                paper.authors.prefix(3).joined(separator: ", ")
                    + (paper.authors.count > 3 ? " et al." : "")
            )
            .font(.system(size: 12))
            .foregroundStyle(theme.mutedForeground)
            .lineLimit(1)

            HStack(spacing: Spacing.sm) {
                if let year = paper.year {
                    Text(String(year))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.accent.opacity(0.7))
                }
                if let count = paper.citationCount {
                    HStack(spacing: 3) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 9))
                        Text("\(count)")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(theme.textTertiary)
                }
                if let journal = paper.journal {
                    Text(journal)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()

                Button {
                    guard !isSaved else { return }
                    let saved = SavedPaper(
                        title: paper.title,
                        authors: paper.authors.joined(separator: ", "),
                        year: paper.year.map { String($0) },
                        journal: paper.journal,
                        doi: paper.doi,
                        abstract: paper.abstract
                    )
                    research.addSavedPaper(saved)
                    isSaved = true
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isSaved ? theme.success : theme.accent)
                }
                .buttonStyle(.plain)
            }

            if isExpanded, let abstract = paper.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.foreground.opacity(0.8))
                    .padding(.top, 4)
            }
        }
        .padding(Spacing.lg)
        .background(
            isHovered ? theme.glassHover : theme.glassBg.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .onTapGesture {
            withAnimation(Motion.quick) { isExpanded.toggle() }
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Labeled Field Helper

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.mutedForeground)
            content
        }
    }
}
