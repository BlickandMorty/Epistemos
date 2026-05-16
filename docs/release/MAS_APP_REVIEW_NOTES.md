# Epistemos — Mac App Store Review Notes

Date: 2026-04-25
Bundle: `Epistemos-AppStore.app`
Build profile: MAS (sandboxed, `EPISTEMOS_APP_STORE` + `MAS_SANDBOX` compile flags)

This document explains entitlement choices for App Review. Attach to the
submission notes field in App Store Connect.

## 1. JIT entitlement (`com.apple.security.cs.allow-jit`)

**Why we use it**: Epistemos performs **on-device machine-learning inference** using Apple's MLX framework (mlx-swift, mlx-swift-lm). MLX compiles GPU compute pipelines (Metal shaders) at runtime when a local model is first loaded. This requires `allow-jit` because Metal's shader compiler emits executable code into a Mach-O code page allocated by the runtime.

**What we do NOT do with it**:
- We do NOT compile or execute user-supplied code, scripts, or expressions.
- We do NOT load remote code or web content into a JIT-capable surface.
- We do NOT use a JavaScript engine or general-purpose interpreter that compiles user input.
- We do NOT use the entitlement to bypass code signing or to load unsigned dylibs.

**What we use the entitlement for**:
- MLX shader compilation for on-device LLM inference.
- Metal Performance Shaders graph compilation for graph-engine rendering on Apple Silicon.

**References**:
- Apple Developer Documentation: "Allowing JIT Compilation for ARM-Based Apps".
- MLX-Swift package: https://github.com/ml-explore/mlx-swift
- MLX-LM package: https://github.com/ml-explore/mlx-swift-examples

## 2. Sandbox (`com.apple.security.app-sandbox = true`)

We are fully sandboxed in the App Store profile. All file access goes through user-selected files and folders, persisted via `com.apple.security.files.bookmarks.app-scope`. No general filesystem access. No automation entitlements. No accessibility bypass.

## 3. File access entitlements

- `com.apple.security.files.user-selected.read-write` — for vault folders the user explicitly opens via the system picker.
- `com.apple.security.files.bookmarks.app-scope` — to remember the user's chosen vault across app launches.
- We do NOT use `com.apple.security.files.bookmarks.document-scope` in the App Store build.

## 4. Network entitlement (`com.apple.security.network.client`)

For optional cloud AI providers (Anthropic, OpenAI, Google, Perplexity). All API requests are user-initiated. API keys are stored in the macOS Keychain (never in `UserDefaults`) and are scoped to the matching provider only. Users can opt out of cloud entirely and use local models.

## 5. What is NOT in the App Store build

The following are excluded at compile time (`#if !EPISTEMOS_APP_STORE`) AND at link time (post-build scrub of `libomega_ax.dylib` + `AXorcist.framework`):

- Accessibility tree walking (`omega-ax`).
- Apple Events / AppleScript automation.
- Screen capture (ScreenCaptureKit).
- Bash / shell / Docker subprocess tools.
- iMessage inbound integration.
- Computer-use stack (Phase 4 bridge, VisualVerifyLoop, AXMutationDetector).
- Python virtual environment / pip operations.
- External DCC integration via Apple Events.

These features only exist in our direct-distribution Pro build, never in the App Store binary.

## 6. Privacy

- `PrivacyInfo.xcprivacy` declares: file timestamp (display), system boot time (elapsed time), disk space (storage info), user defaults (app-local settings).
- No user tracking. No tracking domains. No data collection categories declared.
- All user notes, embeddings, and chat history stay on the user's Mac. The app contacts our servers only if the user enables a cloud AI provider, and then only that provider's published endpoint.
- We have a built-in **Privacy** pane in Settings that surfaces all of this transparency to the user.

## 7. Verification

