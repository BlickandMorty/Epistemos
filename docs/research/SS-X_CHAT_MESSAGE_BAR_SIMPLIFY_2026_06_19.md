# SS-X — Chat message-bar still messy (simplify/demuddify) (2026-06-19)

Read-only research (subagent), code-grounded. Feeds the CHAT-MESSAGE-BAR ledger item. Owner: *"the controls on
the chat are very messy still — on the bottom message bar I still see think, pro, tools etc., old options I
thought I simplified. Fix/simplify/demuddify + more robust teardowns/memory transitions."* Balance: simplify
presentation, NEVER delete/hide functionality. Cross-refs MINICHAT-3-TOGGLES, SS-B, SS-U (teardown).

## Headline — why the simplification missed the bar
The P1.1–1.3 simplification reached the **model-picker popover** (`simplifiedRuntimePopover` +
`cloudToggleSection`, `RootView.swift:1583/1655`), gated on `EpistemosFoundationLineup.simplifiedLineupActive`.
But the **main-chat bottom bar still renders the legacy SPLIT toolbar** — a row of Mode/Routing/Effort/Native
buttons literally labeled **"Think"/"Code"/"Tools"/"Pro"/"Standard"/"Extended"**. That split row is gated on
`preferSplitToolbarControls` **only** — NOT behind `simplifiedLineupActive`, so the flag the owner thinks
"simplified everything" never touches it. Worse, the main composer ALSO renders the new flat
`inlineRuntimePickerTrigger` next to it → **TWO model pickers on the same bar.** MiniChat + Landing were migrated
to the single flat trigger; main chat was half-migrated and left the old controls in.

## Message-bar controls mapped
- **Main chat `ChatInputBar.swift`** control row `:958`: flat `inlineRuntimePickerTrigger` (`:1379`, label
  `currentTierShortLabel:1396` = Fast/Think/Code/Act), `slashButton:1361`, **`ChatBrainPickerMenu(prefer
  SplitToolbarControls:true, hidesModelButton:true) :967`** → renders the messy legacy row, `attachButton:1347`,
  `ComposerMicButton:984`/`VoiceInputButton:1079`, context badge `:1004`, `CoworkPanel:1024`, `ChatCapabilityPill
  :1049`, `ContextualShadowsButton:1117`, **`toolPanelButton:1119/1485`** (slider→`AgentToolTogglePanel`),
  `cloudRouteButton:1123/1521`, `deepResearchButton:1128` (non-MAS), `queueButton:1133`, `sendButton:1137/1443`.
- **Split toolbar `LocalModelToolbarMenu.splitToolbarControls` (`RootView.swift:1079`)** — the legacy buttons:
  Mode `=operatingMode.displayName` → "Think"/"Code"/"Tools" (`:1083`); Model (`:1100`, hidden here); Routing
  "Local/Cloud/Auto" (`:1119`); Effort "Standard/Extended/Max" (`:1135`,`effortButtonTitle:882`); Native
  "OpenAI/Claude/Google" (`:1154`); Temporary-chat + settings (`:1173/1177`).
- **MiniChat `MiniChatView.swift:1026`**: flat trigger `:1033` + slash + attach + toolPanel `:1036` + pill +
  shadows + send. **No split toolbar / no Think/Code/Tools buttons** — already simplified.
- **Landing `LandingView.swift`**: flat `landingSearchToolsToggle` ("Tools"/"Less" disclosure `:1043`) +
  `ChatBrainPickerMenu` with `preferSplitToolbarControls=false` → single compact popover.

## Where think/pro/tools still show + flag gating
| Control | Where | Label source | Behind simplifiedLineupActive? |
|---|---|---|---|
| **"Think"/"Code"/"Tools"** mode | main bar split toolbar `RootView.swift:1083` | `EpistemosOperatingMode.displayName` `InferenceState.swift:2829` (thinking→Think, pro→Code, agent→Tools) | **NO** — `usesSplitToolbarControls:660` gates only on `preferSplitToolbarControls && operatingMode != nil` |
| **"Pro"/"Standard"/"Extended"** effort | split Effort `:1135` | `effortButtonTitle:882` | **NO** |
| **"Tools"** (agent-tool slider) | `toolPanelButton ChatInputBar.swift:1485` | hard-coded "Agent tools" | **NO** (main + MiniChat) |
| Native "OpenAI/Claude" | split `:1154` | provider name | **NO** |
The flag covers the popover INTERIOR (`runtimePopover`→`simplifiedRuntimePopover` `:1490`) + single-button
label-hiding (`hidesLocalModelLabel:854`), but **the split-toolbar branch never consults the flag** — the exact
gap the owner hits.

## Duplication / inconsistency
1. **Two model pickers on the main bar**: flat `inlineRuntimePickerTrigger` (`:960`) AND `ChatBrainPickerMenu
   (preferSplitToolbarControls:true)` (`:967`). `hidesModelButton:true` suppresses only the split *Model* button
   — the Mode("Think")/Routing/Effort/Native buttons still render beside the new trigger. Flat trigger + split
   "Mode" both encode Fast/Think/Code → redundant.
2. **Surface inconsistency**: MiniChat (`:1033`) + Landing (`preferSplitToolbarControls=false`) show ONE flat
   picker; main chat shows flat + the 4-button split row. The 3 primary surfaces disagree.
