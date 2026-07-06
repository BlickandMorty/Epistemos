---
name: proshell-native-fetch-decoder-boundary
description: Extract and harden JSON fetch/decode logic for ProShell native panels. Use when ProAgent, Goose, or Work SwiftUI views fetch server/runtime JSON, merge multiple sources, or render untrusted session/provider/tool metadata.
---

# ProShell Native Fetch Decoder Boundary

Use this skill when a native ProShell panel displays data fetched from a local runtime or web server.

## Method

1. Separate presentation from transport. SwiftUI views may call a fetcher, but JSON parsing, network requests, source merging, and fallback semantics live in a Foundation-only boundary.
2. Preserve failure semantics. Keep `nil`/failure distinct from an empty successful result when the UI must not tell users their data disappeared.
3. Decode leniently but safely. Accept known envelope variants, skip malformed rows, require non-empty identifiers, and preserve source-specific empty states such as 404-as-not-configured.
4. Bound all server-provided display strings before they reach the view: identifiers, titles, directories, provider labels, and diagnostics.
5. Add pure decoder tests for valid rows, malformed rows, unsupported payloads, bounded text, and source-specific defaults.
6. Add a source guard that the view delegates to the boundary and does not regain `URLSession` or `JSONSerialization` parsing.

## Checks

- Run `swiftc -typecheck` on the Foundation-only boundary first.
- Confirm the SwiftUI view shrinks or at least does not grow.
- Boundary-scan staged files for protected paths before committing.
