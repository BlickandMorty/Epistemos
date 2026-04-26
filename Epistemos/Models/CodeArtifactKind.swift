import Foundation
import UniformTypeIdentifiers

// MARK: - CodeArtifactKind
//
// Wave 9.1 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 9.1,
//  cross-ref `epistemos_code_verdict.md`).
//
// Per-language catalog for code artifacts. Each `CodeArtifactKind`
// is one programming language (or markup format) the editor can
// create + edit + index. Keeps the file-extension table + tree-sitter
// grammar id + UTType + new-file template all in one place so the
// "create new code file" flow only needs the user's chosen kind.
//
// Distinct from `ArtifactKind.code` (Wave 3.2): that's the unified
// taxonomy's discriminator (this artifact IS code); `CodeArtifactKind`
// is the per-language refinement (this code IS Swift, Rust, etc.).
//
// All values are CONTRACTS — they appear in `.epcode.json` sidecars,
// in vault folder names, and in cross-ref links. Adding a new
// language is a 4-step ritual:
//   1. Add a case here in declaration order.
//   2. Add the file extension(s), tree-sitter grammar id, UTType,
//      display name, and an optional new-file template.
//   3. Update `CodeArtifactKindParityTests` (canonicalCases list).
//   4. (W9.7 follow-up) wire the Rust indexer to handle the language.

