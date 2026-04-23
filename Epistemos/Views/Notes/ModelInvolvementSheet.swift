import SwiftData
import SwiftUI

enum ModelInvolvementContentVariant: Equatable {
    case sheet
    case inline(maxRows: Int?)
}

nonisolated enum ModelInvolvementFilter: String, CaseIterable, Equatable, Identifiable {
    case all
    case reasoning
    case notes
    case tools
    case structured

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "All"
        case .reasoning:
            "Reasoning"
        case .notes:
            "Note Work"
        case .tools:
            "Tool Use"
        case .structured:
            "Outputs"
        }
    }

    func matches(_ contribution: ModelInvolvementContributionRecord) -> Bool {
        switch self {
        case .all:
            true
        case .reasoning:
            contribution.hasThinkingTrace
        case .notes:
            contribution.isNoteLinked
        case .tools:
            contribution.hasTooling
        case .structured:
            contribution.isStructured
        }
    }
}

nonisolated struct ModelInvolvementContributionSummary: Equatable {
    let totalContributions: Int
    let threadCount: Int
    let reasoningCount: Int
    let noteLinkedCount: Int
    let toolingCount: Int
    let structuredCount: Int
    let latestContributionAt: Date?
}

nonisolated struct ModelInvolvementContributionRecord: Identifiable, Equatable {
    let id: String
    let chatID: String
    let chatTitle: String
    let chatType: String
    let linkedPageID: String?
    let createdAt: Date
    let providerID: String?
    let preview: String
    let hasThinkingTrace: Bool
    let thinkingDurationSeconds: Double?
    let attachmentCount: Int
    let loadedNoteCount: Int
    let contextAttachmentCount: Int
    let artifactCount: Int
    let toolCallCount: Int
    let toolResultCount: Int
    let toolErrorCount: Int
    let toolNames: [String]
    let isError: Bool
    let isVaultBriefing: Bool

    @MainActor
    init(message: SDMessage) {
        let chat = message.chat
        let chatMessage = message.chatMessage(chatId: chat?.id ?? "")
        let contentBlocks = chatMessage.contentBlocks ?? []
        let trimmedTitle = chat?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedContent = chatMessage.effectiveText.trimmingCharacters(in: .whitespacesAndNewlines)

        self.id = message.id
        self.chatID = chat?.id ?? ""
        self.chatTitle = trimmedTitle.isEmpty ? "Untitled chat" : trimmedTitle
        self.chatType = chat?.chatType ?? "chat"
        self.linkedPageID = chat?.linkedPageId
        self.createdAt = message.createdAt
        self.providerID = message.authoredByProviderID
        self.hasThinkingTrace = !(message.thinkingTrace?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        self.thinkingDurationSeconds = message.thinkingDurationSeconds
        self.attachmentCount = chatMessage.attachments.count
        self.loadedNoteCount = chatMessage.loadedNoteTitles?.count ?? 0
        self.contextAttachmentCount = chatMessage.contextAttachments?.count ?? 0
        self.artifactCount = chatMessage.artifacts.count
        self.toolCallCount = contentBlocks.toolUseBlocks.count
        self.toolResultCount = contentBlocks.reduce(into: 0) { count, block in
            if case .toolResult = block {
                count += 1
            }
        }
        self.toolErrorCount = contentBlocks.reduce(into: 0) { count, block in
            if case .toolResult(_, _, let isError) = block, isError {
                count += 1
            }
        }
        self.toolNames = Self.orderedUnique(
            contentBlocks.toolUseBlocks.map { Self.displayToolName($0.name) }
        )
        self.isError = message.isError
        self.isVaultBriefing = message.isVaultBriefing

        if !trimmedContent.isEmpty {
            self.preview = Self.previewText(from: trimmedContent)
        } else if let toolPreview = Self.toolPreview(from: contentBlocks) {
            self.preview = toolPreview
        } else if !chatMessage.artifacts.isEmpty {
            self.preview = "Structured output captured for this turn."
        } else if hasThinkingTrace {
            self.preview = "Reasoning trace captured for this turn."
        } else if message.isVaultBriefing {
            self.preview = "Vault briefing captured for this turn."
        } else {
            self.preview = "Contribution recorded for this turn."
        }
    }

    private static func previewText(from text: String) -> String {
        let compact = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= 240 {
            return compact
        }
        return String(compact.prefix(240)) + "..."
    }

    private static func toolPreview(from blocks: [MessageContentBlock]) -> String? {
        for block in blocks {
            if case .toolResult(_, let content, _) = block {
                let preview = previewText(from: content)
                if !preview.isEmpty {
                    return preview
                }
            }
        }

        for block in blocks {
            switch block {
            case .toolUse(_, let name, _):
                return "Used \(displayToolName(name))"
            default:
                continue
            }
        }
        return nil
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func displayToolName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
    }

    var threadIdentity: String {
        if !chatID.isEmpty {
            return chatID
        }
        return "title:\(chatTitle.lowercased())"
    }

    var isNoteLinked: Bool {
        chatType == "notes" || linkedPageID != nil || loadedNoteCount > 0 || contextAttachmentCount > 0
    }

    var hasTooling: Bool {
        toolCallCount > 0 || toolResultCount > 0
    }

    var isStructured: Bool {
        artifactCount > 0
    }

    var surfaceLabel: String {
        switch chatType {
        case "notes":
            "Notes Chat"
        case "worker":
            "Worker Session"
        case "codeAsk":
            "Code Ask"
        case "dialogue":
            "Dialogue"
        case "aiPartner":
            "AI Partner"
        default:
            "Chat"
        }
    }

    var metadataLine: String {
        var parts = [surfaceLabel]

        if hasThinkingTrace {
            if let seconds = thinkingDurationSeconds,
               seconds.isFinite,
               seconds > 0 {
                parts.append("Reasoned \(Self.formattedSeconds(seconds))")
            } else {
                parts.append("Reasoning trace")
            }
        }

        if loadedNoteCount > 0 {
            parts.append("\(loadedNoteCount) note\(loadedNoteCount == 1 ? "" : "s")")
        }

        if contextAttachmentCount > 0 {
            parts.append("\(contextAttachmentCount) linked context")
        }

        if let toolSummaryLine {
            parts.append(toolSummaryLine)
        }

        if attachmentCount > 0 {
            parts.append("\(attachmentCount) attachment\(attachmentCount == 1 ? "" : "s")")
        }

        if artifactCount > 0 {
            parts.append("\(artifactCount) artifact\(artifactCount == 1 ? "" : "s")")
        }

        if toolErrorCount > 0 {
            parts.append("\(toolErrorCount) tool error\(toolErrorCount == 1 ? "" : "s")")
        }

        if isVaultBriefing {
            parts.append("Vault briefing")
        }

        if isError {
            parts.append("Error")
        }

        if let providerID,
           !providerID.isEmpty {
            parts.append(Self.providerDisplayName(for: providerID))
        }

        return parts.joined(separator: " • ")
    }

    var kindBadges: [String] {
        var badges: [String] = []
        if hasThinkingTrace {
            badges.append("Reasoned")
        }
        if isNoteLinked {
            badges.append("Note Work")
        }
        if hasTooling {
            badges.append("Tool Use")
        }
        if isStructured {
            badges.append("Output")
        }
        if isVaultBriefing {
            badges.append("Vault Briefing")
        }
        if isError || toolErrorCount > 0 {
            badges.append("Error")
        }
        return badges
    }

    private var toolSummaryLine: String? {
        guard hasTooling else { return nil }

        if !toolNames.isEmpty {
            let listedTools = toolNames.prefix(2).joined(separator: ", ")
            let overflow = toolNames.count > 2 ? ", +\(toolNames.count - 2) more" : ""
            if toolCallCount <= 1 {
                return "Used \(listedTools)\(overflow)"
            }
            return "\(toolCallCount) tool runs: \(listedTools)\(overflow)"
        }

        if toolCallCount > 0 {
            return "\(toolCallCount) tool run\(toolCallCount == 1 ? "" : "s")"
        }

        return "\(toolResultCount) tool result\(toolResultCount == 1 ? "" : "s")"
    }

    private static func formattedSeconds(_ seconds: Double) -> String {
        let safeSeconds = max(0, seconds)
        if safeSeconds >= 60 {
            let minutes = Int(safeSeconds) / 60
            let remainder = Int(safeSeconds) % 60
            if remainder == 0 {
                return "\(minutes)m"
            }
            return "\(minutes)m \(remainder)s"
        }
        if safeSeconds >= 10 {
            return "\(Int(safeSeconds.rounded()))s"
        }
        return String(format: "%.1fs", safeSeconds)
    }

    private static func providerDisplayName(for providerID: String) -> String {
        switch providerID {
        case "openai":
            "OpenAI"
        case "anthropic":
            "Anthropic"
        case "google":
            "Google"
        case "local":
            "Local"
        case "appleIntelligence":
            "Apple Intelligence"
        default:
            providerID
        }
    }
}

nonisolated struct ModelInvolvementContributionSession: Identifiable, Equatable {
    let id: String
    let title: String
    let surfaceLabel: String
    let contributions: [ModelInvolvementContributionRecord]
    let latestContributionAt: Date
    let reasoningCount: Int
    let noteLinkedCount: Int
    let toolingCount: Int
    let structuredCount: Int

    var subtitle: String {
        var parts = [
            surfaceLabel,
            "\(contributions.count) contribution\(contributions.count == 1 ? "" : "s")",
        ]

        if reasoningCount > 0 {
            parts.append("\(reasoningCount) reasoned")
        }
        if noteLinkedCount > 0 {
            parts.append("\(noteLinkedCount) note-linked")
        }
        if toolingCount > 0 {
            parts.append("\(toolingCount) tool-driven")
        }
        if structuredCount > 0 {
            parts.append("\(structuredCount) output\(structuredCount == 1 ? "" : "s")")
        }

        return parts.joined(separator: " • ")
    }
}

/// Pass 11 — Per-model "involvement" view.
///
/// Given a `modelID`, shows every substantive `SDMessage` this model
/// authored across chats, worker sessions, and note flows. Cloud
/// models accept both the current vendor model id (`gpt-5.4`) and the
/// legacy provider-qualified id (`openai:gpt-5.4`) so older histories
/// still surface after the curated provider simplification.
struct ModelInvolvementSheet: View {
    let modelID: String

    @Environment(\.dismiss) private var dismiss

    private var prettyModelName: String {
        ModelVaultEntry.presentation(for: modelID).displayName
    }

    var body: some View {
        NavigationStack {
            ModelInvolvementContent(modelID: modelID)
                .navigationTitle(prettyModelName)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 480, minHeight: 520)
    }
}

struct ModelInvolvementContent: View {
    let modelID: String
    let acceptedModelIDs: Set<String>
    let variant: ModelInvolvementContentVariant

    @Environment(\.modelContext) private var modelContext
    @State private var contributions: [ModelInvolvementContributionRecord] = []
    @State private var selectedFilter: ModelInvolvementFilter = .all
    @State private var showsAllInlineContributions = false

    init(
        modelID: String,
        acceptedModelIDs: Set<String>? = nil,
        variant: ModelInvolvementContentVariant = .sheet
    ) {
        self.modelID = modelID
        self.acceptedModelIDs = acceptedModelIDs ?? ModelVaultEntry.acceptedModelIDs(for: modelID)
        self.variant = variant
    }

    private var prettyModelName: String {
        ModelVaultEntry.presentation(for: modelID).displayName
    }

    private var acceptedModelIDsKey: String {
        acceptedModelIDs.sorted().joined(separator: "|")
    }

    private var summary: ModelInvolvementContributionSummary {
        Self.summarize(contributions)
    }

    private var summaryColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: isInline ? 2 : 3
        )
    }

    private var filteredContributions: [ModelInvolvementContributionRecord] {
        contributions.filter { selectedFilter.matches($0) }
    }

    private var visibleContributions: [ModelInvolvementContributionRecord] {
        switch variant {
        case .sheet:
            return filteredContributions
        case .inline(let maxRows):
            guard let maxRows,
                  !showsAllInlineContributions else {
                return filteredContributions
            }
            return Array(filteredContributions.prefix(maxRows))
        }
    }

    private var hiddenContributionCount: Int {
        max(0, filteredContributions.count - visibleContributions.count)
    }

    private var groupedVisibleContributions: [ModelInvolvementContributionSession] {
        Self.groupedContributions(visibleContributions)
    }

    private var isInline: Bool {
        if case .inline = variant {
            return true
        }
        return false
    }

    private var filterCounts: [ModelInvolvementFilter: Int] {
        Dictionary(uniqueKeysWithValues: ModelInvolvementFilter.allCases.map { filter in
            (filter, contributions.filter { filter.matches($0) }.count)
        })
    }

    var body: some View {
        Group {
            if contributions.isEmpty {
                emptyState
            } else {
                switch variant {
                case .sheet:
                    ScrollView {
                        involvementContent
                            .padding(16)
                    }
                case .inline:
                    involvementContent
                }
            }
        }
        .task(id: acceptedModelIDsKey) {
            reload()
        }
        .onChange(of: selectedFilter) { _, _ in
            showsAllInlineContributions = false
        }
    }

    private var involvementContent: some View {
        VStack(alignment: .leading, spacing: isInline ? 10 : 14) {
            summaryPanel
            filterBar

            if filteredContributions.isEmpty {
                filteredEmptyState
            } else {
                timelineHeader

                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(groupedVisibleContributions) { session in
                        ModelInvolvementSessionCard(
                            session: session,
                            compact: isInline
                        )
                    }
                }

                if hiddenContributionCount > 0 {
                    Button {
                        showsAllInlineContributions = true
                    } label: {
                        Text("Show all \(filteredContributions.count) \(selectedFilter.title.lowercased()) contributions")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                } else if isInline,
                          case .inline(let maxRows) = variant,
                          maxRows != nil,
                          showsAllInlineContributions,
                          filteredContributions.count > (maxRows ?? 0) {
                    Button {
                        showsAllInlineContributions = false
                    } label: {
                        Text("Show recent view")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
        }
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(
                columns: summaryColumns,
                alignment: .leading,
                spacing: 8
            ) {
                ModelInvolvementStatCard(
                    title: "Contributions",
                    value: "\(summary.totalContributions)",
                    compact: isInline
                )
                ModelInvolvementStatCard(
                    title: "Threads",
                    value: "\(summary.threadCount)",
                    compact: isInline
                )
                ModelInvolvementStatCard(
                    title: "Reasoned",
                    value: "\(summary.reasoningCount)",
                    compact: isInline
                )
                ModelInvolvementStatCard(
                    title: "Note Work",
                    value: "\(summary.noteLinkedCount)",
                    compact: isInline
                )
                ModelInvolvementStatCard(
                    title: "Tool Use",
                    value: "\(summary.toolingCount)",
                    compact: isInline
                )
                ModelInvolvementStatCard(
                    title: "Outputs",
                    value: "\(summary.structuredCount)",
                    compact: isInline
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Tracks chats, note work, tool use, reasoning, and saved outputs.")
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if let latestContributionAt = summary.latestContributionAt {
                    Text("Latest \(latestContributionAt, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ModelInvolvementFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 4) {
                            Text(filter.title)
                            Text("\(filterCounts[filter] ?? 0)")
                                .foregroundStyle(selectedFilter == filter ? .primary : .tertiary)
                        }
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    selectedFilter == filter
                                        ? Color.secondary.opacity(0.16)
                                        : Color.secondary.opacity(0.08)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedFilter == filter ? .primary : .secondary)
                }
            }
        }
    }

    private var timelineHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Contribution Timeline")
                    .font(isInline ? .caption.weight(.semibold) : .headline)
                Spacer(minLength: 0)
                Text("\(visibleContributions.count) shown")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(
                selectedFilter == .all
                    ? "Every authored turn grouped by the thread where it shaped notes, reasoning, tools, or outputs."
                    : "Filtered to the turns where this model contributed \(selectedFilter.title.lowercased())."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No contributions yet from \(prettyModelName).")
                .font(.headline)
            Text("Turns this model authors will show up here automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredEmptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No \(selectedFilter.title.lowercased()) contributions yet")
                .font(.subheadline.weight(.semibold))
            Text("This model has contributed here, but not through that contribution type yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Show all contributions") {
                selectedFilter = .all
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func reload() {
        let messages = Self.loadContributions(
            modelIDs: acceptedModelIDs,
            in: modelContext
        )
        contributions = Self.makeContributionRecords(from: messages)
    }

    @MainActor
    static func makeContributionRecords(
        from messages: [SDMessage]
    ) -> [ModelInvolvementContributionRecord] {
        messages.map(ModelInvolvementContributionRecord.init(message:))
    }

    nonisolated static func summarize(
        _ contributions: [ModelInvolvementContributionRecord]
    ) -> ModelInvolvementContributionSummary {
        let threadCount = Set(contributions.map(\.threadIdentity)).count
        let latestContributionAt = contributions.map(\.createdAt).max()

        return ModelInvolvementContributionSummary(
            totalContributions: contributions.count,
            threadCount: threadCount,
            reasoningCount: contributions.filter(\.hasThinkingTrace).count,
            noteLinkedCount: contributions.filter(\.isNoteLinked).count,
            toolingCount: contributions.filter(\.hasTooling).count,
            structuredCount: contributions.filter(\.isStructured).count,
            latestContributionAt: latestContributionAt
        )
    }

    nonisolated static func groupedContributions(
        _ contributions: [ModelInvolvementContributionRecord],
        filter: ModelInvolvementFilter = .all
    ) -> [ModelInvolvementContributionSession] {
        let filtered = contributions.filter { filter.matches($0) }
        let grouped = Dictionary(grouping: filtered, by: \.threadIdentity)

        return grouped.values.compactMap { threadContributions in
            guard let latest = threadContributions.map(\.createdAt).max(),
                  let seed = threadContributions.first else {
                return nil
            }

            let ordered = threadContributions.sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id > rhs.id
                }
                return lhs.createdAt > rhs.createdAt
            }

            return ModelInvolvementContributionSession(
                id: seed.threadIdentity,
                title: seed.chatTitle,
                surfaceLabel: seed.surfaceLabel,
                contributions: ordered,
                latestContributionAt: latest,
                reasoningCount: ordered.filter(\.hasThinkingTrace).count,
                noteLinkedCount: ordered.filter(\.isNoteLinked).count,
                toolingCount: ordered.filter(\.hasTooling).count,
                structuredCount: ordered.filter(\.isStructured).count
            )
        }
        .sorted { lhs, rhs in
            if lhs.latestContributionAt == rhs.latestContributionAt {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.latestContributionAt > rhs.latestContributionAt
        }
    }

    @MainActor
    static func loadContributions(
        modelIDs: Set<String>,
        in modelContext: ModelContext
    ) -> [SDMessage] {
        guard !modelIDs.isEmpty else { return [] }

        var mergedByID: [String: SDMessage] = [:]
        for acceptedModelID in modelIDs {
            let descriptor = FetchDescriptor<SDMessage>(
                predicate: #Predicate<SDMessage> { $0.authoredByModelID == acceptedModelID },
                sortBy: [SortDescriptor(\SDMessage.createdAt, order: .reverse)]
            )
            guard let fetched = try? modelContext.fetch(descriptor) else { continue }
            for message in fetched where message.role == "assistant" {
                mergedByID[message.id] = message
            }
        }

        return mergedByID.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

private struct ModelInvolvementSessionCard: View {
    let session: ModelInvolvementContributionSession
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(compact ? .caption.weight(.semibold) : .headline)
                        .lineLimit(1)
                    Text(session.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text(session.latestContributionAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(session.contributions.enumerated()), id: \.element.id) { index, contribution in
                    ModelInvolvementRow(
                        contribution: contribution,
                        compact: compact
                    )
                    if index < session.contributions.count - 1 {
                        Divider()
                            .padding(.leading, compact ? 0 : 4)
                    }
                }
            }
        }
        .padding(compact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

private struct ModelInvolvementRow: View {
    let contribution: ModelInvolvementContributionRecord
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(contribution.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)

                if contribution.hasThinkingTrace {
                    Label("Reasoned", systemImage: "brain")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(contribution.preview)
                .font(compact ? .caption : .body)
                .foregroundStyle(.primary)
                .lineLimit(compact ? 5 : 8)

            if !contribution.kindBadges.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: compact ? 72 : 88), spacing: 6)],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(contribution.kindBadges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                }
            }

            Text(contribution.metadataLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, compact ? 7 : 8)
    }
}

private struct ModelInvolvementStatCard: View {
    let title: String
    let value: String
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}
