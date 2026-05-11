import SwiftUI

// MARK: - CLIDiscoveryHealthRow
//
// RCA13 P8: Settings-side diagnostic that probes the user's machine
// for the 4 agent_core CLI passthrough binaries (claude, codex,
// gemini, kimi). Read-only — the row never executes the CLIs; it
// only checks whether candidate paths point at an existing,
// regular file with the executable bit set. Mirrors the candidate
// path order in `agent_core/src/tools/cli_passthrough.rs` so the
// row reports what the runtime would actually find when it tries
// to spawn a passthrough.
//
// Gated to the Pro build at the call site in SettingsView — the App
// Store build never shows this row because MAS sandbox blocks CLI
// passthrough entirely.

@MainActor
public struct CLIDiscoveryHealthRow: View {

    private struct Probe: Identifiable, Sendable {
        let id: String
        let displayName: String
        let candidates: [String]
        var resolvedPath: String?
        var present: Bool { resolvedPath != nil }
    }

    @State private var probes: [Probe] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(probes) { probe in
                row(probe: probe)
            }
        }
        .onAppear { refresh() }
    }

    /// Re-probe every CLI. Cheap — pure filesystem stats.
    public func refresh() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        probes = Self.canonicalProbes(homeDirectory: homeDirectory)
            .map { probe in
                var resolved = probe
                resolved.resolvedPath = Self.firstExecutable(in: probe.candidates)
                    ?? Self.searchPATH(for: probe.id)
                return resolved
            }
    }

    @ViewBuilder
    private func row(probe: Probe) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(probe.displayName)
                    .font(.system(size: 13, weight: .medium))
                Text(probe.resolvedPath ?? "Not installed")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: probe.present ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(
                    probe.present ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.secondary)
                )
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Probe definitions

    /// Mirrors the candidate-path order in
    /// `agent_core/src/tools/cli_passthrough.rs` so the row's "Not
    /// installed" answer agrees with what the runtime would report.
    private static func canonicalProbes(homeDirectory: String) -> [Probe] {
        [
            Probe(
                id: "claude",
                displayName: "Claude CLI",
                candidates: [
                    "\(homeDirectory)/.local/bin/claude",
                    "\(homeDirectory)/.claude/local/claude",
                    "\(homeDirectory)/.npm-global/bin/claude",
                    "/opt/homebrew/bin/claude",
                    "/usr/local/bin/claude",
                ]
            ),
            Probe(
                id: "codex",
                displayName: "Codex CLI",
                candidates: [
                    "\(homeDirectory)/.local/bin/codex",
                    "/Applications/Codex.app/Contents/Resources/codex",
                    "/opt/homebrew/bin/codex",
                    "/usr/local/bin/codex",
                ]
            ),
            Probe(
                id: "gemini",
                displayName: "Gemini CLI",
                candidates: [
                    "\(homeDirectory)/.local/bin/gemini",
                    "\(homeDirectory)/.npm-global/bin/gemini",
                    "\(homeDirectory)/node_modules/.bin/gemini",
                    "/opt/homebrew/bin/gemini",
                    "/usr/local/bin/gemini",
                ]
            ),
            Probe(
                id: "kimi",
                displayName: "Kimi CLI",
                candidates: [
                    "\(homeDirectory)/.local/bin/kimi",
                    "\(homeDirectory)/.npm-global/bin/kimi",
                    "/Applications/Kimi.app/Contents/Resources/kimi",
                    "/opt/homebrew/bin/kimi",
                    "/usr/local/bin/kimi",
                ]
            ),
        ]
    }

    /// First existing + executable file in the candidate list, or nil.
    /// Stats only — never spawns the binary.
    static func firstExecutable(in candidates: [String]) -> String? {
        let fileManager = FileManager.default
        for path in candidates {
            if fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Fallback: scan the user's PATH for the named binary. Returns
    /// the first matching executable file or nil.
    static func searchPATH(for name: String) -> String? {
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        guard !envPath.isEmpty else { return nil }
        let fileManager = FileManager.default
        for dir in envPath.split(separator: ":") {
            let candidate = "\(dir)/\(name)"
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

#if DEBUG
struct CLIDiscoveryHealthRow_Previews: PreviewProvider {
    static var previews: some View {
        CLIDiscoveryHealthRow()
            .padding()
            .frame(width: 420)
    }
}
#endif
