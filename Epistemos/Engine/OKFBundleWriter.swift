import Foundation

/// R-OKF — writes an Open Knowledge Format bundle (a directory of one-concept-
/// per-file markdown). Pairs with `OKFExporter` (the per-note projection). The
/// only stateful concern here is the filesystem and filename-collision handling,
/// both of which are testable against a tempdir.
///
/// Honest: this only WRITES the markdown the user already has (their notes), to
/// a directory the user picked. It never deletes or mutates the source vault.
nonisolated enum OKFBundleWriter {
    /// Collision-safe `.md` filenames for a sequence of notes, in order. When two
    /// notes slug to the same filename, later ones get `-2`, `-3`, … suffixes so
    /// nothing is silently overwritten. Pure — no I/O.
    static func fileNames(for notes: [OKFExporter.Note]) -> [String] {
        var used: Set<String> = []
        var result: [String] = []
        for note in notes {
            let base = OKFExporter.fileName(for: note)   // "<slug>.md"
            var name = base
            if used.contains(name) {
                let stem = String(base.dropLast(3))      // strip ".md"
                var n = 2
                repeat {
                    name = "\(stem)-\(n).md"
                    n += 1
                } while used.contains(name)
            }
            used.insert(name)
            result.append(name)
        }
        return result
    }

    /// Write each note's OKF markdown into `directory` using collision-safe
    /// filenames. Creates `directory` if needed. Returns the written file URLs,
    /// in note order.
    @discardableResult
    static func write(
        notes: [OKFExporter.Note],
        to directory: URL,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let names = fileNames(for: notes)
        var urls: [URL] = []
        for (note, name) in zip(notes, names) {
            let url = directory.appendingPathComponent(name)
            try Data(OKFExporter.markdown(for: note).utf8).write(to: url, options: .atomic)
            urls.append(url)
        }
        return urls
    }
}
