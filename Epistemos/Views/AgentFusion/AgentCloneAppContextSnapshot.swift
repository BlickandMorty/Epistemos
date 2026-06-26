import Foundation

/// App-owned context for the embedded Act agent shell.
///
/// Keep this plain data. It is the safe growth path for future note/graph/mini
/// context after those surfaces leave isolation; the clone runtime still
/// receives only the bounded bridge context it already understands.
struct AgentCloneAppContextSnapshot: Codable, Equatable, Sendable {
    var appName: String
    var workspacePath: String?
    var vaultPath: String?
    var appSupportPath: String?
    var modeLabel: String
    var presentation: String
    var portalContext: AgentPortalContextSnapshot

    static func defaultAppSupportPath(appName: String) -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent(normalized(appName) ?? "Epistemos", isDirectory: true)
            .appendingPathComponent("AgentClone", isDirectory: true)
            .path
    }

    init(
        appName: String,
        workspacePath: String?,
        vaultPath: String?,
        appSupportPath: String?,
        modeLabel: String,
        presentation: String = "main",
        portalContext: AgentPortalContextSnapshot? = nil
    ) {
        self.appName = Self.normalized(appName) ?? "Epistemos"
        self.workspacePath = Self.normalized(workspacePath)
        self.vaultPath = Self.normalized(vaultPath)
        self.appSupportPath = Self.normalized(appSupportPath)
        self.modeLabel = Self.normalized(modeLabel) ?? "Act"
        self.presentation = Self.normalized(presentation) ?? "main"
        self.portalContext = portalContext ?? .main(
            vaultRootPath: self.vaultPath,
            workspacePath: self.workspacePath
        )
    }

    var modelVisibleSummary: String {
        var parts = [appName, modeLabel, "surface: \(presentation)"]
        parts.append(portalContext.modelVisibleSummary)
        if let vaultPath {
            parts.append("vault: \(vaultPath)")
        }
        if let workspacePath {
            parts.append("workspace: \(workspacePath)")
        }
        return parts.joined(separator: " | ")
    }

    var bridgePresentation: String {
        "\(presentation) | \(portalContext.bridgePresentation)"
    }

    var modelVisibleJSON: String {
        let payload = ModelVisiblePayload(
            appName: appName,
            modeLabel: modeLabel,
            presentation: presentation,
            portalContext: portalContext,
            workspacePath: workspacePath,
            vaultPath: vaultPath
        )
        return Self.encodedJSONString(payload)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func encodedJSONString<Value: Encodable>(_ value: Value) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    private struct ModelVisiblePayload: Codable, Equatable, Sendable {
        var appName: String
        var modeLabel: String
        var presentation: String
        var portalContext: AgentPortalContextSnapshot
        var workspacePath: String?
        var vaultPath: String?
    }
}
