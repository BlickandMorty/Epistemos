# Build Prompt — Experimental Surface, Phase 2: MAKE IT LOOK AND BOOT LIKE EPISTEMOS

> OWNER OVERRIDE — 2026-07-07, `MAS-ONLY-SHIP-LOCK-2026-07-07`: this prompt is
> parked. Do not start, resume, or reprompt Experimental/1Code work while
> MAS-only is active. Preserve this file as historical provenance and salvage
> useful ideas only through MAS-June/App Store-safe architecture.

> OWNER OVERRIDE — 2026-07-07: This older Phase 2 prompt is superseded for
> current 1Code V2 UI work by `docs/plans/1code-v2/**`. Preserve behavior,
> engine, transport, and information layout, but do **not** preserve donor
> 1Code/Goose visible components. Replace shell, workspace rail, sidebar rows,
> composer, status strip, command palette, buttons, cards, popovers,
> transcript viewport, and tool/action surfaces with Epistemos-owned
> components or owned CSS surfaces. Wrapper-only, skin-only,
> token/package-only, or slight-tint work does not satisfy the owner intent.

**Read this whole file before touching anything. It is short on purpose — execute all of it.**

You are continuing an in-progress build (the Experimental agent surface = embedded 1Code). The
**backend, embedding, and plumbing are already DONE and committed** — headless backend, WKWebView host
(`Epistemos/ExperimentalAgent/ExperimentalSurfaceView.swift`), supervisor, Keychain, MCP auto-inject,
the `onecode-shim.js` bridge, the native NSOpenPanel/NSSavePanel dialogs, perf, the `Experimental`
scheme. Claude chat renders in the WebView. **That layer is finished.**

## ⛔ STOP DOING THE THING THAT'S BEEN EATING CYCLES
The reason this build keeps reporting "nothing left" is that it keeps **re-auditing the shim / the
Coordinator handlers / the plumbing** and calling that "completeness." That work is DONE. From now on:
- **Do NOT** re-audit `onecode-shim.js`, the desktopApi channel table, the Coordinator/HostBridge
  handler coverage, or any already-wired IPC channel. It is committed and working.
- **Do NOT** close feature-ledger rows that are already closed, or re-verify green builds as "progress."
- **"Build green" is necessary but NOT done.** Done is defined ONLY by the three VISIBLE outcomes below.

## THE ONLY DEFINITION OF DONE THAT COUNTS (all three, screenshot-proven)
You may **not** report complete until you have **pasted three screenshots of the running
Experimental-scheme app** proving each. If you think you're finished, re-check these three and
screenshot them — if any is unmet, you are not finished; keep going.

- **DoD-1 — Boots straight into the agent.** Launch the app → it lands directly in a ready-to-type
  agent chat scoped to the **Epistemos vault**. **No folder/project picker, no onboarding wall, no
  "choose a repo" step.** Screenshot: the app on launch, cursor in a live composer, zero picker.
- **DoD-2 — Wears the Epistemos theme.** The embedded UI visibly matches the rest of Epistemos —
  Epistemos color tokens, **no donor gradient**, the header/landmark font, correct in **both light
  and dark**. It must not look like stock 1Code. Screenshot: the themed surface in light AND dark,
  next to another Epistemos room for comparison.
- **DoD-3 — Has native SwiftUI chrome (not donor web chrome).** At minimum the **model/provider
  picker**, the **left sidebar (chat list + new chat)**, and the **settings entry** are native
  AppKit/SwiftUI driven off the backend — not the donor's web widgets. Screenshot: a native picker
  open, a native sidebar, over the web transcript.
- **DoD-4 — ZERO donor branding; it is Epistemos.** No "1Code", "21st", "21st.dev", or
  "twentyfirst" text anywhere the user can see — window title, app menu, in-app strings, empty states,
  the served renderer. **Verification gate:** `grep -rEi '21st|1code|twentyfirst'
  .research-clones/1code/headless/dist` returns **0** user-facing hits (LICENSE/NOTICE attribution
  files are the ONLY allowed exception — Apache-2.0 requires keeping those; they are not user-facing
  UI). Screenshot: the app with an Epistemos title/identity, no donor name on screen.
- **DoD-5 — All engines the plan named are actually SELECTABLE and wired, not just the donor's two.**
  The model/provider picker offers **Claude Code, Codex, Kimi, GLM, Gemini, OpenCode (free Zen only)**,
  each driven per `BUILD_PROMPT_EXPERIMENTAL_FINAL.md` §5 (Kimi/GLM via the `ANTHROPIC_BASE_URL`
  harness; Gemini API-key adapter; OpenCode Zen-free whitelist), backed by the live catalog (§5), and a
  Keychain key-paste path for each. Screenshot: the picker listing all six; a real round-trip on at
  least one non-Claude provider that has a key.
