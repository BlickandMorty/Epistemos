# Sovereign Gate Surface Backlog Map — 2026-05-03

> **Purpose.** Read-only inventory of every destructive / sensitive UI surface in `Epistemos/`, classified by current Sovereign Gate routing status, payload risk, and smallest safe future PR slice. Codex can pick from §3 directly without redoing the survey.
>
> Doctrine §7 lane: Core killer-feature seed work — Sovereign Gate broader Core classes follow-through. Generated per `CODEX_PARALLEL_WORK_RATIONALE_PROMPT_2026_05_03.md` P7.

---

## 1. Inspection method

```
grep -rln 'role: .destructive' Epistemos/ --include='*.swift'        # find sites
grep -rn  'AppBootstrap.shared?.sovereignGate' Epistemos/             # tally gated sites
grep -L   'AppBootstrap.shared?.sovereignGate' <files-from-grep1>     # ungated subset
```

No code edits. No production patches. SovereignGate.swift, existing SovereignGateTests.swift, and Codex's round-75 reservation set are untouched.

---

## 2. Already-shipped Sovereign Gate work (do NOT duplicate)

Per `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` "Safe Next Build Order" item 4, the following PRs are **closed** and re-routing those surfaces is a no-op:

| PR | Surface | Helper |
|---|---|---|
| Sovereign Gate Core PR1 | Single Swift executor | `SovereignGate.confirm` |
| Lifecycle PR2 | App / session / sleep grace clearing | `SovereignGateLifecycleObserver` |
| Approval Surface PR3 | Existing agent approval sheet | `ChatApprovalSovereignGate` |
| Rust Matrix PR4 | Additive Rust action-class seed | `agent_core/src/sovereign/mod.rs` |
| Notes Delete PR5 | Notes Sidebar permanent page/folder delete | `NotesSidebarDeletionSovereignGate` |
| Chat Delete PR6 | Chat Sidebar context-menu chat delete | `ChatSidebarDeletionSovereignGate` |
| Version Delete PR7 | DiffSheet version delete menu | `DiffSheetVersionDeletionSovereignGate` |
| RootView Destructive PR8 | Database reset + Vault disconnect | `RootViewDestructiveActionSovereignGate` |
| Model Vault Delete PR9 | Model Vaults Sidebar file/folder delete | `ModelVaultDeletionSovereignGate` |
| Custom Tool Delete PR10 | Agent Control custom-tool delete | `AgentControlSettingsDeletionSovereignGate` |
| Notes Vault Disconnect PR11 | Notes Sidebar vault menu disconnect | `NotesSidebarDeletionSovereignGate.vaultDisconnect` |
| Authority Reset PR12 | Batch authority reset / preset apply | `AuthoritySettingsSovereignGate` |
| Overseer History Reset PR13 | Reset overseer history | `OverseerSettingsSovereignGate` |
| Settings Reset Everything PR14 | Reset-all-data alert | `SettingsViewDestructiveActionSovereignGate.resetEverything` |
| Settings Workspace Delete PR15 | Saved-workspace trash action | `SettingsViewDestructiveActionSovereignGate.savedWorkspace` |
| Settings Vault Disconnect PR16 | Settings vault disconnect button | `SettingsViewDestructiveActionSovereignGate.vaultDisconnect` |

All 10 files containing destructive `role: .destructive` buttons that **do** reference `AppBootstrap.shared?.sovereignGate` are accounted for. The next §3 covers everything that remains.

---

## 3. Open Sovereign Gate surfaces (ungated destructive sites)

`grep -rln 'role: .destructive' | xargs grep -L 'AppBootstrap.shared?.sovereignGate'` returns 4 files. Each is a candidate for a future PR; each row below names the smallest safe slice.

### S-1 — Adapter delete in TrainingHistoryView (HIGH risk)

| Field | Value |
|---|---|
| File | `Epistemos/KnowledgeFusion/UI/TrainingHistoryView.swift` |
| Line | `78` |
| Action | `await vm.deleteAdapter(adapter)` |
| Risk | **HIGH** — deleting a trained adapter destroys hours-to-days of training compute and is irreversible. The user cannot reproduce a deleted QLoRA / QDoRA adapter without re-running the training pipeline. |
| Action class (per doctrine §A.7) | **Destructive** (every-time prompt + passcode) — arguably **Sovereign** if the adapter encodes private training data |
| Smallest safe slice | New helper `KnowledgeFusionAdapterDeletionSovereignGate` mirroring `ModelVaultDeletionSovereignGate` shape; route through existing `AppBootstrap.shared?.sovereignGate.confirm`. New file `Epistemos/KnowledgeFusion/UI/KnowledgeFusionAdapterDeletionSovereignGate.swift` + edits to `TrainingHistoryView.swift` line 78 + new test in `EpistemosTests/KnowledgeFusionAdapterDeletionSovereignGateTests.swift`. |
| Tier | Core (training is a Core surface today) |

### S-2 — Custom graph preset delete in GraphForceSettings (LOW risk)

| Field | Value |
|---|---|
| File | `Epistemos/Views/Graph/GraphForceSettings.swift` |
| Line | `322–324` |
| Action | `graphState.deleteCustomPreset(id: preset.id)` |
| Risk | **LOW** — a graph layout preset is cosmetic and trivially recreated. Touch ID on every preset delete would be friction without benefit. |
| Action class | **Reversible** (no biometric) OR **Sensitive** (15-min grace) at most |
| Recommendation | **Defer.** This is below the threshold for Sovereign Gate routing per the doctrine §A.7 action-class matrix. Leave as a plain `role: .destructive` button. If the user disagrees, S-2 becomes a one-line confirmation dialog rather than biometric. |
| Tier | Core |

