import Foundation
import Testing

@testable import Epistemos

/// Wave 9 base source-guard for the CodeArtifact substrate
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 9,
///  cross-ref `epistemos_code_verdict.md` + brain dump 2026-04-26).
///
/// Three concerns covered here:
///   1. CodeArtifactKind catalog (W9.1) — extension round-trip,
///      tree-sitter grammar mapping, new-file template render
///   2. CodeArtifactSidecar + CodeProvenance + CodeSidecarPath
///      (W9.2 + W9.3) — Codable round-trip, sidecar path resolver,
///      provenance shape parity with EpdocProvenance
///   3. ChatCodeExtractor (W9.4) — markdown fence parsing into
///      typed candidate code blocks
@Suite("Code artifact substrate (Wave 9 base)")
nonisolated struct CodeArtifactTests {

    // MARK: - W9.1 CodeArtifactKind

    @Test("Every CodeArtifactKind has a non-empty primary extension + display name")
    func everyKindHasMetadata() {
        for kind in CodeArtifactKind.allCases {
            #expect(!kind.primaryExtension.isEmpty,
                    "\(kind) must declare a primaryExtension (used by the new-file flow)")
            #expect(!kind.displayName.isEmpty,
                    "\(kind) must declare a displayName (used by the new-file picker)")
            #expect(kind.recognisedExtensions.contains(kind.primaryExtension),
                    "\(kind).recognisedExtensions must include its primaryExtension")
        }
    }

    @Test("CodeArtifactKind.from(fileURL:) classifies common extensions")
    func fromFileURLClassifiesCommon() {
        #expect(CodeArtifactKind.from(fileURL: URL(fileURLWithPath: "/tmp/Foo.swift")) == .swift)
        #expect(CodeArtifactKind.from(fileURL: URL(fileURLWithPath: "/tmp/foo.rs")) == .rust)
        #expect(CodeArtifactKind.from(fileURL: URL(fileURLWithPath: "/tmp/foo.tsx")) == .typescript,
                "tsx is a typescript variant per recognisedExtensions")
        #expect(CodeArtifactKind.from(fileURL: URL(fileURLWithPath: "/tmp/foo.py")) == .python)
        #expect(CodeArtifactKind.from(fileURL: URL(fileURLWithPath: "/tmp/foo.html")) == .html)
        #expect(CodeArtifactKind.from(fileURL: URL(fileURLWithPath: "/tmp/foo.unknown")) == .plain,
                "unknown extension must fall back to .plain (never crash)")
    }

    @Test("CodeArtifactKind tree-sitter grammar id is present for every highlightable kind")
    func treeSitterGrammarPresence() {
        let highlightable: [CodeArtifactKind] = [
            .swift, .rust, .typescript, .javascript, .python, .go, .ruby,
            .html, .css, .json, .yaml, .toml, .markdown, .shell, .sql,
        ]
        for kind in highlightable {
            #expect(kind.treeSitterGrammar != nil,
                    "\(kind) must declare a tree-sitter grammar id (W9.6 SwiftTreeSitter loader uses it)")
        }
        #expect(CodeArtifactKind.plain.treeSitterGrammar == nil,
                ".plain must not have a grammar — it's the no-highlight fallback")
    }

    @Test("newFileTemplate substitutes the supplied name + produces a non-empty body for source kinds")
    func newFileTemplateRendering() {
        let nonEmptyKinds: [CodeArtifactKind] = [
            .swift, .rust, .typescript, .javascript, .python, .go, .ruby,
            .html, .css, .yaml, .toml, .markdown, .shell, .sql,
        ]
        for kind in nonEmptyKinds {
            let body = kind.newFileTemplate(name: "Foo")
            #expect(!body.isEmpty, "\(kind).newFileTemplate must render a non-empty boilerplate")
        }
        #expect(CodeArtifactKind.json.newFileTemplate(name: "x") == "{}\n",
                "json template must be `{}` to be a valid empty document")
        #expect(CodeArtifactKind.plain.newFileTemplate(name: "x").isEmpty,
                ".plain template intentionally empty — caller decides the content")
    }

    @Test("newFileTemplate sanitises angle brackets in the name placeholder")
    func newFileTemplateSanitisesAngleBrackets() {
        let body = CodeArtifactKind.swift.newFileTemplate(name: "<malicious>")
        #expect(!body.contains("<malicious>"),
                "newFileTemplate must strip <> from the name to avoid template-injection lookalikes")
    }

    // MARK: - W9.2 CodeProvenance

    @Test("CodeProvenance Codable round-trip preserves snake_case wire keys")
    func codeProvenanceCodableRoundTrip() throws {
        let original = CodeProvenance(
            producer: .agent,
            derivedFrom: [EpdocArtifactRef(id: "thought-1", kind: .rawThought, title: "kant reasoning")],
            generatedByRun: "run-abc",
            originatedFromThoughtIndex: 7,
            toolId: "write_file",
            toolUseId: "tu-42",
            sourceArtifacts: [EpdocArtifactRef(id: "doc-1", kind: .document, title: "spec")]
        )
        let data = try JSONEncoder.epdocCanonical.encode(original)
        let json = String(data: data, encoding: .utf8) ?? ""
        for snakeKey in [
            "\"derived_from\"",
            "\"generated_by_run\"",
            "\"originated_from_thought_index\"",
            "\"tool_id\"",
            "\"tool_use_id\"",
            "\"source_artifacts\"",
        ] {
            #expect(json.contains(snakeKey),
                    "CodeProvenance encoded JSON must contain key \(snakeKey) — wire-format parity guard")
        }
        let recovered = try JSONDecoder.epdocCanonical.decode(CodeProvenance.self, from: data)
        #expect(recovered == original)
    }

    // MARK: - W9.3 CodeArtifactSidecar + CodeSidecarPath

    @Test("CodeArtifactSidecar Codable round-trip preserves embeddings + symbols + cross-refs")
    func sidecarCodableRoundTrip() throws {
        let original = CodeArtifactSidecar(
            vaultRelativePath: "Sources/Foo.swift",
            kind: .swift,
            contentHash: "deadbeef",
            indexedAt: 1_700_000_000_000,
            provenance: CodeProvenance(producer: .human),
            symbols: [
                CodeSymbol(name: "fooBar", kind: .function, utf8ByteStart: 100, utf8ByteEnd: 250),
                CodeSymbol(name: "Greeter", kind: .type, utf8ByteStart: 300, utf8ByteEnd: 600),
            ],
            crossReferences: [
                EpdocArtifactRef(id: "Sources/Bar.swift", kind: .code, title: "Bar"),
            ],
            embedding: [0.1, 0.2, 0.3, 0.4]
        )
        let data = try JSONEncoder.epdocCanonical.encode(original)
        let recovered = try JSONDecoder.epdocCanonical.decode(CodeArtifactSidecar.self, from: data)
        #expect(recovered.kind == .swift)
        #expect(recovered.symbols.count == 2)
        #expect(recovered.symbols[0].kind == .function)
        #expect(recovered.crossReferences.count == 1)
        #expect(recovered.embedding == [0.1, 0.2, 0.3, 0.4])
        #expect(recovered.contentHash == "deadbeef")
    }

    @Test("CodeSidecarPath produces stable, rename-safe sidecar locations")
    func sidecarPathIsRenameSafe() {
        let vault = URL(fileURLWithPath: "/tmp/Vault")
        let url1 = CodeSidecarPath.sidecarURL(forVaultRoot: vault, vaultRelativePath: "Sources/Foo.swift")
        let url2 = CodeSidecarPath.sidecarURL(forVaultRoot: vault, vaultRelativePath: "Sources/Foo.swift")
        let url3 = CodeSidecarPath.sidecarURL(forVaultRoot: vault, vaultRelativePath: "Sources/Bar.swift")
        #expect(url1 == url2, "same path must produce same sidecar URL (deterministic hashing)")
        #expect(url1 != url3, "different path must produce different sidecar URL")
        #expect(url1.path.contains("/.epcache/code/"),
                "sidecars MUST live under .epcache/code/ — never embedded in the source tree")
        #expect(url1.lastPathComponent.hasSuffix(".epcode.json"),
                "sidecar files MUST use the .epcode.json suffix")
    }

    @Test("CodeSidecarPath.pathHash is deterministic + 64-char hex")
    func pathHashShape() {
        let h1 = CodeSidecarPath.pathHash("Sources/Foo.swift")
        let h2 = CodeSidecarPath.pathHash("Sources/Foo.swift")
        #expect(h1 == h2)
        #expect(h1.count == 64, "SHA-256 hex digest is 64 chars")
        #expect(h1.allSatisfy { "0123456789abcdef".contains($0) },
                "pathHash output must be lowercase hex only")
    }

    // MARK: - W9.4 ChatCodeExtractor

    @Test("ChatCodeExtractor finds a single fenced block")
    func extractsSingleFence() {
        let text = """
        Here's the code:

        ```swift
        func hello() { print("hi") }
        ```

        That's it.
        """
        let blocks = ChatCodeExtractor.extract(from: text)
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .swift)
        #expect(blocks[0].rawLanguageTag == "swift")
        #expect(blocks[0].body.contains("func hello()"))
    }

    @Test("ChatCodeExtractor finds multiple fenced blocks in source order")
    func extractsMultipleInOrder() {
        let text = """
        First:
        ```rust
        fn one() {}
        ```

        Second:
        ```python
        def two(): pass
        ```
        """
        let blocks = ChatCodeExtractor.extract(from: text)
        #expect(blocks.count == 2)
        #expect(blocks[0].kind == .rust)
        #expect(blocks[1].kind == .python)
        #expect(blocks[0].openingFenceOffset < blocks[1].openingFenceOffset,
                "blocks must be returned in source order")
    }

    @Test("ChatCodeExtractor handles language aliases (js, ts, py, sh, etc.)")
    func extractorHandlesAliases() {
        let cases: [(tag: String, expected: CodeArtifactKind)] = [
            ("js", .javascript),
            ("ts", .typescript),
            ("py", .python),
            ("rb", .ruby),
            ("sh", .shell),
            ("bash", .shell),
            ("zsh", .shell),
            ("yml", .yaml),
            ("md", .markdown),
            ("rs", .rust),
            ("golang", .go),
        ]
        for (tag, expected) in cases {
            let text = "```\(tag)\nbody\n```"
            let blocks = ChatCodeExtractor.extract(from: text)
            #expect(blocks.count == 1, "tag '\(tag)' must produce 1 block")
            #expect(blocks.first?.kind == expected,
                    "tag '\(tag)' must classify as \(expected); got \(String(describing: blocks.first?.kind))")
        }
    }

    @Test("ChatCodeExtractor falls back to .plain on missing or unknown tag")
    func extractorFallsBackToPlain() {
        let untagged = "```\nplain body\n```"
        let unknown = "```martian\nplain body\n```"
        #expect(ChatCodeExtractor.extract(from: untagged).first?.kind == .plain)
        #expect(ChatCodeExtractor.extract(from: unknown).first?.kind == .plain)
    }

    @Test("ChatCodeExtractor drops unterminated fences instead of recovering")
    func extractorDropsUnterminated() {
        let text = """
        ```swift
        unterminated body never closes
        """
        let blocks = ChatCodeExtractor.extract(from: text)
        #expect(blocks.isEmpty,
                "unterminated fences must be dropped — recovery is ambiguous and agents rarely emit them")
    }

    @Test("ChatCodeExtractor returns empty array for plain text")
    func extractorEmptyForPlainText() {
        let blocks = ChatCodeExtractor.extract(from: "no code in this message")
        #expect(blocks.isEmpty)
    }

    @Test("ChatCodeExtractor.kind(forLanguageTag:) is case-insensitive")
    func kindCaseInsensitive() {
        #expect(ChatCodeExtractor.kind(forLanguageTag: "Swift") == .swift)
        #expect(ChatCodeExtractor.kind(forLanguageTag: "RUST") == .rust)
        #expect(ChatCodeExtractor.kind(forLanguageTag: "JavaScript") == .javascript)
    }
}
