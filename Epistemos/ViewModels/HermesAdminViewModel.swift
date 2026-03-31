import Foundation
import Observation

@MainActor @Observable
final class HermesAdminViewModel {
    // MARK: - Observable State

    var cronJobs: [CronJobEntry] = []
    var mcpServers: [MCPServerEntry] = []
    var toolsets: [ToolsetEntry] = []
    var configEntries: [ConfigEntry] = []
    var installedSkills: [HermesSkillEntry] = []
    var updateStatus: UpdateStatus?
    var diagnostics: DiagnosticsResult?
    var recentLogs: [String] = []
    var isLoading = false
    var lastError: String?

    // Marketplace state
    var availableSkills: [HubSkillEntry] = []
    var availableSkillsTotal = 0
    var featuredMCPServers: [FeaturedMCPServer] = []
    var featuredSkillNames: [String] = []
    var mcpRegistries: [MCPRegistry] = []

    var isSubprocessRunning: Bool { hermesManager.isRunning }

    // MARK: - Private

    private let hermesManager: HermesSubprocessManager

    init(hermesManager: HermesSubprocessManager) {
        self.hermesManager = hermesManager
    }

    // MARK: - Admin Result Handling

    func handleAdminResult(_ payload: [String: Any]) {
        let domain = payload["domain"] as? String ?? ""
        let action = payload["action"] as? String ?? ""

        if let error = payload["error"] as? String {
            lastError = "\(domain)/\(action): \(error)"
            isLoading = false
            return
        }

        switch (domain, action) {
        case ("cron", "list"):
            cronJobs = parseCronJobs(payload["data"])
        case ("cron", "create"), ("cron", "pause"), ("cron", "resume"), ("cron", "run"):
            refreshCronJobs()
        case ("cron", "remove"):
            refreshCronJobs()

        case ("mcp", "list"):
            mcpServers = parseMCPServers(payload["data"])
        case ("mcp", "add"), ("mcp", "remove"):
            refreshMCPServers()

        case ("tools", "list"):
            toolsets = parseToolsets(payload["data"])
        case ("tools", "toggle"):
            refreshToolsets()

        case ("config", "get"):
            configEntries = parseConfig(payload["data"])
        case ("config", "set"):
            refreshConfig()

        case ("skills", "list"):
            installedSkills = parseSkills(payload["data"])
        case ("skills", "install"), ("skills", "remove"), ("skills", "toggle"):
            refreshSkills()
            browseHub() // Refresh available list after install/remove

        case ("hub", "browse"):
            parseHubBrowse(payload["data"])
        case ("hub", "featured"):
            parseHubFeatured(payload["data"])

        case ("sessions", "list"), ("sessions", "search"):
            break // Sessions handled by AgentViewModel
        case ("sessions", "delete"):
            break

        case ("diagnostics", "doctor"):
            diagnostics = parseDiagnostics(payload["data"])
        case ("diagnostics", "logs"):
            recentLogs = (payload["data"] as? [String]) ?? []

        case ("update", "check"):
            updateStatus = parseUpdateStatus(payload["data"])

        default:
            break
        }

        isLoading = false
    }

    // MARK: - Admin Commands

    func refreshCronJobs() {
        sendAdmin(domain: "cron", action: "list")
    }

    func createCronJob(name: String, schedule: String, prompt: String) {
        sendAdmin(domain: "cron", action: "create", extra: [
            "name": name, "schedule": schedule, "prompt": prompt,
        ])
    }

    func pauseCronJob(id: String) {
        sendAdmin(domain: "cron", action: "pause", extra: ["job_id": id])
    }

    func resumeCronJob(id: String) {
        sendAdmin(domain: "cron", action: "resume", extra: ["job_id": id])
    }

    func runCronJob(id: String) {
        sendAdmin(domain: "cron", action: "run", extra: ["job_id": id])
    }

    func removeCronJob(id: String) {
        sendAdmin(domain: "cron", action: "remove", extra: ["job_id": id])
    }

    func refreshMCPServers() {
        sendAdmin(domain: "mcp", action: "list")
    }

