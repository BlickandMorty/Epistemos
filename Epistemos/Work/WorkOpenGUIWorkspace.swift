import Foundation

// Resolves the Work workspace directory the OpenGUI runtime operates in. VERIFIED against `@opengui/runtime`
// directory-safety.ts `resolveSafeDirectory`: the runtime requires an EXISTING DIRECTORY under `allowedRoots` — it
// does NOT require a git repo (it does `realpath` + `isDirectory` + under-roots; there is no git check). OpenCode
// `serve` likewise runs in any directory. So this just ensures a stable Epistemos-managed workspace exists; the
// supervisor passes the result as BOTH `repo` and the sole `allowedRoots` entry. (Per-vault / per-project workspaces
// are a later refinement; this gives the live ⌘R create/send/stream proof a real, valid path — the last gap.)
enum WorkOpenGUIWorkspace {
    /// The default Epistemos-managed Work workspace under Application Support, created on demand. Falls back to a temp
    /// directory if Application Support is unavailable; nil only if even that can't be created (effectively never).
    static func ensureDefault() -> URL? {
        let fileManager = FileManager.default
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return ensure(at: base.appendingPathComponent("Epistemos/WorkOpenGUI/workspace", isDirectory: true).path)
    }

    /// Ensure an arbitrary directory exists (for a caller-chosen workspace, e.g. the active vault root) and return it.
    /// The runtime needs the dir to EXIST (`realpath`) before `connect`; this guarantees that. nil on empty/failure.
    @discardableResult
    static func ensure(at path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch {
            return nil
        }
    }
}
