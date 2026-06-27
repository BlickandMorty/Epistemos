import Foundation
import Testing
@testable import Epistemos

@Suite("Goose ACP golden fixtures")
struct GooseACPGoldenFixtureTests {
    private let fixtureNames = [
        "F1_initialize.json",
        "F2_session_new.json",
        "F3_prompt_answer_stream.json",
        "F4_permission_tool_result.json",
        "F5_custom_readonly.json",
    ]

    @Test("Phase 0 F1-F5 fixture pack is present and sanitized")
    func fixturePackIsPresentAndSanitized() throws {
        for fixtureName in fixtureNames {
            let text = try loadFixtureText(fixtureName)
            #expect(!text.contains("/Users/"))
            #expect(!text.contains("phase0-fixture-capture-secret"))

            let fixture = try decodeFixture(text)
            #expect(fixture.id == fixtureName.replacingOccurrences(of: ".json", with: ""))
            #expect(!fixture.frames.isEmpty)
            #expect(fixture.generator == "scripts/generate-goose-acp-fixtures.mjs")
        }
    }

    @Test("captured frames decode through the Swift ACP protocol model")
    func capturedFramesDecodeThroughProtocolModel() throws {
        for fixtureName in fixtureNames {
            let fixture = try loadFixture(fixtureName)
            for frame in fixture.frames {
                _ = try decodeIncomingMessage(frame.body)
            }
        }
    }

    @Test("golden fixtures pin Phase 0 ACP surface shapes")
    func fixturesPinPhase0SurfaceShapes() throws {
        let initialize = try loadFixture("F1_initialize.json")
        #expect(clientMethods(in: initialize) == ["initialize"])
        let initializeResult = try responseResult(in: initialize, id: .int(1))
        #expect(initializeResult.objectValue?["protocolVersion"] == .int(1))

        let sessionNew = try loadFixture("F2_session_new.json")
        #expect(clientMethods(in: sessionNew) == ["session/new"])
        let sessionResult = try responseResult(in: sessionNew, id: .int(2))
        #expect(sessionResult.objectValue?["sessionId"]?.stringValue == "<session-1>")

        let prompt = try loadFixture("F3_prompt_answer_stream.json")
        #expect(clientMethods(in: prompt).contains("session/prompt"))
        #expect(sessionUpdates(in: prompt).contains("agent_message_chunk"))
        let promptResult = try responseResult(in: prompt, id: .int(3))
        #expect(promptResult.objectValue?["stopReason"] == .string("end_turn"))

        let permission = try loadFixture("F4_permission_tool_result.json")
        #expect(methods(in: permission).contains("session/request_permission"))
        #expect(sessionUpdates(in: permission).contains { $0 == "tool_call" || $0 == "tool_call_update" })
        #expect(permission.frames.contains { frame in
            frame.direction == .clientToGoose &&
                frame.body.objectValue?["result"]?.objectValue?["outcome"]?.objectValue?["outcome"] == .string("selected")
        })

        let custom = try loadFixture("F5_custom_readonly.json")
        #expect(clientMethods(in: custom) == [
            "_goose/unstable/providers/list",
            "_goose/unstable/config/extensions/list",
            "_goose/unstable/preferences/read",
            "_goose/unstable/defaults/read",
            "_goose/unstable/session/info",
            "_goose/unstable/diagnostics/get",
        ])
        #expect(responseResults(in: custom).count == 6)
    }

    @Test("fixture generator is pinned to local Goose serve and not WebView IPC emulation")
    func fixtureGeneratorUsesGooseServeACP() throws {
        let generator = try loadMirroredSourceTextFile("scripts/generate-goose-acp-fixtures.mjs")
        #expect(generator.contains("\"serve\", \"--host\", host, \"--port\", String(port)"))
        #expect(generator.contains("const acpURL = `ws://${host}:${port}/acp?token=${encodeURIComponent(secret)}`;"))
        #expect(!generator.contains("window.electron"))
        #expect(!generator.contains("ipcRenderer"))
    }

    private func loadFixture(_ name: String) throws -> GooseACPFixture {
        try decodeFixture(loadFixtureText(name))
    }

    private func loadFixtureText(_ name: String) throws -> String {
        try loadMirroredSourceTextFile("EpistemosTests/Fixtures/GooseACP/\(name)")
    }

    private func decodeFixture(_ text: String) throws -> GooseACPFixture {
        let data = try #require(text.data(using: .utf8))
        return try JSONDecoder().decode(GooseACPFixture.self, from: data)
    }

    private func decodeIncomingMessage(_ value: JSONValue) throws -> GooseACPIncomingMessage {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(GooseACPIncomingMessage.self, from: data)
    }

    private func methods(in fixture: GooseACPFixture) -> [String] {
        fixture.frames.compactMap { $0.body.objectValue?["method"]?.stringValue }
    }

    private func clientMethods(in fixture: GooseACPFixture) -> [String] {
        fixture.frames.compactMap { frame in
            guard frame.direction == .clientToGoose else { return nil }
            return frame.body.objectValue?["method"]?.stringValue
        }
    }

    private func sessionUpdates(in fixture: GooseACPFixture) -> [String] {
        fixture.frames.compactMap { frame in
            guard frame.direction == .gooseToClient,
                  frame.body.objectValue?["method"] == .string("session/update"),
                  let update = frame.body.objectValue?["params"]?.objectValue?["update"]?.objectValue else {
                return nil
            }
            return update["sessionUpdate"]?.stringValue ?? update["type"]?.stringValue
        }
    }

    private func responseResult(in fixture: GooseACPFixture, id: GooseACPRequestID) throws -> JSONValue {
        let results = responseResults(in: fixture).filter { $0.id == id }
        return try #require(results.first?.result)
    }

    private func responseResults(in fixture: GooseACPFixture) -> [(id: GooseACPRequestID, result: JSONValue)] {
        fixture.frames.compactMap { frame in
            guard frame.direction == .gooseToClient,
                  let idValue = frame.body.objectValue?["id"],
                  let result = frame.body.objectValue?["result"] else {
                return nil
            }
            guard let id = try? decodeRequestID(idValue) else { return nil }
            return (id, result)
        }
    }

    private func decodeRequestID(_ value: JSONValue) throws -> GooseACPRequestID {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(GooseACPRequestID.self, from: data)
    }
}

private struct GooseACPFixture: Decodable {
    let id: String
    let generator: String
    let frames: [GooseACPFixtureFrame]
}

private struct GooseACPFixtureFrame: Decodable {
    let direction: GooseACPFixtureFrameDirection
    let body: JSONValue
}

private enum GooseACPFixtureFrameDirection: String, Decodable {
    case clientToGoose = "client_to_goose"
    case gooseToClient = "goose_to_client"
}

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }

    var stringValue: String? {
        guard case .string(let string) = self else { return nil }
        return string
    }
}
