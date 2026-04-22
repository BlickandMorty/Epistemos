import Foundation

/// Pass 12 — "Local diff that rivals git, using the time-machine engine."
///
/// A pure-Swift line diff engine that consumes two note bodies and emits
/// structured hunks — same shape git/GitHub use, minus a subprocess. The
/// algorithm is Myers' classic O((N+M)D) edit-distance search with the
/// usual common-prefix / common-suffix shortcut, which in practice runs
/// in the a few hundred microseconds for a normal note and never touches
/// GPU / Metal / Rust. Text diff is already I/O-bound in the app.
///
/// Consumed by the `TimeMachineService` line-diff extension (Pass 12)
/// so any two snapshots of the same page — current body vs any
/// `SDPageVersion`, or two `SDPageVersion`s against each other — produce
/// a hunk list the UI can render. This is the moat the user asked for:
/// git only sees the working tree at commit time; `NoteLineDiff` sees
/// every meaningful save the time-machine captured, so the user can
/// scrub backward and forward in time without ever running `git`.
enum NoteLineDiff {
    /// Tag for each emitted line in a hunk.
    enum LineKind: String, Sendable, Codable {
        case context
        case insertion
        case deletion
    }

    struct Line: Identifiable, Sendable, Codable, Hashable {
        let id: UUID
        let kind: LineKind
        let oldLineNumber: Int?
        let newLineNumber: Int?
        let text: String

        init(
            id: UUID = UUID(),
            kind: LineKind,
            oldLineNumber: Int?,
            newLineNumber: Int?,
            text: String
        ) {
            self.id = id
            self.kind = kind
            self.oldLineNumber = oldLineNumber
            self.newLineNumber = newLineNumber
            self.text = text
        }
    }

    struct Hunk: Identifiable, Sendable, Codable, Hashable {
        let id: UUID
        let oldStart: Int        // 1-based inclusive
        let oldLineCount: Int
        let newStart: Int        // 1-based inclusive
        let newLineCount: Int
        let lines: [Line]

        init(
            id: UUID = UUID(),
            oldStart: Int,
            oldLineCount: Int,
            newStart: Int,
            newLineCount: Int,
            lines: [Line]
        ) {
            self.id = id
            self.oldStart = oldStart
            self.oldLineCount = oldLineCount
            self.newStart = newStart
            self.newLineCount = newLineCount
            self.lines = lines
        }
    }

    struct Summary: Sendable, Codable, Hashable {
        let hunks: [Hunk]
        let addedLines: Int
        let removedLines: Int
        let unchangedLines: Int
        let oldChecksum: UInt64
        let newChecksum: UInt64

        /// Fast identity check — lets callers short-circuit UI work
        /// when the two sides are byte-identical.
        var isUnchanged: Bool {
            addedLines == 0 && removedLines == 0
        }
    }

    /// Entry point. `context` = number of unchanged lines kept on each
    /// side of a change run (git default is 3).
    static func summarize(
        oldText: String,
        newText: String,
        context: Int = 3
    ) -> Summary {
        let oldLines = tokenize(oldText)
        let newLines = tokenize(newText)
        let oldChecksum = checksum(of: oldText)
        let newChecksum = checksum(of: newText)

        if oldChecksum == newChecksum, oldText == newText {
            let unchanged = oldLines.count
            return Summary(
                hunks: [],
                addedLines: 0,
                removedLines: 0,
                unchangedLines: unchanged,
                oldChecksum: oldChecksum,
                newChecksum: newChecksum
            )
        }

        // Trim common prefix / suffix to shrink the Myers search space.
        let prefix = commonPrefixLength(oldLines, newLines)
        let suffix = commonSuffixLength(
            Array(oldLines.dropFirst(prefix)),
            Array(newLines.dropFirst(prefix))
        )
        let oldCore = Array(oldLines.dropFirst(prefix).dropLast(suffix))
        let newCore = Array(newLines.dropFirst(prefix).dropLast(suffix))

        let coreOperations = myersOperations(old: oldCore, new: newCore)

        var fullOperations: [Operation] = []
        fullOperations.reserveCapacity(prefix + coreOperations.count + suffix)
        for line in oldLines.prefix(prefix) {
            fullOperations.append(.same(text: line))
        }
        fullOperations.append(contentsOf: coreOperations)
        let suffixStart = oldLines.count - suffix
        for line in oldLines[suffixStart..<oldLines.count] {
            fullOperations.append(.same(text: line))
        }

        let hunks = buildHunks(fromOperations: fullOperations, context: context)
        var added = 0
        var removed = 0
        var same = 0
        for op in fullOperations {
            switch op {
            case .same: same += 1
            case .insert: added += 1
            case .delete: removed += 1
            }
        }

        return Summary(
            hunks: hunks,
            addedLines: added,
            removedLines: removed,
            unchangedLines: same,
            oldChecksum: oldChecksum,
            newChecksum: newChecksum
        )
    }

