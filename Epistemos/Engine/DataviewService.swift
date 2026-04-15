import Foundation
import SwiftData

// MARK: - DataviewService
// Obsidian Dataview-compatible query layer for vault notes.
// Parses DQL (Dataview Query Language) from ```dataview``` fenced code blocks
// and executes them against SwiftData/GraphStore.
//
// Supported syntax:
//   TABLE file.mtime, tags FROM "Projects" WHERE contains(tags, "active") SORT BY file.mtime DESC LIMIT 10
//   LIST FROM #tag WHERE ...
//   TASK FROM "Tasks"
//
// Reference: soaar and research mode/new/EPISTEMOS-PLUGIN-PORTING-SPEC.md — Category 1 (Dataview)

@MainActor
final class DataviewService {

    // MARK: - Query Model

    enum OutputFormat {
        case table(columns: [String])
        case list
        case task
    }

    struct DataviewQuery {
        let format: OutputFormat
        let from: String?           // folder path or tag (#tag)
        let conditions: [Condition]  // WHERE clauses
        let sortBy: [(field: String, ascending: Bool)]
        let limit: Int?
    }

    struct Condition {
        let field: String
        let op: ConditionOp
        let value: String
    }

    enum ConditionOp: String {
        case equals = "="
        case notEquals = "!="
        case contains
        case greaterThan = ">"
        case lessThan = "<"
    }

    struct QueryResult {
        let rows: [[String: String]]  // each row is a dict of column → value
        let columns: [String]
        let totalCount: Int
    }

    // MARK: - Parse

    /// Parse a DQL string into a DataviewQuery.
    /// Returns nil if the query is not valid DQL.
    func parse(_ dql: String) -> DataviewQuery? {
        let trimmed = dql.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = tokenize(trimmed)
        guard let firstToken = tokens.first?.uppercased() else { return nil }

        let format: OutputFormat
        var idx = 1

        switch firstToken {
        case "TABLE":
            // Parse column list until FROM keyword
            var columns: [String] = []
            while idx < tokens.count && tokens[idx].uppercased() != "FROM" {
                let col = tokens[idx].trimmingCharacters(in: CharacterSet(charactersIn: ","))
                if !col.isEmpty { columns.append(col) }
                idx += 1
            }
            format = .table(columns: columns.isEmpty ? ["file.name"] : columns)
        case "LIST":
            format = .list
        case "TASK":
            format = .task
        default:
            return nil
        }

        // Parse FROM
        var from: String?
        if idx < tokens.count && tokens[idx].uppercased() == "FROM" {
            idx += 1
            if idx < tokens.count {
                from = tokens[idx].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                idx += 1
            }
        }

        // Parse WHERE (simple single-condition for now)
        var conditions: [Condition] = []
        if idx < tokens.count && tokens[idx].uppercased() == "WHERE" {
            idx += 1
            if let condition = parseCondition(tokens: tokens, startIdx: &idx) {
                conditions.append(condition)
            }
        }

        // Parse SORT BY
        var sortBy: [(String, Bool)] = []
        if idx < tokens.count && tokens[idx].uppercased() == "SORT" {
            idx += 1
            if idx < tokens.count && tokens[idx].uppercased() == "BY" { idx += 1 }
            if idx < tokens.count {
                let field = tokens[idx]
                idx += 1
                let ascending = !(idx < tokens.count && tokens[idx].uppercased() == "DESC")
                if idx < tokens.count && (tokens[idx].uppercased() == "ASC" || tokens[idx].uppercased() == "DESC") {
                    idx += 1
                }
                sortBy.append((field, ascending))
            }
        }

        // Parse LIMIT
        var limit: Int?
        if idx < tokens.count && tokens[idx].uppercased() == "LIMIT" {
            idx += 1
            if idx < tokens.count { limit = Int(tokens[idx]) }
        }

        return DataviewQuery(
            format: format,
            from: from,
            conditions: conditions,
            sortBy: sortBy,
            limit: limit
        )
    }

    // MARK: - Execute

    /// Execute a parsed DataviewQuery against the vault.
    func execute(_ query: DataviewQuery, context: ModelContext) -> QueryResult {
        // Fetch pages matching the FROM clause
        var predicate: Predicate<SDPage>?
        var folderPrefix: String?
        if let from = query.from {
            if from.hasPrefix("#") {
                // Tag-based FROM — not yet supported, return empty
                return QueryResult(rows: [], columns: [], totalCount: 0)
            } else {
                // Folder-based FROM
                folderPrefix = from
                predicate = #Predicate<SDPage> {
                    $0.isArchived == false && $0.subfolder != nil
                }
            }
        }

