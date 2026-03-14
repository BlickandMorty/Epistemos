import AppKit

enum NoteCalloutKind: String, CaseIterable, Sendable {
    case note
    case tip
    case warning
    case quote

    var title: String {
        switch self {
        case .note: "Note"
        case .tip: "Tip"
        case .warning: "Warning"
        case .quote: "Quote"
        }
    }
}

enum MarkdownEditorCommands {
    struct TextEdit: Equatable, Sendable {
        let replacementRange: NSRange
        let replacementText: String
        let selectedRange: NSRange
    }

    struct Continuation: Equatable, Sendable {
        let insertedText: String
    }

    struct TableEdit: Equatable, Sendable {
        let replacementRange: NSRange
        let replacementText: String
        let selectedRange: NSRange
    }

    static let markdownTableTemplate =
        "\n| Column 1 | Column 2 | Column 3 |\n| -------- | -------- | -------- |\n| cell     | cell     | cell     |\n"

    static func wrapSelection(
        in text: String,
        selection: NSRange,
        prefix: String,
        suffix: String
    ) -> TextEdit {
        let safeSelection = clampedSelection(selection, textLength: (text as NSString).length)
        let selected = (text as NSString).substring(with: safeSelection)
        let replacementText = prefix + selected + suffix
        return TextEdit(
            replacementRange: safeSelection,
            replacementText: replacementText,
            selectedRange: NSRange(
                location: safeSelection.location + prefix.utf16.count,
                length: safeSelection.length
            )
        )
    }

    static func setHeading(in text: String, selection: NSRange, level: Int) -> TextEdit? {
        let nsText = text as NSString
        let safeSelection = clampedSelection(selection, textLength: nsText.length)
        guard safeSelection.location <= nsText.length else { return nil }

        let lineRange = nsText.lineRange(for: NSRange(location: safeSelection.location, length: 0))
        let lineText = nsText.substring(with: lineRange)
        let hasTrailingNewline = lineText.hasSuffix("\n")
        let lineBody = hasTrailingNewline ? String(lineText.dropLast()) : lineText

        var stripped = lineBody
        var hashCount = 0
        for character in stripped {
            if character == "#" {
                hashCount += 1
            } else {
                break
            }
        }
        if hashCount > 0 {
            stripped = String(stripped.dropFirst(hashCount))
            if stripped.hasPrefix(" ") {
                stripped = String(stripped.dropFirst())
            }
        }

        let clampedLevel = min(max(level, 1), 6)
        let prefix = String(repeating: "#", count: clampedLevel) + " "
        let replacementText = prefix + stripped + (hasTrailingNewline ? "\n" : "")
        return TextEdit(
            replacementRange: lineRange,
            replacementText: replacementText,
            selectedRange: NSRange(location: lineRange.location + prefix.utf16.count, length: 0)
        )
    }

