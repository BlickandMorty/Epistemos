import SwiftUI

nonisolated struct AgentRunTimelineItem: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case running
        case complete
        case failed
        case denied
        case informational
    }

    let id: String
    let sequence: UInt64
    let title: String
    let detail: String
    let status: Status
    let occurredAt: Date

    static func replayItems(from events: [AgentProvenanceEvent]) -> [AgentRunTimelineItem] {
        events.sorted {
            if $0.sequence == $1.sequence {
                return $0.occurredAtMs < $1.occurredAtMs
            }
            return $0.sequence < $1.sequence
        }
        .map(Self.init(event:))
    }

    init(event: AgentProvenanceEvent) {
        self.id = event.eventID
        self.sequence = event.sequence
        self.occurredAt = Date(timeIntervalSince1970: Double(event.occurredAtMs) / 1_000)
        self.title = Self.title(for: event)
        self.detail = Self.detail(for: event)
        self.status = Self.status(for: event)
    }

    private static func title(for event: AgentProvenanceEvent) -> String {
        switch event.kind {
        case .runStarted:
            return "Plan"
        case .routerDecision:
            return "Route"
        case .toolCallRequested:
            return "Approve"
        case .toolCallApproved:
            return "Approved"
        case .toolCallDenied:
            return "Denied"
        case .toolCallStarted:
            return toolTitle(event.tool?.toolName)
        case .toolCallCompleted:
            return "\(toolTitle(event.tool?.toolName)) done"
        case .toolCallFailed:
            return "\(toolTitle(event.tool?.toolName)) failed"
        case .runCompleted:
            return "Output"
        case .summaryStarted, .summaryDelta, .summaryCompleted:
            return "Summary"
        case .hookRegistered, .hookFired, .hookCompleted:
            return "Hook"
        case .steerRequested:
            return "Steer"
        case .vaultCreated, .vaultArchived:
            return "Vault"
        }
    }

    private static func toolTitle(_ toolName: String?) -> String {
        guard let toolName = clean(toolName) else { return "Tool" }
        let lowercased = toolName.lowercased()
        if lowercased.contains("search") || lowercased.contains("grep") {
            return "Search"
        }
        if lowercased.contains("read") || lowercased.contains("open") {
            return "Read"
        }
        if lowercased.contains("write") || lowercased.contains("edit") {
            return "Write"
        }
        return "Tool"
    }

    private static func detail(for event: AgentProvenanceEvent) -> String {
        if event.kind == .runCompleted,
           let packetDetail = answerPacketDetail(for: event.metadata) {
            return bounded(packetDetail)
        }

        if let tool = event.tool {
            switch event.kind {
            case .toolCallRequested, .toolCallApproved, .toolCallDenied, .toolCallStarted:
                return bounded(tool.toolName)
            case .toolCallCompleted:
                if let durationMs = tool.durationMs {
                    return "\(tool.toolName) | \(durationMs) ms"
                }
                return bounded(tool.toolName)
            case .toolCallFailed:
                let reason = clean(tool.errorMessage) ?? "failed"
                return bounded("\(tool.toolName) | \(reason)")
            default:
                break
            }
        }

        if let model = clean(event.metadata["model"]) ?? clean(event.metadata["provider"]) {
            return bounded(model)
        }
        if let reason = clean(event.metadata["stop_reason"]) ?? clean(event.metadata["outcome"]) {
            return bounded(reason)
        }
        return bounded(event.kind.rawValue)
    }

    private static func answerPacketDetail(for metadata: [String: String]) -> String? {
        guard let packetID = clean(metadata["answer_packet_id"]) else { return nil }
        var parts = ["packet=\(packetID)"]
        if let label = clean(metadata["answer_packet_ui_label"]) {
            parts.append("label=\(label)")
        }
        if let mode = clean(metadata["answer_packet_attention_mode"]) {
            parts.append("mode=\(mode)")
        }
        if let bucket = clean(metadata["answer_packet_interrupt_bucket"]) {
            parts.append("bucket=\(bucket)")
        }
        return parts.joined(separator: " | ")
    }

    private static func status(for event: AgentProvenanceEvent) -> Status {
        switch event.kind {
        case .runCompleted, .toolCallCompleted, .toolCallApproved, .summaryCompleted, .hookCompleted:
            return .complete
        case .toolCallFailed:
            return .failed
        case .toolCallDenied:
            return .denied
        case .runStarted, .toolCallStarted, .summaryStarted, .hookFired:
            return .running
        default:
            return .informational
        }
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func bounded(_ value: String) -> String {
        guard value.count > 96 else { return value }
        return "\(value.prefix(93))..."
    }
}

@MainActor
struct AgentRunTimelineView: View {
    let runID: String

    @State private var items: [AgentRunTimelineItem] = []
    @State private var isExpanded = true

    private var normalizedRunID: String {
        runID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if !normalizedRunID.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                header
                if isExpanded {
                    timelineRows
                }
            }
            .padding(.vertical, 4)
            .onAppear(perform: replay)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "timeline.selection")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Button {
                isExpanded.toggle()
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Run timeline")
                        .font(.system(size: 11, weight: .semibold))
                    Text(headerDetail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: replay) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Replay timeline")
            .accessibilityLabel("Replay timeline")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var headerDetail: String {
        let shortRun = String(normalizedRunID.prefix(12))
        guard !items.isEmpty else {
            return "waiting | \(shortRun)"
        }
        return "\(items.count) events | \(shortRun)"
    }

    @ViewBuilder
    private var timelineRows: some View {
        if items.isEmpty {
            Text("No committed events")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    AgentRunTimelineRow(item: item)
                }
            }
        }
    }

    private func replay() {
        let events = EventStore.shared?.agentEvents(runID: normalizedRunID, limit: 64) ?? []
        items = AgentRunTimelineItem.replayItems(from: events)
    }
}

@MainActor
private struct AgentRunTimelineRow: View {
    let item: AgentRunTimelineItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 11, weight: .medium))
                    Text("#\(item.sequence)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(item.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.leading, 2)
    }

    private var symbolName: String {
        switch item.status {
        case .running:
            return "circle"
        case .complete:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .denied:
            return "nosign"
        case .informational:
            return "circle.dotted"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .running:
            return .secondary
        case .complete:
            return .green
        case .failed:
            return .red
        case .denied:
            return .orange
        case .informational:
            return .secondary
        }
    }
}