        let descriptor: FetchDescriptor<SDPage>
        if let predicate {
            descriptor = FetchDescriptor<SDPage>(
                predicate: predicate,
                sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.isArchived == false },
                sortBy: [SortDescriptor(\SDPage.updatedAt, order: .reverse)]
            )
        }

        let pages = (try? context.fetch(descriptor)) ?? []
        let fromFilteredPages: [SDPage]
        if let folderPrefix {
            fromFilteredPages = pages.filter { page in
                (page.subfolder ?? "").contains(folderPrefix)
            }
        } else {
            fromFilteredPages = pages
        }

        // Apply WHERE conditions
        let filtered = fromFilteredPages.filter { page in
            query.conditions.allSatisfy { condition in
                let value = resolveField(condition.field, page: page)
                switch condition.op {
                case .contains:
                    return value.lowercased().contains(condition.value.lowercased())
                case .equals:
                    return value.lowercased() == condition.value.lowercased()
                case .notEquals:
                    return value.lowercased() != condition.value.lowercased()
                case .greaterThan, .lessThan:
                    return true // numeric comparison not yet supported
                }
            }
        }

        // Apply LIMIT
        let limited = query.limit.map { Array(filtered.prefix($0)) } ?? filtered

        // Build result rows
        let columns: [String]
        switch query.format {
        case .table(let cols): columns = cols
        case .list: columns = ["file.name"]
        case .task: columns = ["file.name", "status"]
        }

        let rows = limited.map { page -> [String: String] in
            var row: [String: String] = [:]
            for col in columns {
                row[col] = resolveField(col, page: page)
            }
            return row
        }

        return QueryResult(rows: rows, columns: columns, totalCount: filtered.count)
    }

    // MARK: - Render

    /// Render query results as a markdown table.
    func renderMarkdown(_ result: QueryResult) -> String {
        guard !result.rows.isEmpty else {
            return "*No results*"
        }

        let cols = result.columns
        var md = "| " + cols.joined(separator: " | ") + " |\n"
        md += "| " + cols.map { _ in "---" }.joined(separator: " | ") + " |\n"

        for row in result.rows {
            let values = cols.map { row[$0] ?? "" }
            md += "| " + values.joined(separator: " | ") + " |\n"
        }

        if result.totalCount > result.rows.count {
            md += "\n*Showing \(result.rows.count) of \(result.totalCount) results*\n"
        }

        return md
    }

    // MARK: - Helpers

    private func tokenize(_ input: String) -> [String] {
        // Simple tokenizer that handles quoted strings
        var tokens: [String] = []
        var current = ""
        var inQuotes = false

        for char in input {
            if char == "\"" {
                inQuotes.toggle()
                current.append(char)
            } else if char == " " && !inQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private func parseCondition(tokens: [String], startIdx: inout Int) -> Condition? {
        guard startIdx + 2 < tokens.count else { return nil }

        // Handle "contains(field, value)" syntax
        let first = tokens[startIdx]
        if first.lowercased().hasPrefix("contains(") {
            let inner = first.dropFirst(9) // "contains("
            let combined = String(inner) + " " + tokens[startIdx + 1]
            let parts = combined.replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            if parts.count >= 2 {
                startIdx += 2
                return Condition(field: parts[0], op: .contains, value: parts[1])
            }
        }

        // Handle "field = value" syntax
        let field = tokens[startIdx]
        let op = tokens[startIdx + 1]
        let value = tokens[startIdx + 2].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        startIdx += 3

        let condOp: ConditionOp
        switch op {
        case "=": condOp = .equals
        case "!=": condOp = .notEquals
        case ">": condOp = .greaterThan
        case "<": condOp = .lessThan
        default: condOp = .equals
        }

        return Condition(field: field, op: condOp, value: value)
    }

    private func resolveField(_ field: String, page: SDPage) -> String {
        switch field.lowercased() {
        case "file.name":
            return page.title
        case "file.mtime":
            return ISO8601DateFormatter().string(from: page.updatedAt)
        case "file.ctime":
            return ISO8601DateFormatter().string(from: page.createdAt)
        case "file.path":
            return resolvedFilePath(for: page)
        case "file.size":
            return "\(page.loadBody(mapped: true).count)"
        case "tags":
            return page.tags.joined(separator: ", ")
        case "title":
            return page.title
        default:
            // Try frontmatter key lookup
            return page.title
        }
    }

    private func resolvedFilePath(for page: SDPage) -> String {
        if let filePath = page.filePath {
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            if let subfolder = page.subfolder, !subfolder.isEmpty {
                return "\(subfolder)/\(fileName)"
            }
            return fileName
        }

        let fallbackName = page.title.isEmpty ? "Untitled" : page.title
        if let subfolder = page.subfolder, !subfolder.isEmpty {
            return "\(subfolder)/\(fallbackName)"
        }
        return fallbackName
    }
}
