# PLAN 3 Whole-App Brand Logos Codepack (shipped code) - 2026-06-28

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md` section 11. Scope:
> non-model brand-logo coverage across engines, integrations, MCP, marketplace, tools, and landing-button audit. This builds on the already-shipped model
> provider logo work; it does not replace or fork that map.

## Shipped Verified State

- [VERIFIED-CODE] Model-provider logos already have a single source of truth:
  `Epistemos/Views/Shared/ProviderBrandLogo.swift` defines `ProviderBrand`, maps
  model providers and local model families, and provides render-safe SF Symbol
  fallbacks.
- [VERIFIED-CODE] Model logo rendering already lives in
  `Epistemos/Views/Shared/ProviderLogoView.swift`, which renders an asset-catalog
  image when present and falls back to a symbol.
- [VERIFIED-CODE] Existing provider SVG assets live under `Epistemos/Assets.xcassets`
  as `ProviderLogo*.imageset` entries. These assets are model-provider scoped.
- [VERIFIED-CODE] The Plan 3 extensibility surface currently has inline symbols
  in `Epistemos/Views/Settings/ExtensionsDetailView.swift`: installed MCP server
  rows, marketplace entries, best-of preset rows, and connector rows.
- [VERIFIED-CODE] The connector directory in
  `Epistemos/Engine/CoworkConnectorDirectory.swift` is honest-state only: it
  derives connection status from actual configured URL MCP servers and does not
  store tokens or pretend a connector is connected.
- [VERIFIED-CODE] `Epistemos/Views/Shared/IntegrationBrandMark.swift` is the
  non-model brand registry. It has no runtime logo download path and no official
  vendor asset claims. Monogram fallbacks render as flat, borderless local marks
  backed by `UIState` theme tokens.
- [VERIFIED-CODE] `Epistemos/Views/Settings/ExtensionsDetailView.swift` uses
  `IntegrationBrandMarkView` for installed MCP servers, marketplace rows,
  best-of preset rows, and connectors.
- [VERIFIED-CODE] `Epistemos/Views/Settings/SkillsSettingsView.swift` uses
  `IntegrationBrandMarkView` for discovered skills, create/install skill rows,
  and installed skills, tinted from the active Settings theme tokens rather than
  hierarchical system secondary styling.
- [VERIFIED-CODE] The Plan 3 arXiv, Browser, and Meeting utility headers use
  `IntegrationBrandMarkView`.
- [VERIFIED-CODE] The browser-use Pro Settings diagnostics surface uses the
  non-model `IntegrationBrandMarkView` and does not share claims with the native
  Browser tab.
- [VERIFIED-CODE] `LandingFeatureButton` exposes an `integrationBrand` mapping
  for every Plan 3 landing feature button, and `LandingFeatureButtonTile` passes
  that mapping into `PixelLandingCommandTile` so each Plan 3 landing shortcut
  renders a registry-backed brand mark without changing non-Plan-3 command tiles.
- [VERIFIED-CODE] Settings sidebar branded rows now use `SettingsIntegrationBrandBadge`
  and a typed `SettingsSection.sidebarBrand` mapping for Voice, Extensions, Vault,
  and Provenance while unbranded rows stay on the existing local symbol badge.
  Sidebar row descriptions read the active settings theme muted token.
  Settings disclosure subtitles read the active theme muted token rather than
  hierarchical system secondary styling.

## Non-Goals And Boundaries

- Do not touch Plan 1 files: `Epistemos/Goose/*` or `Epistemos/Agent/*`.
- Do not touch Plan 2 editor surfaces: Epdoc, code editor, Prose, MarkEdit,
  JavaScript editor, HTML workspace, wikilinks, or the PDF viewer.
- Do not download logos at runtime.
- Do not fetch brand assets from the network during app execution.
- Do not add official vendor raster/SVG assets unless the asset, license, and
  provenance are checked into the repo with a clear legal source.
- Do not fake official logos. If there is no vetted asset, render a local,
  honest brand mark: a symbol or monogram with an accessibility label that says
  "mark", not "official logo".
- Do not route through Python, subprocesses, Chromium, browser-use, or any Pro
  runtime path for this MAS-safe logo pass.
- Browser-use remains Pro/Developer-ID only. The native WebKit Browser and the
  browser-use Chromium robot are separate surfaces and must not share claims.

## Architecture

Add a non-model brand registry beside the existing provider registry:

- `ProviderBrand` remains model-only.
- `IntegrationBrand` covers non-model brands and product/tool surfaces:
  vault, web, graph, MCP, skills, registries, connectors, arXiv, Browser,
  meeting/STT, voice, provenance, and landing features.
- `IntegrationBrandMarkView` renders a vetted asset when present, otherwise a
  deterministic SF Symbol or flat monogram fallback.
- Registry classifiers bound each arbitrary MCP/skill/connector input, including
  source/kind/install-source fields, before joining, trimming, and normalization
  so oversized registry names cannot drive unbounded UI string work.
- Surface code asks the registry for a brand. It must not add local ad-hoc
  `if name contains` chains in view bodies.

The delivered implementation wires `IntegrationBrandMarkView` into the Plan 3
extensibility settings rows:

1. Installed URL MCP servers.
2. Marketplace search results.
3. Best-of preset items.
4. Connectors.

This gets engines/integrations/MCP/marketplace/tools on a shared model without
touching Plan 1 or Plan 2.

## Delivery Order

1. [DONE] Verify current model-logo work and Plan 3 logo scope.
2. [DONE] Add this codepack before code changes.
3. [DONE] Add `IntegrationBrand` and `IntegrationBrandMarkView`.
4. [DONE] Wire the first slice into `ExtensionsDetailView`.
5. [DONE] Wire skills settings, arXiv, Browser, Meeting, and landing-feature
   brand mappings.
6. [DONE] Add source guards that lock the no-fake-logo, no-runtime-fetch, no Plan 1,
   and no Plan 2 boundaries.
7. [DONE] Run parse/source verification while any external Xcode lane is active.
8. [DONE] Wire Plan 3 landing-feature button tiles to their registry-backed brand marks.
9. [DONE] Wire settings sidebar marks for clearly branded Plan 3 settings rows.
10. Later slices: utility panel metadata and any licensed official asset import.

## Acceptance Gates

- Every non-model branded row in the first slice has a registry-backed mark.
- Every Plan 3 landing feature button renders its `integrationBrand` through the
  shared brand mark view.
- The registry has render-safe fallbacks for every case.
- Official asset use is optional and provenance-gated.
- No runtime logo download path exists.
- No Plan 1 or Plan 2 file is edited.
- No MAS-forbidden Python/subprocess/Chromium path is introduced.
- Focused source guards and parse checks pass.
