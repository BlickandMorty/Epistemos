# Plan 3 — Extensibility install UI + best-of preset (shipped code, Pass 5)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §5a/§5b`. Skill install works end-to-end; this records the shipped
> marketplace browse, URL-server writer, tabbed Settings surface, and curated one-tap preset.
> `[VERIFIED-CODE]`/`[INFERRED]` tagged. (§5c vault-as-MCP-server is in its own codepack.)

## Verified seams
- URL MCP servers: `agent_core/src/mcp/url_servers.rs:56 discover_url_mcp_servers()` reads capped bare-array JSON
  `{name,url,authorization_token_env?}` HTTPS-only (`:100-150`), paths `.epistemos/mcp_url_servers.json` (project) +
  `~/.config/mcp/url_servers.json` (global). Runtime discovery rejects final symlink config files, malformed or
  secret-bearing URL components, unsafe env-key shapes, and inline token values before forwarding MCP server config to
  the provider. Swift `MCPUrlServerDirectory.parse/discover/write/install/uninstall` covers the same active display
  surface plus MAS-safe HTTPS config writes; it rejects inline token rewrites. Skill install:
  `SkillsDetailView` → `skill_manage` (`skills.rs:741`, github/url Pro-gated `:753`, local unconditional). Surface policy
  `ToolSurfacePolicy.Distribution` (`ToolTierBridge.swift:170,207,278`). Built-ins via `OmegaToolRegistry`
  (`MCPBridge.swift:82`). MAS gate idiom `#if EPISTEMOS_APP_STORE || MAS_SANDBOX`
  (`DeploymentProfileHealthRow.swift:24`).
  Tool-tier list/execution failures now stay visible while mapping external Swift/Foundation errors to bounded
  domain/code diagnostics and capping tool JSON error payloads before they reach UI/tool-call surfaces, with raw
  message/domain strings bounded before trimming and ellipsis kept inside configured caps.

## 1. `Epistemos/Omega/MCPRegistryClient.swift` [DELIVERED]
Pure `URLSession` clients for **Smithery / mcp.so / Glama / GitHub** → unified
`MCPRegistryEntry{id,name,description,source,installKind(.remoteURL|.stdioCommand|.skillRepo),installTarget,homepage}`.
`searchAll(query)` bounds query text, fans out via TaskGroup, dedupes by id; each `search*` is defensive (schema drift or
oversized JSON → empty, never crash), caps per-source record processing, and filters remote URL targets that carry
userinfo/query/fragment secret channels. Registry responses must stay on the requested HTTPS host/path after redirects.
Registry fields are raw-capped, control-stripped, trimmed, and capped before display/ID construction; nested schema
probing is depth-bounded, `searchAll(limit:)` clamps non-positive/oversized limits, and GitHub repo URLs are parsed with
`URLComponents` so
userinfo/query/fragment channels are rejected there too. Registry homepage URLs are HTTPS-only with userinfo/query/fragment
channels rejected before entries carry them. `isMASInstallable = installKind == .remoteURL`. **GitHub search
is the one documented/stable endpoint; the other three registry endpoints are `[INFERRED]` — confirm at build time.** No
exec, no write → MAS-safe.

## 2. `MCPUrlServerDirectory.write/install/uninstall` [DELIVERED]
Mirrors the read contract + the Rust `entry_to_config`: HTTPS-only (`WriteError.notHTTPS`), no URL userinfo/query/fragment
secret channels, strict process-env-shaped auth keys, inline token entries hidden from the active forwarded surface,
secret-safe validation diagnostics, **name-dedupe idempotent** (re-install replaces, never duplicates),
**token VALUE never written or forwarded from config** (only a process-env-shaped `authorization_token_env` name), bare-array JSON to
`~/.config/mcp/url_servers.json` (atomic write; parent directory forced owner-only `0700`, config file forced
owner-only `0600`). Config reads are regular-file checked, final-symlink and multi-hardlink files rejected, and bounded at 256 KiB before JSON
decode; mutations refuse unsafe existing config files instead of treating them as missing.
`install(WritableEntry)` / `uninstall(name:)` return the new `[ServerInfo]`. Config write only → **MAS-safe**; the Rust
side forwards via the Anthropic `mcp_servers` API param.

