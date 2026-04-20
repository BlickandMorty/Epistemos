// CodeAskBar.swift
//
// Specialized Ask Bar for code editor with dual response modes:
// - Focused: Page blurs, detailed response panel with code and explanations
// - Inline: AI advice appears as annotations/hover tooltips on highlighted code sections
//
// Unlike prose editor (which appends responses), this provides contextual,
// integrated AI assistance that feels like part of the IDE.
//
// 2026-04-07.

import SwiftUI
import Combine
import os.log

// MARK: - Response Mode

enum CodeAskBarResponseMode: String, CaseIterable, Codable {
    case focused = "Focused"
    case inline = "Inline"
    
    var icon: String {
        switch self {
        case .focused: return "rectangle.center.inset.filled"
        case .inline: return "text.bubble"
        }
    }
    
    var description: String {
        switch self {
        case .focused:
            return "Detailed responses in focused panel with blurred background"
        case .inline:
            return "AI advice appears as annotations on highlighted code sections"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .focused: return "Focused panel"
        case .inline: return "Inline annotations"
        }
    }
}

// MARK: - Inline Response Annotation

/// Represents an AI response annotation attached to specific code
struct InlineResponseAnnotation: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let codeRange: NSRange
    let lineNumber: Int
    let type: AnnotationType
    let severity: Severity
    let relatedQuery: String
    let timestamp = Date()
    
    enum AnnotationType {
        case suggestion      // Code improvement
        case explanation     // What this code does
        case warning         // Potential issue
        case optimization    // Performance tip
        case pattern         // Pattern matching from vault
        
        var icon: String {
            switch self {
            case .suggestion: return "lightbulb"
            case .explanation: return "text.book.closed"
            case .warning: return "exclamationmark.triangle"
            case .optimization: return "bolt"
            case .pattern: return "arrow.triangle.branch"
            }
        }
        
        var color: Color {
            switch self {
            case .suggestion: return .yellow
            case .explanation: return .blue
            case .warning: return .orange
            case .optimization: return .green
            case .pattern: return .purple
            }
        }

        var description: String {
            switch self {
            case .suggestion: return "Suggestion"
            case .explanation: return "Explanation"
            case .warning: return "Warning"
            case .optimization: return "Optimization"
            case .pattern: return "Pattern"
            }
        }
    }
    
    enum Severity {
        case info
        case suggestion
        case important
        
        var opacity: Double {
            switch self {
            case .info: return 0.15
            case .suggestion: return 0.25
            case .important: return 0.4
            }
        }
    }
}

// MARK: - Focused Response

/// A detailed AI response for the focused panel mode
struct FocusedCodeResponse: Identifiable {
    let id = UUID()
    let query: String
    let summary: String
    let sections: [ResponseSection]
    let relatedCodeRanges: [NSRange]
    let timestamp = Date()
    
    struct ResponseSection: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        let type: SectionType
        let codeBlocks: [CodeBlock]
        
        enum SectionType {
            case explanation
            case suggestion
            case warning
            case example
            case reference

            var icon: String {
                switch self {
                case .explanation: return "text.bubble"
                case .suggestion: return "lightbulb"
                case .warning: return "exclamationmark.triangle"
                case .example: return "doc.text"
                case .reference: return "book"
                }
            }

            var color: Color {
                switch self {
                case .explanation: return .blue
                case .suggestion: return .yellow
                case .warning: return .orange
                case .example: return .green
                case .reference: return .purple
                }
            }

            var label: String {
                switch self {
                case .explanation: return "EXPLANATION"
                case .suggestion: return "SUGGESTION"
                case .warning: return "WARNING"
                case .example: return "EXAMPLE"
                case .reference: return "REFERENCE"
                }
            }
        }
        
        struct CodeBlock: Identifiable {
            let id = UUID()
            let language: String
            let code: String
            let explanation: String?
        }
    }
}

// MARK: - Code Ask Bar Service

@MainActor
@Observable
final class CodeAskBarService {

    var responseMode: CodeAskBarResponseMode = .focused
    var isQuerying = false
    var currentQuery = ""

    // Focused mode state
    var focusedResponse: FocusedCodeResponse?
    var showFocusedPanel = false

