import Foundation

// DATA + FINETUNE substrate, part (5) MARKETPLACE (owner 2026-06-18): "a
// marketplace for data and fine-tuning packs … browse/import/apply/share, each
// {id, kind, source, license, gate}, ProvenanceGate, MAS-safe (no runtime
// Python)." A FineTunePack is a typed marketplace DESCRIPTOR — never runtime code
// — so the registry is MAS-safe. Importing/applying a pack is a separate, gated
// step: a LoRA pack reuses the existing AdapterExporter (.epistemos-adapter
// bundle round-trip); a dataset/instruction/knowledge pack feeds the native
// training-data / vault path. Pure, always-compiled, unit-tested.

/// What a marketplace pack contains.
enum FineTunePackKind: String, Codable, Sendable, CaseIterable {
    case dataset          // training data (chat JSONL the native trainer consumes)
    case loraAdapter      // a trained LoRA adapter (.epistemos-adapter bundle)
    case instructionPack  // a system-prompt / instruction set
    case knowledgePack    // a compiled knowledge vault

    var displayName: String {
        switch self {
        case .dataset: "Dataset"
        case .loraAdapter: "LoRA adapter"
        case .instructionPack: "Instruction pack"
        case .knowledgePack: "Knowledge pack"
        }
    }
}

/// Where a pack comes from — a descriptor (repo/URL), never executable. MAS-safe.
enum FineTunePackSource: Codable, Sendable, Equatable {
    case huggingFace(repo: String)
    case gitHub(repo: String)
    case localFile(URL)
    case remoteURL(URL)

    var displayName: String {
        switch self {
        case .huggingFace(let repo): "Hugging Face · \(repo)"
        case .gitHub(let repo): "GitHub · \(repo)"
        case .localFile(let url): "Local · \(url.lastPathComponent)"
        case .remoteURL(let url): "URL · \(url.host ?? url.absoluteString)"
        }
    }
}

/// Honest availability gate (mirrors the deployment-profile gating). A pack never
/// appears where it can't honestly run.
enum FineTunePackGate: String, Codable, Sendable, CaseIterable {
    case free   // available in every build (MAS + Pro)
    case pro    // Pro / direct release only
    case dev    // dev-cert only

    var displayName: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro"
        case .dev: "Dev"
        }
    }
}

struct FineTunePack: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let kind: FineTunePackKind
    let displayName: String
    let source: FineTunePackSource
    /// License name (e.g. "MIT", "Apache-2.0", "LFM1.0"). REQUIRED — the registry
    /// rejects an unlicensed pack (ProvenanceGate: no license → no entry).
    let license: String
    let gate: FineTunePackGate
    var sizeBytes: Int?
    /// ProvenanceGate posture / origin note (e.g. "direct_import", "research_only").
    var provenance: String

    init(
        id: String,
        kind: FineTunePackKind,
        displayName: String,
        source: FineTunePackSource,
        license: String,
        gate: FineTunePackGate,
        sizeBytes: Int? = nil,
        provenance: String = "unverified"
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.source = source
        self.license = license
        self.gate = gate
        self.sizeBytes = sizeBytes
        self.provenance = provenance
    }
}
