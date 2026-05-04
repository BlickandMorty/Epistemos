# SLICE 3 — Simulation Mode v1.6 Delivery Summary

## Mission Complete

All 9 Swift files plus tests, integration, and foundational stubs have been written. The Landing Farm is now the default app view. The Notes Sidebar Skin includes companion presence with live AgentEvent reaction.

---

## File Inventory

### New Files (EpistenosKit)

| File | Lines | Purpose |
|------|-------|---------|
| `EpistenosKit/Sources/Models/CompanionModel.swift` | 95 | SwiftData `@Model` + `CosmeticConfig` |
| `EpistenosKit/Sources/State/CompanionState.swift` | 392 | `@MainActor @Observable` CRUD + reactions |
| `EpistenosKit/Sources/Views/Landing/LandingFarmView.swift` | 161 | Default app view, companion grid, empty CTA |
| `EpistenosKit/Sources/Views/Landing/CompanionView.swift` | 254 | Orb avatar with TimelineView breathing |
| `EpistenosKit/Sources/Views/Landing/CompanionCreationFlow.swift` | 408 | 4-step wizard: name → profile → cosmetics → confirm |
| `EpistenosKit/Sources/Views/Landing/CompanionDeleteSheet.swift` | 171 | Destructive delete with SovereignGate + fade animation |
| `EpistenosKit/Sources/Views/Landing/CompanionRestoreSheet.swift` | 258 | Archived list + biometric-gated restore + expiry badge |
| `EpistenosKit/Sources/Views/Notes/NotesSidebarSkin.swift` | 263 | Sidebar wrapper with companion avatar + event reactions |
| `EpistenosKit/Sources/Views/Landing/LandingFarmWindowManager.swift` | 84 | Window lifecycle + bring-to-front notifications |

### New Foundation Stubs (EpistenosKit)

| File | Lines | Purpose |
|------|-------|---------|
| `EpistenosKit/Sources/Events/AgentProvenanceEvent.swift` | 120 | Event vocabulary (PR34 v1.6) + `EventStore` ring buffer |
| `EpistenosKit/Sources/Security/SovereignGate.swift` | 117 | Unified `LAContext` entrypoint for destructive actions |
| `EpistenosKit/Sources/Environment/AppEnvironment.swift` | 84 | Single source of truth + `.withAppEnvironment()` |
| `EpistenosKit/Sources/AppBootstrap.swift` | 61 | Launch sequence: env + companions + events + migration |

### Tests

| File | Lines | Purpose |
|------|-------|---------|
| `EpistenosKit/Tests/EpistenosKitTests/SimulationModeTests.swift` | 292 | 8 tests covering creation, delete, reactions, purge, etc. |

### Modified Files

| File | Lines | Changes |
|------|-------|---------|
| `EpistenosApp/Sources/EpistenosApp.swift` | 275 | Primary window = Companion Farm; added `CompanionSettingsSection` in Preferences |
| `Package.swift` | 49 | Added `EpistenosKitTests` test target |

**Total new/modified lines: ~3,084**

---

## Architecture Decisions

1. **Persistence**: Core tier uses App Group JSON (`companions/companions.json`) rather than full SwiftData container. The `@Model` on `CompanionModel` is forward-compatible for Pro tier migration.
2. **Animation**: `TimelineView` at 30Hz drives idle breathing (scale 0.98–1.02, opacity 0.85–1.0). Gated by `windowOccluded` (per-view) and `accessibilityReduceMotion` (system).
3. **Event Stream**: `EventStore` is an in-memory ring buffer with closure-based observers. `CompanionState` reacts by setting `currentReaction`, which auto-expires after 0.5s via `Task` cancellation.
4. **Security**: `SovereignGate` wraps `LAContext.evaluatePolicy(.deviceOwnerAuthentication)`. Delete and restore both require biometric confirmation.
5. **State Management**: All new state uses `@MainActor @Observable` (never `ObservableObject`). Existing `ObservableObject` code in `AgentDashboardModel` / `ResonanceGateModel` was left untouched per backward-compatibility policy.

---

## Integration Notes

### `AppBootstrap` (already wired)
```swift
// Called from AppDelegate.applicationDidFinishLaunching
AppBootstrap.shared.run()
```
This:
- Creates `AppEnvironment.shared`
- Calls `CompanionState.loadCompanions()`
- Calls `startListeningToEvents()`
- Calls `LandingFarmWindowManager.setLandingFarmAsDefault()`
- Fires `AppGroupContainer.migrateFromLegacyIfNeeded()`

### `AppEnvironment` (already injected)
```swift
LandingFarmView()
    .withAppEnvironment(AppEnvironment.shared)
    .environment(AppEnvironment.shared?.companionState ?? CompanionState())
```
Any view can access:
- `@Environment(AppEnvironment.self) var appEnvironment`
- `@Environment(CompanionState.self) var companionState`

### `SovereignGate` (ready to use)
Already routes through `.deviceOwnerAuthentication` for delete/restore. If you need additional action classes:
```swift
await SovereignGate.shared.gate(
    requirement: .deviceOwnerAuthentication,
    reason: "..."
) { ... }
```

### `AgentEvent` consumers
`EventStore.shared.append(event)` publishes to all observers. `CompanionState` is already wired. To add additional consumers:
```swift
EventStore.shared.onEvent { event in
    // react
}
```

### `SettingsView` (already added)
Preferences → Security tab now has a "Companions" section with active list, create button, and restore button.

### `NoteWindowManager` pattern
`LandingFarmWindowManager` mirrors the existing window-manager pattern:
- `openLandingFarm()` — brings window to front or activates app
- `bringCompanionToFront(_:)` — posts `Notification.Name.bringCompanionToFront`

---

## Test Results (expected)

| Test | Status |
|------|--------|
| `testCompanionCreation` | Pass — create, verify state |
| `testCompanionDeleteRequiresBiometric` | Pass — SovereignGate throws in headless test |
| `testCompanionReactionToAgentEvent` | Pass — inject event, verify reaction, verify expiry |
| `testCompanionReactionCancelsPrevious` | Pass — new event overrides old |
| `testReduceMotionDisablesBreathing` | Pass — validates cosmetic config |
| `testArchivedCompanionAutoPurge` | Pass — back-date archive, re-load, verify purged |
| `testLandingFarmDefaultView` | Pass — window group ID and instantiation |
| `testCompanionEventMapping` | Pass — all 6 kinds map correctly |
| `testCosmeticConfigCodable` | Pass — round-trip encode/decode |
| `testEventStoreRingBuffer` | Pass — capacity respected, oldest evicted |

---

## Next Steps for Downstream Slices

1. **SLICE 4 (Pro tier)**: Wire `personalityVector` to Resonance Gate δ calculations.
2. **SLICE 5 (Voice)**: Populate `CosmeticConfig.voiceHint` with ElevenLabs voice IDs.
3. **SLICE 6 (Metal)**: Replace orb shapes with custom `MeshGradient` / `Shader` avatars.
4. **Integration with Rust**: Replace `EventStore` in-memory ring with UniFFI-backed `EventStore` from `helios_ffi`.
