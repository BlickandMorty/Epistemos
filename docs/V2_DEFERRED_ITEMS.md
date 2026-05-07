# V2 Deferred Items

This ledger tracks release-audit items that are intentionally excluded from the v1 hardening pass. These are not v1 bugs unless they run unexpectedly, crash the app, or claim user-facing readiness without a working path.

## 2026-05-07 V1 Release Audit

- Visual Verify runtime bridge — deferred to v2. `VisualVerifyLoop` remains a tested helper, but `AppBootstrap` does not construct or inject it for v1; `DeviceAgentService`, `ScreenCaptureService`, and `Screen2AXFusion` stay lazy until a future bridge slice wires post-action verification deliberately.
- Browser automation first-class app surface — deferred to v2. v1 keeps the Pro-build `agent-browser` CLI wrappers with graceful missing-binary errors; no in-app Chrome MCP or native browser-control surface ships in v1.
- Skill-generated tool registration and autonomous self-evolution promotion — deferred to v2. v1 ships Skill Hub discovery/create/install plus prompt-context loading, while runtime registration of newly authored tools remains out of scope.
- Shadow continuous FSEvents crawler — deferred to v2. v1 ships the production `RustShadowFFIClient` path and bootstrap crawl, while continuous vault watching stays behind the documented W8.7 follow-up.
