# ACT SURFACE COVERAGE MATRIX (2026-06-23) — EXHAUSTIVE "every Osaurus surface landed in the act chat"

> **OWNER DIRECTIVE (2026-06-23, verbatim intent):** "Verify every single thing from the source act … I still want it to be my Epistemos UI, but make sure ALL of Osaurus's features are behind our back into MY UI. Every single surface that exists must be landed in the act chat, exhaustively — because past Osaurus stuff was not working, the agent was just never the same, and the prefill / all the things that should surface should be expressed. Still lots of issues."
>
> **MANDATE:** Each Osaurus (vendored OsaurusCore) UI surface must be expressed in the NATIVE Epistemos act UI (ChatView `actUsesOsaurus`, ActCloneSettingsView, native prompt presenters) — NOT by mounting the vendored Osaurus view. This matrix is the per-surface punch-list; every PARTIAL/MISSING row is a tracked gap to close.

## Architecture (how surfaces reach the act chat today)
- Act chat = `ChatView(actUsesOsaurus: true)` (RootView.swift:1512 `ActEpistemosChatSurface` → ChatView.swift:184).
- Act settings = `ActCloneSettingsView.swift` — inline native Sections for a subset, PLUS a "Complete Osaurus settings map" (ActCloneSettingsView.swift:715-728) listing all 22 `ManagementTab` cases as buttons. Each opens a **native** `ActNativeOsaurusSurfaceSheet` (:1135) — but only **8 surface IDs** render real native state/actions (providers/tools/permissions/sandbox/computerUse/privacy/plugins/models, statusRows :1232-1346). **All other tabs hit the `default` branch (:1347) → a generic "N Osaurus surfaces indexed" row = LISTED, NOT natively expressed.**
- Stream: `ActOsaurusVisibleStreamFilter` (SharedActInference.swift:118-308) STRIPS protocol sentinels (`prefill:`,`stats:`,`billing:`,`done:`,`reasoning:`,`secret:`,`tool:`); structured events re-surface via `actEventStreamIfArmed` → `ActOsaurusStreamEvent` (`.textDelta/.thinkingDelta/.toolStarted/.toolCompleted`).

## Coverage matrix (COVERED / PARTIAL / MISSING)

### A. Chat-thread rendering
| Surface | Native expr | Status |
|---|---|---|
| Thinking blocks | ChatView.swift:1676-1746, MessageBubble.swift:177-183,341 | COVERED |
| Tool-call groups | MessageBubble.swift:822-877; AgentRunTimelineView | COVERED |
| Artifact cards | ArtifactBlockView.swift; MessageBubble.swift:354-358 | COVERED |
| **Charts** | none (no native chart renderer in Views/Chat) | **MISSING** |
| Markdown / **LaTeX** | TaggedMarkdownTextView MessageBubble.swift:207 (md); KaTeX editor-only | PARTIAL (no in-chat math) |
| **Terminal display** | none in chat (tool output = plain text) | **MISSING** |
| **Minimap** | none (only code-editor minimap) | **MISSING** |
| Clarify overlay | ChatView.swift:416-421,1183 (presenter :726) | COVERED |
| Secret overlay | ChatView.swift:407-415,1033 (presenter :718) | COVERED |
| Prompt queue | ChatInputBar.swift:144,938-950 | COVERED |
| Attachments | ChatView.swift:379-380,1796; ChatInputBar | COVERED |
| Redaction | ChatView.swift:399,1419 (presenter :697) | COVERED |

### B. Prefill / stats / streaming telemetry  ← OWNER NAMED ("prefill")
| Surface | Native expr | Status |
|---|---|---|
| reasoning → thinking event | SharedActInference.swift:76-77 | COVERED |
| tool → tool event | re-emitted toolStarted/toolCompleted | COVERED |
| **prefill / stats** (TTFT/tokens/tok-s) | `.generationStats` event → `ActTurnStatsStore` → `ActGenerationStatsChip` (ChatView transcript); driver emits from final ChatTurn | **COVERED (iter40, a90b07c3e)** — native "TTFT 6.93s · 9 tokens · 555 tok/s" chip render-verified |
| billing / credits | not yet surfaced (Pro/credits sentinel) | PARTIAL — TTFT/tokens done; billing/credits chip TBD if/when credits route active |

### C. Models
Native model **selection** (ActCloneSettingsView.swift:661-707 + :785; act picker) + **model DETAIL** (iter41, 8fe0288df): on-device badge + context window rendered in BOTH the act settings model stack AND the in-chat `InlineRuntimePickerPanel.osaurusPickRow` (fed by `EpistemosOsaurusModelPick.isDownloaded/contextLength` from the cheap `downloadStates` map). **PARTIAL (improved)** — still missing: download **progress**, external-model **add**, cache inspector.

### D. Providers
Inline "Providers and MCP" (:269); connect/disconnect remote+MCP + router toggle (:911-945); credential prompt native (RootView.swift:701, installed :161). **PARTIAL** — no native add/edit individual remote provider (RemoteProviderEditSheet), per-provider diagnostics rows, or reorder.

