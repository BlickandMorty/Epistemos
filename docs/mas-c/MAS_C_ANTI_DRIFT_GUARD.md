# MAS C Anti-Drift Guard

ID: `MAS-C-ANTI-DRIFT-GUARD-2026-07-08`

This guard is the preflight check before a MAS C agent edits code or updates
the packet. It turns the owner intent into concrete contradictions to search
for and resolve.

## Owner Intent Lock

MAS C means:

- one App Store product
- native macOS shell quality
- MAS June as the only active agent surface
- in-process `agent_core`
- vault files as truth
- append-only provenance/op-log as witness
- derived indexes that can be rebuilt
- source/legal review before network research features
- no wrapper, reskin, or token-only interpretation of "new stack"

Interpret product-weight words through `MAS_C_TERMINOLOGY_CANON.md` before
editing.

## Red Flags

If an agent sees any of these in an active implementation plan, it must pause
and classify the finding before editing:

- a current product lane for Pro, Developer-ID, Experimental, 1Code,
  OpenChamber, or Kindred runtime work
- a second active chat or agent backend
- terminal/code-exec tools in the MAS product
- browser automation through a bundled Chromium runtime
- Node, Python, or other helper runtime as MAS authority
- a sidecar or subprocess that cannot be explained as App Store-safe behavior
- database or proprietary storage claiming silent truth over vault files
- source ingest that depends on scraping, paywall bypass, or unclear commercial
  terms
- visual "upgrade" work that changes only wrappers, colors, tokens, or blur
  without replacing real component ownership or behavior

## Required Classification Labels

Use these exact labels in evidence notes:

- `active-mas`: valid current MAS behavior
- `legacy-name`: name is stale but behavior is valid and in-process
- `parked-provenance`: historical research or old plan text, not active build
- `forbidden-mas-runtime`: must not ship in MAS archive
- `needs-owner-decision`: cannot classify safely from current evidence
- `needs-official-source`: depends on current policy, API, SDK, license, or
  source terms

## Local Search Set

Run focused local searches before substantial edits:

```bash
rg -n "Experimental|1Code|OpenChamber|Kindred|Developer-ID|ProAgent|browser-use|Chromium|node|python|stdio MCP|terminal|subprocess" docs/mas-c project.yml Epistemos EpistemosTests
rg -n "database.*truth|DB.*truth|source of truth|rebuildable|op-log|provenance|security-scoped|network.server" docs/mas-c Epistemos docs/prompts
rg -n "wrapper|reskin|polish|blur|new stack|replace|revamp|V2|AppKit|SwiftUI|WKWebView" docs/mas-c Epistemos docs/prompts
```

Hits are not automatically failures. They are classification work.

## External Fact Check Triggers

Use official/current sources before editing when the work touches:

- App Store policy, entitlement behavior, sandboxing, privacy manifests, or
  required-reason APIs
- source/API terms for ResearchHub, Reddit, X, papers, datasets, or web content
- Apple framework behavior, Xcode upload requirements, CloudKit/iCloud, StoreKit,
  Speech, AVFoundation, WebKit, or security-scoped bookmarks
- third-party component libraries, licenses, or shipped binaries

## Packet Consistency Checks

After editing MAS C docs, run:

```bash
find docs/mas-c -type f | sort
git diff --check -- docs/mas-c
find docs/mas-c -name '*.md' -type f -exec sh -c 'for f do grep -q "^ID:" "$f" || echo "missing ID: $f"; done' sh {} +
find docs/mas-c/features -mindepth 1 -maxdepth 1 -type d -exec sh -c 'for d do test -f "$d/PLAN.md" || echo "missing PLAN: $d"; test -f "$d/BUILD_PROMPT.md" || echo "missing BUILD_PROMPT: $d"; done' sh {} +
LC_ALL=C rg -n "[^\x00-\x7F]" docs/mas-c
```

Then run the current contradiction and placeholder scans from the active
objective audit, confirm evidence expectations still match
`MAS_C_EVIDENCE_PROTOCOL.md`, refresh the zip, and record the new file count.

## Drift Resolution

When drift is found:

1. Do not rewrite broad docs immediately.
2. Identify whether the drift is active instruction, historical provenance, or
   an implementation artifact.
3. If active instruction conflicts with MAS C, update the smallest doc that owns
   the contradiction.
4. If code behavior conflicts with MAS C, create a feature work item rather than
   pretending the docs solved it.
5. Re-run the packet checks and update `MAS_C_TRACEABILITY_MATRIX.md`.
