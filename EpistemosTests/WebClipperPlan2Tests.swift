import Foundation
import Testing

@testable import Epistemos

@Suite("Plan 2 web clipper")
struct WebClipperPlan2Tests {
    @Test("builder emits source-url frontmatter and strips unsafe HTML")
    func builderSanitizesHTMLAndRecordsSourceURL() throws {
        let document = try WebClipperMarkdownBuilder.document(from: WebClipCaptureDraft(
            title: "",
            sourceURL: "https://example.com/articles/a#section",
            html: """
            <html>
              <head><title>Example Article</title><script>alert("x")</script></head>
              <body><h1>Visible Heading</h1><p>Readable body &amp; <a href="https://example.com/ref?q=1#frag">link text</a>.</p></body>
            </html>
            """,
            plainText: "",
            capturedAt: Date(timeIntervalSince1970: 0)
        ))

        #expect(document.title == "Example Article")
        #expect(document.frontMatter["source-url"] == "https://example.com/articles/a#section")
        #expect(document.frontMatter["source_kind"] == "web_clip")
        #expect(document.markdownBody.contains("Source: <https://example.com/articles/a#section>"))
        #expect(document.markdownBody.contains("Visible Heading"))
        #expect(document.markdownBody.contains("Readable body & [link text](https://example.com/ref?q=1#frag)."))
        #expect(!document.markdownBody.contains("alert("))
        #expect(!document.markdownBody.contains("<script"))
    }

    @Test("builder drops non-web source URLs from frontmatter and body")
    func builderDropsNonWebSourceURLs() throws {
        for sourceURL in ["javascript:alert(1)", "data:text/html,hi", "file:///tmp/private.html", "example.com/no-scheme"] {
            let document = try WebClipperMarkdownBuilder.document(from: WebClipCaptureDraft(
                title: "Unsafe Source",
                sourceURL: sourceURL,
                html: "",
                plainText: "Readable body",
                capturedAt: Date(timeIntervalSince1970: 0)
            ))

            #expect(document.frontMatter["source-url"] == nil)
            #expect(!document.markdownBody.contains("Source: <"))
        }
    }

    @Test("source URL normalizer is shared by builder and sheet")
    func sourceURLNormalizerAcceptsOnlyWebURLs() {
        #expect(WebClipperMarkdownBuilder.normalizedSourceURL(" https://example.com/path?q=1#frag ") == "https://example.com/path?q=1#frag")
        #expect(WebClipperMarkdownBuilder.normalizedSourceURL("http://example.com") == "http://example.com")
        #expect(WebClipperMarkdownBuilder.normalizedSourceURL("javascript:alert(1)") == nil)
        #expect(WebClipperMarkdownBuilder.normalizedSourceURL("data:text/html,hi") == nil)
        #expect(WebClipperMarkdownBuilder.normalizedSourceURL("file:///tmp/private.html") == nil)
        #expect(WebClipperMarkdownBuilder.normalizedSourceURL("example.com/no-scheme") == nil)
        #expect(WebClipperMarkdownBuilder.normalizedSourceURL("https://example.com/\(String(repeating: "a", count: WebClipperMarkdownBuilder.maxSourceURLCharacters))") == nil)
    }

    @Test("notes UI exposes web clipper and createPage accepts metadata before export")
    func notesUIWiresWebClipperToMetadataCreation() throws {
        let workspace = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let sheet = try loadMirroredSourceTextFile("Epistemos/Views/Notes/WebClipperSheet.swift")
        let builder = try loadMirroredSourceTextFile("Epistemos/Engine/WebClipperMarkdownBuilder.swift")
        let vaultSync = try loadMirroredSourceTextFile("Epistemos/Sync/VaultSyncService.swift")
        let vaultIndex = try loadMirroredSourceTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(workspace.contains("@State private var showWebClipperSheet = false"))
        #expect(workspace.contains("WebClipperSheet(theme: ui.theme)"))
        #expect(workspace.contains(#"Label("Clip Web Page", systemImage: "globe")"#))
        #expect(workspace.contains("try await createWebClip(from: draft)"))
        #expect(sheet.contains("TextEditor(text: $captureText)"))
        #expect(sheet.contains("pasteClipboard()"))
        #expect(sheet.contains("NSPasteboard.general"))
        #expect(sheet.contains("NSPasteboard.PasteboardType.html"))
        #expect(sheet.contains("NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)"))
        #expect(sheet.contains("hasInvalidSourceURL"))
        #expect(sheet.contains("Use an http or https source URL."))
        #expect(sheet.contains(".textFieldStyle(.plain)"))
        #expect(sheet.contains("theme.resolved.foreground.color"))
        #expect(sheet.contains(".foregroundStyle(theme.error)"))
        #expect(!sheet.contains(".textFieldStyle(.roundedBorder)"))
        #expect(!sheet.contains(".foregroundStyle(.red)"))
        #expect(sheet.contains("WebClipperMarkdownBuilder.normalizedSourceURL(trimmed)"))
        #expect(sheet.contains("url.flatMap(WebClipperMarkdownBuilder.normalizedSourceURL)"))
        #expect(sheet.contains("sourceURL = normalizedURL"))
        #expect(builder.contains(#""source-url""#))
        #expect(builder.contains("static func normalizedSourceURL"))
        #expect(builder.contains("guard cleaned.count <= maxSourceURLCharacters else { return nil }"))
        #expect(!builder.contains("String(cleaned.prefix(maxSourceURLCharacters))"))
        #expect(builder.contains("stripUnsafeHTML(from: html)"))
        #expect(builder.contains("attributed.enumerateAttribute(.link"))
        #expect(builder.contains("markdownLinkDestination(from: value)"))
        #expect(builder.contains("hasPrefix(\"javascript:\")"))
        #expect(vaultSync.contains("frontMatter: [String: String] = [:]"))
        #expect(vaultSync.contains("page.frontMatter = frontMatter"))
        #expect(vaultIndex.contains("yamlEscapeFrontMatterValue(value)"))
    }
}