3. **"Tools" overloaded 3 ways**: `.agent` mode label (`InferenceState.swift:2834`), the agent-tool toggle
   button (`toolPanelButton`), Landing's secondary-tools disclosure (`LandingView.swift:1045`). Cross-ref
   MINICHAT-3-TOGGLES.

## Simplify design (progressive-disclosure, never delete)
- **Main chat: stop passing `preferSplitToolbarControls:true`** at `ChatInputBar.swift:967` (the
  `ChatBrainPickerMenu` is redundant with the flat trigger since `hidesModelButton` is already true). Removing it
  / setting false drops the "Think/Code/Tools/Effort/Native" row. Clean bar = **flat brain-picker + attach + mic
  + capability pill + (cloud-route when configured) + send** — matching MiniChat.
- **Move Mode/Effort/Routing/Native into the picker's existing Advanced disclosure** — `simplifiedRuntimePopover`
  already has `DisclosureGroup(isExpanded:$showsAdvancedRuntimeOptions)` with routing/Models/cloud/Temporary Chat
  (`RootView.swift:1605`); Effort/Native are the natural next rows — never deleted, one disclosure away. Chat/Act
  depth already lives in `depthToggleSection` (`:1594/1694`), honestly gated on an agent route existing.
- **Single fix for the flag gap**: make `usesSplitToolbarControls` (`RootView.swift:660`) also return false when
  `EpistemosFoundationLineup.simplifiedLineupActive` — one predicate routes EVERY `preferSplitToolbarControls`
  caller back through the single simplified popover (consistent with `:1490`).
- **MAS-safe/honest gates kept**: `deepResearchButton` `#if !EPISTEMOS_APP_STORE` (`:1127`); working-folder strip
  Pro-only (`:219`); `cloudRouteButton` hides when unconfigured (`showsCloudRouteButton:325`). Simplification is
  pure presentation (move into disclosure) — no capability hidden from a build that has it.

## Teardown / memory transitions
- **`ChatInputBar` (main chat) leaks its recall debounce task** — schedules `recallDebounceBox.task=Task{…}`
  (`:1795`) but has **NO `.onDisappear`** to cancel it. MiniChat does exactly this (`MiniChatView.swift:1080-1083`:
  `recallDebounceBox.task?.cancel()` + `cancelStream()`). Main composer should mirror it — a session-switch/
  teardown can leave an in-flight recall task. (cross-ref CLAUDE.md memory-hardening, SS-U.)
- **No WKWebView on chat composer/bubbles** — grep finds WKWebView only in Epdoc/KaTeX (already `dismantleNSView`+
  shared pool). MessageBubble/ArtifactBlockView host none → the SS-U dark/light WKWebView teardown concern does
  NOT extend to chat bubbles (verified by absence). The chat-side risk = debounce-task + stream cancellation on
  session switch, not a webview.
- **Session-switch**: MiniChat sanitizes mode + cancels stream on disappear/selection change (`:1077-1088`);
  main-chat `ChatInputBar` only has `applyPendingComposerDraftIfNeeded` on appear (`:1194`) with no symmetric
  teardown. *Unverified* whether `ChatView` cancels the active stream on `activeChatId` change (no
  `onDisappear`/`onChange(activeChatId)` found — flag for ChatView lifecycle read).

## Ordered plan
1. **[S]** `ChatInputBar.swift:967` — drop `preferSplitToolbarControls:true` (or false). Removes the
   Think/Code/Tools/Effort/Native row; the flat trigger already covers picking. Matches MiniChat. **The direct
   fix for the owner's complaint.**
2. **[S]** `ChatInputBar.swift` — add `.onDisappear { recallDebounceBox.task?.cancel() }` mirroring
   `MiniChatView.swift:1080`. Closes the debounce-task teardown gap.
3. **[M]** `RootView.swift:660` — gate `usesSplitToolbarControls` on `!simplifiedLineupActive` so EVERY
   `preferSplitToolbarControls` caller collapses to the single simplified popover; one predicate, all surfaces
   consistent.
4. **[M]** Fold Effort + Native-Controls into `simplifiedRuntimePopover`'s Advanced `DisclosureGroup`
   (`RootView.swift:1605`) — moved, never deleted.
5. **[L]** Disambiguate the three "Tools" surfaces (per MINICHAT-3-TOGGLES; cross-ref SS-B). *Unverified scope.*
6. **[L]** Verify `ChatView` cancels stream + recall on `activeChatId` change (no hook found) — SS-U alignment.

Key files: `Views/Chat/ChatInputBar.swift` (`:958,967,1379,1485,1795`) · `App/RootView.swift` (`LocalModelToolbar
Menu:522`, `usesSplitToolbarControls:660`, `splitToolbarControls:1079`, `runtimePopover:1488`, `simplified
RuntimePopover:1583`, `cloudToggleSection:1655`, `depthToggleSection:1694`) · `Views/Chat/ChatBrainPickerMenu
.swift` (`preferSplitToolbarControls/hidesModelButton:42/47`) · `State/InferenceState.swift:2829`
(`EpistemosOperatingMode.displayName`) · `Views/MiniChat/MiniChatView.swift` (simplified `:1026`, teardown
`:1080`) · `Views/Landing/LandingView.swift:1043` · `Engine/EpistemosFoundationLineup.swift`
(`simplifiedLineupActive`).
