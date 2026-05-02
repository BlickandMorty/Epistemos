import Foundation

@_silgen_name("oplog_open_at")
nonisolated private func oplog_open_at(
    _ path: UnsafePointer<CChar>?,
    _ actorID: UnsafePointer<CChar>?
) -> UnsafePointer<UInt8>?

@_silgen_name("oplog_iter_after_json")
nonisolated private func oplog_iter_after_json(
    _ handle: UnsafePointer<UInt8>?,
    _ afterSeq: UInt64,
    _ outError: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("oplog_iter_all_json")
nonisolated private func oplog_iter_all_json(
    _ handle: UnsafePointer<UInt8>?,
    _ outError: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("oplog_append_payload_json")
nonisolated private func oplog_append_payload_json(
    _ handle: UnsafePointer<UInt8>?,
    _ payloadJSON: UnsafePointer<CChar>?,
    _ outSeq: UnsafeMutablePointer<UInt64>?,
    _ outError: UnsafeMutablePointer<Int32>?
) -> Int32

@_silgen_name("oplog_chain_tip_hex")
nonisolated private func oplog_chain_tip_hex(
    _ handle: UnsafePointer<UInt8>?,
    _ outError: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("oplog_verify_chain_json")
nonisolated private func oplog_verify_chain_json(
    _ handle: UnsafePointer<UInt8>?,
    _ expectedTipHex: UnsafePointer<CChar>?,
    _ outError: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("oplog_release")
nonisolated private func oplog_release(
    _ handle: UnsafePointer<UInt8>?
)

@_silgen_name("oplog_free_string")
nonisolated private func oplog_free_string(
    _ ptr: UnsafeMutablePointer<CChar>?
)

nonisolated enum RustOpLogFFIError: Error, Equatable, LocalizedError {
    case openFailed(path: String)
    case appendFailed(code: Int32, outError: Int32)
    case chainTipFailed(code: Int32)
    case chainVerificationFailed(code: Int32)
    case iterateFailed(code: Int32)
    case stringEncodingFailed(context: String)
    case decodingFailed(context: String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let path):
            return "oplog_open_at returned null for \(path)"
        case .appendFailed(let code, let outError):
            return "oplog_append_payload_json failed with code \(code), out_error \(outError)"
        case .chainTipFailed(let code):
            return "oplog_chain_tip_hex failed with code \(code)"
        case .chainVerificationFailed(let code):
            return "oplog_verify_chain_json failed with code \(code)"
        case .iterateFailed(let code):
            return "oplog_iter_after_json failed with code \(code)"
        case .stringEncodingFailed(let context):
            return "Rust OpLog string encoding failed: \(context)"
        case .decodingFailed(let context):
            return "Rust OpLog JSON decode failed: \(context)"
        }
    }
}

nonisolated struct OpLogChainVerificationReport: Codable, Equatable, Sendable {
    let valid: Bool
    let checkedCount: Int
    let computedChainTipHex: String
    let storedChainTipHex: String
    let expectedChainTipHex: String?
    let firstBadSeq: UInt64?
    let failureReason: String?

    enum CodingKeys: String, CodingKey {
        case valid
        case checkedCount = "checked_count"
        case computedChainTipHex = "computed_chain_tip_hex"
        case storedChainTipHex = "stored_chain_tip_hex"
        case expectedChainTipHex = "expected_chain_tip_hex"
        case firstBadSeq = "first_bad_seq"
        case failureReason = "failure_reason"
    }
}

nonisolated struct OpLogEntry: Codable, Equatable, Sendable {
    let seq: UInt64
    let lamport: UInt64
    let actorID: String
    let tsUnixMs: Int64
    let payload: OpLogPayload
    let prevHash: String

    enum CodingKeys: String, CodingKey {
        case seq
        case lamport
        case actorID = "actor_id"
        case tsUnixMs = "ts_unix_ms"
        case payload
        case prevHash = "prev_hash"
    }
}

nonisolated enum OpLogJSONValue: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([OpLogJSONValue])
    case object([String: OpLogJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([OpLogJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: OpLogJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode OpLogJSONValue"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

nonisolated enum OpLogPayload: Codable, Equatable, Sendable {
    case nodeAdd(id: String, kind: String, title: String)
    case nodeUpdate(id: String, title: String?)
    case nodeRemove(id: String)
    case edgeAdd(from: String, to: String, label: String?)
    case edgeRemove(from: String, to: String)
    case propSet(nodeID: String, key: String, value: OpLogJSONValue)

    var projectionMutationID: String? {
        guard case .propSet(let nodeID, let key, let value) = self,
              key == Self.mutationProjectionKey else {
            return nil
        }
        if case .object(let fields) = value,
           let rawMutationID = fields["mutation_id"],
           case .string(let mutationID) = rawMutationID {
            return mutationID
        }
        return nodeID
    }

    private static let mutationProjectionKey = "mutation_projection"

    private enum CodingKeys: String, CodingKey {
        case opType = "op_type"
        case id
        case kind
        case title
        case from
        case to
        case label
        case nodeID = "node_id"
        case key
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let opType = try container.decode(String.self, forKey: .opType)
        switch opType {
        case "node_add":
            self = try .nodeAdd(
                id: container.decode(String.self, forKey: .id),
                kind: container.decode(String.self, forKey: .kind),
                title: container.decode(String.self, forKey: .title)
            )
        case "node_update":
            self = try .nodeUpdate(
                id: container.decode(String.self, forKey: .id),
                title: container.decodeIfPresent(String.self, forKey: .title)
            )
        case "node_remove":
            self = try .nodeRemove(id: container.decode(String.self, forKey: .id))
        case "edge_add":
            self = try .edgeAdd(
                from: container.decode(String.self, forKey: .from),
                to: container.decode(String.self, forKey: .to),
                label: container.decodeIfPresent(String.self, forKey: .label)
            )
        case "edge_remove":
            self = try .edgeRemove(
                from: container.decode(String.self, forKey: .from),
                to: container.decode(String.self, forKey: .to)
            )
        case "prop_set":
            self = try .propSet(
                nodeID: container.decode(String.self, forKey: .nodeID),
                key: container.decode(String.self, forKey: .key),
                value: container.decode(OpLogJSONValue.self, forKey: .value)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .opType,
                in: container,
                debugDescription: "unknown OpLog payload op_type \(opType)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .nodeAdd(let id, let kind, let title):
            try container.encode("node_add", forKey: .opType)
            try container.encode(id, forKey: .id)
            try container.encode(kind, forKey: .kind)
            try container.encode(title, forKey: .title)
        case .nodeUpdate(let id, let title):
            try container.encode("node_update", forKey: .opType)
            try container.encode(id, forKey: .id)
            try container.encodeIfPresent(title, forKey: .title)
        case .nodeRemove(let id):
            try container.encode("node_remove", forKey: .opType)
            try container.encode(id, forKey: .id)
        case .edgeAdd(let from, let to, let label):
            try container.encode("edge_add", forKey: .opType)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
            try container.encodeIfPresent(label, forKey: .label)
        case .edgeRemove(let from, let to):
            try container.encode("edge_remove", forKey: .opType)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
        case .propSet(let nodeID, let key, let value):
            try container.encode("prop_set", forKey: .opType)
            try container.encode(nodeID, forKey: .nodeID)
            try container.encode(key, forKey: .key)
            try container.encode(value, forKey: .value)
        }
    }
}

/// Narrow owner for the Rust OpLog C ABI. Production scheduling goes through
/// `MutationOpLogProjectionWorker`; raw ABI symbols remain private to this file.
nonisolated final class RustOpLogFFIClient: @unchecked Sendable {
    private let handle: UnsafePointer<UInt8>

    /// `actorID` is used for future appends; existing persisted rows keep
    /// their original actor IDs when a database is reopened.
    init(databaseURL: URL, actorID: String) throws {
        let raw = databaseURL.path.withCString { pathPtr in
            actorID.withCString { actorPtr in
                oplog_open_at(pathPtr, actorPtr)
            }
        }
        guard let raw else {
            throw RustOpLogFFIError.openFailed(path: databaseURL.path)
        }
        handle = raw
    }

    deinit {
        oplog_release(handle)
    }

    func append(_ payload: OpLogPayload) throws -> UInt64 {
        let data = try Self.encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw RustOpLogFFIError.stringEncodingFailed(context: "payload")
        }

        var errorCode: Int32 = 0
        var seq: UInt64 = 0
        let code = json.withCString { ptr in
            oplog_append_payload_json(handle, ptr, &seq, &errorCode)
        }
        guard code == 0, errorCode == 0 else {
            throw RustOpLogFFIError.appendFailed(code: code, outError: errorCode)
        }
        return seq
    }

    func chainTipHex() throws -> String {
        var errorCode: Int32 = 0
        guard let raw = oplog_chain_tip_hex(handle, &errorCode) else {
            throw RustOpLogFFIError.chainTipFailed(code: errorCode)
        }
        defer { oplog_free_string(raw) }
        guard let value = String(validatingCString: raw) else {
            throw RustOpLogFFIError.stringEncodingFailed(context: "chain_tip")
        }
        return value
    }

    func verifyChain(expectedTipHex: String? = nil) throws -> OpLogChainVerificationReport {
        var errorCode: Int32 = 0
        let raw: UnsafeMutablePointer<CChar>?
        if let expectedTipHex {
            raw = expectedTipHex.withCString { ptr in
                oplog_verify_chain_json(handle, ptr, &errorCode)
            }
        } else {
            raw = oplog_verify_chain_json(handle, nil, &errorCode)
        }

        guard let raw else {
            throw RustOpLogFFIError.chainVerificationFailed(code: errorCode)
        }
        defer { oplog_free_string(raw) }
        guard let json = String(validatingCString: raw),
              let data = json.data(using: .utf8) else {
            throw RustOpLogFFIError.stringEncodingFailed(context: "chain_verification")
        }
        do {
            return try Self.decoder.decode(OpLogChainVerificationReport.self, from: data)
        } catch {
            throw RustOpLogFFIError.decodingFailed(context: error.localizedDescription)
        }
    }

    func iterate(after seq: UInt64) throws -> [OpLogEntry] {
        var errorCode: Int32 = 0
        guard let raw = oplog_iter_after_json(handle, seq, &errorCode) else {
            throw RustOpLogFFIError.iterateFailed(code: errorCode)
        }
        defer { oplog_free_string(raw) }
        return try Self.decodeEntries(from: raw, context: "iter_after")
    }

    func iterateAll() throws -> [OpLogEntry] {
        var errorCode: Int32 = 0
        guard let raw = oplog_iter_all_json(handle, &errorCode) else {
            throw RustOpLogFFIError.iterateFailed(code: errorCode)
        }
        defer { oplog_free_string(raw) }
        return try Self.decodeEntries(from: raw, context: "iter_all")
    }

    private static func decodeEntries(
        from raw: UnsafeMutablePointer<CChar>,
        context: String
    ) throws -> [OpLogEntry] {
        guard let json = String(validatingCString: raw),
              let data = json.data(using: .utf8) else {
            throw RustOpLogFFIError.stringEncodingFailed(context: context)
        }
        do {
            return try Self.decoder.decode([OpLogEntry].self, from: data)
        } catch {
            throw RustOpLogFFIError.decodingFailed(context: error.localizedDescription)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }()

    private static let decoder = JSONDecoder()
}