    func addMCPServer(name: String, command: String? = nil, args: [String]? = nil, url: String? = nil) {
        var extra: [String: Any] = ["name": name]
        if let command { extra["command"] = command }
        if let args { extra["args"] = args }
        if let url { extra["url"] = url }
        sendAdmin(domain: "mcp", action: "add", extra: extra)
    }

    func removeMCPServer(name: String) {
        sendAdmin(domain: "mcp", action: "remove", extra: ["name": name])
    }

    func refreshToolsets() {
        sendAdmin(domain: "tools", action: "list")
    }

    func toggleToolset(name: String, enabled: Bool) {
        sendAdmin(domain: "tools", action: "toggle", extra: [
            "name": name, "enabled": enabled,
        ])
    }

    func refreshConfig() {
        sendAdmin(domain: "config", action: "get")
    }

    func setConfig(key: String, value: String) {
        sendAdmin(domain: "config", action: "set", extra: ["key": key, "value": value])
    }

    func refreshSkills() {
        sendAdmin(domain: "skills", action: "list")
    }

    func installSkill(name: String) {
        sendAdmin(domain: "skills", action: "install", extra: ["name": name])
    }

    func removeSkill(name: String) {
        sendAdmin(domain: "skills", action: "remove", extra: ["name": name])
    }

    func installSkillFromURL(url: String) {
        sendAdmin(domain: "skills", action: "install", extra: ["url": url])
    }

    func toggleSkill(name: String, enabled: Bool) {
        sendAdmin(domain: "skills", action: "toggle", extra: ["name": name, "enabled": enabled])
    }

    // MARK: - Marketplace Commands

    func browseHub(query: String = "") {
        var extra: [String: Any] = [:]
        if !query.isEmpty { extra["query"] = query }
        sendAdmin(domain: "hub", action: "browse", extra: extra)
    }

    func fetchFeatured() {
        sendAdmin(domain: "hub", action: "featured")
    }

    /// One-click install a curated MCP server from the featured catalog.
    func installFeaturedMCPServer(_ server: FeaturedMCPServer) {
        addMCPServer(
            name: server.name,
            command: server.command,
            args: server.args
        )
    }

    func checkForUpdates() {
        sendAdmin(domain: "update", action: "check")
    }

    func runDiagnostics() {
        sendAdmin(domain: "diagnostics", action: "doctor")
    }

    func fetchLogs(limit: Int = 100) {
        sendAdmin(domain: "diagnostics", action: "logs", extra: ["limit": limit])
    }

    func searchSessions(query: String) {
        sendAdmin(domain: "sessions", action: "search", extra: ["query": query])
    }

    func deleteSession(id: String) {
        sendAdmin(domain: "sessions", action: "delete", extra: ["session_id": id])
    }

    func refreshAll() {
        isLoading = true
        lastError = nil
        refreshCronJobs()
        refreshMCPServers()
        refreshToolsets()
        refreshConfig()
        refreshSkills()
        browseHub()
        fetchFeatured()
        checkForUpdates()
        runDiagnostics()
    }

    // MARK: - Private Helpers

    private func sendAdmin(domain: String, action: String, extra: [String: Any] = [:]) {
        var payload: [String: Any] = [
            "command": "admin",
            "domain": domain,
            "action": action,
        ]
        for (key, value) in extra {
            payload[key] = value
        }

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: data, encoding: .utf8) else {
            lastError = "Failed to encode admin command"
            return
        }