    // MARK: - Internals

    private static func tokenize(_ text: String) -> [String] {
        // Split keeping line-break semantics; a trailing newline becomes
        // an empty-string tail line that round-trips correctly through
        // the diff output.
        if text.isEmpty { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private static func commonPrefixLength(_ a: [String], _ b: [String]) -> Int {
        let limit = min(a.count, b.count)
        var i = 0
        while i < limit, a[i] == b[i] { i += 1 }
        return i
    }

    private static func commonSuffixLength(_ a: [String], _ b: [String]) -> Int {
        let limit = min(a.count, b.count)
        var i = 0
        while i < limit, a[a.count - 1 - i] == b[b.count - 1 - i] { i += 1 }
        return i
    }

    enum Operation {
        case same(text: String)
        case insert(text: String)
        case delete(text: String)
    }

    /// Myers O((N+M)D) edit-distance walk. Returns an ordered operation
    /// list that, applied to `old`, reproduces `new`.
    private static func myersOperations(old: [String], new: [String]) -> [Operation] {
        let n = old.count
        let m = new.count
        if n == 0 && m == 0 { return [] }
        if n == 0 { return new.map { .insert(text: $0) } }
        if m == 0 { return old.map { .delete(text: $0) } }

        let maxD = n + m
        // V is the furthest-reaching x value for each k = x - y diagonal.
        var trace: [[Int]] = []
        var v = Array(repeating: 0, count: 2 * maxD + 1)
        let offset = maxD

        for d in 0...maxD {
            var reachedEnd = false
            // Copy the current v into the trace before it's mutated.
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                let kIdx = k + offset
                let downIdx = kIdx + 1
                let upIdx = kIdx - 1
                var x: Int
                if k == -d || (k != d && v[upIdx] < v[downIdx]) {
                    x = v[downIdx]
                } else {
                    x = v[upIdx] + 1
                }
                var y = x - k
                while x < n, y < m, old[x] == new[y] {
                    x += 1
                    y += 1
                }
                v[kIdx] = x
                if x >= n && y >= m {
                    reachedEnd = true
                    break
                }
            }
            if reachedEnd { break }
        }

        // Backtrack through `trace` to recover the edit script.
        var operations: [Operation] = []
        var x = n
        var y = m
        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let vPrev = trace[d]
            let k = x - y
            let kIdx = k + offset
            let prevK: Int
            if k == -d || (k != d && vPrev[kIdx - 1] < vPrev[kIdx + 1]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }
            let prevX = vPrev[prevK + offset]
            let prevY = prevX - prevK
            while x > prevX, y > prevY {
                operations.append(.same(text: old[x - 1]))
                x -= 1
                y -= 1
            }
            if d > 0 {
                if x == prevX {
                    operations.append(.insert(text: new[y - 1]))
                    y -= 1
                } else {
                    operations.append(.delete(text: old[x - 1]))
                    x -= 1
                }
            }
        }
        while x > 0 && y > 0 {
            operations.append(.same(text: old[x - 1]))
            x -= 1
            y -= 1
        }
        while x > 0 {
            operations.append(.delete(text: old[x - 1]))
            x -= 1
        }
        while y > 0 {
            operations.append(.insert(text: new[y - 1]))
            y -= 1
        }

        return operations.reversed()
    }

