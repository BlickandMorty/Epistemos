# V1 Ship Gate Decision

Date: 2026-04-28

Decision: Mac App Store V1 should ship a small, native, sandbox-safe surface: Prose, Chat, Search, Graph, Settings/Privacy, local/cloud model management, and only the parts of Raw Thoughts, Contextual Shadows, Documents, and Code that are proven end to end. Powerful unfinished systems stay hidden or direct-build-only.

## Required Ship-Gate Table

| Feature | Current state | Ship V1? | Hide? | Remove? | Direct build only? | Reason |
|---|---|---|---|---|---|---|
| Prose editor | Built/wired/core | YES | NO | NO | NO | Protected native thinking surface |
| Chat | Built/wired | YES | NO | NO | NO | Core workflow; provider routing/copy must stay exact |
| Search | Built with FTS/readable-block substrate | YES | NO | NO | NO | Must verify artifact/block jump targets |
| Graph | Built/wired | YES | NO | NO | NO | Keep current renderer; no risky graph rewrites before V1 |
| Settings/privacy | Built | YES | NO | NO | NO | MAS copy and tests required |
| Contextual Shadows | V0 state/UI exists behind env flag | YES if P1 proof passes | YES until proof | NO | NO | V1 differentiator; needs end-to-end and no-hitch proof |
| Instant Recall substrate | Built | YES | NO | NO | NO | Async-only rebuild required |
| Raw Thoughts | V0 Rust/Swift/UI exists behind env flag | YES if recovery/provenance tests pass | YES until proof | NO | NO | Must store observable surfaces only |
| `.epdoc` Documents | Built as package/NSDocument/Tiptap shell | MAYBE, gated | YES until smoke passes | NO | NO | Not absent; current gap is user-path proof |
| Code editor | Built with CodeEditSourceEditor and custom support | YES as current editor | NO | NO | NO | 4k-line performance/gutter proof required before marketing as high-performance |
| Code line gutter | Partial/existing logic | YES if benchmark/theme proof passes | YES if not proven | NO | NO | User requested refined non-conflicting line count |
| Quick Capture | Partial/unclear | TBD | YES if no proof | NO | NO | Must save to vault and update derived stores |
| Local model catalog/downloads | Built/partial | YES | NO | NO | NO | Storage and network disclosure required |
| Cloud providers | Built | YES | NO | NO | NO | User-sent content disclosure required |
| MCP safe built-ins | Built/partial | YES subset | NO | NO | NO | MAS only safe vault/search tools |
| Agent runtime | Built | LIMITED | Hide advanced toggles | NO | Direct build for risky tools | No reachable stubs or unsafe automation |
| Computer use | Built outside MAS, stubbed MAS | NO MAS | YES MAS | NO | YES | Screen/AX/CGEvent review risk |
| Shell/PTY/Docker tools | Built/partial | NO MAS | YES MAS | NO | YES | Arbitrary execution risk |
| iMessage automation | Built/partial | NO MAS until reviewed | YES | NO | YES likely | Sensitive entitlement/review risk |
| Agent Command Center | Partial | NO V1 unless already stable | YES | NO | MAYBE | Too broad for MAS V1 |
| Diagnostics panel | Partial | OPTIONAL hidden | YES by default | NO | NO | Useful for developer/test builds |
| Deterministic Knowledge Runtime v1 | Research/partial | NO V1 by default | YES | NO | NO | Needs separate preflight and end-to-end benchmarks |
| Tiptap advanced export DOCX/PDF | Not V1 | NO | YES | NO | NO | Exports are derived/on-demand later |

## P0 Must Clear Before V1

1. MAS build passes after all Settings/Info.plist/entitlement changes.
2. Computer-use, shell, PTY, Docker, and arbitrary external MCP execution are hidden or stubbed in MAS.
3. PrivacyInfo and Settings copy match actual data flow.
4. No reachable hard crash/stub in core open/edit/search/chat/graph/settings flows.
5. User canonical data is not overwritten by derived projections.

## P1 Must Clear Before Public Beta

1. Contextual Shadows V0 end-to-end test and no-hitch proof.
2. Raw Thoughts JSONL recovery and provider opaque preservation tests.
3. `.epdoc` package smoke if Documents are visible.
4. Code editor 4k-line performance and Unicode range tests.
5. Search/readable-block integration for every visible artifact kind.
6. Graph/search deletion and rename consistency proof.

## Hide / Keep Disabled For V1 Unless Proven

- Contextual Shadows if result routing/open behavior is not green.
- Raw Thoughts if JSONL recovery/provider-preservation tests are not green.
- Documents if open/save/search smoke is not green.
- Quick Capture if save/index/graph update is not green.
- Agent Command Center and broad automation.
- Diagnostics unless under Advanced/developer mode.

## Direct-Build-Only

- ScreenCaptureKit/AX/CGEvent computer use.
- Shell/PTY/Docker/local process tools.
- External MCP servers with arbitrary filesystem/process/network permissions.
- iMessage automation until App Store-specific review is complete.

## Final Ship Gate

V1 is approved only after:

- Pro and MAS builds pass from raw logs.
- Targeted P0/P1 tests pass.
- Manual-only Phase S gates are either completed later by the user or explicitly excluded from a non-ship development milestone.
- Bundle size and major resource sizes are recorded.
- Privacy/App Store review notes are current.
- No docs claim a hidden, flagged, or unproven feature is shipped.
