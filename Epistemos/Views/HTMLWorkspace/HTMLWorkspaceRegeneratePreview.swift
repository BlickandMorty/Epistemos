import Foundation

nonisolated enum HTMLWorkspaceRegeneratePreview {
    static func candidatePackage(
        from response: String,
        basePackage: HTMLWorkspacePackage,
        expectedContentHash: String
    ) -> HTMLWorkspacePackage? {
        guard let patchResponse = try? HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: response,
            package: basePackage,
            expectedContentHash: expectedContentHash
        ),
              let parseResult = try? HTMLWorkspacePatchCommandParser.parse(patchResponse),
              parseResult.batches.count == 1,
              let batch = parseResult.batches.first,
              batch.operations.count == 1,
              let operation = batch.operations.first,
              (batch.workspaceID ?? basePackage.manifest.id) == basePackage.manifest.id,
              (batch.expectedContentHash ?? expectedContentHash) == expectedContentHash,
              case .replaceDocument(let replacement) = operation else {
            return nil
        }
        return package(from: replacement, basePackage: basePackage)
    }

    static func loadingPackage(
        from package: HTMLWorkspacePackage,
        instruction: String
    ) -> HTMLWorkspacePackage {
        let request = boundedInstruction(instruction)
        let dataJSON = dataJSON(for: request)
        let indexHTML = """
        <main class="regenerate-preview" data-regenerate-preview>
          <section class="regenerate-preview__panel" aria-live="polite">
            <p class="regenerate-preview__eyebrow">Regenerating surface</p>
            <h1>Building the replacement site</h1>
            <p class="regenerate-preview__request">\(escapeHTML(request))</p>
            <div class="regenerate-preview__meter" aria-hidden="true">
              <span></span>
              <span></span>
              <span></span>
            </div>
          </section>
        </main>
        """
        let styleCSS = """
        :root {
          color-scheme: light dark;
        }

        .regenerate-preview {
          min-height: 100vh;
          display: grid;
          place-items: center;
          padding: clamp(24px, 7vw, 72px);
          background: var(--epistemos-workspace-bg, Canvas);
          color: var(--epistemos-workspace-fg, CanvasText);
          font-family: var(--epistemos-workspace-body-font, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif);
        }

        .regenerate-preview__panel {
          width: min(720px, 100%);
          display: grid;
          gap: 18px;
          padding: clamp(24px, 5vw, 44px);
          border-radius: 8px;
          background: var(--epistemos-workspace-card, color-mix(in srgb, Canvas 94%, CanvasText 6%));
          box-shadow: 0 18px 46px color-mix(in srgb, var(--epistemos-workspace-fg, CanvasText) 12%, transparent);
        }

        .regenerate-preview__eyebrow {
          margin: 0;
          font-size: 0.78rem;
          font-weight: 700;
          letter-spacing: 0;
          text-transform: uppercase;
          color: var(--epistemos-workspace-muted, color-mix(in srgb, CanvasText 62%, transparent));
        }

        .regenerate-preview h1 {
          margin: 0;
          font-size: clamp(2rem, 5vw, 4.25rem);
          line-height: 0.96;
          letter-spacing: 0;
          font-family: var(--epistemos-workspace-title-font, inherit);
        }

        .regenerate-preview__request {
          margin: 0;
          max-width: 62ch;
          font-size: clamp(1rem, 2vw, 1.2rem);
          line-height: 1.55;
          color: color-mix(in srgb, var(--epistemos-workspace-fg, CanvasText) 72%, transparent);
        }

        .regenerate-preview__meter {
          display: flex;
          gap: 8px;
          align-items: center;
          min-height: 18px;
        }

        .regenerate-preview__meter span {
          width: 8px;
          height: 8px;
          border-radius: 999px;
          background: var(--epistemos-workspace-accent, LinkText);
          animation: regenerate-preview-pulse 1.15s ease-in-out infinite;
        }

        .regenerate-preview__meter span:nth-child(2) {
          animation-delay: 0.14s;
        }

        .regenerate-preview__meter span:nth-child(3) {
          animation-delay: 0.28s;
        }

        @keyframes regenerate-preview-pulse {
          0%, 80%, 100% { opacity: 0.28; transform: translateY(0); }
          40% { opacity: 1; transform: translateY(-5px); }
        }
        """
        var manifest = package.manifest
        manifest.updatedAt = Int64(Date().timeIntervalSince1970 * 1_000)
        manifest.title = "Regenerating \(package.manifest.title)"
        manifest.contentHash = HTMLWorkspaceDocument.contentHash(
            indexHTML: indexHTML,
            styleCSS: styleCSS,
            scriptJS: "",
            dataJSON: dataJSON,
            routes: [:],
            assets: [:]
        )
        return HTMLWorkspacePackage(
            manifest: manifest,
            indexHTML: indexHTML,
            styleCSS: styleCSS,
            scriptJS: "",
            dataJSON: dataJSON
        )
    }

    private static func package(
        from replacement: HTMLWorkspaceDocumentReplacement,
        basePackage: HTMLWorkspacePackage
    ) -> HTMLWorkspacePackage {
        let routes = replacement.routes ?? basePackage.routes
        let assets = replacement.assets ?? basePackage.assets
        var manifest = basePackage.manifest
        if let title = replacement.title {
            manifest.title = title
        }
        manifest.updatedAt = Int64(Date().timeIntervalSince1970 * 1_000)
        manifest.contentHash = HTMLWorkspaceDocument.contentHash(
            indexHTML: replacement.html,
            styleCSS: replacement.css,
            scriptJS: replacement.js,
            dataJSON: replacement.dataJSON,
            routes: routes,
            assets: assets
        )
        manifest.generationProvenance = HTMLWorkspaceGenerationProvenance(
            producer: .agent,
            operation: .regenerate,
            generatedAt: manifest.updatedAt,
            previousContentHash: HTMLWorkspaceDocument.contentHash(
                indexHTML: basePackage.indexHTML,
                styleCSS: basePackage.styleCSS,
                scriptJS: basePackage.scriptJS,
                dataJSON: basePackage.dataJSON,
                routes: basePackage.routes,
                assets: basePackage.assets
            ),
            contentHash: manifest.contentHash,
            reversibleSnapshotName: HTMLWorkspacePatchApplier.reversibleSnapshotName(for: basePackage),
            toolId: HTMLWorkspaceGenerationProvenance.patchToolID
        )
        return HTMLWorkspacePackage(
            manifest: manifest,
            indexHTML: replacement.html,
            styleCSS: replacement.css,
            scriptJS: replacement.js,
            dataJSON: replacement.dataJSON,
            routes: routes,
            assets: assets,
            snapshots: basePackage.snapshots
        )
    }

    private static func boundedInstruction(_ instruction: String) -> String {
        let bounded = String(instruction.prefix(240 + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 240 else { return trimmed }
        return String(trimmed.prefix(240 - 3)) + "..."
    }

    private static func dataJSON(for request: String) -> String {
        let payload = [
            "status": "regenerating",
            "request": request,
        ]
        guard let data = try? JSONEncoder.epdocCanonical.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"status":"regenerating"}"#
        }
        return json
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