    private static func buildHunks(fromOperations ops: [Operation], context: Int) -> [Hunk] {
        var hunks: [Hunk] = []
        var i = 0
        var oldLine = 1
        var newLine = 1

        while i < ops.count {
            // Find the next change.
            var j = i
            while j < ops.count, case .same = ops[j] {
                oldLine += 1
                newLine += 1
                j += 1
            }
            if j >= ops.count { break }

            // `j` is the first change. Seed a hunk starting `context`
            // lines of context before.
            let hunkStartOpIndex = max(i, j - context)
            let preSameSkipped = hunkStartOpIndex - i
            var hunkOldLine = oldLine - (j - hunkStartOpIndex)
            var hunkNewLine = newLine - (j - hunkStartOpIndex)
            let hunkOldStart = hunkOldLine
            let hunkNewStart = hunkNewLine

            // Step forward through the changes, absorbing runs of
            // unchanged lines shorter than `2*context`.
            var k = hunkStartOpIndex
            var emittedLines: [Line] = []
            var oldRun = 0
            var newRun = 0

            while k < ops.count {
                // Look ahead over a same-run to decide whether to keep
                // it within this hunk or close the hunk here.
                var lookahead = k
                while lookahead < ops.count, case .same = ops[lookahead] {
                    lookahead += 1
                }
                let sameRun = lookahead - k
                let atEnd = lookahead == ops.count
                let keep = sameRun < context * 2 && !atEnd

                if sameRun > 0 {
                    let keepCount = keep ? sameRun : min(sameRun, context)
                    for offset in 0..<keepCount {
                        if case .same(let text) = ops[k + offset] {
                            emittedLines.append(Line(
                                kind: .context,
                                oldLineNumber: hunkOldLine,
                                newLineNumber: hunkNewLine,
                                text: text
                            ))
                            hunkOldLine += 1
                            hunkNewLine += 1
                            oldRun += 1
                            newRun += 1
                        }
                    }
                    k += sameRun
                    if !keep {
                        // Close out this hunk and restart scanning.
                        hunks.append(Hunk(
                            oldStart: hunkOldStart,
                            oldLineCount: oldRun,
                            newStart: hunkNewStart,
                            newLineCount: newRun,
                            lines: emittedLines
                        ))
                        oldLine = hunkOldLine + (sameRun - min(sameRun, context))
                        newLine = hunkNewLine + (sameRun - min(sameRun, context))
                        i = k
                        break
                    }
                } else {
                    switch ops[k] {
                    case .insert(let text):
                        emittedLines.append(Line(
                            kind: .insertion,
                            oldLineNumber: nil,
                            newLineNumber: hunkNewLine,
                            text: text
                        ))
                        hunkNewLine += 1
                        newRun += 1
                    case .delete(let text):
                        emittedLines.append(Line(
                            kind: .deletion,
                            oldLineNumber: hunkOldLine,
                            newLineNumber: nil,
                            text: text
                        ))
                        hunkOldLine += 1
                        oldRun += 1
                    case .same:
                        break // handled above
                    }
                    k += 1
                }

                if k >= ops.count {
                    hunks.append(Hunk(
                        oldStart: hunkOldStart,
                        oldLineCount: oldRun,
                        newStart: hunkNewStart,
                        newLineCount: newRun,
                        lines: emittedLines
                    ))
                    oldLine = hunkOldLine
                    newLine = hunkNewLine
                    i = k
                    break
                }
            }

            _ = preSameSkipped // kept for readability
        }

        return hunks
    }

    /// FNV-1a-ish 64-bit checksum — stable, branch-free, and fast. Good
    /// enough for diff short-circuit checks; not a cryptographic hash.
    private static func checksum(of text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
