import Foundation

// Mini-session ontology — increment 6 (pure core): bridge the OpenWork worker's `GET /workspace/:id/sessions`
// response → native `[WorkSession]`. Each OpenCode session item is `{ id, parentID?, title?, … }`. Classification
// matches the donor `getRootSessions` (apps/app sidebar/utils.ts): a session is a MAIN (root) when it has no
// `parentID` OR its parentID is an ORPHAN (not among the returned ids); otherwise it's a MINI whose
// `parentSessionID` is that parentID. `id` doubles as the bound `openCodeSessionID`. Pure + testable; callers fetch
// and upsert into `WorkSessionStore`.
enum WorkSessionMapper {
    nonisolated static func workSessions(fromSessionsJSON data: Data, workspaceID: String) -> [WorkSession] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]] else { return [] }
        let ids = Set(items.compactMap { $0["id"] as? String })
        return items.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            let title = item["title"] as? String
            let parentID = (item["parentID"] as? String)?.trimmingCharacters(in: .whitespaces)
            if let parentID, !parentID.isEmpty, parentID != id, ids.contains(parentID) {
                // Mini: parent is a known session → inherit the workspace; id is the bound OpenCode session.
                return WorkSession(id: id, kind: .mini, parentSessionID: parentID, presentation: .attached,
                                   workspaceID: workspaceID, openCodeSessionID: id,
                                   title: WorkSession.normalizedTitle(title))
            }
            // No parent / orphan parent / self-parent → root tab (matches donor getRootSessions).
            return WorkSession.main(id: id, workspaceID: workspaceID, openCodeSessionID: id, title: title)
        }
    }

    // OpenGUI PATH (pivot 2026-06-24): bridge the OpenGUI sidecar's `sessions.list` reply → native `[WorkSession]`.
    // The sidecar (og-sidecar.mjs) returns `data` = a flat ARRAY `[{ id, title? }, …]` (NOT the worker's
    // `{items:[…]}` wrapper). CRITICAL ontology fact (verified against `@opengui/runtime` SessionSummary, which is
    // `{id,title?,status?,directory?,createdAt?,updatedAt?}` — NO parentID): OpenGUI's list cannot express parent
    // lineage, so EVERY listed session maps to a MAIN/root. Mini/parent lineage is EPISTEMOS-OWNED — Work creates a
    // mini `WorkSession` locally with its own `parentSessionID` and binds `openCodeSessionID` to a child OpenGUI
    // session; the parent link lives in the WorkSession layer, never derived from OpenGUI (Epistemos owns identity).
    // The OpenGUI session `id` is already engine-namespaced (`harnessId:sessionId`, e.g. `opencode:ses_…`) and stable
    // across restarts → it doubles as `openCodeSessionID`, preserving recents/identity. Pure + testable.
    nonisolated static func workSessions(
        fromSidecarListJSON data: Data, workspaceID: String
    ) -> [WorkSession] {
        guard let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let id = item["id"] as? String, !id.isEmpty else { return nil }
            return WorkSession.main(
                id: id, workspaceID: workspaceID, openCodeSessionID: id,
                title: WorkSession.normalizedTitle(item["title"] as? String))
        }
    }
}
