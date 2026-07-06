# ProShell Native Fetch Decoder Boundary Report

Cycle frontier: harden the ProAgent All Chats sheet by separating untrusted local-runtime JSON fetch/decode from SwiftUI presentation.

## Shipped

- Added `ProAgentChatList.swift` as a Foundation-only model/fetch/decode boundary.
- Moved merged opencode/goose chat-list fetch logic out of `ProAgentAllChatsSheet`.
- Added bounded cleaning for chat IDs, titles, and directories before display.
- Added pure decoder tests for opencode envelopes, goose malformed payload handling, text bounding, and the view/source boundary.

## Review

- Thermonuclear result: zero confirmed HIGH/MED issues. The change deletes parsing/network branches from the view and gives the decode path direct tests.
- `ProAgentAllChatsSheet.swift` dropped from 249 to 140 lines.

## Verification

- Passed: `swiftc -typecheck Epistemos/ProAgent/ProAgentChatList.swift`
- Passed: `git diff --check` over the scoped cycle files.
- Passed: production guardrail scan for forced execution, debug output, crash calls, and unfinished markers.
- Xcode focused tests were not started because another lane had an active `Epistemos-AppStore` `xcodebuild`; the no-concurrent-Xcode guardrail takes precedence.