## 3. `Epistemos/Views/Settings/ExtensionsDetailView.swift` [DELIVERED]
Segmented tabs: **Skills** (reuses the existing real `SkillsDetailView`) · **MCP Servers** (`MCPServersDetailView`:
installed-list with delete + add-HTTPS-server form with `https://` validation + marketplace browse via §1, one-tap
Install for `.remoteURL`, `.stdio`/`.skillRepo` shown disabled "unlocks in Pro" in MAS) · **Connectors** (existing
read-only `CoworkConnectorDirectory` status) · **browser-use** (Pro diagnostics/settings). URL-server discovery,
install/uninstall, connector refresh, Best-of manifest row loading, and Best-of apply/revert run off the SwiftUI path in
detached utility workers. Settings now routes `.skills` to `ExtensionsDetailView()` where
`@Environment(VaultSyncService.self)` is available. Skills settings actions render through `ToolbarCapsuleButton`,
status text/pills use `UIState` theme tokens, repeated discovery/inventory rows use a fixed row gap instead of hard
separator rules, and Skills plus MCP URL-server/search inputs use the shared flat `SettingsFlatInputChrome` theme-token
surface. Skills settings status text caps skill-manager messages and maps external caught Swift/Foundation failures to
bounded domain/code diagnostics before SwiftUI display, with raw message/domain strings bounded and control/whitespace-normalized before trim/validation.
MCP server settings
status text caps success/failure messages and maps external config-write failures to bounded domain/code diagnostics,
with raw failure/domain strings and success-message display names bounded and control/whitespace-normalized before trimming or punctuation validation;
write-error LocalizedError descriptions are bounded at the source before any SwiftUI status layer can render them.
Primary MCP-server, marketplace, preset, and connector refresh actions render through `ToolbarCapsuleButton` native
chrome instead of local plain buttons, and status text/pills use `UIState` theme tokens rather than fixed
traffic-light colors. Repeated installed-server, registry, preset, and connector rows use a shared fixed row gap instead
of hard separator rules so Settings chrome stays theme-owned.

## 4. `BestOfPreset.swift` + `Epistemos/Resources/best_of_preset.json` [DELIVERED]
Manifest `{kind:.builtinTool|.skillRepo|.remoteMCP, id, displayName, why, minDistribution}` over **only-real-today**
capabilities (eidos.query/vault.search/web.search/web.fetch/think/graph.query/graph.neighbors — all already in
`coreAppStoreAllowedToolNames` `:213-227`; + Anthropic skills repo `[INFERRED url]`; + Context7 HTTPS MCP `[INFERRED url]`).
`apply(vaultPath:distribution:)` is **idempotent + reversible**, diffing the 3 live seams: built-ins → reported
`.alreadyEnabled` (honest — no fake surface), remoteMCP → §2 writer, skillRepo → `skill_manage install_from_github` (Pro).
Honest per-row gating: rows above the build's distribution return `.proLocked` ("unlocks in Pro"), never silently enabled.
`revert()` removes only the remoteMCP rows it added and whose current URL still matches the preset target (built-ins are
policy not state; skill-repo removal is destructive → manual). The bundled manifest loader and receipt persistence are
conservative: regular files only, bounded JSON, and no
final symlink read/write. Apply/revert status text caps and control/whitespace-normalizes skill/tool-returned strings and
maps external caught failures to bounded domain/code diagnostics before the per-row pills render, reusing the bounded,
control/whitespace-normalized MCP URL diagnostic helper.
`BestOfPresetCard` = one-tap UI with per-row status pills; the UI invokes apply/revert from
detached utility workers so config writes do not block Settings. Install-target URLs isolated in `installTarget(for:)`.

URL MCP config reads/writes also reject existing symlink components in the config directory path before reading or
creating `mcp_url_servers.json` / `url_servers.json`, so a symlinked parent cannot redirect MAS-safe config mutations
outside the intended config root.

## 5. MAS/Pro split
| Capability | MAS | Pro | Gate |
|---|---|---|---|
| Skill create/edit/delete + local install | ✅ | ✅ | `skills.rs:743,773` |
| Skill install GitHub/URL | ❌ "Pro only" | ✅ | `skills.rs:753` `#[cfg(pro-build)]` |
| Marketplace browse | ✅ | ✅ | §1 pure networking |
| Add HTTPS URL MCP server | ✅ | ✅ | §2 config write |
| Install stdio MCP / GitHub skill from marketplace | ❌ disabled "unlocks in Pro" | ✅ | subprocess spawn `mcp/client.rs:221` |
| Best-of preset apply | ✅ (built-ins + HTTPS MCP) | ✅ (+ skillRepo) | §4 `isUnlocked` |

Honesty: no fake tool surfaces (built-ins `.alreadyEnabled`); Pro rows disabled+labeled; tokens never in JSON; every
MAS-lane install is config-write or network-read only; subprocess paths deferred to existing Pro gates.
