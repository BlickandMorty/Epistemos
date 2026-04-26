import Foundation
import Testing

@testable import Epistemos

/// Wave 9.6 source-guard for the live-editor controller surface.
@MainActor
@Suite("LiveCodeEditorController (Wave 9.6 base)")
struct LiveCodeEditorControllerTests {

    private func makeVault() -> (URL, () -> Void) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos-live-editor-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return (tmp, { try? FileManager.default.removeItem(at: tmp) })
    }

    private static let provenance = CodeProvenance(producer: .human)

    // MARK: - init

    @Test("controller starts clean with empty highlight tokens for plain text")
    func startsClean() {
        let ctrl = LiveCodeEditorController(text: "hello", language: .plain)
        #expect(ctrl.text == "hello")
        #expect(ctrl.language == .plain)
        #expect(ctrl.isDirty == false)
        // .plain has no keyword needles, so the stub returns no tokens.
        #expect(ctrl.highlightTokens.isEmpty)
    }

    @Test("controller computes highlights for the configured language on init")
    func computesHighlightsOnInit() {
        let ctrl = LiveCodeEditorController(text: "func main() {}", language: .swift)
        #expect(!ctrl.highlightTokens.isEmpty,
                "stub highlighter must mark `func` for Swift on init")
        let kinds = Set(ctrl.highlightTokens.map { $0.kind })
        #expect(kinds.contains(.keyword))
    }

    // MARK: - setText

    @Test("setText with identical bytes is a no-op (no dirty flip, no recompute)")
    func setTextIdenticalIsNoOp() {
        let ctrl = LiveCodeEditorController(text: "func a() {}", language: .swift)
        let before = ctrl.highlightTokens
        ctrl.setText("func a() {}")
        #expect(ctrl.isDirty == false)
        #expect(ctrl.highlightTokens == before)
    }

    @Test("setText with different bytes flips isDirty + recomputes highlights")
    func setTextDifferentBytes() {
        let ctrl = LiveCodeEditorController(text: "func a() {}", language: .swift)
        ctrl.setText("func a() {}\nfunc b() {}")
        #expect(ctrl.isDirty,
                "different bytes from disk content must flip isDirty")
        // Two `func` keywords now.
        let funcCount = ctrl.highlightTokens
            .filter { $0.utf16Length == 4 && $0.kind == .keyword }
            .count
        #expect(funcCount >= 2,
                "two func keywords must produce at least 2 keyword tokens")
    }

    // MARK: - setLanguage

    @Test("setLanguage refreshes the highlight pass against the new grammar")
    func setLanguageRefreshes() {
        let ctrl = LiveCodeEditorController(text: "fn main() {}", language: .swift)
        // Swift grammar shouldn't see "fn" as a keyword.
        let beforeKinds = Set(ctrl.highlightTokens.map { $0.kind })
        #expect(!beforeKinds.contains(.keyword) || ctrl.highlightTokens.isEmpty)
        ctrl.setLanguage(.rust)
        let afterKinds = Set(ctrl.highlightTokens.map { $0.kind })
        #expect(afterKinds.contains(.keyword),
                "Rust grammar must mark `fn` as keyword on language switch")
    }

    @Test("setLanguage to the same kind is a no-op")
    func setLanguageSameIsNoOp() {
        let ctrl = LiveCodeEditorController(text: "func main() {}", language: .swift)
        let before = ctrl.highlightTokens
        ctrl.setLanguage(.swift)
        #expect(ctrl.highlightTokens == before)
    }

    // MARK: - load + save round-trip

    @Test("load() reads the file body + sidecar kind + clears isDirty")
    func loadResetsState() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let files = CodeFileService(vaultRoot: vault)
        let url = try files.createCodeFile(
            relativeDirectory: "",
            name: "Loaded",
            kind: .swift,
            body: "func loaded() {}",
            provenance: Self.provenance
        )

        let ctrl = LiveCodeEditorController()
        ctrl.setText("dirty buffer")
        try ctrl.load(fileURL: url, via: files)
        #expect(ctrl.text == "func loaded() {}")
        #expect(ctrl.language == .swift)
        #expect(ctrl.isDirty == false,
                "load() must clear isDirty — disk hash matches in-memory text")
    }

    @Test("save() writes the buffer + clears isDirty + updates diskContentHash")
    func saveWritesAndClearsDirty() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let files = CodeFileService(vaultRoot: vault)
        let url = try files.createCodeFile(
            relativeDirectory: "",
            name: "Saver",
            kind: .swift,
            body: "// v1\n",
            provenance: Self.provenance
        )

        let ctrl = LiveCodeEditorController()
        try ctrl.load(fileURL: url, via: files)
        ctrl.setText("// v2 modified body\n")
        let dirtyHashBefore = ctrl.diskContentHash
        try ctrl.save(fileURL: url, via: files)
        #expect(ctrl.isDirty == false,
                "save() must clear isDirty after a successful write")
        #expect(ctrl.diskContentHash != dirtyHashBefore,
                "save() must update diskContentHash to the new content's digest")

        // Verify the file actually changed on disk.
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == "// v2 modified body\n")
    }

    @Test("save() is a no-op when not dirty")
    func saveNoOpWhenClean() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let files = CodeFileService(vaultRoot: vault)
        let url = try files.createCodeFile(
            relativeDirectory: "",
            name: "Clean",
            kind: .swift,
            body: "// untouched\n",
            provenance: Self.provenance
        )

        let ctrl = LiveCodeEditorController()
        try ctrl.load(fileURL: url, via: files)
        let hashBefore = ctrl.diskContentHash
        try ctrl.save(fileURL: url, via: files)
        #expect(ctrl.diskContentHash == hashBefore,
                "save() on a clean controller must not touch the file or update the hash")
    }

    @Test("save() can record a fresh provenance (e.g. agent-driven edit)")
    func saveAcceptsProvenanceOverride() throws {
        let (vault, cleanup) = makeVault()
        defer { cleanup() }
        let files = CodeFileService(vaultRoot: vault)
        let url = try files.createCodeFile(
            relativeDirectory: "",
            name: "ProvOverride",
            kind: .swift,
            body: "// v1\n",
            provenance: Self.provenance
        )

        let ctrl = LiveCodeEditorController()
        try ctrl.load(fileURL: url, via: files)
        ctrl.setText("// v2 by agent\n")
        let agentProv = CodeProvenance(
            producer: .agent,
            generatedByRun: "run-grep-9999",
            toolId: "edit_file"
        )
        try ctrl.save(fileURL: url, via: files, provenanceOverride: agentProv)
        let sidecar = try files.readCodeFile(at: url).sidecar
        #expect(sidecar?.provenance.toolId == "edit_file")
        #expect(sidecar?.provenance.generatedByRun == "run-grep-9999")
    }

    // MARK: - Stub highlighter coverage

    @Test("StubLiveHighlighter highlights every per-language keyword needle")
    func stubHighlighterCoverage() {
        let cases: [(CodeArtifactKind, String, String)] = [
            (.swift, "func main() {}", "func"),
            (.rust, "fn main() {}", "fn"),
            (.typescript, "function f() {}", "function"),
            (.javascript, "const x = 1", "const"),
            (.python, "def f(): pass", "def"),
            (.go, "func main() {}", "func"),
            (.ruby, "def f; end", "def"),
        ]
        for (lang, src, needle) in cases {
            let ctrl = LiveCodeEditorController(text: src, language: lang)
            #expect(ctrl.highlightTokens.contains { token in
                let nsRange = token.nsRange
                let extracted = (src as NSString).substring(with: nsRange)
                return extracted == needle && token.kind == .keyword
            }, "stub highlighter must mark `\(needle)` for .\(lang)")
        }
    }

    @Test("StubLiveHighlighter returns empty for non-source languages")
    func stubHighlighterEmptyForNonSource() {
        for lang in [CodeArtifactKind.json, .yaml, .toml, .markdown, .sql, .plain, .shell] {
            let ctrl = LiveCodeEditorController(text: "anything", language: lang)
            #expect(ctrl.highlightTokens.isEmpty,
                    "stub highlighter must produce no tokens for .\(lang) — needles list is empty")
        }
    }

    // MARK: - LiveHighlightToken nsRange

    @Test("LiveHighlightToken.nsRange echoes utf16Start + utf16Length")
    func nsRangeEcho() {
        let token = LiveHighlightToken(utf16Start: 5, utf16Length: 4, kind: .keyword)
        #expect(token.nsRange == NSRange(location: 5, length: 4))
    }
}
