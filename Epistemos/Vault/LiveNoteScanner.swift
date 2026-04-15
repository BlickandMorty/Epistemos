import Foundation
import os
import SwiftData

// MARK: - LiveNoteScanner
// Scans the vault for notes with `live_note: true` YAML frontmatter and
// parses embedded task blocks for scheduling. Based on Rowboat inline_tasks.ts pattern.
//
// Task block format (in note body as fenced JSON):
// ```task
// {
//   "instruction": "Find recent Apple Intelligence announcements",
//   "schedule": { "type": "cron", "expression": "0 9 * * *" },
//   "targetId": "apple-ai-updates",
//   "lastRunAt": null
// }
// ```
//
// Target region (agent output replaces content between markers):
// <!--task-target:apple-ai-updates-->
// [agent writes here]
// <!--/task-target:apple-ai-updates-->

private let log = Logger(subsystem: "com.epistemos", category: "LiveNotes")

private struct LiveNotePageSnapshot: Sendable {
    let id: String
    let title: String
    let filePath: String?
    let subfolder: String?
    let inlineBody: String
    let hasManagedBody: Bool
}

private struct LiveNoteScanResult: Sendable {
    let tasks: [LiveNoteTask]
    let pageCount: Int
}

struct LiveNoteTask: Sendable {
    let instruction: String
    let schedule: LiveNoteSchedule
    let targetId: String
    let lastRunAt: Date?
    let notePath: String       // vault-relative path to the note
    let noteId: String         // SDPage id
    let rawBlockRange: Range<String.Index>  // range of the ```task``` block in note body
}

enum LiveNoteSchedule: Sendable {
    case cron(expression: String)
    case once(runAt: Date)
    case manual  // only runs on explicit trigger
}

@MainActor
final class LiveNoteScanner {

