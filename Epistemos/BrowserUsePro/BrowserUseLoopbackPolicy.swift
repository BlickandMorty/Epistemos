import Foundation

nonisolated enum BrowserUseLoopbackPolicy {
    static func allows(url: URL?) -> Bool {
        guard let url,
              url.scheme?.lowercased() == "http",
              let host = url.host,
              isAllowedHost(host),
              let port = url.port,
              (1...65535).contains(port),
              url.user == nil,
              url.password == nil else {
            return false
        }
        return true
    }

    static func loopbackURL(host: String, port: Int) -> URL? {
        let normalizedHost = normalize(host)
        guard isAllowedHost(normalizedHost),
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

    private static func isAllowedHost(_ host: String) -> Bool {
        let normalized = normalize(host)
        return normalized == "127.0.0.1" || normalized == "localhost" || normalized == "::1"
    }

    private static func normalize(_ host: String) -> String {
        host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .lowercased()
    }
}
