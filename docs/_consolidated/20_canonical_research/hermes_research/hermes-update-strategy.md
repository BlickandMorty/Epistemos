# Hermes Update Strategy (Strategy B)

> **Index status**: CANONICAL-RESEARCH — Hermes integration research (Phase D + K reference).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/hermes_research/`.



## Overview
Epistemos avoids direct updates from upstream (NousResearch) or tightly pinning updates to Epistemos's monthly CD cycle. Strategy B proposes an intermediate auto-update solution delivering Epistemos-signed `.zip` updates directly via `updates.epistemos.app`.

## Strategy Flow
1. **Upstream Polling:** CI polls NousResearch Hermes repository for tagged releases.
2. **Build and Test:** CI cross-compiles Universal `hermes-runtime.zip`, executing the full MCP interface test suite.
3. **Cryptographic Signing (EdDSA):** `swift-crypto` utilizes an Epistemos-controlled Ed25519 signing key to detach a `.sig` against the `runtime.manifest.json` embedded in the zip.
4. **App verification:** `HermesUpdater.swift` uses a baked-in `SUPublicEDKey` fetched from `Info.plist` at app build-time. Zip updates are rejected outright if signatures mismatch or downgrade checks flag rollback.

## Rollback System
`~/Library/Application Support/Epistemos/HermesRuntime/<semver>` manages the active symlink `current`.
If supervision traces `restartCount >= 3` globally, `HermesSubprocessManager` rolls back the symlink pointer `current` to the previous cached `<version-dir>`, executing a fallback payload. 3 prior runtime versions are maintained to provide resilient crash failure redundancy natively.
