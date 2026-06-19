import Foundation

// DATA + FINETUNE part (5) MARKETPLACE — the IMPORT verb (owner: "browse/import/
// apply/share"). Parses a user-supplied pack SOURCE (a Hugging Face repo, a GitHub
// repo, or a URL) into a typed `FineTunePackSource`, applies the ProvenanceGate (a
// license is REQUIRED — no license, no entry), and builds a validated `FineTunePack`
// DESCRIPTOR ready for `FineTunePackRegistry.add(_:)`. MAS-safe: this NEVER fetches or
// runs anything — pulling the pack's bytes is the gated on-device follow-on. Pure +
// unit-tested.

enum FineTunePackImportError: Error, LocalizedError, Equatable {
    case emptySpec
    case unrecognizedSource(String)
    case emptyName
    case missingLicense

    var errorDescription: String? {
        switch self {
        case .emptySpec:
            "Enter a pack source (a Hugging Face repo, a GitHub repo, or a URL)."
        case .unrecognizedSource(let spec):
            "Unrecognized source \"\(spec)\". Use owner/name, huggingface.co/…, github.com/…, or an http(s)/file URL."
        case .emptyName:
            "Give the pack a name."
        case .missingLicense:
            "A license is required — the ProvenanceGate rejects unlicensed packs."
        }
    }
}

enum FineTunePackImporter {

    /// Parse a source spec into a typed `FineTunePackSource` — honest: recognized
    /// hosts only (returns nil for anything it can't map). A bare `owner/name` defaults
    /// to Hugging Face (the common case for model/adapter/dataset repos).
    static func parseSource(_ rawSpec: String) -> FineTunePackSource? {
        let spec = rawSpec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spec.isEmpty else { return nil }
        let lower = spec.lowercased()

        if let repo = repoComponent(in: spec, host: "huggingface.co") {
            return .huggingFace(repo: repo)
        }
        if let repo = repoComponent(in: spec, host: "github.com") {
            return .gitHub(repo: repo)
        }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: spec).map { .remoteURL($0) }
        }
        if lower.hasPrefix("file://") {
            return URL(string: spec).map { .localFile($0) }
        }
        if spec.hasPrefix("/") {
            return .localFile(URL(fileURLWithPath: spec))
        }
        if isBareRepo(spec) {
            return .huggingFace(repo: spec)
        }
        return nil
    }

    /// Build a validated, ProvenanceGate-clean `FineTunePack` descriptor from an import
    /// request. Does NOT fetch bytes — that's the on-device follow-on. The returned
    /// pack is ready to hand to `FineTunePackRegistry.add(_:)` (which re-checks the
    /// license + dedups). Throws an honest error on an empty/unrecognized source, a
    /// missing name, or (ProvenanceGate) a missing license.
    static func makePack(
        spec: String,
        kind: FineTunePackKind,
        displayName: String,
        license: String,
        gate: FineTunePackGate
    ) throws -> FineTunePack {
        let trimmedSpec = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSpec.isEmpty else { throw FineTunePackImportError.emptySpec }
        guard let source = parseSource(trimmedSpec) else {
            throw FineTunePackImportError.unrecognizedSource(trimmedSpec)
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw FineTunePackImportError.emptyName }
        // ProvenanceGate: an imported pack MUST declare a license (no license → no entry).
        let lic = license.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lic.isEmpty else { throw FineTunePackImportError.missingLicense }

        return FineTunePack(
            id: importedID(for: source),
            kind: kind,
            displayName: name,
            source: source,
            license: lic,
            gate: gate,
            provenance: "imported · ProvenanceGate(license: \(lic))"
        )
    }

    // MARK: - Helpers

    /// Extract `owner/name` from a `<host>/owner/name[/…]` spec (with or without scheme).
    private static func repoComponent(in spec: String, host: String) -> String? {
        let lower = spec.lowercased()
        guard let hostRange = lower.range(of: host + "/") else { return nil }
        let after = spec[hostRange.upperBound...]
        let parts = after.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])/\(parts[1])"
    }

    /// A bare `owner/name` (exactly one slash, no scheme/space, no leading slash).
    private static func isBareRepo(_ spec: String) -> Bool {
        guard !spec.contains(" "), !spec.contains("://"), !spec.hasPrefix("/") else { return false }
        let parts = spec.split(separator: "/", omittingEmptySubsequences: true)
        return parts.count == 2
    }

    /// Deterministic, namespaced id so re-importing the same source dedups in the registry.
    private static func importedID(for source: FineTunePackSource) -> String {
        switch source {
        case .huggingFace(let repo): "import.hf.\(slug(repo))"
        case .gitHub(let repo): "import.gh.\(slug(repo))"
        case .localFile(let url): "import.file.\(slug(url.lastPathComponent))"
        case .remoteURL(let url): "import.url.\(slug(url.host ?? url.absoluteString))"
        }
    }

    private static func slug(_ raw: String) -> String {
        String(raw.lowercased().map { ($0.isLetter || $0.isNumber) ? $0 : "-" })
    }
}