nonisolated public enum CodeArtifactKind: String, Codable, Sendable, Hashable, CaseIterable {
    case swift
    case rust
    case typescript
    case javascript
    case python
    case go
    case ruby
    case html
    case css
    case json
    case yaml
    case toml
    case markdown
    case shell
    case sql
    case plain

    // MARK: - Display

    /// Human-readable label for the new-file picker / inspector.
    public var displayName: String {
        switch self {
        case .swift:      return "Swift"
        case .rust:       return "Rust"
        case .typescript: return "TypeScript"
        case .javascript: return "JavaScript"
        case .python:     return "Python"
        case .go:         return "Go"
        case .ruby:       return "Ruby"
        case .html:       return "HTML"
        case .css:        return "CSS"
        case .json:       return "JSON"
        case .yaml:       return "YAML"
        case .toml:       return "TOML"
        case .markdown:   return "Markdown"
        case .shell:      return "Shell"
        case .sql:        return "SQL"
        case .plain:      return "Plain Text"
        }
    }

    // MARK: - File extensions

    /// Primary extension used when creating a new file. The full list
    /// of recognised extensions is in `recognisedExtensions`.
    public var primaryExtension: String {
        switch self {
        case .swift:      return "swift"
        case .rust:       return "rs"
        case .typescript: return "ts"
        case .javascript: return "js"
        case .python:     return "py"
        case .go:         return "go"
        case .ruby:       return "rb"
        case .html:       return "html"
        case .css:        return "css"
        case .json:       return "json"
        case .yaml:       return "yaml"
        case .toml:       return "toml"
        case .markdown:   return "md"
        case .shell:      return "sh"
        case .sql:        return "sql"
        case .plain:      return "txt"
        }
    }

    /// Every file extension that maps back to this kind. Used by the
    /// reverse-resolver to classify an arbitrary file path.
    public var recognisedExtensions: Set<String> {
        switch self {
        case .swift:      return ["swift"]
        case .rust:       return ["rs"]
        case .typescript: return ["ts", "tsx"]
        case .javascript: return ["js", "jsx", "mjs", "cjs"]
        case .python:     return ["py", "pyi"]
        case .go:         return ["go"]
        case .ruby:       return ["rb"]
        case .html:       return ["html", "htm"]
        case .css:        return ["css"]
        case .json:       return ["json"]
        case .yaml:       return ["yaml", "yml"]
        case .toml:       return ["toml"]
        case .markdown:   return ["md", "markdown", "mdx"]
        case .shell:      return ["sh", "bash", "zsh"]
        case .sql:        return ["sql"]
        case .plain:      return ["txt"]
        }
    }

    /// Map a file URL → its CodeArtifactKind (or `.plain` if no
    /// extension matches a registered language). Case-insensitive.
    public static func from(fileURL: URL) -> CodeArtifactKind {
        let ext = fileURL.pathExtension.lowercased()
        for kind in CodeArtifactKind.allCases where kind.recognisedExtensions.contains(ext) {
            return kind
        }
        return .plain
    }

    // MARK: - Tree-sitter grammar

    /// Identifier the SwiftTreeSitter loader uses to look up the
    /// grammar bundle. `nil` for languages we can't currently
    /// highlight (W9.6 follow-up may add).
    public var treeSitterGrammar: String? {
        switch self {
        case .swift:      return "swift"
        case .rust:       return "rust"
        case .typescript: return "typescript"
        case .javascript: return "javascript"
        case .python:     return "python"
        case .go:         return "go"
        case .ruby:       return "ruby"
        case .html:       return "html"
        case .css:        return "css"
        case .json:       return "json"
        case .yaml:       return "yaml"
        case .toml:       return "toml"
        case .markdown:   return "markdown"
        case .shell:      return "bash"
        case .sql:        return "sql"
        case .plain:      return nil
        }
    }

    // MARK: - UTType

    /// macOS UTI for the kind. Falls back to `.plainText` for kinds
    /// without a registered UTI.
    public var utType: UTType {
        switch self {
        case .swift:      return UTType("public.swift-source") ?? .sourceCode
        case .rust:       return UTType("com.rust.rust-source") ?? .sourceCode
        case .typescript: return UTType("public.script.typescript") ?? .sourceCode
        case .javascript: return .javaScript
        case .python:     return .pythonScript
        case .go:         return UTType("com.golang.go-source") ?? .sourceCode
        case .ruby:       return .rubyScript
        case .html:       return .html
        case .css:        return UTType("public.css") ?? .text
        case .json:       return .json
        case .yaml:       return .yaml
        case .toml:       return UTType("io.epistemos.toml") ?? .text
        case .markdown:   return UTType("net.daringfireball.markdown") ?? .text
        case .shell:      return .shellScript
        case .sql:        return UTType("io.epistemos.sql") ?? .text
        case .plain:      return .plainText
        }
    }

    // MARK: - New-file template

    /// Boilerplate inserted when the user creates a new file of this
    /// kind. The name placeholder is `<NAME>` and gets replaced with
    /// the basename the user picks. `nil` for kinds where an empty
    /// file is the right starting point.
    public func newFileTemplate(name: String) -> String {
        let safeName = name.replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
        switch self {
        case .swift:
            return """
            import Foundation

            // \(safeName).swift
            // Created via Epistemos.

            """
        case .rust:
            return """
            //! \(safeName)
            //! Created via Epistemos.

            """
        case .typescript:
            return """
            // \(safeName).ts
            // Created via Epistemos.

            export {};

            """
        case .javascript:
            return """
            // \(safeName).js
            // Created via Epistemos.

            """
        case .python:
            return """
            \"\"\"\(safeName).py — created via Epistemos.\"\"\"

            """
        case .go:
            return """
            // \(safeName).go
            // Created via Epistemos.

            package main

            """
        case .ruby:
            return """
            # \(safeName).rb
            # Created via Epistemos.

            """
        case .html:
            return """
            <!DOCTYPE html>
            <html lang=\"en\">
            <head>
              <meta charset=\"utf-8\">
              <title>\(safeName)</title>
            </head>
            <body>
            </body>
            </html>

            """
        case .css:
            return """
            /* \(safeName).css */

            """
        case .json:
            return "{}\n"
        case .yaml:
            return "# \(safeName).yaml\n"
        case .toml:
            return "# \(safeName).toml\n"
        case .markdown:
            return "# \(safeName)\n\n"
        case .shell:
            return """
            #!/usr/bin/env bash
            # \(safeName).sh — created via Epistemos.
            set -euo pipefail

            """
        case .sql:
            return "-- \(safeName).sql — created via Epistemos.\n"
        case .plain:
            return ""
        }
    }
}
