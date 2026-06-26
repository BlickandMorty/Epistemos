import AppKit
import SwiftUI

struct SystemModeView: View {
    @State private var sections: [SystemSidebarSectionModel] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(sections) { section in
                        SystemSidebarSectionView(section: section)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            reload()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("System")
                .font(.title2.weight(.semibold))
            Spacer(minLength: 0)
            Button {
                reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func reload() {
        sections = Self.sections(vaultURL: AppBootstrap.shared?.vaultSync.vaultURL, fileManager: .default)
    }

    nonisolated static func sections(
        vaultURL: URL?,
        limit: Int = 8
    ) -> [SystemSidebarSectionModel] {
        sections(vaultURL: vaultURL, fileManager: FileManager(), limit: limit)
    }

    nonisolated static func sections(
        vaultURL: URL?,
        fileManager: FileManager,
        limit: Int = 8
    ) -> [SystemSidebarSectionModel] {
        let specs = SystemSidebarSectionSpec.defaultSpecs
        guard let vaultURL else {
            return specs.map {
                SystemSidebarSectionModel(
                    title: $0.title,
                    systemImage: $0.systemImage,
                    status: "No vault connected",
                    items: []
                )
            }
        }

        return specs.map { spec in
            let directories = spec.relativeDirectories.map { vaultURL.appendingPathComponent($0, isDirectory: true) }
            let items = Self.items(in: directories, fileManager: fileManager, limit: limit)
            return SystemSidebarSectionModel(
                title: spec.title,
                systemImage: spec.systemImage,
                status: items.isEmpty ? "No files yet" : "\(items.count) recent",
                items: items
            )
        }
    }

    nonisolated static func items(
        in directories: [URL],
        limit: Int = 8
    ) -> [SystemSidebarItem] {
        items(in: directories, fileManager: FileManager(), limit: limit)
    }

    nonisolated static func items(
        in directories: [URL],
        fileManager: FileManager,
        limit: Int = 8
    ) -> [SystemSidebarItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey]
        let items = directories.flatMap { directory -> [SystemSidebarItem] in
            guard let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }
            return urls.compactMap { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return SystemSidebarItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: url.deletingLastPathComponent().lastPathComponent,
                    url: url,
                    isDirectory: values?.isDirectory == true,
                    modifiedAt: values?.contentModificationDate ?? .distantPast
                )
            }
        }
        return Array(items.sorted { lhs, rhs in
            if lhs.modifiedAt == rhs.modifiedAt {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }.prefix(max(0, limit)))
    }
}

nonisolated struct SystemSidebarSectionSpec: Sendable, Equatable {
    let title: String
    let systemImage: String
    let relativeDirectories: [String]

    nonisolated static let defaultSpecs: [SystemSidebarSectionSpec] = [
        .init(title: "System Prompts", systemImage: "text.badge.star", relativeDirectories: [
            "System Prompts",
            ".epistemos/System Prompts",
            ".epistemos/system-prompts",
        ]),
        .init(title: "Doc Chat Exports", systemImage: "doc.text", relativeDirectories: [
            "Doc Chat Exports",
            ".epistemos/Doc Chat Exports",
        ]),
        .init(title: "Agent Logs", systemImage: "terminal", relativeDirectories: [
            "sessions",
            "Agent Logs",
            ".epistemos/agent-logs",
        ]),
        .init(title: "Skill Outputs", systemImage: "wand.and.stars", relativeDirectories: [
            "Skill Outputs",
            ".epistemos/skill-outputs",
        ]),
    ]
}

nonisolated struct SystemSidebarSectionModel: Identifiable, Sendable, Equatable {
    var id: String { title }
    let title: String
    let systemImage: String
    let status: String
    let items: [SystemSidebarItem]
}

nonisolated struct SystemSidebarItem: Identifiable, Sendable, Equatable {
    var id: String { url.path }
    let title: String
    let subtitle: String
    let url: URL
    let isDirectory: Bool
    let modifiedAt: Date
}

private struct SystemSidebarSectionView: View {
    let section: SystemSidebarSectionModel

    var body: some View {
        DisclosureGroup {
            if section.items.isEmpty {
                Text(section.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 30)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(section.items) { item in
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([item.url])
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.isDirectory ? "folder" : "doc.text")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .lineLimit(1)
                                    Text(item.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .font(.caption)
                            .padding(.vertical, 4)
                            .padding(.leading, 20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Label(section.title, systemImage: section.systemImage)
                    .font(.callout.weight(.medium))
                Spacer(minLength: 0)
                Text(section.status)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }
}
