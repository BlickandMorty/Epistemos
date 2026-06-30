import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

nonisolated struct ArxivPaper: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let authors: [String]
    let summary: String
    let published: Date?
    let pdfURL: URL
    let categories: [String]

    var shortID: String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = trimmed.split(separator: "/").last {
            return String(last).replacingOccurrences(of: "v\\d+$", with: "", options: .regularExpression)
        }
        return trimmed
    }
}

nonisolated enum ArxivClientError: LocalizedError, Equatable, Sendable {
    case invalidQuery
    case invalidResponse
    case requestFailed(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Enter an arXiv search query."
        case .invalidResponse:
            return "arXiv returned an invalid response."
        case .requestFailed(let message):
            return "arXiv request failed: \(message)"
        case .parseFailed(let message):
            return "arXiv response could not be parsed: \(message)"
        }
    }
}

nonisolated enum ArxivPDFURLPolicy {
    static let rejectedMessage = "unsupported arXiv PDF URL"
    static let rejectedFinalURLMessage = "final response URL is not an allowed HTTPS arXiv PDF URL"
    private static let pdfPathPrefix = "/pdf/"
    private static let maxArxivIDLength = 80
    private static let newStyleIDPattern = #"^\d{4}\.\d{4,5}(v\d+)?$"#
    private static let oldStyleIDPattern = #"^[A-Za-z-]+(\.[A-Za-z]{2})?/\d{7}(v\d+)?$"#

    static func isAllowed(_ url: URL) -> Bool {
        normalizedAllowedURL(url) != nil
    }

    static func isAllowedHTTPSResponse(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" else {
            return false
        }
        return normalizedAllowedURL(url) != nil
    }

    static func normalizedAllowedURL(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host?.lowercased(),
              host == "arxiv.org" || host == "export.arxiv.org" else {
            return nil
        }
        guard components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }
        guard components.percentEncodedPath == components.path,
              isCanonicalPDFPath(components.path) else {
            return nil
        }
        components.scheme = "https"
        components.host = host
        return components.url
    }

    private static func isCanonicalPDFPath(_ path: String) -> Bool {
        guard path.hasPrefix(pdfPathPrefix) else {
            return false
        }
        let id = String(path.dropFirst(pdfPathPrefix.count))
        guard !id.isEmpty,
              id.count <= maxArxivIDLength else {
            return false
        }
        return isCanonicalArxivID(id)
    }

    private static func isCanonicalArxivID(_ id: String) -> Bool {
        id.range(of: newStyleIDPattern, options: .regularExpression) != nil
            || id.range(of: oldStyleIDPattern, options: .regularExpression) != nil
    }
}

nonisolated struct ArxivClient: Sendable {
    typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    static let maxSearchResponseBytes = 5 * 1024 * 1024
    static let maxSearchQueryCharacters = 512
    static let maxParsedPapers = 50
    static let maxAtomElementTextCharacters = 64 * 1024
    static let maxAtomRepeatedValues = 32

    private let fetch: Fetch

    init(fetch: @escaping Fetch = { request in
        try await URLSession.shared.data(for: request)
    }) {
        self.fetch = fetch
    }

    func search(query: String, maxResults: Int = 10) async throws -> [ArxivPaper] {
        let request = try Self.searchRequest(query: query, maxResults: maxResults)
        do {
            let (data, response) = try await fetch(request)
            try Self.validateSearchResponse(response)
            return try Self.parseSearchResponse(data)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ArxivClientError {
            throw error
        } catch {
            throw ArxivClientError.requestFailed(error.localizedDescription)
        }
    }

    static func searchRequest(query: String, maxResults: Int = 10) throws -> URLRequest {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= maxSearchQueryCharacters else { throw ArxivClientError.invalidQuery }

        var components = URLComponents(string: "https://export.arxiv.org/api/query")
        components?.queryItems = [
            URLQueryItem(name: "search_query", value: searchQueryValue(trimmed)),
            URLQueryItem(name: "sortBy", value: "submittedDate"),
            URLQueryItem(name: "sortOrder", value: "descending"),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "max_results", value: "\(max(1, min(maxResults, 50)))"),
        ]
        guard let url = components?.url else { throw ArxivClientError.invalidQuery }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Epistemos/Plan3-ArxivPull", forHTTPHeaderField: "User-Agent")
        return request
    }

    static func validateSearchResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = http.url,
              isAllowedSearchResponseURL(finalURL) else {
            throw ArxivClientError.invalidResponse
        }
    }

    static func isAllowedSearchResponseURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https",
              let host = url.host?.lowercased(),
              host == "export.arxiv.org" else {
            return false
        }
        return url.path == "/api/query"
    }

    static func parseSearchResponse(_ data: Data) throws -> [ArxivPaper] {
        guard data.count <= maxSearchResponseBytes else {
            throw ArxivClientError.parseFailed("Atom response exceeds 5 MiB limit.")
        }
        guard !data.isEmpty else {
            throw ArxivClientError.parseFailed("Atom response was empty.")
        }
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = ArxivAtomParser()
        parser.delegate = delegate
        guard parser.parse() else {
            let message = parser.parserError?.localizedDescription ?? "Malformed Atom XML."
            throw ArxivClientError.parseFailed(message)
        }
        return delegate.papers
    }

    private static func searchQueryValue(_ query: String) -> String {
        if query.contains(":") {
            return query
        }
        return "all:\(query)"
    }
}

