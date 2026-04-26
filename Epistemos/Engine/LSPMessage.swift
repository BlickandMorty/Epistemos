import Foundation

// MARK: - LSPMessage
//
// Wave 9.8 base of the Extended Program Plan
// (cross-ref `epistemos_code_verdict.md` §3 "Intelligence" layer:
//  SourceKit-LSP / clangd is the actual truth about the code).
//
// Pure data + codec for LSP JSON-RPC 2.0 messages over stdio. The
// LSP transport framing is exactly the HTTP-style header:
//
//     Content-Length: <byte-count>\r\n
//     [optional headers]\r\n
//     \r\n
//     <body bytes>
//
// The body is a JSON-RPC 2.0 envelope:
//   - Request:      {"jsonrpc":"2.0","id":...,"method":"...","params":...}
//   - Response:     {"jsonrpc":"2.0","id":...,"result":...}
//                   or {"jsonrpc":"2.0","id":...,"error":{...}}
//   - Notification: {"jsonrpc":"2.0","method":"...","params":...}     (no id)
//
// W9.8 base ships:
//   - LSPMessage typed enum (.request/.response/.notification)
//   - LSPMessageCodec — encode + decode (header-framed buffer)
//   - LSPRequestId (string OR int per the JSON-RPC spec)
//   - LSPError (typed error envelope with code + message + data)
//
// W9.8 follow-up wires this codec to a real Subprocess running
// `xcrun sourcekit-lsp`. The codec itself is ready today.

// MARK: - Request id

/// JSON-RPC 2.0 request id. The spec allows string OR integer; LSP
/// servers echo whatever you send. Stored as the union so we can
/// round-trip both forms without losing the original.
nonisolated public enum LSPRequestId: Codable, Sendable, Hashable {
    case string(String)
    case int(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else {
            throw DecodingError.typeMismatch(
                LSPRequestId.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "id must be string or integer per JSON-RPC 2.0"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i):    try container.encode(i)
        }
    }
}

// MARK: - Error envelope

