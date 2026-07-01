import Darwin
import Foundation

nonisolated protocol VaultMCPResourceDispatcher: AnyObject, Sendable {
    nonisolated func dispatch(requestJson: String) -> String
}

nonisolated struct VaultMCPCore {
    static let maxRequestJSONBytes = 8 * 1024 * 1024
    static let maxJSONRPCIDStringLength = 256
    static let maxProtocolDiagnosticCharacters = 256
    static let maxProtocolErrorMessageCharacters = 320
    static let maxRelativePathCharacters = 2_048
    static let maxResourceNotes = 5_000
    static let maxResourceReadBytes = 8 * 1024 * 1024

    static let readToolNames = [
        "vault.search",
        "vault.read",
        "vault.list",
        "eidos.query",
        "vault.backlinks",
        "vault.outlinks",
        "vault.dangling_links",
        "vault.note_links",
        "vault.link_candidates",
        "vault.orphan_notes",
    ]

    private static let readToolNameSet = Set(readToolNames)
    private static let pathRequiredReadToolNameSet = Set([
        "vault.read",
        "vault.outlinks",
        "vault.note_links",
        "vault.link_candidates",
    ])
    private static let pathOptionalReadToolNameSet = Set([
        "vault.backlinks",
    ])
    private static let folderPathOptionalReadToolNameSet = Set([
        "vault.list",
    ])

    private static let readAliasMap: [String: String] = [
        "file.search": "vault.search",
        "search_notes": "vault.search",
        "vault_search": "vault.search",
        "file.read": "vault.read",
        "read_file": "vault.read",
        "vault_read": "vault.read",
        "file.list": "vault.list",
        "list_files": "vault.list",
        "vault_list": "vault.list",
        "eidos_query": "eidos.query",
        "backlinks": "vault.backlinks",
        "vault_backlinks": "vault.backlinks",
        "outlinks": "vault.outlinks",
        "vault_outlinks": "vault.outlinks",
        "dangling_links": "vault.dangling_links",
        "unresolved_links": "vault.dangling_links",
        "note_links": "vault.note_links",
        "link_candidates": "vault.link_candidates",
        "unlinked_mentions": "vault.link_candidates",
        "orphan_notes": "vault.orphan_notes",
        "orphans": "vault.orphan_notes",
    ]

    let vaultRoot: URL?
    let executor: LocalAgentToolExecutor
    private let resourceDispatcher: (any VaultMCPResourceDispatcher)?

    init(
        vaultRoot: URL? = nil,
        executor: @escaping LocalAgentToolExecutor,
        resourceDispatcher: (any VaultMCPResourceDispatcher)? = nil
    ) {
        self.vaultRoot = vaultRoot
        self.executor = executor
        self.resourceDispatcher = resourceDispatcher
    }

    func handle(requestJSON: String) async -> String {
        guard requestJSON.utf8.count <= Self.maxRequestJSONBytes else {
            return Self.errorResponse(id: NSNull(), code: -32600, message: "JSON-RPC request is too large")
        }
        guard let data = requestJSON.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return Self.errorResponse(id: NSNull(), code: -32700, message: "Parse error")
        }

        guard let request = parsed as? [String: Any] else {
            return Self.errorResponse(id: NSNull(), code: -32600, message: "Invalid Request")
        }
        let id = Self.responseID(from: request["id"])
        guard request["jsonrpc"] as? String == "2.0" else {
            return Self.errorResponse(id: id, code: -32600, message: "Invalid Request")
        }
        guard let method = request["method"] as? String,
              !method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Self.errorResponse(id: id, code: -32600, message: "Invalid Request")
        }

        switch method {
        case "initialize":
            return Self.successResponse(id: id, result: Self.initializeResult())
        case "tools/list":
            return Self.successResponse(id: id, result: ["tools": Self.toolsList()])
        case "tools/call":
            return await handleToolsCall(id: id, request: request)
        case "resources/list":
            if let resourceDispatcher {
                return resourceDispatcher.dispatch(requestJson: Self.delegatedDispatchRequestJSON(from: request, id: id))
            }
            let relativePaths = await Task.detached(priority: .utility) {
                Self.markdownRelPaths(vaultRoot: vaultRoot)
            }.value
            return Self.successResponse(id: id, result: ["resources": Self.resourcesList(from: relativePaths)])
        case "resources/read":
            switch validatedResourceReadTarget(id: id, request: request) {
            case .failure(let response):
                return response
            case .success(let target):
                if let resourceDispatcher {
                    return resourceDispatcher.dispatch(
                        requestJson: Self.delegatedResourceReadRequestJSON(
                            from: request,
                            id: id,
                            target: target))
                }
                return await handleResourcesRead(id: id, target: target)
            }
        default:
            return Self.errorResponse(
                id: id,
                code: -32601,
                message: "Method not found: \(Self.protocolDiagnostic(method))"
            )
        }
    }

    private func handleToolsCall(id: Any, request: [String: Any]) async -> String {
        guard let params = request["params"] as? [String: Any],
              let rawName = params["name"] as? String,
              !rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Self.errorResponse(id: id, code: -32602, message: "tools/call requires params.name")
        }

        let canonicalName = Self.canonicalReadToolName(rawName)
        guard Self.readToolNameSet.contains(canonicalName) else {
            return Self.errorResponse(
                id: id,
                code: -32601,
                message: "read-only vault server: \(Self.protocolDiagnostic(rawName))"
            )
        }

        switch validatedArgumentsJSON(for: canonicalName, rawArguments: params["arguments"]) {
        case .failure(let message):
            return Self.errorResponse(id: id, code: -32602, message: message)
        case .success(let argumentsJSON):
            let result = await executor(canonicalName, argumentsJSON)
            return Self.successResponse(id: id, result: Self.toolCallResult(from: result))
        }
    }

    private func validatedArgumentsJSON(for toolName: String, rawArguments: Any?) -> ToolArgumentsValidationResult {
        if Self.folderPathOptionalReadToolNameSet.contains(toolName) {
            return validatedFolderPathArgumentsJSON(rawArguments)
        }

        let requiresPath = Self.pathRequiredReadToolNameSet.contains(toolName)
        let acceptsOptionalPath = Self.pathOptionalReadToolNameSet.contains(toolName)
        guard requiresPath || acceptsOptionalPath else {
            return .success(Self.argumentsJSON(from: rawArguments))
        }

        guard let arguments = Self.argumentsObject(from: rawArguments) else {
            return .failure("\(toolName) requires JSON object arguments")
        }
        guard let rawPath = arguments["path"] as? String else {
            return requiresPath
                ? .failure("\(toolName) requires arguments.path")
                : .success(Self.argumentsJSON(from: rawArguments))
        }
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return requiresPath
                ? .failure("\(toolName) requires arguments.path")
                : .success(Self.argumentsJSON(from: rawArguments))
        }

        do {
            _ = try Self.containedMarkdownURL(vaultRoot: vaultRoot, relativePath: path)
        } catch {
            return .failure(Self.errorMessage(for: error))
        }
        return .success(Self.argumentsJSON(from: rawArguments))
    }

    private func validatedFolderPathArgumentsJSON(_ rawArguments: Any?) -> ToolArgumentsValidationResult {
        guard let arguments = Self.argumentsObject(from: rawArguments) else {
            return .success(Self.argumentsJSON(from: rawArguments))
        }

        for key in ["path", "path_prefix", "prefix"] {
            guard let rawPath = arguments[key] as? String else { continue }
            let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { continue }
            do {
                _ = try Self.containedVaultURL(
                    vaultRoot: vaultRoot,
                    relativePath: path,
                    allowCurrentDirectory: true)
            } catch {
                return .failure(Self.errorMessage(for: error))
            }
        }
        return .success(Self.argumentsJSON(from: rawArguments))
    }

    private static func argumentsObject(from arguments: Any?) -> [String: Any]? {
        if let object = arguments as? [String: Any] { return object }
        if let string = arguments as? String,
           let data = string.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        return nil
    }

    private func validatedResourceReadTarget(id: Any, request: [String: Any]) -> ResourceReadTargetValidationResult {
        guard let params = request["params"] as? [String: Any] else {
            return .failure(Self.errorResponse(id: id, code: -32602, message: "resources/read requires params"))
        }
        guard let uri = params["uri"] as? String, !uri.isEmpty else {
            return .failure(Self.errorResponse(id: id, code: -32602, message: "params.uri is required"))
        }
        guard let relativePath = Self.relativePath(fromVaultURI: uri) else {
            return .failure(Self.errorResponse(id: id, code: -32602, message: "resources/read requires vault:/// URI"))
        }
        do {
            _ = try Self.containedMarkdownURL(vaultRoot: vaultRoot, relativePath: relativePath)
        } catch {
            return .failure(Self.errorResponse(id: id, code: -32602, message: Self.errorMessage(for: error)))
        }
        return .success(ResourceReadTarget(uri: Self.vaultURI(for: relativePath), relativePath: relativePath))
    }

    private func handleResourcesRead(id: Any, target: ResourceReadTarget) async -> String {
        let readResult = await Task.detached(priority: .utility) {
            do {
                return ResourceReadResult.success(try Self.noteText(vaultRoot: vaultRoot, relativePath: target.relativePath))
            } catch {
                return ResourceReadResult.failure(Self.errorMessage(for: error))
            }
        }.value

        switch readResult {
        case .success(let text):
            return Self.successResponse(
                id: id,
                result: [
                    "contents": [[
                        "uri": target.uri,
                        "mimeType": "text/markdown",
                        "text": text,
                    ]],
                ])
        case .failure(let message):
            return Self.errorResponse(id: id, code: -32602, message: message)
        }
    }

    // MARK: Pure shaping helpers

    static func initializeResult() -> [String: Any] {
        [
            "protocolVersion": "2024-11-05",
            "serverInfo": ["name": "epistemos-vault-readonly", "version": "0.1.0"],
            "capabilities": ["tools": [String: Any](), "resources": [String: Any]()],
        ]
    }

    static func toolsList() -> [[String: Any]] {
        readToolNames.map { name in
            [
                "name": name,
                "description": toolDescription(for: name),
                "inputSchema": inputSchema(for: name),
            ]
        }
    }

    static func canonicalReadToolName(_ toolName: String) -> String {
        let trimmed = boundedProtocolInput(toolName).lowercased()
        let canonical = AgentToolNameAliases.canonical(trimmed)
        return readAliasMap[canonical] ?? readAliasMap[trimmed] ?? canonical
    }

    static func resourcesList(vaultRoot: URL?) -> [[String: Any]] {
        resourcesList(from: markdownRelPaths(vaultRoot: vaultRoot))
    }

    private static func resourcesList(from relativePaths: [String]) -> [[String: Any]] {
        relativePaths.map { relativePath in
            [
                "uri": vaultURI(for: relativePath),
                "name": relativePath,
                "mimeType": "text/markdown",
            ]
        }
    }

    static func markdownRelPaths(vaultRoot: URL?, limit: Int = Self.maxResourceNotes) -> [String] {
        guard let vaultRoot else { return [] }
        let limit = max(0, limit)
        guard limit > 0 else { return [] }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: vaultRoot.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return []
        }

        let root = vaultRoot.standardizedFileURL
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var paths: [String] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "md" else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true,
                  let relativePath = relativePath(for: url, under: root),
                  (try? containedMarkdownURL(vaultRoot: root, relativePath: relativePath)) != nil else {
                continue
            }
            paths.append(relativePath)
            if paths.count >= limit { break }
        }
        return paths.sorted()
    }

    static func noteText(vaultRoot: URL?, relativePath: String) throws -> String {
        let url = try containedMarkdownURL(vaultRoot: vaultRoot, relativePath: relativePath)
        return try readMarkdownFile(at: url)
    }

    private static func readMarkdownFile(at url: URL) throws -> String {
        let fd = url.path.withCString { path in
            open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            throw VaultMCPPathError.notRegularFile
        }

        var fileStatus = stat()
        guard fstat(fd, &fileStatus) == 0 else {
            close(fd)
            throw VaultMCPPathError.notRegularFile
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            close(fd)
            throw VaultMCPPathError.notRegularFile
        }
        guard fileStatus.st_size >= 0,
              UInt64(fileStatus.st_size) <= UInt64(maxResourceReadBytes) else {
            close(fd)
            throw VaultMCPPathError.tooLarge
        }

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.readToEnd() ?? Data()
        guard data.count <= maxResourceReadBytes else {
            throw VaultMCPPathError.tooLarge
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw VaultMCPPathError.invalidEncoding
        }
        return text
    }

    static func argumentsJSON(from arguments: Any?) -> String {
        guard let arguments else { return "{}" }
        if let string = arguments as? String { return string }
        if let data = try? JSONSerialization.data(withJSONObject: arguments),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }

    static func responseID(from rawID: Any?) -> Any {
        guard let rawID else { return NSNull() }
        if let string = rawID as? String {
            return String(string.prefix(maxJSONRPCIDStringLength))
        }
        if rawID is NSNull {
            return NSNull()
        }
        if let number = rawID as? NSNumber {
            return number
        }
        return NSNull()
    }

    static func delegatedDispatchRequestJSON(from request: [String: Any], id: Any) -> String {
        var boundedRequest = request
        boundedRequest["id"] = id
        return jsonRPC(boundedRequest)
    }

    static func delegatedResourceReadRequestJSON(
        from request: [String: Any],
        id: Any,
        target: ResourceReadTarget
    ) -> String {
        var boundedRequest = request
        boundedRequest["id"] = id
        boundedRequest["method"] = "resources/read"
        boundedRequest["params"] = ["uri": target.uri]
        return jsonRPC(boundedRequest)
    }

    static func toolCallResult(from result: LocalToolResult) -> [String: Any] {
        [
            "content": [["type": "text", "text": result.resultJson]],
            "isError": result.isError,
        ]
    }

    static func vaultURI(for relativePath: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "#?%")
        let encoded = relativePath.addingPercentEncoding(withAllowedCharacters: allowed) ?? relativePath
        return "vault:///\(encoded)"
    }

    static func successResponse(id: Any, result: [String: Any]) -> String {
        jsonRPC(["jsonrpc": "2.0", "id": id, "result": result])
    }

    static func errorResponse(id: Any, code: Int, message: String) -> String {
        jsonRPC([
            "jsonrpc": "2.0",
            "id": id,
            "error": ["code": code, "message": protocolErrorMessage(message)],
        ])
    }

    private static func inputSchema(for toolName: String) -> [String: Any] {
        switch toolName {
        case "vault.search":
            return [
                "type": "object",
                "properties": [
                    "query": ["type": "string"],
                    "limit": ["type": "integer", "minimum": 1],
                ],
                "required": ["query"],
                "additionalProperties": true,
            ]
        case "vault.read", "vault.outlinks", "vault.note_links", "vault.link_candidates":
            return pathSchema()
        case "vault.backlinks":
            return [
                "type": "object",
                "properties": [
                    "target": ["type": "string"],
                    "path": ["type": "string"],
                ],
                "additionalProperties": true,
            ]
        case "eidos.query":
            return [
                "type": "object",
                "properties": ["query": ["type": "string"]],
                "required": ["query"],
                "additionalProperties": true,
            ]
        default:
            return [
                "type": "object",
                "properties": [String: Any](),
                "additionalProperties": true,
            ]
        }
    }

    private static func pathSchema() -> [String: Any] {
        [
            "type": "object",
            "properties": ["path": ["type": "string"]],
            "required": ["path"],
            "additionalProperties": true,
        ]
    }

    private static func toolDescription(for toolName: String) -> String {
        switch toolName {
        case "vault.search": "Search markdown notes in the active Epistemos vault."
        case "vault.read": "Read a markdown note from the active Epistemos vault."
        case "vault.list": "List markdown notes in the active Epistemos vault."
        case "eidos.query": "Run a read-only semantic query over the local Epistemos knowledge layer."
        case "vault.backlinks": "List notes that link to a target note."
        case "vault.outlinks": "List notes linked from a target note."
        case "vault.dangling_links": "List unresolved wiki links in the vault."
        case "vault.note_links": "Return link context for one note."
        case "vault.link_candidates": "Suggest unlinked mentions for one note."
        case "vault.orphan_notes": "List notes with no graph connections."
        default: "Read-only vault tool."
        }
    }

    private static func relativePath(fromVaultURI uri: String) -> String? {
        guard uri.hasPrefix("vault:///") else { return nil }
        let rawPath = String(uri.dropFirst("vault:///".count))
        guard !rawPath.isEmpty else { return nil }
        guard !containsPercentEncodedPathSeparator(rawPath) else { return nil }
        return rawPath.removingPercentEncoding
    }

    private static func containsPercentEncodedPathSeparator(_ path: String) -> Bool {
        let lowercased = path.lowercased()
        return lowercased.contains("%2f") || lowercased.contains("%5c")
    }

    private static func containedMarkdownURL(vaultRoot: URL?, relativePath: String) throws -> URL {
        guard relativePath.replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .hasSuffix(".md") else {
            throw VaultMCPPathError.notMarkdown
        }
        let url = try containedVaultURL(
            vaultRoot: vaultRoot,
            relativePath: relativePath,
            allowCurrentDirectory: false)
        guard url.pathExtension.lowercased() == "md" else {
            throw VaultMCPPathError.notMarkdown
        }
        return url
    }

    private static func containedVaultURL(
        vaultRoot: URL?,
        relativePath: String,
        allowCurrentDirectory: Bool
    ) throws -> URL {
        guard let vaultRoot else { throw VaultMCPPathError.noVaultRoot }
        let normalizedPath = relativePath
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedPath.count <= maxRelativePathCharacters else {
            throw VaultMCPPathError.pathTooLong
        }
        guard !containsControlPathScalar(normalizedPath) else {
            throw VaultMCPPathError.invalidPathCharacters
        }
        if allowCurrentDirectory && normalizedPath == "." {
            return vaultRoot.standardizedFileURL.resolvingSymlinksInPath()
        }
        guard !normalizedPath.isEmpty,
              !normalizedPath.hasPrefix("/"),
              normalizedPath.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." }) else {
            throw VaultMCPPathError.pathTraversal
        }
        guard !hasHiddenPathComponent(normalizedPath) else {
            throw VaultMCPPathError.hiddenPath
        }

        let root = vaultRoot.standardizedFileURL.resolvingSymlinksInPath()
        try rejectExistingSymlinkComponents(root: root, relativePath: normalizedPath)
        let candidate = root
            .appendingPathComponent(normalizedPath, isDirectory: false)
            .standardizedFileURL
        let resolvedCandidate = resolvedURLForContainment(candidate)
        let rootPath = root.path
        let candidatePath = resolvedCandidate.path
        guard candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/") else {
            throw VaultMCPPathError.pathTraversal
        }
        if candidatePath != rootPath {
            let resolvedRelativePath = String(candidatePath.dropFirst(rootPath.count + 1))
            guard !hasHiddenPathComponent(resolvedRelativePath) else {
                throw VaultMCPPathError.hiddenPath
            }
        }
        return resolvedCandidate
    }

    private static func rejectExistingSymlinkComponents(root: URL, relativePath: String) throws {
        var current = root
        for component in relativePath.split(separator: "/") {
            current = current.appendingPathComponent(String(component), isDirectory: false)
            var fileStatus = stat()
            guard lstat(current.path, &fileStatus) == 0 else {
                if errno == ENOENT || errno == ENOTDIR {
                    return
                }
                throw VaultMCPPathError.notRegularFile
            }
            guard (fileStatus.st_mode & S_IFMT) != S_IFLNK else {
                throw VaultMCPPathError.symlinkPath
            }
        }
    }

    private static func resolvedURLForContainment(_ url: URL) -> URL {
        var existing = url.standardizedFileURL
        var missingPathComponents: [String] = []

        while !FileManager.default.fileExists(atPath: existing.path) {
            let parent = existing.deletingLastPathComponent()
            guard parent.path != existing.path else { break }
            missingPathComponents.insert(existing.lastPathComponent, at: 0)
            existing = parent
        }

        return missingPathComponents.reduce(existing.resolvingSymlinksInPath()) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }.standardizedFileURL
    }

    private static func hasHiddenPathComponent(_ relativePath: String) -> Bool {
        relativePath.split(separator: "/").contains { component in
            component.hasPrefix(".")
        }
    }

    private static func containsControlPathScalar(_ relativePath: String) -> Bool {
        relativePath.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    private static func relativePath(for url: URL, under root: URL) -> String? {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else { return nil }
        return String(filePath.dropFirst(rootPath.count + 1))
    }

    private static func errorMessage(for error: Error) -> String {
        switch error as? VaultMCPPathError {
        case .noVaultRoot:
            "no vault root configured"
        case .pathTraversal:
            "path traversal not allowed"
        case .notMarkdown:
            "only markdown vault resources can be read"
        case .notRegularFile:
            "only regular markdown vault resources can be read"
        case .pathTooLong:
            "vault resource path is too long"
        case .tooLarge:
            "markdown resource is too large"
        case .hiddenPath:
            "hidden vault resources cannot be read"
        case .symlinkPath:
            "symlinked vault resources cannot be read"
        case .invalidEncoding:
            "markdown resource is not valid UTF-8"
        case .invalidPathCharacters:
            "vault resource path contains control characters"
        case .none:
            "read failed"
        }
    }

    private static func protocolDiagnostic(_ value: String) -> String {
        let bounded = String(value.prefix(maxProtocolDiagnosticCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "[empty]" : trimmed
        guard fallback.count > maxProtocolDiagnosticCharacters else {
            return fallback
        }
        return String(fallback.prefix(maxProtocolDiagnosticCharacters - 3)) + "..."
    }

    private static func boundedProtocolInput(_ value: String) -> String {
        let bounded = String(value.prefix(maxProtocolDiagnosticCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxProtocolDiagnosticCharacters else {
            return trimmed
        }
        return String(trimmed.prefix(maxProtocolDiagnosticCharacters))
    }

    private static func protocolErrorMessage(_ value: String) -> String {
        let bounded = String(value.prefix(maxProtocolErrorMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = trimmed.isEmpty ? "request failed" : trimmed
        guard message.count > maxProtocolErrorMessageCharacters else {
            return message
        }
        return String(message.prefix(maxProtocolErrorMessageCharacters - 3)) + "..."
    }

    private static func jsonRPC(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"jsonrpc":"2.0","error":{"code":-32603,"message":"serialize failed"}}"#
        }
        return string
    }
}

private enum ResourceReadResult: Sendable {
    case success(String)
    case failure(String)
}

nonisolated struct ResourceReadTarget: Sendable {
    let uri: String
    let relativePath: String
}

private enum ResourceReadTargetValidationResult: Sendable {
    case success(ResourceReadTarget)
    case failure(String)
}

private enum ToolArgumentsValidationResult: Sendable {
    case success(String)
    case failure(String)
}

private enum VaultMCPPathError: Error, Sendable {
    case noVaultRoot
    case pathTraversal
    case notMarkdown
    case notRegularFile
    case pathTooLong
    case tooLarge
    case hiddenPath
    case symlinkPath
    case invalidEncoding
    case invalidPathCharacters
}
