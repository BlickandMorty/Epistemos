# Hermes Risk Register & Failure Modes

> **Index status**: CANONICAL-RESEARCH — Hermes integration research (Phase D + K reference).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/hermes_research/`.



| Failure Mode | Threat Target | Consequence | Implemented Mitigation |
| ------------- | ------------- | ----------- | ----------------------- |
| Intel Cold-Start Latency | System UX | Python takes > 300ms causing chat freeze | Deferred lazy startup on `HermesSubprocessManager` |
| Malformed Bundle/Zip Corruption | Updates | CI creates botched dependency payload | Signature Verification logic dropping bad `.sig`/`.zip` blobs |
| Retry Loop Rate-Limiting | API Service | Upstream LLMs rejecting continuous looped payloads | Subprocess supervision sets exponential backoff inside `HermesLifecycleState` |
| Crash Loop Iterating Core | Stability | Agent continually faulting on boot | Supervisor caps restarts count to 3. Fallbacks to `disabled` banner |
| Silent File Exfiltration | Device Security | Agent leaks internal sensitive configs | `shell_sandboxed` removes directory pathing options enforcing `/Workspace/` |
| Shared-Secret Sniffing | Process Scope | Attackers viewing bash ENV for process injection | Keys bound exclusively inside loopback via API reference IDs |
| Denied Notification Grants | OS Context | User loses task progress alerts blindly | Secondary `HermesCompletionBanner` toasts inside app UI actively |
| Playwright CodeSign Break | Code Signing | Auto-updaters breaking universal binary certs | Hardened runtime allows bundled dylibs by passing explicit allow-rules |
| Disk Usage Bloat | Storage | Browsers/caches absorbing macOS space infinitely | Auto-cleanup cycles discarding cache inside `__hermes__/tasks` |
| Dynamic Schema Drift | Integration | Hermes updating expected JSON parameters | Version headers exchanged inside `POST /v1/epistemos/bootstrap` handshake |
