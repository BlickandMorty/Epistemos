import Foundation

@MainActor
struct ArenaPathResolver {
    static func resolve(container: AppGroupContainer = .shared) throws -> URL {
        try container.ensureLayout()
        return container.arenaURL
    }

    static func resolveCString(container: AppGroupContainer = .shared) throws -> Data {
        let path = try resolve(container: container).path
        guard var bytes = path.data(using: .utf8) else {
            throw ArenaPathResolverError.invalidPathEncoding(path)
        }
        bytes.append(0)
        return bytes
    }
}

enum ArenaPathResolverError: Error, LocalizedError, Equatable {
    case invalidPathEncoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidPathEncoding(let path):
            return "Arena path could not be encoded as UTF-8: \(path)"
        }
    }
}
