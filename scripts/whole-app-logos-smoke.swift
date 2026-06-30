import Foundation

enum CloudModelProvider: CaseIterable, Sendable {
    case openAI
    case anthropic
    case google
    case kimi
    case zai
    case minimax
    case deepseek
}

@main
struct WholeAppLogosSmoke {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let integrationSource = read("Epistemos/Views/Shared/IntegrationBrandMark.swift", root: root)

        for brand in IntegrationBrand.allCases {
            require(!brand.displayName.isEmpty, "empty IntegrationBrand displayName for \(brand.rawValue)")
            require(brand.assetName == nil, "IntegrationBrand must not claim official asset \(brand.rawValue)")
            require(!brand.systemSymbol.isEmpty, "empty IntegrationBrand symbol for \(brand.rawValue)")
            require(!brand.monogram.isEmpty, "empty IntegrationBrand monogram for \(brand.rawValue)")
        }

        require(IntegrationBrand.installedMCPServer(name: "Context7 MCP", host: "context7.com") == .context7, "Context7 MCP classifier failed")
        require(IntegrationBrand.installedMCPServer(name: "Gmail", host: "googlemail.test") == .gmail, "Gmail MCP classifier failed")
        require(IntegrationBrand.mcpRegistry(source: "mcp.so", installKind: "remoteURL", name: "Search") == .mcpSO, "mcp.so classifier failed")
        require(IntegrationBrand.bestOfPreset(kind: "remoteMCP", id: "vault", displayName: "Vault") == .vault, "best-of vault classifier failed")
        require(IntegrationBrand.connector(id: "google-drive", displayName: "Drive") == .googleDrive, "connector drive classifier failed")
        require(IntegrationBrand.skillDiscovery(source: "codex", identifier: "docs", category: "research") == .codexSkills, "skill discovery classifier failed")
        require(IntegrationBrand.skillInstallSource(rawValue: "localPath") == .localSkill, "skill install classifier failed")
        require(IntegrationBrand.skillInventory(identifier: "github-helper", description: "GitHub tools") == .github, "skill inventory classifier failed")

        for feature in [
            "pdfImport",
            "arxiv",
            "provenance",
            "extensions",
            "vaultMCP",
            "browser",
            "meetingNote",
            "voice",
        ] {
            require(IntegrationBrand.landingFeature(rawValue: feature) != .generic, "landing feature logo fell to generic: \(feature)")
        }

        for provider in ProviderBrand.allCases {
            require(!provider.displayName.isEmpty, "empty ProviderBrand displayName for \(provider.rawValue)")
            require(!provider.sfSymbolFallback.isEmpty, "empty ProviderBrand fallback for \(provider.rawValue)")
            if let assetName = provider.assetName {
                let assetDir = root
                    .appendingPathComponent("Epistemos/Assets.xcassets", isDirectory: true)
                    .appendingPathComponent("\(assetName).imageset", isDirectory: true)
                require(FileManager.default.fileExists(atPath: assetDir.path), "missing provider logo imageset \(assetName)")
                require(hasSVG(in: assetDir), "provider logo imageset has no SVG \(assetName)")
            }
        }

        require(ProviderBrand.cloud(.anthropic) == .claude, "Anthropic cloud brand failed")
        require(ProviderBrand.cloud(.anthropic, accountRuntime: true) == .claudeCode, "Claude Code account brand failed")
        require(ProviderBrand.cloud(.openAI, accountRuntime: true) == .codex, "Codex account brand failed")
        require(ProviderBrand.local(modelID: "DeepSeek-R1-Distill-Qwen-7B-4bit") == .deepseek, "DeepSeek before Qwen classifier failed")
        require(ProviderBrand.local(modelID: "qwqFlagship32B4Bit") == .qwen, "QwQ classifier failed")
        require(ProviderBrand.fromLabel("Codex") == .codex, "Codex label classifier failed")
        require(ProviderBrand.fromLabel("DeepSeek R1 Distill Qwen 7B") == .deepseek, "DeepSeek label classifier failed")

        for forbidden in ["URLSession", "Process(", "subprocess", "curl "] {
            require(!integrationSource.contains(forbidden), "IntegrationBrand registry must not fetch or spawn: \(forbidden)")
        }

        print("whole-app logos smoke OK: integration_brands=\(IntegrationBrand.allCases.count) provider_brands=\(ProviderBrand.allCases.count) checked_assets=true runtime_downloads=false")
    }

    private static func hasSVG(in directory: URL) -> Bool {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        return contents.contains { $0.pathExtension.lowercased() == "svg" }
    }

    private static func read(_ relativePath: String, root: URL) -> String {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            fail("could not read \(relativePath)")
        }
        return text
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("whole-app logos smoke failed: \(message)\n".utf8))
        Foundation.exit(1)
    }
}
