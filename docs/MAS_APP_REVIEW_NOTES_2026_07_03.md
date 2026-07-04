# Epistemos — Mac App Store Review Notes (Plan 1-MAS)

**Draft for App Review submission. Adapt at submission time.** Sources: Plan
1-MAS §4 + the converged canon (`GOOSE_MAS_BUILD_CANON_2026_06_30.md` §6
ready-to-submit notes). This is the reviewer-comprehensibility artifact the
canon says you win or lose on (Guideline 2.5.2).

## What the app is

Epistemos is a self-contained, sandboxed research-and-writing assistant. It
has two clearly separate AI surfaces:

- **Quick Chat ("Ask") — local, free, no account.** Answers are generated
  **entirely on the user's Mac**: Apple Foundation Models when Apple
  Intelligence is available, or an optional user-downloaded open-weights model
  run by a bundled, code-signed inference engine (llama.cpp, embedded as a
  linked library — no helper process). Nothing this surface sends leaves the
  device.
- **Agent Workspace — cloud, subscription.** A multi-step assistant that
  reasons and acts using a third-party cloud AI provider, reached only over
  HTTPS through Epistemos's own backend proxy.

## Guideline 2.5.2 — self-contained, no downloaded/executed code

- All agent logic and every tool are compiled into the app. It does **not**
  download, install, or execute code at runtime, and cannot be extended with
  user-supplied code or local plug-ins.
- The optional local model files are **data** — opaque model parameters parsed
  by the bundled, signed inference engine (the PocketPal AI / Private LLM
  precedent). They are not code, contain no executables/scripts/plug-ins, and
  are stored in the app's container, never in `Contents/Frameworks` or any
  shared location.
- The app spawns **no subprocesses**, runs **no shell**, opens **no listening
  ports / runs no local server**, uses **no AppleScript/Apple Events**, and
  does not use the Accessibility API. (These capabilities exist only in a
  separate Developer-ID edition, not this build.)
- The Agent Workspace tool set is a fixed, in-binary allowlist: vault
  read/write (via the standard open panel + security-scoped bookmarks),
  in-app document conversion and knowledge search, and a fixed set of remote
  HTTPS services. There is no "add MCP server", no extension installer, and no
  deep-link installer.

## Guideline 5.1.2(i) — third-party AI consent (Nov-2025)

Before any user content is transmitted, an in-app consent screen names the
third-party AI provider and the destination host, and requires explicit
permission — **per provider, revocable in Settings**. The free Quick Chat
surface sends nothing off-device and shows no such prompt because none is
needed.

## Guideline 2.4.5 — self-contained, no background persistence

Sandboxed; no auto-launch; no background daemon. The subscription is verified
server-side via the App Store Server API (StoreKit 2; the deprecated
`verifyReceipt` is not used); provider API keys exist only on the server, never
in the binary. Session tokens are stored in the macOS Keychain.

## Entitlements (this build)

- `com.apple.security.app-sandbox` — yes
- `com.apple.security.network.client` — yes (cloud provider proxy + optional
  model downloads)
- `com.apple.security.files.user-selected.read-write` +
  `com.apple.security.files.bookmarks.app-scope` — yes (the vault folder)
- `com.apple.security.network.server` — **not set** (native UI needs no
  loopback)
- JIT / unsigned-executable-memory / disable-library-validation — **none**
  (the local Metal inference path needs no JIT; verified on a release-signed
  build)
- `Info.plist: ITSAppUsesNonExemptEncryption` = false (standard HTTPS via
  URLSession is export-exempt)

## Verification performed

- The embedded llama.cpp engine generates tokens via Metal **inside the App
  Sandbox with `app-sandbox` as the only entitlement** (no JIT), on a
  release-signed build. Re-runnable witness:
  `scripts/llama-mas-sandbox-spike.sh`.
- The in-process cloud agent path streams a real multi-step turn (thinking,
  a sandbox-legal tool call, an approval round-trip, completion) over the
  in-process Rust runtime with no subprocess and no open port. Re-runnable
  witness: `scripts/agent-core-mas-spike.sh`.

## Open-ended chat safeguards (Guideline 4.7)

The agent is treated as embedded functionality serving only the app's own UI.
Open chat surfaces include content filtering and a report/block affordance;
age rating declared conservatively for open-ended AI with web access.
