# MAS C Feature Plan - Capabilities

ID: `MAS-C-F09-CAPABILITIES-2026-07-08`
Codename: `CAPABILITIES`
Status: active after MAS June and Keelstone

## Intent

Expose useful app capabilities to MAS June without smuggling in forbidden
runtime assumptions. Capabilities should feel native, permissioned, and
auditable.

## Scope

- PDF ingest and markdown/provenance extraction.
- Native or WKWebView browser surfaces where MAS-safe.
- Voice/STT where permissioned.
- Skills/tool registry entries backed by `agent_core`.
- Vault tools, graph tools, source tools, and editor tools.

## Fabric Mapping

- F1 vault bus: outputs become vault notes/artifacts.
- F2 agent capability registry: all capabilities register through `agent_core`.
- F3 MAS status/provenance: each tool reports real run state.
- F4 graph: capability outputs link through public graph API.
- F5 provenance: records source, transform, confidence, and approval.
- F6 event bus: streams capability lifecycle.

## Phases

1. Inventory existing capabilities and classify MAS-safe, parked, forbidden.
2. Define capability schema and approval gates.
3. Implement one safe capability end to end.
4. Add provenance, undo/rollback, and UI evidence.
5. Add release guards preventing forbidden runtime leakage.

## Parked Or Forbidden

- Browser-use Chromium is parked/forbidden for MAS execution.
- Python helper automation is forbidden in MAS.
- Terminal/code-exec tools are forbidden.
- Any source capability with unclear license is parked.

## Acceptance Evidence

- Capability classification matrix.
- One safe capability proof through MAS June.
- Provenance and rollback evidence.
- Release scan for forbidden helpers.
- Manual UI evidence when visible.

