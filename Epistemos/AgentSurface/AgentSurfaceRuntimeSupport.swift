#if !EPISTEMOS_APP_STORE
import Darwin
import Foundation
import Security

/// Shared runtime plumbing for embedded agent surfaces.
enum AgentSurfaceRuntimeSupport {
    nonisolated static let loopbackHost = "127.0.0.1"
    /// Ports are allocated from the ephemeral range only: dynamic allocation
    /// avoids occupied fixed ports and stays above the WHATWG fetch bad-port blocklist.
    nonisolated static let ephemeralPortRange: ClosedRange<Int> = 49_300...64_900
    nonisolated static let portAllocationAttempts = 48
    nonisolated static let maxSubprocessEnvironmentValueCharacters =
        AgentSurfaceSubprocessEnvironment.maxSubprocessEnvironmentValueCharacters
    nonisolated static let maxSubprocessPathCharacters =
        AgentSurfaceSubprocessEnvironment.maxSubprocessPathCharacters
    nonisolated static let maxSubprocessPathEntryCharacters =
        AgentSurfaceSubprocessEnvironment.maxSubprocessPathEntryCharacters
    nonisolated static let maxSubprocessPathEntries =
        AgentSurfaceSubprocessEnvironment.maxSubprocessPathEntries
    /// Provider env keys bridged Keychain -> child process env at spawn.
    nonisolated static let bridgedProviderEnvironmentKeys: [String] = [
        "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GOOGLE_API_KEY", "PERPLEXITY_API_KEY",
        "OPENROUTER_API_KEY", "GROQ_API_KEY", "MISTRAL_API_KEY", "XAI_API_KEY",
        "DEEPSEEK_API_KEY", "HF_TOKEN",
    ]

    nonisolated static func baseURL(port: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = loopbackHost
        components.port = port
        return components.url
    }

    nonisolated static func allocateLoopbackPort(excluding: Set<Int> = []) -> Int? {
        for _ in 0..<portAllocationAttempts {
            let candidate = Int.random(in: ephemeralPortRange)
            guard !excluding.contains(candidate) else { continue }
            if Self.isLoopbackTCPPortAvailable(candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Sanitized child environment: allowlisted inherited vars only, with PATH
    /// rebuilt from the child's binary directories plus canonical tool dirs.
    nonisolated static func childEnvironment(
        binaryDirectories: [URL],
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        AgentSurfaceSubprocessEnvironment.childEnvironment(binaryDirectories: binaryDirectories, base: base)
    }

    /// Shared Node runtime resolution. Release builds resolve only trusted
    /// bundled locations; DEBUG adds developer-machine fallbacks.
    nonisolated static func resolvedNodeBinary(bundle: Bundle = .main) -> URL? {
        var candidates: [URL] = []
        if let resources = bundle.resourceURL {
            candidates.append(resources.appendingPathComponent("experimental-runtime/bin/node"))
            candidates.append(resources.appendingPathComponent("node"))
        }
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["EPISTEMOS_NODE_BINARY"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/node"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/node"))
        #endif
        return firstExecutable(in: candidates)
    }

    nonisolated static func firstExecutable(in candidates: [URL]) -> URL? {
        let fileManager = FileManager.default
        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    nonisolated static func randomSecretKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            return Data(bytes).base64EncodedString()
        }
        return (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }

    nonisolated static func isLoopbackTCPPortAvailable(_ port: Int) -> Bool {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }

        var reuse = Int32(1)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr(loopbackHost))

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(descriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }

    /// Keychain -> env bridge for agent child processes.
    nonisolated static func bridgedProviderEnvironment(
        keychainLoad: (String) -> String? = { Keychain.load(for: $0) }
    ) -> [String: String] {
        var env: [String: String] = [:]
        for envVar in bridgedProviderEnvironmentKeys {
            guard let keychainKey = AppBootstrap.agentCoreKeychainKey(forEnvironmentKey: envVar),
                  let raw = keychainLoad(keychainKey) else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.utf8.count <= 4_096, !value.utf8.contains(0) else { continue }
            env[envVar] = value
        }
        return env
    }

    /// Time-bounded provider-env bridge. The Keychain reads are synchronous and
    /// can block on first-launch ACL prompts, so race them against a deadline.
    nonisolated static func bridgedProviderEnvironment(
        timeout: Duration,
        onTimeout: @escaping @Sendable () -> Void
    ) async -> [String: String] {
        return await withCheckedContinuation { (continuation: CheckedContinuation<[String: String], Never>) in
            let box = AgentSurfaceContinuationBox(continuation)
            Task.detached(priority: .userInitiated) {
                box.resolve(bridgedProviderEnvironment())
            }
            Task.detached {
                try? await Task.sleep(for: timeout)
                if box.resolve([:]) { onTimeout() }
            }
        }
    }
}

/// Resumes a CheckedContinuation exactly once across a race.
private nonisolated final class AgentSurfaceContinuationBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?
    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    @discardableResult
    func resolve(_ value: T) -> Bool {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: value)
        return cont != nil
    }
}
#endif