        do {
            try hermesManager.writeLine(line)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Parsing

    private func parseCronJobs(_ data: Any?) -> [CronJobEntry] {
        guard let jobs = data as? [[String: Any]] else { return [] }
        return jobs.compactMap { dict in
            guard let id = dict["id"] as? String else { return nil }
            return CronJobEntry(
                id: id,
                name: dict["name"] as? String ?? "Untitled",
                prompt: dict["prompt"] as? String ?? "",
                schedule: dict["schedule_display"] as? String ?? dict["schedule"] as? String ?? "",
                enabled: dict["enabled"] as? Bool ?? true,
                state: dict["state"] as? String ?? "scheduled",
                lastRunAt: dict["last_run_at"] as? String,
                nextRunAt: dict["next_run_at"] as? String
            )
        }
    }

    private func parseMCPServers(_ data: Any?) -> [MCPServerEntry] {
        guard let servers = data as? [String: [String: Any]] else { return [] }
        return servers.map { (name, config) in
            let transportType: String
            if config["url"] != nil {
                transportType = "HTTP"
            } else if config["command"] != nil {
                transportType = "stdio"
            } else {
                transportType = "unknown"
            }
            return MCPServerEntry(
                name: name,
                transportType: transportType,
                command: config["command"] as? String,
                url: config["url"] as? String,
                timeout: config["timeout"] as? Int
            )
        }.sorted { $0.name < $1.name }
    }

    private func parseToolsets(_ data: Any?) -> [ToolsetEntry] {
        guard let toolsets = data as? [String: [String: Any]] else { return [] }
        return toolsets.map { (name, config) in
            ToolsetEntry(
                name: name,
                enabled: config["enabled"] as? Bool ?? true
            )
        }.sorted { $0.name < $1.name }
    }

    private func parseConfig(_ data: Any?) -> [ConfigEntry] {
        guard let config = data as? [String: Any] else { return [] }
        return flattenConfig(config, prefix: "").sorted { $0.key < $1.key }
    }

    private func flattenConfig(_ dict: [String: Any], prefix: String) -> [ConfigEntry] {
        var entries: [ConfigEntry] = []
        for (key, value) in dict {
            let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? [String: Any] {
                entries.append(contentsOf: flattenConfig(nested, prefix: fullKey))
            } else {
                entries.append(ConfigEntry(key: fullKey, value: "\(value)"))
            }
        }
        return entries
    }

    private func parseSkills(_ data: Any?) -> [HermesSkillEntry] {
        guard let skills = data as? [[String: Any]] else { return [] }
        return skills.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            return HermesSkillEntry(
                name: name,
                path: dict["path"] as? String ?? "",
                description: dict["description"] as? String ?? "",
                version: dict["version"] as? String ?? "0.0.0",
                enabled: dict["enabled"] as? Bool ?? true,
                tags: dict["tags"] as? [String] ?? []
            )
        }
    }

    private func parseHubBrowse(_ data: Any?) {
        guard let dict = data as? [String: Any] else { return }
        availableSkillsTotal = dict["total"] as? Int ?? 0
        guard let skills = dict["skills"] as? [[String: Any]] else { return }
        availableSkills = skills.compactMap { s in
            guard let name = s["name"] as? String else { return nil }
            return HubSkillEntry(
                name: name,
                description: s["description"] as? String ?? "",
                version: s["version"] as? String ?? "",
                category: s["category"] as? String ?? "other",
                source: s["source"] as? String ?? "unknown",
                installed: s["installed"] as? Bool ?? false,
                tags: s["tags"] as? [String] ?? [],
                author: s["author"] as? String ?? ""
            )
        }
    }

    private func parseHubFeatured(_ data: Any?) {
        guard let dict = data as? [String: Any] else { return }

        featuredSkillNames = dict["featured_skills"] as? [String] ?? []

        if let servers = dict["mcp_servers"] as? [[String: Any]] {
            featuredMCPServers = servers.compactMap { s in
                guard let name = s["name"] as? String,
                      let command = s["command"] as? String else { return nil }
                return FeaturedMCPServer(
                    name: name,
                    displayName: s["display_name"] as? String ?? name,
                    description: s["description"] as? String ?? "",
                    command: command,
                    args: s["args"] as? [String] ?? [],
                    source: s["source"] as? String ?? "community",
                    category: s["category"] as? String ?? "other",
                    tags: s["tags"] as? [String] ?? [],
                    envHint: s["env_hint"] as? String
                )
            }
        }

        if let registries = dict["registries"] as? [[String: Any]] {
            mcpRegistries = registries.compactMap { r in
                guard let name = r["name"] as? String,
                      let url = r["url"] as? String else { return nil }
                return MCPRegistry(
                    name: name,
                    url: url,
                    description: r["description"] as? String ?? ""
                )
            }
        }
    }

