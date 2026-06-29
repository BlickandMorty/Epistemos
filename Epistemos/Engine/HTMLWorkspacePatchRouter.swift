import AppKit
import Foundation

nonisolated public enum HTMLWorkspacePatchRouterError: Error, CustomStringConvertible, LocalizedError, Equatable {
    case noPatchBlocks
    case malformedPatchJSON
    case tooManyOperations(count: Int)
    case unsafeSource(reason: String)
    case oversizedSource(kind: String, count: Int)
    case oversizedAsset(name: String, count: Int)
    case targetWorkspaceNotFound(String)
    case contentHashMismatch(expected: String, actual: String)

    public var description: String {
        switch self {
        case .noPatchBlocks:
            return "No HTML Workspace patch block was found."
        case .malformedPatchJSON:
            return "HTML Workspace patch JSON is malformed."
        case .tooManyOperations(let count):
            return "HTML Workspace patch has too many operations: \(count)."
        case .unsafeSource(let reason):
            return "HTML Workspace patch contains unsafe source: \(reason)."
        case .oversizedSource(let kind, let count):
            return "HTML Workspace \(kind) source is too large: \(count) characters."
        case .oversizedAsset(let name, let count):
            return "HTML Workspace asset \(name) is too large: \(count) bytes."
        case .targetWorkspaceNotFound(let id):
            return "HTML Workspace \(id) is not open."
        case .contentHashMismatch(let expected, let actual):
            return "HTML Workspace content changed before patching. Expected \(expected), got \(actual)."
        }
    }

    public var errorDescription: String? {
        description
    }
}

nonisolated public enum HTMLWorkspacePatchCommandLimits {
    public static let maxOperations = 16
    public static let maxHTMLCharacters = 400_000
    public static let maxCSSCharacters = 240_000
    public static let maxJSCharacters = 240_000
    public static let maxDataJSONCharacters = 240_000
    public static let maxAssetBytes = 2_000_000
}

nonisolated public struct HTMLWorkspacePatchCommandBatch: Codable, Sendable, Equatable {
    public var workspaceID: String?
    public var expectedContentHash: String?
    public var operations: [HTMLWorkspacePatchCommand]

    public init(
        workspaceID: String? = nil,
        expectedContentHash: String? = nil,
        operations: [HTMLWorkspacePatchCommand]
    ) {
        self.workspaceID = workspaceID
        self.expectedContentHash = expectedContentHash
        self.operations = operations
    }

    private enum CodingKeys: String, CodingKey {
        case workspaceID = "workspace_id"
        case expectedContentHash = "expected_content_hash"
        case operations
    }
}

