import Foundation
import Observation
import SwiftUI

nonisolated struct VaultRegistryEntry: Identifiable, Hashable, Sendable {
    var identity: VaultIdentity
    var rootURL: URL
    var nodeCount: Int
    var lastModified: Date?

    var id: String {
        switch identity {
        case .model(let name):
            return "model:\(name)"
        case .agent(let name):
            return "agent:\(name)"
        case .team(let names):
            return "team:\(names.joined(separator: ","))"
        case .useCase(let name):
            return "use-case:\(name)"
        case .personal:
            return "personal"
        }
    }
}

@MainActor @Observable
final class VaultRegistry {
    var entries: [VaultRegistryEntry] = []
    var selectedIdentity: VaultIdentity = .personal
    var selectedContextSource: VaultIdentity = .personal
    var selectedGraphFilter: VaultIdentity = .personal

    @ObservationIgnored
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func register(identity: VaultIdentity, path: URL) {
        let entry = VaultRegistryEntry(
            identity: identity,
            rootURL: path,
            nodeCount: markdownNodeCount(in: path),
            lastModified: lastModifiedDate(in: path)
        )

        if let index = entries.firstIndex(where: { $0.identity == identity }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        entries = sorted(entries)
    }

    func resolve(identity: VaultIdentity) -> URL? {
        entries.first(where: { $0.identity == identity })?.rootURL
    }

    func list() -> [VaultRegistryEntry] {
        sorted(entries)
    }

    func mergeVaults(identities: [VaultIdentity]) -> [VaultRegistryEntry] {
        var seenPaths = Set<String>()
        return identities
            .compactMap { identity in
                entries.first(where: { $0.identity == identity })
            }
            .sorted(by: compareEntries)
            .filter { entry in
                seenPaths.insert(entry.rootURL.path).inserted
            }
    }

    func select(_ identity: VaultIdentity) {
        selectedIdentity = identity
        selectedContextSource = identity
        selectedGraphFilter = identity
    }

    private func sorted(_ entries: [VaultRegistryEntry]) -> [VaultRegistryEntry] {
        entries.sorted(by: compareEntries)
    }

    private func compareEntries(_ left: VaultRegistryEntry, _ right: VaultRegistryEntry) -> Bool {
        let leftPriority = priority(for: left.identity)
        let rightPriority = priority(for: right.identity)
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }
        if left.identity.displayName != right.identity.displayName {
            return left.identity.displayName.localizedCaseInsensitiveCompare(right.identity.displayName) == .orderedAscending
        }
        return left.rootURL.path < right.rootURL.path
    }

    private func priority(for identity: VaultIdentity) -> Int {
        switch identity {
        case .agent:
            return 0
        case .team:
            return 1
        case .model:
            return 2
        case .useCase:
            return 3
        case .personal:
            return 4
        }
    }

    private func markdownNodeCount(in rootURL: URL) -> Int {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }

        var count = 0
        for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "md" {
            count += 1
        }
        return count
    }

    private func lastModifiedDate(in rootURL: URL) -> Date? {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return nil
        }

        var latestDate: Date?
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate else {
                continue
            }
            if latestDate == nil || modified > latestDate ?? .distantPast {
                latestDate = modified
            }
        }
        return latestDate
    }
}

struct VaultSwitcher: View {
    @Bindable var registry: VaultRegistry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vaults")
                .font(.headline)

            ForEach(registry.list()) { entry in
                Button {
                    registry.select(entry.identity)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: iconName(for: entry.identity))
                            .font(.title3)
                            .foregroundStyle(registry.selectedIdentity == entry.identity ? .primary : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.identity.displayName)
                                .font(.body.weight(.semibold))
                            Text("\(entry.nodeCount) nodes • \(lastModifiedLabel(for: entry.lastModified))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if registry.selectedIdentity == entry.identity {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(registry.selectedIdentity == entry.identity ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func iconName(for identity: VaultIdentity) -> String {
        switch identity {
        case .model:
            return "brain.head.profile"
        case .agent:
            return "bolt.circle"
        case .team:
            return "person.3"
        case .useCase:
            return "scope"
        case .personal:
            return "person.crop.circle"
        }
    }

    private func lastModifiedLabel(for date: Date?) -> String {
        guard let date else {
            return "never scanned"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
