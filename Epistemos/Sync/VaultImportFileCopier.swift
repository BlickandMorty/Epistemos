import Foundation

/// A utility for copying files into the vault during import.
enum VaultImportFileCopier {
    /// Copies files from source URLs to a destination directory.
    /// Skips files that already exist in the destination.
    /// - Parameters:
    ///   - urls: The source file URLs to copy.
    ///   - destination: The destination directory URL.
    /// - Returns: The number of files successfully copied.
    static func copy(urls: [URL], to destination: URL) async -> Int {
        var count = 0
        let fm = FileManager.default
        
        // Ensure destination directory exists
        if !fm.fileExists(atPath: destination.path) {
            try? fm.createDirectory(at: destination, withIntermediateDirectories: true)
        }
        
        for url in urls {
            let destinationURL = destination.appendingPathComponent(url.lastPathComponent)
            
            // Skip if file already exists at destination
            guard !fm.fileExists(atPath: destinationURL.path) else {
                continue
            }
            
            do {
                try fm.copyItem(at: url, to: destinationURL)
                count += 1
            } catch {
                // Skip on error (e.g. permission issues) as per test expectations
            }
        }
        
        return count
    }
}
