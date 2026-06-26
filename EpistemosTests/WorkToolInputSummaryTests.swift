import Foundation
import Testing
@testable import Epistemos

// Pure, debris-safety invariants for the tool-call summary line (OpenCode-TUI minimalism, NO raw input dump).
@Suite("Work tool-input summary — compact, debris-safe per-tool extraction")
struct WorkToolInputSummaryTests {

    @Test("shell/bash → command; edit/write/read → filePath; glob/grep → pattern; webfetch → url")
    func salientKeys() {
        #expect(WorkToolInputSummary.summary(toolName: "bash", input: ["command": "ls -la"]) == "ls -la")
        #expect(WorkToolInputSummary.summary(toolName: "shell", input: ["command": "git status"]) == "git status")
        #expect(WorkToolInputSummary.summary(toolName: "edit", input: ["filePath": "/a/b.swift"]) == "/a/b.swift")
        #expect(WorkToolInputSummary.summary(toolName: "write", input: ["filePath": "/a/c.swift"]) == "/a/c.swift")
        #expect(WorkToolInputSummary.summary(toolName: "read", input: ["filePath": "/a/d.swift"]) == "/a/d.swift")
        #expect(WorkToolInputSummary.summary(toolName: "grep", input: ["pattern": "TODO"]) == "TODO")
        #expect(WorkToolInputSummary.summary(toolName: "webfetch", input: ["url": "https://x.dev"]) == "https://x.dev")
    }

    @Test("case-insensitive tool name")
    func caseInsensitive() {
        #expect(WorkToolInputSummary.summary(toolName: "Edit", input: ["filePath": "/x"]) == "/x")
        #expect(WorkToolInputSummary.summary(toolName: "BASH", input: ["command": "echo hi"]) == "echo hi")
    }

    @Test("DEBRIS GUARD: write.content / edit.oldString+newString are NEVER surfaced — only filePath")
    func neverDumpsContent() {
        let write = WorkToolInputSummary.summary(
            toolName: "write", input: ["filePath": "/f.txt", "content": String(repeating: "X", count: 5000)])
        #expect(write == "/f.txt")
        let edit = WorkToolInputSummary.summary(
            toolName: "edit", input: ["filePath": "/g.txt", "oldString": "secret-old", "newString": "secret-new"])
        #expect(edit == "/g.txt")
        #expect(edit?.contains("secret") == false)
    }

    @Test("safeCandidates keeps only sanitized salient keys, never raw content fields")
    func safeCandidatesOnlyKeepsAllowlistedSummaries() {
        let candidates = WorkToolInputSummary.safeCandidates(input: [
            "filePath": "/x/file.swift",
            "content": "SECRET-BODY",
            "oldString": "SECRET-OLD",
            "newString": "SECRET-NEW",
            "command": "echo hi\npwd",
        ])

        #expect(candidates["filePath"] == "/x/file.swift")
        #expect(candidates["command"] == "echo hi pwd")
        #expect(candidates["content"] == nil)
        #expect(candidates.values.contains { $0.contains("SECRET") } == false)
        #expect(WorkToolInputSummary.summary(toolName: "write", candidates: candidates) == "/x/file.swift")
        #expect(WorkToolInputSummary.summary(toolName: "bash", candidates: candidates) == "echo hi pwd")
    }

    @Test("newlines collapse to one line; over-long input is truncated with an ellipsis")
    func collapseAndTruncate() {
        #expect(WorkToolInputSummary.summary(toolName: "bash", input: ["command": "a\nb\nc"]) == "a b c")
        let long = String(repeating: "z", count: WorkToolInputSummary.maxLength + 50)
        let out = WorkToolInputSummary.summary(toolName: "bash", input: ["command": long])
        #expect(out?.count == WorkToolInputSummary.maxLength + 1) // maxLength chars + the "…"
        #expect(out?.hasSuffix("…") == true)
    }

    @Test("unknown tool / missing key / non-string / empty / nil → nil (no raw dump, ever)")
    func lenientNil() {
        #expect(WorkToolInputSummary.summary(toolName: "mysteryTool", input: ["command": "x"]) == nil)
        #expect(WorkToolInputSummary.summary(toolName: "bash", input: ["notCommand": "x"]) == nil)
        #expect(WorkToolInputSummary.summary(toolName: "bash", input: ["command": 42]) == nil)
        #expect(WorkToolInputSummary.summary(toolName: "bash", input: ["command": "   "]) == nil)
        #expect(WorkToolInputSummary.summary(toolName: "bash", input: nil) == nil)
        #expect(WorkToolInputSummary.summary(toolName: nil, input: ["command": "x"]) == nil)
    }
}
