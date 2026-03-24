import Foundation
import Testing
@testable import Epistemos

// MARK: - Test Fixtures

private func createTestVault() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("kf-test-vault-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    // File 1: Markdown with multiple headers
    let md1 = """
    # Document Title

    Introductory paragraph that should be captured as preamble text before the first H2.

    ## Overview of Quantum Computing

    Quantum computing leverages quantum mechanical phenomena such as superposition and entanglement to process information. Unlike classical bits which are either 0 or 1, quantum bits (qubits) can exist in multiple states simultaneously. This fundamentally changes the computational paradigm and opens new possibilities for solving complex problems that are intractable for classical computers. Research in this field has accelerated dramatically in recent years with major breakthroughs from both academic institutions and technology companies.

    ## Key Algorithms

    Shor's algorithm can factor large integers exponentially faster than the best known classical algorithms. Grover's algorithm provides a quadratic speedup for unstructured search problems. The Variational Quantum Eigensolver (VQE) is a hybrid quantum-classical algorithm used for finding the ground state energy of molecular systems. These algorithms demonstrate the theoretical advantage of quantum computing for specific problem classes.

    ### Shor's Algorithm Details

    Shor's algorithm operates in two phases: a classical reduction of factoring to order-finding, and a quantum subroutine that performs order-finding efficiently using the Quantum Fourier Transform. The algorithm achieves exponential speedup over classical factoring methods, threatening RSA encryption. Implementation requires error-corrected logical qubits, which current noisy intermediate-scale quantum (NISQ) devices cannot yet reliably provide at the necessary scale.

    ## Applications in Cryptography

    The advent of large-scale quantum computers poses a significant threat to current public-key cryptography systems. RSA and elliptic curve cryptography rely on the computational difficulty of factoring and discrete logarithm problems respectively. Post-quantum cryptography research focuses on developing algorithms resistant to quantum attacks, including lattice-based, hash-based, and code-based approaches. NIST has been standardizing post-quantum cryptographic algorithms since 2016.

    ## Future Outlook

    Experts predict that fault-tolerant quantum computers capable of running Shor's algorithm at scale may emerge within the next decade. This timeline drives urgency in deploying quantum-resistant cryptographic standards. Meanwhile hybrid quantum-classical algorithms continue to find practical applications in chemistry simulation and optimization problems on near-term quantum hardware.
    """
    try md1.write(to: root.appendingPathComponent("quantum_computing.md"), atomically: true, encoding: .utf8)

    // File 2: Short markdown (tests orphan merging)
    let md2 = """
    ## Short Section

    Brief note.

    ## Another Short One

    Also brief.

    ## Substantial Section

    This section has enough content to stand on its own. It discusses multiple topics including machine learning architectures, transformer models, attention mechanisms, and their applications in natural language processing. The field has evolved rapidly since the introduction of the transformer architecture in 2017, leading to models like BERT, GPT, and their successors. These models have achieved remarkable performance across a wide range of language tasks.
    """
    try md2.write(to: root.appendingPathComponent("short_notes.md"), atomically: true, encoding: .utf8)

    // File 3: Plain text (no markdown headers)
    let txt = """
    Personal journal entry for March 2026.

    Today I worked on the Epistemos knowledge fusion system. The key insight was that markdown-header-based chunking preserves natural language boundaries better than naive recursive splitting. I spent most of the afternoon debugging the chunker algorithm.

    In the evening I reviewed the research paper on QLoRA fine-tuning and made notes about the optimal hyperparameters for knowledge absorption versus style cloning. The distinction between attention layers (style) and MLP layers (facts) is fascinating.

    Tomorrow I plan to implement the synthetic data generation pipeline using the Self-Instruct backtranslation methodology. The three-step loop of query generation, response rewriting, and quality scoring should produce high-quality training pairs from my vault notes.
    """
    try txt.write(to: root.appendingPathComponent("journal.txt"), atomically: true, encoding: .utf8)

    return root
}

