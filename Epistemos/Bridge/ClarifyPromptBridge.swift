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

struct ClarifyPromptPresentation: Sendable {
    let question: String
    let choices: [String]?
}

struct ClarifyPromptAnswer: Sendable {
    let response: String
    let choiceIndex: Int?
    let cancelled: Bool
}

@MainActor
final class ClarifyPromptBridge {
    typealias Presenter = @MainActor (ClarifyPromptPresentation) async -> ClarifyPromptAnswer

    static let shared = ClarifyPromptBridge()

    private let logger = Logger(subsystem: "app.epistemos", category: "Clarify")
    private let presenter: Presenter
    private let agentProvenanceRecorder: AgentToolProvenanceRecorder
    private var clarifyToolCallSequence: UInt64 = 0

    init(
        presenter: @escaping Presenter = { prompt in
            await ClarifyPromptBridge.presentPrompt(prompt)
        },
        agentProvenanceRecorder: AgentToolProvenanceRecorder = AgentToolProvenanceRecorder()
    ) {
        self.presenter = presenter
        self.agentProvenanceRecorder = agentProvenanceRecorder
    }

    /// Block on a native alert until the user answers. Returns the JSON
    /// payload expected by the Rust side. Never throws — on any error we
    /// fall back to an empty response so the agent loop can continue.
    func ask(questionJson: String) async -> String {
        let parsed = ClarifyRequest.decode(jsonString: questionJson)
        let request = clarifyPromptEventRequest(from: parsed)
        let toolCallID = nextClarifyToolCallID()
        recordClarifyPromptEvent(
            toolCallID: toolCallID,
            kind: .toolCallRequested,
            status: .requested,
            request: request
        )
        recordClarifyPromptEvent(
            toolCallID: toolCallID,
            kind: .toolCallStarted,
            status: .started,
            request: request
        )

        let start = Date()
        let answer = await presenter(
            ClarifyPromptPresentation(question: parsed.question, choices: parsed.choices)
        )
        let result = ClarifyPromptEventResult(
            answered: !answer.cancelled && !answer.response.isEmpty,
            cancelled: answer.cancelled,
            responseLengthBucket: responseLengthBucket(answer.response),
            choiceIndex: answer.choiceIndex
        )
        recordClarifyPromptEvent(
            toolCallID: toolCallID,
            kind: .toolCallCompleted,
            status: .completed,
            request: request,
            result: result,
            durationMs: durationMilliseconds(since: start)
        )

        return Self.encodeResponse(answer: answer)
    }

