import Foundation

/// Scans text for credentials and redacts them before context injection.
/// Shows first 4 + last 4 characters, masks the middle with `***`.
nonisolated enum CredentialRedactor {

    // MARK: - Patterns

    private nonisolated static let patterns: [(label: String, regex: NSRegularExpression)] = {
        let defs: [(String, String)] = [
            // Anthropic / OpenAI style keys
            ("api_key", #"sk-[A-Za-z0-9_\-]{20,}"#),
            // GitHub personal access tokens
            ("github_pat", #"ghp_[A-Za-z0-9]{36,}"#),
            ("github_pat_fine", #"github_pat_[A-Za-z0-9_]{22,}"#),
            // AWS access key IDs
            ("aws_key", #"AKIA[0-9A-Z]{16}"#),
            // PEM private keys
            ("pem_key", #"-----BEGIN[A-Z ]*PRIVATE KEY-----[\s\S]*?-----END[A-Z ]*PRIVATE KEY-----"#),
            // Bearer tokens
            ("bearer", #"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#),
            // Generic token= in URLs or config
            ("token_param", #"token=[A-Za-z0-9\-._~+/]{16,}"#),
            // Slack tokens
            ("slack_token", #"xox[bporas]-[A-Za-z0-9\-]{10,}"#),
            // Generic long hex secrets (32+ hex chars following common key names)
            ("hex_secret", #"(?:api[_-]?key|secret|password|token)\s*[:=]\s*["\']?[A-Fa-f0-9]{32,}["\']?"#),
        ]
        return defs.compactMap { label, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return (label, regex)
        }
    }()

    // MARK: - Public API

    /// Redact detected credentials in the given text.
    /// Returns the text with secrets partially masked (first 4 + `***` + last 4).
    nonisolated static func redact(_ text: String) -> String {
        var result = text
        for (_, regex) in patterns {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            // Process matches in reverse so ranges stay valid
            for match in matches.reversed() {
                guard let swiftRange = Range(match.range, in: result) else { continue }
                let matched = String(result[swiftRange])
                result.replaceSubrange(swiftRange, with: mask(matched))
            }
        }
        return result
    }

    /// Returns true if the text contains any credential patterns.
    nonisolated static func containsCredentials(_ text: String) -> Bool {
        for (_, regex) in patterns {
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Internal

    /// Show first 4 + last 4 chars, mask middle with `***`.
    private nonisolated static func mask(_ secret: String) -> String {
        guard secret.count > 12 else {
            // Too short to reveal any chars safely
            return String(repeating: "*", count: secret.count)
        }
        let prefix = secret.prefix(4)
        let suffix = secret.suffix(4)
        return "\(prefix)***\(suffix)"
    }
}
