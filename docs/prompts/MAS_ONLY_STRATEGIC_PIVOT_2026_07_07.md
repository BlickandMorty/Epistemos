# MAS-Only Strategic Pivot — 2026-07-07

Instruction lock ID: `MAS-ONLY-SHIP-LOCK-2026-07-07`.

Owner intent checkpoint:
- Verbatim owner steer: "all the plans i want them all to be competely redirected towards mas ... completel stopping pro and experient and just going full mas no other builds atp ... mas version is good hardenend and that all plans are tailroed toward mas and mas alone."
- Interpreted intent: Epistemos should now optimize for one shippable Mac App Store product. Pro, Developer-ID, Experimental, 1Code, OpenChamber, and Kindred runtime work are no longer active execution lanes.
- Hard constraint: preserve useful product ideas only when they can be rebuilt through MAS-safe architecture: App Store sandbox, in-process `agent_core`, June, Swift/AppKit/SwiftUI, WKWebView with bundled assets, security-scoped vault access, Keychain secrets, no hidden sidecars, no runtime subprocess, no local server, no stdio MCP, no terminal/code-exec tools.
- Non-goal: do not delete old research, donor analysis, or historical plan reasoning just because it mentions Pro/Experimental. Treat it as provenance unless this lock explicitly promotes it.

## Active Product Target

The only active target is the Mac App Store app:

- `Epistemos-AppStore`
- `EPISTEMOS_APP_STORE`
- `MAS_SANDBOX`
- June as the sole active agent surface
- `agent_core` in-process via FFI
- local/private lane honestly gated as chat/light-agent unless tool grammar is proven
- cloud lane through the receipt-gated proxy and per-turn approval surfaces

Any plan row, prompt, codepack, build note, or research line that says "both builds",
"Experimental/1Code", "Developer-ID", "Pro", "OpenChamber", "Goose surface", "browser-use
Pro", "Kindred companion", "Node backend", "terminal", "stdio MCP", or "subprocess OK"
is suspended for current execution unless it is explicitly rewritten in MAS terms.

## Redirection Rules

1. **MAS/June is the agent.** All agent-facing capability work routes through June +
   `agent_core`. Do not build or revive a second user-facing agent lane.
2. **1Code/Kindred becomes pattern-provenance only.** Salvage ideas such as compact
   Epdoc assist, visible run state, staged edits, provenance, and acceptance flows, but
   implement them as MAS-June surfaces. Do not port 1Code transports, Node runtime,
   Kindred presence, tRPC, terminal, file-viewer, or companion authority.
3. **LumenLens remains active as MAS editor infrastructure.** Its suggestion adapter,
   provenance ledger, minimal-diff writeback, notebook/container work, and fidelity
   disclosures are active only insofar as they support MAS June, notes, datasets, and
   App Store-safe editing.
4. **Reckoner remains active as MAS data infrastructure.** Datasets live in the note
   workspace and vault artifacts; June drives dataset tools through `agent_core`.
   Presence and Kindred-specific paths are parked.
5. **Keelstone remains active as MAS storage/release infrastructure.** Collapse any
   two-surface wording into an App Store release gate, vault safety, security-scoped
   access, sync durability, and MAS leak/symbol checks.
6. **Capabilities remain active only through MAS-safe implementations.** Native/WKWebView
   Browser, PDF, arXiv/ResearchHub, Voice/STT, Quick Capture, Skills, and vault tools may
   ship if they obey App Store constraints. Browser-use/Chromium/Python/subprocess lanes
   are parked.
7. **Icons/design remain active for the MAS app.** Any web-token mirror targets the
   bundled June/Epdoc/Reckoner web surfaces, not Experimental/1Code.

## MAS Acceptance Bar

No plan phase is complete unless it can be proven in the MAS build or is explicitly
documented as a parked research artifact. Evidence should include the relevant source
guards, App Store build/test commands, leak/symbol scans for parked lanes, manual runtime
proof where UI changed, vault permission proof where storage changed, and App Review-
aware privacy/permission notes where user data or cloud routing is involved.

## Agent Handoff Sentence

When handing work to another agent, include this sentence:

> Read `docs/prompts/MAS_ONLY_STRATEGIC_PIVOT_2026_07_07.md` first. Treat MAS as the only active product target. Preserve useful non-MAS ideas only by rebuilding them through MAS-safe June, `agent_core`, native Swift/AppKit/SwiftUI, WKWebView-bundled assets, and App Store sandbox constraints.
