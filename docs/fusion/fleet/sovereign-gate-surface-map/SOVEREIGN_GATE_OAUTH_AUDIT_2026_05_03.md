# Sovereign Gate OAuth Completion Handler Audit — 2026-05-03

> **Verdict: NO Sovereign Gate gap on initial sign-in (already user-initiated). One silent-refresh AUDIT gap on token refresh paths — not Sovereign-class, but worth a tiny `AgentEvent` provenance row for audit visibility.**
>
> Read-only audit per `SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md` SG-CARD-2. Source authority: `Epistemos/Engine/CloudProviderAuthService.swift` (1,328 lines), `Epistemos/Views/Shared/CloudProviderSetupCard.swift`, `Epistemos/Sovereign/SovereignGate.swift`.

---

## 1. Cited evidence

| File:line | Role |
|---|---|
| `Epistemos/Engine/CloudProviderAuthService.swift:8` | `enum CloudProviderOAuthMode` — supports `openAICodex`, `googleGemini` |
| `:14` | `struct CloudProviderOAuthCredential` — encoded credential blob saved to Keychain |
| `:78` | `struct GoogleOAuthClientConfiguration` — client config (also Keychain-backed for user override) |
| `:257` | `@MainActor final class CloudProviderAuthService` — service entry |
| `:271-274` | Default `keychainSave` closure — calls `Keychain.save(value, for: key)` |
| `:288-294` | `storedOAuthCredential(for:)` — read |
| `:297-306` | `storeOAuthCredential(_:)` — **write site** (called from sign-in success + token refresh) |
| `:308-310` | `clearOAuthCredential(for:)` — sign-out delete |
| `:316-336` | `resolvedCredential(for:apiKey:)` — calls `refreshedCredentialIfNeeded(_:)` on every resolution |
| `:705-732` | OpenAI device-code polling loop |
| `:762-789` | `exchangeOpenAIDeviceCode(_:)` — Authorization Code → Access Token exchange |
| `Epistemos/Views/Shared/CloudProviderSetupCard.swift:63` | UI `Save` button calls `Keychain.save(...)` for the Google client config blob |
| `Epistemos/Views/Shared/CloudProviderSetupCard.swift:72` | UI `Clear` button calls `Keychain.delete(...)` |

`grep` for `SovereignGate.confirm\|sovereignGate\.confirm` against `CloudProviderAuthService.swift` and `CloudProviderSetupCard.swift` returns **zero hits** — neither the OAuth flow nor the OAuth setup card is currently Sovereign-routed.

---

## 2. The OAuth lifecycle (verified from source)

```
User clicks "Sign in with OpenAI"  ← user-initiated (UI)
    │
    ▼
exchangeOpenAIDeviceCode → access_token + refresh_token
    │
    ▼
storeOAuthCredential → keychainSave → SecItemUpdate / SecItemAdd
    │
    ▼ (later, on every resolvedCredential call)
refreshedCredentialIfNeeded
    │
    ├─ token still valid → return as-is (no Keychain write)
    └─ token near expiry → fetch new token → storeOAuthCredential → SILENT KEYCHAIN WRITE
```

The silent-refresh branch is the only one that writes to Keychain without explicit user action.

---

## 3. Sovereign Gate verdict per branch

Per doctrine §A.7 action-class matrix:

| Branch | Action class | Current routing | Gap? |
|---|---|---|---|
| Initial sign-in (`Sign in with OpenAI` button) | **Sensitive** (15-min grace) | User-initiated through UI button — no biometric prompt today | **No gap.** User-initiated UI suffices for Sensitive. Doctrine does not require Touch ID for "user clicked Sign in" — only for Destructive / Sovereign classes. |
| Token refresh (`refreshedCredentialIfNeeded`) | **Trivial** (no prompt, recorded) | Silent write to Keychain, no audit event | **AUDIT gap (not Sovereign gap).** Token refresh shouldn't prompt the user every 60 minutes, but the silent refresh has no provenance row — an audit can't reconstruct WHEN credentials rotated. |
| Sign-out (`Clear` button) | **Sensitive** (15-min grace) | User-initiated through UI button — no biometric prompt today | **No gap.** Same rationale as sign-in. |
| OAuth client config save (`CloudProviderSetupCard.swift:63`) | **Sensitive** (15-min grace) | User-initiated through Settings UI Save button | **No gap.** |