    /// Synchronous compatibility path retained for tests and callers that still
    /// link against the original signature. Production scheduling should use
    /// the async overload so bulk body reads happen off the main actor.
    func scanForLiveNotes(context: ModelContext) -> [LiveNoteTask] {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.isArchived == false }
        )
        let pages = (try? context.fetch(descriptor)) ?? []
        let candidates = pages.map(Self.snapshot(for:))
        let result = Self.scanTasks(from: candidates)

        log.info("LiveNoteScanner: found \(result.tasks.count) live tasks across \(result.pageCount) pages")
        return result.tasks
    }

    /// Production scan path — performs the full fetch/read/parse pipeline off the main actor.
    func scanForLiveNotes(modelContainer: ModelContainer) async -> [LiveNoteTask] {
        let result: LiveNoteScanResult = await Task.detached(priority: .utility) { () -> LiveNoteScanResult in
            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.isArchived == false }
            )
            let pages = (try? context.fetch(descriptor)) ?? []
            let candidates = pages.map(Self.snapshot(for:))
            return Self.scanTasks(from: candidates)
        }.value

        log.info("LiveNoteScanner: found \(result.tasks.count) live tasks across \(result.pageCount) pages")
        return result.tasks
    }

    private nonisolated static func snapshot(for page: SDPage) -> LiveNotePageSnapshot {
        LiveNotePageSnapshot(
            id: page.id,
            title: page.title,
            filePath: page.filePath,
            subfolder: page.subfolder,
            inlineBody: page.body,
            hasManagedBody: NoteFileStorage.bodyExists(pageId: page.id)
        )
    }

    private nonisolated static func scanTasks(from candidates: [LiveNotePageSnapshot]) -> LiveNoteScanResult {
        var tasks: [LiveNoteTask] = []
        tasks.reserveCapacity(candidates.count)

        for candidate in candidates {
            let body = loadBody(for: candidate)
            guard body.contains("live_note: true") || body.contains("live_note:true") else {
                continue
            }

            let parsed = parseTaskBlocks(
                from: body,
                notePath: notePath(for: candidate),
                noteId: candidate.id
            )
            tasks.append(contentsOf: parsed)
        }

        return LiveNoteScanResult(tasks: tasks, pageCount: candidates.count)
    }

    private nonisolated static func loadBody(for page: LiveNotePageSnapshot) -> String {
        let diskBody = NoteFileStorage.readBody(pageId: page.id, mapped: true, fast: true)
        if !diskBody.isEmpty || page.hasManagedBody {
            return diskBody
        }
        if !page.inlineBody.isEmpty {
            return page.inlineBody
        }
        if let filePath = page.filePath,
           !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fileURL = URL(fileURLWithPath: filePath)
            if let readableVaultBody = VaultIndexActor.decodedBodyFromReadableVaultFile(at: fileURL) {
                return readableVaultBody
            }
        }
        return ""
    }

    private nonisolated static func notePath(for page: LiveNotePageSnapshot) -> String {
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

    /// Parse all ```task``` fenced code blocks from a note body.
    private nonisolated static func parseTaskBlocks(from body: String, notePath: String, noteId: String) -> [LiveNoteTask] {
        var tasks: [LiveNoteTask] = []
        let pattern = "```task\\s*\\n([\\s\\S]*?)\\n```"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return tasks
        }

        let nsBody = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: nsBody.length))

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let jsonRange = match.range(at: 1)
            let jsonString = nsBody.substring(with: jsonRange)

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let instruction = json["instruction"] as? String,
                  let targetId = json["targetId"] as? String else {
                continue
            }

            // Parse schedule
            let schedule: LiveNoteSchedule
            if let scheduleDict = json["schedule"] as? [String: Any],
               let scheduleType = scheduleDict["type"] as? String {
                switch scheduleType {
                case "cron":
                    let expression = scheduleDict["expression"] as? String ?? "0 9 * * *"
                    schedule = .cron(expression: expression)
                case "once":
                    if let runAtStr = scheduleDict["runAt"] as? String,
                       let runAt = ISO8601DateFormatter().date(from: runAtStr) {
                        schedule = .once(runAt: runAt)
                    } else {
                        schedule = .manual
                    }
                default:
                    schedule = .manual
                }
            } else {
                schedule = .manual
            }

            // Parse lastRunAt
            let lastRunAt: Date?
            if let lastRunStr = json["lastRunAt"] as? String {
                lastRunAt = ISO8601DateFormatter().date(from: lastRunStr)
            } else {
                lastRunAt = nil
            }

            // Compute block range for later replacement
            let fullMatchRange = match.range(at: 0)
            guard let swiftRange = Range(fullMatchRange, in: body) else { continue }

            tasks.append(LiveNoteTask(
                instruction: instruction,
                schedule: schedule,
                targetId: targetId,
                lastRunAt: lastRunAt,
                notePath: notePath,
                noteId: noteId,
                rawBlockRange: swiftRange
            ))
        }

        return tasks
    }

    /// Check if a live note task is due for execution.
    func isDue(_ task: LiveNoteTask, now: Date = .now) -> Bool {
        switch task.schedule {
        case .cron(let expression):
            return isCronDue(expression: expression, lastRun: task.lastRunAt, now: now)
        case .once(let runAt):
            return task.lastRunAt == nil && now >= runAt
        case .manual:
            return false // only runs on explicit trigger
        }
    }

    /// Simple cron check: supports daily (hour match) and hourly (minute match).
    /// Full cron parsing is deferred — this covers the 90% case.
    private func isCronDue(expression: String, lastRun: Date?, now: Date) -> Bool {
        let components = expression.split(separator: " ").map(String.init)
        guard components.count == 5 else { return false }

        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: now)

        // If never run, it's due
        guard let lastRun else { return true }

        // Don't run more than once per hour (safety rail)
        if now.timeIntervalSince(lastRun) < 3600 { return false }

        // Check hour match (component 1) — handles "0 9 * * *" (daily at 9am)
        if components[1] != "*" {
            if let cronHour = Int(components[1]), cronHour == nowComponents.hour {
                return true
            }
        }

        // Hourly schedule: "0 * * * *"
        if components[0] != "*" && components[1] == "*" {
            if let cronMinute = Int(components[0]), cronMinute == nowComponents.minute {
                return true
            }
        }

        return false
    }
}