/// LSP error per the JSON-RPC 2.0 + LSP `ResponseError` shape.
nonisolated public struct LSPError: Codable, Sendable, Hashable {
    public let code: Int
    public let message: String
    /// Optional structured payload — the LSP spec allows arbitrary JSON.
    /// We preserve it as a `Data` blob so callers that want to decode
    /// it into a typed schema can; round-trips byte-equal otherwise.
    public let data: Data?

    public init(code: Int, message: String, data: Data? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try c.decode(Int.self, forKey: .code)
        self.message = try c.decode(String.self, forKey: .message)
        if let raw = try? c.decode(LSPJSONValue.self, forKey: .data) {
            self.data = try? JSONEncoder().encode(raw)
        } else {
            self.data = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(code, forKey: .code)
        try c.encode(message, forKey: .message)
        if let data {
            if let value = try? JSONDecoder().decode(LSPJSONValue.self, from: data) {
                try c.encode(value, forKey: .data)
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case code, message, data
    }
}

// MARK: - Loosely-typed JSON value

/// Tiny JSON-value type so we can pass-through arbitrary `params` /
/// `result` payloads without forcing a typed schema. Avoids dragging
/// in a heavyweight JSON library.
nonisolated public enum LSPJSONValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([LSPJSONValue])
    case object([String: LSPJSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([LSPJSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: LSPJSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.typeMismatch(
                LSPJSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "value not encodable as LSPJSONValue"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:           try c.encodeNil()
        case .bool(let b):    try c.encode(b)
        case .int(let i):     try c.encode(i)
        case .double(let d):  try c.encode(d)
        case .string(let s):  try c.encode(s)
        case .array(let a):   try c.encode(a)
        case .object(let o):  try c.encode(o)
        }
    }
}

// MARK: - Message envelope

/// Typed LSP message. Each variant captures exactly the fields the
/// JSON-RPC 2.0 wire shape requires for that kind.
nonisolated public enum LSPMessage: Codable, Sendable, Hashable {
    case request(id: LSPRequestId, method: String, params: LSPJSONValue?)
    case responseSuccess(id: LSPRequestId, result: LSPJSONValue)
    case responseError(id: LSPRequestId?, error: LSPError)
    case notification(method: String, params: LSPJSONValue?)

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case method
        case params
        case result
        case error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try? c.decodeIfPresent(LSPRequestId.self, forKey: .id)
        let method = try? c.decodeIfPresent(String.self, forKey: .method)
        let params = try? c.decodeIfPresent(LSPJSONValue.self, forKey: .params)
        let result = try? c.decodeIfPresent(LSPJSONValue.self, forKey: .result)
        let error = try? c.decodeIfPresent(LSPError.self, forKey: .error)

        if let error {
            self = .responseError(id: id, error: error)
        } else if let result {
            guard let id else {
                throw DecodingError.dataCorruptedError(
                    forKey: .id,
                    in: c,
                    debugDescription: "JSON-RPC response with `result` MUST carry an `id`"
                )
            }
            self = .responseSuccess(id: id, result: result)
        } else if let method {
            if let id {
                self = .request(id: id, method: method, params: params)
            } else {
                self = .notification(method: method, params: params)
            }
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .method,
                in: c,
                debugDescription: "JSON-RPC body must carry method, result, or error"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("2.0", forKey: .jsonrpc)
        switch self {
        case .request(let id, let method, let params):
            try c.encode(id, forKey: .id)
            try c.encode(method, forKey: .method)
            if let params { try c.encode(params, forKey: .params) }
        case .responseSuccess(let id, let result):
            try c.encode(id, forKey: .id)
            try c.encode(result, forKey: .result)
        case .responseError(let id, let error):
            if let id { try c.encode(id, forKey: .id) } else {
                try c.encodeNil(forKey: .id)
            }
            try c.encode(error, forKey: .error)
        case .notification(let method, let params):
            try c.encode(method, forKey: .method)
            if let params { try c.encode(params, forKey: .params) }
        }
    }
}

// MARK: - Codec (header framing)

/// Encode + decode LSP messages over the standard Content-Length
/// header framing used by SourceKit-LSP / clangd / rust-analyzer.
nonisolated public enum LSPMessageCodec {

    /// Encode one outgoing message: JSON-encode body + prepend the
    /// canonical `Content-Length: <n>\r\n\r\n` header. Returns the
    /// full byte block ready to be written to the LSP stdin.
    public static func encode(_ message: LSPMessage, encoder: JSONEncoder = .lspCanonical) throws -> Data {
        let body = try encoder.encode(message)
        var header = Data()
        header.append("Content-Length: \(body.count)\r\n\r\n".data(using: .utf8)!)
        header.append(body)
        return header
    }

    /// Errors the streaming decoder can raise.
    public enum DecodeError: Error, Equatable {
        case malformedHeader
        case unknownHeader(String)
        case missingContentLength
        case bodyTooShort
    }

    /// Decode result of a single decode pass: either a complete
    /// message + the number of bytes consumed, or `.needMoreData` to
    /// signal the caller to buffer more bytes before retrying.
    public enum DecodeResult: Sendable {
        case message(LSPMessage, consumed: Int)
        case needMoreData
    }

    /// Try to decode a single message from the front of `buffer`. The
    /// caller maintains the buffer (typically a `Data` ring or
    /// growing slice) and slides off `consumed` bytes after a
    /// successful pass. `.needMoreData` means leave the buffer alone
    /// and append more bytes from the LSP server's stdout stream.
    public static func decodeOne(buffer: Data, decoder: JSONDecoder = .lspCanonical) throws -> DecodeResult {
        guard let headerEnd = findHeaderTerminator(in: buffer) else {
            return .needMoreData
        }
        let headerData = buffer.prefix(headerEnd)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw DecodeError.malformedHeader
        }
        var contentLength: Int?
        for line in headerString.split(separator: "\r\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                throw DecodeError.malformedHeader
            }
            let name = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch name {
            case "content-length":
                guard let n = Int(value) else {
                    throw DecodeError.malformedHeader
                }
                contentLength = n
            case "content-type":
                // LSP defines content-type but the only canonical value
                // is `application/vscode-jsonrpc; charset=utf-8`. We
                // tolerate it without validation.
                continue
            default:
                throw DecodeError.unknownHeader(name)
            }
        }
        guard let len = contentLength else {
            throw DecodeError.missingContentLength
        }
        let bodyStart = headerEnd + 4   // skip the trailing \r\n\r\n
        let bodyEnd = bodyStart + len
        if buffer.count < bodyEnd {
            return .needMoreData
        }
        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        let message = try decoder.decode(LSPMessage.self, from: body)
        return .message(message, consumed: bodyEnd)
    }

    /// Find the index where `\r\n\r\n` ends in the buffer. Returns
    /// the index of the FIRST `\r` so `prefix(index)` is the header
    /// bytes only.
    private static func findHeaderTerminator(in buffer: Data) -> Int? {
        let needle: [UInt8] = [0x0d, 0x0a, 0x0d, 0x0a]
        guard buffer.count >= needle.count else { return nil }
        for i in 0...(buffer.count - needle.count) {
            if buffer[i] == needle[0] && buffer[i + 1] == needle[1] && buffer[i + 2] == needle[2] && buffer[i + 3] == needle[3] {
                return i
            }
        }
        return nil
    }
}

// MARK: - Default encoder/decoder

public extension JSONEncoder {
    /// Canonical encoder for LSP wire messages: compact (no extra
    /// whitespace) so the Content-Length header reflects the smallest
    /// possible body. Sorted keys keeps the wire format diff-friendly.
    nonisolated static var lspCanonical: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    /// Canonical decoder. Tolerates extra fields per LSP forward-
    /// compatibility rules.
    nonisolated static var lspCanonical: JSONDecoder {
        JSONDecoder()
    }
}