    static func toggleLinePrefix(in text: String, selection: NSRange, prefix: String) -> TextEdit? {
        let nsText = text as NSString
        let safeSelection = clampedSelection(selection, textLength: nsText.length)
        guard safeSelection.location <= nsText.length else { return nil }

        let lineRange = expandedLineRange(for: safeSelection, in: nsText)
        let lineText = nsText.substring(with: lineRange)
        let replacementText = transformedLineBlock(lineText) { line in
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count))
            }
            return prefix + strippedLineMarker(from: line)
        }

        return TextEdit(
            replacementRange: lineRange,
            replacementText: replacementText,
            selectedRange:
                safeSelection.length == 0
                ? NSRange(location: lineRange.location + prefix.utf16.count, length: 0)
                : NSRange(location: lineRange.location, length: replacementText.utf16.count)
        )
    }

    static func insertCallout(
        in text: String,
        selection: NSRange,
        kind: NoteCalloutKind
    ) -> TextEdit {
        let safeSelection = clampedSelection(selection, textLength: (text as NSString).length)
        if safeSelection.length > 0 {
            let selected = (text as NSString).substring(with: safeSelection)
            let header = "> [!\(kind.rawValue)] \(kind.title)\n"
            let quotedBody = transformedLineBlock(selected) { line in
                line.isEmpty ? ">" : "> \(line)"
            }
            return TextEdit(
                replacementRange: safeSelection,
                replacementText: header + quotedBody,
                selectedRange: NSRange(
                    location: safeSelection.location + header.utf16.count,
                    length: quotedBody.utf16.count
                )
            )
        }
        return insertionEdit(
            text: text,
            selection: selection,
            insertedText: calloutTemplate(for: kind),
            cursorOffset: calloutTemplate(for: kind).utf16.count
        )
    }

    static func insertMarkdownTable(in text: String, selection: NSRange) -> TextEdit {
        let safeSelection = clampedSelection(selection, textLength: (text as NSString).length)
        let table = markdownTableTemplate
        let cursorOffset: Int
        let selectedLength: Int
        if let offset = table.range(of: "| cell") {
            cursorOffset = table.distance(from: table.startIndex, to: offset.lowerBound) + 2
            selectedLength = 4
        } else {
            cursorOffset = table.utf16.count
            selectedLength = 0
        }
        return TextEdit(
            replacementRange: NSRange(location: safeSelection.location, length: 0),
            replacementText: table,
            selectedRange: NSRange(
                location: safeSelection.location + cursorOffset,
                length: selectedLength
            )
        )
    }

    static func insertDivider(in text: String, selection: NSRange) -> TextEdit {
        let safeSelection = clampedSelection(selection, textLength: (text as NSString).length)
        return TextEdit(
            replacementRange: NSRange(location: safeSelection.location, length: 0),
            replacementText: "\n---\n",
            selectedRange: NSRange(
                location: safeSelection.location + "\n---\n".utf16.count,
                length: 0
            )
        )
    }

    static func insertCodeFence(in text: String, selection: NSRange) -> TextEdit {
        let safeSelection = clampedSelection(selection, textLength: (text as NSString).length)
        if safeSelection.length > 0 {
            let selected = (text as NSString).substring(with: safeSelection)
            let replacement = "```\n\(selected)\n```"
            return TextEdit(
                replacementRange: safeSelection,
                replacementText: replacement,
                selectedRange: NSRange(location: safeSelection.location + 4, length: safeSelection.length)
            )
        }
        return insertionEdit(
            text: text,
            selection: selection,
            insertedText: "```\n\n```",
            cursorOffset: 4
        )
    }

    static func autoExpandCodeFence(
        in text: String,
        selection: NSRange,
        replacementString: String?
    ) -> TextEdit? {
        guard replacementString == "`" else { return nil }

        let nsText = text as NSString
        let safeSelection = clampedSelection(selection, textLength: nsText.length)
        guard safeSelection.length == 0, safeSelection.location >= 2 else { return nil }

        let lineProbe = NSRange(location: min(safeSelection.location, max(nsText.length - 1, 0)), length: 0)
        let lineRange = nsText.lineRange(for: lineProbe)
        let lineBodyRange = normalizedLineBodyRange(lineRange, in: nsText)

        let prefixRange = NSRange(
            location: lineBodyRange.location,
            length: safeSelection.location - lineBodyRange.location
        )
        let suffixRange = NSRange(
            location: safeSelection.location,
            length: max(0, NSMaxRange(lineBodyRange) - safeSelection.location)
        )

        let prefix = nsText.substring(with: prefixRange)
        let suffix = nsText.substring(with: suffixRange)
        let indentation = String(prefix.prefix { $0 == " " || $0 == "\t" })

        guard prefix == indentation + "``" else { return nil }
        guard suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let replacementRange = NSRange(
            location: safeSelection.location - 2,
            length: 2 + suffixRange.length
        )
        let replacementText = "```\n\(indentation)\n\(indentation)```"
        return TextEdit(
            replacementRange: replacementRange,
            replacementText: replacementText,
            selectedRange: NSRange(
                location: replacementRange.location + 4 + indentation.utf16.count,
                length: 0
            )
        )
    }

    static func replace(
        in text: String,
        range: NSRange,
        replacement: String,
        selectedRange: NSRange? = nil
    ) -> TextEdit? {
        let nsText = text as NSString
        guard range.location <= nsText.length else { return nil }
        let safeRange = clampedSelection(range, textLength: nsText.length)
        return TextEdit(
            replacementRange: safeRange,
            replacementText: replacement,
            selectedRange: selectedRange
                ?? NSRange(location: safeRange.location + replacement.utf16.count, length: 0)
        )
    }

    static func continuedInsertion(for line: String) -> Continuation? {
        let trimmedLine = line.replacingOccurrences(of: "\r", with: "")
        let lineBody = trimmedLine.hasSuffix("\n") ? String(trimmedLine.dropLast()) : trimmedLine
        let indentation = String(lineBody.prefix { $0 == " " || $0 == "\t" })
        let content = String(lineBody.dropFirst(indentation.count))
        guard !content.isEmpty else { return nil }

        if let prefix = taskListPrefix(for: content) {
            return Continuation(insertedText: "\n\(indentation)\(prefix)")
        }
        if let prefix = orderedListPrefix(for: content) {
            return Continuation(insertedText: "\n\(indentation)\(prefix)")
        }
        if let prefix = unorderedListPrefix(for: content) {
            return Continuation(insertedText: "\n\(indentation)\(prefix)")
        }
        if let prefix = quotePrefix(for: content) {
            return Continuation(insertedText: "\n\(indentation)\(prefix)")
        }
        return nil
    }

    static func strippedLineMarker(from line: String) -> String {
        if let range = line.range(of: #"^[-*+] \[(?: |x|X)\] "#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        if let range = line.range(of: #"^\d+\. "#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        if let range = line.range(of: #"^[-*+] "#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        if let range = line.range(of: #"^(?:>\s*)+"#, options: .regularExpression) {
            return String(line[range.upperBound...])
        }
        return line
    }

    static func calloutTemplate(for kind: NoteCalloutKind) -> String {
        "> [!\(kind.rawValue)] \(kind.title)\n> "
    }

    static func alignTable(in text: String, selection: NSRange) -> TableEdit? {
        guard let table = parseTable(in: text as NSString, selection: selection) else { return nil }
        return rebuiltTableEdit(from: table, rows: table.rows, selectedRow: table.cursorRow, selectedColumn: table.cursorColumn)
    }

    static func isSelectionInsideTable(in text: String, selection: NSRange) -> Bool {
        parseTable(in: text as NSString, selection: selection) != nil
    }

    static func insertTableRowBelow(in text: String, selection: NSRange) -> TableEdit? {
        guard let table = parseTable(in: text as NSString, selection: selection) else { return nil }
        let columnCount = table.columnCount
        guard columnCount > 0 else { return nil }

        var rows = normalizedRows(table.rows, columnCount: columnCount)
        let separatorRow = table.separatorRow ?? 1
        let anchorRow = max(table.cursorRow, separatorRow)
        let insertRow = min(anchorRow + 1, rows.count)
        rows.insert([String](repeating: "", count: columnCount), at: insertRow)
        return rebuiltTableEdit(from: table, rows: rows, selectedRow: insertRow, selectedColumn: min(table.cursorColumn, columnCount - 1))
    }

    static func insertTableColumnRight(in text: String, selection: NSRange) -> TableEdit? {
        guard let table = parseTable(in: text as NSString, selection: selection) else { return nil }
        let columnCount = table.columnCount
        let insertColumn = min(table.cursorColumn + 1, columnCount)
        var rows = normalizedRows(table.rows, columnCount: columnCount)

        for rowIndex in rows.indices {
            if rowIndex == table.separatorRow {
                rows[rowIndex].insert("--------", at: insertColumn)
            } else if rowIndex == 0 {
                rows[rowIndex].insert("Column \(insertColumn + 1)", at: insertColumn)
            } else {
                rows[rowIndex].insert("", at: insertColumn)
            }
        }

        let selectedRow = table.cursorRow == table.separatorRow ? min((table.separatorRow ?? 0) + 1, rows.count - 1) : table.cursorRow
        return rebuiltTableEdit(from: table, rows: rows, selectedRow: selectedRow, selectedColumn: insertColumn)
    }

    static func deleteTableRow(in text: String, selection: NSRange) -> TableEdit? {
        guard let table = parseTable(in: text as NSString, selection: selection) else { return nil }
        guard table.cursorRow != 0, table.cursorRow != table.separatorRow else { return nil }

        var rows = normalizedRows(table.rows, columnCount: table.columnCount)
        let dataRowCount = rows.indices.filter { $0 != 0 && $0 != table.separatorRow }.count
        let selectedColumn = min(table.cursorColumn, max(0, table.columnCount - 1))

        let selectedRow: Int
        if dataRowCount <= 1 {
            rows[table.cursorRow] = [String](repeating: "", count: table.columnCount)
            selectedRow = table.cursorRow
        } else {
            rows.remove(at: table.cursorRow)
            selectedRow = min(table.cursorRow, rows.count - 1)
        }

        return rebuiltTableEdit(from: table, rows: rows, selectedRow: selectedRow, selectedColumn: selectedColumn)
    }

    static func deleteTableColumn(in text: String, selection: NSRange) -> TableEdit? {
        guard let table = parseTable(in: text as NSString, selection: selection) else { return nil }
        guard table.columnCount > 1 else { return nil }

        var rows = normalizedRows(table.rows, columnCount: table.columnCount)
        for rowIndex in rows.indices {
            rows[rowIndex].remove(at: min(table.cursorColumn, rows[rowIndex].count - 1))
        }

        let selectedColumn = min(table.cursorColumn, table.columnCount - 2)
        let selectedRow = table.cursorRow == table.separatorRow ? min((table.separatorRow ?? 0) + 1, rows.count - 1) : table.cursorRow
        return rebuiltTableEdit(from: table, rows: rows, selectedRow: selectedRow, selectedColumn: selectedColumn)
    }

    @MainActor
    static func apply(_ edit: TextEdit, to textView: NSTextView) -> Bool {
        guard textView.shouldChangeText(
            in: edit.replacementRange,
            replacementString: edit.replacementText
        ) else {
            return false
        }
        textView.textStorage?.replaceCharacters(
            in: edit.replacementRange,
            with: edit.replacementText
        )
        textView.didChangeText()
        textView.setSelectedRange(edit.selectedRange)
        return true
    }

    @MainActor
    static func apply(_ edit: TableEdit, to textView: NSTextView) -> Bool {
        apply(
            TextEdit(
                replacementRange: edit.replacementRange,
                replacementText: edit.replacementText,
                selectedRange: edit.selectedRange
            ),
            to: textView
        )
    }

    @MainActor
    static func handleTableNewline(in textView: NSTextView) -> Bool {
        apply(insertTableRowBelow(in: textView.string, selection: textView.selectedRange()), to: textView)
    }

    @MainActor
    static func realignTable(in textView: NSTextView) -> Bool {
        apply(alignTable(in: textView.string, selection: textView.selectedRange()), to: textView)
    }

    @MainActor
    static func handleContinuationNewline(in textView: NSTextView) -> Bool {
        let str = textView.string as NSString
        guard str.length > 0 else { return false }

        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }

        let safeLocation = min(selection.location, max(0, str.length - 1))
        let lineRange = str.lineRange(for: NSRange(location: safeLocation, length: 0))
        let line = str.substring(with: lineRange)

        guard let continuation = continuedInsertion(for: line) else { return false }
        let insertionRange = NSRange(location: selection.location, length: 0)
        if textView.shouldChangeText(in: insertionRange, replacementString: continuation.insertedText) {
            textView.textStorage?.replaceCharacters(in: insertionRange, with: continuation.insertedText)
            textView.didChangeText()
            let newLocation = selection.location + continuation.insertedText.utf16.count
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            return true
        }
        return false
    }

    private static func taskListPrefix(for line: String) -> String? {
        guard let range = line.range(of: #"^[-*+] \[(?: |x|X)\] "#, options: .regularExpression),
              range.lowerBound == line.startIndex else { return nil }
        let bullet = line[line.startIndex]
        return "\(bullet) [ ] "
    }

    private static func unorderedListPrefix(for line: String) -> String? {
        guard let range = line.range(of: #"^[-*+] "#, options: .regularExpression),
              range.lowerBound == line.startIndex else { return nil }
        return String(line[range])
    }

    private static func orderedListPrefix(for line: String) -> String? {
        guard let range = line.range(of: #"^\d+\. "#, options: .regularExpression),
              range.lowerBound == line.startIndex else { return nil }
        let marker = String(line[range]).trimmingCharacters(in: .whitespaces)
        let numberText = marker.dropLast()
        let next = (Int(numberText) ?? 0) + 1
        return "\(next). "
    }

    private static func quotePrefix(for line: String) -> String? {
        var index = line.startIndex
        var depth = 0

        while index < line.endIndex, line[index] == ">" {
            depth += 1
            index = line.index(after: index)
            while index < line.endIndex, line[index] == " " {
                index = line.index(after: index)
            }
        }

        guard depth > 0 else { return nil }
        return Array(repeating: ">", count: depth).joined(separator: " ") + " "
    }

    private struct ParsedTable {
        let range: NSRange
        let rows: [[String]]
        let separatorRow: Int?
        let cursorRow: Int
        let cursorColumn: Int
        let columnCount: Int
        let hasTrailingNewline: Bool
    }

    private static func parseTable(in text: NSString, selection: NSRange) -> ParsedTable? {
        guard text.length > 0 else { return nil }
        let safeLocation = min(selection.location, max(0, text.length - 1))
        let cursorLineRange = text.lineRange(for: NSRange(location: safeLocation, length: 0))
        guard isTableLine(text.substring(with: cursorLineRange)) else { return nil }

        var lineRanges: [NSRange] = [cursorLineRange]
        var tableStart = cursorLineRange.location
        while tableStart > 0 {
            let previousLineRange = text.lineRange(for: NSRange(location: tableStart - 1, length: 0))
            guard isTableLine(text.substring(with: previousLineRange)) else { break }
            lineRanges.insert(previousLineRange, at: 0)
            tableStart = previousLineRange.location
        }

        var tableEnd = NSMaxRange(cursorLineRange)
        while tableEnd < text.length {
            let nextLineRange = text.lineRange(for: NSRange(location: tableEnd, length: 0))
            guard isTableLine(text.substring(with: nextLineRange)) else { break }
            lineRanges.append(nextLineRange)
            tableEnd = NSMaxRange(nextLineRange)
        }

        let tableRange = NSRange(location: tableStart, length: tableEnd - tableStart)
        let rows = lineRanges.map { parseTableCells(in: text.substring(with: $0)) }
        let columnCount = rows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return nil }

        let separatorRow = rows.firstIndex(where: isSeparatorRow)
        let cursorRow = lineRanges.firstIndex(where: { selection.location >= $0.location && selection.location <= NSMaxRange($0) }) ?? 0
        let cursorColumn = min(columnIndex(in: text.substring(with: lineRanges[cursorRow]), selectionLocation: selection.location, lineStart: lineRanges[cursorRow].location), columnCount - 1)
        let hasTrailingNewline = tableRange.length > 0 && text.character(at: NSMaxRange(tableRange) - 1) == 0x0A

        return ParsedTable(
            range: tableRange,
            rows: rows,
            separatorRow: separatorRow,
            cursorRow: cursorRow,
            cursorColumn: cursorColumn,
            columnCount: columnCount,
            hasTrailingNewline: hasTrailingNewline
        )
    }

    private static func clampedSelection(_ selection: NSRange, textLength: Int) -> NSRange {
        let safeLocation = min(max(selection.location, 0), textLength)
        let maxLength = max(textLength - safeLocation, 0)
        let safeLength = min(max(selection.length, 0), maxLength)
        return NSRange(location: safeLocation, length: safeLength)
    }

    private static func normalizedLineBodyRange(_ lineRange: NSRange, in text: NSString) -> NSRange {
        guard lineRange.length > 0 else { return lineRange }
        let lineEnd = NSMaxRange(lineRange)
        let hasTrailingNewline = lineEnd <= text.length && lineEnd > 0 && text.character(at: lineEnd - 1) == 0x0A
        return NSRange(
            location: lineRange.location,
            length: hasTrailingNewline ? max(0, lineRange.length - 1) : lineRange.length
        )
    }

    private static func expandedLineRange(for selection: NSRange, in text: NSString) -> NSRange {
        guard text.length > 0 else { return NSRange(location: 0, length: 0) }
        let safeSelection = clampedSelection(selection, textLength: text.length)
        let startLine = text.lineRange(for: NSRange(location: min(safeSelection.location, text.length - 1), length: 0))
        guard safeSelection.length > 0 else { return startLine }
        let selectionEnd = min(NSMaxRange(safeSelection), text.length)
        let endLocation = max(startLine.location, selectionEnd - 1)
        let endLine = text.lineRange(for: NSRange(location: min(endLocation, text.length - 1), length: 0))
        return NSRange(location: startLine.location, length: NSMaxRange(endLine) - startLine.location)
    }

    private static func transformedLineBlock(
        _ block: String,
        transform: (String) -> String
    ) -> String {
        let lines = block.components(separatedBy: "\n")
        return lines
            .enumerated()
            .map { index, line in
                if index == lines.count - 1, block.hasSuffix("\n"), line.isEmpty {
                    return line
                }
                return transform(line)
            }
            .joined(separator: "\n")
    }

    private static func insertionEdit(
        text: String,
        selection: NSRange,
        insertedText: String,
        cursorOffset: Int,
        selectedLength: Int = 0
    ) -> TextEdit {
        let safeSelection = clampedSelection(selection, textLength: (text as NSString).length)
        return TextEdit(
            replacementRange: safeSelection,
            replacementText: insertedText,
            selectedRange: NSRange(
                location: safeSelection.location + cursorOffset,
                length: selectedLength
            )
        )
    }

    private static func rebuiltTableEdit(
        from table: ParsedTable,
        rows: [[String]],
        selectedRow: Int,
        selectedColumn: Int
    ) -> TableEdit {
        let normalized = normalizedRows(rows, columnCount: rows.map(\.count).max() ?? table.columnCount)
        let safeColumnCount = max(1, normalized.first?.count ?? table.columnCount)
        let bodyText = alignedTableBody(rows: normalized, separatorRow: table.separatorRow)
        let replacementText = table.hasTrailingNewline ? bodyText + "\n" : bodyText
        let localSelection = tableSelectionRange(
            in: bodyText,
            row: min(selectedRow, max(0, normalized.count - 1)),
            column: min(selectedColumn, safeColumnCount - 1)
        )
        return TableEdit(
            replacementRange: table.range,
            replacementText: replacementText,
            selectedRange: NSRange(
                location: table.range.location + localSelection.location,
                length: localSelection.length
            )
        )
    }

    private static func normalizedRows(_ rows: [[String]], columnCount: Int) -> [[String]] {
        rows.map { row in
            if row.count >= columnCount { return row }
            return row + [String](repeating: "", count: columnCount - row.count)
        }
    }

    private static func alignedTableBody(rows: [[String]], separatorRow: Int?) -> String {
        let columnCount = rows.first?.count ?? 0
        var widths = [Int](repeating: 6, count: columnCount)

        for (rowIndex, row) in rows.enumerated() where rowIndex != separatorRow {
            for (columnIndex, cell) in row.enumerated() {
                widths[columnIndex] = max(widths[columnIndex], cell.count)
            }
        }

        return rows.enumerated().map { rowIndex, row in
            let renderedCells = row.enumerated().map { columnIndex, cell in
                let width = widths[columnIndex]
                if rowIndex == separatorRow {
                    let leftColon = cell.hasPrefix(":")
                    let rightColon = cell.hasSuffix(":")
                    let dashCount = max(width - (leftColon ? 1 : 0) - (rightColon ? 1 : 0), 3)
                    return (leftColon ? ":" : "") + String(repeating: "-", count: dashCount) + (rightColon ? ":" : "")
                }
                return cell.padding(toLength: width, withPad: " ", startingAt: 0)
            }
            return "| " + renderedCells.joined(separator: " | ") + " |"
        }.joined(separator: "\n")
    }

    private static func tableSelectionRange(in tableBody: String, row: Int, column: Int) -> NSRange {
        let lines = tableBody.components(separatedBy: "\n")
        guard row < lines.count else { return NSRange(location: 0, length: 0) }

        let prefixLength = lines[..<row].reduce(0) { $0 + ($1 as NSString).length + 1 }
        let line = lines[row]
        let nsLine = line as NSString
        var pipePositions: [Int] = []
        nsLine.enumerateSubstrings(in: NSRange(location: 0, length: nsLine.length), options: .byComposedCharacterSequences) { substring, substringRange, _, _ in
            if substring == "|" {
                pipePositions.append(substringRange.location)
            }
        }

        guard pipePositions.count >= 2 else { return NSRange(location: prefixLength, length: 0) }
        let safeColumn = min(column, pipePositions.count - 2)
        let cellStart = min(pipePositions[safeColumn] + 2, nsLine.length)
        let cellEnd = max(cellStart, min(pipePositions[safeColumn + 1] - 1, nsLine.length))
        let rawCell = nsLine.substring(with: NSRange(location: cellStart, length: max(0, cellEnd - cellStart)))
        let trimmed = rawCell.trimmingCharacters(in: .whitespaces)
        let leadingSpaces = rawCell.prefix { $0 == " " }.count
        let location = prefixLength + cellStart + (trimmed.isEmpty ? 0 : leadingSpaces)
        return NSRange(location: location, length: trimmed.utf16.count)
    }

    private static func parseTableCells(in rawLine: String) -> [String] {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isTableLine(trimmed) else { return [trimmed] }
        return trimmed.dropFirst().dropLast()
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isSeparatorRow(_ cells: [String]) -> Bool {
        !cells.isEmpty && cells.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0 == "-" || $0 == ":" } }
    }

    private static func isTableLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 1
    }

    private static func columnIndex(in line: String, selectionLocation: Int, lineStart: Int) -> Int {
        let utf16 = Array(line.utf16)
        var pipePositions: [Int] = []
        for (offset, character) in utf16.enumerated() where character == 0x7C {
            pipePositions.append(lineStart + offset)
        }
        guard pipePositions.count >= 2 else { return 0 }
        for column in 0..<(pipePositions.count - 1) where selectionLocation <= pipePositions[column + 1] {
            return column
        }
        return max(0, pipePositions.count - 2)
    }

    @MainActor
    private static func apply(_ edit: TableEdit?, to textView: NSTextView) -> Bool {
        guard let edit else { return false }
        return apply(edit, to: textView)
    }
}
