import Foundation

nonisolated enum GooseACPSourceType: String, Codable, Equatable, Sendable {
    case skill
    case builtinSkill
    case recipe
    case subrecipe
    case agent
    case project
    /// Forward-compat (review L2): a source type a future goose adds that this build does not model
    /// yet. `GooseACPSourceEntry` maps any unrecognized wire value to this case so one new type can
    /// never throw the WHOLE `sources/list` decode. Never sent by Epistemos.
    case unknown
}

nonisolated enum GooseACPSourceScope: Encodable, Equatable, Sendable {
    case global
    case projectDir(String)
    case projectId(String)

    private enum CodingKeys: String, CodingKey {
        case scope
        case projectDir
        case projectId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .global:
            try container.encode("global", forKey: .scope)
        case .projectDir(let projectDir):
            try container.encode("projectDir", forKey: .scope)
            try container.encode(projectDir, forKey: .projectDir)
        case .projectId(let projectId):
            try container.encode("projectId", forKey: .scope)
            try container.encode(projectId, forKey: .projectId)
        }
    }
}

nonisolated struct GooseACPSourcesListRequest: Encodable, Equatable, Sendable {
    let sourceType: GooseACPSourceType?
    let projectDir: String?
    let includeProjectSources: Bool?

    init(
        type: GooseACPSourceType? = nil,
        projectDir: String? = nil,
        includeProjectSources: Bool? = nil
    ) {
        sourceType = type
        self.projectDir = projectDir
        self.includeProjectSources = includeProjectSources
    }

    private enum CodingKeys: String, CodingKey {
        case sourceType = "type"
        case projectDir
        case includeProjectSources
    }
}

nonisolated struct GooseACPSourceEntry: Decodable, Equatable, Sendable {
    let sourceType: GooseACPSourceType
    let name: String
    let description: String
    let content: String
    let path: String
    let global: Bool
    let writable: Bool
    let supportingFiles: [String]
    let properties: [String: JSONValue]

    private enum CodingKeys: String, CodingKey {
        case sourceType = "type"
        case name
        case description
        case content
        case path
        case global
        case writable
        case supportingFiles
        case properties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // review L2: decode leniently — an unrecognized source type maps to `.unknown` instead of
        // throwing and blanking the entire sources/list (skills/recipes surface). Mirrors the
        // per-element resilience used for provider-inventory models.
        let rawSourceType = try container.decode(String.self, forKey: .sourceType)
        sourceType = GooseACPSourceType(rawValue: rawSourceType) ?? .unknown
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        content = try container.decode(String.self, forKey: .content)
        path = try container.decode(String.self, forKey: .path)
        global = try container.decode(Bool.self, forKey: .global)
        writable = try container.decodeIfPresent(Bool.self, forKey: .writable) ?? false
        supportingFiles = try container.decodeIfPresent([String].self, forKey: .supportingFiles) ?? []
        properties = try container.decodeIfPresent([String: JSONValue].self, forKey: .properties) ?? [:]
    }
}

nonisolated struct GooseACPSourcesListResponse: Decodable, Equatable, Sendable {
    let sources: [GooseACPSourceEntry]
}

nonisolated struct GooseACPSourceCreateRequest: Encodable, Equatable, Sendable {
    let sourceType: GooseACPSourceType
    let name: String
    let description: String
    let content: String
    let target: GooseACPSourceScope
    let properties: [String: JSONValue]?

    init(
        type: GooseACPSourceType,
        name: String,
        description: String,
        content: String,
        target: GooseACPSourceScope,
        properties: [String: JSONValue]? = nil
    ) {
        sourceType = type
        self.name = name
        self.description = description
        self.content = content
        self.target = target
        self.properties = properties
    }

    private enum CodingKeys: String, CodingKey {
        case sourceType = "type"
        case name
        case description
        case content
        case target
        case properties
    }
}

nonisolated struct GooseACPSourceUpdateRequest: Encodable, Equatable, Sendable {
    let sourceType: GooseACPSourceType
    let path: String
    let name: String
    let description: String
    let content: String
    let properties: [String: JSONValue]?

    init(
        type: GooseACPSourceType,
        path: String,
        name: String,
        description: String,
        content: String,
        properties: [String: JSONValue]? = nil
    ) {
        sourceType = type
        self.path = path
        self.name = name
        self.description = description
        self.content = content
        self.properties = properties
    }

    private enum CodingKeys: String, CodingKey {
        case sourceType = "type"
        case path
        case name
        case description
        case content
        case properties
    }
}

nonisolated struct GooseACPSourceDeleteRequest: Encodable, Equatable, Sendable {
    let sourceType: GooseACPSourceType
    let path: String

    init(type: GooseACPSourceType, path: String) {
        sourceType = type
        self.path = path
    }

    private enum CodingKeys: String, CodingKey {
        case sourceType = "type"
        case path
    }
}

nonisolated struct GooseACPSourceExportRequest: Encodable, Equatable, Sendable {
    let sourceType: GooseACPSourceType
    let path: String

    init(type: GooseACPSourceType, path: String) {
        sourceType = type
        self.path = path
    }

    private enum CodingKeys: String, CodingKey {
        case sourceType = "type"
        case path
    }
}

nonisolated struct GooseACPSourceExportResponse: Decodable, Equatable, Sendable {
    let json: String
    let filename: String
}

nonisolated struct GooseACPSourceResponse: Decodable, Equatable, Sendable {
    let source: GooseACPSourceEntry
}

nonisolated struct GooseACPSourcesImportRequest: Encodable, Equatable, Sendable {
    let data: String
    let target: GooseACPSourceScope
}

nonisolated struct GooseACPSourcesImportResponse: Decodable, Equatable, Sendable {
    let sources: [GooseACPSourceEntry]
}