private nonisolated final class ArxivAtomParser: NSObject, XMLParserDelegate {
    private(set) var papers: [ArxivPaper] = []

    private var currentEntry: EntryBuilder?
    private var elementStack: [String] = []
    private var textBuffer = ""
    private var insideAuthor = false

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = normalizedElementName(elementName)
        elementStack.append(name)
        textBuffer = ""

        if name == "entry" {
            currentEntry = EntryBuilder()
        } else if name == "author" {
            insideAuthor = true
        } else if name == "category", let term = attributeDict["term"] {
            currentEntry?.appendCategory(term)
        } else if name == "link" {
            captureLink(attributeDict)
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        guard textBuffer.count < ArxivClient.maxAtomElementTextCharacters else { return }
        let remaining = ArxivClient.maxAtomElementTextCharacters - textBuffer.count
        if string.count <= remaining {
            textBuffer += string
        } else {
            textBuffer += String(string.prefix(remaining))
        }
    }

    func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        let name = normalizedElementName(elementName)
        let text = Self.normalizedText(textBuffer)

        if var entry = currentEntry {
            switch name {
            case "id":
                entry.id = text
            case "title":
                entry.title = text
            case "summary":
                entry.summary = text
            case "published":
                entry.published = Self.date(from: text)
            case "name" where insideAuthor:
                if !text.isEmpty {
                    entry.appendAuthor(text)
                }
            case "entry":
                if papers.count < ArxivClient.maxParsedPapers,
                   let paper = entry.paper {
                    papers.append(paper)
                }
                currentEntry = nil
            default:
                break
            }
            if name != "entry" {
                currentEntry = entry
            }
        }

        if name == "author" {
            insideAuthor = false
        }
        _ = elementStack.popLast()
        textBuffer = ""
    }

    private func captureLink(_ attributes: [String: String]) {
        guard var entry = currentEntry,
              let href = attributes["href"],
              let url = URL(string: href) else {
            return
        }
        let title = attributes["title"]?.lowercased()
        let type = attributes["type"]?.lowercased()
        let looksLikePDFLink = title == "pdf" || type == "application/pdf" || href.contains("/pdf/")
        if looksLikePDFLink, let normalizedURL = ArxivPDFURLPolicy.normalizedAllowedURL(url) {
            entry.pdfURL = normalizedURL
            currentEntry = entry
        }
    }

    private func normalizedElementName(_ name: String) -> String {
        if let suffix = name.split(separator: ":").last {
            return String(suffix)
        }
        return name
    }

    private struct EntryBuilder {
        var id = ""
        var title = ""
        var authors: [String] = []
        var summary = ""
        var published: Date?
        var pdfURL: URL?
        var categories: [String] = []

        mutating func appendAuthor(_ author: String) {
            guard authors.count < ArxivClient.maxAtomRepeatedValues else { return }
            authors.append(author)
        }

        mutating func appendCategory(_ category: String) {
            guard categories.count < ArxivClient.maxAtomRepeatedValues else { return }
            categories.append(category)
        }

        var paper: ArxivPaper? {
            guard !id.isEmpty,
                  !title.isEmpty,
                  let pdfURL else {
                return nil
            }
            return ArxivPaper(
                id: id,
                title: title,
                authors: authors,
                summary: summary,
                published: published,
                pdfURL: pdfURL,
                categories: categories
            )
        }
    }

    private static func normalizedText(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func date(from raw: String) -> Date? {
        ISO8601DateFormatter.arxiv.date(from: raw)
    }
}

private extension ISO8601DateFormatter {
    nonisolated static var arxiv: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if formatter.date(from: "2026-01-01T00:00:00Z") == nil {
            formatter.formatOptions = [.withInternetDateTime]
        }
        return formatter
    }
}