    // Inline mode state
    var inlineAnnotations: [InlineResponseAnnotation] = []
    var hoveredAnnotation: UUID?
    
    // Services
    private let triageService: TriageService?
    private let graphState: GraphState?
    private let embeddingService: EmbeddingService
    private let logger = Logger(subsystem: "app.epistemos", category: "CodeAskBar")
    private var queryTask: Task<Void, Never>?

    init(triageService: TriageService?, graphState: GraphState?) {
        self.triageService = triageService
        self.graphState = graphState
        self.embeddingService = graphState?.embeddingService ?? EmbeddingService()
    }
    
    // MARK: - Query Processing
    
    func submitQuery(_ query: String, code: String, language: String, cursorLine: Int) {
        guard !query.isEmpty, !isQuerying else { return }
        
        currentQuery = query
        isQuerying = true
        
        queryTask?.cancel()
        queryTask = Task { @MainActor in
            await processQuery(query, code: code, language: language, cursorLine: cursorLine)
        }
    }
    
    private func processQuery(_ query: String, code: String, language: String, cursorLine: Int) async {
        defer { isQuerying = false }

        let context = extractContext(code: code, aroundLine: cursorLine)
        let prompt = buildPrompt(query: query, context: context, language: language)

        do {
            let response = try await generateResponse(prompt: prompt, userQuery: query, language: language)

            switch responseMode {
            case .focused:
                showFocusedResponse(query: query, response: response, code: code)
            case .inline:
                createInlineAnnotations(query: query, response: response, code: code)
            }

            // Persist query + response to SDChat for chat unification
            persistCodeAskExchange(query: query, response: response, language: language)
        } catch {
            logger.error("Query failed: \(error.localizedDescription)")
        }
    }

