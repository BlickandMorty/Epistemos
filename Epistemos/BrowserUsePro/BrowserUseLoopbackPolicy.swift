import Foundation

nonisolated struct BrowserUseLoopbackOrigin: Equatable, Sendable {
    let host: String
    let port: Int

    func allows(url: URL?) -> Bool {
        BrowserUseLoopbackPolicy.origin(for: url) == self
    }
}

nonisolated enum BrowserUseLoopbackPolicy {
    private static let defaultURLDiagnosticLength = 120
    private static let maxDiagnosticSchemeLength = 32
    private static let maxDiagnosticHostLength = 96

    static func allows(url: URL?) -> Bool {
        origin(for: url) != nil
    }

    static func origin(for url: URL?) -> BrowserUseLoopbackOrigin? {
        guard let url,
              url.scheme?.lowercased() == "http",
              let host = url.host,
              let normalizedHost = normalizedAllowedHost(host),
              let port = url.port,
              (1...65535).contains(port),
              url.user == nil,
              url.password == nil else {
            return nil
        }
        return BrowserUseLoopbackOrigin(host: normalizedHost, port: port)
    }

    static func loopbackURL(host: String, port: Int) -> URL? {
        guard let normalizedHost = normalizedAllowedHost(host),
              (1...65535).contains(port) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = normalizedHost == "::1" ? "[::1]" : normalizedHost
        components.port = port
        components.path = "/"
        return components.url
    }

    static func allowsHost(_ host: String) -> Bool {
        normalizedAllowedHost(host) != nil
    }

    static func redactedDescription(
        for url: URL,
        maxLength: Int = defaultURLDiagnosticLength
    ) -> String {
        let sourceComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let scheme = sourceComponents?.scheme ?? url.scheme,
           let host = sourceComponents?.host ?? url.host,
           !host.isEmpty {
            let safeScheme = String(scheme.prefix(maxDiagnosticSchemeLength))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let safeHost = String(host.prefix(maxDiagnosticHostLength))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !safeScheme.isEmpty, !safeHost.isEmpty else {
                return "[blocked URL]"
            }
            var displayComponents = URLComponents()
            displayComponents.scheme = safeScheme
            displayComponents.host = safeHost
            displayComponents.port = sourceComponents?.port ?? url.port
            return capped(displayComponents.string ?? "\(safeScheme)://\(safeHost)", maxLength: maxLength)
        }

        if let rawScheme = sourceComponents?.scheme ?? url.scheme {
            let scheme = String(rawScheme.prefix(maxDiagnosticSchemeLength))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !scheme.isEmpty {
                return capped("\(scheme) URL", maxLength: maxLength)
            }
        }

        return "[blocked URL]"
    }

    private static func normalizedAllowedHost(_ host: String) -> String? {
        guard let normalized = normalize(host),
              normalized == "127.0.0.1" || normalized == "localhost" || normalized == "::1" else {
            return nil
        }
        return normalized
    }

    private static func normalize(_ host: String) -> String? {
        let bounded = String(host.prefix(128))
        let trimmed = bounded
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("[") || trimmed.hasSuffix("]") {
            guard trimmed.hasPrefix("["),
                  trimmed.hasSuffix("]"),
                  trimmed.dropFirst().dropLast().contains(":") else {
                return nil
            }
            return String(trimmed.dropFirst().dropLast())
        }

        return trimmed
    }

    private static func capped(_ value: String, maxLength: Int) -> String {
        let limit = max(0, maxLength)
        let bounded = String(value.prefix(limit + 1))
        guard bounded.count > limit else {
            return bounded
        }
        guard limit > 3 else {
            return String(bounded.prefix(limit))
        }
        return String(bounded.prefix(limit - 3)) + "..."
    }
}
