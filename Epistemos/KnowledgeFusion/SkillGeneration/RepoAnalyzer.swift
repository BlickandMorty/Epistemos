import Foundation

// MARK: - Repo Analysis Result

struct RepoAnalysis: Sendable {
    let functionSignatures: [ExtractedFunction]
    let namingConvention: NamingConvention
    let errorHandlingPatterns: [String]
    let importPatterns: [String: Int]       // import → frequency
    let detectedLanguages: [String: Int]    // language → file count
    let architectureHints: [String]
}

struct ExtractedFunction: Sendable {
    let name: String
    let signature: String
    let file: String
    let language: String
}

enum NamingConvention: String, Sendable {
    case camelCase
    case snakeCase
    case mixed
    case unknown
}

// MARK: - Repo Analyzer

/// Static analysis of code repositories to extract patterns, conventions,
/// and function signatures. No LLM required — uses regex and heuristics.
nonisolated struct RepoAnalyzer: Sendable {

    private static let languageMap: [String: String] = [
        "swift": "Swift", "py": "Python", "rs": "Rust",
        "js": "JavaScript", "ts": "TypeScript", "jsx": "JavaScript",
        "tsx": "TypeScript", "go": "Go", "java": "Java",
        "kt": "Kotlin", "rb": "Ruby", "c": "C", "cpp": "C++",
        "h": "C", "hpp": "C++", "sh": "Shell"
    ]

    func analyze(vaultURL: URL) -> RepoAnalysis {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return RepoAnalysis(
                functionSignatures: [], namingConvention: .unknown,
                errorHandlingPatterns: [], importPatterns: [:],
                detectedLanguages: [:], architectureHints: []
            )
        }

        var functions: [ExtractedFunction] = []
        var languages: [String: Int] = [:]
        var imports: [String: Int] = [:]
        var camelCount = 0
        var snakeCount = 0
        var errorPatterns: Set<String> = []
        var archHints: Set<String> = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard let lang = Self.languageMap[ext] else { continue }
            languages[lang, default: 0] += 1

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            let fileName = fileURL.lastPathComponent

            // Extract functions (first 500 lines to keep fast)
            for line in lines.prefix(500) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Function signatures
                if let sig = extractFunction(trimmed, language: lang) {
                    functions.append(ExtractedFunction(
                        name: sig.name, signature: sig.signature,
                        file: fileName, language: lang
                    ))
                }

                // Imports
                if trimmed.hasPrefix("import ") || trimmed.hasPrefix("from ") || trimmed.hasPrefix("use ") {
                    let key = String(trimmed.prefix(60))
                    imports[key, default: 0] += 1
                }

                // Naming convention detection
                let identifiers = extractIdentifiers(trimmed)
                for id in identifiers {
                    if id.contains("_") && id.lowercased() == id { snakeCount += 1 }
                    else if id.first?.isLowercase == true && id.contains(where: { $0.isUppercase }) { camelCount += 1 }
                }

                // Error handling patterns
                if trimmed.contains("do {") || trimmed.contains("try ") { errorPatterns.insert("do/catch (Swift)") }
                if trimmed.contains("Result<") || trimmed.contains("Result.success") { errorPatterns.insert("Result type") }
                if trimmed.contains("throws") || trimmed.contains("async throws") { errorPatterns.insert("throws functions") }
                if trimmed.contains("guard let") || trimmed.contains("guard ") { errorPatterns.insert("guard statements") }
                if trimmed.contains("try?") { errorPatterns.insert("optional try") }
                if trimmed.contains("except") || trimmed.contains("try:") { errorPatterns.insert("try/except (Python)") }
                if trimmed.contains("unwrap()") || trimmed.contains(".unwrap()") { errorPatterns.insert("unwrap (Rust)") }
            }

            // Architecture hints from file names
            if fileName.contains("ViewModel") || fileName.contains("viewmodel") { archHints.insert("MVVM") }
            if fileName.contains("Controller") { archHints.insert("MVC") }
            if fileName.contains("Store") || fileName.contains("State") { archHints.insert("State Management") }
            if fileName.contains("Service") { archHints.insert("Service Layer") }
            if fileName.contains("Repository") { archHints.insert("Repository Pattern") }
            if fileName.contains("Router") { archHints.insert("Router/Coordinator") }
        }

        let naming: NamingConvention
        if camelCount > snakeCount * 2 { naming = .camelCase }
        else if snakeCount > camelCount * 2 { naming = .snakeCase }
        else if camelCount > 0 || snakeCount > 0 { naming = .mixed }
        else { naming = .unknown }

        return RepoAnalysis(
            functionSignatures: Array(functions.prefix(200)),
            namingConvention: naming,
            errorHandlingPatterns: Array(errorPatterns).sorted(),
            importPatterns: imports,
            detectedLanguages: languages,
            architectureHints: Array(archHints).sorted()
        )
    }

    // MARK: - Function Extraction

    private func extractFunction(_ line: String, language: String) -> (name: String, signature: String)? {
        switch language {
        case "Swift":
            // func name(...) -> Type
            if line.contains("func "), let match = line.range(of: #"func\s+(\w+)\s*\([^)]*\)"#, options: .regularExpression) {
                let sig = String(line[match])
                let name = sig.components(separatedBy: "(").first?.replacingOccurrences(of: "func ", with: "").trimmingCharacters(in: .whitespaces) ?? sig
                return (name, String(line.prefix(120)))
            }
        case "Python":
            if line.hasPrefix("def "), let match = line.range(of: #"def\s+(\w+)\s*\([^)]*\)"#, options: .regularExpression) {
                let sig = String(line[match])
                let name = sig.components(separatedBy: "(").first?.replacingOccurrences(of: "def ", with: "").trimmingCharacters(in: .whitespaces) ?? sig
                return (name, String(line.prefix(120)))
            }
        case "Rust":
            if line.contains("fn "), let match = line.range(of: #"fn\s+(\w+)\s*[<(]"#, options: .regularExpression) {
                let sig = String(line[match])
                let name = sig.components(separatedBy: "(").first?.replacingOccurrences(of: "fn ", with: "").trimmingCharacters(in: .whitespaces) ?? sig
                return (name, String(line.prefix(120)))
            }
        case "JavaScript", "TypeScript":
            if line.contains("function ") || line.contains("=> {") {
                if let match = line.range(of: #"(?:function|const|let|var)\s+(\w+)"#, options: .regularExpression) {
                    let name = String(line[match]).components(separatedBy: " ").last ?? ""
                    return (name, String(line.prefix(120)))
                }
            }
        default:
            break
        }
        return nil
    }

    private func extractIdentifiers(_ line: String) -> [String] {
        let pattern = #"\b[a-zA-Z_]\w{2,30}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap {
            Range($0.range, in: line).map { String(line[$0]) }
        }.prefix(10).map { $0 }
    }
}