    /// Persists a code ask bar exchange to SDChat for unified chat history.
    private func persistCodeAskExchange(query: String, response: String, language: String) {
        guard let ctx = AppBootstrap.shared?.modelContainer.mainContext else { return }

        let chat = SDChat(title: "Code Ask: \(language)", chatType: "codeAsk")
        ctx.insert(chat)

        let userMsg = SDMessage(role: "user", content: query)
        userMsg.chat = chat
        ctx.insert(userMsg)

        let assistantMsg = SDMessage(role: "assistant", content: response)
        assistantMsg.chat = chat
        ctx.insert(assistantMsg)
        let persistedMessages = [userMsg, assistantMsg]

        do { try ctx.save() } catch {
            for message in persistedMessages {
                ctx.delete(message)
            }
            ctx.delete(chat)
            logger.error("Code ask persistence failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Focused Mode
    
    private func showFocusedResponse(query: String, response: String, code: String) {
        let sections = parseResponseIntoSections(response, language: "swift")
        let ranges = findRelevantCodeRanges(response: response, code: code)
        
        focusedResponse = FocusedCodeResponse(
            query: query,
            summary: extractSummary(from: response),
            sections: sections,
            relatedCodeRanges: ranges
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showFocusedPanel = true
        }
    }
    
    func dismissFocusedPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showFocusedPanel = false
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            self.focusedResponse = nil
        }
    }
    
    // MARK: - Inline Mode
    
    private func createInlineAnnotations(query: String, response: String, code: String) {
        // Clear previous annotations
        inlineAnnotations.removeAll()
        
        // Parse response for specific code references
        let lines = code.components(separatedBy: .newlines)
        var annotations: [InlineResponseAnnotation] = []
        
        // Example: Find references to specific lines or patterns
        let referencedLines = extractReferencedLines(from: response, totalLines: lines.count)
        
        for lineNum in referencedLines {
            guard lineNum > 0, lineNum <= lines.count else { continue }
            
            let line = lines[lineNum - 1]
            let range = NSRange(
                location: calculatePosition(code: code, line: lineNum, column: 1),
                length: line.count
            )
            
            // Generate specific advice for this line
            let advice = generateAdviceForLine(line: line, lineNumber: lineNum, fullResponse: response)
            
            let annotation = InlineResponseAnnotation(
                text: advice,
                codeRange: range,
                lineNumber: lineNum,
                type: determineAnnotationType(from: advice),
                severity: .suggestion,
                relatedQuery: query
            )
            
            annotations.append(annotation)
        }
        
        // Also add general annotations for broader sections
        if let generalAdvice = extractGeneralAdvice(from: response) {
            let generalAnnotation = InlineResponseAnnotation(
                text: generalAdvice,
                codeRange: NSRange(location: 0, length: code.count),
                lineNumber: 1,
                type: .explanation,
                severity: .info,
                relatedQuery: query
            )
            annotations.append(generalAnnotation)
        }
        
        inlineAnnotations = annotations
    }
    
    func clearInlineAnnotations() {
        withAnimation(.easeInOut(duration: 0.2)) {
            inlineAnnotations.removeAll()
        }
    }
    
    func removeAnnotation(id: UUID) {
        inlineAnnotations.removeAll { $0.id == id }
    }
    
    // MARK: - Helper Methods
    
    private func extractContext(code: String, aroundLine: Int) -> String {
        let lines = code.components(separatedBy: .newlines)
        let start = max(0, aroundLine - 10)
        let end = min(lines.count, aroundLine + 10)
        return lines[start..<end].joined(separator: "\n")
    }
    
    private func buildPrompt(query: String, context: String, language: String) -> String {
        let modeInstruction = responseMode == .focused
            ? "Provide a detailed response with code examples and explanations."
            : "Provide specific, line-by-line advice that can be shown as inline annotations. Reference specific line numbers."
        
        return """
        User question about \(language) code:
        "\(query)"
        
        Code context:
        ```\(language)
        \(context)
        ```
        
        \(modeInstruction)
        """
    }
    
    private func generateResponse(prompt: String, userQuery: String, language: String) async throws -> String {
        guard let triageService = triageService else {
            throw NSError(domain: "CodeAskBar", code: -1, userInfo: [NSLocalizedDescriptionKey: "TriageService not available"])
        }

        return try await triageService.generate(
            prompt: prompt,
            systemPrompt: """
            You are an expert coding assistant. Provide clear, actionable advice.
            When referencing code, be specific about line numbers and provide concrete examples.
            """,
            operation: .ask(query: userQuery),
            contentLength: prompt.count
        )
    }
    
    private func parseResponseIntoSections(_ response: String, language: String) -> [FocusedCodeResponse.ResponseSection] {
        // Parse response into structured sections
        var sections: [FocusedCodeResponse.ResponseSection] = []
        
        // Split by headers (## or ###)
        let pattern = "(##|###)\\s*(.+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        let nsRange = NSRange(response.startIndex..., in: response)
        let matches = regex?.matches(in: response, options: [], range: nsRange) ?? []
        
        if matches.isEmpty {
            // No headers - treat entire response as one section
            sections.append(FocusedCodeResponse.ResponseSection(
                title: "Response",
                content: response,
                type: .explanation,
                codeBlocks: extractCodeBlocks(from: response)
            ))
        } else {
            // Parse sections
            for (index, match) in matches.enumerated() {
                guard let titleRange = Range(match.range(at: 2), in: response) else { continue }
                let title = String(response[titleRange])
                
                let startIndex = match.range.location
                let endIndex = index < matches.count - 1 ? matches[index + 1].range.location : response.count
                let contentRange = NSRange(location: startIndex, length: endIndex - startIndex)
                
                guard let contentSwiftRange = Range(contentRange, in: response),
                      let headerSwiftRange = Range(match.range, in: response) else { continue }
                let matchedHeader = String(response[headerSwiftRange])
                let content = String(response[contentSwiftRange])
                    .replacingOccurrences(of: matchedHeader, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                sections.append(FocusedCodeResponse.ResponseSection(
                    title: title,
                    content: content,
                    type: determineSectionType(from: title),
                    codeBlocks: extractCodeBlocks(from: content)
                ))
            }
        }
        
        return sections
    }
    
    private func extractCodeBlocks(from text: String) -> [FocusedCodeResponse.ResponseSection.CodeBlock] {
        let pattern = "```(\\w+)?\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        return matches.compactMap { match in
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            let language: String
            if languageRange.location != NSNotFound,
               let langRange = Range(languageRange, in: text) {
                language = String(text[langRange])
            } else {
                language = "text"
            }
            
            guard let codeSwiftRange = Range(codeRange, in: text) else { return nil }
            let code = String(text[codeSwiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            return FocusedCodeResponse.ResponseSection.CodeBlock(
                language: language,
                code: code,
                explanation: nil
            )
        }
    }
    
    private func determineSectionType(from title: String) -> FocusedCodeResponse.ResponseSection.SectionType {
        let lower = title.lowercased()
        if lower.contains("warn") || lower.contains("caution") { return .warning }
        if lower.contains("example") || lower.contains("code") { return .example }
        if lower.contains("suggest") || lower.contains("improve") { return .suggestion }
        if lower.contains("reference") || lower.contains("see also") { return .reference }
        return .explanation
    }
    
    private func extractSummary(from response: String) -> String {
        // Extract first sentence or first 150 chars
        let sentences = response.components(separatedBy: ".")
        if let first = sentences.first {
            return first.trimmingCharacters(in: .whitespaces) + "."
        }
        return String(response.prefix(150)) + "..."
    }
    
    private func findRelevantCodeRanges(response: String, code: String) -> [NSRange] {
        // Find which parts of the code are referenced in the response
        var ranges: [NSRange] = []
        let lines = code.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() where !line.isEmpty {
            if response.contains(line.trimmingCharacters(in: .whitespaces).prefix(30)) {
                let position = calculatePosition(code: code, line: index + 1, column: 1)
                ranges.append(NSRange(location: position, length: line.count))
            }
        }
        
        return ranges
    }
    
    private func extractReferencedLines(from response: String, totalLines: Int) -> [Int] {
        // Look for line number references like "line 5" or "line 10-15"
        let pattern = "line\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        
        let matches = regex.matches(in: response, options: [], range: NSRange(response.startIndex..., in: response))
        
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: response) else { return nil }
            return Int(response[range])
        }.filter { $0 > 0 && $0 <= totalLines }
    }
    
    private func generateAdviceForLine(line: String, lineNumber: Int, fullResponse: String) -> String {
        // Extract advice specific to this line from the full response
        let lines = fullResponse.components(separatedBy: .newlines)
        
        for (index, responseLine) in lines.enumerated() {
            if responseLine.contains("line \(lineNumber)") || responseLine.contains(line.trimmingCharacters(in: .whitespaces).prefix(20)) {
                // Found a reference - get surrounding context
                let start = max(0, index - 1)
                let end = min(lines.count, index + 2)
                return lines[start..<end].joined(separator: " ")
            }
        }
        
        return "Consider reviewing this code based on your query."
    }
    
    private func determineAnnotationType(from advice: String) -> InlineResponseAnnotation.AnnotationType {
        let lower = advice.lowercased()
        if lower.contains("warn") || lower.contains("error") || lower.contains("issue") {
            return .warning
        } else if lower.contains("optim") || lower.contains("faster") || lower.contains("performance") {
            return .optimization
        } else if lower.contains("pattern") || lower.contains("similar") || lower.contains("vault") {
            return .pattern
        } else if lower.contains("suggest") || lower.contains("could") || lower.contains("consider") {
            return .suggestion
        }
        return .explanation
    }
    
    private func extractGeneralAdvice(from response: String) -> String? {
        // Extract overall recommendation
        let paragraphs = response.components(separatedBy: "\n\n")
        return paragraphs.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func calculatePosition(code: String, line: Int, column: Int) -> Int {
        let lines = code.components(separatedBy: .newlines)
        var position = 0
        for i in 0..<min(line - 1, lines.count) {
            position += lines[i].count + 1
        }
        return position + column - 1
    }
}

// MARK: - Preview

#Preview("Code Ask Bar Modes") {
    VStack(spacing: 20) {
        ForEach(CodeAskBarResponseMode.allCases, id: \.self) { mode in
            HStack {
                Image(systemName: mode.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading) {
                    Text(mode.rawValue)
                        .font(.headline)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }
    .padding()
    .frame(width: 400)
}