- The Swift app calls `verifyAgentCorePolicyProfile()` at startup (`Epistemos/App/AppBootstrap.swift:2686-2704`). The MAS build will fatal if the linked Rust agent core is not the `mas_sandbox`-feature variant.
- Drift detection: `EpistemosTests/AppStoreHardeningTests.swift` (16-test suite) enforces every entitlement and Info.plist key on every CI run.
- Privacy manifest drift: `AppStoreHardeningTests.swift:74-85` enforces the `PrivacyInfo.xcprivacy` shape on every CI run.

## 8. Reviewer-facing demo flow

To exercise the local-only path (no JIT triggered):
1. Launch the app.
2. Create a vault.
3. Create a note. Type. Save.
4. Search for the note (FTS5).
5. Open the graph view. Pan + zoom.
6. Open Settings → Privacy. Verify the transparency content matches this document.

To exercise the JIT path:
1. Open Settings → AI → Local Models.
2. Enable a small local model (e.g., a 1B parameter model).
3. The first message in chat triggers MLX shader compilation (the JIT use).
4. All subsequent messages reuse the compiled shaders.

No user input is ever compiled or executed.

---

## 9. Pro Notarization Checklist (T-A iter 17, 2026-05-16)

This section governs the **Pro Developer-ID distribution path** (out-of-scope for App Store Review — that's §§1-8 above). It aligns with V3 §0 victory criteria 11/12/13 + V3 §5 Phase G G2/G4/G5.

**Scope:** Pro bundle `Epistemos-Pro.app` packaged as `Epistemos-Pro.dmg` for Developer-ID distribution outside the App Store. MAS bundle (`Epistemos-AppStore.app`) does NOT go through this path — App Store handles notarization implicitly via App Store Connect submission.

### 9.1 Pre-submission gate (run ALL before invoking notarytool)

```bash
# 1. Code signature verified end-to-end
codesign --verify --strict --deep --verbose=2 Epistemos-Pro.app
# Expected: "valid on disk" + "satisfies its Designated Requirement"

# 2. Hardened Runtime enabled on every Mach-O
codesign --display --verbose=2 Epistemos-Pro.app | grep -E "flags="
# Expected: flags include "runtime" — e.g. "flags=0x10000(runtime)"

# 3. Timestamped (secure timestamp present)
codesign --display --verbose=2 Epistemos-Pro.app | grep -E "Timestamp"
# Expected: "Timestamp=<datetime>" with non-zero datetime

# 4. Pro entitlements verified per V3 §0 criterion 15
#    - WASMExecXPC.entitlements: cs.allow-jit + cs.disable-library-validation (Wasmtime needs both)
#    - Main Pro app: NO cs.disable-library-validation (XPC-scoped only)
#    - Other Pro entitlements per docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md §X.1-X.5
codesign --display --entitlements - Epistemos-Pro.app/Contents/MacOS/Epistemos
codesign --display --entitlements - Epistemos-Pro.app/Contents/XPCServices/WASMExecXPC.xpc

# 5. DMG built deterministically + Pro bundle inside it
hdiutil verify Epistemos-Pro.dmg
ls Epistemos-Pro.dmg.mount/Epistemos-Pro.app  # via mount
```

### 9.2 Submission + audit-trail capture

```bash
# Submit (capture submission ID + status in audit trail)
SUBMIT_JSON=$(xcrun notarytool submit Epistemos-Pro.dmg --wait --output-format json \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$NOTARY_APP_SPECIFIC_PASSWORD")

# Expected response shape (status: "Accepted"):
#   {
#     "id": "ABC123...",
#     "status": "Accepted",
#     "createdDate": "2026-...",
#     ...
#   }

# Capture audit trail (T-A V3 §2 owns docs/release/* per ownership matrix —
# append a new entry to docs/release/notarization-log.md for each submission)
echo "## Submission $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> docs/release/notarization-log.md
echo "" >> docs/release/notarization-log.md
echo "- DMG SHA256: $(shasum -a 256 Epistemos-Pro.dmg | awk '{print $1}')" >> docs/release/notarization-log.md
echo "- Submission ID: $(echo "$SUBMIT_JSON" | jq -r .id)" >> docs/release/notarization-log.md
echo "- Status: $(echo "$SUBMIT_JSON" | jq -r .status)" >> docs/release/notarization-log.md
echo "- Created: $(echo "$SUBMIT_JSON" | jq -r .createdDate)" >> docs/release/notarization-log.md
echo "" >> docs/release/notarization-log.md

# On Invalid status: capture the log
if [ "$(echo "$SUBMIT_JSON" | jq -r .status)" != "Accepted" ]; then
  xcrun notarytool log "$(echo "$SUBMIT_JSON" | jq -r .id)" \
    --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$NOTARY_APP_SPECIFIC_PASSWORD" \
    > "build/notarization-log-$(echo "$SUBMIT_JSON" | jq -r .id).json"
  exit 1  # Stop the release pipeline
fi
```

### 9.3 Stapling + validation

```bash
# Staple the notarization ticket to the DMG (offline-installable)
xcrun stapler staple Epistemos-Pro.dmg
# Expected: "The staple and validate action worked!"

# Validate the staple
xcrun stapler validate Epistemos-Pro.dmg
# Expected: "The validate action worked!" with returncode 0

# Gatekeeper assessment (final ship-readiness check)
spctl --assess --type install --verbose=2 Epistemos-Pro.dmg
# Expected: "accepted" + source "Notarized Developer ID"
```

### 9.4 Failure modes table

| Symptom | Apple error code / message | Recovery |
|---|---|---|
| Invalid signature | `EXEC_HARDENED_RUNTIME` / "cdhash mismatch" | Re-codesign with `--options runtime --timestamp --deep` — both flags required for notarytool acceptance |
| Timestamp missing | `90001` / "the signature did not include a secure timestamp" | Add `--timestamp` to `codesign` invocation; verify network reachable to Apple's timestamp server during sign |
| Hardened Runtime not enabled | `INVALID_RUNTIME` / "flag not set on .../<binary>" | Re-codesign with `--options runtime`; verify with `codesign --display --verbose=2 .../<binary> \| grep flags` shows `runtime` |
| JIT entitlement without justification | rejection note: "entitlement requested without runtime justification" | Document the JIT use per §1 above (MLX shader compilation + MPS only); if a Pro-only binary carries `cs.allow-jit`, gate it through `WASMExecXPC.xpc` only — never the main app binary |
| Subprocess spawn flagged | rejection note: "binary observed spawning subprocess; hardened runtime requires explicit entitlement" | Confirm `agent_core/src/security.rs::harden_cli_subprocess` is wired into every spawn site (10 sites enumerated in CLAUDE.md §Subprocess Hardening); App Store path additionally requires the binary NOT carry the subprocess-spawning code at all (`#if !EPISTEMOS_APP_STORE` compile-time exclusion + link-time post-build scrub per §5) |
| Library validation failure on XPC | `INVALID_LIBRARY_VALIDATION` / "library not signed by same Team ID" | If Wasmtime XPC needs to load third-party Wasm bytecode, carry `cs.disable-library-validation` ONLY on `WASMExecXPC.entitlements` (never on the main Pro app); cross-reference §0 criterion 15 |
| Provisioning profile mismatch | `INVALID_PROVISIONING_PROFILE` / "embedded profile does not match signature" | Re-export the Pro provisioning profile from Apple Developer Portal for the Pro app bundle ID, embed it during `xcodebuild archive`, re-sign |

### 9.5 Cross-references

- **V3 §0 victory criteria 11/12/13:** codesign verify ⇒ notarytool Accepted ⇒ stapler validate. This checklist is the canonical operator procedure for satisfying those three criteria.
- **V3 §5 Phase G G2/G4/G5:** same as above (G2 codesign · G4 notarization · G5 staple+verify).
- **MAS_COMPLETE_FUSION §0 immutable rules 6, 7, 8:** the Pro bundle MUST honor the same hardened-runtime + subprocess-allowlist + egress-allowlist invariants as MAS (rules 7 + 8 apply universally; rule 6 is MAS-only for the WKWebView constraint, but the CLI/subprocess clause from rule 6's A-V6.1.1 sharpening applies to MAS only — Pro CAN carry CLI passthrough behind SovereignGate).
- **`docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` §X.1-X.5:** per-XPC entitlement audit (V3 §0 criterion 15) — must complete BEFORE notarytool submit so any XPC carrying disallowed entitlements is caught at pre-submission gate (§9.1 step 4) not at Apple's notary server.
- **`docs/release/notarization-log.md`:** sibling audit-trail file (T-A V3 §2 owned). Each successful + failed notarytool submission appends one entry. Format defined in §9.2 above. File should be created as needed (no template required — `echo` + `jq` per §9.2 is the spec).

### 9.6 Scope boundary (what this checklist does NOT cover)

- **Apple Developer Program membership active:** assumed true per HELIOS V6.1 / V3 §1 ("Paid Apple Developer Program ACTIVE confirmed 2026-05-16"). If membership lapses, notarytool returns `MEMBERSHIP_INACTIVE` and the whole flow stops — recovery is membership renewal, not a notarization fix.
- **DMG packaging:** delegated to `xcodebuild archive` + `productbuild` / `hdiutil` upstream. This checklist starts AFTER the DMG exists on disk.
- **Distribution channel decision:** V3 §5 Phase G G6 is a separate user-decision item (direct download vs Cloudflare CDN vs Backblaze vs other). Notarization completes before distribution — channel decision is upstream of release timing.
- **Sparkle / Squirrel auto-update:** out-of-scope; Pro V1 is manual DMG download per current Phase G framing.

## 10. Per-XPC Entitlement Audit (T-A iter 18, 2026-05-16 — V3 §0 criterion 15)

This audit is the **release-time validation procedure** for V3 §0 criterion 15 ("Pro entitlements verified for each Hardened Runtime relaxation"). It does NOT define entitlement specs — those are canonical in `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md §2.1-§2.5`. This §10 is the operator's "before notarytool submit, run these greps" checklist.

**Scope:** Pro Developer-ID build. The MAS bundle ships only the main app entitlements (`Epistemos-AppStore.entitlements` per §0 rule 7 — 6 keys); XPC service decomposition (Phase F′) is Pro-only.

### 10.1 Service inventory — 5 Phase F′ XPC services

| Service | Bundle path | Canonical entitlement spec | Plane (per Hermes §5.3) |
|---|---|---|---|
| Main App | `Epistemos-Pro.app/Contents/MacOS/Epistemos` | XPC_MASTERY §2.1 | Plane 0 (orchestrator) |
| VaultXPC | `Epistemos-Pro.app/Contents/XPCServices/VaultXPC.xpc` | XPC_MASTERY §2.2 | Plane 4 (write/forget/admit) |
| AgentXPC | `Epistemos-Pro.app/Contents/XPCServices/AgentXPC.xpc` | XPC_MASTERY §2.3 | Plane 1+2 (state + episodic) |
| ProviderXPC | `Epistemos-Pro.app/Contents/XPCServices/ProviderXPC.xpc` | XPC_MASTERY §2.4 | Plane 4 (network egress) |
| WASMExecXPC | `Epistemos-Pro.app/Contents/XPCServices/WASMExecXPC.xpc` | XPC_MASTERY §2.5 | Plane 4 (sandboxed exec) |

### 10.2 Per-service required-keys validation (release-time greps)

For each `<XPC>.entitlements`, run the following before invoking notarytool (§9.2 pre-submission gate):

```bash
# Helper: dump entitlements for a binary in human-readable form
dump_entitlements() {
  codesign --display --entitlements - --xml "$1" 2>/dev/null | plutil -convert json -o - -
}

PRO="Epistemos-Pro.app"

# 10.2.1 Main App — REQUIRED: app-sandbox=true · application-groups=[group.com.epistemos.shared]
#                            files.user-selected.read-write · files.bookmarks.app-scope
#         DISALLOWED on main: cs.allow-jit · cs.disable-library-validation · cs.allow-unsigned-executable-memory
#                             network.client (network is Provider XPC's job)
dump_entitlements "$PRO/Contents/MacOS/Epistemos" | jq -e '
  ."com.apple.security.app-sandbox" == true and
  (."com.apple.security.application-groups" // []) | contains(["group.com.epistemos.shared"]) and
  (."com.apple.security.cs.allow-jit" // false) == false and
  (."com.apple.security.cs.disable-library-validation" // false) == false and
  (."com.apple.security.network.client" // false) == false
'

# 10.2.2 VaultXPC — REQUIRED: app-sandbox · application-groups · files.bookmarks.app-scope
#         DISALLOWED: cs.allow-jit · network.client · files.user-selected.* (those flow through main app)
dump_entitlements "$PRO/Contents/XPCServices/VaultXPC.xpc/Contents/MacOS/VaultXPC" | jq -e '
  ."com.apple.security.app-sandbox" == true and
  (."com.apple.security.cs.allow-jit" // false) == false and
  (."com.apple.security.network.client" // false) == false
'

# 10.2.3 AgentXPC — REQUIRED: app-sandbox ONLY (pure compute; delegates everything)
#         DISALLOWED: cs.allow-jit · network.client · any filesystem
dump_entitlements "$PRO/Contents/XPCServices/AgentXPC.xpc/Contents/MacOS/AgentXPC" | jq -e '
  ."com.apple.security.app-sandbox" == true and
  (."com.apple.security.cs.allow-jit" // false) == false and
  (."com.apple.security.network.client" // false) == false and
  (."com.apple.security.files.user-selected.read-write" // false) == false
'

# 10.2.4 ProviderXPC — REQUIRED: app-sandbox · network.client (the ONLY XPC with network)
#         DISALLOWED: cs.allow-jit · any filesystem · GPU access
dump_entitlements "$PRO/Contents/XPCServices/ProviderXPC.xpc/Contents/MacOS/ProviderXPC" | jq -e '
  ."com.apple.security.app-sandbox" == true and
  ."com.apple.security.network.client" == true and
  (."com.apple.security.cs.allow-jit" // false) == false
'

# 10.2.5 WASMExecXPC — REQUIRED: app-sandbox · cs.allow-jit (the ONLY XPC with JIT)
#         CONDITIONAL: cs.disable-library-validation — see §10.4 doctrine catch
#         DISALLOWED: network.client · any filesystem (WASI preopens fed in per-execution)
dump_entitlements "$PRO/Contents/XPCServices/WASMExecXPC.xpc/Contents/MacOS/WASMExecXPC" | jq -e '
  ."com.apple.security.app-sandbox" == true and
  ."com.apple.security.cs.allow-jit" == true and
  (."com.apple.security.network.client" // false) == false
'
```

All 5 greps MUST exit 0. Any non-zero exit halts the notarytool pipeline at §9.2.

### 10.3 Cross-XPC invariants (the "no leak" pass)

```bash
# Invariant 1: cs.allow-jit appears in EXACTLY ONE entitlement file (WASMExecXPC).
grep -r "cs.allow-jit\|cs\\.allow-jit" "$PRO" --include="*.entitlements" 2>/dev/null | grep -c WASMExecXPC
# Expected: 1

grep -rE "cs\\.allow-jit" "$PRO" --include="*.entitlements" 2>/dev/null | grep -v WASMExecXPC | wc -l
# Expected: 0 (no other XPC and not the main app)

# Invariant 2: network.client appears in EXACTLY ONE entitlement file (ProviderXPC).
grep -rE "network\\.client" "$PRO" --include="*.entitlements" 2>/dev/null | grep -c ProviderXPC
# Expected: 1

grep -rE "network\\.client" "$PRO" --include="*.entitlements" 2>/dev/null | grep -v ProviderXPC | wc -l
# Expected: 0

# Invariant 3: cs.disable-library-validation appears in AT MOST ONE entitlement file (WASMExecXPC, conditional — see §10.4).
grep -rE "cs\\.disable-library-validation" "$PRO" --include="*.entitlements" 2>/dev/null | grep -v WASMExecXPC | wc -l
# Expected: 0 (anywhere else is a hard fail)
```

Any invariant violation halts the pipeline + requires entitlement-file fix before resubmit.

### 10.4 §5.0 doctrine-disagreement catch on WASMExecXPC + `cs.disable-library-validation`

**Two doctrine sources disagree on whether `WASMExecXPC.entitlements` requires `cs.disable-library-validation` in addition to `cs.allow-jit`:**

- **V3 §0 victory criterion 15** (in `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md`) states:
  > `WASMExecXPC.entitlements`: `cs.allow-jit + cs.disable-library-validation` (Wasmtime needs both)
- **`docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md §2.5`** shows only:
  ```xml
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
  ```
  with NO `cs.disable-library-validation` key. The §2.5 commentary on JIT does not mention library validation.

**Reconciliation required (decision-required-from-user):** which doctrine source is canonical?

- **Option A: V3 §0 criterion 15 is correct** — Wasmtime in fact needs both `cs.allow-jit` AND `cs.disable-library-validation` to load its third-party `*.cwasm` bytecode caches; XPC_MASTERY §2.5 is incomplete and needs updating to add the key (with rationale subsection explaining the library-validation relaxation is XPC-scoped, not main-app scoped). MAS_APP_REVIEW_NOTES §1 (which references §0 rule 7) should also cross-link.
- **Option B: XPC_MASTERY §2.5 is correct** — `cs.allow-jit` alone is sufficient for Wasmtime's JIT codegen (the `*.cwasm` cache loads run inside the same-signed XPC binary, so library validation is not relaxed); V3 §0 criterion 15's "+ cs.disable-library-validation" is over-specified and needs amending.

**Verification needed:** consult Wasmtime upstream docs (`https://docs.wasmtime.dev/`) on Hardened Runtime entitlement requirements for macOS code-signing. The current Wasmtime version used in `Cargo.toml` is the ground truth — if it loads JIT-compiled code from non-signed memory regions, `cs.allow-jit` alone is sufficient (page-level JIT relaxation); if it dynamically loads `.cwasm` files signed by a different Team ID (e.g. from user-installed plugins), `cs.disable-library-validation` is also required.

**Decision required from user:** {Option A — add `cs.disable-library-validation` to WASMExecXPC + update XPC_MASTERY §2.5} OR {Option B — drop `cs.disable-library-validation` requirement from V3 §0 criterion 15 + clarify}. Either way, ONE doctrine source must change to reconcile.

**This catch surfaces here in §10.4 because:** T-A V3 §2 owns `docs/release/MAS_APP_REVIEW_NOTES.md` + does NOT own `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md` (user-owned per loop-prompt evolution pattern) NOR `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` (shared per V3 §2 — both terminals may update sections, but the entitlement specs at §2.1-§2.5 are the canonical authority that doctrine-edits should consult Wasmtime upstream before changing). Audit surfaces the disagreement so user can pick the reconciliation direction.

### 10.5 Cross-references

- **V3 §0 victory criterion 15:** the doctrine target this audit satisfies.
- **`docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md §2.1-§2.5`:** canonical entitlement spec source. THIS audit is the validation procedure; specs come from there.
- **§9 above:** Pro Notarization Checklist — §10's audit is one of the §9.1 pre-submission gate validations (specifically step 4 "Pro entitlements verified per V3 §0 criterion 15").
- **MAS_COMPLETE_FUSION §0 immutable rules 6/7/8:** rule 7's JIT defense covers the MAS side (JIT NEVER in MAS); rule 8's per-Live-File egress allowlist composes with §10.2.4 ProviderXPC network gating.
- **`docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md §3` Trust attestation:** every XPC service verifies caller code signature before honoring messages — composes with §10's entitlement audit (entitlements are the static surface; trust attestation is the dynamic gate).

---

Contact for App Review questions: (developer email).
