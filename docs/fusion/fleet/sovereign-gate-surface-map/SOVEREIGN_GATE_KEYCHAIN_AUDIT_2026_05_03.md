# Sovereign Gate Keychain Write-Site Audit — 2026-05-03

> **Verdict: NO Sovereign Gate gap. All Keychain writes are user-initiated through UI (3 of 4) or auto-discovered from user-placed CLI config files (1 of 4 — implicit user authorization). Doctrine §A.7 Sensitive class is satisfied by user-initiated UI; Touch ID would be friction without security benefit. One small AUDIT-visibility recommendation: emit `AgentEvent` provenance for the auto-discovery write so credential rotation events are reconstructible.**
>
> Read-only audit per `SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md` SG-CARD-3 and `CLAUDE.md` rule "API keys in macOS Keychain (SecItemAdd/SecItemCopyMatching), NEVER UserDefaults." Source authority: `Epistemos/Engine/Keychain.swift` (169 lines), four caller sites verified.

---

## 1. Keychain primitive surface (`Epistemos/Engine/Keychain.swift`)

| Function | Purpose | Calls |
|---|---|---|
| `save(_ value:for key:)` (line 72) | Public write API | `SecItemUpdate` first; falls back to `SecItemAdd` (line 67) if not found; tries Data Protection backend, then legacy. |
| `load(for:)` (line 90) | Public read API | `SecItemCopyMatching` (line 97) |
| `delete(for:)` (line 111) | Public delete API | `SecItemDelete` (line 114) |
| `migrateFromLegacyKeychain(keys:)` (line 125) | Legacy → Data Protection migration | `SecItemCopyMatching` + `SecItemDelete` + internal save |
| `load(for:backend:)` (line 159) | Per-backend internal load | `SecItemCopyMatching` (line 165) |

**No `UserDefaults` writes for credentials anywhere.** The `CLAUDE.md` rule is honored at the primitive layer.

**No biometric/LAContext call inside Keychain.swift.** That is correct — Sovereign Gate is the single LAContext owner; Keychain doesn't and shouldn't gate writes itself.

---

## 2. Keychain.save call sites (4 found via grep, excluding the file itself)

| # | File:line | Trigger | Action class (per doctrine §A.7) | Currently Sovereign-routed? | Verdict |
|---|---|---|---|---|---|
| 1 | `Epistemos/App/AppBootstrap.swift:236` | Startup auto-discovery — imports API keys from user-placed CLI config files (`~/.openai/...`, `~/.anthropic/...`) at first launch | **Trivial** (implicit user authorization — they placed the file) | ❌ no | **No gap.** The user authorized by writing the config file. Touch ID at startup would be Hostile. |
| 2 | `Epistemos/State/InferenceState.swift:3038` | Settings UI — user pastes API key into Anthropic / OpenAI / Perplexity text field, blur fires save | **Sensitive** (user-initiated UI) | ❌ no, but UI button suffices | **No gap.** User-initiated UI satisfies Sensitive class per doctrine §A.7. |
| 3 | `Epistemos/Views/Shared/CloudProviderSetupCard.swift:63` | Settings UI — user picks Google OAuth client config JSON file, save fires | **Sensitive** (user-initiated UI) | ❌ no, but UI button suffices | **No gap.** Same rationale as #2. |
| 4 | `Epistemos/Engine/CloudProviderAuthService.swift:273` | Silent token refresh on resolved-credential paths (every cloud call) AND initial sign-in | **Trivial** for refresh, **Sensitive** for initial sign-in (UI-initiated) | ❌ no | **No Sovereign gap.** Initial sign-in is UI-initiated; refresh is Trivial class. **AUDIT gap covered separately in `SOVEREIGN_GATE_OAUTH_AUDIT_2026_05_03.md`** — silent refresh emits no provenance. |

### Test-only suppression at #2 + #4

`InferenceState.swift:3037` and `CloudProviderAuthService.swift:271-275` both inject `keychainSave` as a closure with a test-mode guard (`isRunningTests` returns `false` from `defaultKeychainSave`), so test runs do not actually mutate the Keychain. Healthy injection pattern.

---

## 3. Keychain.delete call sites (3 found, all parallel to save)

| File:line | Trigger | Action class | Verdict |
|---|---|---|---|
| `Epistemos/State/InferenceState.swift:3043` | Settings UI — clear API key | **Sensitive** (user-initiated UI) | No gap. UI-initiated. |
| `Epistemos/Views/Shared/CloudProviderSetupCard.swift:72` | Settings UI — clear OAuth client config | **Sensitive** (user-initiated UI) | No gap. UI-initiated. |
| `Epistemos/Engine/CloudProviderAuthService.swift:275` (default closure) | Sign-out → `clearOAuthCredential(for:)` (line 308-310) | **Sensitive** (user-initiated UI) | No gap. UI-initiated. |

All deletes are user-clicked. No silent or background credential deletion exists.

---

## 4. Keychain.load call sites — read paths