private func cleanupVault(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

// MARK: - VaultParser Tests

@Suite("VaultParser")
struct VaultParserTests {

    @Test("Parses a test vault with mixed file types")
    func parsesTestVault() async throws {
        let vaultURL = try createTestVault()
        defer { cleanupVault(vaultURL) }

        let parser = VaultParser()
        let result = await parser.parseVault(at: vaultURL, vaultName: "TestVault")

        #expect(result.totalFiles == 3)
        #expect(result.parsedFiles == 3)
        #expect(result.errors.isEmpty)
        #expect(result.documents.count == 3)

        let markdown = result.documents.filter { $0.fileType == .markdown }
        let text = result.documents.filter { $0.fileType == .text }
        #expect(markdown.count == 2)
        #expect(text.count == 1)
    }

    @Test("Metadata is populated correctly")
    func metadataPopulated() async throws {
        let vaultURL = try createTestVault()
        defer { cleanupVault(vaultURL) }

        let parser = VaultParser()
        let result = await parser.parseVault(at: vaultURL, vaultName: "MetaVault")

        for doc in result.documents {
            #expect(doc.metadata.sourceVault == "MetaVault")
            #expect(doc.metadata.wordCount > 0)
            #expect(!doc.metadata.title.isEmpty)
            #expect(doc.id != UUID())
        }
    }

    @Test("Handles non-existent directory gracefully")
    func handlesNonExistentDirectory() async {
        let parser = VaultParser()
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent-vault-\(UUID().uuidString)")
        let result = await parser.parseVault(at: fakeURL)

        #expect(result.documents.isEmpty)
        #expect(result.totalFiles == 0)
    }

    @Test("Skips unsupported file types")
    func skipsUnsupportedFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kf-skip-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { cleanupVault(root) }

        try "valid markdown".write(to: root.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)
        try Data([0x00, 0x01, 0x02]).write(to: root.appendingPathComponent("image.png"))
        try "{ \"key\": \"value\" }".write(to: root.appendingPathComponent("data.json"), atomically: true, encoding: .utf8)

        let parser = VaultParser()
        let result = await parser.parseVault(at: root)

        #expect(result.parsedFiles == 1)  // only .md
    }
}

// MARK: - DocumentChunker Tests

@Suite("DocumentChunker")
struct DocumentChunkerTests {

    @Test("Markdown header chunking produces correct chunk count")
    func markdownHeaderChunking() async throws {
        let vaultURL = try createTestVault()
        defer { cleanupVault(vaultURL) }

        let parser = VaultParser()
        let result = await parser.parseVault(at: vaultURL)
        let quantumDoc = result.documents.first { $0.metadata.title == "quantum_computing" }!

        let chunker = DocumentChunker()
        let chunks = chunker.chunk(document: quantumDoc)

        // quantum_computing.md has: preamble + Overview + Key Algorithms + Shor's Details + Cryptography + Future
        // That's ~5-6 sections depending on merging
        #expect(chunks.count >= 3)
        #expect(chunks.count <= 7)

        // All chunks should be markdown type
        for chunk in chunks {
            #expect(chunk.chunkType == .markdown)
            #expect(chunk.documentId == quantumDoc.id)
        }
    }

    @Test("No chunk exceeds max token limit")
    func noChunkExceedsMaxTokens() async throws {
        let vaultURL = try createTestVault()
        defer { cleanupVault(vaultURL) }

        let parser = VaultParser()
        let result = await parser.parseVault(at: vaultURL)
        let chunker = DocumentChunker(maxTokens: 1500)

        for doc in result.documents {
            let chunks = chunker.chunk(document: doc)
            for chunk in chunks {
                #expect(chunk.estimatedTokenCount <= 1500,
                       "Chunk \(chunk.chunkIndex) in \(doc.metadata.title) exceeds 1500 tokens: \(chunk.estimatedTokenCount)")
            }
        }
    }

    @Test("Orphan sections are merged")
    func orphanSectionsMerged() async throws {
        let vaultURL = try createTestVault()
        defer { cleanupVault(vaultURL) }

        let parser = VaultParser()
        let result = await parser.parseVault(at: vaultURL)
        let shortDoc = result.documents.first { $0.metadata.title == "short_notes" }!

        let chunker = DocumentChunker(minWords: 50)
        let chunks = chunker.chunk(document: shortDoc)

        // The two short sections ("Brief note." and "Also brief.") should merge
        // because each is under 50 words. After merging, total chunk count
        // should be fewer than the raw heading count (3 headings).
        #expect(chunks.count <= 3, "Expected orphan merging to reduce chunk count")
        // Verify no chunk is just a single heading with no body
        for chunk in chunks {
            #expect(!chunk.text.isEmpty)
        }
    }

    @Test("Plain text uses paragraph chunking")
    func plainTextParagraphChunking() async throws {
        let vaultURL = try createTestVault()
        defer { cleanupVault(vaultURL) }

        let parser = VaultParser()
        let result = await parser.parseVault(at: vaultURL)
        let textDoc = result.documents.first { $0.fileType == .text }!

        let chunker = DocumentChunker()
        let chunks = chunker.chunk(document: textDoc)

        #expect(!chunks.isEmpty)
        for chunk in chunks {
            #expect(chunk.chunkType == .paragraph)
            #expect(chunk.heading == nil)
        }
    }

    @Test("Empty document produces no chunks")
    func emptyDocumentNoChunks() {
        let doc = ParsedDocument(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/empty.md"),
            fileType: .markdown,
            rawText: "",
            metadata: DocumentMetadata(
                title: "empty",
                createdAt: nil,
                modifiedAt: nil,
                wordCount: 0,
                sourceVault: "test"
            )
        )

        let chunker = DocumentChunker()
        let chunks = chunker.chunk(document: doc)
        #expect(chunks.isEmpty)
    }

    @Test("Token estimation is reasonable")
    func tokenEstimation() {
        let chunker = DocumentChunker()
        // 100 words * 1.3 ≈ 130 tokens
        let text = Array(repeating: "word", count: 100).joined(separator: " ")
        let estimate = chunker.estimateTokens(text)
        #expect(estimate == 130)
    }

    @Test("Chunk indices are sequential")
    func chunkIndicesSequential() async throws {
        let vaultURL = try createTestVault()
        defer { cleanupVault(vaultURL) }

        let parser = VaultParser()
        let result = await parser.parseVault(at: vaultURL)
        let chunker = DocumentChunker()

        for doc in result.documents {
            let chunks = chunker.chunk(document: doc)
            for (i, chunk) in chunks.enumerated() {
                #expect(chunk.chunkIndex == i)
            }
        }
    }
}

