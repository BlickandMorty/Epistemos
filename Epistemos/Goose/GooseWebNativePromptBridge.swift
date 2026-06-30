import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class GooseWebNativePromptBridge: NSObject, WKScriptMessageHandlerWithReply {
    nonisolated static let maxPromptIDCharacters = 128
    nonisolated static let maxPromptPayloadBytes = 1 * 1024 * 1024
    nonisolated private static let maxPromptPayloadDepth = 32
    nonisolated private static let maxPromptPayloadCollectionEntries = 4_096

    private(set) var pendingPermission: GooseWebPermissionPrompt?
    private(set) var pendingElicitation: GooseWebElicitationPrompt?

    @ObservationIgnored private var permissionReply: (@MainActor @Sendable (Any?, String?) -> Void)?
    @ObservationIgnored private var elicitationReply: (@MainActor @Sendable (Any?, String?) -> Void)?
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()

    isolated deinit {
        cancelPendingPrompts()
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        // review C-M3: handler is registered in the `.page` content world (NOT forMainFrameOnly), so
        // reject prompt-bridge messages from non-main frames — a foreign iframe must not be able to
        // drive permission/elicitation replies.
        guard message.frameInfo.isMainFrame else {
            replyHandler(nil, "Epistemos blocked a Goose prompt request from a non-main frame.")
            return
        }
        guard let body = message.body as? [String: Any] else {
            replyHandler(nil, "Malformed Epistemos Goose prompt request.")
            return
        }
        receivePromptMessage(body, replyHandler: replyHandler)
    }

    func receivePromptMessage(
        _ body: [String: Any],
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        guard let type = body["type"] as? String,
              let rawID = body["id"] as? String,
              let requestObject = body["request"] else {
            replyHandler(nil, "Malformed Epistemos Goose prompt request.")
            return
        }
        guard let id = Self.boundedPromptID(rawID) else {
            replyHandler(
                nil,
                GooseWebNativePromptBridgeError.promptIDTooLong(Self.maxPromptIDCharacters).localizedDescription
            )
            return
        }
        guard type == "permission" || type == "elicitation" else {
            replyHandler(nil, "Unsupported Epistemos Goose prompt request.")
            return
        }

        do {
            let requestData = try jsonData(from: requestObject)
            switch type {
            case "permission":
                let request = try decoder.decode(GooseACPRequestPermissionRequest.self, from: requestData)
                cancelPendingPermission()
                pendingPermission = GooseWebPermissionPrompt(id: id, request: request)
                permissionReply = replyHandler
            case "elicitation":
                let request = try decoder.decode(GooseACPCreateElicitationRequest.self, from: requestData)
                cancelPendingElicitation()
                pendingElicitation = GooseWebElicitationPrompt(id: id, request: request)
                elicitationReply = replyHandler
            default:
                replyHandler(nil, "Unsupported Epistemos Goose prompt request.")
            }
        } catch {
            replyHandler(nil, "Invalid Epistemos Goose prompt payload: \(error.localizedDescription)")
        }
    }

    func resolvePermission(promptID: String, optionID: String?) {
        guard pendingPermission?.id == promptID,
              let reply = permissionReply else { return }
        pendingPermission = nil
        permissionReply = nil

        let response = optionID.map(GooseACPRequestPermissionResponse.selected(optionId:))
            ?? GooseACPRequestPermissionResponse.cancelled()
        replyWithJSONObject(response, reply: reply)
    }

    func acceptElicitation(promptID: String, values: [String: JSONValue]) {
        resolveElicitation(promptID: promptID, response: .accept(values))
    }

    func declineElicitation(promptID: String) {
        resolveElicitation(promptID: promptID, response: .decline())
    }

    func cancelElicitation(promptID: String) {
        resolveElicitation(promptID: promptID, response: .cancel())
    }

    func cancelPendingPrompts() {
        cancelPendingPermission()
        cancelPendingElicitation()
    }

    private func resolveElicitation(
        promptID: String,
        response: GooseACPCreateElicitationResponse
    ) {
        guard pendingElicitation?.id == promptID,
              let reply = elicitationReply else { return }
        pendingElicitation = nil
        elicitationReply = nil
        replyWithJSONObject(response, reply: reply)
    }

    private func cancelPendingPermission() {
        guard let reply = permissionReply else { return }
        pendingPermission = nil
        permissionReply = nil
        replyWithJSONObject(GooseACPRequestPermissionResponse.cancelled(), reply: reply)
    }

    private func cancelPendingElicitation() {
        guard let reply = elicitationReply else { return }
        pendingElicitation = nil
        elicitationReply = nil
        replyWithJSONObject(GooseACPCreateElicitationResponse.cancel(), reply: reply)
    }

    private func replyWithJSONObject<T: Encodable>(
        _ value: T,
        reply: @MainActor @Sendable (Any?, String?) -> Void
    ) {
        do {
            let data = try encoder.encode(value)
            reply(try JSONSerialization.jsonObject(with: data), nil)
        } catch {
            reply(nil, error.localizedDescription)
        }
    }

    private func jsonData(from object: Any) throws -> Data {
        guard GooseNativeJSONSizeBudget.permits(
            object,
            maxBytes: Self.maxPromptPayloadBytes,
            maxDepth: Self.maxPromptPayloadDepth,
            maxCollectionEntries: Self.maxPromptPayloadCollectionEntries
        ) else {
            throw GooseWebNativePromptBridgeError.payloadTooLarge(Self.maxPromptPayloadBytes)
        }
        guard JSONSerialization.isValidJSONObject(object) else {
            throw GooseWebNativePromptBridgeError.nonJSONObject
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        guard data.count <= Self.maxPromptPayloadBytes else {
            throw GooseWebNativePromptBridgeError.payloadTooLarge(Self.maxPromptPayloadBytes)
        }
        return data
    }

    nonisolated static func boundedPromptID(_ rawID: String) -> String? {
        let withoutControls = String(String.UnicodeScalarView(rawID.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }))
        let trimmed = withoutControls.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= Self.maxPromptIDCharacters else {
            return nil
        }
        return trimmed
    }
}

struct GooseWebPermissionPrompt: Identifiable, Equatable, Sendable {
    let id: String
    let request: GooseACPRequestPermissionRequest
}

struct GooseWebElicitationPrompt: Identifiable, Equatable, Sendable {
    let id: String
    let request: GooseACPCreateElicitationRequest

    var message: String { request.message }
    var fields: [GooseACPElicitationFormField] {
        GooseACPElicitationFormField.fields(from: request.requestedSchema)
    }
}

private enum GooseWebNativePromptBridgeError: LocalizedError {
    case nonJSONObject
    case payloadTooLarge(Int)
    case promptIDTooLong(Int)

    var errorDescription: String? {
        switch self {
        case .nonJSONObject:
            "Prompt payload is not a JSON object."
        case .payloadTooLarge(let limit):
            "Prompt payload is over \(limit) bytes."
        case .promptIDTooLong(let limit):
            "Prompt ID is empty or over \(limit) characters."
        }
    }
}
