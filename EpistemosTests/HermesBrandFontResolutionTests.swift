import Foundation
import Testing

/// Stage E.0 fonts contract.
///
/// SwiftUI's `.custom(name:size:)` looks up fonts by their PostScript name,
/// not by file name. If the bundled .ttf's actual PSName diverges from the
/// string passed to `.custom(...)`, SwiftUI silently substitutes the system
/// font — the user sees no error, just the wrong typography.
///
/// This test reads each bundled font's PSName directly from the .ttf binary
/// and asserts the names HermesBrand requests actually exist. It would have
/// caught the original Stage E.0 bug where Inter-Regular.ttf and
/// Inter-SemiBold.ttf both shipped with PSName "InterVariable" but
/// HermesBrand.swift was requesting "Inter-Regular" / "Inter-SemiBold" —
/// silently falling back to the system font on every Hermes surface.
@Suite("Hermes brand font resolution (Stage E.0)")
struct HermesBrandFontResolutionTests {

    /// The fonts HermesBrand.swift requests, paired with the bundled .ttf
    /// file expected to contain that PSName. Update this matrix only when
    /// HermesBrand intentionally adds / removes a font.
    ///
    /// Inter is shipped as a single variable font (PSName `InterVariable`);
    /// HermesBrand picks weight axes via `.weight()`. We deliberately do
    /// not ship Inter-SemiBold.ttf because it would be the same binary
    /// with the same PSName — wasted bundle space.
    private static let expectedFontResolution: [(psName: String, ttfFile: String)] = [
        ("InterVariable",         "Inter-Regular.ttf"),
        ("JetBrainsMono-Regular", "JetBrainsMono-Regular.ttf"),
    ]

    @Test("Every PSName HermesBrand requests is actually present in a bundled .ttf")
    func everyHermesBrandFontRequestResolvesToBundledPSName() throws {
        let fontsDir = try Self.bundledFontsDirectory()

        for entry in Self.expectedFontResolution {
            let url = fontsDir.appendingPathComponent(entry.ttfFile)
            let resolved = try Self.readPostScriptName(at: url)
            #expect(
                resolved == entry.psName,
                """
                Bundled \(entry.ttfFile) has PostScript name "\(resolved)" but \
                HermesBrand requests "\(entry.psName)". SwiftUI's \
                .custom(name:size:) looks up by PSName, so this lookup \
                silently falls back to the system font. Either rebundle a \
                static cut of the font with the requested PSName, or update \
                HermesBrand to request the actual PSName "\(resolved)" and \
                pick the weight axis with .weight().
                """
            )
        }
    }

    // MARK: - Helpers

    /// Resolve the on-disk Fonts/ directory in the bundled source mirror.
    private static func bundledFontsDirectory() throws -> URL {
        let fontsDir = try sourceMirrorURL(for: "Epistemos/Resources/Fonts")

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fontsDir.path, isDirectory: &isDir),
              isDir.boolValue else {
            throw FontResolutionTestError.fontsDirectoryNotFound(fontsDir.path)
        }
        return fontsDir
    }

    /// Parse a TrueType font binary's `name` table, return the PostScript
    /// name (nameID 6). Bare-bones reader sufficient for static .ttf files.
    private static func readPostScriptName(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard data.count >= 12 else {
            throw FontResolutionTestError.malformedFont(url.lastPathComponent, "header truncated")
        }
        let numTables = Int(data.uint16BE(at: 4))

        var nameTableOffset: Int? = nil
        for i in 0..<numTables {
            let recordOffset = 12 + i * 16
            guard recordOffset + 16 <= data.count else { break }
            let tag = String(data: data.subdata(in: recordOffset..<recordOffset + 4), encoding: .ascii) ?? ""
            if tag == "name" {
                nameTableOffset = Int(data.uint32BE(at: recordOffset + 8))
                break
            }
        }

        guard let tableOffset = nameTableOffset, tableOffset + 6 <= data.count else {
            throw FontResolutionTestError.malformedFont(url.lastPathComponent, "name table missing")
        }

        let recordCount = Int(data.uint16BE(at: tableOffset + 2))
        let stringStorageOffset = tableOffset + Int(data.uint16BE(at: tableOffset + 4))

        for j in 0..<recordCount {
            let recOffset = tableOffset + 6 + j * 12
            guard recOffset + 12 <= data.count else { break }
            let platformID = data.uint16BE(at: recOffset + 0)
            let nameID = data.uint16BE(at: recOffset + 6)
            guard nameID == 6 else { continue }
            let length = Int(data.uint16BE(at: recOffset + 8))
            let strOffset = stringStorageOffset + Int(data.uint16BE(at: recOffset + 10))
            guard strOffset + length <= data.count else { continue }
            let raw = data.subdata(in: strOffset..<strOffset + length)
            // Per the TrueType `name` table spec the encoding depends on
            // platformID: 0 (Unicode) and 3 (Microsoft) store strings as
            // UTF-16 BE; 1 (Macintosh) stores them as MacRoman / ASCII.
            // Decoding UTF-16 BE for an ASCII platform record yields
            // garbled CJK glyphs (e.g. "䥮瑥牖" for "Inter").
            switch platformID {
            case 1:
                if let mac = String(data: raw, encoding: .macOSRoman) ?? String(data: raw, encoding: .ascii) {
                    let trimmed = mac.replacingOccurrences(of: "\0", with: "")
                    if !trimmed.isEmpty { return trimmed }
                }
            case 0, 3:
                if let utf16 = String(data: raw, encoding: .utf16BigEndian) {
                    let trimmed = utf16.replacingOccurrences(of: "\0", with: "")
                    if !trimmed.isEmpty { return trimmed }
                }
            default:
                continue
            }
        }

        throw FontResolutionTestError.malformedFont(url.lastPathComponent, "no nameID 6 record")
    }

    enum FontResolutionTestError: Error, CustomStringConvertible {
        case fontsDirectoryNotFound(String)
        case malformedFont(String, String)

        var description: String {
            switch self {
            case .fontsDirectoryNotFound(let path):
                return "Fonts directory not found at \(path)"
            case .malformedFont(let file, let reason):
                return "Malformed font \(file): \(reason)"
            }
        }
    }
}

private extension Data {
    func uint16BE(at offset: Int) -> UInt16 {
        let hi = UInt16(self[offset])
        let lo = UInt16(self[offset + 1])
        return (hi << 8) | lo
    }

    func uint32BE(at offset: Int) -> UInt32 {
        let b0 = UInt32(self[offset])
        let b1 = UInt32(self[offset + 1])
        let b2 = UInt32(self[offset + 2])
        let b3 = UInt32(self[offset + 3])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }
}
