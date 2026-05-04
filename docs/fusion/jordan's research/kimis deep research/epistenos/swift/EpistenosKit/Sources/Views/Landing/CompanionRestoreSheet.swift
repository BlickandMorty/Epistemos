import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - CompanionRestoreSheet
// ---------------------------------------------------------------------------

/// A sheet that lists archived companions and allows restoration.
///
/// Restoration requires `SovereignGate.deviceOwnerAuthentication` per §4.2.
/// Archived companions are automatically purged after 30 days; the sheet
/// shows a dimmed badge for companions near expiry.
public struct CompanionRestoreSheet: View {
    @Environment(CompanionState.self) private var companionState
    @Environment(\.dismiss) private var dismiss

    @State private var archivedCompanions: [CompanionModel] = []
    @State private var isLoading = false
    @State private var selectedCompanion: CompanionModel?
    @State private var errorMessage: String?
    @State private var restoreSuccessID: UUID?

    private let purgeInterval: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Divider()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if archivedCompanions.isEmpty {
                emptyState
            } else {
                archivedList
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(16)
        }
        .frame(minWidth: 400, minHeight: 320)
        .onAppear {
            Task { @MainActor in
                await loadArchived()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Restore Companion")
                    .font(.title3.bold())
                Text("Archived companions are kept for 30 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Archived List

    private var archivedList: some View {
        List(archivedCompanions) { companion in
            HStack(spacing: 12) {
                Circle()
                    .fill(companion.themeColor.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(companion.name.prefix(1)))
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(companion.name)
                        .font(.body)
                    Text("Archived \(companion.relativeLastActive)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if daysUntilPurge(for: companion) <= 7 {
                        Text("Expires in \(daysUntilPurge(for: companion)) days")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                if restoreSuccessID == companion.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Restore") {
                        restore(companion)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Archived companion \(companion.name)")
            .accessibilityHint("Tap Restore to recover this companion.")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No archived companions")
                .font(.headline)
            Text("Deleted companions appear here for 30 days.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadArchived() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await companionState.loadCompanions()
            // Reload from disk to get archived companions too
            guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.epistenos.shared")
            else {
                archivedCompanions = []
                return
            }
            let dir = container.appendingPathComponent("companions", isDirectory: true)
            let url = dir.appendingPathComponent("companions.json")
            guard FileManager.default.fileExists(atPath: url.path) else {
                archivedCompanions = []
                return
            }
            let data = try Data(contentsOf: url)
            let records = try JSONDecoder().decode([CompanionRecord].self, from: data)
            archivedCompanions = records
                .filter { $0.isArchived }
                .map { $0.toModel() }
                .sorted { $0.lastActiveAt > $1.lastActiveAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ companion: CompanionModel) {
        errorMessage = nil
        restoreSuccessID = nil

        Task { @MainActor in
            do {
                try await companionState.restoreCompanion(id: companion.id)
                restoreSuccessID = companion.id
                // Refresh list after a brief delay
                try? await Task.sleep(nanoseconds: 600_000_000)
                await loadArchived()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private func daysUntilPurge(for companion: CompanionModel) -> Int {
        let expiry = companion.lastActiveAt.addingTimeInterval(purgeInterval)
        let remaining = expiry.timeIntervalSince(Date())
        return max(0, Int(ceil(remaining / 86400)))
    }
}

// ---------------------------------------------------------------------------
// MARK: - CompanionRecord (private, for decoding archived companions)
// ---------------------------------------------------------------------------

private struct CompanionRecord: Codable, Identifiable {
    let id: UUID
    var name: String
    var baseProfile: String
    var cosmeticConfig: CosmeticConfig
    var createdAt: Date
    var lastActiveAt: Date
    var isArchived: Bool
    var personalityVector: [Float]?

    init(from model: CompanionModel) {
        self.id = model.id
        self.name = model.name
        self.baseProfile = model.baseProfile
        self.cosmeticConfig = model.cosmeticConfig
        self.createdAt = model.createdAt
        self.lastActiveAt = model.lastActiveAt
        self.isArchived = model.isArchived
        self.personalityVector = model.personalityVector
    }

    func toModel() -> CompanionModel {
        CompanionModel(
            id: id,
            name: name,
            baseProfile: baseProfile,
            cosmeticConfig: cosmeticConfig,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            isArchived: isArchived,
            personalityVector: personalityVector
        )
    }
}

// ---------------------------------------------------------------------------
// MARK: - Preview
// ---------------------------------------------------------------------------

#if DEBUG
#Preview {
    CompanionRestoreSheet()
        .environment(CompanionState())
        .frame(width: 440, height: 360)
}
#endif
