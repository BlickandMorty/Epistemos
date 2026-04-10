// ClarifyPromptBridge.swift
//
// Bridges the Rust `clarify` tool (Phase 1) to a native macOS prompt.
// The Rust side calls `AgentEventDelegate.ask_user_question(question_json)`
// when it needs a clarifying answer mid-loop. The Swift side surfaces an
// NSAlert with an optional accessory text field (free-form) or a list of
// buttons (one per choice). The chosen response is serialized back as
// `{ "response": String, "choice_index": Int? }` so the agent loop can
// continue with the user's answer.
//
// We deliberately use NSAlert + key window — same pattern as
// `ChatCoordinator.promptForToolApproval` — so the prompt is modal,
// dismissable, and works regardless of which view hierarchy is on screen.

import AppKit
import Foundation
import os

@MainActor
final class ClarifyPromptBridge {
    static let shared = ClarifyPromptBridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "Clarify")

    private init() {}

    /// Block on a native alert until the user answers. Returns the JSON
    /// payload expected by the Rust side. Never throws — on any error we
    /// fall back to an empty response so the agent loop can continue.
    func ask(questionJson: String) async -> String {
        let parsed = ClarifyRequest.decode(jsonString: questionJson)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "The agent has a question"
        alert.informativeText = parsed.question.isEmpty
            ? "(no question provided)"
            : parsed.question

        // Add a button per choice. NSAlert supports up to 3 buttons cleanly.
        // For >3 choices we collapse the rest into the free-form text path.
        let choices = parsed.choices ?? []
        let useButtons = !choices.isEmpty && choices.count <= 3
        if useButtons {
            for choice in choices {
                alert.addButton(withTitle: choice)
            }
            // Always offer a Cancel escape so the agent can be told "no answer".
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.addButton(withTitle: "Send")
            alert.addButton(withTitle: "Cancel")
        }

        // Free-form text field for the open-ended path.
        var inputField: NSTextField?
        if !useButtons {
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
            field.placeholderString = "Type your answer…"
            alert.accessoryView = field
            // Make the field first responder when the alert appears.
            DispatchQueue.main.async { [weak field] in
                if let win = NSApp.keyWindow {
                    win.makeFirstResponder(field)
                }
            }
            inputField = field
        }

        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            response = await withCheckedContinuation { (continuation: CheckedContinuation<NSApplication.ModalResponse, Never>) in
                alert.beginSheetModal(for: window) { resp in
                    continuation.resume(returning: resp)
                }
            }
        } else {
            response = alert.runModal()
        }

        return Self.encodeResponse(
            response: response,
            useButtons: useButtons,
            choices: choices,
            inputText: inputField?.stringValue ?? ""
        )
    }

    private static func encodeResponse(
        response: NSApplication.ModalResponse,
        useButtons: Bool,
        choices: [String],
        inputText: String
    ) -> String {
        if useButtons {
            // The N-th button (0-indexed) corresponds to choices[N], with the
            // final button being Cancel. AlertFirstButton is .alertFirstButtonReturn.
            let firstRaw = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            let idx = response.rawValue - firstRaw
            if idx >= 0 && idx < choices.count {
                return jsonString([
                    "response": choices[idx],
                    "choice_index": idx,
                ])
            }
            return jsonString([
                "response": "",
                "choice_index": NSNull(),
                "cancelled": true,
            ])
        }
        // Free-form text path
        if response == .alertFirstButtonReturn {
            return jsonString([
                "response": inputText,
                "choice_index": NSNull(),
            ])
        }
        return jsonString([
            "response": "",
            "choice_index": NSNull(),
            "cancelled": true,
        ])
    }

    private static func jsonString(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{\"response\":\"\",\"choice_index\":null}"
        }
        return string
    }
}

// MARK: - Decode helpers

private struct ClarifyRequest: Sendable {
    let question: String
    let choices: [String]?

    static func decode(jsonString: String) -> ClarifyRequest {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ClarifyRequest(question: "", choices: nil)
        }
        let question = (root["question"] as? String) ?? ""
        let choicesArray = root["choices"] as? [String]
        let choices = (choicesArray?.isEmpty == false) ? choicesArray : nil
        return ClarifyRequest(question: question, choices: choices)
    }
}