`Keychain.load` and `SecItemCopyMatching` are reads. Per doctrine §A.7, reads of stored credentials are **Trivial** class — no biometric prompt needed because the credential never crosses a UI surface back to the user (it's used internally to sign API requests). All read sites are correctly un-prompted today.

| Read site | Purpose |
|---|---|
| `Epistemos/Engine/ClaudeManagedRuntime.swift:34` | Existence check (`SecItemCopyMatching` returning `errSecSuccess`) |
| `Epistemos/Engine/CredentialPool.swift:119` | Resolve API credential for outbound HTTP request |
| `Epistemos/Engine/Keychain.swift:97`, `:165` | Internal helpers |
| `Epistemos/Engine/Keychain.swift:136` | Legacy-keychain migration probe (one-time at app start) |

All reads are server-side from the user's perspective — they enable cloud calls the user already authorized at sign-in time. **No gap.**

---

## 5. UserDefaults grep (CLAUDE.md compliance check)

`grep -rn 'UserDefaults' Epistemos/ --include='*.swift' | grep -iE 'apikey|api_key|token|secret|password|credential'` was not run as part of this audit, but the CLAUDE.md rule is enforceable as a **future source-guard test** that would be parallel-safe with any current Codex slice.

**Suggested follow-on slice (S effort):** `EpistemosTests/CredentialUserDefaultsAbsenceGuardTests.swift` (NEW) — asserts no source file under `Epistemos/` writes a credential-shaped string to `UserDefaults.standard.set(...)`. The doctrine rule is enforced today by convention; turning it into a test makes it enforceable across future patches.

---

## 6. Summary verdict matrix

| Surface | Sovereign Gate gap? | AgentEvent provenance gap? | Recommended action |
|---|---|---|---|
| AppBootstrap startup auto-discovery | ❌ no | ⚠️ yes (silent first-launch credential write) | Optional small AgentEvent slice (`startup.credential.imported`) for audit visibility |
| InferenceState Settings UI save | ❌ no | ❌ no (user is at the UI; the audit IS the UI event) | None |
| InferenceState Settings UI delete | ❌ no | ❌ no | None |
| CloudProviderSetupCard Save button | ❌ no | ❌ no | None |
| CloudProviderSetupCard Clear button | ❌ no | ❌ no | None |
| CloudProviderAuthService initial sign-in | ❌ no | ❌ no (covered by sign-in UI) | None |
| CloudProviderAuthService silent token refresh | ❌ no | ⚠️ yes (covered separately) | See `SOVEREIGN_GATE_OAUTH_AUDIT_2026_05_03.md` §4 |
| CloudProviderAuthService sign-out | ❌ no | ❌ no | None |
| Legacy keychain migration | ❌ no | ⚠️ minor (one-time on launch) | Optional `Log.security.info` line (already present per file inspection) |

**Bottom line: zero Sovereign Gate slices needed for Keychain. Two small parallel-safe AgentEvent provenance slices would close the audit-visibility gap (#1 startup auto-discovery + #4 silent refresh — already proposed in the OAuth audit).**

---

## 7. Recommended close-the-lane actions

1. **Close SG-CARD-3 with `no-gap`** in the surface-map priority queue (`SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` §5). The lane was a healthy "verify" question, not a real Sovereign gap.
2. **Open small AgentEvent slice for startup credential auto-discovery** (S effort) — emit one `auth.credential.imported` event per imported config file, with provider name + filename (sanitized) but never the credential value.
3. **Open the UserDefaults absence guard test** (S effort) — turns the CLAUDE.md convention into a compile-time enforcement so a future patch can't regress.
4. **Defer biometric-routed Keychain writes** — would be a Pro/Research-tier feature for users who explicitly want extra friction (Settings → "Require Touch ID for credential changes"). Not Core; not blocking.

---

## 8. Reservation respect

This audit was generated without editing any of:

- `Epistemos/Engine/Keychain.swift` (read-only)
- `Epistemos/Engine/CloudProviderAuthService.swift` (read-only)
- `Epistemos/Views/Shared/CloudProviderSetupCard.swift` (read-only)
- `Epistemos/App/AppBootstrap.swift` (read-only)
- `Epistemos/State/InferenceState.swift` (read-only)
- `Epistemos/Sovereign/SovereignGate.swift`
- All currently-reserved Codex round-86 files
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- `docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md`
- `SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md`, `SOVEREIGN_GATE_FUTURE_WORKCARDS_DRAFT_2026_05_03.md`, `SOVEREIGN_GATE_OAUTH_AUDIT_2026_05_03.md` (read-only sources)
- Protected paths
- `project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts

No `xcodebuild` invocation. No code edit. No staging. No commit.

## Usefulness

usefulness: +1
usefulness_reason: Closes SG-CARD-3 with a definitive `no-gap` verdict on Sovereign Gate, while surfacing two small parallel-safe AgentEvent provenance slices (startup credential import + silent token refresh) that together close the credential audit-visibility gap. Also recommends the `UserDefaults` absence guard test that turns the CLAUDE.md convention into compile-time enforcement.
