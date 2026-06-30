import Foundation

@main
enum VaultMCPSmoke {
    enum SmokeError: Error {
        case serverDidNotStart
        case badURL
        case badResponse
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("vault-MCP smoke failed: \(message)\n".utf8))
        exit(1)
    }

    static func main() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-mcp-smoke-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try "# Smoke Note\n\nVault MCP live read.".write(
                to: root.appendingPathComponent("Smoke #1.md"),
                atomically: true,
                encoding: .utf8
            )
            try "not a note resource".write(
                to: root.appendingPathComponent("secret.txt"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            fail("could not create temporary vault: \(error)")
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let token = "secret-token-abcdefghijklmnopqrstuvwxyz"
        let server = VaultMCPServer(
            vaultRoot: root,
            executor: { name, argumentsJSON in
                LocalToolResult(
                    toolName: name,
                    resultJson: #"{"tool":"\#(name)","arguments":\#(argumentsJSON)}"#,
                    isError: false
                )
            },
            token: token,
            resourceDispatcher: SmokeRustResourceDispatcher(vaultRoot: root)
        )
        defer { server.stop() }

        let registration: WorkNativeMCPRegistration
        do {
            registration = try await startAndAwait(server)
        } catch {
            fail("server did not start: \(error)")
        }

        do {
            let (toolsData, toolsResponse) = try await post(
                #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#,
                to: registration
            )
            guard toolsResponse.statusCode == 200 else {
                fail("authorized tools/list returned \(toolsResponse.statusCode)")
            }
            let toolsObject = try jsonObject(toolsData)
            let result = toolsObject["result"] as? [String: Any]
            let tools = result?["tools"] as? [[String: Any]] ?? []
            let names = Set(tools.compactMap { $0["name"] as? String })
            guard names == Set(VaultMCPCore.readToolNames), !names.contains("vault.write") else {
                fail("tools/list did not expose exactly the read-only surface: \(names)")
            }

            let (_, badAuth) = try await post(
                #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#,
                to: registration,
                bearer: "wrong-token"
            )
            guard badAuth.statusCode == 401 else {
                fail("bad bearer was not rejected: \(badAuth.statusCode)")
            }

            let (resourcesData, resourcesResponse) = try await post(
                #"{"jsonrpc":"2.0","id":4,"method":"resources/list"}"#,
                to: registration
            )
            guard resourcesResponse.statusCode == 200 else {
                fail("resources/list returned \(resourcesResponse.statusCode)")
            }
            let resourcesObject = try jsonObject(resourcesData)
            let resourcesResult = resourcesObject["result"] as? [String: Any]
            let resources = resourcesResult?["resources"] as? [[String: Any]] ?? []
            let resourceURIs = Set(resources.compactMap { $0["uri"] as? String })
            let readURI = "vault:///Smoke%20%231.md"
            guard resourceURIs.contains(readURI) else {
                fail("Rust resource dispatcher did not expose encoded vault URI: \(resourceURIs)")
            }

            let (readData, readResponse) = try await post(
                #"{"jsonrpc":"2.0","id":5,"method":"resources/read","params":{"uri":"\#(readURI)"}}"#,
                to: registration
            )
            guard readResponse.statusCode == 200 else {
                fail("resources/read returned \(readResponse.statusCode)")
            }
            let readObject = try jsonObject(readData)
            let readResult = readObject["result"] as? [String: Any]
            let contents = readResult?["contents"] as? [[String: Any]] ?? []
            let text = contents.first?["text"] as? String ?? ""
            guard text.contains("Vault MCP live read.") else {
                fail("resources/read did not return note text")
            }

            let (nonMarkdownData, nonMarkdownResponse) = try await post(
                #"{"jsonrpc":"2.0","id":6,"method":"resources/read","params":{"uri":"vault:///secret.txt"}}"#,
                to: registration
            )
            guard nonMarkdownResponse.statusCode == 200 else {
                fail("non-markdown resources/read returned HTTP \(nonMarkdownResponse.statusCode)")
            }
            let nonMarkdownObject = try jsonObject(nonMarkdownData)
            let nonMarkdownError = nonMarkdownObject["error"] as? [String: Any]
            let nonMarkdownMessage = nonMarkdownError?["message"] as? String ?? ""
            guard nonMarkdownMessage.contains("only markdown vault resources can be read") else {
                fail("non-markdown resource was not rejected by Rust dispatcher: \(nonMarkdownObject)")
            }
        } catch {
            fail("HTTP proof failed: \(error)")
        }

        print("vault-MCP smoke OK: loopback=\(registration.url) auth=true readonly=true rust_resource_dispatch=true resource_read=true non_markdown_reject=true")
    }

    private static func startAndAwait(_ server: VaultMCPServer) async throws -> WorkNativeMCPRegistration {
        try server.start()
        for _ in 0..<100 {
            if case .running(let registration) = server.status {
                return registration
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw SmokeError.serverDidNotStart
    }

    private static func post(
        _ json: String,
        to registration: WorkNativeMCPRegistration,
        bearer: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: registration.url) else {
            throw SmokeError.badURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer ?? registration.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data(json.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SmokeError.badResponse
        }
        return (data, http)
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SmokeError.badResponse
        }
        return object
    }
}

private final class SmokeRustResourceDispatcher: VaultMCPResourceDispatcher, @unchecked Sendable {
    private let dispatcher: McpDispatcher

    init(vaultRoot: URL) {
        dispatcher = McpDispatcher(logDbPath: ":memory:")
        dispatcher.setVaultRoot(root: vaultRoot.standardizedFileURL.resolvingSymlinksInPath().path)
    }

    nonisolated func dispatch(requestJson: String) -> String {
        dispatcher.dispatch(requestJson: requestJson)
    }
}
