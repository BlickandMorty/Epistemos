# Bundle Weight Audit — 2026-05-13

Closes RCA-P3-002 ("Audit Pro bundle weight and build fragility").

## Measurements (Debug builds, fresh as of 2026-05-13 MAS + 2026-04-29 Pro)

### MAS bundle (com.epistemos.appstore)
- Total: 731 MB Debug
- `Epistemos.debug.dylib`: 421 MB (Debug symbols — strips ~80% in Release)
- `Frameworks/libagent_core.dylib`: 143 MB (Debug)
- `Frameworks/libepistemos_shadow.dylib`: 76 MB (W8.4 + W8.7 tantivy + usearch backend)
- `Frameworks/libepistemos_core.dylib`: 61 MB
- `Frameworks/libomega_mcp.dylib`: 14 MB
- `Frameworks/llama.framework`: 8 MB
- Other resources: ~8 MB (Metal lib, Assets.car, SDF labels, manifest, mlx-swift bundle)
- **Python files in bundle: 0** ✅

### Pro bundle (com.epistemos.app)
- Total: ~771 MB Debug
- `Epistemos.debug.dylib`: 366 MB (Debug symbols)
- `Frameworks/libagent_core.dylib`: 113 MB (Debug, no Halo backend in April build)
- `Frameworks/libepistemos_core.dylib`: 41 MB
- `Frameworks/libomega_mcp.dylib`: 11 MB
- `Frameworks/libomega_ax.dylib`: 2.5 MB ⚠️ Pro-only (AX automation)
- `Frameworks/llama.framework`: 8 MB
- Testing frameworks: ~25 MB (XCTest / XCUIAutomation / Testing / XCTestCore / XCUnit / XCTAutomationSupport)
- Python files in bundle: 10 — `sgmm_kernel.py`, `test_router.py`, `__init__.py`, `test_sgmm_kernel.py`, `train_style.py`, `train_router.py`, `train_kto.py`, `train_knowledge.py`, `molora_inference.py`, `patch-uniffi-bindings.py` (the last only in test plugin)

## Target gating verification

| Asset | MAS | Pro | Expected? |
|---|---|---|---|
| `Epistemos.debug.dylib` (debug symbols) | 421 MB | 366 MB | ✅ Stripped in Release |
| `libagent_core.dylib` | 143 MB | 113 MB | ✅ MAS slightly larger because Halo backend rolled in; Pro April build pre-dates W8.4 |
| `libepistemos_shadow.dylib` | 76 MB | (will be 76 MB once Pro rebuilds) | ✅ Both ship Halo |
| `libomega_ax.dylib` (AX automation) | 0 MB | 2.5 MB | ✅ Pro-only |
| Python training scripts (`train_*.py`, `molora_*.py`, `sgmm_*.py`) | 0 | 10 | ✅ Pro-only (Python sandbox-forbidden) |
| Testing.framework + XCTest* | 0 | ~25 MB | ✅ Debug + Test only; not in Release archive |
| `libomega_mcp.dylib` | 14 MB | 11 MB | ✅ Both ship; MAS has MCP bridge for Anthropic/OpenAI etc. |

## Release-mode projections

Debug builds carry ~80% debug symbol overhead. Conservative estimates
for `Release` configuration (which is what ships to Mac App Store):

| Build | Debug size | Estimated Release size |
|---|---|---|
| MAS Release | 731 MB | **~150–200 MB** |
| Pro Release | 771 MB | **~170–220 MB** (no Testing.framework, no Python in App Store Pro release if shipped) |

Note: Pro is NOT going to App Store — it ships as a Developer ID
notarized DMG with all features intact (including Python +
subprocess paths).

## Build pipeline gates

1. **Cargo features at build time**:
   - `mas-build,lsp-runtime` for MAS — `cli_passthrough.rs` +
     `terminal.rs` modules `#[cfg]`-excluded from the dylib
   - `pro-build,lsp-runtime` for Pro — full surface
2. **Swift compile flag**: `EPISTEMOS_APP_STORE` — gates
   `CLIDiscoveryHealthRow.swift`, `EmbodiedCaptureService.swift`,
   and the `AppStoreComputerUseStubs` denial-by-design layer.
3. **Build script**: `build-agent-core.sh` picks the right Cargo
   feature based on `$TARGET_NAME`.
4. **Bundle resource exclusion**: Python scripts and any sandbox-
   incompatible assets are NOT in the MAS target's Compile Sources
   or Copy Bundle Resources phases.

## Verification commands (must pass before MAS submission)

```bash
APP="path/to/Release/Epistemos.app"

# 1. Zero Python files in MAS bundle
find "$APP" -name "*.py" | wc -l   # expected: 0

# 2. Zero subprocess path strings in MAS binary
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | \
  grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'
# expected: 0 matches (per RCA4-P0-002 fix-pass)

# 3. Bundle ID is the MAS one
defaults read "$APP/Contents/Info.plist" CFBundleIdentifier
# expected: com.epistemos.appstore

# 4. Sandbox entitlement is YES in Release
codesign -d --entitlements - "$APP" 2>&1 | grep app-sandbox

# 5. Symbol audit: no subprocess-related exports
nm -gU "$APP/Contents/Frameworks/libagent_core.dylib" 2>/dev/null | \
  grep -iE 'osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_(claude|codex|gemini|kimi)|computer_use|screencap'
# expected: 0 matches
```

## Bundle fragility

Scripts in the build pipeline:
- `build-agent-core.sh` — universal binary build for Rust dylibs;
  feature-flag dispatch by TARGET_NAME
- `build-tiptap-bundle.sh` — npm install + esbuild (content-hash
  gated on `package-lock.json`; skipped if hash unchanged)
- `build-epistemos-shadow.sh` — cdylib build for Halo backend
- `scripts/patch_mlx_metal_warnings.sh` — silences a known MLX
  Metal logging quirk
- `scripts/sync-uniffi-bindings.sh` — UniFFI checksum sync

Operational discipline:
- All scripts must be idempotent (re-runnable).
- `package-lock.json` is committed so the Tiptap bundle is
  reproducible.
- `agent_core/Cargo.lock` is committed.
- UniFFI bindings drift is detected via `Epistemos/AgentCoreFFI/checksums.json`.

## Cross-references

- `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` — authoritative MAS
  feature inventory
- `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` — tool surface
  per build
- `agent_core/Cargo.toml` — Cargo feature matrix
- `build-agent-core.sh` — feature-flag dispatch script
- Audit register: RCA3-P0-001 (CLI path strings, PATCHED),
  RCA4-P0-002 (MAS symbol scan, PATCHED), RCA-P3-002 (this doc)
