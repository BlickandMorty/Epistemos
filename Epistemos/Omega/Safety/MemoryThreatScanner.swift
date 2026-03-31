import Foundation

/// Scans text for prompt injection, role hijacking, exfiltration, and invisible unicode
/// before injecting vault content into agent context.
nonisolated enum MemoryThreatScanner {

    // MARK: - Types

    enum ThreatLevel: Comparable, Sendable {
        case safe
        case suspicious
        case blocked
    }

    struct ScanResult: Sendable {
        let level: ThreatLevel
        let threats: [String]
    }

    // MARK: - Patterns

    private static let roleHijackPatterns: [String] = [
        #"(?i)you are now\b"#,
        #"(?i)ignore (all )?previous"#,
        #"(?i)ignore (your )?(above |prior )?instructions"#,
        #"(?i)^system\s*:"#,
        #"<\|im_start\|>"#,
        #"<\|im_end\|>"#,
        #"(?i)\[INST\]"#,
        #"(?i)new instructions:"#,
        #"(?i)override:\s"#,
    ]

    private static let exfiltrationPatterns: [String] = [
        #"(?i)curl\s+.*\|\s*(?:ba)?sh"#,
        #"(?i)wget\s+.*\|\s*(?:ba)?sh"#,
        #"(?i)curl\s+.*-o\s+/tmp/"#,
        #"(?i)python\s+-c\s+['\"]import\s+(?:urllib|requests|subprocess)"#,
        #"(?i)nc\s+-e\s+/bin/"#,
    ]

    /// Zero-width and bidi override characters that can hide malicious text.
    private static let invisibleUnicodeScalars: Set<Unicode.Scalar> = [
        "\u{200B}", // Zero-width space
        "\u{200C}", // Zero-width non-joiner
        "\u{200D}", // Zero-width joiner
        "\u{2060}", // Word joiner
        "\u{FEFF}", // BOM / zero-width no-break space
        "\u{202A}", // LTR embedding
        "\u{202B}", // RTL embedding
        "\u{202C}", // Pop directional
        "\u{202D}", // LTR override
        "\u{202E}", // RTL override
        "\u{2066}", // LTR isolate
        "\u{2067}", // RTL isolate
        "\u{2068}", // First strong isolate
        "\u{2069}", // Pop directional isolate
    ]

    // MARK: - Public API

    /// Scan text for prompt injection and other threats.
    nonisolated static func scan(_ text: String) -> ScanResult {
        var threats: [String] = []
        var maxLevel = ThreatLevel.safe

        // Role hijack patterns → blocked
        for pattern in roleHijackPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil {
                threats.append("Role hijack attempt detected")
                maxLevel = max(maxLevel, .blocked)
                break
            }
        }

        // Exfiltration patterns → blocked
        for pattern in exfiltrationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil {
                threats.append("Exfiltration command detected")
                maxLevel = max(maxLevel, .blocked)
                break
            }
        }

        // Credential patterns → suspicious (handled by CredentialRedactor, just flag here)
        if CredentialRedactor.containsCredentials(text) {
            threats.append("Embedded credentials detected")
            maxLevel = max(maxLevel, .suspicious)
        }

        // Invisible unicode → suspicious
        if text.unicodeScalars.contains(where: { invisibleUnicodeScalars.contains($0) }) {
            threats.append("Invisible unicode characters detected")
            maxLevel = max(maxLevel, .suspicious)
        }

        return ScanResult(level: maxLevel, threats: threats)
    }

    /// Sanitize text by removing invisible unicode characters.
    nonisolated static func sanitize(_ text: String) -> String {
        String(text.unicodeScalars.filter { !invisibleUnicodeScalars.contains($0) })
    }
}