### S-3 — Block delete in EpdocBlockContextMenu (MEDIUM risk)

| Field | Value |
|---|---|
| File | `Epistemos/Views/Epdoc/EpdocBlockContextMenu.swift` |
| Line | `139` |
| Action | `onDelete()` (closure injected by parent — deletes one Tiptap block) |
| Risk | **MEDIUM** — block deletion is recoverable via the editor's undo stack but is a noticeable interruption of writing flow. The user may also delete a block containing significant content. |
| Action class | **Sensitive** (15-min grace) — too friction-heavy to require Touch ID on every block delete; grace is the right shape |
| Smallest safe slice | New helper `EpdocBlockDeletionSovereignGate` returning `.biometric(category: .epdocBlockDelete, graceDuration: 15 * 60)`. **However**, the editor itself is a protected path (`Epistemos/Views/Notes/ProseEditor*.swift` and graph render internals), and `EpdocBlockContextMenu.swift` lives in `Views/Epdoc/`, not `Views/Notes/`. Confirm with the user whether `Views/Epdoc/` is part of the protected-path family before touching. |
| Tier | Core |
| Coordination flag | **YES** — verify protected-path scope before slicing |

### S-4 — Property entry delete in BlockPropertySheet (LOW risk)

| Field | Value |
|---|---|
| File | `Epistemos/Views/Notes/BlockPropertySheet.swift` |
| Line | `44–46` |
| Action | `entries.removeAll { $0.id == entry.id }` (in-memory mutation in a sheet) |
| Risk | **LOW** — the sheet is a transient editing surface; removing an entry mutates the local `@State` array. The user can dismiss without saving to discard. |
| Action class | **Trivial** (no prompt) — already Sovereign-correct as-is |
| Recommendation | **No change.** Sheet-local mutations that don't persist on dismiss don't need Sovereign Gate routing. |
| Tier | Core |

---

## 4. Sensitive (non-destructive) surfaces worth surveying separately

Beyond `role: .destructive` buttons, the doctrine §A.7 also surfaces:

- **Permission grant flows** — TCC dialogs (Screen Recording, Accessibility, Full Disk Access) that the app surfaces through Settings or onboarding. These are macOS-owned prompts; Sovereign Gate does not own them. **No action needed.**
- **OAuth scope grants** — When the user authorizes a cloud provider (OpenAI, Anthropic, Google) via OAuth, Sovereign Gate should wrap the redirect-handling step. Existing path: `Epistemos/Engine/CloudProviderAuthService.swift`. **Recommend a future inspection slice S-5 (research-only, no code) to verify whether the OAuth completion handler routes through `SovereignGate.confirm`.**
- **Keychain writes** — Per `CLAUDE.md`, "API keys in macOS Keychain (SecItemAdd/SecItemCopyMatching), NEVER UserDefaults." Adding/rotating an API key is **Sensitive** action class. **Recommend S-6 (research-only): grep for `SecItemAdd` / `SecItemUpdate` and verify each write site is biometric-gated or explicitly user-initiated through a Sovereign-routed UI.**
- **Vault export / cloud sync trigger** — If/when the user can export a vault snapshot or upload to a cloud sync surface, that crosses category boundaries (private content leaving local trust boundary). **No surface exists today** per a quick scan; defer until one is built.

---

## 5. Recommended PR queue (prioritized)

Pick top-down. Each is file-disjoint from Codex's round-75 reservation set (Phase5Bridge.swift, GraphEventConsumerProjection guards, current deliberation/oversight/fleet folders).

| Order | Slice | Effort | Tier | Why this rank |
|---|---|---|---|---|
| 1 | **S-1 Adapter delete** | M | Core | Highest payload risk; losing a trained adapter is irreversible work |
| 2 | **S-5 OAuth completion handler audit** (research-only) | S | Pro | Read-only audit; pre-requisite to any OAuth-Sovereign wiring |
| 3 | **S-6 Keychain write site audit** (research-only) | S | Core | Read-only audit; identifies where Sensitive action class needs to be applied |
| 4 | **S-3 Block delete** (with protected-path coordination check first) | S–M | Core | Medium risk + needs scope confirmation before code |
| — | S-2 Custom preset delete | — | — | **Defer per §3 S-2 — risk too low to justify the friction** |
| — | S-4 Property entry delete | — | — | **No change per §3 S-4 — sheet-local mutation** |

---

## 6. Reservation respect

This map was generated without editing any of:

- `Epistemos/Sovereign/SovereignGate.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `Epistemos/Bridge/Phase5Bridge.swift` (Codex round-75 reservation)
- `EpistemosTests/Phase5BridgeAgentEventTests.swift`
- `EpistemosTests/GraphEventConsumerProjectionGuardTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- Any current-slice deliberation file in `docs/fusion/deliberation/`
- Any current-round oversight file in `docs/fusion/oversight/`
- Protected paths: `ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`, graph physics/render internals

S-1, S-5, S-6, S-3 are all file-disjoint from the round-75 reservation set per `PARALLEL_WORK_MANIFEST.md`.
