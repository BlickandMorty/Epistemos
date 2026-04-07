// SkillPromptLibrary.swift
//
// Editor skill definitions extracted from Hermes skill templates.
// Provides focused system prompts for code-centric ask bar interactions.
// Each skill narrows the model's behavior and tool subset.
//
// 2026-04-06.

import Foundation

// MARK: - Editor Skill

enum EditorSkill: String, CaseIterable, Identifiable, Sendable {
    case codeReview = "Review"
    case addErrorHandling = "Harden"
    case writeTests = "Test"
    case explainCode = "Explain"
    case refactorCode = "Refactor"
    case documentCode = "Document"
    case debugCode = "Debug"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .codeReview: "eye.fill"
        case .addErrorHandling: "shield.fill"
        case .writeTests: "checkmark.seal.fill"
        case .explainCode: "text.bubble.fill"
        case .refactorCode: "arrow.triangle.2.circlepath"
        case .documentCode: "doc.text.fill"
        case .debugCode: "ant.fill"
        }
    }

    /// System prompt fragment prepended to the user's query when this skill is active.
    var systemPrompt: String {
        switch self {
        case .codeReview:
            return """
            You are reviewing code for clarity, correctness, and language idioms.
            Focus on: security (hardcoded secrets, input validation, injection), \
            error handling (try/catch, resource cleanup), code quality (function size, \
            naming, DRY), and testing considerations.
            Provide specific, actionable suggestions with line references. \
            Explain WHY, not just WHAT. Offer solutions, not just problems.
            Do not rewrite the code — provide a structured review.
            """

        case .addErrorHandling:
            return """
            You are hardening code by adding comprehensive error handling.
            Add try/catch blocks, guard clauses, input validation, and proper error propagation.
            Ensure resource cleanup in all error paths. Replace force-unwraps with safe alternatives.
            Use the edit_file tool to apply changes. Preserve existing behavior — only add safety.
            """

        case .writeTests:
            return """
            You are writing tests for the given code using the project's testing framework.
            Follow TDD principles: write clear, descriptive test names that describe behavior.
            Cover: happy path, error cases, edge cases, and boundary conditions.
            One assertion per test when possible. Use insert_at_line to add tests.
            For Swift: use @Test and #expect (Swift Testing), not XCTest.
            """

        case .explainCode:
            return """
            You are explaining code to help the user understand it.
            Break down the code's purpose, data flow, and design decisions.
            Identify patterns, algorithms, and architectural choices.
            Reference specific line numbers. Tailor depth to the code complexity.
            Do NOT suggest changes — only explain what exists.
            """

        case .refactorCode:
            return """
            You are refactoring code to improve clarity and maintainability.
            Preserve exact behavior — no functional changes allowed.
            Focus on: naming clarity, function decomposition (<50 lines per function), \
            reducing nesting, extracting shared logic, improving type safety.
            Use edit_file to apply changes. Explain each refactoring decision.
            """

        case .documentCode:
            return """
            You are generating documentation for the given code.
            Use the project's documentation style (/// for Swift, /// or // for Rust).
            Include: purpose, parameters, return values, throws/errors, usage examples.
            For complex algorithms, explain the approach and time/space complexity.
            Use insert_at_line or edit_file to add documentation in place.
            """

        case .debugCode:
            return """
            You are systematically debugging code. Follow root cause investigation:
            1. Read error messages carefully — don't skip stack traces.
            2. Check recent changes (what changed?).
            3. Trace data flow upstream to the source.
            4. Form a single hypothesis and test minimally.
            Fix at the source, not the symptom. One fix at a time.
            Use edit_file to apply the fix. Explain the root cause.
            """
        }
    }

    /// Which file-op tools to expose when this skill is active.
    var toolSubset: [CloudJSONSchema] {
        switch self {
        case .codeReview, .explainCode:
            return [] // read-only skills
        case .addErrorHandling, .refactorCode, .debugCode:
            return [FileEditTool.editFile, FileEditTool.replaceFile]
        case .writeTests, .documentCode:
            return [FileEditTool.insertAtLine, FileEditTool.editFile]
        }
    }
}
