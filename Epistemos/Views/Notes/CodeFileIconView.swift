import Foundation
import SwiftUI

nonisolated struct CodeFileIdentityTint {
    let red: Double
    let green: Double
    let blue: Double

    @MainActor var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

nonisolated struct CodeFileIdentity {
    let languageID: String
    let displayName: String
    let shortMark: String
    let symbolName: String?
    let tint: CodeFileIdentityTint?
}

struct CodeFileIconView: View {
    let filePath: String?
    let language: String
    let theme: EpistemosTheme

    private var identity: CodeFileIdentity {
        CodeFileIconResolver.identity(forFilePath: filePath, language: language)
    }

    var body: some View {
        let tint = identity.tint?.color ?? theme.resolved.accent.color
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(tint.opacity(theme.isDark ? 0.24 : 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(tint.opacity(theme.isDark ? 0.42 : 0.28), lineWidth: 0.75)
                )

            if let symbolName = identity.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
            } else {
                Text(identity.shortMark)
                    .font(.system(size: identity.shortMark.count > 3 ? 7 : 8, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(tint)
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}

nonisolated enum CodeFileIconResolver {
    static func identity(forFilePath filePath: String?, language: String) -> CodeFileIdentity {
        let resolvedLanguage = normalizedLanguage(forFilePath: filePath, language: language)
        switch resolvedLanguage {
        case "swift":
            return CodeFileIdentity(
                languageID: "swift",
                displayName: "Swift",
                shortMark: "SW",
                symbolName: "swift",
                tint: CodeFileIdentityTint(red: 0.95, green: 0.33, blue: 0.18)
            )
        case "rust":
            return CodeFileIdentity(
                languageID: "rust",
                displayName: "Rust",
                shortMark: "RS",
                symbolName: "gearshape.2.fill",
                tint: CodeFileIdentityTint(red: 0.78, green: 0.42, blue: 0.22)
            )
        case "python":
            return CodeFileIdentity(
                languageID: "python",
                displayName: "Python",
                shortMark: "PY",
                symbolName: "curlybraces",
                tint: CodeFileIdentityTint(red: 0.28, green: 0.51, blue: 0.89)
            )
        case "javascript":
            return CodeFileIdentity(
                languageID: "javascript",
                displayName: "JavaScript",
                shortMark: "JS",
                symbolName: "function",
                tint: CodeFileIdentityTint(red: 0.86, green: 0.62, blue: 0.13)
            )
        case "typescript":
            return CodeFileIdentity(
                languageID: "typescript",
                displayName: "TypeScript",
                shortMark: "TS",
                symbolName: "curlybraces",
                tint: CodeFileIdentityTint(red: 0.25, green: 0.53, blue: 0.94)
            )
        case "json":
            return CodeFileIdentity(
                languageID: "json",
                displayName: "JSON",
                shortMark: "JSON",
                symbolName: "curlybraces.square",
                tint: CodeFileIdentityTint(red: 0.30, green: 0.68, blue: 0.42)
            )
        case "html":
            return CodeFileIdentity(
                languageID: "html",
                displayName: "HTML",
                shortMark: "HTML",
                symbolName: "chevron.left.forwardslash.chevron.right",
                tint: CodeFileIdentityTint(red: 0.93, green: 0.42, blue: 0.18)
            )
        case "css":
            return CodeFileIdentity(
                languageID: "css",
                displayName: "CSS",
                shortMark: "CSS",
                symbolName: "paintpalette.fill",
                tint: CodeFileIdentityTint(red: 0.30, green: 0.47, blue: 0.92)
            )
        case "bash":
            return CodeFileIdentity(
                languageID: "bash",
                displayName: "Shell",
                shortMark: "SH",
                symbolName: "terminal.fill",
                tint: CodeFileIdentityTint(red: 0.34, green: 0.72, blue: 0.45)
            )
        case "go":
            return CodeFileIdentity(
                languageID: "go",
                displayName: "Go",
                shortMark: "GO",
                symbolName: "bolt.horizontal.fill",
                tint: CodeFileIdentityTint(red: 0.14, green: 0.62, blue: 0.82)
            )
        case "c":
            return CodeFileIdentity(
                languageID: "c",
                displayName: "C",
                shortMark: "C",
                symbolName: "c.circle.fill",
                tint: CodeFileIdentityTint(red: 0.45, green: 0.56, blue: 0.86)
            )
        case "cpp":
            return CodeFileIdentity(
                languageID: "cpp",
                displayName: "C++",
                shortMark: "C++",
                symbolName: "c.circle",
                tint: CodeFileIdentityTint(red: 0.36, green: 0.48, blue: 0.84)
            )
        case "yaml":
            return CodeFileIdentity(
                languageID: "yaml",
                displayName: "YAML",
                shortMark: "YML",
                symbolName: "list.bullet.rectangle",
                tint: CodeFileIdentityTint(red: 0.64, green: 0.50, blue: 0.92)
            )
        case "toml":
            return CodeFileIdentity(
                languageID: "toml",
                displayName: "TOML",
                shortMark: "TOML",
                symbolName: "slider.horizontal.3",
                tint: CodeFileIdentityTint(red: 0.37, green: 0.66, blue: 0.62)
            )
        case "markdown":
            return CodeFileIdentity(
                languageID: "markdown",
                displayName: "Markdown",
                shortMark: "MD",
                symbolName: "text.alignleft",
                tint: nil
            )
        case "gdscript":
            return CodeFileIdentity(
                languageID: "gdscript",
                displayName: "GDScript",
                shortMark: "GD",
                symbolName: "gamecontroller.fill",
                tint: CodeFileIdentityTint(red: 0.36, green: 0.58, blue: 0.92)
            )
        case "lua":
            return CodeFileIdentity(
                languageID: "lua",
                displayName: "Lua",
                shortMark: "LUA",
                symbolName: "moon.stars.fill",
                tint: CodeFileIdentityTint(red: 0.32, green: 0.40, blue: 0.92)
            )
        case "ruby":
            return CodeFileIdentity(
                languageID: "ruby",
                displayName: "Ruby",
                shortMark: "RB",
                symbolName: "diamond.fill",
                tint: CodeFileIdentityTint(red: 0.82, green: 0.18, blue: 0.22)
            )
        case "java":
            return CodeFileIdentity(
                languageID: "java",
                displayName: "Java",
                shortMark: "JV",
                symbolName: "cup.and.saucer.fill",
                tint: CodeFileIdentityTint(red: 0.74, green: 0.34, blue: 0.22)
            )
        case "sql":
            return CodeFileIdentity(
                languageID: "sql",
                displayName: "SQL",
                shortMark: "SQL",
                symbolName: "cylinder.split.1x2.fill",
                tint: CodeFileIdentityTint(red: 0.33, green: 0.58, blue: 0.86)
            )
        case "zig":
            return CodeFileIdentity(
                languageID: "zig",
                displayName: "Zig",
                shortMark: "ZIG",
                symbolName: "bolt.fill",
                tint: CodeFileIdentityTint(red: 0.91, green: 0.58, blue: 0.20)
            )
        default:
            let displayName = CodeLanguage.displayName(for: resolvedLanguage)
            return CodeFileIdentity(
                languageID: resolvedLanguage,
                displayName: displayName,
                shortMark: shortMark(for: displayName),
                symbolName: "chevron.left.forwardslash.chevron.right",
                tint: nil
            )
        }
    }

    static func fallbackSymbol(for language: String) -> String {
        identity(forFilePath: nil, language: language).symbolName ?? "chevron.left.forwardslash.chevron.right"
    }

    private static func normalizedLanguage(forFilePath filePath: String?, language: String) -> String {
        if let filePath,
           let detected = CodeLanguage.detectEditorLanguage(from: filePath) {
            return detected
        }

        let normalized = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "md" || normalized == "mdx" {
            return "markdown"
        }
        if normalized == "sh" || normalized == "shell" || normalized == "zsh" || normalized == "fish" {
            return "bash"
        }
        if normalized == "rs" {
            return "rust"
        }
        if normalized == "js" || normalized == "jsx" {
            return "javascript"
        }
        if normalized == "ts" || normalized == "tsx" {
            return "typescript"
        }
        if normalized == "yml" {
            return "yaml"
        }
        if normalized.isEmpty,
           let fallbackLanguage = fallbackLanguageFromPath(filePath) {
            return fallbackLanguage
        }
        return normalized.isEmpty ? "code" : normalized
    }

    private static func fallbackLanguageFromPath(_ filePath: String?) -> String? {
        guard let filePath, !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let fileName = (filePath as NSString).lastPathComponent.lowercased()
        switch fileName {
        case "makefile", "gnumakefile", "dockerfile":
            return "bash"
        case "cargo.toml", "pyproject.toml":
            return "toml"
        default:
            let pathExtension = (filePath as NSString).pathExtension.lowercased()
            return pathExtension.isEmpty ? nil : pathExtension
        }
    }

    private static func shortMark(for displayName: String) -> String {
        let letters = displayName.filter(\.isLetter)
        let prefix = String(letters.prefix(3))
        return prefix.isEmpty ? "CODE" : prefix.uppercased()
    }
}
