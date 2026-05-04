import SwiftUI
import Combine

// MARK: - Data Models

public enum ProvenanceFilter: String, CaseIterable {
    case all = "All"
    case user = "User"
    case agent = "Agent"
    case tool = "Tool"
    case security = "Security"
    case error = "Errors"
}

public enum EventTier: String {
    case core = "Core"
    case pro = "Pro"
    case research = "Research"
}

public enum EventStatus: String {
    case success = "✓"
    case failure = "✗"
    case pending = "◌"
}

public struct ProvenanceEventRow: Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let actor: String           // "user", "agent", "tool", "xpc", "provider"
    public let action: String          // "tool_call", "vault_create", "summary", etc.
    public let tier: EventTier         // Core, Pro, Research
    public let status: EventStatus     // success, failure, pending
    public let hash: String            // BLAKE3 hex
    public let prevHash: String        // chain link
    public let metadata: [String: String] // sanitized metadata

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        actor: String,
        action: String,
        tier: EventTier,
        status: EventStatus,
        hash: String,
        prevHash: String,
        metadata: [String: String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actor = actor
        self.action = action
        self.tier = tier
        self.status = status
        self.hash = hash
        self.prevHash = prevHash
        self.metadata = metadata
    }
}

// MARK: - Event Row View

public struct ProvenanceEventRowView: View {
    let event: ProvenanceEventRow

    public init(event: ProvenanceEventRow) {
        self.event = event
    }

    public var body: some View {
        HStack {
            Text(event.status.rawValue)
                .font(.caption)
                .foregroundStyle(statusColor)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.action)
                    .font(.headline)
                Text(event.actor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.timestamp, style: .time)
                    .font(.caption)
                Text(event.tier.rawValue)
                    .font(.caption2)
                    .foregroundStyle(tierColor)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch event.status {
        case .success: return .green
        case .failure: return .red
        case .pending: return .orange
        }
    }

    private var tierColor: Color {
        switch event.tier {
        case .core: return .blue
        case .pro: return .purple
        case .research: return .orange
        }
    }
}

// MARK: - Event Detail View

public struct ProvenanceEventDetailView: View {
    let event: ProvenanceEventRow

    public init(event: ProvenanceEventRow) {
        self.event = event
    }

    public var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: event.id.uuidString)
                LabeledContent("Actor", value: event.actor)
                LabeledContent("Action", value: event.action)
                LabeledContent("Tier", value: event.tier.rawValue)
                LabeledContent("Status", value: event.status.rawValue)
            }

            Section("Chain") {
                LabeledContent("Hash", value: event.hash)
                    .lineLimit(1)
                    .truncationMode(.middle)
                LabeledContent("Previous", value: event.prevHash)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Section("Timestamp") {
                LabeledContent("Date", value: event.timestamp, format: .dateTime)
            }

            if !event.metadata.isEmpty {
                Section("Metadata") {
                    ForEach(event.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 240)
    }
}

// MARK: - Main Console View

public struct ProvenanceConsoleView: View {
    @State private var state: ProvenanceConsoleState

    public init(state: ProvenanceConsoleState) {
        self._state = State(initialValue: state)
    }

    public var body: some View {
        NavigationSplitView {
            // MARK: Sidebar — Filter + Search + Controls
            List {
                Section("Filter") {
                    Picker("Filter", selection: $state.filter) {
                        ForEach(ProvenanceFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section("Search") {
                    TextField("Search actions or actors…", text: $state.searchQuery)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Live Feed") {
                    Toggle("Live Updates", isOn: $state.isLive)
                }

                Section("Export") {
                    Button("Export JSON…") {
                        Task { await exportJSON() }
                    }
                    .disabled(state.events.isEmpty)
                }

                Section("Stats") {
                    LabeledContent("Total Events", value: "\(state.events.count)")
                    LabeledContent("Filtered", value: "\(state.filteredEvents.count)")
                }
            }
            .frame(minWidth: 200, idealWidth: 220)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)

        } detail: {
            // MARK: Detail — Event List
            List(state.filteredEvents, selection: $state.selectedEvent) {
                ProvenanceEventRowView(event: $0)
                    .tag($0)
            }
            .frame(minWidth: 400, idealWidth: 500)
            .navigationSplitViewColumnWidth(min: 400, ideal: 500)
            .overlay {
                if state.filteredEvents.isEmpty {
                    ContentUnavailableView {
                        Label("No Events", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text(state.events.isEmpty
                            ? "Waiting for events…"
                            : "No events match the current filter.")
                    }
                }
            }

        } inspector: {
            // MARK: Inspector — Selected Event Detail
            if let selected = state.selectedEvent {
                ProvenanceEventDetailView(event: selected)
                    .navigationTitle("Event Detail")
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Select an event")
                        .foregroundStyle(.secondary)
                    Text("Choose an event from the list to inspect its chain, metadata, and identity.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task { await state.loadEvents() }
        .refreshable { await state.loadEvents() }
        .onAppear { state.startLivePolling() }
        .onDisappear { state.stopLivePolling() }
        .onChange(of: state.isLive) { _, isLive in
            if isLive {
                state.startLivePolling()
            } else {
                state.stopLivePolling()
            }
        }
    }

    // MARK: - Export

    private func exportJSON() async {
        let data = await state.exportToJSON()
        guard !data.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "provenance_export_\(ISO8601DateFormatter().string(from: Date())).json"

        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url)
        } catch {
            print("Export failed: \(error)")
        }
    }
}
