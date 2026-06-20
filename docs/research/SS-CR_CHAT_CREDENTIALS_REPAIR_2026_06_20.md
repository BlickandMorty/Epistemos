# SS-CR — CRITICAL chat repair: "credentials rejected" on local + cloud (2026-06-20)

Owner: *"it said credentials were rejected whenever I try to send a query to any local model, most of them say that; I
think the only one that works is the Qwen, even that may be broken. cloud models too. something fundamentally wrong with
the chat — it needs deep repair before any more additional building on it."* **#1 PRIORITY — blocks the core app.**
Code-grounded root + fix. NON-INVASIVE to scope-boundary domains.

## Root cause
A LOCAL pick is being MIS-ROUTED into the CLOUD branch, then fails the cloud credential gate (the local MLX/GGUF path is
credential-free: `TriageService.localStreamOrFallback:2275`, `Bridge/LocalGgufRuntimeBridge.swift` has zero auth). Routing
authority = `InferenceState.effectiveChatSurfaceSelection(for:)` (`State/InferenceState.swift:4704`). Three triggers:
1. **(most likely live) Pending-unavailable-cloud override:** `setPreferredChatModelSelection` (`:5812-5816`) — picking a
   cloud model without cloud access pins `.localMLX` BUT sets `pendingUnavailableCloudSelection`; then
   `effectiveChatSurfaceSelection:4705` returns `pendingUnavailableCloudIntentSelection` (`:5843`) = `.cloud(model)` FIRST,
   overriding the local pin → every turn routes to a cloud model with no access → 401/missingOAuthSession → "credentials
   rejected", persisting across turns until cleared.
2. **Auto-cloud when local tier model not installed:** `:4736-4765` returns `.cloud(autoModel)` when
   `effectiveLocalTextModelID(for:)==nil && !appleIntelligenceAvailable`.
3. **Foundation-tier nil-resolve:** `effectiveLocalTextModelID(for:)` (`:4280-4283`) returns nil for a tier whose specific
   model isn't installed (Think→VibeThinker, Code→coder, non-default Fast Gemma) → feeds 1/2.
**CLOUD also fails (Keychain bootstrap RACE):** `initializeDeferredCloudCredentialState` (`:3598-3600`) seeds ALL providers
as "missing"; the real Keychain read is async (`startDeferredCloudCredentialBootstrap:3609`, lands in `applyCloudCredentialSnapshot
:3630`); `apiKey(for:)` (`:5214`) returns nil while `missingCloudAPIKeyProviders.contains(provider)` → a send BEFORE the
snapshot lands throws `missingOAuthSession` even with a valid key in Keychain. (Genuine wrong/expired key = real 401 at
`LLMService.swift:585`; header construction is correct — `x-api-key`/`Bearer`.)
**Why Qwen works:** Qwen3-4B is the installed default → `effectiveLocalTextModelID` resolves non-nil via the unified-picker
branch (`:4286-4297`) → stays `.localMLX` → never enters the cloud branch.
Error surfaces: `PipelineService.swift:73,98` (classify→"provider rejected your credentials"), underlying
`LLMService.swift:585-586` (401) or `CloudProviderAuthService.swift:340` (missingOAuthSession). (The XPC `MockProviderServiceStreaming`
`kc:` check is SCAFFOLD-only, not live — ignore.)

## FIX
**LOCAL must NEVER silently route to cloud:**
1. `InferenceState.swift:4705` — do NOT let `pendingUnavailableCloudIntentSelection` override a runnable local pick. Treat
   `pendingUnavailableCloudSelection` as UI-ONLY (a "reconnect to use X" badge), keep the local pin authoritative for
   EXECUTION (`setPreferredChatModelSelection:5812`).
2. `:4736-4765` — auto-cloud escalation must require `hasConfiguredCloudAccess(for: autoModel.provider)` AND never fire while
   a local model / Apple Intelligence can serve; else prefer Apple Intelligence or surface `modelNotReady`, never `.cloud`.
3. `:4280-4283` — a foundation tier whose own model isn't installed should return a RUNNABLE local id (installed Qwen/AI
   baseline) or `.appleIntelligence`, not `nil`, so the surface degrades to a working local model.
**CLOUD must read the Keychain key (kill the race):**
4. `apiKey(for:)` (`:5214-5222`) — when `isBootstrappingCloudCredentials` (snapshot not landed), do a direct synchronous
   `keychainLoad(provider.apiKeyKeychainKey)` instead of trusting the all-"missing" seed (gate the
   `missingCloudAPIKeyProviders.contains` early-return on `!isBootstrappingCloudCredentials`, else fall through to the live
   Keychain read). First send after launch then reads the real key.
Genuine 401s stay honestly surfaced (`LLMService.swift:585`) — no change there; the fix is (a) local never lands in cloud,
(b) the key is actually fetched.

## Tests (behavior, not substring)
- Falsifier: a LOCAL pick (any tier, installed or not) NEVER resolves to `.cloud` in `effectiveChatSurfaceSelection` (incl.
  with a `pendingUnavailableCloudSelection` set) → routes local/AppleIntelligence.
- Cloud: with a key in Keychain but `isBootstrappingCloudCredentials==true`, `apiKey(for:)` returns the key (race fixed).
- Foundation-tier-not-installed → returns a runnable local id, not nil.
Key file: `State/InferenceState.swift` (routing 4704-4816, local-resolve 4189-4298, credential bootstrap/read 3598-3702,
5210-5248, pending-cloud 5803-5832). Cross-ref PipelineService/LLMService/CloudProviderAuthService/TriageService. **Do this
BEFORE any further chat work** (owner directive).