### E. Tools
"Tool approval policy" inline (:413, `ActToolPermissionNativeRow` :1490); in-chat `AgentToolTogglePanel`; permission prompt native (RootView.swift:540, installed :158); **tool secrets** native inventory (iter42, 62dfdc108): `toolSecretRows()` → "Tool secrets" Section (plugin credential + Set/Missing badge) from PluginManager SecretSpecs + ToolSecretsKeychain. **COVERED (read-only)** — follow-on: inline set/clear.

### F. Slash commands
Composer popover `SlashCommandPopover.swift` (ChatInputBar.swift:127-468). **PARTIAL** — no native slash-command management/catalog editor (`commands` tab = generic index row).

### G. Skills
Native skill **catalog** (iter43, 07b964d01): `skillRows()` seam (SkillManager.shared.skills → name/desc/source/category/enabled) → "Skills (N/M on)" Section in ActCloneSettingsView; slash invocation render-verified ("Commands + Skills" popover, /tmp/epi_iter43_slash). **COVERED (read-only catalog)** — follow-on: per-skill enable toggle + skill editor.

### H. Plugins
Native sheet = installed/ready counts + dependency-recipe count (:1325-1338) + repair (:984). **PARTIAL/MISSING** — no native install, marketplace browse/detail, GitHub import, plugin config, or sandbox-plugin editor.

### I. Sandbox / VM
"Sandbox and VM controls" inline (:344); provision/start/stop/diagnostics (:809-839), folder pick/clear (:795-809), native sheet (:1278), `ActSandboxDiagnosticNativeRow` (:1427), repair (:984). **COVERED**.

### J. Computer use
"Computer Use prompts" inline (:473); global preset + allowlist (:896-902); in-chat approval overlay ChatView.swift:391,751. **PARTIAL** — **ComputerUseFeedView (live action feed) = no native equivalent**.

### K. Voice
Composer mic only (`ComposerMicButton`/`VoiceInputButton` ChatInputBar.swift:1106,1200). **PARTIAL/MISSING** — no native VAD/TTS/transcription-mode settings, hotkey recorder, or voice-input overlay.

### L. Agents
Pairing prompt native (RootView.swift:869, installed :164) + agent default toggles (:848-854) + **agents INVENTORY** (iter44, a1cbbebdb): `agentRows()` seam (AgentManager.shared.agents → name/effectiveModel/tools/memory/autonomous/default/active) → "Agents (N)" Section in ActCloneSettingsView. **PARTIAL(improved)** — agents list + pairing + toggles COVERED; still missing: agent select/edit (capability manager), schedules, watchers.

### M. Server settings  ← LARGEST GAP
ServerView + ServerSettings/* (~16: Generation Defaults, Concurrency, Cache, Connection, Auth, AdvancedHTTP, GlobalProxy, MTP, Multimodal, Power, MemorySafety, ModelResidency, DecodePerformance, LiveActivity, ToolsTemplates, BatchDiagnostics). **MISSING** — `server` tab = generic index row; zero native sections.

### N. Identity / Credits / Memory / Insights / Themes / Pairing / Onboarding / WhatsNew / Storage
| Sub | Status |
|---|---|
| Identity | MISSING (index-only) |
| Credits | MISSING (index-only) |
| Memory | PARTIAL (enable toggle only :854) |
| Insights | MISSING (Epistemos has own HealthRows, not Osaurus insights) |
| Themes | MISSING (index-only) — note act inherits Epistemos theme already |
| Pairing | COVERED (RootView.swift:869) |
| Privacy filter | COVERED (:556 + sheet :1306 + review overlay) |
| Storage | MISSING (index-only) |
| Onboarding / WhatsNew | MISSING (likely out of act scope — confirm w/ owner) |

## TOP MISSING/PARTIAL PUNCH-LIST (close in priority order)
1. **Prefill/stats/billing telemetry** (B) — OWNER NAMED. Surface TTFT / tokens-sec / prefill latency / credits as a native stats chip in the act transcript (parse the stripped `stats:`/`prefill:`/`billing:` sentinels instead of discarding). **← START HERE.**
2. **Server settings** (M) — ~16 ServerSettings sections, zero native. Largest surface gap.
3. **Plugins beyond counts** (H) — install / marketplace / GitHub import / config / sandbox-plugin editor.
4. **Agents / Schedules / Watchers** (L) — list, capability manager, schedules, watchers.
5. **Voice settings** (K) — VAD/TTS/transcription/hotkey/overlay.
6. **Model detail / download / cache inspector / external-model add** (C).
7. **Skills view/editor** (G) + **slash-command catalog editor** (F).
8. **Tool secrets** (E).
9. **NativeChartView, terminal-in-chat, in-chat LaTeX, minimap** (A).
10. **Identity / Credits / Themes / Insights / Storage** (N).
11. **ComputerUseFeedView** live action feed (J).

## "Generic index row" architecture gap (cross-cutting)
The 14 non-native `ManagementTab` cases (server, voice, skills, agents, schedules, watchers, identity, credits, memory-console, insights, themes, storage, slash-commands-mgmt, onboarding) currently render a single generic "N surfaces indexed" row in the act sheet. Each is a tracked item above; landing them replaces the index row with a real native surface.
