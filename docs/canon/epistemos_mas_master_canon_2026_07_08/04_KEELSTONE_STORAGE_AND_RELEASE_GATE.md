# 04 - KEELSTONE Storage and MAS Release Gate

## Storage architecture verdict

**Verdict: HYBRIDIZE current KEELSTONE.**

Keep the current file/artifact truth direction. Add an app-owned append-only provenance/op-log and stable content-ID layer. Do not revert to old DB-first storage. Do not make opaque proprietary storage the sole truth.

## Architecture diagram in words

User-visible vault files and artifacts are the durable root. KEELSTONE coordinates access, atomic writes, file event detection, conflict handling, and rebuild triggers. GRDB, search indexes, graph projections, embeddings, dataset working caches, thumbnails, and `.epcache` are projections. The append-only journal records app actions, agent effects, conflict witnesses, capture routes, dataset transforms, and provenance events. The journal can replay, explain, heal, or migrate; it cannot silently outrank the vault.

## Truth, derived, append-only, rebuildable

| Category | Contents | Rule |
|---|---|---|
| Truth | `.md` notes, dataset `.csv`, `.xlsx`, `.icalc`, `.dataset.md`, legal saved media/artifacts | User-readable, user-exportable, externally editable where practical |
| Derived | GRDB, FTS, embeddings, RRF, graph projections, dataset working cache, search indexes, `.epcache` | Rebuild from truth; never authoritative |
| Append-only | provenance ledger, op-log, route journal, conflict witnesses, suggestion events | Explains/replays/heals; does not override truth |
| Rebuildable | all caches, indexes, projections, previews, thumbnails | Delete/rebuild must not lose user data |

## Stable ID strategy

Every durable user object needs a stable ID that survives rename/move/import/export/cache rebuild:

- Notes: stable note ID in frontmatter or structured metadata path, plus path/inode correlation for moves.
- Datasets: stable dataset ID in `.dataset.md`, referenced by note embeds/tabs.
- ResearchHub saved items: source ID + canonical URL/DOI/arXiv/PMID where applicable, plus vault ID.
- Captures: capture ID + timestamp + route journal row.
- Agent/provenance events: event ID + turn ID + object ID + path snapshot + hash.

If IDs conflict with file truth, surface a repair prompt. Do not silently fork.

## Migration plan

1. Verify live repo body truth: find every production save path for notes, datasets, captures, ResearchHub items.
2. Land or verify `AtomicVaultWriter` for text and binary artifacts.
3. Collapse note bodies to vault `.md` only; `SDPage.body` and `NoteFileStorage` become metadata/history/staging only.
4. Add or verify append-only journal/provenance store.
5. Route LUMENLENS writes and RECKONER artifact writes through KEELSTONE.
6. Rebuild derived caches from vault; compare before/after.
7. Add rollback toggle to ignore journal and rebuild from files.

## Rollback path

- Disable journal consumers.
- Rebuild all derived stores from vault files/artifacts.
- Keep conflict copies and source files untouched.
- Restore prior App Store target settings from Git if pruning step misfires.
- Never delete old research; move old docs to provenance archive.

## Falsifier tests

These tests would prove the storage recommendation is wrong or incomplete:

- Incremental reconcile does not equal fresh rebuild after external edit storm.
- `kill -9` during write produces truncated or mixed file.
- Dirty open note is silently clobbered by external edit.
- GRDB deletion loses notes/datasets.
- Dataset artifact move/delete silently resurrects stale GRDB content.
- Op-log grows without bound or becomes necessary to read ordinary user files.
- App Review flags the storage model as opaque or privacy-unclear.

## Sync coexistence

Sync is not a server. It is safe coexistence with user-chosen file-sync systems.

- iCloud Drive / Dropbox / Syncthing can mutate files.
- FSEvents is broad change detection.
- `NSFileCoordinator` is write/read coordination.
- `NSFilePresenter` participates and receives coordinated changes, but is not the sole change source.
- Placeholders/dehydrated files must not be treated as empty/deleted.
- Clean editor can reload; dirty editor must enter merge/conflict flow.

## Base-app pruning

Pruning is part of KEELSTONE because archive truth is storage/release truth.

Required active target:

- `Epistemos-AppStore`
- `EPISTEMOS_APP_STORE`
- `MAS_SANDBOX`

Forbidden in MAS archive:

- `EPISTEMOS_EXPERIMENTAL`
- `KINDRED_ENABLED`
- OpenChamber/ProAgent code/resources/scripts/tests
- Goose runtime, browser-use, Chromium, Node/Tauri runtime, stdio MCP, terminal/code-exec, local server, subprocess sidecars

## Local verification commands

```bash
# MAS lane and parked-lane search
rg -n --hidden "EPISTEMOS_APP_STORE|MAS_SANDBOX|EPISTEMOS_EXPERIMENTAL|KINDRED_ENABLED|OpenChamber|ProAgent|1Code|Goose|Kindred|browser-use|Chromium|terminal|subprocess|stdio|local server|network.server" .

# Storage truth search
rg -n "SDPage|NoteFileStorage|AtomicVaultWriter|VaultSyncService|VaultIndexActor|SearchIndexService|ReadableBlocksIndex|NSFileCoordinator|NSFilePresenter|FSEvents|security-scoped|bookmarkDataIsStale|dataset|\.dataset\.md|AppColdStore|UAS|oplog|journal|provenance" Epistemos agent_core docs

# Build config / entitlements / privacy
find . \( -name "project.yml" -o -name "*.entitlements" -o -name "PrivacyInfo.xcprivacy" \) -print
xcodebuild -scheme Epistemos-AppStore -showBuildSettings | rg "SWIFT_ACTIVE_COMPILATION_CONDITIONS|CODE_SIGN_ENTITLEMENTS|PRODUCT_BUNDLE_IDENTIFIER"

# AppStore build and archive proof
xcodegen generate
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' build
xcodebuild -scheme Epistemos-AppStore -configuration Release archive -archivePath /tmp/Epistemos-AppStore.xcarchive
codesign -d --entitlements :- /tmp/Epistemos-AppStore.xcarchive/Products/Applications/Epistemos.app
strings /tmp/Epistemos-AppStore.xcarchive/Products/Applications/Epistemos.app/Contents/MacOS/* | rg -i "goose|openchamber|kindred|browser-use|chromium|playwright|tauri|node|pty|subprocess|stdio|localhost"

# Tests
swift test
cargo test --manifest-path agent_core/Cargo.toml
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' test
```
