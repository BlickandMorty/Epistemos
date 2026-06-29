import Foundation

nonisolated enum BrowserUseLoopbackPolicy {
    static func allows(url: URL?) -> Bool {
        guard let url,
              url.scheme?.lowercased() == "http",
              let host = url.host,
              normalizedAllowedHost(host) != nil,
              let port = url.port,
              (1...65535).contains(port),
              url.user == nil,
              url.password == nil else {
            return false
        }
        return true
    }

    static func loopbackURL(host: String, port: Int) -> URL? {
        guard let normalizedHost = normalizedAllowedHost(host),
              (1...65535).contains(port) else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = normalizedHost
        components.port = port
        components.path = "/"
        return components.url
    }

    private static func normalizedAllowedHost(_ host: String) -> String? {
        guard let normalized = normalize(host),
              normalized == "127.0.0.1" || normalized == "localhost" || normalized == "::1" else {
            return nil
        }
        return normalized
    }

    private static func normalize(_ host: String) -> String? {
        let trimmed = host
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
}
