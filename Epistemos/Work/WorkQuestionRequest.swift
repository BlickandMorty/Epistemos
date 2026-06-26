import Foundation

// Native model for an OpenGUI/OpenCode QUESTION request (the agent asks the user) — the sibling of WorkPermissionRequest
// forwarded through the same `harness.on("event")` bridge: `HarnessEvent { type:"question.requested", request: QuestionRequest }`
// where `QuestionInteractionRequest` (src/protocol/session-transcript.ts) is:
//   { id, sessionID, questions: QuestionPrompt[], tool?{messageID,callID} }
//   QuestionPrompt = { question, header, options:[{label, description?}], multiple?, custom? }
// The reply is a QuestionAnswer per prompt = string[] (selected option labels; multi when `multiple`, or a custom string
// when `custom`). Pure, lenient, testable REQUEST model + decoder; the sidecar `respondQuestion`/`rejectQuestion` + the
// supervisor wrappers + the card UI consume it.

struct WorkQuestionOption: Sendable, Hashable, Identifiable {
    var id: String { label }
    let label: String
    let description: String?
}

struct WorkQuestionPrompt: Sendable, Hashable, Identifiable {
    let id: Int            // index within the request (stable for ForEach + answer ordering)
    let question: String
    let header: String
    let options: [WorkQuestionOption]
    let multiple: Bool     // multi-select allowed
    let custom: Bool       // a free-text custom answer is allowed
}

struct WorkQuestionRequest: Identifiable, Sendable, Hashable {
    let id: String
    let harnessID: String?
    let sessionID: String
    let prompts: [WorkQuestionPrompt]
    let toolCallID: String?
}

enum WorkQuestionRequestDecoder {
    /// Decode a question request from the sidecar. Accepts the harness-event envelope
    /// `{type:"question.requested", request:{…}}` (or `{event:{…}}` wrappers) OR a bare request object. Lenient: returns
    /// nil only when `id` is absent or there are no prompts. Never throws.
    static func decode(_ data: Data?) -> WorkQuestionRequest? {
        guard let data, let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return decode(any: root)
    }

    static func decode(any: Any) -> WorkQuestionRequest? {
        guard let object = requestObject(from: any) else { return nil }
        guard let id = object["id"] as? String, !id.isEmpty else { return nil }
        let harnessID = (object["harnessId"] as? String) ?? (object["harnessID"] as? String)
        guard let sessionID = (object["sessionID"] as? String) ?? (object["sessionId"] as? String),
              !sessionID.isEmpty else { return nil }
        let rawPrompts = (object["questions"] as? [[String: Any]]) ?? []
        let prompts: [WorkQuestionPrompt] = rawPrompts.enumerated().compactMap { index, raw in
            guard let question = raw["question"] as? String else { return nil }
            let options = ((raw["options"] as? [[String: Any]]) ?? []).compactMap { opt -> WorkQuestionOption? in
                guard let label = opt["label"] as? String else { return nil }
                return WorkQuestionOption(label: label, description: opt["description"] as? String)
            }
            return WorkQuestionPrompt(
                id: index, question: question, header: (raw["header"] as? String) ?? "",
                options: options, multiple: (raw["multiple"] as? Bool) ?? false,
                custom: (raw["custom"] as? Bool) ?? false)
        }
        guard !prompts.isEmpty else { return nil }
        let tool = object["tool"] as? [String: Any]
        let toolCallID = (tool?["callID"] as? String) ?? (tool?["callId"] as? String)
        return WorkQuestionRequest(id: id, harnessID: harnessID, sessionID: sessionID, prompts: prompts, toolCallID: toolCallID)
    }

    /// Dig to the request object: a bare request (has `questions`), else the `request` field, else inside `event`.
    private static func requestObject(from any: Any) -> [String: Any]? {
        if let dict = any as? [String: Any] {
            if dict["questions"] != nil, dict["id"] != nil { return dict }
            if let request = dict["request"] as? [String: Any] { return requestObject(from: request) }
            if let event = dict["event"] { return requestObject(from: event) }
        }
        return nil
    }
}
