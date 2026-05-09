import SwiftUI

// MARK: - ArenaHealthRow
//
// Read-only v1 diagnostics for the shared arena scaffold. This does not
// create a memory authority lane or claim mmap activation; it reports the
// existing app-group path, Swift bridge budgets, and whether arena.dat is
// currently materialized on disk.

@MainActor
struct ArenaHealthRow: View {
    @State private var snapshot: Snapshot

    private let container: AppGroupContainer

    init(container: AppGroupContainer = .shared) {
        self.container = container
        self._snapshot = State(initialValue: Self.snapshot(container: container))
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: snapshot.ok ? "memorychip" : "memorychip.fill")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shared arena")
                    .font(.system(size: 13, weight: .medium))
                Text(snapshot.detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: snapshot.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(snapshot.ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.orange))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear { refresh() }
    }

    func refresh() {
        snapshot = Self.snapshot(container: container)
    }

    static func snapshot(
        container: AppGroupContainer = .shared,
        fileManager: FileManager = .default
    ) -> Snapshot {
        do {
            let url = try ArenaPathResolver.resolve(container: container)
            let exists = fileManager.fileExists(atPath: url.path)
            let bytes = fileSize(at: url, fileManager: fileManager)
            let state = exists ? "materialized \(byteCount(bytes))" : "not materialized"
            let detail = [
                "v\(ArenaBridge.arenaVersion)",
                "slots \(ArenaBridge.slotCount)",
                "inline \(ArenaBridge.maxInlinePayloadBytes)/\(ArenaBridge.maxInlineResponseBytes) B",
                state,
                url.path,
            ].joined(separator: " · ")
            return Snapshot(ok: true, path: url.path, exists: exists, byteSize: bytes, detail: detail)
        } catch {
            return Snapshot(
                ok: false,
                path: nil,
                exists: false,
                byteSize: nil,
                detail: "Unavailable — \(error.localizedDescription)"
            )
        }
    }

    private static func fileSize(at url: URL, fileManager: FileManager) -> Int64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    private static func byteCount(_ value: Int64?) -> String {
        guard let value else { return "unknown bytes" }
        return ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    struct Snapshot: Equatable, Sendable {
        let ok: Bool
        let path: String?
        let exists: Bool
        let byteSize: Int64?
        let detail: String
    }
}