- **DoD-6 — Deeply integrated into Epistemos, not a bolted-on clone.** (a) The **Epistemos vault MCP is
  actually present to the engine** — the agent can search/read the user's notes; verify the engine sees
  `epistemos-vault` (MCP list or a vault-tool call in a transcript), not just that an env var is set.
  (b) On launch the surface **auto-loads the app's chosen vault folder** (`AppBootstrap.shared.vaultSync.vaultURL`)
  as the active project and opens a ready chat — see DoD-1. Screenshot: a chat where the agent uses a
  vault tool, and the launch landing on the vault with no picker.

The full detail for each lives in `BUILD_PROMPT_EXPERIMENTAL_FINAL.md` §4 (de-brand/decouple), §5
(providers + catalog), §6 (MCP), §7 (native feel) + `EXPERIMENTAL_R.md` §1.10, §1.11. **Read those now.**
This file is the forcing wrapper, not a replacement.

## ⚠️ SPECIFIC INTEGRATION THE PLAN REQUIRED THAT IS CURRENTLY MISSING (proof — you did NOT finish it)
A source check found the backend env is wired but the user-facing integration is absent. Do not argue
these are done — they are not:
- **Branding still shipped:** `.research-clones/1code/headless/dist/index.cjs` has **27** `21st`/`1code`
  hits and `dist/onecode-shim.js` has 7. The user sees donor branding. (DoD-4)
- **Providers only stock:** the supervisor has a key→env map (`ExperimentalRuntimeSupervisor.swift:349-352`)
  but the **UI picker exposes only the donor's Claude+Codex**; Kimi/GLM/Gemini/OpenCode are not
  selectable, catalog is still the donor's hardcoded `lib/models.ts`. (DoD-5)
- **MCP is a plausible no-op:** `ExperimentalRuntimeSupervisor.swift:182-194` sets `EPISTEMOS_VAULT_MCP_*`
  only when a vault exists and never verifies the engine actually loaded `epistemos-vault`. (DoD-6a)
- **No auto-vault-boot:** `EPISTEMOS_VAULT_ROOT` is handed to the backend (`:198-199`) but nothing drives
  the renderer to select that project and open a chat — the donor picker still blocks first paint. (DoD-6b)

---

## TASK 0 (KEYSTONE — build this first; Tasks 1 and 3 both need it)
**The native→SPA state bridge.** Per `EXPERIMENTAL_R.md` §1.11, the donor's send-transport reads
model/mode/project **live from the renderer's shared Jotai `appStore` (`lib/jotai-store.ts`) at send
time** — so native controls that only write native state silently desync the chat. Build ONE primitive:
a native Swift call that **sets a named Jotai atom (or runs a Zustand action) in the renderer's shared
`appStore`, keyed by the active `subChatId`**, via `evaluateJavaScript`/`page.callJavaScript` on the
existing script-message bridge (reuse the escaping discipline already in the surface). Expose it as a
small Swift API, e.g. `experimentalBridge.setAtom(name:, value:, subChatId:)` and
`.dispatch(event:, detail:)`. Everything visible below rides this. Commit it alone first.

## TASK 1 — Boot straight into the agent (DoD-1)
The vault root is already exposed to the backend (`EPISTEMOS_VAULT_ROOT`, supervisor). What's missing is
**auto-advancing past the donor's project picker** on launch. On `supervisor.status == .running`, use
Task 0's bridge to: (a) select/create the Epistemos-vault project in the SPA (set the project-selection
atom to the vault path — see §1.11 sidebar/new-chat notes), and (b) open a new chat / focus the composer
— so the user lands in a ready chat, never the picker. If no vault is configured, fall back to the
last-used project; only show a chooser if there is genuinely nothing. **Never block the first paint on a
folder dialog.** Verify: cold launch → composer focused, no picker → screenshot = DoD-1.

## TASK 2 — Wear the Epistemos theme (DoD-2) — biggest visible win, lowest risk
Use the neutral AgentSurface/Experimental theme-injection pattern; do **not** depend on
`Epistemos/ProAgent/ProAgentThemeBridge.swift`, because ProAgent/OpenChamber are deletion targets.
Inject Epistemos theme tokens as **inline `!important` CSS custom
properties on `:root`/`documentElement` via a `WKUserScript` at `.atDocumentStart`**, plus a
`MutationObserver` that re-asserts them, plus a live light/dark switch (`page.callJavaScript`). Source the
token values from `Epistemos/Theme/EpistemosTheme.swift`. Add this as a SECOND user script in
`ExperimentalSurfaceView.swift` (the shim script is added ~line 89 — add the theme script alongside).
Requirements: kill the donor gradient (`background-image: none !important` on the offending classes);
apply the chunky header font to **landmarks/headers ONLY** — never dense chat/editor body, Monaco and
xterm must stay legible; set the WKWebView `underPageBackgroundColor` to the Epistemos surface color for a
pre-paint blend. Because 1Code is Tailwind + Radix + next-themes (token-driven), overriding `:root`
re-skins most of it in one shot; only stray hardcoded hex needs explicit overrides. Verify in **both**
appearances → screenshot = DoD-2.

