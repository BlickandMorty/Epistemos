import Foundation

nonisolated enum BrowserUseSymlinkPathGuard {
    static func firstSymlinkComponent(
        in url: URL,
        fileManager: FileManager = .default
    ) -> URL? {
        var cursor = URL(fileURLWithPath: "/", isDirectory: true)
        for component in URL(fileURLWithPath: url.path).standardizedFileURL.pathComponents.dropFirst() {
            cursor = cursor.appendingPathComponent(component)
            guard !isMacOSCompatibilitySymlink(cursor) else {
                continue
            }
            if (try? fileManager.destinationOfSymbolicLink(atPath: cursor.path)) != nil {
                return cursor
            }
        }
        return nil
    }

    private static func isMacOSCompatibilitySymlink(_ url: URL) -> Bool {
        switch url.path {
        case "/etc", "/tmp", "/var":
            return true
        default:
            return false
        }
    }
}
