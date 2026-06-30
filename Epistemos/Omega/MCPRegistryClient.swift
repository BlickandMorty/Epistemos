import Foundation

nonisolated enum MCPRegistrySource: String, CaseIterable, Codable, Sendable {
    case smithery = "Smithery"
    case mcpSO = "mcp.so"
    case glama = "Glama"
    case github = "GitHub"
}

nonisolated enum MCPRegistryInstallKind: String, Codable, Sendable {
    case remoteURL
    case stdioCommand
    case skillRepo

    var displayName: String {
        switch self {
        case .remoteURL: "Remote URL"
        case .stdioCommand: "Stdio"
        case .skillRepo: "Skill Repo"
        }
    }
}

nonisolated struct MCPRegistryEntry: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let source: MCPRegistrySource
    let installKind: MCPRegistryInstallKind
    let installTarget: String
    let homepage: String?

    var isMASInstallable: Bool {
        installKind == .remoteURL
    }
}

nonisolated struct MCPRegistryClient: Sendable {
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    static let maxRegistryFieldLength = 2_048

    private static let maxSearchQueryLength = 128
    private static let maxSearchAllResults = 64
    private static let maxRegistryResponseBytes = 2 * 1024 * 1024
    private static let maxRecordsPerSource = 32
    private static let maxRegistryLookupDepth = 4

    private let fetch: Fetch

    init(fetch: @escaping Fetch = { request in
        try await URLSession.shared.data(for: request)
    }) {
        self.fetch = fetch
    }

    func searchAll(query: String, limit: Int = 24) async -> [MCPRegistryEntry] {
        guard let normalizedQuery = Self.normalizedQuery(query) else { return [] }
        guard let boundedLimit = Self.normalizedLimit(limit) else { return [] }

        let sources: [@Sendable () async -> [MCPRegistryEntry]] = [
            { await self.searchSmithery(query: normalizedQuery) },
            { await self.searchMCPSO(query: normalizedQuery) },
            { await self.searchGlama(query: normalizedQuery) },
            { await self.searchGitHub(query: normalizedQuery) },
        ]

        var entries: [MCPRegistryEntry] = []
        await withTaskGroup(of: [MCPRegistryEntry].self) { group in
            for source in sources {
                group.addTask(operation: source)
            }
            for await result in group {
                entries.append(contentsOf: result)
            }
        }

        return Array(Self.deduped(entries).prefix(boundedLimit))
    }

    func searchGitHub(query: String) async -> [MCPRegistryEntry] {
        guard let query = Self.normalizedQuery(query) else { return [] }
        guard var components = URLComponents(string: "https://api.github.com/search/repositories") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(query) mcp server"),
            URLQueryItem(name: "per_page", value: "8"),
        ]
        guard let url = components.url,
              let root = try? await requestJSON(url) else {
            return []
        }
        let records = Self.collection(in: root).prefix(Self.maxRecordsPerSource)
        return records.compactMap { record in
            guard let name = Self.string(record, keys: ["full_name", "name"]),
                  let homepage = Self.githubURL(Self.string(record, keys: ["html_url"])) else {
                return nil
            }
            return MCPRegistryEntry(
                id: "github:\(name.lowercased())",
                name: name,
                description: Self.string(record, keys: ["description"]) ?? "",
                source: .github,
                installKind: .skillRepo,
                installTarget: homepage,
                homepage: homepage
            )
        }
    }

    func searchSmithery(query: String) async -> [MCPRegistryEntry] {
        await searchRegistry(
            source: .smithery,
            urlString: "https://smithery.ai/api/servers",
            queryName: "q",
            query: query
        )
    }

    func searchMCPSO(query: String) async -> [MCPRegistryEntry] {
        await searchRegistry(
            source: .mcpSO,
            urlString: "https://mcp.so/api/servers",
            queryName: "search",
            query: query
        )
    }

    func searchGlama(query: String) async -> [MCPRegistryEntry] {
        await searchRegistry(
            source: .glama,
            urlString: "https://glama.ai/api/mcp/v1/servers",
            queryName: "query",
            query: query
        )
    }

    private func searchRegistry(
        source: MCPRegistrySource,
        urlString: String,
        queryName: String,
        query: String
    ) async -> [MCPRegistryEntry] {
        guard let query = Self.normalizedQuery(query) else { return [] }
        guard var components = URLComponents(string: urlString) else { return [] }
        components.queryItems = [URLQueryItem(name: queryName, value: query)]
        guard let url = components.url,
              let root = try? await requestJSON(url) else {
            return []
        }
        return Self.collection(in: root)
            .prefix(Self.maxRecordsPerSource)
            .compactMap { Self.registryEntry(from: $0, source: source) }
    }

    private func requestJSON(_ url: URL) async throws -> Any {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Epistemos/Plan3-MCPRegistry", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = http.url,
              Self.isAllowedRegistryResponseURL(finalURL, requestURL: url) else {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else { return [] }
        guard data.count <= Self.maxRegistryResponseBytes else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func isAllowedRegistryResponseURL(_ responseURL: URL, requestURL: URL) -> Bool {
        guard let response = URLComponents(url: responseURL, resolvingAgainstBaseURL: false),
              let request = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              response.scheme?.lowercased() == "https",
              response.host?.lowercased() == request.host?.lowercased(),
              response.percentEncodedPath == request.percentEncodedPath,
              response.user == nil,
              response.password == nil,
              response.percentEncodedFragment == nil else {
            return false
        }
        return true
    }

    private static func registryEntry(
        from record: [String: Any],
        source: MCPRegistrySource
    ) -> MCPRegistryEntry? {
        guard let name = string(record, keys: [
            "name", "displayName", "display_name", "title", "slug", "id",
        ]) else {
            return nil
        }

        let description = string(record, keys: [
            "description", "summary", "shortDescription", "short_description",
        ]) ?? ""
        let homepage = string(record, keys: [
            "homepage", "homepageUrl", "homepage_url", "htmlUrl", "html_url", "url",
        ])

        if let target = string(record, keys: [
            "remoteUrl", "remote_url", "mcpUrl", "mcp_url", "serverUrl", "server_url",
            "sseUrl", "sse_url", "endpoint", "connectionUrl", "connection_url",
        ]).flatMap(remoteURLTarget) {
            return MCPRegistryEntry(
                id: "\(source.rawValue.lowercased()):remote:\(name.lowercased())",
                name: name,
                description: description,
                source: source,
                installKind: .remoteURL,
                installTarget: target,
                homepage: homepage
            )
        }

        if let repo = githubURL(string(record, keys: [
            "repository", "repositoryUrl", "repository_url", "githubUrl", "github_url",
            "repo", "sourceUrl", "source_url",
        ]) ?? homepage) {
            return MCPRegistryEntry(
                id: "\(source.rawValue.lowercased()):repo:\(repo.lowercased())",
                name: name,
                description: description,
                source: source,
                installKind: .skillRepo,
                installTarget: repo,
                homepage: homepage ?? repo
            )
        }

        if let command = string(record, keys: [
            "command", "stdioCommand", "stdio_command", "installCommand",
            "install_command", "package", "npmPackage", "npm_package",
        ]) {
            return MCPRegistryEntry(
                id: "\(source.rawValue.lowercased()):stdio:\(name.lowercased())",
                name: name,
                description: description,
                source: source,
                installKind: .stdioCommand,
                installTarget: command,
                homepage: homepage
            )
        }

        return nil
    }

    private static func normalizedQuery(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxSearchQueryLength))
    }

    private static func normalizedLimit(_ limit: Int) -> Int? {
        guard limit > 0 else { return nil }
        return min(limit, maxSearchAllResults)
    }

    private static func remoteURLTarget(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.percentEncodedQuery == nil,
              components.percentEncodedFragment == nil else {
            return nil
        }
        return trimmed
    }

    private static func collection(in root: Any) -> [[String: Any]] {
        collection(in: root, depth: 0)
    }

    private static func collection(in root: Any, depth: Int) -> [[String: Any]] {
        if let array = root as? [[String: Any]] {
            return array
        }
        guard let dictionary = root as? [String: Any] else { return [] }
        for key in ["items", "servers", "results", "data", "packages"] {
            if let array = dictionary[key] as? [[String: Any]] {
                return array
            }
            if depth < maxRegistryLookupDepth,
               let nested = dictionary[key] as? [String: Any] {
                let nestedCollection = collection(in: nested, depth: depth + 1)
                if !nestedCollection.isEmpty {
                    return nestedCollection
                }
            }
        }
        return []
    }

    private static func string(_ record: [String: Any], keys: [String]) -> String? {
        string(record, keys: keys, depth: 0)
    }

    private static func string(_ record: [String: Any], keys: [String], depth: Int) -> String? {
        for key in keys {
            if let value = record[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return String(trimmed.prefix(maxRegistryFieldLength))
                }
            }
            if depth < maxRegistryLookupDepth,
               let nested = record[key] as? [String: Any],
               let nestedValue = string(nested, keys: keys, depth: depth + 1) {
                return nestedValue
            }
        }
        return nil
    }

    private static func githubURL(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == "github.com",
              components.user == nil,
              components.password == nil,
              components.percentEncodedQuery == nil,
              components.percentEncodedFragment == nil,
              components.path.split(separator: "/").count >= 2 else {
            return nil
        }
        return trimmed
    }

    private static func deduped(_ entries: [MCPRegistryEntry]) -> [MCPRegistryEntry] {
        var seen: Set<String> = []
        var result: [MCPRegistryEntry] = []
        for entry in entries where seen.insert(entry.id).inserted {
            result.append(entry)
        }
        return result.sorted { left, right in
            if left.source.rawValue == right.source.rawValue {
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
            return left.source.rawValue < right.source.rawValue
        }
    }
}
