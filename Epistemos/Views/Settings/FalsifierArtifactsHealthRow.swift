import Darwin
import Foundation
import SwiftUI

nonisolated enum FalsifierArtifactResultReader {
    static let maxArtifactDirectories = 128
    static let maxArtifactDirectoryCandidates = 512
    static let maxResultBytes = 256 * 1024

    static func artifactDirectories(
        in root: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        guard isReadableDirectory(root, fileManager: fileManager),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
                options: [.skipsSubdirectoryDescendants]
              ) else {
            return []
        }

        var dirs: [URL] = []
        var inspectedCandidates = 0
        for case let url as URL in enumerator {
            guard inspectedCandidates < maxArtifactDirectoryCandidates else { break }
            inspectedCandidates += 1
            guard dirs.count < maxArtifactDirectories else { break }
            guard isReadableDirectory(url, fileManager: fileManager),
                  hasReadableResultFile(
                    url.appendingPathComponent("result.json"),
                    fileManager: fileManager
                  ) else {
                continue
            }
            dirs.append(url)
        }
        return dirs
    }

    static func jsonObject(
        at resultPath: URL,
        fileManager: FileManager = .default
    ) -> [String: Any]? {
        guard let data = resultData(at: resultPath, fileManager: fileManager) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func resultData(
        at resultPath: URL,
        fileManager: FileManager = .default
    ) -> Data? {
        guard resultPath.isFileURL,
              fileManager.isReadableFile(atPath: resultPath.path),
              (try? fileManager.destinationOfSymbolicLink(atPath: resultPath.path)) == nil else {
            return nil
        }

        let fd = resultPath.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            return nil
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            return nil
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            return nil
        }
        guard fileStatus.st_nlink <= 1 else {
            close(fd)
            return nil
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxResultBytes) else {
            close(fd)
            return nil
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              data.count <= maxResultBytes else {
            return nil
        }
        return data
    }

    private static func hasReadableResultFile(
        _ url: URL,
        fileManager: FileManager
    ) -> Bool {
        guard url.isFileURL,
              fileManager.isReadableFile(atPath: url.path),
              (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil else {
            return false
        }
        var fileStatus = stat()
        guard lstat(url.path, &fileStatus) == 0,
              (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_nlink <= 1,
              fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxResultBytes) else {
            return false
        }
        return true
    }

    private static func isReadableDirectory(
        _ url: URL,
        fileManager: FileManager
    ) -> Bool {
        guard url.isFileURL,
              (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil else {
            return false
        }

        guard let type = try? fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeDirectory
    }
}

// MARK: - FalsifierArtifactsHealthRow
//
// Phase 2 Terminal F surface row. Renders the live state of every T23B
// falsifier artifact produced by the `falsify_*` harness binaries:
//
//   artifacts/falsifiers/<falsifier_id>/result.json
//
// Per docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md §Terminal F step 6
// ("Wire to a Substrate Health row — Terminal D consumer"). Designed
// to be embedded inside Terminal D's unified SubstrateHealthPanel.
//
// WRV honesty per PR #57: chip strip flips orange/red → green ONLY
// when the artifact's `overall_pass=true` AND `fallback_tier=Primary`.
// `fallback_tier=Fallback` renders amber + the scope caveat, NEVER
// green — the artifact is honest about what is (and is not) measured.
//
// Mirrors FUlpHealthRow / VaultRecallHealthRow shape (chip strip, refresh on
// appear, shared health-clock polling refresh).
//
// Source:
// - docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md (18 fields)
// - docs/audits/FALSIFIER_M2PRO_5_PASS_2026_05_23.md
// - agent_core/src/bin/falsify_*.rs (5 harness binaries)
// - agent_core/src/falsifier_artifacts/mod.rs (shared writer)

@MainActor
public struct FalsifierArtifactsHealthRow: View {

    @State private var snapshots: [FalsifierArtifactSnapshot] = []
    @State private var lastRefresh: Date? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            VerifiedFloorChipStrip(
                flag: "n/a",
                substrate: primaryPassCount > 0 ? "primary witness present" : "artifact reader",
                productionWired: primaryPassCount > 0,
                falsifierPassed: primaryPassCount > 0,
                falsifier: "docs/falsifiers/FALSIFIER_ARTIFACT_SCHEMA_2026_05_18.md",
                wiredToday: "Settings scans artifacts/falsifiers/*/result.json and distinguishes primary from fallback evidence.",
                stillStub: "Rows without primary_witness/overall_pass stay non-green."
            )
            if snapshots.isEmpty {
                emptyState
            } else {
                ForEach(snapshots) { snap in
                    artifactRow(snap)
                }
            }
        }
        .substrateHealthPoll { refresh() }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("T23B falsifier artifacts")
                    .font(.system(size: 13, weight: .medium))
                Text(headerDetail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            Text("No T23B artifacts under artifacts/falsifiers/* — run a falsify_* harness binary to produce one.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func artifactRow(_ snap: FalsifierArtifactSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: snap.statusSymbol)
                    .foregroundStyle(snap.statusTint)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text(snap.falsifierId)
                        .font(.system(size: 13, weight: .medium))
                    Text(snap.detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Spacer()
                Text(snap.tierBadge)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(snap.tierTint.opacity(0.18))
                    .foregroundStyle(snap.tierTint)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var headerDetail: String {
        let primary = primaryPassCount
        let fallback = snapshots.filter { $0.fallbackTier == "Fallback" && $0.overallPass }.count
        let failed = snapshots.filter { !$0.overallPass }.count
        let refreshed = lastRefresh.map { "\(Self.relative($0))" } ?? "—"
        return "\(primary) primary · \(fallback) fallback · \(failed) failed · refreshed \(refreshed)"
    }

    private var primaryPassCount: Int {
        snapshots.filter { $0.fallbackTier == "Primary" && $0.overallPass }.count
    }

    public func refresh() {
        snapshots = Self.loadArtifacts()
        lastRefresh = Date()
    }

    private static func loadArtifacts() -> [FalsifierArtifactSnapshot] {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        let root = URL(fileURLWithPath: cwd, isDirectory: true)
            .appendingPathComponent("artifacts", isDirectory: true)
            .appendingPathComponent("falsifiers", isDirectory: true)
        var out: [FalsifierArtifactSnapshot] = []
        for dir in FalsifierArtifactResultReader.artifactDirectories(in: root, fileManager: fm) {
            let resultPath = dir.appendingPathComponent("result.json")
            guard let json = FalsifierArtifactResultReader.jsonObject(at: resultPath, fileManager: fm) else {
                continue
            }
            let snap = FalsifierArtifactSnapshot(
                falsifierId: (json["falsifier_id"] as? String) ?? dir.lastPathComponent,
                overallPass: (json["overall_pass"] as? Bool) ?? false,
                fallbackTier: (json["artifact_kind"] as? String) == "primary_witness"
                    ? "Primary"
                    : ((json["fallback_tier"] as? String) ?? "Fallback"),
                notes: (json["notes"] as? String) ?? "",
                resultPath: resultPath.path,
                timestampUtc: (json["timestamp_utc"] as? String) ?? ""
            )
            out.append(snap)
        }
        return out.sorted { $0.falsifierId < $1.falsifierId }
    }

    private static func relative(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 1 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3_600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3_600))h ago"
    }
}

public struct FalsifierArtifactSnapshot: Identifiable {
    public var id: String { falsifierId }
    public let falsifierId: String
    public let overallPass: Bool
    public let fallbackTier: String
    public let notes: String
    public let resultPath: String
    public let timestampUtc: String

    public var statusSymbol: String {
        if overallPass {
            return fallbackTier == "Primary" ? "checkmark.circle.fill" : "checkmark.circle"
        }
        return "xmark.circle.fill"
    }

    public var statusTint: Color {
        if !overallPass {
            return .red
        }
        return fallbackTier == "Primary" ? .green : .orange
    }

    public var tierBadge: String { fallbackTier.uppercased() }

    public var tierTint: Color {
        switch fallbackTier {
        case "Primary": return .green
        case "Fallback": return .orange
        default: return .red
        }
    }

    public var detail: String {
        let prefix = overallPass ? "PASS" : "FAIL"
        let kindLabel = fallbackTier == "Primary" ? "primary_witness" : "fallback_witness"
        let noteSnip = notes.split(separator: ";").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        return "\(prefix) (\(kindLabel)) · \(noteSnip)"
    }
}