**No Sovereign Gate slice is needed for OAuth.** The flow is correctly user-initiated for Sensitive-class action; Touch ID would be friction without security benefit (the user is staring at the Sign-In dialog when the write happens).

---

## 4. Real gap surfaced: silent token-refresh AUDIT visibility

`refreshedCredentialIfNeeded` writes a new Keychain credential silently when the access token nears expiry. Today that write emits zero provenance — not in `Log`, not as `AgentEvent`. An audit timeline shows:
- Initial sign-in (visible to user)
- ... <gap of N hours/days>
- Token expiry / silent refresh (invisible)
- ... <gap>
- Token expiry / silent refresh (invisible)

If a stolen refresh-token vector were ever in play, the silent refresh would be the only signal — and it doesn't get one.

### Proposed slice (not Sovereign Gate — AgentEvent provenance)

| Field | Value |
|---|---|
| Slice | `oauth-refresh-agent-event-pr46` (or similar) |
| Lane | Core open / runtime AgentEvent coverage |
| Effort | S |
| Allowed write set | `Epistemos/Engine/CloudProviderAuthService.swift` (only the `refreshedCredentialIfNeeded` function), `EpistemosTests/CloudProviderAuthServiceRefreshAgentEventTests.swift` (NEW) |
| Forbidden write set | All other CloudProviderAuthService functions, `Epistemos/Sovereign/SovereignGate.swift`, all canon-in-flight, all currently reserved Codex slices, `project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts |
| Sanitization invariants | `argumentsJSON` records provider name + previous-token-fingerprint (first 8 chars of SHA-256, NOT the token itself) + new-expiry timestamp. **Never** the access_token, refresh_token, or any provider secret. |
| Acceptance | Refresh emits `auth.token.refreshed` lifecycle event with `requested` + `completed/failed`. Sanitization tests prove no token bytes leak. Silent-refresh path stays silent (no Touch ID prompt). |
| Tier | Core + Pro (cloud providers are Pro/Research-only at runtime, but the audit code lives in Core) |

This is a small parallel slice that closes the audit gap without changing user-facing behavior.

---

## 5. Sign-in / sign-out source-guard suggestion

The current sign-in / sign-out paths in `CloudProviderSetupCard.swift` could benefit from a **source-guard test** (not a behavioral change) that asserts:
- The view never calls `LAContext()` (single-owner rule per doctrine §6 + Sovereign-Gate-Requirement-Matrix tests).
- The view never persists raw access tokens outside the `CloudProviderAuthService.storeOAuthCredential(_:)` codepath (defense in depth — prevents a future patch from caching tokens in `@State` or `UserDefaults`).

Suggested test file: `EpistemosTests/CloudProviderSetupCardSourceGuardTests.swift` (NEW). Effort: S.

---

## 6. Reservation respect

This audit was generated without editing any of:

- `Epistemos/Engine/CloudProviderAuthService.swift` (read-only)
- `Epistemos/Views/Shared/CloudProviderSetupCard.swift` (read-only)
- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/Engine/Keychain.swift`
- All currently-reserved Codex round-86 files
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- `docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md`
- `SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` (read-only source)
- `SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md` (read-only source)
- Protected paths
- `project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts

No `xcodebuild` invocation. No code edit. No staging. No commit.

## Usefulness

usefulness: +1
usefulness_reason: Closes SG-CARD-2 with a definitive verdict (no Sovereign Gate gap) and surfaces a NEW small AgentEvent slice (silent token-refresh provenance) the original surface map didn't anticipate — a real audit gap that's a clean parallel-safe S-effort PR.
