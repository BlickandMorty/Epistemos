import Foundation

// Work-owned context seam for the native OpenGUI surface.
//
// This intentionally stores only plain values. The app-wide graph/chat/note surfaces can populate richer fields after
// the current deletion/refactor isolation lifts, but Work should not import those UI/state types directly.
struct WorkAppContextSnapshot: Codable, Equatable, Sendable {
    struct Row: Identifiable, Equatable, Sendable {
        let id: String
        let label: String
        let value: String
    }

    var workspacePath: String?
    var vaultPath: String?
    var managedSkillsCount: Int
    var nativeToolsAvailable: Bool
    var appMode: String?
    var selectedEngine: String?
    var selectedModelID: String?
    var selectedAgent: String?
    var activeWorkSessionID: String?
    var queuedPromptCount: Int
    var activeNoteTitle: String?
    var activeNotePath: String?
    var graphFocusSummary: String?
    var currentSelectionPreview: String?

    static let empty = WorkAppContextSnapshot()

    init(
        workspacePath: String? = nil,
        vaultPath: String? = nil,
        managedSkillsCount: Int = 0,
        nativeToolsAvailable: Bool = false,
        appMode: String? = nil,
        selectedEngine: String? = nil,
        selectedModelID: String? = nil,
        selectedAgent: String? = nil,
        activeWorkSessionID: String? = nil,
        queuedPromptCount: Int = 0,
        activeNoteTitle: String? = nil,
        activeNotePath: String? = nil,
        graphFocusSummary: String? = nil,
        currentSelectionPreview: String? = nil
    ) {
        self.workspacePath = Self.clean(workspacePath, limit: 1024)
        self.vaultPath = Self.clean(vaultPath, limit: 1024)
        self.managedSkillsCount = max(0, managedSkillsCount)
        self.nativeToolsAvailable = nativeToolsAvailable
        self.appMode = Self.clean(appMode, limit: 80)
        self.selectedEngine = Self.clean(selectedEngine, limit: 120)
        self.selectedModelID = Self.clean(selectedModelID, limit: 240)
        self.selectedAgent = Self.clean(selectedAgent, limit: 120)
        self.activeWorkSessionID = Self.clean(activeWorkSessionID, limit: 240)
        self.queuedPromptCount = max(0, queuedPromptCount)
        self.activeNoteTitle = Self.clean(activeNoteTitle, limit: 240)
        self.activeNotePath = Self.clean(activeNotePath, limit: 1024)
        self.graphFocusSummary = Self.clean(graphFocusSummary, limit: 600)
        self.currentSelectionPreview = Self.clean(currentSelectionPreview, limit: 600)
    }

    static func current(
        workspace: URL,
        vaultRoot: URL?,
        nativeToolsAvailable: Bool,
        selectedEngine: String? = nil,
        selectedModelID: String? = nil,
        selectedAgent: String? = nil,
        activeWorkSessionID: String? = nil,
        queuedPromptCount: Int = 0,
        fileManager: FileManager = .default
    ) -> WorkAppContextSnapshot {
        WorkAppContextSnapshot(
            workspacePath: workspace.standardizedFileURL.path,
            vaultPath: vaultRoot?.standardizedFileURL.path,
            managedSkillsCount: WorkSkillsProvisioner
                .provisionedSkills(workspace: workspace, fileManager: fileManager)
                .count,
            nativeToolsAvailable: nativeToolsAvailable,
            appMode: "work",
            selectedEngine: selectedEngine,
            selectedModelID: selectedModelID,
            selectedAgent: selectedAgent,
            activeWorkSessionID: activeWorkSessionID,
            queuedPromptCount: queuedPromptCount)
    }

    var isEmpty: Bool {
        workspacePath == nil
            && vaultPath == nil
            && managedSkillsCount == 0
            && !nativeToolsAvailable
            && appMode == nil
            && selectedEngine == nil
            && selectedModelID == nil
            && selectedAgent == nil
            && activeWorkSessionID == nil
            && queuedPromptCount == 0
            && activeNoteTitle == nil
            && activeNotePath == nil
            && graphFocusSummary == nil
            && currentSelectionPreview == nil
    }

    func rows(pathLimit: Int = 86, textLimit: Int = 120) -> [Row] {
        var rows: [Row] = []
        if let workspacePath {
            rows.append(Row(id: "workspace", label: "workspace", value: Self.compactPath(workspacePath, limit: pathLimit)))
        }
        if let vaultPath {
            rows.append(Row(id: "vault", label: "vault", value: Self.compactPath(vaultPath, limit: pathLimit)))
        }
        if let appMode {
            rows.append(Row(id: "mode", label: "mode", value: Self.compact(appMode, limit: textLimit)))
        }
        if let selectedEngine {
            rows.append(Row(id: "engine", label: "engine", value: Self.compact(selectedEngine, limit: textLimit)))
        }
        if let selectedModelID {
            rows.append(Row(id: "model", label: "model", value: Self.compact(selectedModelID, limit: textLimit)))
        }
        if let selectedAgent {
            rows.append(Row(id: "agent", label: "agent", value: Self.compact(selectedAgent, limit: textLimit)))
        }
        if let activeWorkSessionID {
            rows.append(Row(id: "session", label: "session", value: Self.compact(activeWorkSessionID, limit: textLimit)))
        }
        rows.append(Row(
            id: "native-tools",
            label: "native tools",
            value: nativeToolsAvailable ? "registered" : "not registered"))
        rows.append(Row(id: "skills", label: "skills", value: "\(managedSkillsCount)"))
        if queuedPromptCount > 0 {
            rows.append(Row(id: "queue", label: "queue", value: "\(queuedPromptCount)"))
        }
        if let activeNoteTitle {
            rows.append(Row(id: "note", label: "note", value: Self.compact(activeNoteTitle, limit: textLimit)))
        }
        if let activeNotePath {
            rows.append(Row(id: "note-path", label: "note path", value: Self.compactPath(activeNotePath, limit: pathLimit)))
        }
        if let graphFocusSummary {
            rows.append(Row(id: "graph", label: "graph", value: Self.compact(graphFocusSummary, limit: textLimit)))
        }
        if let currentSelectionPreview {
            rows.append(Row(id: "selection", label: "selection", value: Self.compact(currentSelectionPreview, limit: textLimit)))
        }
        return rows
    }

    func jsonString(pretty: Bool = false) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"available":false}"#
        }
        return string
    }

    private static func clean(_ value: String?, limit: Int) -> String? {
        let bounded = String((value ?? "").prefix(limit + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard limit > 3, trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 3)) + "..."
    }

    private static func compactPath(_ path: String, limit: Int) -> String {
        let value = (path as NSString).abbreviatingWithTildeInPath
        guard limit > 3, value.count > limit else { return value }
        let remaining = limit - 3
        let headCount = remaining / 2
        let tailCount = remaining - headCount
        return String(value.prefix(headCount)) + "..." + String(value.suffix(tailCount))
    }

    private static func compact(_ value: String, limit: Int) -> String {
        let bounded = String(value.prefix(limit + 32))
        guard limit > 3, bounded.count > limit else { return bounded }
        return String(bounded.prefix(limit - 3)) + "..."
    }
}

nonisolated final class WorkAppContextStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _snapshot: WorkAppContextSnapshot?

    var snapshot: WorkAppContextSnapshot? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _snapshot
        }
        set {
            lock.lock()
            _snapshot = newValue
            lock.unlock()
        }
    }
}
