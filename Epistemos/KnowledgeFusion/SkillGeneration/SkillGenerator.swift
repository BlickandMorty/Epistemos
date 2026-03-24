import Foundation

// MARK: - Skill Generator

/// Generates structured skill files from vault analysis and training data.
/// Uses the local model to summarize patterns into AI-consumable instructions.
/// Skills are stored in Application Support and injected into system prompts at inference.
actor SkillGenerator {
    private let inferenceProvider: KFInferenceProvider
    private let skillsDir: URL

    init(inferenceProvider: KFInferenceProvider) {
        self.inferenceProvider = inferenceProvider
        self.skillsDir = SkillManifest.skillsDirectory
    }

    // MARK: - Public API

    /// Generate all skill files from vault analysis + training pairs.
    func generateSkills(
        vaultAnalysis: VaultAnalysis,
        repoAnalysis: RepoAnalysis?,
        trainingPairs: URL?,   // JSONL file with generated pairs
        sourceVault: String,
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) async throws -> SkillManifest {
        let fm = FileManager.default
        try fm.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        var manifest = SkillManifest.load()

        // 1. Writing Voice Profile (from style pairs or prose analysis)
        if vaultAnalysis.proseFiles > 0 {
            progressHandler?("Generating writing voice profile...")
            if let entry = try await generateWritingProfile(sourceVault: sourceVault, trainingPairs: trainingPairs) {
                manifest.addSkill(entry)
            }
        }

        // 2. Coding Style Guide (from repo analysis)
        if let repo = repoAnalysis, !repo.functionSignatures.isEmpty {
            progressHandler?("Generating coding style guide...")
            if let entry = try await generateCodingStyle(repo: repo, sourceVault: sourceVault) {
                manifest.addSkill(entry)
            }

            // 3. Tool Registry
            progressHandler?("Generating tool registry...")
            if let entry = try await generateToolRegistry(repo: repo, sourceVault: sourceVault) {
                manifest.addSkill(entry)
            }
        }

        // 4. Domain Knowledge Glossary (from knowledge pairs)
        if let trainingPairs, vaultAnalysis.totalWords > 500 {
            progressHandler?("Generating domain knowledge glossary...")
            if let entry = try await generateDomainGlossary(trainingPairs: trainingPairs, sourceVault: sourceVault) {
                manifest.addSkill(entry)
            }
        }

        // 5. Guardrails (always generated)
        progressHandler?("Generating AI guardrails...")
        if let entry = try await generateGuardrails(sourceVault: sourceVault) {
            manifest.addSkill(entry)
        }

        try manifest.save()
        return manifest
    }

    // MARK: - Individual Generators

    private func generateWritingProfile(sourceVault: String, trainingPairs: URL?) async throws -> SkillEntry? {
        // Sample some training pairs for style analysis
        var sampleText = ""
        if let pairs = trainingPairs, let content = try? String(contentsOf: pairs, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }.prefix(5)
            sampleText = lines.joined(separator: "\n")
        }

        let prompt = """
        Analyze these writing samples and create a concise voice profile. Describe:
        1. Sentence structure patterns (short/long, simple/complex)
        2. Vocabulary level (casual/academic/technical)
        3. Tone (formal/informal/conversational)
        4. Common phrases or verbal tics
        5. How arguments are structured

        Write the profile as instructions an AI should follow to match this voice.
        Keep it under 300 words. Be specific and actionable.

        Samples:
        \(sampleText.prefix(2000))
        """

        let result = try await inferenceProvider.generate(prompt: prompt, systemPrompt: "You are a writing style analyst.", maxTokens: 500)
        guard !result.isEmpty else { return nil }

        let dir = skillsDir.appendingPathComponent("writing")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filePath = "writing/voice-profile.md"
        try result.write(to: skillsDir.appendingPathComponent(filePath), atomically: true, encoding: .utf8)

        return SkillEntry(
            id: UUID(), name: "Voice Profile", type: .writingVoice,
            filePath: filePath, generatedAt: Date(), sourceVault: sourceVault,
            sourceAdapter: nil, confidence: min(1.0, Double(sampleText.count) / 2000.0),
            wordCount: result.split(separator: " ").count
        )
    }

    private func generateCodingStyle(repo: RepoAnalysis, sourceVault: String) async throws -> SkillEntry? {
        let langs = repo.detectedLanguages.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let funcs = repo.functionSignatures.prefix(20).map { "  \($0.signature) // \($0.file)" }.joined(separator: "\n")
        let errors = repo.errorHandlingPatterns.joined(separator: ", ")
        let arch = repo.architectureHints.joined(separator: ", ")

        let content = """
        # Coding Style Guide
        Generated from: \(sourceVault)
        Languages: \(langs.joined(separator: ", "))
        Naming Convention: \(repo.namingConvention.rawValue)
        Architecture Patterns: \(arch.isEmpty ? "Not detected" : arch)
        Error Handling: \(errors.isEmpty ? "Not detected" : errors)

        ## Function Signature Examples
        \(funcs.isEmpty ? "No functions extracted" : funcs)

        ## Instructions for AI
        - Follow \(repo.namingConvention.rawValue) naming convention
        - Use the error handling patterns listed above
        - Match the architecture style: \(arch.isEmpty ? "follow existing patterns" : arch)
        - Write code in the same style as the examples above
        """

        let dir = skillsDir.appendingPathComponent("coding-style")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filePath = "coding-style/style-guide.md"
        try content.write(to: skillsDir.appendingPathComponent(filePath), atomically: true, encoding: .utf8)

        return SkillEntry(
            id: UUID(), name: "Coding Style Guide", type: .codingStyle,
            filePath: filePath, generatedAt: Date(), sourceVault: sourceVault,
            sourceAdapter: nil, confidence: min(1.0, Double(repo.functionSignatures.count) / 50.0),
            wordCount: content.split(separator: " ").count
        )
    }

    private func generateToolRegistry(repo: RepoAnalysis, sourceVault: String) async throws -> SkillEntry? {
        guard !repo.functionSignatures.isEmpty else { return nil }

        var registry: [[String: String]] = []
        for func_ in repo.functionSignatures.prefix(100) {
            registry.append([
                "name": func_.name,
                "signature": func_.signature,
                "file": func_.file,
                "language": func_.language
            ])
        }

        let dir = skillsDir.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filePath = "tools/tool-registry.json"
        let data = try JSONSerialization.data(withJSONObject: registry, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: skillsDir.appendingPathComponent(filePath), options: .atomic)

        return SkillEntry(
            id: UUID(), name: "Tool Registry", type: .toolRegistry,
            filePath: filePath, generatedAt: Date(), sourceVault: sourceVault,
            sourceAdapter: nil, confidence: min(1.0, Double(registry.count) / 50.0),
            wordCount: registry.count
        )
    }

    private func generateDomainGlossary(trainingPairs: URL, sourceVault: String) async throws -> SkillEntry? {
        guard let content = try? String(contentsOf: trainingPairs, encoding: .utf8) else { return nil }
        let sample = String(content.prefix(3000))

        let prompt = """
        From these training Q&A pairs, extract the key domain concepts and definitions.
        Format as a glossary with term → definition. Maximum 20 entries.
        Focus on specialized terminology, not common words.

        Data:
        \(sample)
        """

        let result = try await inferenceProvider.generate(prompt: prompt, systemPrompt: "You are a knowledge extractor.", maxTokens: 800)
        guard !result.isEmpty else { return nil }

        let dir = skillsDir.appendingPathComponent("domain-knowledge")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filePath = "domain-knowledge/glossary.md"
        try ("# Domain Glossary\nGenerated from: \(sourceVault)\n\n" + result)
            .write(to: skillsDir.appendingPathComponent(filePath), atomically: true, encoding: .utf8)

        return SkillEntry(
            id: UUID(), name: "Domain Glossary", type: .domainKnowledge,
            filePath: filePath, generatedAt: Date(), sourceVault: sourceVault,
            sourceAdapter: nil, confidence: 0.6,
            wordCount: result.split(separator: " ").count
        )
    }

    private func generateGuardrails(sourceVault: String) async throws -> SkillEntry? {
        let content = """
        # AI Guardrails
        Generated for: \(sourceVault)

        ## Response Rules
        - Always be helpful and accurate
        - If unsure, say so rather than guessing
        - Match the user's communication style
        - Respect the coding conventions in the style guide
        - Use tools from the tool registry when applicable
        - Never fabricate citations or references

        ## Sandbox Constraints
        - Do not access external networks or APIs without user permission
        - Do not modify files outside the current vault
        - Do not execute code unless explicitly asked
        - Preserve existing code structure when suggesting changes

        ## Quality Standards
        - Provide concise, actionable responses
        - Include code examples when discussing technical topics
        - Reference specific notes or documents when available
        - Admit limitations of on-device model knowledge
        """

        let dir = skillsDir.appendingPathComponent("guardrails")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filePath = "guardrails/safety-instructions.md"
        try content.write(to: skillsDir.appendingPathComponent(filePath), atomically: true, encoding: .utf8)

        return SkillEntry(
            id: UUID(), name: "Safety Instructions", type: .guardrails,
            filePath: filePath, generatedAt: Date(), sourceVault: sourceVault,
            sourceAdapter: nil, confidence: 1.0,
            wordCount: content.split(separator: " ").count
        )
    }
}
