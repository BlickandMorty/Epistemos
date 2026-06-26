# Work/OpenGUI Donor Contract Registry

This registry explains which Work/OpenGUI names may be surfaced as Epistemos branding and which names must stay donor
compatible. Use it with `docs/WORK_CANON_STATUS_2026_06_25.md` before any rename pass.

## Rule

- Foreground product label: prefer `Epistemos Work`.
- Foreground neutral terms: runtime, engine, bridge, workspace, tools, sessions, permissions, questions, recents, transcript.
- Real picker/diagnostic/runtime identity: keep the actual engine name when it helps users choose or debug a real runtime.
- Donor/runtime/API/config/storage/protocol/import names: preserve unless a specific compatibility proof and tests show a
  rename is safe.

## Preserve

| Name or pattern | Kind | Why it stays named |
| --- | --- | --- |
| `OpenGUI`, `opengui` | Donor project/runtime identity | Identifies the harness and official clone; changing it obscures provenance and can break file, package, or sidecar assumptions. |
| `OpenCode`, `opencode` | Engine/CLI/runtime identity | The bundled binary, commands, paths, and protocol surface use this identity. Keep it for pickers, diagnostics, commands, and process control. |
| `OpenWork`, `openwork` | Fallback/runtime identity | The fallback SPA and localStorage/bootstrap contracts use this namespace. Keep it until fallback removal is proven live. |
| `Goose` | Future engine/adapter identity | It is a real engine seam, not Epistemos chrome. Keep it in diagnostics, tests, and later adapter contracts. |
| `opencode-runtime` | Bundled runtime resource path | Build scripts and app resource resolution look for this path. Renaming risks losing bundled OpenCode/Bun resolution. |
| `opencode.json`, `.opencode`, `OPENCODE_CONFIG` | OpenCode config contract | The runtime reads these names. Epistemos should merge/provision them, not rename them. |
| `OPENCODE_*` | OpenCode env contract | Runtime and sidecar behavior depend on these env names. |
| `OPENWORK_MANAGE_OPENCODE`, `OPENWORK_OPENCODE_BIN` | OpenWork env contract | The fallback supervisor uses these names to coordinate OpenCode ownership and binary path. |
| `OPENGUI_OPENCODE_PORT` | OpenGUI sidecar env contract | Epistemos probe/sidecar scripts use this for port-scoped OpenCode control and cleanup. |
| `Epistemos/OpenGUIRuntime`, `Epistemos/WorkOpenGUI/workspace` | Hidden app-owned storage paths | These are not foreground branding. They are migration-sensitive runtime/workspace locations under Application Support; renaming without an explicit migration can orphan state or break resume paths. |
| `openwork.server.token`, `openwork.server.active`, `openwork.server.list` | OpenWork SPA storage contract | The bootstrap and SPA expect these keys. Renaming would orphan auth/session state. |
| `openwork.preferences`, `openwork.themePref` | OpenWork SPA preference contract | Theme/onboarding bootstrap relies on these keys. |
| Sidecar NDJSON frame names | Protocol contract | The Swift supervisor and JS sidecar must agree byte-for-byte. |
| Tool names and MCP method names | Protocol/tool contract | OpenCode/OpenGUI/native MCP dispatch uses these names for routing. |
| Package/import/module names | Build contract | Renaming imports or package identities can break compilation or dependency resolution. |
| Bundle, TCC, Keychain, and automation hotwords | OS/automation contract | macOS permissions, stored credentials, or automation scripts may depend on exact names. |

## Epistemos-Owned Names

| Name or pattern | Why it can stay Epistemos-named |
| --- | --- |
| `Epistemos Work` | Visible product/chrome name. |
| `epistemos-native` | App-owned native tool/runtime identity, not a donor contract. |
| `epistemos-vault` | App-owned vault tool identity, not a donor contract. |
| `EPISTEMOS_OPENGUI_SIDECAR_ROOT` | App-owned sidecar-root override around the donor runtime. |
| `EPISTEMOS_WORK_OPENCODE_V0`, `EPISTEMOS_WORK_GOOSE_V0` | Legacy app-owned feature/diagnostic gates; preserve for compatibility unless a migration removes all readers. |

## Rename Checklist

Before changing a Work/OpenGUI name:

1. Classify it as foreground label, picker/diagnostic identity, app-owned wrapper id, or donor/runtime contract.
2. If it is a donor/runtime contract, do not rename it unless you can cite the readers/writers and update all tests.
3. If it is foreground UI, prefer `Epistemos Work` or neutral copy.
4. Run the foreground-name scan and protected-name scan from the current Work canon.
5. Run the focused seam tests for the touched area, then the broad Work/Workspace sweep for shared behavior.
