# MAS C Terminology Canon

ID: `MAS-C-TERMINOLOGY-CANON-2026-07-08`

This canon defines product-weight language for MAS C. It exists so agents do
not flatten owner intent into wrappers, token edits, reskins, or shallow
compatibility changes.

## Product-Weight Terms

| Term | MAS C meaning | Insufficient interpretation | Required proof |
|---|---|---|---|
| `whole new stack` | A changed ownership model for the relevant surface: native shell boundaries, component ownership, event/state authority, storage/tool authority, and release evidence all align with MAS C. | Adding a package, wrapper, theme layer, or CSS token set while old component authority remains. | Ownership map, files changed, behavior proof, and before/after evidence where visible. |
| `replace` | Remove or bypass the old active behavior for the requested scope and make the MAS C path the active path. | Leaving old behavior active under a new wrapper or alias. | Source search showing active path changed and release/behavior check proving the old path is parked or gone. |
| `revamp` / `upgrade` / `V2` | Structural product improvement with new behavior, stronger evidence, and no old-lane drift. | Color, blur, spacing, copy, or package-presence changes alone. | Acceptance checks tied to behavior, architecture, and visible outcome. |
| `hard` / `ceramic` / `glass` feel | Durable native macOS quality: stable layout, real native ownership where it matters, predictable state, fast response, no fragile web shell illusion. | Heavy blur, gradients, decorative material, or motion without better component/state ownership. | Native/WKWebView ownership map, screenshot/runtime evidence, text-fit/accessibility checks, and state proof. |
| `native` | AppKit/SwiftUI owns shell, windowing, permissions, sidebars, docks, panels, status, file access, and review-sensitive surfaces. | A web component styled to look macOS-like. | File/component map naming native owners and any WKWebView boundary. |
| `WKWebView` | A bundled, local, reviewable host for rich surfaces when web tech is the honest best implementation host. | A hidden browser app, remote web app, or escape hatch for forbidden runtimes. | Asset bundling proof, no remote authority, bridge/event contract, and release scan. |
| `MAS June` | The sole current agent surface backed by in-process `agent_core`. | A second chat, 1Code fork, Goose/Kindred runtime, or visual clone. | One-agent-authority map and proof that no parallel agent backend is current product behavior. |
| `MiniChat` / `Epdoc Assist` | Native Epdoc dock using MAS June session, context, approvals, provenance, and undo. | 1Code embedded again or a second isolated assistant. | Selected-context proof, read-only flow, approved write flow, undo/provenance proof. |
| `storage truth` | User-visible vault files and artifacts are authoritative; op-log/provenance is witness; indexes are derived unless proven otherwise. | Database or proprietary cache silently becoming truth. | Vault before/after, rebuild proof, rollback/recovery proof, and no-divergence check. |
| `proprietary storage` | Optional acceleration, witness, or recovery layer that raises quality while preserving vault reconstruction and user data ownership. | Locking data into an opaque store or hiding divergence. | Export/reconstruct proof, migration/rollback plan, and data-loss fixtures. |
| `release ready` | MAS build/test/archive/privacy/entitlement/source/legal evidence all support the claim. | Build green, source guard green, or docs updated. | Full release evidence pack from `MAS_C_EVIDENCE_PROTOCOL.md`. |
| `parked` | Historical/provenance-only; not active product behavior, target membership, or release artifact. | Merely renamed while still active. | Target membership or release scan proof when relevant. |
| `legacy-name` | A stale name for valid in-process MAS behavior that is temporarily documented and gated. | A reason to keep forbidden runtime behavior. | Classification note, behavior map, release scan, and rename/document decision. |
| `wrapper` | A shell around old behavior. Wrappers are allowed only when they are explicit transition scaffolding and not claimed as replacement. | Presenting the wrapper as the actual refactor. | Old/new ownership map and removal/migration plan. |
| `polish` | Final fit-and-finish after behavior and ownership are correct. | Substitute for architecture, component, or state replacement. | Screenshot/manual evidence plus proof core behavior already changed. |

## Interpretation Rule

When owner wording is emotional, metaphorical, or brain-dumped, preserve the
exact excerpt first, then translate it into:

1. product surface
2. active old behavior being rejected
3. desired new ownership/behavior
4. non-goals
5. acceptance evidence

If the translation cannot identify old behavior and new ownership, the agent
must perform a read-only mapping pass before editing.

## UI Stack Rule

A MAS C UI stack is not proven by a dependency list. It is proven by:

- which layer owns layout
- which layer owns state
- which layer owns events
- which layer owns persistence
- which layer owns permissions
- which layer owns release-sensitive behavior
- screenshots or runtime evidence for visible surfaces

For the active MAS product, native AppKit/SwiftUI should own the shell and
review-sensitive surfaces. Bundled WKWebView may own rich editor/agent/data
surfaces only when its bridge is explicit, local, and reviewable.

## Storage Language Rule

When a plan mentions storage, it must name:

- truth layer
- witness layer
- derived layers
- rebuild path
- rollback path
- user-visible artifact
- data-loss test or fixture

If it cannot name those, it is not ready for implementation.

## Agent Language Rule

When a plan says "agent", it means MAS June through in-process `agent_core`.
Any other agent-like surface must be labeled `parked-provenance`,
`legacy-name`, `forbidden-mas-runtime`, or `needs-owner-decision`.
