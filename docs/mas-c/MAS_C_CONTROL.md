# MAS C Control Lock

ID: `MAS-C-CONTROL-2026-07-08`

## Owner Intent

The owner is pivoting all current product work to one Mac App Store release.
The desired product should feel hard, native, durable, and top-company quality:
closer to a carefully made AppKit/Swift/macOS application than a fragile web
reskin. Feature ideas from older tracks may survive only if rebuilt through the
MAS architecture.

## Active Constraints

- `Epistemos-AppStore` is the only active target.
- `EPISTEMOS_APP_STORE` and `MAS_SANDBOX` are the active compile-time surface.
- June is the only active user-facing agent surface.
- `agent_core` is the in-process authority for tools, events, provenance, and
  state.
- Vault access must use App Sandbox-safe user-selected access, security-scoped
  bookmarks, Keychain for secrets, and App Review-readable privacy notes.
- Bundled WKWebView assets are allowed when they are static, local, and
  reviewable.
- Native Swift/AppKit/SwiftUI should own shell, windowing, panels, docks,
  status, file access, and review-sensitive permission surfaces.

## Parked Or Forbidden For Current Execution

- Pro, Developer-ID, Experimental, 1Code, OpenChamber, and Kindred runtime work.
- Terminal tools, arbitrary code execution, browser-use Chromium, Python helper
  runtimes, Node backend authority, stdio MCP, hidden sidecars, and unreviewed
  local network services.
- Database-as-truth storage that can diverge from the vault.
- Research sources that require unowned commercial licenses, scraping, or
  bypassing paywalls.

## Important Clarification

The Cursor packet found names such as `GooseInProcessACPServer` and
`hermes_bridge_*` in current code and archives. MAS C does not treat names alone
as proof of a hidden subprocess. The rule is:

- In-process, bundled, loopback-only, owner-gated bridges can be temporarily kept
  if they are documented, entitlement-justified, leak-scanned, and eventually
  renamed to neutral June/MAS terms.
- Any separate `goose`, `goosed`, Chromium, Node, Python, or terminal subprocess
  in the MAS archive is forbidden.

## Live Known Blockers To Resolve

- `Epistemos/Epistemos-AppStore.entitlements` currently contains
  `com.apple.security.network.server = true`; justify it with a loopback-only
  MAS bridge note or remove it.
- App Store target membership and release archives need repeated leak scans for
  parked lanes and helper runtimes.
- `JuneAgentGateway` currently references a Goose-named in-process helper; rename
  or document it without changing functionality.
- `hermes_bridge_*` JS handler names are wire-compatible legacy names; keep only
  while documented, then migrate carefully.
- App Store hardening tests must encode MAS-only truth rather than dual product
  assumptions.

## Current External Policy Anchors

- Apple says App Store Connect uploads since April 28, 2026 require Xcode 26 or
  later and current platform SDKs.
- Apple required-reason API and privacy manifest rules remain active; the app
  must declare reasons accurately.
- Reddit API use can require additional terms and app review/approval; do not
  ship commercial Reddit API features without explicit clearance.

## Done Means

No MAS C feature is done until it has:

- A plan doc.
- A build prompt.
- F1-F6 integration mapping where relevant.
- MAS legality and source-legality status.
- Runtime or source evidence sized to the claim.
- A release-gate path that can prove no parked lane leaked into the MAS app.

