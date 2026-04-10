# Migration and Rollback Plan

**Date:** 2026-04-08

## Feature Flag Strategy

All SSM state persistence is gated behind `EpistemosConfig`:

```swift
// Feature flags (UserDefaults backed)
ssmStatePersistenceEnabled: Bool = false    // Master switch
ssmAutoSaveOnTurnEnd: Bool = true           // Auto-save after each turn
ssmMaxSnapshotsPerModel: Int = 5            // Retention limit
```

### Flag Behavior

| Flag State | Behavior |
|------------|----------|
| `ssmStatePersistenceEnabled = false` | No state saved/loaded. MLX runs as before. Zero overhead. |
| `ssmStatePersistenceEnabled = true` | State saved after SSM model generation. Loaded on session resume. |
| `ssmAutoSaveOnTurnEnd = false` | State only saved explicitly (manual trigger). |

### Activation Path

1. User enables in Settings → AI → "Persistent SSM Memory"
2. `SSMStateService.activate(enabled: true)` called
3. Next SSM model generation → state auto-saved
4. Next session resume with same model → state loaded

## Rollback Procedures

### Level 1: Disable Feature (No Code Change)
- Set `ssmStatePersistenceEnabled = false` in Settings
- All state persistence stops immediately
- Existing state files remain on disk (inert)
- No impact on app behavior

### Level 2: Clear State Data
- Delete `{vault_root}/ssm_cache/` directory
- Delete `{vault_root}/ssm_state/` directory
- Can be exposed as "Clear SSM Cache" button in Settings

### Level 3: Remove Code (Emergency)
- Revert `EpistemosConfig.swift` changes (remove 3 @AppStorage lines)
- Revert `MLXInferenceService.swift` hooks (remove save/load calls)
- Remove `SSMStateService.swift`
- Remove `epistemos-core/src/ssm_state.rs`
- These are isolated additions — no existing code was modified destructively

## Data Migration

### v1 → v2 MAMB Format
- v2 reader supports v1 files (missing vault_id/model_hash default to 0)
- No explicit migration needed — files are read-compatible
- New saves always use v2

### MLX Cache Format
- Uses MLX-Swift's own serialization — no custom migration needed
- Forward-compatible with MLX-Swift updates (they maintain backward compat)

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| MLX state extraction fails | Feature flag OFF → no impact. SSMStateService returns nil. |
| State file corruption | Magic number validation. Corrupted files logged and skipped. |
| Model update invalidates state | State scoped by model_hash — different model = different directory. |
| Disk space growth | Auto-pruning via `ssmMaxSnapshotsPerModel`. NightBrain 30-day cleanup. |
| Performance regression | State operations are async, off main thread. Feature flag disables entirely. |

## Testing Checklist

- [ ] App builds with flag OFF — no new code paths execute
- [ ] App builds with flag ON — state saved after SSM generation
- [ ] Non-SSM models (Qwen, Gemma) completely unaffected
- [ ] State file created in correct directory
- [ ] State loads on session resume
- [ ] Invalid state file handled gracefully (logged, skipped)
- [ ] Pruning removes old files correctly
- [ ] Flag toggle mid-session works cleanly
- [ ] Memory usage does not grow with repeated save/load