    private func parseUpdateStatus(_ data: Any?) -> UpdateStatus? {
        guard let dict = data as? [String: Any] else { return nil }
        return UpdateStatus(
            updateAvailable: dict["update_available"] as? Bool ?? false,
            commitsBehind: dict["commits_behind"] as? Int ?? 0,
            hermesVersion: dict["hermes_version"] as? String ?? "unknown",
            error: dict["error"] as? String
        )
    }

    private func parseDiagnostics(_ data: Any?) -> DiagnosticsResult? {
        guard let dict = data as? [String: Any] else { return nil }
        let deps = (dict["dependencies"] as? [String: Bool]) ?? [:]
        return DiagnosticsResult(
            pythonVersion: dict["python_version"] as? String ?? "unknown",
            pythonPath: dict["python_path"] as? String ?? "unknown",
            hermesVersion: dict["hermes_version"] as? String ?? "unknown",
            hermesHome: dict["hermes_home"] as? String ?? "unknown",
            hermesHomeExists: dict["hermes_home_exists"] as? Bool ?? false,
            configExists: dict["config_exists"] as? Bool ?? false,
            skillsDirExists: dict["skills_dir_exists"] as? Bool ?? false,
            memoriesDirExists: dict["memories_dir_exists"] as? Bool ?? false,
            sessionsDirExists: dict["sessions_dir_exists"] as? Bool ?? false,
            cronDirExists: dict["cron_dir_exists"] as? Bool ?? false,
            dependencies: deps,
            gitRevision: dict["git_revision"] as? String ?? "unknown",
            diskFreeGB: dict["disk_free_gb"] as? Double,
            mcpServerCount: dict["mcp_server_count"] as? Int ?? 0,
            cronJobCount: dict["cron_job_count"] as? Int ?? 0,
            skillCount: dict["skill_count"] as? Int ?? 0
        )
    }
}

// MARK: - Data Types

struct CronJobEntry: Identifiable, Sendable {
    let id: String
    let name: String
    let prompt: String
    let schedule: String
    let enabled: Bool
    let state: String
    let lastRunAt: String?
    let nextRunAt: String?
}

struct MCPServerEntry: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let transportType: String
    let command: String?
    let url: String?
    let timeout: Int?
}

struct ToolsetEntry: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let enabled: Bool
}

struct ConfigEntry: Identifiable, Sendable {
    var id: String { key }
    let key: String
    let value: String
}

struct HermesSkillEntry: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let path: String
    let description: String
    let version: String
    let enabled: Bool
    let tags: [String]
}

// MARK: - Marketplace Types

struct HubSkillEntry: Identifiable, Sendable {
    var id: String { "\(source):\(name)" }
    let name: String
    let description: String
    let version: String
    let category: String
    let source: String
    let installed: Bool
    let tags: [String]
    let author: String

    var sourceLabel: String {
        switch source {
        case "bundled": "Built-in"
        case "optional": "Official"
        case "user": "Custom"
        default: source.capitalized
        }
    }
}

struct FeaturedMCPServer: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String
    let description: String
    let command: String
    let args: [String]
    let source: String
    let category: String
    let tags: [String]
    let envHint: String?

    var isOfficial: Bool { source == "official" }
}

struct MCPRegistry: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let url: String
    let description: String
}

struct DiagnosticsResult: Sendable {
    let pythonVersion: String
    let pythonPath: String
    let hermesVersion: String
    let hermesHome: String
    let hermesHomeExists: Bool
    let configExists: Bool
    let skillsDirExists: Bool
    let memoriesDirExists: Bool
    let sessionsDirExists: Bool
    let cronDirExists: Bool
    let dependencies: [String: Bool]
    let gitRevision: String
    let diskFreeGB: Double?
    let mcpServerCount: Int
    let cronJobCount: Int
    let skillCount: Int
}

struct UpdateStatus: Sendable {
    let updateAvailable: Bool
    let commitsBehind: Int
    let hermesVersion: String
    let error: String?
}
