import Foundation

// MARK: - Vault Analysis Result

struct VaultAnalysis: Sendable {
    let totalFiles: Int
    let totalWords: Int
    let estimatedTokens: Int

    // Content type breakdown
    let proseFiles: Int      // .md, .txt with narrative text
    let codeFiles: Int       // .swift, .py, .rs, .js, .ts, etc.
    let docFiles: Int        // .pdf
    let audioFiles: Int      // .m4a, .mp3, .wav

    let avgWordsPerFile: Int
    let codeToTextRatio: Double   // 0.0 = all prose, 1.0 = all code
    let vocabularyRichness: Double // unique words / total words (0-1)

    // Auto-recommended settings
    let recommendedProfile: TrainingProfile
    let recommendedRank: Int
    let recommendedAlpha: Int
    let recommendedIterations: Int
    let recommendedSeqLen: Int
    let rationale: String
}

// MARK: - Vault Analyzer

/// Lightweight vault scanner that classifies content types and recommends
/// optimal training settings WITHOUT using an LLM. Uses heuristics only.
/// Runs in <1 second for vaults up to 10,000 files.
nonisolated struct VaultAnalyzer: Sendable {

    private static let codeExtensions: Set<String> = [
        "swift", "py", "rs", "js", "ts", "jsx", "tsx", "go", "c", "cpp",
        "h", "hpp", "java", "kt", "rb", "sh", "zsh", "bash", "lua",
        "sql", "r", "m", "mm", "css", "scss", "html", "xml", "json", "yaml", "yml", "toml"
    ]

    private static let proseExtensions: Set<String> = [
        "md", "markdown", "txt", "rtf", "org", "rst", "tex", "adoc"
    ]

    private static let audioExtensions: Set<String> = [
        "m4a", "mp3", "wav", "ogg", "flac", "aac"
    ]

    /// Analyze a vault directory and return content classification + recommended settings.
    func analyze(vaultURL: URL, systemMemoryGB: Int) -> VaultAnalysis {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return emptyAnalysis(systemMemoryGB: systemMemoryGB)
        }

        var totalFiles = 0
        var proseFiles = 0
        var codeFiles = 0
        var docFiles = 0
        var audioFiles = 0
        var totalWords = 0
        var wordSet = Set<String>()
        var sampledWordCount = 0

        // Scan files — read first 2000 chars of text files for word stats
        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
            totalFiles += 1

            if Self.codeExtensions.contains(ext) {
                codeFiles += 1
                sampleWords(from: fileURL, totalWords: &totalWords, wordSet: &wordSet, sampledCount: &sampledWordCount)
            } else if Self.proseExtensions.contains(ext) {
                proseFiles += 1
                sampleWords(from: fileURL, totalWords: &totalWords, wordSet: &wordSet, sampledCount: &sampledWordCount)
            } else if ext == "pdf" {
                docFiles += 1
            } else if Self.audioExtensions.contains(ext) {
                audioFiles += 1
            }
        }

        let textFiles = proseFiles + codeFiles
        let avgWords = textFiles > 0 ? totalWords / textFiles : 0
        let codeRatio = textFiles > 0 ? Double(codeFiles) / Double(textFiles) : 0
        let vocabRichness = totalWords > 0 ? min(1.0, Double(wordSet.count) / Double(min(totalWords, 5000))) : 0
        let estimatedTokens = Int(Double(totalWords) * 1.3)

        // Auto-recommend based on content
        let (profile, rank, alpha, iterations, seqLen, rationale) = recommendSettings(
            proseFiles: proseFiles,
            codeFiles: codeFiles,
            totalWords: totalWords,
            estimatedTokens: estimatedTokens,
            codeRatio: codeRatio,
            vocabRichness: vocabRichness,
            avgWords: avgWords,
            systemMemoryGB: systemMemoryGB
        )

        return VaultAnalysis(
            totalFiles: totalFiles,
            totalWords: totalWords,
            estimatedTokens: estimatedTokens,
            proseFiles: proseFiles,
            codeFiles: codeFiles,
            docFiles: docFiles,
            audioFiles: audioFiles,
            avgWordsPerFile: avgWords,
            codeToTextRatio: codeRatio,
            vocabularyRichness: vocabRichness,
            recommendedProfile: profile,
            recommendedRank: rank,
            recommendedAlpha: alpha,
            recommendedIterations: iterations,
            recommendedSeqLen: seqLen,
            rationale: rationale
        )
    }

    // MARK: - Settings Recommendation

    private func recommendSettings(
        proseFiles: Int,
        codeFiles: Int,
        totalWords: Int,
        estimatedTokens: Int,
        codeRatio: Double,
        vocabRichness: Double,
        avgWords: Int,
        systemMemoryGB: Int
    ) -> (TrainingProfile, Int, Int, Int, Int, String) {

        // Profile selection
        let profile: TrainingProfile
        let rationale: String

        if codeRatio > 0.6 {
            profile = .knowledge  // Code repos → knowledge profile (needs MLP layers for tool patterns)
            rationale = "Code-heavy vault (\(Int(codeRatio * 100))% code) — using knowledge profile to capture tool patterns and APIs"
        } else if codeRatio < 0.15 && proseFiles > 3 {
            profile = .style
            rationale = "Prose-heavy vault (\(proseFiles) text files) — using style profile to capture your writing voice"
        } else if proseFiles > 0 && codeFiles > 0 {
            profile = .mixed
            rationale = "Mixed vault (\(proseFiles) prose + \(codeFiles) code) — training both style and knowledge adapters"
        } else {
            profile = .knowledge
            rationale = "General vault — using knowledge profile for broad learning"
        }

        // Rank: higher for complex/diverse content, lower for simple style
        let rank: Int
        switch profile {
        case .style:
            rank = vocabRichness > 0.5 ? 8 : 8  // Style always rank 8
        case .knowledge:
            if systemMemoryGB >= 32 { rank = 32 }
            else if vocabRichness > 0.4 { rank = 16 }
            else { rank = 16 }
        case .mixed:
            rank = systemMemoryGB >= 32 ? 32 : 16
        }
        let alpha = rank * 2

        // Iterations: scale with data size, cap by hardware
        let baseIters = max(100, min(1000, estimatedTokens / 50))
        let iterations: Int
        if systemMemoryGB <= 16 { iterations = min(baseIters, 500) }
        else if systemMemoryGB <= 32 { iterations = min(baseIters, 800) }
        else { iterations = baseIters }

        // Sequence length: longer for docs with long paragraphs
        let seqLen: Int
        if systemMemoryGB >= 32 && avgWords > 500 { seqLen = 2048 }
        else if systemMemoryGB >= 24 && avgWords > 300 { seqLen = 1024 }
        else { seqLen = 1024 }

        return (profile, rank, alpha, iterations, seqLen, rationale)
    }

    // MARK: - Helpers

    private func sampleWords(from url: URL, totalWords: inout Int, wordSet: inout Set<String>, sampledCount: inout Int) {
        // Only sample first 2000 chars to keep analysis fast
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { handle.closeFile() }
        let data = handle.readData(ofLength: 2000)
        guard let text = String(data: data, encoding: .utf8) else { return }

        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        totalWords += words.count
        sampledCount += 1

        // Track unique words for vocabulary richness (cap at 5000 to avoid memory bloat)
        if wordSet.count < 5000 {
            for word in words.prefix(200) {
                wordSet.insert(word.lowercased())
            }
        }
    }

    private func emptyAnalysis(systemMemoryGB: Int) -> VaultAnalysis {
        VaultAnalysis(
            totalFiles: 0, totalWords: 0, estimatedTokens: 0,
            proseFiles: 0, codeFiles: 0, docFiles: 0, audioFiles: 0,
            avgWordsPerFile: 0, codeToTextRatio: 0, vocabularyRichness: 0,
            recommendedProfile: .knowledge,
            recommendedRank: 16, recommendedAlpha: 32,
            recommendedIterations: 200, recommendedSeqLen: 1024,
            rationale: "Empty vault"
        )
    }
}