nonisolated public enum HTMLWorkspacePatchCommand: Codable, Sendable, Equatable {
    case replaceDocument(HTMLWorkspaceDocumentReplacement)
    case replaceHTML(String)
    case replaceCSS(String)
    case replaceJS(String)
    case replaceDataJSON(String)
    case insertBlock(html: String, location: HTMLWorkspaceBlockInsertion.Location)
    case insertChart(HTMLWorkspaceChartSpec)
    case updateStyleRule(HTMLWorkspaceStyleRulePatch)
    case addAsset(name: String, base64: String)
    case captureSnapshot(name: String)

    private enum CodingKeys: String, CodingKey {
        case type
        case html
        case css
        case js
        case json
        case title
        case location
        case chart
        case selector
        case declarations
        case name
        case base64
    }

    private enum OperationType: String, Codable {
        case replaceDocument
        case regenerate
        case replaceHTML
        case replaceCSS
        case replaceJS
        case replaceDataJSON
        case insertBlock
        case insertChart
        case updateStyleRule
        case addAsset
        case captureSnapshot
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OperationType.self, forKey: .type)
        switch type {
        case .replaceDocument, .regenerate:
            self = .replaceDocument(HTMLWorkspaceDocumentReplacement(
                title: try container.decodeIfPresent(String.self, forKey: .title),
                html: try container.decode(String.self, forKey: .html),
                css: try container.decode(String.self, forKey: .css),
                js: try container.decode(String.self, forKey: .js),
                dataJSON: try container.decode(String.self, forKey: .json)
            ))
        case .replaceHTML:
            self = .replaceHTML(try container.decode(String.self, forKey: .html))
        case .replaceCSS:
            self = .replaceCSS(try container.decode(String.self, forKey: .css))
        case .replaceJS:
            self = .replaceJS(try container.decode(String.self, forKey: .js))
        case .replaceDataJSON:
            self = .replaceDataJSON(try container.decode(String.self, forKey: .json))
        case .insertBlock:
            let location = try container.decodeIfPresent(HTMLWorkspaceBlockInsertion.Location.self, forKey: .location) ?? .append
            self = .insertBlock(
                html: try container.decode(String.self, forKey: .html),
                location: location
            )
        case .insertChart:
            self = .insertChart(try container.decode(HTMLWorkspaceChartSpec.self, forKey: .chart))
        case .updateStyleRule:
            self = .updateStyleRule(HTMLWorkspaceStyleRulePatch(
                selector: try container.decode(String.self, forKey: .selector),
                declarations: try container.decode([String: String].self, forKey: .declarations)
            ))
        case .addAsset:
            self = .addAsset(
                name: try container.decode(String.self, forKey: .name),
                base64: try container.decode(String.self, forKey: .base64)
            )
        case .captureSnapshot:
            self = .captureSnapshot(name: try container.decode(String.self, forKey: .name))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .replaceDocument(let replacement):
            try container.encode(OperationType.replaceDocument, forKey: .type)
            try container.encodeIfPresent(replacement.title, forKey: .title)
            try container.encode(replacement.html, forKey: .html)
            try container.encode(replacement.css, forKey: .css)
            try container.encode(replacement.js, forKey: .js)
            try container.encode(replacement.dataJSON, forKey: .json)
        case .replaceHTML(let html):
            try container.encode(OperationType.replaceHTML, forKey: .type)
            try container.encode(html, forKey: .html)
        case .replaceCSS(let css):
            try container.encode(OperationType.replaceCSS, forKey: .type)
            try container.encode(css, forKey: .css)
        case .replaceJS(let js):
            try container.encode(OperationType.replaceJS, forKey: .type)
            try container.encode(js, forKey: .js)
        case .replaceDataJSON(let json):
            try container.encode(OperationType.replaceDataJSON, forKey: .type)
            try container.encode(json, forKey: .json)
        case .insertBlock(let html, let location):
            try container.encode(OperationType.insertBlock, forKey: .type)
            try container.encode(html, forKey: .html)
            try container.encode(location, forKey: .location)
        case .insertChart(let chart):
            try container.encode(OperationType.insertChart, forKey: .type)
            try container.encode(chart, forKey: .chart)
        case .updateStyleRule(let rule):
            try container.encode(OperationType.updateStyleRule, forKey: .type)
            try container.encode(rule.selector, forKey: .selector)
            try container.encode(rule.declarations, forKey: .declarations)
        case .addAsset(let name, let base64):
            try container.encode(OperationType.addAsset, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(base64, forKey: .base64)
        case .captureSnapshot(let name):
            try container.encode(OperationType.captureSnapshot, forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }

    public func patchOperation() throws -> HTMLWorkspacePatchOperation {
        try validate()
        switch self {
        case .replaceDocument(let replacement):
            return .replaceDocument(replacement)
        case .replaceHTML(let html):
            return .replaceHTML(html)
        case .replaceCSS(let css):
            return .replaceCSS(css)
        case .replaceJS(let js):
            return .replaceJS(js)
        case .replaceDataJSON(let json):
            return .replaceDataJSON(json)
        case .insertBlock(let html, let location):
            return .insertBlock(HTMLWorkspaceBlockInsertion(html: html, location: location))
        case .insertChart(let chart):
            return .insertChart(chart)
        case .updateStyleRule(let rule):
            return .updateStyleRule(rule)
        case .addAsset(let name, let base64):
            guard let data = Data(base64Encoded: base64) else {
                throw HTMLWorkspacePackageError.invalidPackagePath(name: name)
            }
            guard data.count <= HTMLWorkspacePatchCommandLimits.maxAssetBytes else {
                throw HTMLWorkspacePatchRouterError.oversizedAsset(name: name, count: data.count)
            }
            return .addAsset(HTMLWorkspaceAsset(name: name, data: data))
        case .captureSnapshot(let name):
            return .captureSnapshot(name: name)
        }
    }

    private func validate() throws {
        switch self {
        case .replaceDocument(let replacement):
            try Self.validateHTML(replacement.html)
            try Self.validateSource(replacement.css, kind: "CSS", maxCharacters: HTMLWorkspacePatchCommandLimits.maxCSSCharacters)
            try Self.validateJavaScript(replacement.js)
            try Self.validateDataJSON(replacement.dataJSON)
        case .replaceHTML(let html), .insertBlock(let html, _):
            try Self.validateHTML(html)
        case .replaceCSS(let css):
            try Self.validateSource(css, kind: "CSS", maxCharacters: HTMLWorkspacePatchCommandLimits.maxCSSCharacters)
        case .replaceJS(let js):
            try Self.validateJavaScript(js)
        case .replaceDataJSON(let json):
            try Self.validateDataJSON(json)
        case .insertChart(let chart):
            try Self.validateChart(chart)
        case .updateStyleRule(let rule):
            _ = try HTMLWorkspacePatchApplier.apply(
                .updateStyleRule(rule),
                to: HTMLWorkspacePackage.defaultPackage()
            )
        case .addAsset(let name, let base64):
            try HTMLWorkspacePackage.validatePackageFileName(name)
            guard let data = Data(base64Encoded: base64) else {
                throw HTMLWorkspacePackageError.invalidPackagePath(name: name)
            }
            guard data.count <= HTMLWorkspacePatchCommandLimits.maxAssetBytes else {
                throw HTMLWorkspacePatchRouterError.oversizedAsset(name: name, count: data.count)
            }
        case .captureSnapshot(let name):
            try HTMLWorkspacePackage.validatePackageFileName(name)
        }
    }

    private static func validateHTML(_ html: String) throws {
        try validateSource(html, kind: "HTML", maxCharacters: HTMLWorkspacePatchCommandLimits.maxHTMLCharacters)
        let lowercased = html.lowercased()
        let unsafeFragments = ["<script", "javascript:"]
        if let match = unsafeFragments.first(where: { lowercased.contains($0) }) {
            throw HTMLWorkspacePatchRouterError.unsafeSource(reason: match)
        }
        if containsAppBridgeReference(in: html) {
            throw HTMLWorkspacePatchRouterError.unsafeSource(reason: "window.webkit.messageHandlers")
        }
        if html.range(
            of: #"(^|[\s/<])on[a-z][a-z0-9_-]*\s*="#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            throw HTMLWorkspacePatchRouterError.unsafeSource(reason: "inline event handler")
        }
    }

    private static func validateJavaScript(_ js: String) throws {
        try validateSource(js, kind: "JS", maxCharacters: HTMLWorkspacePatchCommandLimits.maxJSCharacters)
        let lowercased = js.lowercased()
        let unsafeFragments = ["indexeddb", "localstorage", "sessionstorage"]
        if let match = unsafeFragments.first(where: { lowercased.contains($0) }) {
            throw HTMLWorkspacePatchRouterError.unsafeSource(reason: match)
        }
        if containsAppBridgeReference(in: js) {
            throw HTMLWorkspacePatchRouterError.unsafeSource(reason: "window.webkit.messageHandlers")
        }
    }

    private static func containsAppBridgeReference(in source: String) -> Bool {
        var normalized = source.lowercased().filter { !$0.isWhitespace }
        normalized = normalized.replacingOccurrences(of: "?.[", with: "[")

        for (token, replacement) in [
            ("[\"webkit\"]", ".webkit"),
            ("['webkit']", ".webkit"),
            ("[\"messagehandlers\"]", ".messagehandlers"),
            ("['messagehandlers']", ".messagehandlers"),
        ] {
            normalized = normalized.replacingOccurrences(of: token, with: replacement)
        }

        normalized = normalized.replacingOccurrences(of: "?.", with: ".")
        while normalized.contains("..") {
            normalized = normalized.replacingOccurrences(of: "..", with: ".")
        }

        return normalized.contains("window.webkit.messagehandlers")
            || normalized.contains("globalthis.webkit.messagehandlers")
            || normalized.contains("webkit.messagehandlers")
    }

    private static func validateDataJSON(_ json: String) throws {
        try validateSource(json, kind: "data JSON", maxCharacters: HTMLWorkspacePatchCommandLimits.maxDataJSONCharacters)
        guard let data = json.data(using: .utf8) else {
            throw HTMLWorkspacePatchRouterError.malformedPatchJSON
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw HTMLWorkspacePatchRouterError.malformedPatchJSON
        }
    }

    private static func validateSource(_ source: String, kind: String, maxCharacters: Int) throws {
        guard source.count <= maxCharacters else {
            throw HTMLWorkspacePatchRouterError.oversizedSource(kind: kind, count: source.count)
        }
    }

    private static func validateChart(_ chart: HTMLWorkspaceChartSpec) throws {
        try HTMLWorkspacePackage.validatePackageFileName(chart.id)
        guard chart.values.count <= 200 else {
            throw HTMLWorkspacePatchRouterError.tooManyOperations(count: chart.values.count)
        }
        for datum in chart.values {
            guard datum.value.isFinite else {
                throw HTMLWorkspacePackageError.invalidStyleRule(reason: "chart value")
            }
        }
    }
}

extension HTMLWorkspaceBlockInsertion.Location: Codable {
    private enum LocationName: String, Codable {
        case append
        case beforeClosingBody
    }

    public init(from decoder: Decoder) throws {
        let name = try LocationName(from: decoder)
        switch name {
        case .append:
            self = .append
        case .beforeClosingBody:
            self = .beforeClosingBody
        }
    }

    public func encode(to encoder: Encoder) throws {
        let name: LocationName = switch self {
        case .append: .append
        case .beforeClosingBody: .beforeClosingBody
        }
        try name.encode(to: encoder)
    }
}

nonisolated public struct HTMLWorkspacePatchParseResult: Sendable, Equatable {
    public var batches: [HTMLWorkspacePatchCommandBatch]
    public var cleanedText: String
}

nonisolated public enum HTMLWorkspacePatchCommandParser {
    public static let fencedLanguage = "epistemos-html-workspace-patch"

    public static func parse(_ response: String) throws -> HTMLWorkspacePatchParseResult {
        let expression = try NSRegularExpression(
            pattern: #"(?s)```epistemos-html-workspace-patch\s*(\{.*?\})\s*```"#
        )
        let range = NSRange(response.startIndex..<response.endIndex, in: response)
        let matches = expression.matches(in: response, range: range)
        guard !matches.isEmpty else {
            return HTMLWorkspacePatchParseResult(batches: [], cleanedText: response)
        }

        var batches: [HTMLWorkspacePatchCommandBatch] = []
        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: response) else {
                throw HTMLWorkspacePatchRouterError.malformedPatchJSON
            }
            let json = String(response[jsonRange])
            guard let data = json.data(using: .utf8) else {
                throw HTMLWorkspacePatchRouterError.malformedPatchJSON
            }
            do {
                let batch = try JSONDecoder.epdocCanonical.decode(HTMLWorkspacePatchCommandBatch.self, from: data)
                try validate(batch)
                batches.append(batch)
            } catch let error as HTMLWorkspacePatchRouterError {
                throw error
            } catch let error as HTMLWorkspacePackageError {
                throw error
            } catch {
                throw HTMLWorkspacePatchRouterError.malformedPatchJSON
            }
        }

        let cleaned = expression.stringByReplacingMatches(
            in: response,
            range: range,
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return HTMLWorkspacePatchParseResult(batches: batches, cleanedText: cleaned)
    }

    public static func validate(_ batch: HTMLWorkspacePatchCommandBatch) throws {
        guard batch.operations.count <= HTMLWorkspacePatchCommandLimits.maxOperations else {
            throw HTMLWorkspacePatchRouterError.tooManyOperations(count: batch.operations.count)
        }
        for operation in batch.operations {
            _ = try operation.patchOperation()
        }
    }
}

@MainActor
struct HTMLWorkspacePatchApplicationResult: Sendable, Equatable {
    public var visibleResponse: String
    public var appliedOperations: Int
    public var errors: [String]

    public static func unchanged(_ response: String) -> HTMLWorkspacePatchApplicationResult {
        HTMLWorkspacePatchApplicationResult(
            visibleResponse: response,
            appliedOperations: 0,
            errors: []
        )
    }
}

@MainActor
enum HTMLWorkspacePatchRouter {
    static func contextPack(for attachments: [ContextAttachment]) -> String? {
        let htmlAttachments = attachments.filter { $0.kind == .htmlWorkspace }
        guard !htmlAttachments.isEmpty else { return nil }

        let sections = htmlAttachments.compactMap { attachment -> String? in
            guard let document = document(matching: attachment) else { return nil }
            let snapshot = document.chatContextSnapshot()
            let targetLines = """
            Document Target:
            Surface ID: \(snapshot.workspaceID)
            Surface Kind: htmlWorkspace
            Pane: preview
            Selected Range: none
            Allowed Operations: replaceDocument, regenerate, replaceHTML, replaceCSS, replaceJS, replaceDataJSON, insertBlock, insertChart, updateStyleRule, addAsset, captureSnapshot
            """
            return """
            ### Attached HTML Workspace: \(snapshot.title)
            Workspace ID: \(snapshot.workspaceID)
            Content Hash: \(snapshot.contentHash)
            Sandbox: offline=\(!snapshot.sandboxPolicy.allowNetwork), app_bridge=\(snapshot.sandboxPolicy.allowAppBridge)
            \(targetLines)
            Priority: Active workspace context. Use structured HTML Workspace patch blocks when the user asks you to edit, animate, visualize, restyle, or add UI.
            Patch Format:
            ```epistemos-html-workspace-patch
            {"workspace_id":"\(snapshot.workspaceID)","expected_content_hash":"\(snapshot.contentHash)","operations":[{"type":"insertBlock","html":"<section></section>","location":"append"}]}
            ```
            Allowed operation types: replaceDocument, regenerate, replaceHTML, replaceCSS, replaceJS, insertBlock, insertChart, updateStyleRule, addAsset, captureSnapshot.
            Full-surface replacement: use replaceDocument/regenerate when the user asks to rebuild the whole page; include "html", "css", "js", and "json" in one operation.
            Data operation: replaceDataJSON with a "json" string for local structured data.
            Safety: Do not request network or app bridge access. Keep behavior local/offline. Put JavaScript in replaceJS, not inline HTML event handlers.

            Current HTML:
            \(snapshot.html)

            Current CSS:
            \(snapshot.css)

            Current JS:
            \(snapshot.js)

            Current data.json:
            \(snapshot.dataJSON)
            """
        }

        guard !sections.isEmpty else { return nil }
        return sections.joined(separator: "\n\n")
    }

    static func applyPatchCommands(
        in response: String,
        attachments: [ContextAttachment]
    ) -> HTMLWorkspacePatchApplicationResult {
        let parseResult: HTMLWorkspacePatchParseResult
        do {
            parseResult = try HTMLWorkspacePatchCommandParser.parse(response)
        } catch {
            return HTMLWorkspacePatchApplicationResult(
                visibleResponse: appendPatchStatus(to: response, status: "HTML Workspace patch was not applied: \(error.localizedDescription)"),
                appliedOperations: 0,
                errors: [error.localizedDescription]
            )
        }
        guard !parseResult.batches.isEmpty else {
            return .unchanged(response)
        }

        var appliedCount = 0
        var errors: [String] = []
        for batch in parseResult.batches {
            do {
                let document = try targetDocument(for: batch, attachments: attachments)
                if let expected = batch.expectedContentHash {
                    let actual = HTMLWorkspaceDocument.contentHash(
                        indexHTML: document.package.indexHTML,
                        styleCSS: document.package.styleCSS,
                        scriptJS: document.package.scriptJS,
                        dataJSON: document.package.dataJSON
                    )
                    guard expected == actual else {
                        throw HTMLWorkspacePatchRouterError.contentHashMismatch(expected: expected, actual: actual)
                    }
                }
                for command in batch.operations {
                    try document.applyPatch(command.patchOperation())
                    appliedCount += 1
                }
            } catch {
                errors.append(error.localizedDescription)
            }
        }

        var visible = response
        if appliedCount > 0 {
            visible = appendPatchStatus(to: visible, status: "Applied \(appliedCount) HTML Workspace change\(appliedCount == 1 ? "" : "s").")
        }
        if !errors.isEmpty {
            visible = appendPatchStatus(to: visible, status: "Some HTML Workspace changes were not applied: \(errors.joined(separator: "; "))")
        }
        return HTMLWorkspacePatchApplicationResult(
            visibleResponse: visible.isEmpty ? "Applied \(appliedCount) HTML Workspace change\(appliedCount == 1 ? "" : "s")." : visible,
            appliedOperations: appliedCount,
            errors: errors
        )
    }

    static func document(matching attachment: ContextAttachment) -> HTMLWorkspaceDocument? {
        let targetID = attachment.targetId.trimmingCharacters(in: .whitespacesAndNewlines)
        let documents = orderedOpenDocuments()
        if !targetID.isEmpty,
           let match = documents.first(where: { $0.package.manifest.id == targetID }) {
            return match
        }
        return nil
    }

    private static func targetDocument(
        for batch: HTMLWorkspacePatchCommandBatch,
        attachments: [ContextAttachment]
    ) throws -> HTMLWorkspaceDocument {
        let htmlAttachments = attachments.filter { $0.kind == .htmlWorkspace }
        if let workspaceID = batch.workspaceID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !workspaceID.isEmpty {
            if let attachment = htmlAttachments.first(where: { $0.targetId == workspaceID }),
               let document = document(matching: attachment) {
                return document
            }
            if let document = orderedOpenDocuments().first(where: { $0.package.manifest.id == workspaceID }) {
                return document
            }
            throw HTMLWorkspacePatchRouterError.targetWorkspaceNotFound(workspaceID)
        }

        if let attachment = htmlAttachments.first,
           let document = document(matching: attachment) {
            return document
        }
        if let active = orderedOpenDocuments().first {
            return active
        }
        throw HTMLWorkspacePatchRouterError.targetWorkspaceNotFound("active")
    }

    private static func orderedOpenDocuments() -> [HTMLWorkspaceDocument] {
        let controller = NSDocumentController.shared
        var documents = controller.documents
        if let current = controller.currentDocument {
            documents.removeAll { $0 === current }
            documents.insert(current, at: 0)
        }
        return documents.compactMap { document in
            guard let htmlDocument = document as? HTMLWorkspaceDocument else { return nil }
            let hasVisibleWindow = htmlDocument.windowControllers.contains { controller in
                controller.window?.isKeyWindow == true || controller.window?.isVisible == true
            }
            return hasVisibleWindow ? htmlDocument : nil
        }
    }

    private static func appendPatchStatus(to response: String, status: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? status : "\(trimmed)\n\n\(status)"
    }
}