    private static func presentPrompt(_ prompt: ClarifyPromptPresentation) async -> ClarifyPromptAnswer {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "The agent has a question"
        alert.informativeText = prompt.question.isEmpty
            ? "(no question provided)"
            : prompt.question

        // Add a button per choice. NSAlert supports up to 3 buttons cleanly.
        // For >3 choices we collapse the rest into the free-form text path.
        let choices = prompt.choices ?? []
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
            Task { @MainActor [weak field] in
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

        return Self.promptAnswer(
            response: response,
            useButtons: useButtons,
            choices: choices,
            inputText: inputField?.stringValue ?? ""
        )
    }

    private static func promptAnswer(
        response: NSApplication.ModalResponse,
        useButtons: Bool,
        choices: [String],
        inputText: String
    ) -> ClarifyPromptAnswer {
        if useButtons {
            // The N-th button (0-indexed) corresponds to choices[N], with the
            // final button being Cancel. AlertFirstButton is .alertFirstButtonReturn.
            let firstRaw = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            let idx = response.rawValue - firstRaw
            if idx >= 0 && idx < choices.count {
                return ClarifyPromptAnswer(
                    response: choices[idx],
                    choiceIndex: idx,
                    cancelled: false
                )
            }
            return ClarifyPromptAnswer(response: "", choiceIndex: nil, cancelled: true)
        }
        // Free-form text path
        if response == .alertFirstButtonReturn {
            return ClarifyPromptAnswer(response: inputText, choiceIndex: nil, cancelled: false)
        }
        return ClarifyPromptAnswer(response: "", choiceIndex: nil, cancelled: true)
    }

    private static func encodeResponse(answer: ClarifyPromptAnswer) -> String {
        if answer.cancelled {
            return jsonString([
                "response": "",
                "choice_index": NSNull(),
                "cancelled": true,
            ])
        }
        if let choiceIndex = answer.choiceIndex {
            return jsonString([
                "response": answer.response,
                "choice_index": choiceIndex,
            ])
        }
        return jsonString([
            "response": answer.response,
            "choice_index": NSNull(),
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

    private func nextClarifyToolCallID() -> String {
        let sequence = clarifyToolCallSequence
        if clarifyToolCallSequence < UInt64.max {
            clarifyToolCallSequence += 1
        }
        return "clarify-prompt-\(sequence)"
    }

    private func recordClarifyPromptEvent(
        toolCallID: String,
        kind: AgentProvenanceEventKind,
        status: AgentToolEventStatus,
        request: ClarifyPromptEventRequest,
        result: ClarifyPromptEventResult? = nil,
        durationMs: UInt64? = nil
    ) {
        agentProvenanceRecorder.recordToolEvent(
            runID: "clarify-prompt",
            traceID: nil,
            kind: kind,
            actor: .agent(id: "clarify-prompt-bridge", modelID: nil),
            toolCallID: toolCallID,
            toolName: "clarify.ask.\(request.inputMode)",
            argumentsJSON: clarifyPromptArgumentsJSON(request),
            resultJSON: result.map { clarifyPromptResultJSON($0) },
            durationMs: durationMs,
            status: status,
            metadata: clarifyPromptMetadata(
                request: request,
                result: result
            )
        )
    }

    private func clarifyPromptArgumentsJSON(_ request: ClarifyPromptEventRequest) -> String {
        Self.jsonString([
            "input_mode": request.inputMode,
            "question_scope": request.questionScope,
            "choice_count_bucket": request.choiceCountBucket,
            "payload_class": request.payloadClass,
        ])
    }

    private func clarifyPromptResultJSON(_ result: ClarifyPromptEventResult) -> String {
        var payload: [String: Any] = [
            "answered": result.answered,
            "cancelled": result.cancelled,
            "response_length_bucket": result.responseLengthBucket,
        ]
        payload["choice_index"] = result.choiceIndex ?? NSNull()
        return Self.jsonString(payload)
    }

    private func clarifyPromptMetadata(
        request: ClarifyPromptEventRequest,
        result: ClarifyPromptEventResult?
    ) -> [String: String] {
        var metadata = [
            "source": "clarify_prompt_bridge",
            "surface": "clarify.ask",
            "input_mode": request.inputMode,
            "question_scope": request.questionScope,
            "choice_count_bucket": request.choiceCountBucket,
            "payload_class": request.payloadClass,
        ]
        if let result {
            metadata["result_class"] = result.cancelled
                ? "cancelled"
                : (result.answered ? "answered" : "empty")
        }
        return metadata
    }

    private func clarifyPromptEventRequest(from parsed: ClarifyRequest) -> ClarifyPromptEventRequest {
        let choiceCount = parsed.choices?.count ?? 0
        return ClarifyPromptEventRequest(
            inputMode: choiceCount > 0 && choiceCount <= 3 ? "choice" : "freeform",
            questionScope: parsed.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "empty"
                : "provided",
            choiceCountBucket: choiceCountBucket(choiceCount),
            payloadClass: parsed.payloadClass
        )
    }

    private func choiceCountBucket(_ count: Int) -> String {
        switch count {
        case 0:
            return "0"
        case 1:
            return "1"
        case 2...3:
            return "2_3"
        default:
            return "4_plus"
        }
    }

    private func responseLengthBucket(_ response: String) -> String {
        switch response.count {
        case 0:
            return "0"
        case 1...5:
            return "1_5"
        case 6...16:
            return "6_16"
        case 17...64:
            return "17_64"
        default:
            return "65_plus"
        }
    }

    private func durationMilliseconds(since start: Date) -> UInt64 {
        let elapsed = Date().timeIntervalSince(start) * 1_000
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        return UInt64(elapsed.rounded())
    }
}

// MARK: - Decode helpers

private struct ClarifyPromptEventRequest: Sendable {
    let inputMode: String
    let questionScope: String
    let choiceCountBucket: String
    let payloadClass: String
}

private struct ClarifyPromptEventResult: Sendable {
    let answered: Bool
    let cancelled: Bool
    let responseLengthBucket: String
    let choiceIndex: Int?
}

private struct ClarifyRequest: Sendable {
    let question: String
    let choices: [String]?
    let payloadClass: String

    static func decode(jsonString: String) -> ClarifyRequest {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ClarifyRequest(question: "", choices: nil, payloadClass: "invalid_json")
        }
        let question = (root["question"] as? String) ?? ""
        let choicesArray = root["choices"] as? [String]
        let choices = (choicesArray?.isEmpty == false) ? choicesArray : nil
        return ClarifyRequest(question: question, choices: choices, payloadClass: "valid_json")
    }
}
