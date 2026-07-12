# MAS C Feature Plan - MAS June

ID: `MAS-C-F02-MAS-JUNE-2026-07-08`
Codename: `MAS-JUNE`
Status: active after Keelstone release safety

## Intent

Make June the only active agent surface for the MAS app. Keep the feel of a
native macOS product while using bundled June web assets only where they are the
honest best host for agent UI.

## Scope

- Native shell owns window, toolbar, docks, permissions, and status.
- Bundled WKWebView may host June UI assets.
- `agent_core` owns tool registry, event stream, provenance, and approvals.
- Cloud and local lanes are explicit, user-approved, and logged.
- Legacy Goose/Hermes names are migrated or documented without breaking behavior.

## Fabric Mapping

- F1 vault bus: June reads/writes only through approved vault capabilities.
- F2 agent capability registry: single registry in `agent_core`.
- F3 MAS status/provenance: live run state renders in native and June surfaces.
- F4 graph: agent-created links use public graph API.
- F5 provenance: every tool call has intent, approval, source, and result.
- F6 event bus: one state/event stream feeds all MAS surfaces.

## Phases

1. Map current June bridge, gateway, WKWebView, and `agent_core` seams.
2. Separate legacy naming from actual runtime behavior.
3. Remove or document any entitlement needed for loopback-only bridge behavior.
4. Harden approval, cancellation, rollback, and no-hidden-cloud behavior.
5. Verify native shell quality and bundled-asset loading.

## Parked Or Forbidden

- No second agent surface.
- No 1Code/Experimental renderer as active path.
- No terminal/code-exec or browser-use tool.
- No hidden cloud fallback.
- No subprocess agent runtime in MAS archive.

## Acceptance Evidence

- MAS build/test checkpoint.
- Bridge map and naming migration plan.
- Tool registry proof showing one active authority.
- Approval/cancel/rollback proof for a real tool call.
- Archive scan showing no forbidden helper runtime.
- Manual UI proof for native shell plus bundled June loading.

