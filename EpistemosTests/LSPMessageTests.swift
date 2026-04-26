import Foundation
import Testing

@testable import Epistemos

/// Wave 9.8 source-guard for the LSP JSON-RPC 2.0 codec.
@Suite("LSPMessage codec (Wave 9.8 base)")
nonisolated struct LSPMessageTests {

    // MARK: - Request id

    @Test("LSPRequestId round-trips both string and int forms")
    func requestIdRoundTrips() throws {
        let stringJSON = "\"abc-1\"".data(using: .utf8)!
        let intJSON = "42".data(using: .utf8)!
        let s = try JSONDecoder.lspCanonical.decode(LSPRequestId.self, from: stringJSON)
        let i = try JSONDecoder.lspCanonical.decode(LSPRequestId.self, from: intJSON)
        #expect(s == .string("abc-1"))
        #expect(i == .int(42))

        let sBack = try JSONEncoder.lspCanonical.encode(LSPRequestId.string("abc-1"))
        let iBack = try JSONEncoder.lspCanonical.encode(LSPRequestId.int(42))
        #expect(String(data: sBack, encoding: .utf8) == "\"abc-1\"")
        #expect(String(data: iBack, encoding: .utf8) == "42")
    }

    // MARK: - Request

    @Test("Request encodes with jsonrpc + id + method + params")
    func requestEncodes() throws {
        let msg = LSPMessage.request(
            id: .int(1),
            method: "initialize",
            params: .object(["processId": .int(123)])
        )
        let data = try JSONEncoder.lspCanonical.encode(msg)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"jsonrpc\":\"2.0\""))
        #expect(json.contains("\"id\":1"))
        #expect(json.contains("\"method\":\"initialize\""))
        #expect(json.contains("\"params\""))
    }

    @Test("Request decodes via the typed envelope")
    func requestDecodes() throws {
        let json = #"{"jsonrpc":"2.0","id":7,"method":"textDocument/hover","params":{"x":1}}"#
            .data(using: .utf8)!
        let msg = try JSONDecoder.lspCanonical.decode(LSPMessage.self, from: json)
        switch msg {
        case .request(let id, let method, let params):
            #expect(id == .int(7))
            #expect(method == "textDocument/hover")
            #expect(params != nil)
        default:
            #expect(Bool(false), "expected .request; got \(msg)")
        }
    }

    // MARK: - Response

    @Test("Response success encodes with id + result (no method/error)")
    func responseSuccessEncodes() throws {
        let msg = LSPMessage.responseSuccess(
            id: .string("call-9"),
            result: .object(["capabilities": .object([:])])
        )
        let data = try JSONEncoder.lspCanonical.encode(msg)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"id\":\"call-9\""))
        #expect(json.contains("\"result\""))
        #expect(!json.contains("\"method\""), "success response MUST NOT carry method")
        #expect(!json.contains("\"error\""), "success response MUST NOT carry error")
    }

    @Test("Response success decodes")
    func responseSuccessDecodes() throws {
        let json = #"{"jsonrpc":"2.0","id":1,"result":{"hover":"text"}}"#
            .data(using: .utf8)!
        let msg = try JSONDecoder.lspCanonical.decode(LSPMessage.self, from: json)
        switch msg {
        case .responseSuccess(let id, let result):
            #expect(id == .int(1))
            switch result {
            case .object: break
            default: #expect(Bool(false), "result must be an object")
            }
        default:
            #expect(Bool(false), "expected .responseSuccess")
        }
    }

    @Test("Response error decodes the typed error envelope")
    func responseErrorDecodes() throws {
        let json = #"{"jsonrpc":"2.0","id":3,"error":{"code":-32601,"message":"method not found"}}"#
            .data(using: .utf8)!
        let msg = try JSONDecoder.lspCanonical.decode(LSPMessage.self, from: json)
        switch msg {
        case .responseError(let id, let error):
            #expect(id == .int(3))
            #expect(error.code == -32601)
            #expect(error.message == "method not found")
        default:
            #expect(Bool(false), "expected .responseError")
        }
    }

    // MARK: - Notification

    @Test("Notification decodes (method present, no id)")
    func notificationDecodes() throws {
        let json = #"{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"x":1}}"#
            .data(using: .utf8)!
        let msg = try JSONDecoder.lspCanonical.decode(LSPMessage.self, from: json)
        switch msg {
        case .notification(let method, let params):
            #expect(method == "textDocument/didChange")
            #expect(params != nil)
        default:
            #expect(Bool(false), "expected .notification; got \(msg)")
        }
    }

    @Test("Notification encodes without id")
    func notificationEncodes() throws {
        let msg = LSPMessage.notification(method: "$/cancelRequest", params: nil)
        let data = try JSONEncoder.lspCanonical.encode(msg)
        let json = String(data: data, encoding: .utf8) ?? ""
        // JSONEncoder escapes `/` to `\/` per the JSON spec — both
        // forms decode equivalently. Check the unescaped substring
        // is present then round-trip-decode to confirm semantics.
        #expect(json.contains("cancelRequest"))
        #expect(!json.contains("\"id\""), "notifications MUST NOT carry an id")
        let recovered = try JSONDecoder.lspCanonical.decode(LSPMessage.self, from: data)
        if case .notification(let method, _) = recovered {
            #expect(method == "$/cancelRequest")
        } else {
            #expect(Bool(false), "must round-trip as notification")
        }
    }

    // MARK: - Decode errors

    @Test("Decoding a body without method/result/error throws")
    func malformedBodyDecodeThrows() {
        let json = #"{"jsonrpc":"2.0"}"#.data(using: .utf8)!
        do {
            _ = try JSONDecoder.lspCanonical.decode(LSPMessage.self, from: json)
            #expect(Bool(false), "must throw on body without method/result/error")
        } catch {
            // expected
        }
    }

    // MARK: - Codec — encode

    @Test("encode prepends Content-Length header + \\r\\n\\r\\n separator")
    func encodeFramesWithContentLength() throws {
        let msg = LSPMessage.request(id: .int(1), method: "initialize", params: nil)
        let frame = try LSPMessageCodec.encode(msg)
        let asString = String(data: frame, encoding: .utf8) ?? ""
        #expect(asString.hasPrefix("Content-Length: "))
        #expect(asString.contains("\r\n\r\n"),
                "header section must be terminated by \\r\\n\\r\\n per LSP framing")

        // The byte count after the separator must equal the
        // declared Content-Length.
        let separatorRange = frame.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a]))!
        let bodyStart = separatorRange.upperBound
        let body = frame.subdata(in: bodyStart..<frame.count)
        let header = String(data: frame.subdata(in: 0..<separatorRange.lowerBound), encoding: .utf8) ?? ""
        let lengthLine = header.split(separator: "\r\n").first ?? ""
        let n = Int(lengthLine.replacingOccurrences(of: "Content-Length:", with: "").trimmingCharacters(in: .whitespaces)) ?? -1
        #expect(n == body.count,
                "Content-Length value MUST equal the body's byte count exactly")
    }

    // MARK: - Codec — decode

    @Test("decodeOne returns .needMoreData when header isn't complete")
    func decodeIncomplete() throws {
        let partial = "Content-Length: 100\r\n".data(using: .utf8)!
        let result = try LSPMessageCodec.decodeOne(buffer: partial)
        switch result {
        case .needMoreData: break
        default: #expect(Bool(false), "incomplete header must return .needMoreData")
        }
    }

    @Test("decodeOne returns .needMoreData when body is short")
    func decodeShortBody() throws {
        // Header says Content-Length: 99 but only 5 body bytes present.
        var buf = "Content-Length: 99\r\n\r\n".data(using: .utf8)!
        buf.append("short".data(using: .utf8)!)
        let result = try LSPMessageCodec.decodeOne(buffer: buf)
        switch result {
        case .needMoreData: break
        default: #expect(Bool(false), "short body must return .needMoreData")
        }
    }

    @Test("decodeOne returns the message + bytes consumed when frame is complete")
    func decodeCompleteFrame() throws {
        let body = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#
        let frame = "Content-Length: \(body.utf8.count)\r\n\r\n\(body)".data(using: .utf8)!
        let result = try LSPMessageCodec.decodeOne(buffer: frame)
        switch result {
        case .message(let msg, let consumed):
            switch msg {
            case .request(let id, let method, _):
                #expect(id == .int(1))
                #expect(method == "initialize")
            default:
                #expect(Bool(false), "expected .request")
            }
            #expect(consumed == frame.count,
                    "consumed bytes must equal full frame size for a single message")
        case .needMoreData:
            #expect(Bool(false), "complete frame must yield .message, not .needMoreData")
        }
    }

    @Test("decodeOne tolerates Content-Type header alongside Content-Length")
    func decodeAcceptsContentTypeHeader() throws {
        let body = #"{"jsonrpc":"2.0","method":"x"}"#
        let frame = "Content-Length: \(body.utf8.count)\r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n\(body)"
            .data(using: .utf8)!
        let result = try LSPMessageCodec.decodeOne(buffer: frame)
        if case .message = result {} else {
            #expect(Bool(false), "must accept frames carrying Content-Type alongside Content-Length")
        }
    }

    @Test("decodeOne throws on unknown header")
    func decodeUnknownHeaderThrows() {
        let body = "{}"
        let frame = "Content-Length: \(body.utf8.count)\r\nWeird-Header: nope\r\n\r\n\(body)"
            .data(using: .utf8)!
        do {
            _ = try LSPMessageCodec.decodeOne(buffer: frame)
            #expect(Bool(false), "unknown header must throw")
        } catch let LSPMessageCodec.DecodeError.unknownHeader(name) {
            #expect(name == "weird-header")
        } catch {
            #expect(Bool(false), "wrong error: \(error)")
        }
    }

    @Test("decodeOne throws on missing Content-Length header")
    func decodeMissingContentLength() {
        let body = "{}"
        let frame = "Content-Type: application/vscode-jsonrpc\r\n\r\n\(body)"
            .data(using: .utf8)!
        do {
            _ = try LSPMessageCodec.decodeOne(buffer: frame)
            #expect(Bool(false), "missing Content-Length must throw")
        } catch LSPMessageCodec.DecodeError.missingContentLength {
            // expected
        } catch {
            #expect(Bool(false), "wrong error: \(error)")
        }
    }

    // MARK: - Encode + decode round-trip

    @Test("encode → decode round-trips every message variant")
    func roundTripEveryVariant() throws {
        let messages: [LSPMessage] = [
            .request(id: .int(1), method: "initialize", params: .object(["pid": .int(99)])),
            .responseSuccess(id: .string("abc"), result: .array([.int(1), .int(2)])),
            .responseError(id: .int(2), error: LSPError(code: -32601, message: "no method")),
            .notification(method: "textDocument/didChange", params: nil),
        ]
        for msg in messages {
            let frame = try LSPMessageCodec.encode(msg)
            let result = try LSPMessageCodec.decodeOne(buffer: frame)
            switch result {
            case .message(let recovered, _):
                switch (msg, recovered) {
                case (.request, .request),
                     (.responseSuccess, .responseSuccess),
                     (.responseError, .responseError),
                     (.notification, .notification):
                    break
                default:
                    #expect(Bool(false), "round-trip kind mismatch: \(msg) → \(recovered)")
                }
            default:
                #expect(Bool(false), "round-trip must yield .message")
            }
        }
    }
}