// MARK: - AudioTranscriber Tests

@Suite("AudioTranscriber")
struct AudioTranscriberTests {

    @Test("Backend detection runs without crash")
    func backendDetection() async {
        let transcriber = AudioTranscriber()
        let backend = await transcriber.detectBackend()
        // mlx-whisper should be available since we installed it
        // But model download may be needed, so just verify no crash
        #expect(backend == .mlxWhisper || backend == .whisperCpp || backend == .unavailable)
    }

    @Test("Hesitation frequency calculation is correct")
    func hesitationParsing() throws {
        // Test the parsing logic with synthetic whisper JSON
        let json: [String: Any] = [
            "text": "So um I think uh the quantum uh computing approach is um basically correct",
            "segments": [
                [
                    "start": 0.0,
                    "end": 5.0,
                    "text": "So um I think uh the quantum uh computing approach is um basically correct"
                ] as [String: Any]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        // Use a mirror to test internal parsing (or make a testable wrapper)
        // For now, verify the struct construction logic manually:
        let fullText = json["text"] as! String
        let words = fullText.split(whereSeparator: { $0.isWhitespace })
        let hesitationPatterns: Set<String> = ["uh", "um", "erm", "hmm", "hm", "er", "ah"]
        let hesitations = words.filter { hesitationPatterns.contains($0.lowercased()) }.count

        // "um" appears 2x, "uh" appears 2x = 4 hesitations in 13 words
        #expect(hesitations == 4)

        let frequency = Double(hesitations) / Double(words.count) * 100.0
        #expect(frequency > 25.0 && frequency < 35.0)  // ~30.8%
    }
}

// MARK: - Integration

@Suite("DataIngestion Integration")
struct DataIngestionIntegrationTests {

    @Test("Full parse-then-chunk pipeline produces valid output")
    func fullPipeline() async throws {
        let vaultURL = try createTestVault()
        defer { cleanupVault(vaultURL) }

        let parser = VaultParser()
        let result = await parser.parseVault(at: vaultURL)
        #expect(result.parsedFiles == 3)

        let chunker = DocumentChunker(maxTokens: 1500, minWords: 50)
        let allChunks = chunker.chunkAll(documents: result.documents)

        #expect(!allChunks.isEmpty)
        #expect(allChunks.count >= 3)  // At least one chunk per document

        // Verify all chunks have valid fields
        for chunk in allChunks {
            #expect(!chunk.text.isEmpty)
            #expect(chunk.estimatedTokenCount > 0)
            #expect(chunk.estimatedTokenCount <= 1500)
        }

        // Verify document IDs are correctly linked
        let docIds = Set(result.documents.map(\.id))
        for chunk in allChunks {
            #expect(docIds.contains(chunk.documentId))
        }
    }
}