## TASK 3 — Native SwiftUI chrome (DoD-3)
Lift chrome to native per the `EXPERIMENTAL_R.md` §1.11 classification. **Order by
highest-visibility-first**, and obey the split:
- **NATIVE-SAFE (pure tRPC/DB — build these natively, drive off the backend directly):** the left
  **sidebar** (chat list + archive/rename via `chats.*`, + a native "New Chat"), the **settings** entry
  and tabs (MCP/Skills/Custom-Agents/Plugins/Projects/Account), window chrome. These need no atom bridge.
- **INTENT-BRIDGE (native control MUST write the renderer atom via Task 0's bridge):** the
  **model/provider/mode picker** — native picker writes `subChatModelIdAtomFamily(subChatId)` +
  `lastSelectedModelIdAtom`; mode **dual-writes** the atom + Zustand `updateSubChatMode`; sidebar
  *selection* pushes the 5-atom tuple (`selectedAgentChatIdAtom`, `selectedChatIsRemoteAtom`,
  `chatSourceModeAtom`, `showNewChatFormAtom=false`, `desktopViewAtom=null`) + `claimChat`. Get this
  wrong and the live chat desyncs — that's why Task 0 exists.
- **⛔ NEVER nativize (the §0 rule — absolute):** the transcript/streaming, the terminal/xterm, tool
  renderers, the prompt editor. They stay web. **If moving something to native will break it, do not
  move it.** Push intents into the SPA via Task 0's bridge / injected `CustomEvent`s — **never reload
  the URL** (a reload reboots the SPA and kills the live session).

Ship the model picker + the sidebar + the settings entry natively for DoD-3; the rest of the §1.11
NATIVE-SAFE list is follow-on, not blocking.

## TASK 4 — De-brand: make it Epistemos, not 1Code (DoD-4)
Strip every user-facing donor identity and replace with Epistemos. Targets: the served renderer
strings ("1Code", "21st", "21st.dev", "twentyfirst"), the window title / app menu / about, empty-state
copy, the shim, and any remaining `cdn.21st.dev` / `twentyfirst-agents://` references. **Do it at
bundle time in `build-experimental-web.sh`** (a string-replace pass over the built dist) so it survives
re-vendoring the donor, AND add a gate that **refuses the dist if `grep -rEi '21st|1code|twentyfirst'
dist` returns any user-facing hit** (mirror the existing service-worker refusal). Keep the Apache
`LICENSE`/`NOTICE` attribution files (required) — those are not UI. This is what "truly a part of my
app" means: no donor name reaches the screen.

## TASK 5 — Wire ALL six engines + make the vault MCP real (DoD-5, DoD-6a)
The supervisor already maps provider keys to env (`ExperimentalRuntimeSupervisor.swift:349-352`) — now
make them **usable and visible**:
- **Surface all six in the (native, Task 3) picker:** Claude Code, Codex, Kimi, GLM, Gemini, OpenCode
  (free Zen only). Drive per `BUILD_PROMPT_EXPERIMENTAL_FINAL.md` §5 — Kimi/GLM ride the already-wired
  `ANTHROPIC_BASE_URL` harness (verified base URLs: `api.moonshot.ai/anthropic`, `api.z.ai/api/anthropic`);
  Gemini = API-key adapter; OpenCode = Zen-free whitelist. Each gets a Keychain key-paste path (the
  write path exists — surface the UI).
- **Replace the donor's hardcoded catalog** (`lib/models.ts`) with the **live catalog** (§5:
  `models.dev/api.json` backbone + per-provider `/models` + pinned fallback) so current models appear.
- **Make the vault MCP actually present to the engine** (not just an env var): inject `epistemos-vault`
  router-level per §6 (Claude `options.mcpServers` `claude.ts:1266-1376`; Codex `session.mcpServers`
  `codex.ts:1259-1262`) in the forked backend, defaulting to the app's vault — verify the engine lists
  it / can call a vault tool. The file-fallback (`~/.claude.json`) stays as the compat path.

---

## EXECUTION RULES (do not violate)
1. Work Task 0 → 1 → 2 → 3, in order. **Commit after each task** (build green, arm64,
   `CODE_SIGNING_ALLOWED=NO`). Never two `xcodebuild`s at once (16 GB machine).
2. **Verify in the RUNNING app, not just a green build.** Launch the `Epistemos-Experimental` scheme,
   screenshot the actual surface. A compile is not evidence of a visible change.
3. **Do not stop, do not report done, do not idle on "nothing left" while ANY of DoD-1/2/3 is unmet.**
   If a scheduled/loop wrapper is driving you with an older prompt, this file supersedes it — the goal
   is the three screenshots, nothing else.
4. If you catch yourself editing `onecode-shim.js` or auditing handler coverage → **stop, that's the
   trap**; return to the current Task.
5. Rails unchanged: the vendored fork stays in `.research-clones/` (gitignored, never committed); edits
   to it get a `PATCH_LEDGER.md` row; overlay in NEW files where possible; never `git add -A`; provider
   keys stay in Keychain, never in webview JS; report honestly.

**Definition of success, restated:** the owner launches the Experimental scheme and sees *their* app —
it opens straight into a themed agent chat with native chrome — not stock 1Code. Three screenshots or
it isn't done.
