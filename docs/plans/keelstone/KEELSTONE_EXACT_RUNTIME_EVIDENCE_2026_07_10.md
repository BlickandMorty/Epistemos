# KEELSTONE Exact Runtime Evidence — 2026-07-10

Current canonical execution key:
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.

Current final verdict: **INCOMPLETE**.

The original 2026-07-10 pass stopped at its mandatory resource preflight. The
owner authorized exact continuation after a forced restart on 2026-07-12, then
dated a controlling free-V1 product boundary on 2026-07-13: June, generative
AI, models, Browser, and ResearchHub are paid-only and hidden/inert; Kokoro and
the deterministic local capability ring remain free. The latest continuation
now has a passing focused Red14 discriminator and passing twenty-five-test
current-source regression. The older Release archive was removed after later
source work and is not current evidence; app/archive inventory is zero while a
new archive preflight is prepared. The owner-visible runtime matrix has not
resumed. No model load, provider request, Keychain-secret read, owner-vault
operation, or audio operation was performed.

## Owner Intent Checkpoint

Verbatim owner steer excerpt:

> Determine whether the current source can satisfy the remaining KEELSTONE
> evidence bar through one serial, resource-capped build/archive/runtime chain.

> Stop immediately if memory pressure or swap becomes unsafe.

Interpreted intent:

- Remain exclusively in
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- Establish current-source compilation, create exactly one fresh
  `Epistemos-AppStore` Release archive, prove its MAS artifact truth, and only
  then run the finite owner-visible runtime matrix.
- Treat the resource preflight as a hard safety gate. Near-exhausted swap means
  no Xcode or runtime workload may begin.

Hard constraints:

- Preserve the dirty `feat/goose-surface` worktree.
- No reset, revert, discard, staging, commit, broad formatting, or unrelated
  regeneration.
- No parallel builds, concurrent archives, or concurrent model loads.
- No app launch while an artifact gate is red or absent.
- No secret inspection or mutation.
- No implementation phase transition.

Non-goals:

- No June/MiniChat expansion.
- No LumenLens, Reckoner, Sync, ResearchHub, Quick Capture, or Capability Ring
  work.
- No broad source audit, optional micro-hardening, or older numbered-corpus
  execution authority.

Acceptance checks:

- A fresh current-source archive must exist and pass all artifact gates before
  any runtime launch.
- Runtime behavior must be paired with matching logs.
- The chain must stop immediately when memory pressure or swap is unsafe.

Next action applied in this pass:

- Capture branch, HEAD, dirty count, toolchain, disk, memory, swap, and
  competing-process state before verification.
- Stop the chain because swap was unsafe.

## Repository Baseline

Captured before verification:

| Field | Evidence |
| --- | --- |
| Branch | `feat/goose-surface` |
| HEAD | `0c7123ba442c959b23b87528d3fdff1560320498` |
| Dirty-state count | 546 entries from `git status --porcelain=v1 -uall` |
| Xcode | 26.4.1, build 17E202 |
| macOS SDK | 26.4 |
| Available workspace disk | 110 GiB |
| Competing Xcode/compiler/model/app processes | None found; only the preflight shell and its `rg` process matched the diagnostic pattern |

Exact identity command:

```bash
branch=$(git branch --show-current)
head=$(git rev-parse HEAD)
dirty=$(git status --porcelain=v1 -uall | wc -l | tr -d ' ')
printf 'BRANCH=%s\nHEAD=%s\nDIRTY_COUNT=%s\n' "$branch" "$head" "$dirty"
```

Result:

```text
BRANCH=feat/goose-surface
HEAD=0c7123ba442c959b23b87528d3fdff1560320498
DIRTY_COUNT=546
```

Toolchain commands:

```bash
xcodebuild -version
xcrun --sdk macosx --show-sdk-version
```

Result:

```text
Xcode 26.4.1
Build version 17E202
26.4
```

## Resource Preflight And Stop Trigger

Commands:

```bash
sysctl vm.swapusage
memory_pressure -Q
vm_stat
ps -axo pid=,rss=,command= | \
  rg -i 'xcodebuild|swift-frontend|swiftc|clang|llama|Epistemos\.app/Contents/MacOS/Epistemos'
df -h . build
```

Swap result:

```text
vm.swapusage: total = 23552.00M  used = 22392.56M  free = 1159.44M  (encrypted)
```

Memory-pressure result:

```text
The system has 17179869184 bytes of physical memory.
System-wide memory free percentage: 40%
```

Relevant VM state:

```text
Pages throttled: 0
Pages stored in compressor: 2610411
Pages occupied by compressor: 405141
Swapins: 264962271
Swapouts: 302770084
```

Safety interpretation:

- Instantaneous free memory was not itself critical.
- Swap was 95.1% occupied, with only about 1.13 GiB free.
- The owner explicitly required an immediate stop when swap became unsafe and
  previously reported an approximately 25 GB RAM event.
- Starting Xcode compilation/archive work under this state would violate the
  resource cap and risk additional compression, swap churn, and system impact.

Stop action:

- No focused Xcode test began.
- No build or archive began.
- No source or implementation file changed.
- No stale or exact app was launched.
- No GGUF or Core ML model loaded.
- No OpenAI/Anthropic request or Keychain access occurred.
- No audio operation occurred.

## Focused Tests

Status: **NOT RUN — RESOURCE STOP**.

The intended narrow serial invocation was not started because the resource
preflight failed before compilation. No test result bundle was created by this
pass.

Prior source-only evidence in the owner-steer handoff remains historical input,
not current execution proof:

- targeted Swift parsing passed;
- the source-only KEELSTONE gate reported 827 PASS lines;
- those checks do not prove current Xcode compilation or runtime behavior.

## Fresh Release Archive

Status: **NOT CREATED — RESOURCE STOP**.

Exact archive path: **NONE**.

No Release build or archive command was started. Therefore there is no current
artifact against which to make packaging, signing, entitlement, privacy,
quarantine, parked-lane, GGUF-linkage, or JuneWeb claims.

## Artifact Gates

Status: **NOT RUN — NO FRESH ARCHIVE**.

Untested artifact requirements:

- KEELSTONE built-app gate;
- App Store bundle scan;
- effective entitlement inspection;
- privacy-manifest inspection and source/bundle comparison;
- quarantine scan;
- parked-lane string/resource/symbol scan;
- strict deep signature verification;
- embedded `llama.framework` presence;
- app-executable load command for `llama.framework/Versions/A/llama`;
- current JuneWeb `dist/index.html` and shim presence;
- current JuneWeb identity, model, consent, and literal-send copy.

Because these gates did not run, application launch was forbidden by the owner
authorization and did not occur.

## Finite Runtime Matrix

Status: **NOT RUN — ARTIFACT PRECONDITION NOT MET**.

Every runtime item remains untested in this pass:

1. Normal product identity as MAS/June.
2. Owner-vault select, edit/save, quit, relaunch, restore, and second edit/save.
3. Absence of `no vault URL`, truncation, silent loss, and false restore warning.
4. Epdoc → Source → Prose → Epdoc rich-Markdown fidelity, including tables,
   lists, links, blockquotes, formatting, and intentionally empty content.
5. Input/save behavior in Epdoc, Prose, Source/Code, Quick Capture, embedded
   graph, and hologram graph.
6. Open/input/save responsiveness and graph-node routing into writable editors.
7. One Qwen3 4B June turn, selected-model routing, streaming,
   cancellation/teardown, and truthful failure behavior.
8. Existing configured/consented OpenAI or Anthropic behavior, or the precise
   visible configuration/consent blocker.
9. Literal June prompt preservation and absence of Hermes/Prompt Forge rewrite.
10. English Kokoro preview, read-aloud surface checks, and owner audible-language
    confirmation when logs alone cannot establish language.

No runtime logs were created because launching the app was prohibited after the
resource stop.

## Failures And Surgical Corrections

Failure:

- The resource preflight failed the swap-safety condition before the first
  focused test.

Source cause:

- Not investigated. The unsafe state is system-wide resource pressure, not a
  demonstrated Epistemos source or artifact failure.

Surgical correction:

- None. Making a product-source change would not correct system swap occupancy
  and would violate the evidence-only/source-freeze boundary.

## Historical Resumption Boundary — 2026-07-10

This evidence chain may be restarted only from the resource preflight after
system swap has returned to a safe level. Do not reuse this pass as compilation
or artifact proof.

On a safe system, the next sequence remains:

1. Re-record branch, HEAD, dirty count, memory, swap, disk, and competing
   processes.
2. Run only the narrow current-source compile/regression batch serially.
3. Produce exactly one fresh `Epistemos-AppStore` Release archive.
4. Run every artifact gate against that exact archive.
5. Launch only if every artifact gate passes.
6. Run the finite runtime matrix serially with correlated logs.
7. Update this evidence document with the exact commands, paths, results, and
   one allowed verdict.

## Post-Reset Continuation Evidence — 2026-07-12

Owner authorization resumed only canonical Prompt 2 under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. The external July 8 master
canon and its numbered `03_MINIMAL_PROMPT_PACK.md` remain prompt authority.

### Current identity and resource gate

- Branch: `feat/goose-surface`.
- Pre-continuation HEAD: `a69f5bfc417db95d7c552a6e913d6294da4700c6`.
- `origin/feat/goose-surface` and live GitHub:
  `f73b3244c09a76a14961050964969bcb5ac9fa70`.
- GitHub CLI remains unauthenticated; publication is not claimed.
- Final exact-test preflight: 699.44 MiB swap used of 2 GiB, 73% free memory,
  zero throttled pages, and no competing build/compiler/model/app process.
  This passed the owner's below-4-GiB, at-least-25%, zero-throttling, serial
  threshold.

### June recovery and stage identity

- Recovered donor: `/Users/jojo/dev/june-epistemos`, branch
  `codex/recover-june-exact-2026-07-12`, public base
  `2f84f3e4fa19fded5135aa044ff5accf9fbd3809`, with the 93-file reconstructed
  private overlay retained as uncommitted donor state.
- The reconstruction replays the durable Codex patch record. It is current
  reconstruction evidence, not a claim that the old generated dependency tree
  was reproduced byte-for-byte.
- Current checked-in candidate stage contains 28 files. Hashes:
  - `dist/index.html`: `822fd4be182eca74eedbf73cae1a6c4a7ff169960069c3bc778082fffb9a6bad`
  - `dist/assets/main-CBFgaVJI.js`:
    `518eef05376dd0a6ad3537cede4647d155c8bc7cfd9088d1a2ef77387d96a7fd`
  - `tauri-internals-shim.js`:
    `7440986d70a044689fea50f8a181441dfc05c5b8736421691db8b2980979e77a`
- The shim matches the reviewed historical oracle exactly. The current
  index/main hashes do not match the older reviewed oracles, so this stage is
  explicitly new evidence and not substituted historical proof.

### Narrow compile and regression result

The first restored build exposed only current Swift/Xcode compatibility
failures. Surgical compile corrections were made in the affected provider
switch returns, conditional SwiftUI builders, actor-isolation annotations,
termination callback, and nonisolated receipt/signal types, with matching
source-guard updates. A later test run exposed one real early-Document-edit
flush regression, one missing release-gate bundle-scan wrapper, and stale
source assertions; those exact failed legs were corrected without reopening
general product work.

The owner then added a durable one-current-build rule. Before every subsequent
test build, every prior DerivedData `Epistemos.app` and Epistemos archive was
inventoried and deleted. Xcode GUI/indexer duplicates were removed. The final
exact-state command was:

```bash
xcodebuild -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO test
```

Result: **PASS — 71 tests in 2 suites, zero failures**. The temporary console
log did not survive the later restart. The exact final Xcode result bundle was
recovered from DerivedData, copied out of disposable build storage, archived,
and checksum-verified at:

`/Users/jojo/Downloads/Epistemos-Aftercare-Local-2026-07-12/keelstone-evidence-32d5d264e/Test-Epistemos-AppStore-2026.07.12_19-38-56--0500.xcresult.zip`

Its independently extracted `xcresulttool` summary reports `Passed`, 71 total,
71 passed, zero failed, zero skipped, and zero expected failures on arm64
macOS 26.3.1.

The only surviving app product is:

`/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Build/Products/Debug/Epistemos.app`

- Size: 772,032 KiB.
- Executable SHA-256:
  `55991dc381bf8b5b0cfb360c3c0c052f73472ba79523a2e21c7c59494804318f`.
- Bundled June shim SHA-256:
  `7440986d70a044689fea50f8a181441dfc05c5b8736421691db8b2980979e77a`.

This is an unsigned Debug test product containing XCTest support. It proves
compilation and the focused regression target only; it is not a distributable
Release archive or owner-visible runtime artifact. Xcode's test host did start
the executable to run the isolated tests, including temporary test-vault
fixtures. No owner vault was selected or mutated.

### Source gate and archive stop

`bash scripts/keelstone-release-gate.sh` passed 49 source/staged-June checks;
shell parsing passed for both release-gate scripts. The temporary log did not
survive the later restart, so the source-only gate was rerun without any Xcode
build, archive, app launch, model/provider/secret/vault/audio operation. Its
durable checksum-verified log is:

`/Users/jojo/Downloads/Epistemos-Aftercare-Local-2026-07-12/keelstone-evidence-32d5d264e/KEELSTONE_SOURCE_GATE_2026-07-12.log`

The Release archive leg did not begin because:

- `security find-identity -v -p codesigning` reports zero valid identities;
- `~/Library/MobileDevice/Provisioning Profiles` is absent;
- the project requests team `3BNL2669SL` and automatic Apple signing.

Therefore no fresh Release archive exists, no archive artifact gate ran, and
launching the app for the finite owner-visible runtime matrix remains
forbidden. The exact next action requires the owner to connect the Apple
Developer/Xcode account and signing assets. After that, rerun the resource
preflight, delete the surviving Debug app and any stale archives, produce one
and only one signed Release archive, run every artifact gate against that
archive, and launch only if they all pass. Do not begin Prompt 3.

## Free V1 Continuation Evidence — 2026-07-13

This dated continuation supersedes the stale statement that Apple enrollment,
payment, or distribution signing is required before free-V1 source, archive,
or local runtime evidence can proceed. It does not represent the resulting
archive as App Store submission-ready.

### Controlling owner steer

Verbatim excerpts:

> the v1 free versjon will have no ai at all.

> browser, research hub both are needing to be on paid version as well an
> hidden from v1 releawe

> movig forward there must be oe build whever testung u must delte the stale
> builds before building an ew app

Applied product boundary:

- Free V1 keeps KEELSTONE, Epdoc/LUMENLENS deterministic planner work,
  RECKONER, Meeting, Sync, Quick Capture, calendar/tasks, PDF/import, Kokoro,
  graph/search, and portable workspace/export capabilities.
- June, Epdoc Assist, model/provider/generative/agent actions, Browser, and
  ResearchHub are future paid capabilities and are hidden and inert in free V1.
- Payment, StoreKit, Apple enrollment, and distribution signing remain
  deferred. They do not block free-V1 source or local ad-hoc evidence.
- The one-current-build rule remains mandatory before every build, test build,
  or archive.

### Current repository and resource identity

- Branch: `feat/goose-surface`.
- HEAD during the evidence leg:
  `5e0a335d3cc2de87d89ec91698a3077036d693a7`.
- Dirty entries before the final runtime preflight: 56.
- Final runtime preflight: 457.75 MiB swap used of 1 GiB, 72% free memory,
  zero throttled pages, about 750 GiB free disk, and no competing Xcode,
  compiler, model, or Epistemos process.
- The branch/worktree remained intentionally dirty with the scoped free-V1
  implementation and canon/handoff work. Nothing was reset or overwritten.

### Free V1 implementation and focused regression

The current target now declares `EPISTEMOS_PRODUCT_EDITION=FREE_V1` and the
`EPISTEMOS_FREE_V1` compilation condition. A centralized
`ProductCapabilityPolicy` classifies the paid and free surfaces. Paid routes,
shortcuts, startup work, provider state, App Intents, June, Browser,
ResearchHub/arXiv, and generative note actions fail closed. Kokoro and the
deterministic free capability ring remain available. Free packaging removes
`JuneWeb`, `model_manifest.json`, and `DefaultSkills`.

Exact focused result bundle:

`/tmp/Epistemos-FreeV1-Policy.xcresult`

`xcresulttool` summary: **Passed — 8 total, 8 passed, zero failed, zero
skipped, zero expected failures**, arm64 macOS 26.3.1. The startup log now
reports `Free V1 model boundary: June=DISABLED, local-gguf-runtime=DISABLED,
cloud-models=OFF`.

The edition-aware source gate also passed. It validates the centralized policy,
free build setting/condition, paid-web build skip, free resource omissions,
and the existing MAS architecture boundaries.

### Exactly one fresh Release archive

Before the evidence build, the prior test host and all stale Epistemos app and
archive products were removed. A first signing-enabled archive attempt stopped
before compilation because the requested Apple provisioning profile is absent;
it produced no app or archive. After a fresh resource preflight and without a
competing build, this exact local-evidence command succeeded:

```bash
./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-FreeV1-Archive \
  -archivePath /Users/jojo/Downloads/Epistemos/build/archives/Epistemos-FreeV1-current.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Result: `** ARCHIVE SUCCEEDED **`.

Retained archive and app:

- Archive:
  `/Users/jojo/Downloads/Epistemos/build/archives/Epistemos-FreeV1-current.xcarchive`
- App:
  `/Users/jojo/Downloads/Epistemos/build/archives/Epistemos-FreeV1-current.xcarchive/Products/Applications/Epistemos.app`
- Bundle: `com.epistemos.appstore`, version `1.0.0`, build `1`.
- Executable: universal `x86_64` + `arm64`.
- Executable SHA-256 after local signing:
  `3e4273c9cdfe7ed3f3deca7883f9d05020fd92fc3d95ec986ba18cd6f6513f5b`.
- App size: 234,456 KiB. Archive size: 647,928 KiB.
- Final inventory: exactly one Epistemos app and exactly one Epistemos
  xcarchive; no DerivedData app product remains.

The app and its nested dylibs/framework were signed locally with ad-hoc
identity `-` for evidence only. Strict deep verification passed. Effective
entitlements include `com.apple.security.app-sandbox=true`; app CDHash is
`2fd8aab90e02e5534892ed4f616e526a4ed531b1`. `TeamIdentifier` is absent, so
this is not Apple distribution signing and cannot prove submission readiness.

### Exact artifact gates

Command:

```bash
bash scripts/keelstone-release-gate.sh \
  --appstore-app /Users/jojo/Downloads/Epistemos/build/archives/Epistemos-FreeV1-current.xcarchive/Products/Applications/Epistemos.app
```

Result: **PASS**. The exact archive app:

- has the App Sandbox entitlement;
- omits `JuneWeb`, `model_manifest.json`, and `DefaultSkills`;
- has no quarantine attributes;
- has no prohibited parked account/backend, retired-lane, 1Code, research/tool
  resource, or prohibited runtime-string/linkage finding;
- passes the comprehensive App Store bundle scanner.

The archive still links dormant shared implementation libraries including
`libagent_core.dylib`, `libomega_mcp.dylib`, and `llama.framework`. No model,
June web app, agent skills, route, shortcut, startup, provider, or generative
capability is active in the free edition, and the scanner found no prohibited
runtime symbol. Removing paid-only native libraries from the free target is
separate size/build-topology debt; deleting them from the finished bundle is
unsafe because the executable currently links them.

### Finite free-V1 runtime matrix and stop boundary

The later owner steer removes the old Qwen/provider/June items from the current
free-V1 matrix. The remaining finite matrix is:

1. Normal product identity as Epistemos free V1.
2. June, models/providers/generative actions, Browser, and ResearchHub absent
   from navigation, settings, shortcuts, restoration, and background startup.
3. Disposable-vault select, edit/save, quit/relaunch/restore, and second save.
4. Epdoc rich-Markdown fidelity across Epdoc, Source, and Prose.
5. Deterministic Meeting, Quick Capture, task/planner, Sync-status,
   calendar-permission, PDF/import, and export entry points.
6. Writable/responsive graph-to-editor and search/source routing.
7. English Kokoro preview/read-aloud with correlated local logs and no agent or
   provider startup.
8. Correlated logs contain no paid-route restoration, provider request, model
   load, `no vault URL`, silent loss, or false success.

The exact app was not launched. Computer-use returned: `The Mac is locked and
automatic unlock could not unlock it.` A process scan found no Epistemos
process, and the correlated unified-log query found no Epistemos runtime line.
Therefore no vault, model, provider, Keychain, network, microphone, or audio
operation began. Bypassing the lock would not provide owner-visible evidence.

Exact next action:

1. Unlock the Mac manually; do not change the owner's five-minute lock setting.
2. Re-run the resource preflight and stop if any owner threshold is red.
3. Re-run the exact artifact gate if the archive bytes changed; otherwise keep
   this sole archive immutable.
4. Launch the exact archive app and run only the finite free-V1 runtime matrix
   serially with correlated logs and a disposable vault.
5. Update this document and stop after the KEELSTONE verdict. Do not start a
   new canonical execution key or paid/payment work.

## Final KEELSTONE Verdict

**INCOMPLETE**

Reason: the focused free-V1 regression and exact Release archive artifact gate
now pass, but the owner-visible free-V1 runtime matrix is blocked at the locked
Mac boundary. Apple distribution signing/payment is intentionally deferred and
is separately unproven. No claim of App Store submission readiness, audible
Kokoro behavior, vault persistence, Epdoc fidelity, or paid-feature runtime
absence beyond the proven source/artifact boundaries is made.

No recommendation to begin another canonical execution key is made.

## Editor Transaction Continuation Evidence — 2026-07-13

This section supersedes the prior exact-next-action statement. It remains part
of the same canonical execution key:
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.

### Scope and owner boundary

The owner directed the task to continue “as if we never stopped” and kept the
below-8-GiB swap ceiling. Work resumed at the already-red editor identity/body
transaction contracts. No canon feature work, payment/account work, model or
provider operation, owner-vault mutation, app launch, archive, signing, audio,
or new execution key began.

Current repository identity remained:

- Branch: `feat/goose-surface`.
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`.
- The owner worktree remained intentionally dirty; no reset or overwrite was
  performed.

### Red and interrupted evidence retained

- `build/xcode-results/2026-07-13-identity-atomicity-red-8gib.xcresult`
  selected zero tests because the initial Swift Testing selectors omitted the
  required trailing parentheses. It is invalid as behavioral evidence.
- The corrected selector run at
  `build/xcode-results/2026-07-13-identity-atomicity-red-8gib-selectors.xcresult`
  executed eight tests: four passed and four failed. This is the valid initial
  red leg.
- The first post-correction build at
  `build/xcode-results/2026-07-13-identity-atomicity-green1-8gib.xcresult`
  stopped before tests with one compile error: SDK 26.5 has no typed
  `URLResourceValues.volumeURL` member. The same official resource key is
  supported through `allValues`; only that compatibility seam changed.
- The next build at
  `build/xcode-results/2026-07-13-identity-atomicity-green2-8gib.xcresult`
  compiled and launched the selected tests. Its readable interrupted bundle
  records three started tests: one passed, the rollback test failed two
  expectations because its fixture lacked a known synced-body baseline, and
  the dirty-save test was cancelled. The cancellation was deliberate after a
  real unbounded retry produced `Saved 0 of 1 dirty pages to vault` repeatedly.
  The result-bundle writer later returned exit 73 because the interrupted test
  log did not close within 30 seconds; this bundle is failure evidence, not a
  valid completed pass.

### Surgical corrections proved by the current batch

The current source now:

- uses exact whole-file baselines for coordinated replacement, move, and
  removal and refuses occupied/mismatched paths;
- preserves replacement metadata and synchronizes affected directories;
- rejects cross-volume CAS moves rather than silently degrading to
  copy-and-delete semantics;
- keeps note-body, front matter, filename, folder identity, sidecar, SwiftData
  metadata, derived search state, and rollback in one serialized per-page
  transaction;
- preserves newer live/pending/inline drafts and external edits instead of
  publishing uncertain success;
- uses one full SHA-256 body fingerprint for both small and large files;
- skips Markdown title/reference behavior for raw source files and refreshes
  their exact sidecar hash;
- clears a pending body only when it exactly matches the successful or stale
  export that owned it. A different newer pending body remains. This makes a
  stale dirty save retry the newer body once instead of selecting its obsolete
  staged body forever;
- treats a returned body-hash mismatch as a failed evidence leg rather than an
  immediate unbounded stale retry.

### Resource preflights and exact green evidence

Every build remained serial and used a freshly cleared disposable location.
The failed prior app product was deleted before each later build; result
bundles were retained as evidence.

- Green1 preflight: 4,861.38 MiB swap used, 75% free memory, zero throttled
  pages, 741 GiB available disk, and no competing active build/compiler/model/
  Epistemos runtime.
- Green2 preflight: 4,976.44 MiB swap used, 61% free memory, zero throttled
  pages, 741 GiB available disk, and no competing active job. Long-idle macOS
  Metal compiler services were sleeping at 0% CPU and were not active work.
- Green3 preflight: 6,206.38 MiB swap used, 71% free memory, zero throttled
  pages, 739 GiB available disk, and no competing active job.

All three passed the owner threshold: swap below 8 GiB, free memory at least
25%, throttled pages zero, and no competing Xcode/compiler/model/Epistemos
runtime.

Exact completed command scope: the 14 selected App Store Keelstone identity,
body-save, CAS, external-conflict, raw-source, and sidecar regressions.

Result bundle:

`build/xcode-results/2026-07-13-identity-atomicity-green3-8gib.xcresult`

Direct `xcresulttool` summary:

- Executed: 14.
- Passed: 14.
- Failed: 0.
- Skipped: 0.

The stale-save regression itself logged one zero-save stale pass followed by
one successful pass, then terminated. The suite completed in 0.674 seconds.

Current artifact inventory contains exactly one app and no archive:

- App:
  `/private/tmp/Epistemos-IdentityAtomicityGreen3-8GiB/Build/Products/Debug/Epistemos.app`
- Executable SHA-256:
  `2ddda5f91b6f8758dc601f80dff3689c33f7d188d20c1343c8917357a1c24d28`

This is an unsigned Debug test product. It is current compile/test-host
evidence only and is not a Release, artifact-gate, distribution, manual
interaction, or owner-visible runtime artifact.

### Remaining verification debt and exact resumption boundary

The narrow core is green, but KEELSTONE remains incomplete. Current source
still has legacy page move/rename/delete/create and directory mutation entry
points outside the same lifecycle admission. Stop/switch can release a
security-scoped vault while admitted identity/body/dirty/import/FSEvent work is
still suspended. A process killed between file write, move, sidecar, metadata,
and rollback still has no durable phase journal.

The next evidence chain is therefore:

1. Add failing lifecycle-admission and stop/switch-drain tests.
2. Implement the smallest epoch/drain barrier and deterministic lock order,
   using private unlocked helpers so nested public calls cannot deadlock.
3. Add the durable identity phase journal and deterministic watch-start
   reconciliation tests for forward, rollback, sidecar, metadata, unknown-byte,
   and repeated-recovery states.
4. Add the remaining three-save, BOM/CRLF/metadata, new-file provisional-path,
   metadata-save-after-move, vault-switch-during-suspension, and large-file
   repeat regressions.
5. Before the next build, delete the current Green3 app product, rerun the full
   owner resource preflight, and produce exactly one fresh test artifact.
6. Only after editor/lifecycle/crash-recovery closeout continue the app-wide
   performance/Free-V1 audit. Canon synchronization and feature work remain
   later.

## Updated KEELSTONE Verdict — 2026-07-13

**INCOMPLETE**

Reason: 14 exact editor transaction regressions now pass, but lifecycle drain,
force-quit journal recovery, broader editor/manual runtime behavior, Free-V1
compile topology, current Release artifact gates, and the finite runtime matrix
remain unproven. No recommendation to start another canonical execution key is
made.

## Vault Lifecycle Admission Evidence — 2026-07-13

This continuation remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It began at the exact next
action above and did not start canon features, payment/account work, a model or
provider, an archive, or another execution key.

### Exact red proof

The first new regression suspended a body export against vault A, replaced the
testing session with vault B, and then released the old export. Current source
before the correction incorrectly returned success and published vault-A
metadata as clean under B:

- the save returned `true` instead of `false`;
- `filePath` changed from the original A path to the exported A path;
- `lastSyncedBodyHash` and `lastSyncedAt` advanced;
- `needsVaultSync` became `false`.

Result bundle:

`build/xcode-results/2026-07-13-lifecycle-epoch-red1-8gib.xcresult`

Direct result summary: one executed, zero passed, one failed, zero skipped.

### Surgical correction

`VaultSyncService` now gives every explicit body save, file-first identity
commit, and dirty-save loop a main-actor admission ticket before its first
suspension. The ticket binds a unique request, monotonically changing lifecycle
epoch, and standardized vault path. Promotion and post-I/O checks accept the
ticket only while that exact session is operational or draining. A forced
epoch/path replacement cannot publish the old result into SwiftData or mark it
clean.

Asynchronous stop now enters `draining` before it waits, cancels current ingress
sources, rejects new admissions, waits for admitted file-first work, and only
then tears down vault services and clears/releases the session. A synchronous
vault replacement refuses to proceed while tracked mutations remain active.

This is not yet a claim that every structural or background path participates:
legacy create/move/rename/delete/directory work, imported/FSEvent callbacks,
and detached post-import tasks remain explicit debt.

### Exact green proof and resource state

Red preflight recorded 6,206.38 MiB swap used, 72% free memory, zero throttled
pages, 737 GiB available disk, and no competing Xcode/compiler/model/Epistemos
runtime. Green preflight recorded 6,174.38 MiB swap used, 70% free memory, zero
throttled pages, 737 GiB available disk, and no competing runtime. Both passed
the owner’s below-8-GiB rule.

Before each build, the previous disposable app was removed and the result
bundle retained. Xcode remained serial. The first strengthened attempt is
retained at
`build/xcode-results/2026-07-13-lifecycle-epoch-green2-8gib.xcresult`. It
stopped during compilation with zero tests executed because the lock-backed
synchronous scope-release probe inherited the test target's default
`MainActor` isolation. The only correction was to make that probe
`nonisolated`; the failed app was then removed before a fresh build.

The current post-correction batch ran only:

- suspended save cannot publish across vault sessions;
- stop drains an admitted save before clearing its vault session and releases
  the exact security scope afterward;
- queued identity commits cannot cross a same-path vault epoch.

Result bundle:

`build/xcode-results/2026-07-13-lifecycle-epoch-green3-8gib.xcresult`

Direct `xcresulttool` summary:

- Executed: 3.
- Passed: 3.
- Failed: 0.
- Skipped: 0.

The Green3 preflight recorded 6,166.38 MiB swap used, 68% free memory, zero
throttled pages, 737 GiB available disk, and no competing Xcode/compiler/model/
Epistemos runtime. It passed the owner's below-8-GiB rule.

Current inventory contains exactly one unsigned Debug test app and no archive:

- App:
  `/private/tmp/Epistemos-LifecycleEpochGreen3-8GiB/Build/Products/Debug/Epistemos.app`
- Executable SHA-256:
  `d355c48015a5a0e09a50618f796fcfd12b5ff0ad71771ea6ece965ac4032403e`

### Exact resumption boundary

1. Add a deterministic failing old-import/background-task drain test.
2. Track, cancel, and await import, FSEvent processing, and post-import tasks so
   no old-vault callback can publish after drain.
3. Route legacy page create/move/rename/delete and directory mutations through
   the same admission and deterministic lock order using private unlocked
   helpers.
4. Add the durable multi-phase identity journal and deterministic watch-start
   reconciliation before claiming force-quit recovery.
5. Delete the current Debug app and rerun the owner resource preflight before
   the next fresh test build.

## Updated KEELSTONE Verdict — Lifecycle Admission Checkpoint

**INCOMPLETE**

Reason: exact cross-session body-save rejection, same-path identity rejection,
admitted-save stop drain, and scope-release order are green, but structural and
background lifecycle coverage, crash-journal recovery, broader editor/manual
runtime proof, current Release artifact gates, and the finite free-V1 runtime
matrix remain open. No recommendation to start another canonical execution key
is made.

## Initial Import Drain Evidence — 2026-07-13

This pass continued the same
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` execution key. It did not
start a feature/canon lane, model/provider operation, archive, or app launch.

### Exact red proof

The new deterministic test replaced the real initial import with a checked
continuation barrier that deliberately ignored cancellation. While that import
remained suspended, current source before correction completed stop, cleared
the vault session, released its security scope, and left the lifecycle drain.
Four assertions from the one test failed on those exact consequences.

Result bundle:

`build/xcode-results/2026-07-13-background-import-drain-red1-8gib.xcresult`

Direct result summary: one executed, zero passed, one failed, zero skipped.

### Surgical correction

Initial import now captures an exact epoch/path lifecycle token before its first
suspension. Progress publication requires that same token to remain
operational. Asynchronous stop cancels and then awaits the captured import task
after admitted file mutations drain and before it clears actor/search state or
releases security-scoped access. The task checks cancellation and exact
operational identity before post-import maintenance, after the recovery-check
suspension, before success/error toast publication, and before final telemetry.

This correction deliberately does not claim ownership of the detached
Spotlight/search/Instant Recall children, hybrid migration, graph/manifest/body
cleanup, or FSEvent processing. Those remain the next lifecycle debts.

### Exact green proof and resource state

Red preflight recorded 6,158.38 MiB swap used, 69% free memory, zero throttled
pages, 739 GiB available disk, and no competing Xcode/compiler/model/Epistemos
runtime. Green preflight recorded 6,291.06 MiB swap used, 69% free memory, zero
throttled pages, 739 GiB available disk, and no competing runtime. Both passed
the owner's below-8-GiB rule. Before each build, the prior app/DerivedData was
removed, the result bundle was retained, and Xcode remained serial.

The post-correction batch ran only the cancellation-ignoring initial-import
drain regression. It additionally asserted zero old-session `.vaultChanged`
events and no stale final import summary.

Result bundle:

`build/xcode-results/2026-07-13-background-import-drain-green1-8gib.xcresult`

Direct `xcresulttool` summary:

- Executed: 1.
- Passed: 1.
- Failed: 0.
- Skipped: 0.

Current inventory contains exactly one unsigned Debug test app and no archive:

- App:
  `/private/tmp/Epistemos-BackgroundImportGreen1-8GiB/Build/Products/Debug/Epistemos.app`
- Executable SHA-256:
  `471f656210893375f4dd751a82134f3721e36eb958edb00a85fa6adaa9377f0c`

### Exact resumption boundary

1. Add the deterministic stale-FSEvent-callback regression and bind watcher
   callback/debounce ingress to the exact lifecycle token.
2. Clear every pending watcher field, including `pendingLastEventID`, on stop.
3. Track, cancel, and await already-running FSEvent processing, hybrid
   migration, detached indexing, graph, manifest, and healthy-body cleanup.
4. Then route structural mutations through lifecycle admission and add the
   durable multi-phase identity journal/reconciliation leg.
5. Delete the current Debug app and rerun the exact resource preflight before
   the next fresh test build.

## Updated KEELSTONE Verdict — Initial Import Drain Checkpoint

**INCOMPLETE**

Reason: the cancellation-ignoring initial-import task is now token-bound and
drained before scope release, but its detached child work, hybrid migration,
watcher ingress/processing, structural mutation coverage, crash-journal
recovery, broader editor/manual runtime proof, current Release artifact gates,
and the finite free-V1 runtime matrix remain open. No recommendation to start
another canonical execution key is made.

## Stale Watcher Ingress Evidence — 2026-07-13

This pass remained inside
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It launched no model or
provider, opened no owner vault, created no archive, and did not start the
feature/canon lane.

### Exact red proof

The deterministic test captured a vault-A watcher delivery behind a checked
continuation, activated vault B, and then released the old A delivery. Before
correction, the handler wrote the old event ID before path classification and
armed a debounce even though the A path was ignored against B.

Result bundle:

`build/xcode-results/2026-07-13-stale-watcher-callback-red1-8gib.xcresult`

Direct `xcresulttool` summary: one executed, zero passed, one failed, zero
skipped. The test recorded two issues: `lastEventID` was `91001` instead of
`nil`, and `debounceActive` was true instead of false.

### Surgical correction

The FSEvents callback box and directory fallback now capture the exact
`VaultLifecycleToken` from watcher creation. The test delivery seam uses the
same production handler. Ingress rejects a stale token before touching any
pending watcher field; debounce validates before scheduling and again after
its suspension; drain validates before consuming pending state; checkpoint
persistence validates after detached processing. Stop now clears
`pendingLastEventID` with the other pending watcher fields.

The first corrected A-to-B run passed in
`build/xcode-results/2026-07-13-stale-watcher-callback-green1-8gib.xcresult`,
but it was deliberately treated as preliminary after review identified that a
path-only guard could pass that test shape. The accepted test was strengthened
to capture in A, activate B, reactivate A under a new epoch, and only then
release the old A callback. A nonexistent routable `Old.md` would classify as
deleted if incorrectly admitted, so every pending-state assertion remains
deterministic without sleeps.

### Exact final green proof and resource state

Final result bundle:

`build/xcode-results/2026-07-13-stale-watcher-callback-green2-8gib.xcresult`

Direct `xcresulttool` summary:

- Executed: 1.
- Passed: 1.
- Failed: 0.
- Skipped: 0.

The final preflight recorded 6,259.06 MiB swap used, 68% free memory, zero
throttled pages, 739 GiB available disk, and no competing Xcode/compiler/model/
Epistemos runtime. It passed the owner's below-8-GiB ceiling. Before the run,
the preliminary app and DerivedData were deleted; Xcode remained serial.

Current inventory contains exactly one unsigned Debug test app and no archive:

- App:
  `/private/tmp/Epistemos-StaleWatcherGreen2-8GiB/Build/Products/Debug/Epistemos.app`
- Executable SHA-256:
  `2e141a872572b10413e34086026a317ec5ab3adae5b9c22e2b5cd0cd045767dd`

### Proven boundary and exact resumption action

This evidence proves stale watcher ingress cannot seed a different-path or
same-path/new-epoch session. It does not prove real `Unmanaged` callback-box
lifetime, stop cleanup of already-seeded current-session state, or ownership of
an already-running detached processor. That processor can still mutate/index,
spawn recall work, and publish through global current-vault state before the
new checkpoint guard runs.

1. Add the deterministic already-running processor drain regression.
2. Track the processor task and exact lifecycle token, cancel and await it
   before actor/search teardown and security-scope release, and reject every
   post-suspension publication/checkpoint from a stale token.
3. Add the smaller seeded-pending-state stop regression as a sibling teardown
   proof.
4. Then drain hybrid migration and detached import/index/recall/graph/manifest/
   cleanup work before structural mutations or durable-journal recovery.
5. Delete the current Debug app and rerun the exact resource preflight before
   the next fresh test build.

## Updated KEELSTONE Verdict — Stale Watcher Ingress Checkpoint

**INCOMPLETE**

Reason: exact stale ingress rejection is green across different-path and
same-path/new-epoch sessions, but processor/child-task ownership, structural
mutation admission, crash-journal recovery, broader editor/manual runtime
proof, current Release artifact gates, and the finite free-V1 runtime matrix
remain open. No recommendation to start another canonical execution key is
made.

## Ordered Watcher Processor Evidence — 2026-07-13

This pass remained inside
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It opened no owner vault,
launched no model or provider, read no secret, created no archive, performed no
audio operation, and did not begin feature/canon work.

### Exact red proofs

Ordering/partial Red1 is retained at:

`build/xcode-results/2026-07-13-watcher-processor-ordering-red1-8gib.xcresult`

Direct summary: five executed, three passed, two failed, zero skipped. Current
source before correction suppressed a committed `(didProcess: false,
didMutate: true)` mutation and allowed an older completed event to move a
stored checkpoint from `94002` backward to `94001`.

FIFO/failure-barrier Red2 is retained at:

`build/xcode-results/2026-07-13-watcher-processor-ordering-red2-8gib.xcresult`

Direct summary: two executed, zero passed, two failed, zero skipped. The FIFO
test observed two running processors and zero queued, then ended at `95001`
instead of `95002`. The failure-barrier test observed one publication instead
of two and checkpoint `96002` instead of the seeded `96000`.

The disposable Red1 and Red2 app executable SHA-256 values were respectively:

- `d56e3c9b47580ca9a73d011ce1b04f4f425a2973908fba913e2ec4f585c1d685`
- `853d6ce194c7fc70de2edb2b32dbe3c93a385e49633349cb17e4e4f2f4a1b5c1`

Each disposable app/DerivedData tree was removed before the next build; its
`.xcresult` was retained.

### Surgical correction

Watcher ingress now registers an admission before it clears accepted pending
state and enqueues an immutable batch. A main-actor FIFO owns all accepted
batches, and exactly one detached processor runs at a time. Already-admitted
queued work continues during drain so stop cannot deadlock or release actor,
vault, search, or security-scope ownership early.

Completion remains inside the admission through checkpoint persistence and
synchronous EventBus publication. It suppresses all stale/draining completion,
publishes every committed mutation independently of full-batch success, and
sets an exact-lifecycle failure barrier when a batch is incomplete. Later
batches in that lifecycle may publish their mutations but cannot advance the
checkpoint past the failed range. Checkpoint persistence also refuses a value
less than or equal to its current unsigned event ID. The static worker catch
preserves `didMutate` when earlier operations succeeded before a later error.

The accepted queue uses a head index and periodically removes its consumed
prefix, bounding historical-batch retention during sustained ingress. The
watcher completion also stopped directly requesting an ambient-manifest
refresh. `.vaultChanged` remains the single event, and AppCoordinator's
standard subscription remains the sole refresh owner, preventing two serial
manifest builds for one watcher mutation.

### Exact green proofs and resource state

The first Green1 invocation is retained only as invalid evidence:

`build/xcode-results/2026-07-13-watcher-processor-ordering-green1-8gib.xcresult`

It omitted `CODE_SIGNING_ALLOWED=NO`; Xcode stopped at the missing provisioning
profile before compilation, executed zero tests, and produced no app. No
account, payment, or provisioning update was attempted. Its DerivedData was
deleted before the established unsigned local-test setting was restored.

Preliminary Green2 is retained at:

`build/xcode-results/2026-07-13-watcher-processor-ordering-green2-8gib.xcresult`

Direct summary: seven executed, seven passed, zero failed, zero skipped. Its
disposable app executable SHA-256 was
`3d50b6213c2df8d1b2ea7565fa93a3f45d81d77c27fb3ed2e65f199fe9b20749`.
That app/DerivedData tree was deleted before the adjacent duplicate-refresh
correction was built.

Accepted final Green3 is retained at:

`build/xcode-results/2026-07-13-watcher-processor-ordering-green3-8gib.xcresult`

Direct `xcresulttool` summary:

- Executed: 8.
- Passed: 8.
- Failed: 0.
- Skipped: 0.

The eight tests prove seeded watcher cleanup, cancellation-ignoring processor
drain before exact scope release, same-path/new-epoch suppression, committed
partial-mutation publication without checkpoint advance, monotonic checkpoint
persistence, one-running/one-queued FIFO execution, failed-batch checkpoint
barrier with later mutation visibility, and a single ambient-refresh owner.

Recorded preflights:

- Red1: 6,610.31 MiB swap, 70% free memory, zero throttled pages, 737 GiB disk.
- Red2: 6,866.94 MiB swap, 70% free memory, zero throttled pages, 737 GiB disk.
- Unsigned Green2 retry: 6,858.94 MiB swap, 71% free memory, zero throttled
  pages, 737 GiB disk.
- Final Green3: 6,834.81 MiB swap, 69% free memory, zero throttled pages,
  737 GiB disk.

No preflight found a competing Xcode build, compiler, model, or Epistemos
runtime. Every executed build passed the owner's below-8-GiB safety ceiling.

Current inventory contains exactly one unsigned Debug test app and no archive:

- App:
  `/private/tmp/Epistemos-WatcherProcessorOrderingGreen3-8GiB/Build/Products/Debug/Epistemos.app`
- Executable SHA-256:
  `a64ca84207213bf0c085c5977a702b52f4cff91a92c158ac37a34234453fdc27`

### Exact resumption boundary

The outer watcher processor is ordered, token-gated, and admission-drained.
The next unproved boundary is child work started inside the processor:
`scheduleInstantRecallPostImportUpdate` and
`scheduleInstantRecallIndexRebuild` still create detached tasks that are not
owned by the batch admission and can outlive stop or same-path epoch
replacement.

1. Add deterministic cancellation-ignoring child-task drain and same-path
   epoch regressions.
2. Give processor-spawned recall/index children explicit lifecycle/task
   ownership and keep their parent admission active until they finish.
3. Gate every child publication or derived-state apply by the exact lifecycle
   token.
4. Continue through hybrid/post-import child ownership, then structural
   mutations and durable identity journal/reconciliation.
5. Delete the current Debug app and rerun the full owner resource preflight
   before the next fresh test build.

## Updated KEELSTONE Verdict — Ordered Watcher Processor Checkpoint

**INCOMPLETE**

Reason: watcher batch admission, FIFO, partial-mutation truth, checkpoint
ordering/barrier, and single ambient-refresh ownership are green, but
processor-spawned child tasks, hybrid/post-import work, structural mutations,
crash-journal recovery, broad editor/manual runtime proof, current Release
artifact gates, and the finite Free V1 runtime matrix remain open. No
recommendation to start another canonical execution key is made.

## Watcher Recall Child Ownership Evidence — 2026-07-13

This pass remained inside
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It opened no owner vault,
launched no model or provider, read no secret, created no archive, performed no
audio operation, and did not begin feature/canon work.

### Exact red and invalid attempts

The valid red result is retained at:

`build/xcode-results/2026-07-13-watcher-recall-child-red3-8gib.xcresult`

Direct summary: three executed, zero passed, three failed, zero skipped, with
twelve recorded issues. Before correction:

- stop completed with the watcher admission already zero, released the exact
  security scope, cleared the vault URL, accepted one old Recall apply and one
  old `.vaultChanged`, and persisted checkpoint `97001`;
- same-path/new-epoch replacement accepted one old Recall apply and one old
  `.vaultChanged` and persisted checkpoint `97002`;
- `VaultIndexActor.removePageArtifacts` still contained a separate
  `instantRecallService` owner and untracked main-actor task.

The disposable Red3 app executable SHA-256 was
`8ade1f9a74afb12e896da4441785835dbd2a3722d3a29cdf0a7e88bab83ffa9c`.

Red1 is retained but invalid: compilation stopped before tests because the new
value types inherited the test target's default `MainActor` isolation. Red2 is
also invalid: selectors without their required `()` suffix executed zero
tests. Their build trees were removed before the next fresh build; result
bundles were retained.

### Surgical correction

The static watcher worker now returns a data-only
`VaultPostImportRecallWorkload` with its processing result. The already-owned
FIFO processor awaits Recall preparation before main-actor completion and
before finishing its mutation admission. Preparation snapshots either bounded
incremental notes/deletions or a complete prepared document dictionary.

`completeVaultFileSystemBatch` rechecks the exact operational lifecycle token
immediately before synchronously applying that prepared mutation. Only then
does it establish any failed-batch checkpoint barrier, persist a successful
checkpoint, publish `.vaultChanged`, finish admission, and start the next FIFO
batch. A stale or draining batch applies and publishes nothing. A partially
committed `(false, true)` batch still applies Recall and publishes its mutation
but cannot advance the checkpoint.

`VaultIndexActor.removePageArtifacts` no longer launches an independent Recall
deletion. If duplicate cleanup removes rows without an exact deleted-ID list,
the import snapshot now marks its change IDs incomplete so Recall receives a
full rebuild workload rather than an incomplete incremental update.

The compatibility `InstantRecallService.rebuildIndexAsync` path builds and
filters its dictionary in a utility detached task. Current watcher rebuild
preparation already runs in the retained utility processor. Main-actor apply
uses `replaceIndex(with:)` to swap the prepared dictionary and reset results/
metrics instead of mapping full note text on the main actor.

### Exact green proof and resource state

Preliminary Green1 is retained at:

`build/xcode-results/2026-07-13-watcher-recall-child-green1-8gib.xcresult`

It executed eleven tests with eleven passes, but it is not evidence for current
source: `VaultSyncService`, `InstantRecallService`, and both test files changed
after its finish time to introduce the prepared-dictionary/atomic-replace
refinement and scoped guards. Its disposable executable SHA-256 was
`0fc6d72c1b825f434bc30ba62a286273980cdbd0433a68bcd134cfd602ef363f`.
That app/DerivedData tree was deleted before the accepted build.

Accepted current-source Green2 is retained at:

`build/xcode-results/2026-07-13-watcher-recall-child-green2-8gib.xcresult`

Direct `xcresulttool` summary:

- Executed: 13.
- Passed: 13.
- Failed: 0.
- Skipped: 0.

The batch proves the prior watcher stop/processor/same-path/FIFO/partial/
monotonic/failure-barrier/single-refresh contracts plus:

- stop retains the exact scope and admission while cancellation-ignoring
  watcher Recall preparation is suspended;
- old Recall cannot apply, publish, or checkpoint across a same-path epoch;
- partial mutation applies Recall once without checkpoint advance;
- artifact removal has no second ambient Recall owner;
- rebuild preparation is in the owned utility processor and main-actor apply
  consumes a prepared dictionary;
- the real Recall service removes stale documents, installs prepared
  documents, resets results and search metrics, and retains whitespace
  filtering through its async compatibility rebuild.

Green2 preflight at `2026-07-13T22:44:45Z` recorded:

- branch: `feat/goose-surface`;
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty entries: 108;
- swap: 6,929.12 MiB used of 8,192 MiB;
- system free memory: 69%;
- pages throttled: zero;
- available disk: 735 GiB;
- competing Xcode/compiler/model/Epistemos processes: none.

Post-run state recorded 6,957.62 MiB swap used, 66% free memory, zero throttled
pages, and 734 GiB available disk. Two parentless `ibtoold` helpers left by the
completed build were inspected and reaped; the final competing-process scan is
empty. All thresholds passed the owner's below-8-GiB rule.

Current inventory contains exactly one unsigned Debug test app and no archive:

- App:
  `/private/tmp/Epistemos-WatcherRecallChildGreen2-8GiB/Build/Products/Debug/Epistemos.app`
- Executable SHA-256:
  `dc83df74cadf7576efd29a2ff872e06d238aa32e83eca1e7be55bb9831c02629`

### Exact resumption boundary

This evidence is narrow to watcher-triggered Instant Recall. Initial import and
manual sync still schedule unowned Recall work; hybrid migrations are detached
from and can race initial import; SearchIndex change notification, folder/body/
toast publication, and Spotlight children still escape retained lifecycle
ownership. Incremental Recall apply also performs bounded text checks/mutations
on the main actor, and replacing a dictionary may release its old storage
there. These remain explicit ownership/performance debt.

1. Add deterministic failing hybrid-migration ordering and cancellation-
   ignoring initial-import child-drain regressions.
2. Fold hybrid migration into the retained initial-import task before import.
3. Retain and await required post-import Recall/search/Spotlight work, reject
   stale publication by the exact lifecycle token, and finish the parent only
   after those children settle.
4. Then close Search notification, folder/body/toast, and Spotlight ownership
   before structural mutations or durable identity-journal reconciliation.
5. Delete the current Debug app and rerun the full owner resource preflight
   before the next fresh test build.

## Updated KEELSTONE Verdict — Watcher Recall Child Checkpoint

**INCOMPLETE**

Reason: watcher Recall preparation/apply is now FIFO-owned, token-gated, and
directly verified, but hybrid/initial-import children, remaining notification/
Spotlight work, structural mutation admission, crash-journal recovery, broad
editor/manual runtime proof, current Release artifact gates, and the finite
Free V1 runtime matrix remain open. No recommendation to start another
canonical execution key is made.

## Hybrid Migration Ownership Evidence — 2026-07-13

This pass continued
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It opened no owner vault,
launched no model/provider, created no archive, and did not begin canon feature
work.

### Exact red proof

Result bundle:

`build/xcode-results/2026-07-13-hybrid-migration-ownership-red1-8gib.xcresult`

Direct `xcresulttool` summary: two executed, one passed, one failed, zero
skipped. The failed source contract recorded two issues: the hybrid-migration
call occurred after the `didImport` start and remained inside its own utility
task. That shape let migration race import and outlive the retained import
handle.

The cancellation-ignoring runtime test passed before correction, but it is not
counted as red or behavior proof: the parent import could still be active and
independently keep stop suspended. The deterministic red claim is limited to
the two source-order/ownership failures. Disposable executable SHA-256:
`c0840d9201f1666b047df6d2939315d69d4f6312172c58a6cd2ad01cb0efff79`.

Red preflight recorded 6,917.62 MiB swap used, 68% free memory, zero throttled
pages, 735 GiB available disk, and no competing Xcode/compiler/model/Epistemos
runtime. The disposable build tree was deleted before the green build.

### Surgical correction

`migrateToHybridSync` and `migrateFromExternalStorage` now execute, in that
order, inside the already-retained `importTask` before core import. A test-only
operation seam avoids mutating real one-time migration preferences. After the
migrations return, the parent checks cancellation and the exact operational
lifecycle epoch/path before it may begin import. `stopWatchingAsync` already
cancels and awaits that parent before actor/search teardown or scope release,
so a cancellation-ignoring migration cannot escape teardown.

The former separate utility migration task was removed. No post-import child,
watcher buffering, manual sync, or maintenance ownership claim is made here.

### Exact green proof and resource state

Accepted result bundle:

`build/xcode-results/2026-07-13-hybrid-migration-ownership-green1-8gib.xcresult`

Direct `xcresulttool` summary:

- Executed: 3.
- Passed: 3.
- Failed: 0.
- Skipped: 0.

The tests jointly prove:

- source order/ownership has migration inside the import task before
  `didImport`, with a cancellation/exact-token guard between them;
- stop remains draining, keeps the old vault URL, and holds the security scope
  while an injected migration ignores cancellation;
- core import does not start while migration is blocked and the exact observed
  order after release is migration-started, migration-finished, import-started.

Green preflight at `2026-07-13T23:02:59Z` recorded branch
`feat/goose-surface`, HEAD
`668b52cfb43721de95db102260d9f327ae24e13e`, 108 dirty entries, 7,026.75 MiB
swap used, 67% free memory, zero throttled pages, 735 GiB available disk, and
no competing runtime. Post-run state recorded 7,026.75 MiB swap, 66% free
memory, zero throttled pages, and 733 GiB disk. One parentless `ibtoold` helper
from the completed build was reaped; the final process scan is empty. The run
remained below the owner's 8-GiB swap ceiling.

Current inventory contains exactly one unsigned Debug test app and no archive:

- App:
  `/private/tmp/Epistemos-HybridMigrationOwnershipGreen1-8GiB/Build/Products/Debug/Epistemos.app`
- Executable SHA-256:
  `5f046e9ace96197d63446c506d44935deca96dae41d88c1b6734ef643fd50c9e`

### Exact resumption boundary

The migration child is owned, but the full initial pipeline is not. Search
diff, outer/inner Spotlight, and Recall work still escape through detached
tasks; watcher processing can interleave before the retained pipeline is
ready; and search notifications, Spotlight completion timestamp, healthy-body
cleanup, graph/manifest refresh, body/folder/toast publication remain open.

1. Add deterministic post-import-child stop-drain and same-path/new-epoch
   rejection tests plus a normal exactly-once pipeline test.
2. Add a watcher-during-import buffer/drain-once regression.
3. Await Search diff, legacy and typed Spotlight work, and Recall preparation
   serially inside the retained parent; recheck exact token between legs and
   immediately before synchronous Recall apply.
4. Drain buffered watcher events once, then publish ready/progress/event and
   separately harden remaining maintenance/publication children.
5. Delete the current Debug app and rerun the full resource preflight before
   the next fresh test build.

## Updated KEELSTONE Verdict — Hybrid Migration Checkpoint

**INCOMPLETE**

Reason: hybrid migration ordering and stop/scope ownership are green, but
post-import Search/Spotlight/Recall ownership, watcher buffering, remaining
maintenance/publication work, structural mutation admission, crash-journal
recovery, broad runtime proof, Release artifact gates, and the finite Free V1
matrix remain open. No new execution key is recommended.

## Initial Derived Readiness And Journal Checkpoint — 2026-07-13

This pass remained inside
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It launched no app, opened
no owner vault, loaded no model or provider, read no secret, created no
archive, performed no audio operation, and did not begin feature/canon work.

### Prior and red evidence

`build/xcode-results/2026-07-13-initial-derived-ownership-green1-8gib.xcresult`
is compile-only evidence. Its direct result summary contains zero executed
tests and an `unknown` result, so it is not counted as green behavior proof.

`build/xcode-results/2026-07-13-initial-derived-ownership-green2-8gib.xcresult`
executed 22 tests: 20 passed, two failed, and none were skipped. The two
failures were stale source-contract expectations after the implementation
moved from `let didImport: Bool` to an `InitialImportResult` and strengthened
the watcher processor from optional to retained strong ownership. Both were
corrected before the valid red pass. Green2 predates the current source and is
not current-source acceptance evidence.

The valid red result is retained at:

`build/xcode-results/2026-07-13-initial-readiness-red2-8gib.xcresult`

Direct summary: seven executed, four passed, three failed, zero skipped. It
proved that the then-current source could still:

- publish initial ready after a failed buffered-watcher reconciliation;
- lose the failed buffered batch instead of preserving it for retry;
- reopen the watcher gate while recovery remained unresolved; and
- fail the strengthened Search/Spotlight/readiness source contract.

The disposable Red2 executable was 40,344 bytes with SHA-256
`7464fc2a0753cf271ab45a6fbb9fbd90cbb6a17e7f98a120244a265216a5bede`.
Its build tree was deleted; its result bundle and log remain retained.

### Surgical correction represented by current source

Initial import now owns the Search page/block diff and its single awaited
notification, rejects a nil importer snapshot, stages Recall before an exact
lifecycle-gated apply, and keeps readiness closed while buffered watcher work
drains. The watcher completion fence now carries the processing result. A
failed batch is requeued without overwriting newer opposite-direction events,
forces a safe rescan, preserves the maximum event ID, and cannot publish
ready.

Spotlight startup state is now scoped to the exact vault through the service's
injected defaults. The actor returns a journal receipt, queries inclusively in
ascending order without the former 1,000-row cap, propagates cancellation and
legacy/typed donation failure, and proposes the maximum staged `updatedAt`
rather than wall-clock time. The service persists that receipt only after the
initial derived work, buffered-watcher reconciliation, any required catch-up,
and recovery check succeed for the exact lifecycle token. A journal receipt
does not claim that macOS Spotlight has already made an item searchable.

### Current focused result and mandatory resource stop

The current focused result is retained at:

`build/xcode-results/2026-07-13-initial-readiness-green3-8gib.xcresult`

Direct `xcresulttool` summary:

- Executed: 9.
- Passed: 8.
- Failed: 1.
- Skipped: 0.

All four new behavioral regressions passed: failed buffered reconciliation
kept ready closed and preserved retry state; nil importer output was rejected;
Spotlight cursor keys were vault-scoped; and an unresolved recovery issue kept
the watcher gate closed. Hybrid ordering, normal watcher buffering, and the
watcher Recall ownership guard also passed. The sole failure was a stale
source-contract string that still expected
`Self.applyInstantRecallMutation(recallMutation)` after the owned result was
renamed to `derivedResult.recallMutation`. This is not a fully green batch.

Green3 preflight at `2026-07-13T23:55:57Z` recorded:

- branch: `feat/goose-surface`;
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty entries: 110;
- swap: 7,456.88 MiB used;
- system free memory: 68%;
- pages throttled: zero;
- available disk: 734 GiB;
- competing Xcode/compiler/model/Epistemos processes: none.

The disposable Green3 executable was 40,344 bytes with SHA-256
`ef8ce1a3e6124cf9c62375c19a9b7d552de585fc63cbb8ee1601ae6449a168ca`.
After the completed test, swap reached 8,363.38 MiB while free memory was 72%,
pages throttled remained zero, and 731 GiB was available. The disposable app
and DerivedData tree were then deleted. The result bundle and log remain
retained, and the final app-product inventory is empty.

After deletion, swap was still 8,347.38 MiB. That exceeds the owner's strict
below-8-GiB threshold, so no further app-source correction, test, build,
archive, or launch began. The exact safe resumption action is to wait for a
fresh preflight below 8 GiB, update the one stale source expectation to the
current owned expression, delete any stale app product if one appears, and run
one fresh serial focused batch. A broader regression batch remains deferred
until that focused batch is fully green.

### Post-result source audit correction

A subsequent read-only audit established that changing the stale expectation
alone would be insufficient and must not be treated as the safe resumption
action. Current source still has untested false-success paths inside this exact
derived-readiness leg:

- known watcher work can arrive after the one private drain and remain pending
  while readiness is published after later Spotlight/recovery suspension;
- full-rescan processing disables missing-file deletion, ignores any explicit
  changed/deleted paths in the same batch, and can still acknowledge the event
  checkpoint;
- the failed-batch checkpoint barrier has no proven same-lifecycle retry and
  clear transition;
- required Search timestamp fetch failure collapses to an empty array, a nil
  full-page provider is silently skipped, stale block rows are not reconciled,
  and the owned notification can announce both page and block domains without
  a result-bearing block proof;
- required Recall incremental/rebuild reads also convert missing/fetch failure
  into skipped or empty output that can still be applied;
- destructive Spotlight clear is unawaited and legacy-only while the scoped
  cursor survives; normal watcher mutations do not own legacy/typed Spotlight
  update/deletion; and the typed deletion helper uses the legacy searchable-
  item deletion API rather than the typed entity API;
- Spotlight body batches are bounded to 50, but the actor first fetches and
  stages every matching page, so metadata allocation remains unbounded.

These are source findings, not executed runtime failures. They invalidate a
fully green or readiness claim and require focused red regressions before
correction. Apple’s current Core Spotlight documentation independently
confirms that indexing completion acknowledges journaling, not already-visible
search results, and documents a separate typed `deleteAppEntities` API.

The exact publication verification was refreshed after Green3: the handoff
publication commit, local HEAD, and fetched `origin/feat/goose-surface` all
equal `668b52cfb43721de95db102260d9f327ae24e13e`.

The corrected resumption action is therefore: wait for a strict below-8-GiB
preflight; add deterministic red coverage for late buffered work, full-rescan
deletion/checkpoint truth, Search/Recall missing-input failure, block receipt
and notification truth, cursor invalidation, typed deletion, watcher Spotlight
ownership, and retry-barrier healing; then make surgical fail-closed changes
and update the stale guards before one fresh serial focused batch.

### Resumed continuation preflight — 2026-07-14T00:30:28Z

The owner asked to continue “as if we never stopped.” A fresh fetch and
publication check again resolved the active branch to `feat/goose-surface` and
resolved local `HEAD`, fetched `origin/feat/goose-surface`, and the handoff
publication commit to the same full SHA:

`668b52cfb43721de95db102260d9f327ae24e13e`

The worktree still contained 110 owner-dirty entries. The first resumed
preflight recorded 8,291.38 MiB swap, 73% system free memory, zero throttled
pages, 732 GiB available disk, and no competing Xcode/compiler/model/Epistemos
runtime. A later read-only recheck recorded 8,259.38 MiB swap. Both swap
measurements remained above the strict below-8-GiB threshold, so no app/test
source edit, test, build, archive, launch, owner-vault access, model/provider/
secret/audio operation, or new execution key began.

No `Epistemos*.app` product or `Epistemos*.xcarchive` was present in the active
temporary, repository build, Xcode DerivedData, or Xcode Archives locations.
The retained result bundles and logs remain evidence, not app products. Work
continued only as read-only correction design plus this durable documentation
checkpoint. The next executable action remains unchanged: require a fresh
strictly-below-8-GiB preflight before adding red tests or touching app/test
source.

### Owner resource-ceiling supersession — 10 GiB

The owner subsequently directed: “u can run it birng it to 10gb limit at
10gb.” This supersedes the prior strict below-8-GiB swap ceiling with a strict
below-10-GiB ceiling (10,240 MiB) for the continuing Keelstone evidence leg.
The at-least-25% free-memory, zero-throttled-pages, no-competing-build/runtime,
serial-Xcode, and one-current-app rules remain unchanged. A fresh complete
preflight is still mandatory before any app/test source edit or execution.

### Initial-readiness Red3 — exact failed-behavior evidence

The fresh 10-GiB preflight passed on branch `feat/goose-surface`. Local `HEAD`,
fetched `origin/feat/goose-surface`, and the handoff publication commit all
equalled `668b52cfb43721de95db102260d9f327ae24e13e`; the owner-dirty count remained
110. Resources were 8,235.38 MiB swap, 75% system free memory, zero throttled
pages, 732 GiB available disk, and no competing Xcode/compiler/model/Epistemos
runtime. No stale Epistemos app product or archive existed before the run.

One fresh serial focused batch ran into:

`build/xcode-results/2026-07-14-initial-readiness-red3-10gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-initial-readiness-red3-10gib.log`

Direct `xcresulttool` inspection reported six executed, one passed, five
failed, and zero skipped. The failures proved the current source behavior:

- the initial Search owner still announces `.searchBlocks` without a proven
  block reconciliation receipt;
- a second watcher deletion delivered before the first completion fence
  resumed was not drained before readiness (`processorProbe` remained one);
- Search diff did not throw when a required full-page projection was missing
  and had already deleted the stale row;
- typed entity deletion still omitted both `deleteAppEntities` identifier and
  type-wide APIs; and
- a successful full-rescan-shaped reconciliation left the prior checkpoint
  barrier permanent (`96000` instead of `96002`).

The disposable executable was 40,344 bytes with SHA-256
`e30f516fa21c7a118a154b1616b1d5c55487643f022c44e9f4c57734c13a2c1a`.
Post-run resources were 8,195.38 MiB swap, 69% system free memory, zero
throttled pages, and 730 GiB available disk. The complete DerivedData/app tree
was deleted immediately; retained result/log evidence remained, the app/archive
inventory returned empty, and post-cleanup free memory rose to 70% with 732 GiB
available disk.

The shell wrapper attempted to assign zsh's read-only `status` parameter only
after `xcodebuild` had finished and written the complete result bundle. This
made the wrapper itself exit nonzero but did not invalidate the direct result,
test identities, executable identity, or retained log. Future wrappers must
use a non-reserved exit-code variable.

### Red3 surgical correction checkpoint — 2026-07-14T00:47:48Z

Only the five failed Red3 behaviors were corrected before the next evidence
run:

- Search diff now resolves every required replacement row before deleting any
  stale row and throws when a required page projection is missing;
- the initial Search owner no longer announces `.searchBlocks` without a block
  reconciliation receipt;
- initial readiness now repeatedly drains buffered watcher work, detects work
  admitted across recovery suspension with a monotonic revision, and publishes
  readiness only at a no-await stable instant; the bounded churn ceiling is
  eight successful startup drains;
- typed NoteEntity deletion now uses the identifier-scoped typed API and has a
  separate type-wide typed removal operation; and
- a failed FSEvent checkpoint barrier can clear only when a later processing
  result carries an explicit authoritative-full-rescan receipt. An ordinary
  successful batch cannot erase the barrier.

The checkpoint-healing test operation now supplies that explicit receipt on
its second invocation. Production fallback import does not yet manufacture the
receipt because its deletion-completeness contract is still unresolved; this
prevents the focused fix from overclaiming production reconciliation.

The edited source and tests were re-read and `git diff --check` passed. No
build, test, archive, app launch, vault access, or runtime operation had begun
at this checkpoint. Broader Search atomic page/block reconciliation, throwing
SwiftData source reads, Recall preparation/apply receipts, dual-lane Spotlight
journaling and durable clear generation, watcher Spotlight ownership, bounded
Spotlight pagination, and manual visibility remain verification debt and keep
the overall verdict incomplete regardless of the next focused result.

### Initial-readiness Green4 — focused correction evidence

Before Green4, the remote/publication identity was refreshed again. Branch was
`feat/goose-surface`; local `HEAD`, fetched `origin/feat/goose-surface`, and the
handoff publication commit all equalled
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty entry count remained 110.
The first complete resource reading was 8,179.38 MiB swap, 72% free memory,
zero throttled pages, and 731 GiB available disk, with no competing scoped
Xcode/compiler/model/Epistemos runtime. Inventory found one stale Release app
inside `Epistemos-FreeV1-Archive` DerivedData. That exact app product was
deleted, no archive existed, and the inventory was empty before Green4.

The final immediate preflight still recorded 8,179.38 MiB swap, 71% free
memory, and zero throttled pages. One fresh serial six-test batch then ran into:

`build/xcode-results/2026-07-14-initial-readiness-green4-10gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-initial-readiness-green4-10gib.log`

Direct `xcresulttool` summary inspection reported six total, six passed, zero
failed, zero expected failures, and zero skipped. The result was `Passed` on an
arm64 MacBook Pro running macOS 26.3.1. The retained log independently names
all six selected tests and ends `** TEST SUCCEEDED **`. A secondary attempt to
enumerate the test tree through `xcresulttool get test-results tests` returned
an XCResult database-view error, so no claim relies on that failed secondary
query.

The disposable app was exactly:

`/private/tmp/Epistemos-InitialReadinessGreen4-10GiB/Build/Products/Debug/Epistemos.app`

Its executable was 40,344 bytes with SHA-256
`108eb862144e29b7c6b201ff631a0c916ed9366fb514a24a07f4dab209dbe923`.
The app bundle occupied 489,596 KiB. Post-run resources were 8,171.38 MiB swap,
67% free memory, zero throttled pages, and 729 GiB available disk. The complete
DerivedData/app tree was then deleted. The final app/archive inventory was
empty, free memory was 68%, and available disk returned to 731 GiB. No archive,
artifact-gate pass, manual app launch, model/provider request, secret access,
audio operation, owner-vault access, or subsequent execution key began.

Green4 closes only the five Red3 regressions under the selected test contract.
It does not close the explicitly retained Search/Recall/Spotlight receipt and
normal-watcher debt listed above.

### Search/Recall Red4 — exact failed-behavior evidence

The next bounded leg used no new production fault hook. It added one Search
behavior regression proving stale page-owned block cleanup and one watcher
Recall regression proving a missing required incremental page must prevent
apply/checkpoint and preserve retry state.

Its complete preflight again resolved branch `feat/goose-surface`, local
`HEAD`, fetched `origin/feat/goose-surface`, and the handoff publication commit
to `668b52cfb43721de95db102260d9f327ae24e13e`, with 110 dirty entries. It
recorded 8,163.38 MiB swap, 70% free memory, zero throttled pages, 731 GiB
available disk, no competing scoped runtime, and an empty app/archive
inventory.

One fresh serial two-test batch ran into:

`build/xcode-results/2026-07-14-search-recall-red4-10gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-search-recall-red4-10gib.log`

Direct `xcresulttool` summary inspection reported two total, zero passed, two
failed, and zero skipped. The Search test proved that diff sync deleted one
stale page but left its `indexed_blocks` row searchable. The Recall test proved
that a missing required changed page still produced one apply, advanced the
checkpoint from `98300` to `98301`, and left neither full-rescan retry state nor
the failed event ID pending.

The disposable app was exactly:

`/private/tmp/Epistemos-SearchRecallRed4-10GiB/Build/Products/Debug/Epistemos.app`

Its executable was 40,344 bytes with SHA-256
`0a1c018d02a70f0108a1c712d2a7316dc2bbcdbb92b007551f324ce425dd5aa2`;
the app bundle occupied 489,656 KiB. Post-run resources were 8,155.38 MiB swap,
68% free memory, zero throttled pages, and 729 GiB available disk. The complete
DerivedData/app tree was deleted, the final inventory returned empty, and disk
returned to 731 GiB. Red4 therefore authorizes only the two corresponding
surgical corrections; it does not authorize an archive or a general hardening
refactor.

### Red4 surgical correction checkpoint — 2026-07-14T01:07:48Z

The Search correction stages all required page snapshots as before, then
deletes stale page-owned block rows, deletes the stale pages, removes historical
orphan block rows, performs page upserts, and verifies final page count plus a
zero-orphan invariant inside one GRDB write transaction. It returns a
`SearchIndexDiffReceipt` containing actual page/block change counts, final
counts, and receipt-derived notification dependencies. Initial Search ownership
now announces only the committed domains in that receipt. Passive WAL
checkpoint maintenance is logged as maintenance debt after commit rather than
turning a committed logical diff into a false failure.

The Recall correction makes preparation failure distinct from both a valid
`.none` mutation and a legitimate empty rebuild. Missing required incremental
pages now fail preparation; the rebuild path uses an optional required-source
read while the existing manual rebuild API retains its compatibility fallback.
Watcher processing converts a Recall preparation failure into an effective
`didProcess: false` result, suppresses Recall apply and checkpoint advancement,
preserves committed mutation publication, requeues the batch for a full rescan,
and passes the same effective failure to the startup completion fence.

The Red4 Search test now also requires exact receipt counts and both changed
dependencies. Existing source guards were updated to require receipt-derived
Search notification and effective Recall failure propagation. Changed regions
were re-read and `git diff --check` passed. These corrections are source-only
and unexecuted at this checkpoint; their next allowed action is one fresh
serial focused Green5 batch after another complete 10-GiB preflight.

### Search/Recall Green5 — focused correction evidence

The fresh Green5 preflight again resolved branch `feat/goose-surface`, local
`HEAD`, fetched `origin/feat/goose-surface`, and the handoff publication commit
to `668b52cfb43721de95db102260d9f327ae24e13e`, with 110 dirty entries. It
recorded 8,139.38 MiB swap, 69% free memory, zero throttled pages, 731 GiB
available disk, no competing scoped Xcode/compiler/model/Epistemos runtime,
and an empty app/archive inventory. `git diff --check` passed before execution.

One fresh serial twelve-test batch ran into:

`build/xcode-results/2026-07-14-search-recall-green5-10gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-search-recall-green5-10gib.log`

Direct `xcresulttool` summary inspection reported twelve total, twelve passed,
zero failed, zero expected failures, and zero skipped. The result was `Passed`
on an arm64 MacBook Pro running macOS 26.3.1. The batch included all five Red3
regressions, both Red4 regressions, the Recall atomic rebuild test, partial
mutation publication without checkpoint advance, cancellation-ignoring Recall
ownership through stop, and same-path epoch exclusion.

The disposable app was exactly:

`/private/tmp/Epistemos-SearchRecallGreen5-10GiB/Build/Products/Debug/Epistemos.app`

Its executable was 40,344 bytes with SHA-256
`d8f632bc74c43ba2df237b7653c810fe006c00c9f0f34b9a58aff7d88068683c`;
the app bundle occupied 489,736 KiB. Post-run resources were 8,576.56 MiB swap,
69% free memory, zero throttled pages, and 730 GiB available disk. The swap
reading remained below the owner's strict 10,240-MiB ceiling. The complete
DerivedData/app tree was deleted, and the final app/archive inventory was
empty. No archive, artifact gate, manual app launch, owner-vault access,
model/provider request, secret access, audio operation, or subsequent execution
key began.

Green5 closes only the seven focused Red3/Red4 failures under the twelve-test
contract. It does not prove required Search source-read failure, Recall rebuild
source-read failure, public page/block deletion atomicity, typed Spotlight
error receipts, dual-lane Spotlight cursor/clear/watcher/keyset ownership,
production authoritative-full-rescan receipt truth, a Release artifact, or the
finite runtime matrix.

The exact next evidence action is a new preflight followed by deterministic
red coverage for a failed required Recall rebuild-source read, including the
startup completion fence/readiness result. No production correction is
authorized until that test proves the current failed behavior. Required Search
timestamp/full-page read failure remains the next bounded receipt leg after
that Recall proof.

### Owner resource-ceiling supersession — 12 GiB

The owner then directed: “let the ceilig be 12gb now.” This supersedes the
strict below-10-GiB swap ceiling with a strict below-12-GiB ceiling (12,288
MiB) for the same Keelstone execution key. The at-least-25% free-memory,
zero-throttled-pages, no-competing-build/runtime, serial-Xcode, and
one-current-app rules remain unchanged. This changes no product boundary and
authorizes no archive, app launch, owner-vault access, feature/canon work,
model/provider/secret/audio operation, or subsequent execution key.

The complete pre-edit reading immediately before this steer had already passed
the stricter former ceiling: branch `feat/goose-surface`, local `HEAD`, fetched
`origin/feat/goose-surface`, and the handoff publication commit all equalled
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count was 110; swap was
8,576.56 MiB; free memory was 70%; throttled pages were zero; available disk
was 731 GiB; and app/archive inventory was empty. A new complete 12-GiB
preflight is still mandatory immediately before the next build.

### Required-source Red5 compile stop — zero tests

The first 12-GiB preflight passed with exact branch/remote/publication identity,
110 dirty entries, 8,552.56 MiB swap, 71% free memory, zero throttled pages,
730 GiB available disk, no competing scoped process, and an empty app/archive
inventory. Four focused tests were selected: missing Search projection
notification truth, required Search timestamp failure, required Recall rebuild
source failure, and startup readiness rejection after failed Recall rebuild
preparation.

The retained result is:

`build/xcode-results/2026-07-14-required-source-red5-12gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-required-source-red5-12gib.log`

Compilation stopped before test execution because the new deterministic Recall
test hook added a conditional branch before an implicit-return expression;
Swift required an explicit `return` in
`requiredPagesForInstantRecallRebuild()`. Direct result inspection reported
zero total, zero passed, zero failed, and result `unknown`. This is not Red5
behavioral evidence and proves none of the four selected contracts.

The incomplete app directory occupied 197,172 KiB and contained no executable
to identify. Post-stop resources were 8,536.56 MiB swap, 66% free memory, zero
throttled pages, and 729 GiB available disk. The complete disposable build tree
was removed; final app/archive inventory was empty and disk returned to 730
GiB. The only authorized correction is the missing explicit `return`, followed
by source inspection, a fresh complete 12-GiB preflight, and a rerun of the same
four-test selection under a new retained result identity.

### Required-source Red5b — exact destructive Search failure

After the explicit-return correction, the fresh Red5b preflight again matched
branch, local/fetched remote, and handoff publication identity at
`668b52cfb43721de95db102260d9f327ae24e13e`, with 110 dirty entries. Resources
were 8,536.56 MiB swap, 66% free memory, zero throttled pages, 730 GiB available
disk, no competing scoped process, and an empty app/archive inventory.

The retained result is:

`build/xcode-results/2026-07-14-required-source-red5b-12gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-required-source-red5b-12gib.log`

Direct result inspection reported four total, three passed, one failed, and
zero skipped. The missing full-page projection test passed with no mutation or
notification. The forced required Recall rebuild-source read returned no
mutation, and startup rejected the failed buffered Recall preparation while
preserving its retry boundary. Only
`appStoreSearchRequiredTimestampReadFailureCannotMutateOrNotify()` failed.

That test proved the exact current defect: one forced required SwiftData
timestamp-read failure was caught by the compatibility API and converted to an
empty page list; Search then returned success, deleted the seeded indexed page
and its seeded block, and emitted one index-change notification. All four
contract assertions failed for that one root behavior. No unrelated selected
test failed.

The disposable executable was 40,344 bytes with SHA-256
`9f8fd9cf75ce32287f17b35685a6d77596b50e516d9ac8425c676c35cde19049`;
the app bundle occupied 489,864 KiB. Post-run resources were 8,799.44 MiB swap,
68% free memory, zero throttled pages, and 728 GiB available disk. The complete
build tree was deleted; final app/archive inventory was empty, free memory was
69%, and disk returned to 730 GiB.

Red5b authorizes only fail-closed required timestamp ownership: initial/manual
scheduled Search diff and normal watcher Search reconciliation must consume the
optional required timestamp read and stop before `diffSync` when it is nil.
The display-only compatibility count may retain its empty fallback. A structural
guard must bind both Search owners to the required read before the prior Green5
regressions and these four tests are rerun together.

### Red5b surgical correction checkpoint

`VaultIndexActor` now has one shared throwing timestamp loader, an existing
compatibility accessor that still logs and returns an empty list for
display-only count use, and a required Search accessor that logs and returns
nil on failure. The initial/manual scheduled Search owner now returns false
before `diffSync` when that required accessor is nil. The normal watcher owner
returns a failed-but-mutation-preserving processing result before `diffSync`,
so the batch remains retryable and cannot advance its checkpoint while already
committed SwiftData/Recall work can retain its existing partial-mutation
contract.

A source guard requires both production Search owners to use the required
accessor and rejects the ambiguous compatibility API in those sections. The
changed regions were re-read and `git diff --check` passed. No build, test,
archive, app launch, owner-vault access, or subsequent execution key began at
this correction checkpoint. The next executable action is one fresh combined
Green6 batch after a complete 12-GiB preflight.

### Required-source Green6 — combined focused evidence

The complete Green6 preflight again resolved branch `feat/goose-surface`,
local `HEAD`, fetched `origin/feat/goose-surface`, and the handoff publication
commit to `668b52cfb43721de95db102260d9f327ae24e13e`, with 110 dirty entries.
It recorded 8,791.44 MiB swap, 69% free memory, zero throttled pages, 730 GiB
available disk, no competing scoped Xcode/compiler/model/Epistemos runtime,
and an empty app/archive inventory. `git diff --check` passed before execution.

Exactly one fresh serial sixteen-test batch ran into:

`build/xcode-results/2026-07-14-required-source-green6-12gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-required-source-green6-12gib.log`

The retained log has SHA-256
`018678fd260df32f18013a587a38badfed6e324fda5de972881741603990e8e5`.
Direct `xcresulttool` summary inspection reported sixteen total, sixteen
passed, zero failed, zero expected failures, and zero skipped. The result was
`Passed` on an arm64 MacBook Pro running macOS 26.3.1. The selected set was
the complete Green5 twelve-test batch plus required Search timestamp-read
failure, required Recall rebuild-source failure, startup readiness rejection
after failed buffered Recall preparation, and the structural guard binding
both Search diff owners to fail-closed timestamp reads.

The disposable app was exactly:

`/private/tmp/Epistemos-RequiredSourceGreen6-12GiB/Build/Products/Debug/Epistemos.app`

Its executable was 40,344 bytes with SHA-256
`1f24c9f8de83e45311712849776b19f6c30a145328d36a6460653b0f400ed6ad`;
the app bundle occupied 489,912 KiB. Immediate post-run resources were
8,783.44 MiB swap, 69% free memory, zero throttled pages, and 728 GiB
available disk. The swap reading remained below the owner's strict
12,288-MiB ceiling.

After recording that exact identity, the complete disposable build tree was
deleted. The final app/archive inventory was empty. Post-cleanup resources
were 8,775.44 MiB swap, 69% free memory, zero throttled pages, and 730 GiB
available disk. `git diff --check` passed. No archive, artifact-gate pass,
manual app launch, owner-vault access, model/provider request, secret access,
audio operation, or subsequent canonical execution key began.

Green6 closes the focused required Search timestamp-read and Recall
rebuild-source/readiness contracts under this sixteen-test selection. It does
not prove public page/block deletion atomicity outside `diffSync`, typed
Spotlight error receipts, dual-lane Spotlight cursor/clear/watcher/keyset
ownership, production authoritative-full-rescan receipt truth, a Release
artifact, or the finite Free V1 runtime matrix. The next bounded evidence leg
is a failing behavior test for the public Search page-deletion API: seed one
page-owned block, delete the page through the public API, and require page and
block deletion to occur as one receipt-bearing transaction before changing
production code.

### Public Search deletion Red6 — exact orphan-block failure

The Red6 source change added only one behavior regression. It seeded one
indexed page plus one page-owned block, confirmed that both were searchable,
invoked the existing public `SearchIndexService.delete(pageId:)`, and required
both projections to disappear. No production code changed before Red6.

The complete Red6 preflight again matched branch `feat/goose-surface`, local
`HEAD`, fetched `origin/feat/goose-surface`, and handoff publication commit at
`668b52cfb43721de95db102260d9f327ae24e13e`, with 110 dirty entries. It
recorded 8,759.38 MiB swap, 70% free memory, zero throttled pages, 729 GiB
available disk, no competing scoped process, an empty app/archive inventory,
and a passing `git diff --check`.

Exactly one serial one-test batch ran into:

`build/xcode-results/2026-07-14-public-search-delete-red6-12gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-public-search-delete-red6-12gib.log`

The log has SHA-256
`f61db9480f4b0420dacec846b813246fff693e91ed0458b6727a309ff9449468`.
Direct result inspection reported one total, zero passed, one failed, zero
expected failures, and zero skipped. The only issue was the final requirement
that the page-owned block no longer be searchable. The page-removal assertion
passed. This is exact behavioral evidence that the public delete removes the
page row but leaves its block row orphaned and searchable.

The disposable app was exactly:

`/private/tmp/Epistemos-PublicSearchDeleteRed6-12GiB/Build/Products/Debug/Epistemos.app`

Its executable was 40,344 bytes with SHA-256
`8d7b4b6383af765848444d015ae17b4b92573f122372f56e8ff1cc16ba7817d1`;
the app bundle occupied 489,936 KiB. Immediate post-run resources were
8,865.25 MiB swap, 69% free memory, zero throttled pages, and 728 GiB
available disk. The complete disposable build tree was then deleted. Final
app/archive inventory was empty; swap remained 8,865.25 MiB, free memory 69%,
throttled pages zero, and available disk returned to 729 GiB.

Red6 authorizes only the shared atomic page-deletion correction: reuse the
existing in-transaction block-first/page-second deletion helper, return exact
page/block counts with receipt-derived dependencies, notify at most once after
commit, and replace both production two-call deletion sequences with that one
operation while honoring their notification-suppression policy. It does not
authorize a schema migration, rebuild redesign, Spotlight/Recall work,
archive, app launch, runtime matrix, or feature/canon work.

### Red6 surgical correction checkpoint

`SearchIndexService.delete(pageId:)` now reuses the same private
`deletePageRows(ids:in:)` helper already exercised by `diffSync`. Block rows
delete first and the page row deletes second inside one GRDB write transaction.
The operation returns `SearchIndexPageDeletionReceipt` with exact changed-row
counts. A shared dependency function keeps diff and direct-deletion receipt
semantics aligned: page changes map to `.searchPages`, block changes map to
`.searchBlocks`, and no changed rows map to no dependencies. The public method
posts at most one receipt-derived notification after commit and only when
notification ownership is enabled and the receipt is nonempty.

Both production `VaultIndexActor` cleanup owners now call that single deletion
operation and pass `searchIndexNotificationsEnabled`; their separate swallowed
`deleteBlocksForPage` calls are removed. The Red6 behavior test now also checks
the exact `1/1` receipt, union dependencies, no-op `0/0` receipt, and an
orphan-block-only `0/1` receipt. A second test installs a deterministic SQLite
block-deletion failure and requires the complete transaction to roll back with
both the page and block still searchable. A source guard binds both production
owners to the atomic operation, and the existing general Search integration
test now covers the page-plus-block receipt contract. The stale
`ProductionHardeningTests` source expectation was updated to the same owner
contract.

A separate audit found an adjacent notification-ownership debt that this patch
does not close. Initial import intentionally installs Search with observer
notifications disabled, writes page/block rows during import, and then runs a
diff that can be empty because those rows are already current. In that case the
owned diff leg has no receipt dependencies to publish. A future import-level
aggregate mutation receipt, or a redesign that defers those mutations to the
owned leg, is required before claiming exact initial-Search notification
ownership. Global `object: nil` notification correlation and page-only full
rebuild block reconciliation also remain separate debt.

All changed regions were re-read, old two-call production patterns were
searched, and `git diff --check` passed. No post-correction build, test,
archive, app launch, owner-vault access, or runtime action has begun. The next
executable action is one fresh serial Green7 batch after another complete
12-GiB preflight.

### Public Search deletion Green7 — combined focused evidence

The complete Green7 preflight again resolved branch `feat/goose-surface`,
local `HEAD`, fetched `origin/feat/goose-surface`, and handoff publication
commit to `668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count was 112
because the bounded correction intentionally modified two previously clean
general test files in addition to already-dirty feature files. Resources were
8,841.25 MiB swap, 69% free memory, zero throttled pages, and 729 GiB
available disk, with no competing scoped process, an empty app/archive
inventory, and a passing `git diff --check`.

Exactly one serial nineteen-test batch ran into:

`build/xcode-results/2026-07-14-public-search-delete-green7-12gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-public-search-delete-green7-12gib.log`

The log has SHA-256
`06a50e5daed38fc39a5b1171a3f84c74b1673db9f7fa59b64230aab2783d351b`.
Direct result inspection reported nineteen total, nineteen passed, zero
failed, zero expected failures, and zero skipped. The result was `Passed` on
an arm64 MacBook Pro running macOS 26.3.1. The batch contained the complete
sixteen-test Green6 set plus public page/block deletion receipt behavior,
forced block-deletion rollback, and the atomic production-owner source guard.

The disposable app was exactly:

`/private/tmp/Epistemos-PublicSearchDeleteGreen7-12GiB/Build/Products/Debug/Epistemos.app`

Its executable was 40,344 bytes with SHA-256
`34792943b5c81710c525e185bad3c61d5b1a64722c66b83203ec1fb02b94fd65`;
the app bundle occupied 490,044 KiB. Immediate post-run resources were
8,990.25 MiB swap, 69% free memory, zero throttled pages, and 726 GiB
available disk. The dynamic swap allocation total had increased to 10,240
MiB, but used swap remained below the owner's strict 12,288-MiB ceiling.

After recording the exact identity, the complete disposable build tree was
deleted. Final app/archive inventory was empty; swap remained 8,990.25 MiB,
free memory 69%, throttled pages zero, and available disk returned to 728 GiB.
`git diff --check` passed. No archive, artifact-gate pass, manual app launch,
owner-vault access, model/provider request, secret access, audio operation, or
subsequent canonical execution key began.

Green7 closes the exact Red6 public-deletion defect under this nineteen-test
App Store selection: page and owned-block deletion is one transaction; failed
block deletion rolls back the page; receipt counts distinguish page+block,
no-op, and orphan-block-only outcomes; and both production owners use the one
notification-policy-aware operation. The modified general
`SearchIndexServiceIntegrationTests` and `ProductionHardeningTests` files are
not members of the active App Store scheme and were therefore not executed by
Green7; their broad-suite execution remains verification debt. Initial-import
aggregate Search notification ownership, page-only rebuild block
reconciliation, global notification correlation, Spotlight receipts, and the
Release/runtime gates also remain open.

## Updated KEELSTONE Verdict — Initial Derived Readiness Checkpoint

**INCOMPLETE**

Reason: Green7 closes the exact Red6 public page/block deletion defect under
nineteen selected App Store tests, but the non-App-Store broad test files have
not been executed, and initial-import aggregate Search notification ownership,
page-only rebuild block reconciliation, broader Search/Spotlight receipts,
dual-lane Spotlight ownership, production authoritative-full-rescan truth,
normal-watcher/manual-sync breadth, structural mutation/recovery, broad
runtime proof, Release artifact gates, and the finite Free V1 matrix remain
open. No subsequent canonical execution key is started or recommended.

### Owner resource-ceiling supersession — 16 GiB

The owner directed: “make it lock at 16gb at this point man.” This supersedes
the prior strict below-12-GiB swap ceiling with a strict below-16-GiB ceiling
(16,384 MiB) for the continuing Keelstone evidence leg. Sixteen GiB is the
active locked ceiling until a later explicit owner steer changes it.

Every other preflight and scope boundary remains unchanged: free memory must
be at least 25%, pages throttled must be zero, no competing Xcode/compiler/
model/Epistemos runtime may be active, stale app products and archives must be
removed before each build, only one serial Xcode build may run, and the exact
current disposable app must be identified before its complete build tree is
deleted. This resource-only steer does not authorize an archive, app launch,
owner-vault access, model/provider/secret/audio work, payment work, hidden Free
V1 implementation, feature/canon work, or a subsequent execution key.

Green7 remains the latest executable evidence. The next action is still a
read-first selection of the smallest deterministic Search debt followed by a
single test-first red batch, and it may run only after a fresh complete
16-GiB preflight passes.

### Next bounded debt selection — page-only rebuild orphan blocks

Current-source comparison confirms the page-only full rebuild defect is the
smallest deterministic next leg. `rebuildFromSwiftData` replaces only
`indexed_pages`; `indexed_blocks` has no foreign-key cascade and therefore
retains searchable rows belonging to removed pages. A direct App Store test
can demonstrate this without a fault seam or any production edit.

The initial-import aggregate Search notification gap remains real but larger:
suppressed import writes occur through page and block APIs that do not return a
truthful actor-level aggregate receipt, and some failures are currently logged
and swallowed. That work remains explicit debt; an import snapshot alone must
not be misrepresented as proof that both derived indexes changed successfully.

Before production changes, add one test only: seed a page and its owned block,
verify both are searchable, run the existing async rebuild with an empty page
source, verify the page is removed, and require the block to be removed. The
expected current red is exactly the surviving block. Execute it only after a
fresh complete 16-GiB preflight and retain the exact result/log/app identity
before deleting the disposable build tree.

### Pre-execution debt-selection correction — initial-import Search ownership

Before any test or build ran, the delayed design review proved the preferred
initial-import Search gap is deterministic. The provisional rebuild-first
selection above is therefore superseded for the next red leg; its unexecuted
test draft is removed, while the rebuild-orphan defect remains explicit later
debt.

The selected red imports one unique note with page and block tokens while
Search notifications are suppressed, proves both projections committed with
zero notification, proves a subsequent direct diff is unchanged, then invokes
the current owned diff wrapper and requires one awaited notification with both
Search dependencies. Current source should return success but publish nothing,
so the expected red is one empty-versus-union dependency-snapshot failure. No
production correction is authorized before that exact result is captured
under a fresh complete 16-GiB preflight.

### Initial-import Search Red8 attempt A — harness compilation rejection

The fresh preflight passed with exact local/remote/handoff SHA
`668b52cfb43721de95db102260d9f327ae24e13e`, 112 dirty entries, 8,926.19 MiB
swap, 72% free memory, zero throttled pages, 728 GiB available disk, no
competing scoped process, and empty app/archive inventory. Exactly one serial
focused build then ran, but no test executed: Swift rejected the observer
closure for sending its task-isolated `Notification` argument to the
default-main-actor `QueryDependencyKey.from` method.

The retained result is
`build/xcode-results/2026-07-14-initial-search-receipt-red8-16gib.xcresult`;
direct summary reports zero tests and result `unknown`. The retained log is
`build/xcode-results/2026-07-14-initial-search-receipt-red8-16gib.log`, with
SHA-256 `74e48c04807269500ecdf57b2c590247577c3a105ee8b04453fe6a1fc456f3ec`.
The disposable app executable was 40,344 bytes with SHA-256
`51b811f0a971612b17cb39106ef6aa483e5821a427cb903cb57b15d448b5a400`;
the bundle occupied 479,084 KiB.

This is a test-harness rejection, not product-behavior evidence, and it
authorizes no production correction. After identity capture, the complete
build tree was deleted. Final inventory was empty; resources were 8,918.19 MiB
swap, 67% free memory, zero throttled pages, and 728 GiB available disk. The
next action is one harness-only isolation correction followed by the same
single focused test after a new complete 16-GiB preflight.

### Initial-import Search Red8B — aggregate dependency ownership failure

After the harness-only correction, a second complete preflight passed with the
same exact Git identity, 112 dirty entries, 8,918.19 MiB swap, 67% free memory,
zero throttled pages, 728 GiB available disk, no competing scoped process, and
empty app/archive inventory. Exactly one serial focused test then ran.

The import committed both a searchable page projection and a searchable owned
block projection while observer notifications were suppressed. No notification
fired during import. A direct suppressed diff returned zero upserts, zero page
deletes, zero block deletes, and empty dependencies. The owned diff repeated
that zero-change result and returned success. The sole failing assertion was
the final dependency snapshot: observed `[]`, required one
`searchBlocks,searchPages` notification.

The retained result is
`build/xcode-results/2026-07-14-initial-search-receipt-red8b-16gib.xcresult`.
Direct summary reports one total, zero passed, one failed, zero expected
failures, and zero skipped on an arm64 MacBook Pro running macOS 26.3.1. The
retained log is
`build/xcode-results/2026-07-14-initial-search-receipt-red8b-16gib.log`, with
SHA-256 `76dcae1237dc03481481e2f6e1a4ae06bfdcdae99dfc0c5fd4155ea665c39650`.

The disposable app executable was 40,344 bytes with SHA-256
`e4e0941945db0dd7da22bfff5de92a3b1ee1106739476effbee770cd7b72c03c`;
the bundle occupied 490,088 KiB. Immediate post-run resources were 9,403.81 MiB
swap, 70% free memory, zero throttled pages, and 726 GiB available disk. After
identity capture, the complete build tree was deleted. Final inventory was
empty; resources were 9,347.81 MiB swap, 70% free memory, zero throttled pages,
and 728 GiB available disk.

Red8B authorizes only truthful committed Search mutation receipts, suppressed
import accumulation with fail-closed invalidation, successful-diff merge, one
awaited union notification, and consume-after-publication ownership. It does
not authorize rebuild-orphan, global correlation, Eidos, Spotlight, Recall,
archive/runtime, feature/canon, payment, model/provider/secret/audio, or
owner-vault work.

### Initial-import Search Red8 correction — pre-Green source checkpoint

The bounded production correction is now prepared but has not been compiled.
Page upsert, block replacement, and atomic page/block deletion return typed
committed mutation receipts. `VaultIndexActor` binds those receipts to one
explicit Search service, batch ID, and revision; swallowed Search failures make
the batch invalid instead of permitting a source-derived success claim.

The owned diff leg now seals the exact import-plus-diff receipt before an
awaited notification. The pending batch is consumed only after the lifecycle-
checked notification succeeds. If that publication is vetoed, the sealed diff
and import receipt remain available to the exact ID for retry, so retry does
not rerun the diff or silently lose its mutation domains. Search-service
replacement and same-batch mutation are rejected while the receipt is sealed.
Missing Search service remains fail-closed for initial readiness.

The App Store regression now checks the committed page/block counts, empty
direct diff, exact dependency union, veto-without-consumption, sealed receipt
reuse, one successful publication, exact consumption, and no second
publication from the consumed ID. Related timestamp-failure, initial-pipeline,
atomic-deletion, and broader cleanup source guards were updated to the typed
contract. `git diff --check` passes and no obsolete production global Search
notification-suppression symbol remains.

This is not Green evidence. No post-correction compiler, test, archive, app
launch, owner-vault, model/provider/secret/audio, or runtime action has begun.
Page-only rebuild orphan cleanup, global notification correlation, broader
receipts, and the Release/runtime matrix remain open. The exact next executable
action is one fresh serial focused Green batch, and it may begin only after the
complete locked 16-GiB preflight passes.

### Initial-import Search Green8 preflight

The fresh preflight passed. After fetching origin, branch
`feat/goose-surface`, local HEAD, fetched `origin/feat/goose-surface`, and the
handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count is 112 and
`git diff --check` passes.

Resources are 9,267.81 MiB swap used, 73% free memory, zero throttled pages,
and 728 GiB available disk. No scoped Xcode/compiler/model/Epistemos process
is active. No Epistemos app product or archive exists in the disposable temp
locations, DerivedData, repository build tree, or Xcode Archives; there was no
stale product to remove.

One serial twenty-test App Store batch is authorized: all nineteen Green7
tests plus `appStoreInitialImportPublishesCommittedSearchDependenciesOnce()`.
It will use a new disposable DerivedData path and a new retained result/log;
no archive, launch, owner-vault, provider/model/secret/audio, or other build is
authorized by this preflight.

### Initial-import Search Green8 — combined focused evidence

Exactly one serial twenty-test batch ran into:

`build/xcode-results/2026-07-14-initial-search-receipt-green8-16gib.xcresult`

Its retained log is:

`build/xcode-results/2026-07-14-initial-search-receipt-green8-16gib.log`

The log SHA-256 is
`1722b3e93c960f522201fe67eb4867e60e7d6852dca42388da5a967352ebd96f`.
Direct result inspection reports twenty total, twenty passed, zero failed,
zero expected failures, and zero skipped. The result is `Passed` on an arm64
MacBook Pro running macOS 26.3.1.

The new test proves the initial import committed one Search page projection
and positive block projection receipts without observer publication. Its
owned diff was empty. A lifecycle veto then produced no notification and did
not consume the batch; the sealed diff remained exact. Retrying the same batch
published one `searchBlocks,searchPages` union, consumed the exact batch, and
a repeated call with the consumed ID produced no second publication. The
nineteen prior Green7 tests also remained green.

The disposable app is exactly:

`/private/tmp/Epistemos-InitialSearchReceiptGreen8-16GiB/Build/Products/Debug/Epistemos.app`

Its executable is 40,344 bytes with SHA-256
`4d8c9241173b453421f6c94f08a209989144fb91471e5dbd9a72660da5cd1273`;
the app bundle occupies 490,368 KiB. Immediate post-run resources are
9,557.31 MiB swap, 69% free memory, zero throttled pages, and 726 GiB
available disk. No scoped compiler, model, or Epistemos test host remains;
dirty count is 112 and `git diff --check` passes.

Green8 closes the exact Red8B defect under this selected App Store evidence
set. It does not close the non-App-Store broad test debt, page-only rebuild
orphan blocks, global notification correlation, broader Search/Spotlight
receipts, Release artifact gates, manual runtime proof, or the finite Free V1
matrix. The disposable build must now be removed before any later build.

After recording the exact identity, the complete disposable Green8 build tree
was deleted. The retained result and log remain. Final app/archive inventory is
empty across the disposable temp locations, DerivedData, repository build
tree, and Xcode Archives. Final resources are 9,549.31 MiB swap, 69% free
memory, zero throttled pages, and 728 GiB available disk. No scoped compiler,
model, or Epistemos process is active; dirty count remains 112 and
`git diff --check` passes.

## Updated KEELSTONE Verdict — Green8 Search Receipt Checkpoint

**INCOMPLETE**

Reason: Green8 closes the exact initial-import Search aggregate-notification
defect under twenty selected App Store tests, but broad non-App-Store tests,
page-only rebuild block reconciliation, global notification correlation,
remaining Search/Spotlight receipt ownership, dual-lane Spotlight proof,
authoritative full-rescan/manual-sync breadth, structural mutation/recovery,
Release archive and artifact gates, manual runtime behavior, and the finite
Free V1 matrix remain open. No subsequent canonical execution key is started
or recommended.

### Page-only Search rebuild Red9 preflight

The test-first regression is present and production remains unchanged for this
leg. It seeds one indexed page and one owned block, proves both exact IDs are
searchable, runs the existing asynchronous full rebuild with an empty
authoritative page source, then requires both exact IDs to be absent. Current
source is expected to remove the page but leave the block searchable because
the full rebuild does not reconcile `indexed_blocks`.

The fresh complete preflight passed. After fetching origin, branch
`feat/goose-surface`, local HEAD, fetched `origin/feat/goose-surface`, and the
handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count is 112 and
`git diff --check` passes.

Swap used is 9,533.31 MiB, strictly below the locked 16,384-MiB ceiling;
system free memory is 71%; pages throttled are zero; and available disk is
727 GiB. No competing scoped Xcode/compiler/model/Epistemos process is
active. App/archive inventory is empty across the new disposable path,
`/private/tmp`, Xcode DerivedData, the repository build tree, and Xcode
Archives. The new result-bundle path is also absent.

Exactly one serial test is authorized:
`appStoreFullSearchRebuildRemovesBlocksOwnedByRemovedPages()`. It will use
`/private/tmp/Epistemos-SearchRebuildRed9-16GiB` and retain its result/log at
`build/xcode-results/2026-07-14-search-rebuild-orphan-red9-16gib.*`. No
production correction, second build, archive, launch, owner-vault access,
model/provider/secret/audio work, feature/canon phase, or subsequent execution
key is authorized by this preflight.

### Page-only Search rebuild Red9 — exact orphan-block survival

Exactly one serial test executed. Direct result-bundle inspection reports
result `Failed`: one total, zero passed, one failed, zero expected failures,
and zero skipped on an arm64 MacBook Pro running macOS 26.3.1. The seeded page
and owned block were both searchable before rebuild. Rebuilding from an empty
authoritative page source removed the exact page ID. The sole failure was the
final exact-ID assertion because the same block ID and owner page ID remained
searchable.

The runtime initialized the temporary Search database with page, block, and
readable-block FTS5 features unavailable, so this executable proof exercised
the plain-table fallback query path. The current-source review independently
shows the same stale row remains an external-content FTS source when FTS5 is
available because the block-delete trigger never fires. This evidence proves
the stale `indexed_blocks` row and fallback-visible behavior; it does not
overclaim an executed FTS5 configuration.

The retained result is:

`build/xcode-results/2026-07-14-search-rebuild-orphan-red9-16gib.xcresult`

The retained log is:

`build/xcode-results/2026-07-14-search-rebuild-orphan-red9-16gib.log`

Its SHA-256 is
`55184b247636a93876af180bea6dde79c007f74850ea3d09a6332ed6a53e802e`.
The disposable app executable is 40,344 bytes with SHA-256
`b75068400509b07b84f1918917da81d1fb6a607f4b9939325d80f98d83669b16`;
the bundle occupies 490,388 KiB at
`/private/tmp/Epistemos-SearchRebuildRed9-16GiB/Build/Products/Debug/Epistemos.app`.

Immediate post-run resources are 9,899.62 MiB swap, 70% free memory, zero
throttled pages, and 725 GiB available disk. No scoped compiler, model, or
Epistemos process remains. Dirty count is 112 and `git diff --check` passes.

Red9 authorizes only one transactional orphan-block reconciliation after the
replacement page set is inserted, reuse of the existing set-based cleanup
logic, and block dependency invalidation only when a committed block row was
removed. It does not authorize wholesale block truncation, a schema migration,
initial-import changes, manual-rebuild source-fetch semantics, Eidos,
Spotlight, Recall, global notification correlation, archive/runtime,
feature/canon, payment, model/provider/secret/audio, or owner-vault work.
Before production editing, the exact disposable Red9 build tree must be
deleted and empty inventory restored.

The complete disposable Red9 build tree was deleted after identity capture.
The retained `.xcresult` and log remain. App/archive inventory is empty across
the disposable temp locations, Xcode DerivedData, repository build tree, and
Xcode Archives. Final cleanup resources are 9,875.62 MiB swap, 70% free
memory, zero throttled pages, and 727 GiB available disk. No scoped compiler,
model, or Epistemos process is active; dirty count remains 112 and
`git diff --check` passes.

### Page-only Search rebuild correction — pre-Green source checkpoint

The bounded production correction is prepared but has not been compiled.
`rebuildFromSwiftData` now reinserts the complete authoritative page set and
then deletes only block rows whose `page_id` has no matching replacement page,
all inside its existing database write transaction. The set-based orphan SQL
is extracted into one helper and reused by diff sync; no duplicate cleanup SQL
or schema migration was introduced.

The committed orphan deletion count adds `.searchBlocks` to the rebuild's
existing single post-commit page invalidation only when at least one block row
was removed. Public rebuild signatures, background offload, checkpoint
behavior, Settings caller, Eidos mirroring, initial-import receipts, and other
subsystems are unchanged.

The regression is strengthened with one removed page/block pair and one
retained page/block pair. Both pairs must be searchable before rebuild; after
rebuild, the removed exact IDs must be absent and the retained exact IDs must
remain. This rejects wholesale block truncation, cleanup before replacement
page insertion, and cleanup before old-page removal. Two independent read-only
reviews found no correction or Swift compile seam; `git diff --check` passes.

Runtime proof remains absent until Green. In particular, the block dependency
payload is source-reviewed but not independently observer-correlated, and the
manual rebuild caller's empty-on-source-read-failure behavior plus a possible
post-commit checkpoint failure remain explicit later debt. The exact next
executable action is one fresh twenty-one-test App Store batch: the complete
Green8 selection plus the rebuilt orphan regression. It requires a new full
16-GiB preflight and empty current-build inventory first.

### Page-only Search rebuild Green9 preflight

The fresh preflight passed. After fetching origin, branch
`feat/goose-surface`, local HEAD, fetched `origin/feat/goose-surface`, and the
handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count is 112 and
`git diff --check` passes.

Swap used is 9,859.62 MiB, strictly below the locked 16,384-MiB ceiling;
system free memory is 70%; pages throttled are zero; and available disk is
727 GiB. No competing scoped Xcode/compiler/model/Epistemos process is active.
App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
repository build tree, and Xcode Archives. The new disposable DerivedData and
result-bundle paths are absent.

One serial twenty-one-test App Store batch is authorized: all twenty Green8
tests plus
`appStoreFullSearchRebuildRemovesBlocksOwnedByRemovedPages()`. It will use
`/private/tmp/Epistemos-SearchRebuildGreen9-16GiB` and retain result/log paths
under `build/xcode-results/2026-07-14-search-rebuild-orphan-green9-16gib.*`.
No overlapping build, archive, launch, owner-vault access, model/provider/
secret/audio work, feature/canon phase, or subsequent execution key is
authorized.

### Green14 rerun executed — warning persists

The validated serial rerun exited zero. Direct summary inspection reports
`Passed`: twenty-five total tests, twenty-five passed, zero failed, zero
skipped, and zero expected failures. Direct test-node inspection agrees and
the console contains one twenty-five-test pass plus `TEST SUCCEEDED`. All
fifteen Search initializations report
`fts5_pages=true fts5_blocks=true fts5_readable_blocks=true`; the log contains
zero false flags, read-only optimizer errors, SQLite client/vnode/descriptor
violations, notification-rate text, failure markers, or priority-inversion
text.

The direct result-node audit nevertheless contains exactly one `Runtime
Warning`, again under
`appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()` at source line
4750: a User-interactive thread waited on a Utility-QoS thread. Targeted test
details report the test passed in 0.073 seconds and serialize the same warning.
This disproves the bounded theory that directly awaiting the stored detached
task handle alone would make the dependency warning-free. Green14 is red for
its explicit zero-runtime-warning bar, and no archive is authorized.

Direct build-result inspection reports a succeeded build with zero errors and
the same three separate warnings: Rust `block` 0.1.6 future incompatibility,
an unnecessary `await` in `TextCapturePipeline.swift`, and an unused `try?`
result in `LiteParsePDFImportController.swift`.

The retained 1,515,761-byte log is
`build/xcode-results/2026-07-14-watcher-drain-priority-green14-rerun-16gib.log`
with SHA-256
`c75e36df41ad1aadd321cac3663563b52c4d401d433d9f173e759cea8294c507`.
The retained result occupies 137,440 KiB. Before cleanup, the disposable app
occupies 475,784 KiB; its 40,344-byte arm64 executable has SHA-256
`7b8cc40bc3ffaea36d5fcc2fb523dd7789aeaaa189ea09e47037519ab07aa912`,
bundle identifier `com.epistemos.appstore`, build `1`, and version `1.0.0`.
The exact build-created universal arm64/x86_64 graph archive is 928,375,752
bytes with SHA-256
`3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`;
universal, arm64, and x86_64 `_sqlite3_*` export counts and the independent
SQLite string count are all zero.

Post-run resources are 12,093.06 MiB swap used, 66% free memory, zero
throttled pages, and 671 GiB available disk. No competing process remains;
dirty count is 117 and the diff check passes. Exact next action is to delete
only the disposable rerun DerivedData/app and staged graph archive while
retaining the failed result/log, verify empty broad product inventory, and
perform a new read-only causal trace. No additional source edit, test, build,
archive, launch, runtime matrix, canon/feature work, or later execution key is
authorized by this failed leg.

The exact disposable Green14 rerun DerivedData/app and staged graph archive
were deleted after identity capture. Both paths are absent and broad
app/archive inventory is zero. The red result remains 137,440 KiB and its log
digest re-verifies as
`c75e36df41ad1aadd321cac3663563b52c4d401d433d9f173e759cea8294c507`.
Cleanup resources are 12,093.06 MiB swap used, 60% free memory, and zero
throttled pages; dirty count remains 117 and the diff check passes. The only
safe continuation is read-only causal analysis of the retained warning.

### Page-only Search rebuild Green9 — combined focused evidence

Exactly one serial twenty-one-test App Store batch completed with result
`Passed`. Direct result-bundle inspection reports twenty-one total,
twenty-one passed, zero failed, zero expected failures, and zero skipped on an
arm64 MacBook Pro running macOS 26.3.1.

The new regression proves both removed and retained page/block pairs were
searchable before rebuild. After rebuilding from the one retained page
snapshot, the removed exact page and block IDs were absent while the retained
exact page and block IDs remained searchable. This rejects wholesale block
truncation and cleanup before replacement-page insertion. The twenty prior
Green8 tests also remained green, including diff orphan cleanup, public atomic
page/block deletion and rollback, required Search read failures, initial-import
receipt ownership, watcher/Recall fencing, and Spotlight source ownership.

The retained result is:

`build/xcode-results/2026-07-14-search-rebuild-orphan-green9-16gib.xcresult`

The retained log is:

`build/xcode-results/2026-07-14-search-rebuild-orphan-green9-16gib.log`

Its SHA-256 is
`9ed17d263462360e2d5a5108036afd34640d8c6412ddb80192084ad95d68a92d`.
The disposable app executable is 40,344 bytes with SHA-256
`05121bf186de5a721deacfb901b155718276b11aac60d5861b94ea055898619c`;
the app bundle occupies 490,396 KiB at
`/private/tmp/Epistemos-SearchRebuildGreen9-16GiB/Build/Products/Debug/Epistemos.app`.

Immediate post-run resources are 9,859.62 MiB swap, 69% free memory, zero
throttled pages, and 725 GiB available disk. No scoped compiler, model, or
Epistemos process remains; dirty count is 112 and `git diff --check` passes.

Green9 closes the exact Red9 page-only rebuild orphan-block defect under this
selected App Store evidence set. It does not prove an FTS5-enabled executable
configuration, separately correlated notification payload/timing, fail-closed
manual rebuild source acquisition, post-commit checkpoint recovery, Eidos
deletion reconciliation, broad non-App-Store tests, remaining Spotlight/
Search receipts, Release artifact gates, manual runtime behavior, or the Free
V1 matrix. The exact disposable Green9 build must be deleted after this
identity capture before any later build.

After identity capture, the complete disposable Green9 build tree was deleted.
The retained `.xcresult` and log remain. App/archive inventory is empty across
the disposable temp locations, Xcode DerivedData, repository build tree, and
Xcode Archives. Final resources are 9,859.62 MiB swap, 69% free memory, zero
throttled pages, and 727 GiB available disk. No scoped compiler, model, or
Epistemos process is active; dirty count remains 112 and `git diff --check`
passes.

## Updated KEELSTONE Verdict — Green9 Search Rebuild Checkpoint

**INCOMPLETE**

Reason: Green9 closes the exact page-only Search rebuild orphan-block defect
under twenty-one selected App Store tests, but broad non-App-Store tests,
fail-closed manual rebuild source acquisition, Search notification correlation,
remaining Search/Spotlight receipt ownership, dual-lane Spotlight proof,
authoritative full-rescan/manual-sync breadth, structural mutation/recovery,
Release archive and artifact gates, manual runtime behavior, and the finite
Free V1 matrix remain open. No subsequent canonical execution key is started
or recommended.

The exact next action is read-only comparison of the remaining Keelstone debts,
beginning with the newly exposed manual full-rebuild source-read ambiguity and
the recorded notification/Spotlight receipt gaps. No further build is
authorized until a new intent checkpoint and complete 16-GiB preflight exist.

### Manual Search rebuild source failure — pre-Red10 source checkpoint

Read-only comparison selected the Settings/manual full Search rebuild source
ambiguity ahead of global notification correlation and Spotlight receipts.
`VaultIndexActor.allPagesForRebuild()` still maps a failed required derived-
page fetch to `[]`; the actual Settings owner, `VaultSyncService.rebuildIndex()`,
still passes that array to the destructive full rebuild. Production behavior
is intentionally unchanged for Red10.

The test-only harness generalizes the existing DEBUG derived-rebuild failure
switch and adds a DEBUG service forwarder to the service's private actor. The
new App Store test uses the actual `rebuildIndex()` caller. It requires the
fault seam and seeded page/block projections to exist, observes the rebuild's
synchronous indexing admission, waits up to five seconds for completion, then
requires the exact page and page-owned block to survive. A bounded main-actor
drain also observes whether a Search update notification was published.

Current source is expected to fail the two exact projection-survival
expectations because the forced failed source read becomes an authoritative
empty rebuild. Green9's orphan reconciliation makes the block deletion follow
the page deletion. Notification publication is observed in this isolated test
window but is not claimed as globally service-correlated; that broader design
remains separate debt.

Two independent read-only reviews confirmed that the actual Settings owner is
exercised, production remains unfixed, actor isolation is sound, and the fault
seam is omitted from the App Store Release product configuration. They also
required hard setup/completion gates so a missing actor, failed seed, or still-
running rebuild cannot imitate the target defect; those gates are present.
Running the test target itself under a non-DEBUG configuration remains
unproven and predates Red10 through the existing Recall fault-seam test.

`git diff --check` passes. No compiler, test, archive, app launch, owner-vault,
model/provider/secret/audio, runtime, feature/canon, payment, or subsequent-key
operation has begun. The exact next action is the complete locked 16-GiB
preflight; only if every gate passes may one selected Red10 test build run.

### Manual Search rebuild Red10 preflight

The complete preflight passed at 2026-07-13 22:36 CDT. After fetching origin,
branch `feat/goose-surface`, local HEAD, fetched
`origin/feat/goose-surface`, and the handoff publication commit all resolve to
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count is 112 and
`git diff --check` passes.

Swap used is 9,827.62 MiB, strictly below the owner-locked 16,384-MiB ceiling;
system free memory is 72%; pages throttled are zero; and available disk is
727 GiB. No competing scoped Xcode/compiler/model/Epistemos process is active.
App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
repository build tree, and Xcode Archives. The new disposable DerivedData,
result-bundle, and log paths are absent.

Exactly one selected App Store test build is authorized:
`appStoreManualSearchRebuildSourceFailureCannotEraseProjections()`. It will use
`/private/tmp/Epistemos-ManualSearchRebuildRed10-16GiB` and retain its result
and log under
`build/xcode-results/2026-07-13-manual-search-rebuild-source-red10-16gib.*`.
No production correction, second build, archive, launch, owner-vault,
model/provider/secret/audio, runtime, feature/canon, payment, or subsequent-key
operation is authorized by this preflight.

### Manual Search rebuild Red10 — failed source treated as empty vault

Exactly one serial selected test executed. Direct result-bundle inspection
reports result `Failed`: one total, zero passed, one failed, zero expected
failures, and zero skipped on an arm64 MacBook Pro running macOS 26.3.1.

The test successfully installed the DEBUG source-failure seam and required the
seeded exact page and page-owned block to be searchable before invoking the
same `VaultSyncService.rebuildIndex()` used by Settings. The service logged the
forced required derived-rebuild source failure, then current production rebuilt
the Search index with zero pages. After owned task completion, the exact page
was absent, the exact block was absent, and the isolated observer had received
one Search update. The test recorded those exact three expectation issues and
no setup, compile, seed, timeout, or unrelated-test failure.

The retained result is:

`build/xcode-results/2026-07-13-manual-search-rebuild-source-red10-16gib.xcresult`

The retained log is:

`build/xcode-results/2026-07-13-manual-search-rebuild-source-red10-16gib.log`

Its SHA-256 is
`34c8b0842980fd9e336a742276239f138c87b6f8289295623e5e9a3db24ca032`.
The disposable app executable is 40,344 bytes with SHA-256
`ba15451fbe65804f19fccd6301795d63af2b9bc3ec1bc9bacad6257c1073d61a`;
the bundle occupies 490,468 KiB at
`/private/tmp/Epistemos-ManualSearchRebuildRed10-16GiB/Build/Products/Debug/Epistemos.app`.

Immediate post-run resources are 9,795.62 MiB swap, 68% free memory, zero
throttled pages, and 725 GiB available disk. No scoped compiler, model, or
Epistemos process remains. Dirty count is 112 and `git diff --check` passes.

Red10 proves only the destructive manual source-read ambiguity and its
uncorrelated notification within this isolated window. It authorizes a
distinct optional required Search-rebuild source read and a guard before the
actual rebuild. It does not authorize global notification identity,
checkpoint recovery, Eidos, Spotlight, Recall, schema work, archive/runtime,
Free V1, feature/canon, payment, model/provider/secret/audio, owner-vault, or a
subsequent key. The complete disposable build must be removed before production
editing.

The complete disposable Red10 build tree was deleted after exact identity
capture. Its retained result and log remain. App/archive inventory is empty
across `/private/tmp`, Xcode DerivedData, the repository build tree, and Xcode
Archives. Final cleanup resources are 9,795.62 MiB swap, 68% free memory, zero
throttled pages, and 727 GiB available disk. No scoped compiler, model, or
Epistemos process is active; dirty count is 112 and `git diff --check` passes.
The bounded fail-closed source correction is now authorized, but no Green build
may begin before another complete 16-GiB preflight.

### Manual Search rebuild correction — pre-Green10 source checkpoint

The bounded production correction is prepared but has not been executed.
`VaultIndexActor.requiredPagesForSearchRebuild()` returns the existing optional
derived-page source directly. The compatibility `allPagesForRebuild()` API is
unchanged. `VaultSyncService.rebuildIndex()` now guards the required optional
before calling the destructive rebuild: `nil` logs and returns without Search
mutation or notification, while a successful `.some([])` still performs a
legitimate empty-vault rebuild.

The rebuild task now restores `isIndexing` from its existing `defer`, covering
source failure, success, and thrown rebuild error. The Settings button still
calls the same owner. Search schema, rebuild transaction, notification
implementation, Eidos, Recall, diff sync, initial import, and checkpoint
semantics are unchanged.

Two independent read-only reviews found no actionable correction or compile
seam. The Green test retains hard fault-installation, seed, admission, and task-
completion requirements; bounded drains before observer installation and after
completion reduce leakage from the known globally uncorrelated notification
channel. `git diff --check` passes.

This is not Green evidence. The exact next executable action is one fresh
serial twenty-two-test App Store batch containing the complete Green9 selection
plus the Red10 regression, and it may begin only after another complete locked
16-GiB preflight passes with empty app/archive inventory.

### Manual Search rebuild Green10 preflight

The complete fresh preflight passed at 2026-07-13 22:45 CDT. After fetching
origin, branch `feat/goose-surface`, local HEAD, fetched
`origin/feat/goose-surface`, and the handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count is 112 and
`git diff --check` passes.

Swap used is 9,795.62 MiB, strictly below the locked 16,384-MiB ceiling;
system free memory is 69%; pages throttled are zero; and available disk is
727 GiB. No competing scoped Xcode/compiler/model/Epistemos process is active.
App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
repository build tree, and Xcode Archives. The new disposable DerivedData,
result-bundle, and log paths are absent.

Exactly one serial twenty-two-test App Store batch is authorized: the complete
twenty-one-test Green9 selection plus
`appStoreManualSearchRebuildSourceFailureCannotEraseProjections()`. It will use
`/private/tmp/Epistemos-ManualSearchRebuildGreen10-16GiB` and retain result/log
paths under
`build/xcode-results/2026-07-13-manual-search-rebuild-source-green10-16gib.*`.
No overlapping build, archive, launch, owner-vault, runtime, feature/canon,
payment, model/provider/secret/audio, or subsequent-key action is authorized.

### Manual Search rebuild Green10 — combined focused evidence

Exactly one serial twenty-two-test App Store batch completed and
`xcodebuild` exited zero with `** TEST SUCCEEDED **`. Direct result-bundle
inspection reports result `Passed`: twenty-two total, twenty-two passed, zero
failed, zero expected failures, and zero skipped on an arm64 MacBook Pro
running macOS 26.3.1.

The new regression exercised the real Settings/manual `rebuildIndex()` owner
with the required derived-page read forced to fail. The exact seeded Search
page and page-owned block remained searchable and the isolated observation
window received zero Search update notifications. The complete twenty-one-test
Green9 selection remained green in the same build, including required Search
read failures, page/block deletion and rollback, full-rebuild orphan cleanup,
initial-import receipt ownership, watcher/Recall fencing, and typed Spotlight
source ownership.

The retained result is:

`build/xcode-results/2026-07-13-manual-search-rebuild-source-green10-16gib.xcresult`

The retained log is:

`build/xcode-results/2026-07-13-manual-search-rebuild-source-green10-16gib.log`

Its SHA-256 is
`65a8dfc905fd6964d65335a83d0f51a55be99931eb442043f3f9d36b14793e69`.
The disposable app executable is 40,344 bytes with SHA-256
`6e3c6d2ff7a20a1d5f3988c23a51af4c04472401b84ce3a5db16191a217b9e95`;
the app bundle occupies 490,472 KiB at
`/private/tmp/Epistemos-ManualSearchRebuildGreen10-16GiB/Build/Products/Debug/Epistemos.app`.

Immediate post-run resources are 9,795.62 MiB swap, 70% free memory, zero
throttled pages, and 725 GiB available disk. No scoped Xcode/compiler/model/
Epistemos process remains. Dirty count is 112, `git diff --check` passes, and
local HEAD still equals fetched `origin/feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`.

Green10 closes the exact Red10 manual Search rebuild source-acquisition defect
under this selected App Store evidence set. It does not prove an FTS5-enabled
executable configuration, globally correlated Search notifications,
post-commit checkpoint recovery, Eidos deletion reconciliation, remaining
Spotlight receipts and dual-lane ownership, broad non-App-Store tests, Release
artifact gates, manual runtime behavior, or the finite Free V1 matrix. The
complete disposable Green10 build must be deleted after this identity capture
before any later build.

After exact identity capture, the complete disposable Green10 build tree was
deleted. Its retained result bundle and log remain. App/archive inventory is
empty across `/private/tmp`, Xcode DerivedData, the repository build tree, and
Xcode Archives. Final cleanup resources are 9,763.62 MiB swap, 70% free
memory, zero throttled pages, and 726 GiB available disk. No scoped Xcode/
compiler/model/Epistemos process is active; dirty count remains 112 and
`git diff --check` passes.

## Updated KEELSTONE Verdict — Green10 Manual Search Rebuild Checkpoint

**INCOMPLETE**

Reason: Green10 closes the exact failed-source-as-empty manual Search rebuild
defect under twenty-two selected App Store tests, but FTS5-enabled executable
proof, Search notification correlation, post-commit checkpoint recovery,
Eidos deletion reconciliation, remaining Search/Spotlight receipt ownership,
dual-lane Spotlight proof, broad non-App-Store tests, authoritative full-
rescan/manual-sync breadth, structural recovery, Release archive and artifact
gates, manual runtime behavior, and the finite Free V1 matrix remain open. No
subsequent canonical execution key is started or recommended.

The exact next action is read-only comparison of the remaining bounded
Keelstone debts. No additional build or source edit is authorized until the
next debt has its own owner-intent checkpoint, test-first boundary, and fresh
complete 16-GiB preflight.

### Post-commit Search checkpoint failure — pre-Red11 source checkpoint

Read-only comparison selected the full Search rebuild's post-commit checkpoint
failure ahead of global notification correlation and Spotlight receipts. The
rebuild transaction commits before `truncateCheckpoint()`. A later checkpoint
error currently escapes as logical rebuild failure and prevents the existing
Eidos mirror and Search invalidation from running. The sibling `diffSync` path
already catches and logs equivalent post-commit checkpoint maintenance errors.

The checkpoint's `last_truncate_checkpoint_at` success marker is also written
before the actual truncate operation. A checkpoint failure can therefore leave
misleading success telemetry. The smallest Red11 harness is one DEBUG-gated
forced failure at the real checkpoint boundary and one actual full-rebuild
behavior test. Production behavior must remain otherwise unchanged for Red11.

Red11 must prove the replacement transaction committed, the removed page and
owned block stayed removed, the checkpoint error still escaped, the expected
page-and-block invalidation was absent, and the checkpoint success marker
advanced despite failure. Only after that exact evidence may the checkpoint
operation precede its success marker and its post-commit error be caught so the
existing mirror/invalidation path can finish.

This leg does not authorize global notification identity, Eidos deletion,
Spotlight, FTS5 configuration, schema, archive/runtime, Free V1, feature/canon,
payment, model/provider/secret/audio, owner-vault, or a subsequent execution
key. No build is authorized until the behavior-preserving harness and test are
re-read, `git diff --check` passes, and a fresh complete locked 16-GiB
preflight passes.

The behavior-preserving Red11 harness is now prepared. A `#if DEBUG`-gated
`Mutex<Bool>` fault switch throws at the actual truncate-checkpoint boundary
after the current success-marker write. Release omits the storage, setter, and
injected branch; the default false path is unchanged.

The new selected test seeds one exact page and owned block, records the current
checkpoint marker, enables the fault, and performs the actual async full
rebuild to one replacement page. It expects the checkpoint error not to escape,
the committed replacement to exist, the old page and block to be absent, one
`searchBlocks,searchPages` invalidation, and an unchanged checkpoint marker.
Current unfixed source is expected to fail exactly the no-escape, notification,
and marker expectations while the three committed-state assertions pass.

An independent read-only review found no actionable seam, Release-boundary,
actor-isolation, syntax, determinism, or test-meaning issue and confirmed that
no correction slipped into Red11. `git diff --check` passes. No compiler, test,
build, archive, launch, owner-vault, runtime, feature/canon, payment,
model/provider/secret/audio, or subsequent-key action has begun. The exact next
action is the complete fresh 16-GiB preflight; only if every gate passes may
one selected Red11 test build run.

### Post-commit Search checkpoint Red11 preflight

The complete fresh preflight passed at 2026-07-13 23:01 CDT. After fetching
origin, branch `feat/goose-surface`, local HEAD, fetched
`origin/feat/goose-surface`, and the handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count is 112 and
`git diff --check` passes.

Swap used is 9,763.62 MiB, strictly below the owner-locked 16,384-MiB ceiling;
system free memory is 71%; pages throttled are zero; and available disk is
726 GiB. No competing scoped Xcode/compiler/model/Epistemos process is active.
App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
repository build tree, and Xcode Archives. The disposable DerivedData,
result-bundle, and log paths are absent.

Exactly one selected App Store test build is authorized:
`appStoreCommittedSearchRebuildSurvivesCheckpointMaintenanceFailure()`. It
will use `/private/tmp/Epistemos-SearchCheckpointRed11-16GiB` and retain its
result and log under
`build/xcode-results/2026-07-13-search-checkpoint-postcommit-red11-16gib.*`.
No production correction, second build, archive, launch, owner-vault, runtime,
feature/canon, payment, model/provider/secret/audio, or subsequent-key action
is authorized by this preflight.

### Post-commit Search checkpoint Red11 — exact committed-maintenance split

Exactly one serial selected test executed. Direct result-bundle inspection
reports result `Failed`: one total, zero passed, one failed, zero expected
failures, and zero skipped on an arm64 MacBook Pro running macOS 26.3.1. Direct
test-detail inspection reports exactly three issues and a 0.23-second test run.

The replacement page assertion passed, and the old exact page and page-owned
block were both absent after the call, proving the full rebuild transaction had
committed. The three issues were exactly the intended post-commit maintenance
defect: the forced checkpoint error escaped, the isolated observer received no
`searchBlocks,searchPages` invalidation, and
`last_truncate_checkpoint_at` advanced from `nil` to
`805694677.960701` despite the forced checkpoint failure. There was no setup,
compile, seed, search-state, timeout, or unrelated-test issue. The log also
reports FTS5 feature flags false on this machine, so Red11 does not supply the
still-open FTS5-enabled executable proof.

The retained result is:

`build/xcode-results/2026-07-13-search-checkpoint-postcommit-red11-16gib.xcresult`

The retained log is:

`build/xcode-results/2026-07-13-search-checkpoint-postcommit-red11-16gib.log`

Its SHA-256 is
`27dd81f4adec64bb3a6afdd8ee6d99166aa2f646b6c9507b910407bc276d001c`.
The disposable app executable is 40,344 bytes with SHA-256
`486a331be7b3b9f95342c51fdddc314fb1ebcbf160ca15a64efbd157e2dd0f31`;
the bundle occupies 490,528 KiB at
`/private/tmp/Epistemos-SearchCheckpointRed11-16GiB/Build/Products/Debug/Epistemos.app`.

Immediate post-run resources are 9,897.38 MiB swap, 67% free memory, zero
throttled pages, and 724 GiB available disk. No scoped Xcode/compiler/model/
Epistemos process remains. Dirty count is 112 and `git diff --check` passes.

Red11 authorizes only reordering the checkpoint-success marker after a
successful checkpoint and catching/logging that post-commit maintenance error
before the existing mirror/invalidation path. It does not authorize global
notification identity, Eidos deletion, Spotlight, FTS5 configuration, schema,
archive/runtime, Free V1, feature/canon, payment, model/provider/secret/audio,
owner-vault, or a subsequent key. The complete disposable Red11 build must be
deleted before production correction.

After exact identity capture, the complete disposable Red11 build tree was
deleted. Its retained result and log remain. App/archive inventory is empty
across `/private/tmp`, Xcode DerivedData, the repository build tree, and Xcode
Archives. Final cleanup resources are 9,897.38 MiB swap, 67% free memory, zero
throttled pages, and 726 GiB available disk. No scoped Xcode/compiler/model/
Epistemos process is active; dirty count remains 112 and `git diff --check`
passes. The bounded checkpoint correction is now authorized, but no Green
build may begin before source review and another complete 16-GiB preflight.

### Post-commit Search checkpoint correction — pre-Green11 source checkpoint

The bounded correction is prepared but not yet executed. Inside
`truncateCheckpoint()`, the actual `.truncate` operation now precedes the
`last_truncate_checkpoint_at` marker write. Forced or real checkpoint failure
therefore cannot record a false success marker. The DEBUG fault remains at the
actual checkpoint boundary and remains entirely omitted from Release.

The full rebuild's authoritative `dbPool.write` remains outside the new
checkpoint-only `do/catch`, so transaction, schema, and full-rebuild manifest
failures still throw and prevent downstream publication. Only the later
post-commit `truncateCheckpoint()` error is logged as maintenance failure;
the existing rebuild success log, Eidos upsert mirror, and dependency-derived
Search invalidation then continue. This matches the already non-fatal
post-commit checkpoint treatment in `diffSync` without modifying that path.

Two independent read-only reviews found no actionable transaction-boundary,
marker-order, actual/forced-checkpoint, error-propagation, actor/Mutex,
Release-gating, mirror/notification, selection, or scope issue. The complete
Green11 selection is the exact twenty-two Green10 selectors plus the Red11
regression once, for twenty-three serialized App Store tests. No extra test is
required for this bounded failure leg; broader successful-marker and true
transaction-failure suites remain separate evidence rather than silently
widening this build. The known `object:nil` notification channel remains a
separate correlation debt; suite serialization and the existing bounded
drains limit but do not erase that test risk.

`git diff --check` passes. This is source review, not Green evidence. The exact
next executable action is another complete fresh locked 16-GiB preflight. Only
if every identity, resource, process, inventory, and fresh-path gate passes may
one serial twenty-three-test Green11 App Store build run.

### Post-commit Search checkpoint Green11 preflight

The complete fresh preflight passed at 2026-07-13 23:10 CDT. After fetching
origin, branch `feat/goose-surface`, local HEAD, fetched
`origin/feat/goose-surface`, and the handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count is 112 and
`git diff --check` passes.

Swap used is 9,897.38 MiB, strictly below the locked 16,384-MiB ceiling;
system free memory is 68%; pages throttled are zero; and available disk is
726 GiB. No competing scoped Xcode/compiler/model/Epistemos process is active.
App/archive inventory is empty across `/private/tmp`, Xcode DerivedData, the
repository build tree, and Xcode Archives. The new disposable DerivedData,
result-bundle, and log paths are absent.

Exactly one serial twenty-three-test App Store batch is authorized: the exact
twenty-two Green10 selectors plus
`appStoreCommittedSearchRebuildSurvivesCheckpointMaintenanceFailure()` once.
It will use `/private/tmp/Epistemos-SearchCheckpointGreen11-16GiB` and retain
result/log paths under
`build/xcode-results/2026-07-13-search-checkpoint-postcommit-green11-16gib.*`.
No overlapping build, archive, launch, owner-vault, runtime, feature/canon,
payment, model/provider/secret/audio, or subsequent-key action is authorized.

### Post-commit Search checkpoint Green11 — combined focused evidence

Exactly one serial twenty-three-test App Store batch completed and
`xcodebuild` exited zero with `** TEST SUCCEEDED **`. Direct result-bundle
inspection reports result `Passed`: twenty-three total, twenty-three passed,
zero failed, zero expected failures, and zero skipped on an arm64 MacBook Pro
running macOS 26.3.1. Direct detail inspection reports the corrected checkpoint
regression passed in 0.22 seconds.

The forced post-commit checkpoint error was logged as maintenance failure, the
rebuild returned normally, its committed replacement remained searchable, the
old exact page and owned block remained absent, one page-and-block invalidation
arrived, and the failed checkpoint did not advance its success marker. The
successful sibling full-rebuild test also logged a completed truncate
checkpoint and passed. All twenty-two Green10 tests remained green, covering
manual/required Search source failures, diff validation and orphan cleanup,
atomic page/block deletion and rollback, initial-import receipts,
watcher/Recall fencing, and typed Spotlight source ownership.

The retained result is:

`build/xcode-results/2026-07-13-search-checkpoint-postcommit-green11-16gib.xcresult`

The retained log is:

`build/xcode-results/2026-07-13-search-checkpoint-postcommit-green11-16gib.log`

Its SHA-256 is
`db207d5c1140252b5593f39025ba08cf34e3c93211f0f85a1188dec0d0af8dc0`.
The disposable app executable is 40,344 bytes with SHA-256
`fc601fbc454297916de8c924200124e46abd17d097a40b5f76cb54178582972b`;
the app bundle occupies 490,528 KiB at
`/private/tmp/Epistemos-SearchCheckpointGreen11-16GiB/Build/Products/Debug/Epistemos.app`.

Immediate post-run resources are 10,245.19 MiB swap, 68% free memory, zero
throttled pages, and 723 GiB available disk. No scoped Xcode/compiler/model/
Epistemos process remains. Dirty count is 112, `git diff --check` passes, and
local HEAD still equals fetched `origin/feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`.

Green11 closes the exact Red11 post-commit Search checkpoint maintenance and
success-marker defect under this selected App Store evidence set. It does not
prove an FTS5-enabled executable configuration, globally correlated Search
notifications, Eidos deletion reconciliation, remaining Spotlight receipts
and dual-lane ownership, broad non-App-Store tests, Release artifact gates,
manual runtime behavior, or the finite Free V1 matrix. The complete disposable
Green11 build must be deleted after this identity capture before any later
build.

After exact identity capture, the complete disposable Green11 build tree was
deleted. Its retained result bundle and log remain. App/archive inventory is
empty across `/private/tmp`, Xcode DerivedData, the repository build tree, and
Xcode Archives. Final cleanup resources are 10,245.19 MiB swap, 68% free
memory, zero throttled pages, and 724 GiB available disk. No scoped Xcode/
compiler/model/Epistemos process is active; dirty count remains 112 and
`git diff --check` passes.

## Updated KEELSTONE Verdict — Green11 Search Checkpoint

**INCOMPLETE**

Reason: Green11 closes the full Search rebuild's exact post-commit checkpoint
maintenance and false-success-marker defect under twenty-three selected App
Store tests, but FTS5-enabled executable proof, global Search notification
correlation, Eidos deletion reconciliation, remaining Search/Spotlight receipt
ownership, dual-lane Spotlight proof, broad non-App-Store tests,
authoritative-rescan/manual-sync breadth, structural recovery, Release archive
and artifact gates, manual runtime behavior, and the finite Free V1 matrix
remain open. No subsequent canonical execution key is started or recommended.

The exact next action is read-only comparison of the remaining bounded
Keelstone debts. No additional build or source edit is authorized until the
next debt has its own owner-intent checkpoint, test-first boundary, and fresh
complete 16-GiB preflight.

### Search notification producer correlation — pre-Red12 checkpoint

The read-only comparison selected SearchIndexService page/block producer
correlation ahead of the source-only typed Spotlight receipt guard, Eidos
deletion, and FTS5 configuration. Current page/block publication posts
`.searchIndexDidUpdate` with `object: nil`. A delayed event from a retired or
different vault service is therefore indistinguishable from the active
service. `ReactiveQuery` can execute unrelated Search SQL after its 35-ms
debounce, and an HTML workspace data feed can cancel/schedule a visible refresh
against the current vault. This is a bounded performance and UI-stability risk;
it is not current evidence of data loss.

Red12 is limited to one behavior-preserving HTML test overload and one behavior
test. Two distinct file-backed Search services will be created. Service B will
perform a real awaited page `diffSync` with observer publication enabled. The
captured notification must identify B; B-bound reactive and HTML consumers must
accept it; A-bound peers must reject it. An object-nil `.searchReadable` event
must remain conservatively accepted. Current source is expected to fail exactly
the missing source identity plus the two A-bound rejection checks.

Only exact Red12 evidence may authorize the surgical correction: instance-own
the Search page/block notification helper, publish the concrete service as its
object, route the VaultSync aggregate publisher through that service, and apply
the same mismatch rejection in QueryRuntime/ReactiveQuery and the HTML feed.
Nil and non-Service producers remain accepted, so ReadableBlocks behavior is
unchanged and is not claimed correlated.

This leg does not authorize Search schema/results/receipts, debounce timing,
ReadableBlocks changes, Spotlight, Eidos, FTS5 configuration, Recall,
authoritative rescan, Release/archive/runtime, Free V1 capability, feature/
canon, payment, model/provider/secret/audio, owner-vault, private/removable
storage, or another execution key. No build is authorized until the
behavior-preserving Red12 harness is re-read, `git diff --check` passes, and a
fresh complete strict-below-16,384-MiB preflight passes.

### Search notification producer correlation — Red12 harness boundary

The bounded Red12 harness is prepared without changing production behavior.
`HTMLWorkspaceDataFeedStatus` has a two-argument test seam that accepts an
active `SearchIndexService` but deliberately delegates to the existing
dependency-only helper. The live HTML binder still invokes the old one-argument
helper. The serialized MainActor regression creates distinct file-backed
services A and B, makes B perform one real awaited page `diffSync` with
publication enabled, and requires a captured page event sourced by B. It also
requires B-bound reactive and HTML consumers to accept that event, A-bound
consumers to reject it, and object-nil `.searchReadable` fallback events to
remain accepted.

An independent read-only review found the compile shape plausible, found no
production correction in the harness, and confirmed current source should fail
exactly three expectations: B source identity, A-bound `ReactiveQuery`
rejection, and A-bound HTML rejection. Receipt/domain behavior and both
readable fallback checks should pass. The reviewer identified a minor fixed
100-ms drain risk; that heuristic was removed and the source assertion now
checks for the uniquely created B identity rather than requiring a globally
exact notification array. Unrelated delayed events cannot satisfy that
identity. A follow-up read-only review approved the hardened harness and
reconfirmed the same three expected Red failures. Notification exclusivity or
duplicate-unrelated-event proof is intentionally outside this correlation leg.

The changed regions were re-read. Dirty count remains 112 and
`git diff --check` passes. This is source-only harness evidence, not an executed
Red and not authorization for production correction. The exact next action is
a complete fresh preflight: fetch origin; reverify branch/local/remote/handoff
identity; record dirty state, swap strictly below 16,384 MiB, free memory at
least 25%, zero throttled pages, disk, and scoped processes; prove empty stale
app/archive inventory and absent Red12 paths. Only a fully passing preflight
authorizes one selected Red12 App Store test build.

### Search notification producer correlation — Red12 preflight

The complete fresh preflight passed at 2026-07-13 23:40 CDT. Origin fetched
successfully. Branch `feat/goose-surface`, local HEAD, fetched
`origin/feat/goose-surface`, and the handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty entry count is 112 and
`git diff --check` passes.

Swap used is 10,213.19 MiB, strictly below the locked 16,384-MiB ceiling;
system free memory is 72%; pages throttled are zero; and available disk is
724 GiB. No competing exact-basename Xcode build, compiler, model, Epistemos
app, or App Store test process is active. App/archive inventory is empty across
`/private/tmp`, Xcode DerivedData, the repository build tree, and Xcode
Archives; the Archives root itself is absent. The new Red12 DerivedData,
result-bundle, and log paths are absent.

An initial read-only process probe rejected an unescaped `clang++` regular
expression, and the companion inventory aggregation returned nonzero because
the Archives root is absent. Neither started Xcode or changed an app product.
Both checks were rerun with exact-basename and root-aware logic and passed with
unambiguous empty output.

Exactly one serial selected App Store test is authorized:
`appStoreSearchNotificationsStayWithTheirProducingService()`. It will use
`/private/tmp/Epistemos-SearchNotificationRed12-16GiB` and retain
`build/xcode-results/2026-07-13-search-notification-source-red12-16gib.*`.
No overlapping or second build, archive, launch, owner-vault, runtime,
production correction before exact Red, feature/canon, payment,
model/provider/secret/audio, or later-key action is authorized.

### Search notification producer correlation — Red12 first attempt rejected

The one authorized build exited 65 before executing a test. Direct xcresult
summary inspection reports result `unknown`, zero total tests, zero passed,
zero failed, zero expected failures, and zero skipped. Direct build-result
inspection reports status `failed`, two errors, and four warnings. The decisive
harness error is Swift 6 `Sending 'notification' risks causing data races`,
paired with the warning that `QueryDependencyKey.from` is MainActor-isolated
but was called from the synchronous nonisolated NotificationCenter observer
closure. The companion error states that testing was cancelled because the
build failed. The intended three-failure behavior Red was not reached and no
production correction is authorized.

The observer's dependency parse is unnecessary for this test: service B is
freshly created inside the test, so exact `notification.object === serviceB`
identity cannot be supplied by any earlier producer. Removing only that
actor-isolated parse retains the real awaited B `diffSync`, receipt check,
synthetic page-domain consumer checks, and object-nil readable fallback while
repairing only the harness compile boundary.

The retained rejected result is:

`build/xcode-results/2026-07-13-search-notification-source-red12-16gib.xcresult`

The retained log is:

`build/xcode-results/2026-07-13-search-notification-source-red12-16gib.log`

Its SHA-256 is
`aeb815d236334c24dbb7177a266cfe8ab6dd259376b72ecc676721ad79fedfff`.
Before cleanup, the disposable app executable was 40,344 bytes with SHA-256
`5ff65155594b9d7c08700283f7617ccfd3a3fe37c9133bf742879a1f848be615`;
the app bundle occupied 479,248 KiB at
`/private/tmp/Epistemos-SearchNotificationRed12-16GiB/Build/Products/Debug/Epistemos.app`.

Immediate post-run resources were 10,885.31 MiB swap, 68% free memory, zero
throttled pages, and 722 GiB disk. No scoped process remained. After exact
identity capture, the complete disposable DerivedData tree was deleted. The
failed result and log remain; app/archive inventory is empty across all scoped
roots. Cleanup resources are 10,885.31 MiB swap, 70% free memory, zero
throttled pages, and 724 GiB disk. Dirty count remains 112 and
`git diff --check` passes.

This attempt is retained as a harness failure, not Red12 product evidence. The
exact next action is the one-line test-only actor-isolation correction, source
review, and a new full 16-GiB preflight. Only a fully passing new preflight may
authorize one behavior rerun using fresh
`/private/tmp/Epistemos-SearchNotificationRed12Rerun-16GiB` and retained
`build/xcode-results/2026-07-13-search-notification-source-red12-rerun-16gib.*`.

### Search notification producer correlation — corrected Red12 harness boundary

Only the failed observer's actor-isolated
`QueryDependencyKey.from(notification)` guard was removed. The callback now
performs only a `SearchIndexService` cast, exact actor identity comparisons,
and writes to the existing explicitly nonisolated locked probe. No production
file or behavior changed.

An independent follow-up review approved the harness correction. Service B is
freshly created before observer installation, so no prior producer can supply
that exact identity; the awaited B `diffSync` completes its MainActor post
before the source assertion. Delayed unrelated events can record nil or a
different service but cannot satisfy `contains("service-b")`. The reviewer
reconfirmed the unchanged source should still produce exactly three behavior
failures: missing B source, A-bound reactive acceptance, and A-bound HTML
acceptance. B-bound checks and object-nil readable fallback should pass.

Search publication still uses `object: nil`; ReactiveQuery still filters only
dependency domains; the new HTML overload still ignores its active service;
and the live binder still calls the original helper. The corrected region was
re-read, dirty count remains 112, and `git diff --check` passes. The fresh
rerun DerivedData, result, and log paths are absent. This is source-only review,
not behavior Red evidence. The exact next action is a new complete locked
16-GiB preflight; no production correction is authorized before exact Red.

### Search notification producer correlation — Red12 rerun preflight

The new complete preflight passed at 2026-07-13 23:46 CDT. Origin fetched
successfully. Branch `feat/goose-surface`, local HEAD, fetched
`origin/feat/goose-surface`, and the handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 112 and
`git diff --check` passes.

Swap used is 10,845.31 MiB, strictly below the locked 16,384-MiB ceiling;
system free memory is 72%; pages throttled are zero; and available disk is
724 GiB. No competing scoped process is active. App/archive inventory is
empty across every scoped root, and the fresh rerun DerivedData, result, and
log paths are absent. The rejected first-attempt result and log remain present;
the retained log still has SHA-256
`aeb815d236334c24dbb7177a266cfe8ab6dd259376b72ecc676721ad79fedfff`.

Exactly one serial rerun of
`appStoreSearchNotificationsStayWithTheirProducingService()` is authorized,
using `/private/tmp/Epistemos-SearchNotificationRed12Rerun-16GiB` and retained
`build/xcode-results/2026-07-13-search-notification-source-red12-rerun-16gib.*`.
No second build, archive, launch, owner-vault, runtime, production correction
before exact Red, feature/canon, payment, model/provider/secret/audio, or
later-key action is authorized.

### Search notification producer correlation — exact Red12 behavior evidence

The one authorized rerun exited 65 because the selected behavior test failed,
not because compilation or setup failed. Direct build-result inspection reports
status `succeeded`, zero build errors, and three unrelated retained warnings.
Direct test summary reports result `Failed`: one total test, zero passed, one
failed, zero expected failures, and zero skipped on an arm64 MacBook Pro
running macOS 26.3.1.

Direct targeted `test-details` inspection and the retained log expose exactly
three issue trees in 0.061 seconds:

1. The real awaited service-B page `diffSync` completed one upsert, but the
   captured source array was `["nil"]` and did not contain `service-b`.
2. A page ReactiveQuery bound to service A returned true for a synthetic page
   event sourced by service B.
3. The HTML refresh predicate bound to service A returned true for that same
   service-B page event.

No other issue was recorded. The mutation receipt, B-bound reactive and HTML
checks, page-domain behavior, and both object-nil `.searchReadable` fallback
checks therefore passed. The generic xcresult `tests` listing subcommand
returned an internal database-move collision, but a repeated direct summary
and targeted `test-details` inspection both succeeded afterward, proving the
bundle remained valid and exposing all three issue trees.

The retained exact Red result is:

`build/xcode-results/2026-07-13-search-notification-source-red12-rerun-16gib.xcresult`

It occupies 136,704 KiB. The retained log is:

`build/xcode-results/2026-07-13-search-notification-source-red12-rerun-16gib.log`

Its SHA-256 is
`29d684ee3c0b2822ec880d8dcc1f0ce9ddd1250607b7eb62d793a297ce3144af`.
Before cleanup, the disposable app executable was 40,344 bytes with SHA-256
`5c75f848205f2b0c57c0f3caf0fd5f113bade049cd38a0f302c59e841c67cd0a`;
the app bundle occupied 490,580 KiB at
`/private/tmp/Epistemos-SearchNotificationRed12Rerun-16GiB/Build/Products/Debug/Epistemos.app`.

Immediate post-run resources were 11,059.94 MiB swap, 69% free memory, zero
throttled pages, and 721 GiB disk. No scoped process remained. After exact
identity capture, the complete disposable build tree was deleted. The result
and log remain; app/archive inventory is empty. Cleanup resources are
11,059.94 MiB swap, 70% free memory, zero throttled pages, and 723 GiB disk.
Dirty count remains 112 and `git diff --check` passes.

Exact Red12 authorizes only the bounded producer-correlation correction:
instance-source page/block Search notifications, publish the concrete service
from aggregate VaultSync, reject only mismatched concrete Search services in
ReactiveQuery and HTML data feeds, and preserve nil/non-service fallback. No
Green build is authorized before surgical source review and another complete
locked 16-GiB preflight.

### Search notification producer correlation — pre-Green12 source checkpoint

The bounded correction is prepared. Both Search publication helpers remain
`nonisolated` but are now instance methods on the concrete
`SearchIndexService`; their MainActor post uses `object: self`. All nine
internal publication call sites use the producing instance, and the aggregate
VaultSync path publishes through its exact `searchService` after the existing
continuation fence.

`QueryExecutor` now requires concrete Search-source matching. `QueryRuntime`,
the only current conformer, stores the constructor's Search service and
compares actor identity. `ReactiveQuery` rejects only a
`.searchIndexDidUpdate` event whose object is a concrete different Search
service, before retaining the existing dependency-domain and unscoped fallback
logic. The HTML predicate rejects only when producer and active Search services
are both concrete and different, then delegates to its existing dependency
predicate. Its live binder supplies
`AppBootstrap.shared?.vaultSync.searchService`. Nil producer, non-service
producer, nil active service, and same-service events retain conservative
legacy handling.

`ReadableBlocksIndex` is untouched and still emits object-nil
`.searchReadable` events. Search schema, receipts, result semantics, debounce,
Spotlight, Eidos, Recall, FTS5 configuration, owner vault, runtime, archive,
Free V1 capability policy, feature/canon, payment, model/provider/secret/audio,
and later execution keys remain outside this correction. Three source guards
now require instance publication spelling while preserving the
prepare-publish-consume ordering proof. Semantic scans find no stale static
Search helper call and exactly two intended producers: instance-sourced
page/block Search and object-nil ReadableBlocks.

An independent read-only applied-diff audit found no missed call site, Swift 6
isolation risk, fallback error, source-guard inconsistency, or scope creep. The
changed regions were re-read. Dirty count is 114 because QueryRuntime and
ReactiveQuery joined the existing dirty feature set, and `git diff --check`
passes.

Green12 is the exact twenty-three Green11 selectors plus the Red12 regression
once, for twenty-four serialized App Store tests. No Green build is authorized
until a fresh complete locked preflight passes. The proposed fresh paths are
`/private/tmp/Epistemos-SearchNotificationGreen12-16GiB` and
`build/xcode-results/2026-07-13-search-notification-correlation-green12-16gib.*`.

### Search notification producer correlation — Green12 preflight

The complete fresh preflight passed at 2026-07-14 00:00 CDT. Origin fetched
successfully. Branch `feat/goose-surface`, local HEAD, fetched
`origin/feat/goose-surface`, and the handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 114 and
`git diff --check` passes.

Swap used is 10,635.94 MiB, strictly below the locked 16,384-MiB ceiling;
system free memory is 70%; pages throttled are zero; and available disk is
723 GiB. No competing scoped process is active. App/archive inventory is
empty across all scoped roots.

The selection audit derives the exact twenty-three unique Green11 selectors
from its retained log and adds the Red12 regression exactly once, producing
twenty-four unique serialized App Store selectors with no duplicate. Midnight
crossed after the source checkpoint, so the proposed July 13 result/log
basename is superseded only for evidence dating. The actual verified-absent
paths are
`build/xcode-results/2026-07-14-search-notification-correlation-green12-16gib.*`;
the fresh DerivedData path remains
`/private/tmp/Epistemos-SearchNotificationGreen12-16GiB`, also absent.

Both rejected/behavior Red12 result-log pairs remain retained with their exact
verified digests. Exactly one serial twenty-four-test Green12 build is now
authorized. No overlapping or second build, archive, launch, owner-vault,
runtime, feature/canon, payment, model/provider/secret/audio, or later-key
action is authorized.

### Search notification producer correlation — Green12 first attempt failed to compile

The one authorized Green12 build exited 65 before test execution. Direct
xcresult build inspection reports status `failed`, two errors, and four
warnings. Direct test-summary inspection reports result `unknown` with zero
total, passed, failed, expected, or skipped tests. No source or runtime behavior
was proven by this attempt.

The exact bounded compiler error is in
`HTMLWorkspaceDataFeed.shouldRefresh(for:activeSearchService:)`: after the
concrete mismatched-service rejection, it invokes the existing one-argument
predicate without returning that predicate's `Bool`. The retained log reports
`Missing return in static method expected to return 'Bool'` at line 594 and an
associated unused-result warning. This is the only correction authorized.

The failed result is retained at
`build/xcode-results/2026-07-14-search-notification-correlation-green12-16gib.xcresult`
and occupies 500 KiB. The retained 2,052-KiB log has SHA-256
`1324ec22b8051d335fa6f0b66c00f8579587e2752b6e97de78601bb71ab2815e`.
The partial disposable app occupied 197,176 KiB and contained no main Epistemos
executable. Its only executable under `Contents/MacOS` was the 16,760-byte
`__preview.dylib`, SHA-256
`d84f77e6467c2bf34498a4dbb0871fc906a374ca80dcbe70d574c74ffcab58bf`.

Immediate post-failure resources remain within the owner safety lock: swap used
is 11,217.75 MiB, strictly below 16,384 MiB; free memory is 66%; pages
throttled are zero; and disk availability is 721 GiB. No scoped
Xcode/compiler/model/Epistemos process remains. Branch `feat/goose-surface`,
local HEAD, fetched origin, and handoff publication commit remain identical at
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 114 and
`git diff --check` passes.

The exact safe continuation is: retain the failed result/log, delete only the
partial disposable Green12 DerivedData, verify empty app/archive inventory,
insert only the missing `return`, re-read the changed region and diff, and run a
fresh complete 16-GiB preflight. No rerun, archive, launch, owner-vault,
runtime, feature/canon, payment, model/provider/secret/audio, or later-key
action is authorized before those gates pass.

The exact partial DerivedData path was then deleted after identity capture. The
failed result and log remain retained, while app/archive inventory is empty
across the scoped build roots. Cleanup resources are 11,193.75 MiB swap used,
66% free memory, zero throttled pages, and 723 GiB available disk. No scoped
process remains. The single missing-return correction is now authorized; a
rerun still requires changed-region review, diff validation, and a new complete
preflight.

The authorized correction is now applied: the existing dependency predicate is
explicitly returned after the concrete mismatched-service guard. The changed
region was re-read; an independent review confirmed that same-service, nil
producer, non-Search producer, nil active service, missing metadata, and the
three Search dependency domains retain their intended behavior. The exact
structural source check passes, dirty count remains 114, and
`git diff --check` passes. Green12 remains unproven. Only a fresh complete
16-GiB preflight may authorize one rerun with new DerivedData/result/log paths.

### Search notification producer correlation — Green12 rerun preflight

The complete rerun preflight passed at 2026-07-14 00:06 CDT after a successful
origin fetch. Branch `feat/goose-surface`, local HEAD, fetched
`origin/feat/goose-surface`, and the handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 114 and
`git diff --check` passes.

Swap used is 11,177.75 MiB, strictly below the locked 16,384-MiB ceiling;
system free memory is 67%; pages throttled are zero; and available disk is
723 GiB. No competing scoped process is active. App/archive inventory is empty
across the scoped build roots. The fresh rerun DerivedData, result, and log
paths are all absent.

The failed first-attempt result/log remain retained, and the log SHA-256
re-verifies as
`1324ec22b8051d335fa6f0b66c00f8579587e2752b6e97de78601bb71ab2815e`.
Selector extraction from that exact command returns twenty-four total and
twenty-four unique selectors, including the Red12 regression once. The exact
post-correction source structure also passes.

Exactly one serial twenty-four-test Green12 rerun is authorized using
`/private/tmp/Epistemos-SearchNotificationGreen12Rerun-16GiB` and retained
`build/xcode-results/2026-07-14-search-notification-correlation-green12-rerun-16gib.*`.
No overlapping or second build, archive, launch, owner-vault, runtime,
feature/canon, payment, model/provider/secret/audio, or later-key action is
authorized.

### Search notification producer correlation — Green12 zero-test rerun rejected

The authorized rerun compiled and linked successfully and exited zero, but it
does not provide Green12 behavior evidence. Direct xcresult build inspection
reports status `succeeded`, zero errors, and three unrelated retained warnings.
Direct test inspection reports result `unknown` with zero total, passed,
failed, expected, or skipped tests. The retained log likewise records
`Test run with 0 tests in 1 suite passed`; its terminal `TEST SUCCEEDED` is a
build/test-session success only and must not be promoted to a passing selected
batch.

The exact cause is command selector spelling. All twenty-four attempted names
omitted the trailing `()` required by this Swift Testing bundle. The retained
proven Green11 command contains `()` on each of its twenty-three selectors, and
its xcresult test-node identifiers contain the same suffix. The source compiled
past the corrected HTML predicate, but no selected behavior ran. Only the
selector command may be corrected; no production or test-source edit is
authorized by this result.

The invalid zero-test result is retained at
`build/xcode-results/2026-07-14-search-notification-correlation-green12-rerun-16gib.xcresult`
and occupies 560 KiB. Its retained 2,052-KiB log has SHA-256
`19d588de28e62a9017b7592ad46392dc0fead227a10a46296eaa152b8c1a80ae`.
Before cleanup, the disposable app executable was 40,344 bytes with SHA-256
`98396e509a692d0bcaff586cc83153b7fa6e0974834a587041f2c28477269ee9`;
the bundle occupied 490,604 KiB.

Immediate resources were 11,519.69 MiB swap used, 67% free memory, zero
throttled pages, and 721 GiB disk. No scoped Xcode/compiler/model/Epistemos
process remains. Branch and the local/origin/handoff SHA triple remain exact at
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 114 and
`git diff --check` passes.

Green12 remains unproven. Exact safe continuation is to retain this invalid
result/log, delete only its disposable DerivedData, verify empty app/archive
inventory, then perform a new complete 16-GiB preflight for one corrected
twenty-four-selector command with `()` on every test identifier. No broader
action is authorized.

### Search notification producer correlation — corrected-selector preflight

The invalid zero-test DerivedData was deleted after exact artifact identity
capture. Its result and log remain retained; the log digest re-verifies as
`19d588de28e62a9017b7592ad46392dc0fead227a10a46296eaa152b8c1a80ae`.
App/archive inventory is empty across the scoped build roots.

The complete corrected-selector preflight passed at 2026-07-14 00:11 CDT after
a successful origin fetch. Branch `feat/goose-surface`, local HEAD, fetched
origin, and the handoff publication commit remain identical at
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 114 and
`git diff --check` passes.

Swap used is 11,519.69 MiB, strictly below the locked 16,384-MiB ceiling; free
memory is 68%; pages throttled are zero; disk availability is 723 GiB; and no
scoped process is active. The new DerivedData, result, and log paths are all
absent.

The exact corrected selection contains twenty-four total and twenty-four
unique identifiers: the proven Green11 twenty-three plus the Red12 regression
once. Every identifier ends in the required `()`; a zero-mismatch suffix audit
passes. Exactly one corrected serial batch is authorized using
`/private/tmp/Epistemos-SearchNotificationGreen12SelectedRerun-16GiB` and
retained
`build/xcode-results/2026-07-14-search-notification-correlation-green12-selected-rerun-16gib.*`.
Green12 remains unproven until direct result-bundle inspection. No overlapping
build or broader action is authorized.

### Search notification producer correlation — Green12 passed

The one corrected serial batch exited zero. Direct xcresult test-summary
inspection reports result `Passed`: twenty-four total tests, twenty-four
passed, zero failed, zero skipped, and zero expected failures on an arm64
MacBook Pro running macOS 26.3.1. Direct build-result inspection reports status
`succeeded`, zero errors, and three unrelated retained warnings.

Direct test-node inspection and targeted `test-details` inspection prove
`appStoreSearchNotificationsStayWithTheirProducingService()` passed in 0.014
seconds. The retained log independently records the named test pass, the
twenty-four-test suite pass in 0.946 seconds, and terminal `TEST SUCCEEDED`.
This is current exact evidence for the bounded producer-correlation correction;
it is not archive, launch, owner-vault, full runtime, release, or later-key
evidence.

The retained Green12 result is
`build/xcode-results/2026-07-14-search-notification-correlation-green12-selected-rerun-16gib.xcresult`
and occupies 136,940 KiB. The retained 2,052-KiB log has SHA-256
`8808bed8c621a3d94b5f43f1d7477cc44c1e82c702c509cf5bb34cea100b41d6`.
Before cleanup, the disposable app executable was 40,344 bytes with SHA-256
`55dea8d717e03ba550c99bc4c3e74f8d2b0bacccd97db34081ce82a811ba883f`;
the app bundle occupied 490,612 KiB.

Immediate resources were 11,519.69 MiB swap used, 67% free memory, zero
throttled pages, and 721 GiB available disk. No scoped Xcode/compiler/model/
Epistemos process remains. Branch and the local/origin/handoff SHA triple remain
exact at `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 114 and
`git diff --check` passes.

Green12 closes the bounded Search producer-correlation evidence leg. The
overall KEELSTONE verdict remains `INCOMPLETE`. Exact next action is to delete
only the disposable Green12 DerivedData after identity capture, verify empty
app/archive inventory while retaining all result/log evidence, and then compare
the next bounded verification debt read-only before authorizing any new edit or
build. No archive, launch, owner-vault, runtime, feature/canon, payment,
model/provider/secret/audio, or later execution key is authorized here.

The exact Green12 DerivedData was deleted after artifact identity capture. It
is absent, and app/archive inventory is empty across the scoped build roots.
After the direct test-node and targeted-detail inspection, the retained result
occupies 137,192 KiB; the retained log remains 2,052 KiB with SHA-256
`8808bed8c621a3d94b5f43f1d7477cc44c1e82c702c509cf5bb34cea100b41d6`.

Cleanup resources are 11,503.69 MiB swap used, 68% free memory, zero throttled
pages, and 722 GiB available disk. No scoped Xcode/compiler/model/Epistemos
process remains. Branch/local/origin/handoff identity remains exact, dirty
count is 114, and `git diff --check` passes. The safe boundary is now a
read-only comparison of remaining bounded KEELSTONE verification debts; no new
build or source correction is pre-authorized.

### Next-debt comparison — FTS5 linked-SQLite collision selected

The read-only comparison selected FTS5-enabled App Store execution ahead of
the typed Spotlight deletion-receipt source guard and Eidos deletion. The
canonical execution key remains
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`, the overall verdict remains
`INCOMPLETE`, and the owner lock remains strictly below 16,384 MiB swap used
before any test or build.

Current exact evidence repeatedly initializes every fresh Search service with
`fts5_pages=false fts5_blocks=false fts5_readable_blocks=false`. The system
SQLite reports `ENABLE_FTS5` and completes a direct FTS5 table/`MATCH` probe,
so OS capability is present while the actual Epistemos test host falls back.

Current source supplies a bounded causal hypothesis. `graph-engine` enables
Cozo 0.7.6 default features. Cozo's default `compact` closure enables bundled
SQLite through `minimal` → `storage-sqlite` + `storage-sqlite-src`; the current
universal `libgraph_engine.a` exports 269 `_sqlite3_*` symbols and is linked in
the App Store executable alongside GRDB. By contrast, all three production
Cozo constructors use the unconditional in-memory backend, and no source use
of Cozo persistent storage, backup/restore, requests, custom fixed rules, or
optional graph algorithms was found.

Local KEELSTONE/RRF canon requires external-content FTS5 in the existing shared
GRDB Search database and keeps every Search index derived/disposable. Targeted
primary-source validation confirms that compiled-in SQLite FTS5 requires its
FTS5 build option, Cozo's memory backend and pure Datalog do not require its
default SQLite/request/graph-algorithm feature closure, and GRDB warns against
multiple SQLite implementations in one process. These facts support the
diagnosis but do not yet prove causality in Epistemos; only the bounded
executable Red/Green may do that.

The smaller Spotlight helper edit would provide only a source-shape receipt
contract, not Core Spotlight behavior, caller consumption, or dual-lane
lifecycle ownership. Eidos deletion spans Rust storage, FFI, generated
bindings, three Swift convergence paths, and a paid target; Free V1 correctly
links no `agent_core`, so meaningful Eidos behavior cannot be proven in the
current App Store host. Both debts remain open and are not changed here.

Red13 is test-only. One serialized App Store test will create an isolated
`SearchIndexService`, seed page, block, and readable-block rows, require all
three FTS5 virtual tables, and run exact unique-token `MATCH` queries through
the real linked SQLite. Current source is expected to fail at table
availability. No production correction is authorized until that exact Red is
captured and inspected.

If Red13 proves the expected failure, the only proposed correction is disabling
Cozo default features in `graph-engine/Cargo.toml` plus mechanical lockfile
reconciliation. Green must then prove the memory/Datalog Cozo uses, zero
exported `_sqlite3_*` symbols from the rebuilt graph archive, the new real
FTS5 round trip, and all twenty-four Green12 selectors in one serialized
twenty-five-test App Store batch. Search fallback/schema semantics, Spotlight,
Eidos, Recall, vault data, archive/runtime launch, feature/canon work, paid
surfaces, and later execution keys remain out of scope.

Exact next action: add only the Red13 test, re-read and diff-check it, then run
a complete fresh 16-GiB preflight. Only a passing preflight authorizes one
serial selected Red13 Xcode build. No stale/current app or archive product may
exist before that build, and its disposable app must be removed after exact
identity capture.

### FTS5 linked-SQLite Red13 harness prepared

Only the serialized App Store test file changed for Red13. The new test opens a
fresh Search database in the real product host, seeds page, block, and readable
rows, and requires the three production FTS virtual tables. A guard after that
single table-set expectation prevents misleading follow-on SQL failures on the
current no-FTS host. When the tables exist, three raw unique-token `MATCH`
queries must each return exactly one row; fallback Search APIs are not used.

An independent read-only review found and closed two harness-only risks before
execution. GRDB query bindings now use explicit `StatementArguments`, and the
readable row is seeded directly inside the database writer transaction rather
than through the notifying public helper. This removes an asynchronous
object-nil notification that could have contaminated the next serialized test,
and removes the corresponding `async`/`Task.yield()` heuristic.

The complete changed test region was re-read. The Cozo declaration remains
unchanged, no production correction is present, and `git diff --check` passes.
Red13 is not yet executed. Exact next action is a fresh complete 16-GiB
preflight. Only a passing preflight authorizes one selected Xcode build at a
new disposable DerivedData path with a new retained result/log pair.

### FTS5 linked-SQLite Red13 — exact executable failure proved

The fresh preflight passed after fetching origin. Branch
`feat/goose-surface`, local HEAD, fetched `origin/feat/goose-surface`, and the
handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count was 114 and
`git diff --check` passed. Swap used was 11,375.62 MiB, below the locked
16,384-MiB ceiling; free memory was 75%; pages throttled were zero; disk
availability was 722 GiB; no competing Xcode build, compiler, model, or
Epistemos runtime was active; scoped app/archive inventory was empty; and the
new DerivedData/result/log paths were absent.

Exactly one selected App Store test build ran against disposable DerivedData
`/private/tmp/Epistemos-FTS5Red13-16GiB`. Direct `xcresulttool` build-result
inspection reports status `succeeded`, zero errors, and three pre-existing
warnings. Direct test-summary and test-node inspection report one total test,
zero passes, one failure, zero skipped, and zero expected failures. The sole
failure is
`appStoreLinkedSQLiteProvidesAllSearchFTS5RoundTrips()` at the required table
set: installed tables were empty rather than exactly `page_search`,
`block_search`, and `readable_blocks_fts`.

The executable log independently records the fresh Search service at its
isolated temporary database with
`fts5_pages=false fts5_blocks=false fts5_readable_blocks=false`. The test's
guard then returned, so there were no secondary missing-table or raw-MATCH
errors. This is the exact intended Red13: product-host compilation succeeded,
the real linked SQLite lacked all three FTS5 projections, and no Search
fallback API could satisfy the assertion.

The retained result is
`build/xcode-results/2026-07-14-search-fts5-linked-sqlite-red13-16gib.xcresult`.
The retained 1,387,824-byte log has SHA-256
`357380c51f43d1deaabef0bd34716286c0373dc81cf42c13a9870fac356a6e4d`.
Before cleanup, the disposable app occupied 490,604 KiB; its 40,344-byte
executable had SHA-256
`437c9448ce794f4bbad7626f3aa0d5bdf0b11d570d8263af44166e6e2ab9ac90`.
Post-run resources were 11,577.19 MiB swap used, 68% free memory, zero
throttled pages, and 720 GiB available disk.

The exact disposable DerivedData was deleted after app identity capture. It is
absent, the result/log evidence remains retained, and scoped app/archive
inventory is empty. Red13 proves the current executable failure but does not
yet prove the causal correction, Green behavior, performance, archive/runtime
behavior, or release readiness. Overall KEELSTONE remains `INCOMPLETE`.

Exact next action: make only the already-bounded Cozo manifest correction—pin
0.7.6 with default features disabled—and accept only mechanical lockfile
reconciliation. Inspect that diff, then run the graph-engine in-memory/Datalog
regressions and rebuild its archive outside Xcode. The archive must export zero
`_sqlite3_*` symbols before a fresh 16-GiB preflight may authorize the one
serialized twenty-five-test Green13 App Store batch. No archive, launch,
owner-vault, Spotlight/Eidos, canon/feature, paid runtime, model/provider,
secret, audio, or later execution key is authorized.

### Cozo minimal closure Red13b — Rayon is required, storage is not

The first locked graph-engine suite attempt after the one-line manifest change
and mechanical lock reconciliation compiled dependencies but ran zero tests.
Cozo 0.7.6 failed with four compiler errors: its non-WASM evaluator imports
`rayon::prelude`, two core evaluation paths call `par_iter()`, and its
multi-transaction path calls `rayon::spawn()` even when no Cozo feature is
selected. Thus `default-features = false` with no explicit feature is not a
valid macOS compilation closure.

The retained 3,902-byte compile log is
`build/xcode-results/2026-07-14-graph-engine-cozo-zero-feature-red13b-compile-16gib.log`
with SHA-256
`7bb0fc0c6d53a3b12949c7dcf59c7b3d66d9a0bf8037ce091bc0536a8ef80184`.
This is a dependency-closure Red, not a Rust test failure and not an App Store
build. No staged graph archive or app/archive product exists. Post-attempt
resources were 11,577.19 MiB swap used, 70% free memory, zero throttled pages,
and 722 GiB available disk; no compiler/build/model/Epistemos runtime remains.

Current upstream manifest/source inspection resolves the smallest valid
closure. Rayon is an optional dependency with an implicit `rayon` feature.
The broader `graph-algo` feature adds both `graph` and `rayon`; `minimal` adds
SQLite storage/source; `requests` adds HTTP/TLS. Epistemos uses only the memory
backend and pure Datalog. Therefore only `features = ["rayon"]` is justified
beside `default-features = false`. SQLite storage/source, requests, optional
graph algorithms, and alternate storage remain excluded.

Exact next action: adjust only the existing Cozo declaration to that
Rayon-only closure, reconcile the lockfile mechanically, and prove the
resulting active dependency graph contains Rayon but no SQLite/request/graph
package. Then perform a fresh complete 16-GiB preflight before retrying the
full graph-engine suite with `bolt-graph,shared-position-buffers`. Green13
Xcode execution remains unauthorized until those tests pass and the exact
universal staged archive exports zero `_sqlite3_*` symbols.

### Rayon-only Rust and archive proof — one direct outline test still owed

The reconciled active feature tree contains `cozo feature "rayon"` and no
SQLite, sqlite3 source/sys, request, or optional graph package. The full
graph-engine suite with the exact Xcode features passed 2,871 tests, zero
failed, and eight intentional ignores. Its retained 248,904-byte log is
`build/xcode-results/2026-07-14-graph-engine-cozo-minimal-green13-rust-tests-16gib.log`
with SHA-256
`58a9d2c8ec70c598cd78fbffaaabe65875d20852537be88f845ac2beb6279ae5`.

The exact Debug staging script then rebuilt the Xcode-linked universal static
archive for arm64 and x86_64. It is 928,374,328 bytes with SHA-256
`b4523c8d4c3f1527583d4bfef3c1c93dcc940cc6276ef2a7bfc1ac7ade48646b`.
The retained 1,583-byte build log has SHA-256
`d98fe18f37c26bbca7441b77a3ab76e8db6451e49056c682bf838c55164412cc`.
Exported `_sqlite3_*` symbol counts are zero for the universal archive, arm64,
and x86_64 independently. Post-build resources were 11,577.19 MiB swap used,
70% free memory, zero throttled pages, and 718 GiB available disk; app/archive
inventory remains empty.

A read-only test-ownership audit found one remaining direct-coverage gap before
the App Store Green. Existing tests exercise the knowledge-core Cozo store and
the BTK property database, but no test subscribes to a pre-materialized BTK
outline and therefore no test directly executes its distinct `outline_db`
constructor/import/query/decode path. Add one test-only regression using the
existing two-block fixture, sync before subscription, and assert both outline
rows' page/parent/depth/content round trip. Then run its exact selector plus
the full exact-feature Rust suite after a fresh 16-GiB gate. No production seam
or behavior change is authorized. The current staged archive must be deleted
as stale before any later app build; Green13 Xcode remains unauthorized until
this final Rust-memory leg passes.

### Final Cozo memory coverage passed; Green13 app batch is next

The direct BTK outline-memory test now exists beside the established property
and link tests. It first materializes the existing two-block page, then
subscribes, consumes the initial payload, and proves root/child page, parent,
depth, and content fields round-trip through the distinct Cozo `outline_db`
path. Targeted Rust formatting and `git diff --check` pass. No production seam,
schema, FFI, or runtime behavior was added.

After a complete passing 16-GiB preflight, its exact locked/offline selector
passed one of one tests in 0.02 seconds. The retained 736-byte log is
`build/xcode-results/2026-07-14-graph-engine-outline-cozo-green13-narrow-16gib.log`
with SHA-256
`bf3d82f2d2fee76eaf7e7c92dbf3c07e01f6c1308ea403ebb4987d1e10fef112`.

The full exact-feature suite then reran and passed 2,872 tests with zero
failures and eight intentional ignores across the 2,806 library tests,
canonical-doctrine, FFI, NaN quarantine, phase A/B/C stress,
visual-equivalence, and doc-test legs. The retained 249,034-byte final log is
`build/xcode-results/2026-07-14-graph-engine-cozo-minimal-green13-rust-tests-rerun-16gib.log`
with SHA-256
`17f3f0d2e62f3ebca05c0db97b9aebe9c5bb8449c572cd4bea0aa1fe439c4e01`.

Post-test resources were 11,577.19 MiB swap used, 70% free memory, zero
throttled pages, and 717 GiB available disk. The earlier staged graph archive
was deliberately deleted after its arm64/x86_64 zero-SQLite symbol proof so it
cannot be mistaken for the archive created by the coming app build. Scoped
app/archive inventory is empty. Branch/local/origin/handoff identity remains
exact at `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and
`git diff --check` passes.

Exact next action: recover the proven twenty-four Green12 selectors, append
`appStoreLinkedSQLiteProvidesAllSearchFTS5RoundTrips()` once, and audit the
selection for exactly twenty-five total/unique identifiers with valid `()`
suffixes. Use new absent DerivedData/result/log paths and perform a full fresh
16-GiB preflight. Only a passing gate may authorize the one serialized
Green13 App Store build. Direct result inspection must prove 25/25, the log
must show all three FTS5 flags true, and the graph archive produced inside
that exact build must again export zero `_sqlite3_*` symbols. Capture the app
identity, then delete all disposable app/archive/DerivedData products while
retaining result/log evidence. No archive, launch, owner-vault, Spotlight/Eidos,
canon/feature, paid runtime, model/provider, secret, audio, or later execution
key is authorized.

### Green13 — FTS5 restored, reader maintenance regression exposed

The owner's durable resource ceiling is now strictly below 16,384 MiB swap
used before any test or build. The other gates remain at least 25% system free
memory, zero throttled pages, sufficient disk, no competing build/compiler/
model/Epistemos runtime, one serial Xcode job, and one disposable current app
artifact. This supersedes the temporary lower ceilings without authorizing any
broader execution.

Green13's complete fresh preflight passed. Branch `feat/goose-surface`, local
HEAD, fetched `origin/feat/goose-surface`, and the handoff publication commit
all equaled `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count was 117 and
`git diff --check` passed. Swap used was 11,569.19 MiB, free memory was 70%,
pages throttled were zero, disk availability was 718 GiB, no competing process
was active, scoped app/archive inventory was empty, the staged graph archive
was absent, and all new DerivedData/result/log paths were absent. The selector
audit proved exactly twenty-five total and unique `()`-suffixed App Store test
identifiers: Green12's twenty-four plus the linked-SQLite FTS5 regression once.

Exactly one serial App Store test build ran against
`/private/tmp/Epistemos-SearchFTS5Green13Selected-16GiB`. It compiled and
linked, and direct build-result inspection reports status `succeeded`, zero
errors, and three unrelated retained warnings. Direct test-summary and node
inspection report result `Failed`: twenty-five total tests, fourteen passed,
eleven failed, zero skipped, and zero expected failures. Every failed test has
the same causal exception: `SQLite error 8: attempt to write a readonly
database - while executing PRAGMA optimize`. One test records both an expected-
error mismatch and the thrown exception, which explains the console's twelve
issues without inflating the failed-test count.

The retained log independently proves that the intended linked-SQLite repair
did take effect. Every Search service initialized during the batch reports
`fts5_pages=true fts5_blocks=true fts5_readable_blocks=true`; there is no
false/false/false initialization. The FTS5 regression itself reaches the same
true/true/true state, then fails when its first GRDB read connection executes
the connection-preparation `PRAGMA optimize`. Thus this run proves restored
FTS5 capability and exposes a separate reader/writer ownership defect; it does
not satisfy Green13.

The retained result is
`build/xcode-results/2026-07-14-search-fts5-linked-sqlite-green13-selected-16gib.xcresult`
and occupied 136,708 KiB after direct inspection. The retained 1,488,467-byte
log has SHA-256
`d661d4b5d829003626cc95ed55f975f835cf4723b69bfe4270bb97a409aa7cb1`.
Before cleanup, the disposable App Store bundle occupied 475,772 KiB at the
isolated DerivedData path. Its 40,344-byte arm64 executable had SHA-256
`f46884543c2d9188cd2966fe4b566226f6f4814aca52494e43d639948836f8d1`,
bundle identifier `com.epistemos.appstore`, build `1`, and version `1.0.0`.

The graph archive created by this exact build is a universal arm64/x86_64
archive, 928,375,752 bytes, with SHA-256
`3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.
Its exported `_sqlite3_*` count is zero in universal, arm64, and x86_64 symbol
views, and an archive string scan finds zero SQLite symbol names. Post-run
resources were 11,618.19 MiB swap used, 68% free memory, zero throttled pages,
and 710 GiB available disk. Git identity remained exact and dirty count stayed
117.

Overall KEELSTONE remains `INCOMPLETE`. Exact next action is to retain this red
result/log, delete only the disposable Green13 DerivedData/app and staged graph
archive after the identities above, and verify empty scoped app/archive
inventory. Then complete a read-only audit of the current connection-
preparation `PRAGMA optimize`, its writer-owned memory-pressure call, the GRDB
reader contract, and nearby pragma/Search tests. Only that evidence may define
one surgical test-first correction and a later fresh 16-GiB preflight. No
archive, launch, owner-vault, runtime matrix, feature/canon, payment,
model/provider, secret, audio, or later execution key is authorized.

### Green14 setup invocation aborted before test execution

The first Green14 invocation did not satisfy its command precondition. Its
shell used `mapfile`, which is unavailable in the installed macOS Bash, and the
script lacked an immediate-exit guard. The selector array therefore remained
empty and Xcode began resolving an unfiltered test command. The invocation was
interrupted immediately after build-description setup.

Direct partial-result inspection reports `unknown`, zero total tests, zero
passed, zero failed, and zero skipped. The apparent app product is an empty
zero-KiB directory with no executable; the log contains no Swift compilation,
test-case, suite-success, or suite-failure marker. No graph archive exists and
no build/compiler/runtime process remains. This aborted setup invocation is
not Green14 evidence and cannot authorize any behavior claim.

Exact next action is to delete the partial DerivedData, empty app directory,
partial result, and partial log; verify all exact paths and broad product
inventory are empty; validate a Bash-3-compatible selector-array constructor
under immediate-exit mode without invoking Xcode; then repeat the complete
16-GiB preflight on new `-rerun` paths. No retry is authorized before those
steps pass.

The exact partial DerivedData, empty app directory, partial result, partial log,
and staged graph path are now absent. Broad app/archive inventory is zero. A
Bash-3-compatible `while read` array constructor was then run under
`set -euo pipefail` without invoking Xcode; it produced exactly twenty-five
selectors with the expected first and last identifiers. The replacement
command will use new `green14-rerun-16gib` evidence paths and remains blocked
until a complete fresh preflight passes.

### Green14 rerun preflight passed

The replacement preflight exited zero. Branch/local/origin/handoff identity is
still exact at
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117, the diff
check passes, and the Bash-3-compatible selector array contains exactly
twenty-five entries. Swap used is 11,985.31 MiB, strictly below 16,384 MiB;
free memory is 72%; pages throttled are zero; no competing Xcode, compiler,
model, or Epistemos process exists; and broad app/archive inventory is zero.

The new DerivedData path
`/private/tmp/Epistemos-WatcherDrainPriorityGreen14Rerun-16GiB`, result
`build/xcode-results/2026-07-14-watcher-drain-priority-green14-rerun-16gib.xcresult`,
log sibling, and staged graph archive are all absent. One retry is authorized
with immediate-exit mode and the validated twenty-five selectors. No archive,
launch, runtime matrix, canon/feature work, or later execution key is
authorized.

### Green13 cleanup and read-only causal audit

The exact disposable Green13 DerivedData/app and the graph archive produced by
that build were deleted after identity capture. Both paths are absent, scoped
app/archive inventory is empty, and the result/log evidence remains retained.
The result still occupies 136,708 KiB; the log digest re-verifies as
`d661d4b5d829003626cc95ed55f975f835cf4723b69bfe4270bb97a409aa7cb1`.

The completed read-only source and primary-documentation audit isolates one
ownership defect. Epistemos pins GRDB 7.10.0. Its current `Configuration`
contract says `prepareDatabase` runs on the DatabasePool writer and every
reader, distinguished by `db.configuration.readonly`; `DatabasePool` clones
the pool configuration with `readonly = true` for readers. Current SQLite
documentation and implementation say `PRAGMA optimize` can invoke `ANALYZE`
when statistics are missing or stale, which writes `sqlite_stat*`. A connection
can therefore appear to accept the pragma while no work is needed and later
raise `SQLITE_READONLY` when optimization becomes actionable. Green13 is that
exact transition after real FTS5 became available.

The current source places `PRAGMA optimize` inside the shared multi-pragma SQL
executed by `databaseConfiguration().prepareDatabase`. Its separate memory-
pressure maintenance path already invokes the same pragma through
`dbPool.write`, which is correctly writer-owned. Local KEELSTONE canon likewise
requires optimizer work at maintenance points rather than hot-path `ANALYZE`.

The smallest correction is therefore authorized and test-first: remove only
`PRAGMA optimize` from the shared SQL block and immediately execute the same
pragma only when `!db.configuration.readonly`. This retains the existing writer
startup behavior, every connection-scoped pragma, quick-check/journal guards,
schema and FTS behavior, and writer-owned memory-pressure maintenance. It adds
no API, seam, feature, fallback, route, or generalized refactor. The failed
Green13 FTS5 test plus ten existing selected reader-opening tests are the
executable Red.

Green13's log also contains three system-SQLite API-violation messages for a
temporary `search.sqlite`, WAL, and SHM file being unlinked while still open;
one notification-rate warning at 61.2266 posts/second; and one passed test with
a priority-inversion runtime warning. They are recorded rather than normalized
away. A bounded read-only lifetime audit is required before the next batch to
decide whether the unlink signal is test teardown or production ownership.
The other warnings remain explicit later verification debt unless the current
failed leg directly owns them.

Exact next action: make only the guarded writer-optimizer source move, re-read
the full configuration region, inspect the diff, and run source/diff checks.
Then finish the temporary-database lifetime audit and update this ledger before
any new build authorization. A later build still requires a complete fresh
16-GiB preflight and new absent DerivedData/result/log paths. No archive,
launch, owner-vault, runtime matrix, canon/feature, payment, model/provider,
secret, audio, or later execution key is authorized.

### Green13 temporary Search teardown audit

The three vnode-unlink API violations are confined to
`appStoreInitialImportPublishesCommittedSearchDependenciesOnce()`. That test
begins a suppressed Search mutation batch, and `VaultIndexActor` strongly owns
the Search service both as its active service and inside the batch until
consumption. Its first page query lazily opens a DatabasePool reader and fails
on the unguarded optimizer. Error unwinding then runs the temporary-root defer
while the actor still owns the open pool, so system SQLite reports the main,
WAL, and SHM files being unlinked in use.

This is a deterministic test-teardown defect exposed by the genuine production
reader defect. It does not require a new production close API: the test already
has `searchService.databaseWriter()`, whose GRDB writer contract supplies
`close()`. The exact authorized test-only correction is to register cleanup
after Search-service creation and close that writer before deleting the
temporary vault/Search roots. The next one-build log must contain zero vnode-
unlink or invalidated-descriptor messages.

The guarded production optimizer move is now prepared and source-audited: the
shared SQL contains every original pragma except `PRAGMA optimize`; the same
optimizer statement executes immediately afterward only when
`!db.configuration.readonly`; the existing memory-pressure path remains inside
`dbPool.write`. `git diff --check` passes. Exact next action is the single
test-teardown close edit, followed by complete region/diff/source checks and a
ledger update. No test/build is authorized until those checks and a fresh
complete 16-GiB preflight pass.

### Green13 rerun source checkpoint

Both bounded corrections are prepared. `SearchIndexService.databaseConfiguration`
retains every existing connection pragma, but the shared SQL no longer contains
`PRAGMA optimize`; that statement now runs immediately afterward only when
`!db.configuration.readonly`. The existing memory-pressure maintenance remains
writer-owned inside `dbPool.write`. No schema, Search/FTS query, fallback,
receipt, notification, lifecycle, feature, or route behavior changed.

The one actor-retained App Store test now creates its Search service before
registering cleanup, and its defer closes the existing
`searchService.databaseWriter()` before removing the temporary vault and Search
roots. This adds no production API or seam and directly addresses the exact
main/WAL/SHM unlink sequence in the retained Red log.

The complete changed regions and exact diff were re-read. `git diff --check`
passes and dirty count remains 117. SHA-256 is
`bbd455a749460fa52c31155b3176ae686fd5e2f298cd6c43262ff03bf0c32c54`
for `Epistemos/Sync/SearchIndexService.swift` and
`7b39223065e06da332283cd7860023b93c65e97472c65e5a94b4e45ee0f973b6`
for
`EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`.
No test or build has run after either edit.

Exact next action: recover the identical twenty-five Green13 selectors and
audit total, uniqueness, and `()` suffixes; choose new absent DerivedData,
result, and log paths; then perform a complete fresh 16-GiB preflight. Only a
passing preflight authorizes one serial App Store rerun. Direct evidence must
prove build success, 25/25, FTS5 true/true/true and one page/block/readable raw
match apiece, zero read-only optimizer errors, zero vnode-unlink/client-bug/
invalidated-descriptor messages, and zero graph-archive `_sqlite3_*` exports.
After exact app/archive identity capture, delete the disposable build and
verify empty scoped app/archive inventory while retaining the result/log.

### Green13 writer-only rerun preflight

The complete fresh gate passed after a successful origin fetch. Branch
`feat/goose-surface`, local HEAD, fetched `origin/feat/goose-surface`, and the
handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and
`git diff --check` passes. The recovered selection contains exactly twenty-five
total and unique `()`-suffixed identifiers, each resolving to exactly one
current App Store test function.

Swap used is 11,610.19 MiB, below the locked 16,384-MiB ceiling. System free
memory is 68%, pages throttled are zero, disk availability is 690 GiB, and no
competing Xcode build, compiler, model, or Epistemos runtime is active. A broad
inventory of Xcode DerivedData, Xcode Archives, `/private/tmp`, and the
repository build root contains zero Epistemos app/archive products. The fresh
DerivedData path
`/private/tmp/Epistemos-SearchFTS5Green13WriterOnlyRerun-16GiB`, staged graph
archive, retained result bundle, and retained log paths are all absent.

Exactly one serial twenty-five-test App Store rerun is authorized using that
DerivedData path and
`build/xcode-results/2026-07-14-search-fts5-writer-only-green13-rerun-16gib.*`.
No overlapping build, archive, launch, owner-vault, runtime matrix,
feature/canon, payment, model/provider, secret, audio, or later execution key
is authorized.

### Green13 writer-only rerun passed

The one authorized App Store command exited zero. Direct `xcresulttool`
summary inspection reports `Passed`: twenty-five total tests, twenty-five
passed, zero failed, zero skipped, and zero expected failures. Direct node
inspection independently lists all twenty-five requested identifiers as
`Passed`. Targeted result details report
`appStoreLinkedSQLiteProvidesAllSearchFTS5RoundTrips()` passed in 0.0082
seconds and
`appStoreInitialImportPublishesCommittedSearchDependenciesOnce()` passed in
0.05 seconds.

Direct build-result inspection reports status `succeeded`, zero errors, and
three unrelated retained warnings: Rust `block` 0.1.6 future incompatibility,
an unnecessary `await` in `TextCapturePipeline.swift`, and an unused `try?`
result in `LiteParsePDFImportController.swift`.

The retained log contains fifteen Search initializations, all with
`fts5_pages=true fts5_blocks=true fts5_readable_blocks=true`, and zero false
FTS flags. The dedicated linked-host test passed only after requiring all three
virtual tables and raw unique-token page, block, and readable-block `MATCH`
counts of exactly one each. This supplies the missing functional FTS5 round-
trip proof, not only capability detection.

The same console log has zero matches for `attempt to write a readonly
database`, zero SQLite `BUG IN CLIENT`, vnode-unlink, or invalidated-descriptor
messages, zero notification-rate warning text, zero priority-inversion warning
text, and zero failed-test markers. It contains one twenty-five-test suite pass and one
`TEST SUCCEEDED` marker. The production reader ownership correction and the
test-only close-before-delete correction are therefore both evidenced in the
same fresh product host.

The retained 1,515,756-byte log is
`build/xcode-results/2026-07-14-search-fts5-writer-only-green13-rerun-16gib.log`
with SHA-256
`89e90e1b248626d6898226795b2ccb42513cced56d9fb04552761df601e0470b`.
The retained result bundle occupies 136,468 KiB after direct summary, node, and
targeted-detail inspection.

Before cleanup, the disposable app occupies 475,784 KiB at the isolated
DerivedData path. Its 40,344-byte arm64 executable has SHA-256
`3baffa337c7aa8364b976f7de5ad8ca49724c8b8fd7be446661dd7dd6e127c3c`,
bundle identifier `com.epistemos.appstore`, build `1`, and version `1.0.0`.
The graph archive produced by this exact build is universal arm64/x86_64,
928,375,752 bytes, with SHA-256
`3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.
Its universal, arm64, and x86_64 exported `_sqlite3_*` counts are each zero,
and an independent archive string scan finds zero SQLite symbol names.

Post-run resources are 12,089.31 MiB swap used, 68% free memory, zero
throttled pages, and 686 GiB available disk; no competing process remains.
Branch/local/origin/handoff identity remains exact at
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and
`git diff --check` passes.

This closes the bounded linked-SQLite/reader-ownership Green13 leg. It is not an
archive, manual-launch, full-runtime, distribution, or release-readiness pass;
overall KEELSTONE remains `INCOMPLETE`. Exact next action is to delete only the
disposable rerun DerivedData/app and staged graph archive after the identities
above, verify empty broad app/archive inventory while retaining the result/log,
then compare the next bounded verification debt read-only. No archive, launch,
owner-vault, runtime matrix, feature/canon, payment, model/provider, secret,
audio, or later execution key is authorized by this result.

The exact disposable rerun DerivedData/app and the build-created graph archive
were deleted after identity capture. Both paths are absent. Broad inventory
across Xcode DerivedData, Xcode Archives, `/private/tmp`, and the repository
build root contains zero Epistemos app/archive products. The retained result
still occupies 136,468 KiB and the retained log digest re-verifies as
`89e90e1b248626d6898226795b2ccb42513cced56d9fb04552761df601e0470b`.

Cleanup resources are 12,065.31 MiB swap used, 68% free memory, zero throttled
pages, and 689 GiB available disk. No competing process remains; dirty count is
117 and `git diff --check` passes. The exact safe continuation is a read-only
comparison of remaining bounded KEELSTONE verification debts. No new source
edit, test, build, archive, launch, owner-vault action, runtime matrix,
feature/canon work, payment, model/provider, secret, audio, or later execution
key is pre-authorized.

### Green13 result-bundle warning correction — Red14 performance boundary

The later required full issue-node audit corrected one overbroad Green13
statement. Direct
`xcresulttool get test-results tests` inspection of the retained writer-only
result contains one `Runtime Warning` under
`appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()` at the final
test assertion: a user-interactive thread waited on a Utility-QoS thread.
Targeted `test-details` confirms that the test still passed in 0.069 seconds,
but the warning is part of the result bundle even though the console log
contains no matching text. Green13 remains valid for its twenty-five passing
behaviors, FTS5 round trips, SQLite ownership correction, and teardown fix; it
does not satisfy the stricter warning-free performance bar.

The warning is reproducible in retained selected results from the same watcher
Recall test. Current source runs the serial watcher processor through the
intentional background
`Task.detached(priority: .utility)`, while
`waitForVaultMutationDrain()` waits indirectly through a checked continuation.
That continuation records completion but does not expose the producer task as
the awaited dependency. Current Apple Thread Performance Checker guidance says
opaque semaphore/group-style waits cannot propagate priority, and current
Swift Task documentation says directly awaiting the target task is the normal
way to obtain implicit priority escalation. Raising the watcher processor's
normal QoS would move file/index work toward the UI and is not authorized.

This retained warning is the exact Red14 evidence. The bounded correction under
review is to keep Utility QoS, but make the drain directly await each current
`vaultFileSystemProcessorTask.value` before falling back to the existing
continuation for non-watcher admissions. That gives explicit stop/disconnect
drains a priority-aware dependency while leaving ordinary watcher execution in
the background. No test-only priority override, busy wait, polling, route,
schema, Spotlight, Recall-result, archive, or feature change is allowed.

Before any edit, independently confirm the loop cannot miss a newly queued
serial watcher batch and cannot weaken the existing all-admissions drain. After
the surgical change, re-read the complete drain and processor regions, inspect
the exact diff, and run a new full locked preflight. Only a passing preflight
may authorize one serial selected rerun. Green14 requires 25/25 passes plus
zero `Runtime Warning` nodes in direct result inspection; console-log grep is
not sufficient. The archive remains unauthorized until this failed evidence
leg is closed and its disposable build is removed.

### Red14 task-handle drain source checkpoint

Two independent read-only ownership reviews confirm the bounded correction.
The drain now loops while any vault-mutation admission remains. When the
already-owned watcher processor task exists, the drain snapshots that exact
task handle and awaits its `value`; when only a non-watcher admission remains,
it retains the prior checked-continuation fallback. The watcher processor stays
detached at Utility QoS, FIFO ordering is unchanged, and no polling,
cancellation, test-only priority override, Recall/checkpoint change, or new
runtime seam was introduced.

The loop is required because completing one accepted batch can synchronously
rotate the stored handle to the next accepted FIFO batch. Directly awaiting a
local task snapshot suspends the main actor, allows the detached processor to
finish its main-actor completion, and exposes the dependency to Swift priority
escalation. The surrounding admission loop also preserves mixed watcher and
non-watcher drain semantics. Stop/disconnect enters the draining lifecycle
before waiting, so no later watcher admission can race into that production
path.

The complete drain and processor regions and the exact diff were re-read.
`git diff --check` passes and dirty count remains 117. No test or build has run
after this source edit. Exact next action is to reconstruct and audit the same
twenty-five Green13 selectors, choose fresh absent DerivedData/result/log
paths, and perform the complete 16-GiB preflight. Only a passing preflight
authorizes one serial Green14 rerun, and direct result-node inspection—not
console grep—must prove zero Runtime Warning nodes.

### Green14 watcher-drain preflight

The complete fresh gate passed after fetching origin. Branch
`feat/goose-surface`, local HEAD, fetched `origin/feat/goose-surface`, and the
handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and
`git diff --check` passes. The recovered Green13 selection contains exactly
twenty-five total and unique `()`-suffixed identifiers, and every identifier
matches exactly one current App Store test function. The changed
`VaultSyncService.swift` SHA-256 is
`b63dba10666c02e06f1c274f2721024178efb1971ce9f6a37b2558c50c009b58`.

Swap used is 12,001.31 MiB, strictly below the locked 16,384-MiB ceiling.
System free memory is 71%, pages throttled are zero, disk availability is
683 GiB, and the corrected process scan finds no competing Xcode build,
compiler, model, or Epistemos runtime. Broad Xcode DerivedData, Xcode Archives,
`/private/tmp`, and repository build-root inventory contains zero Epistemos
app/archive products.

The fresh DerivedData path
`/private/tmp/Epistemos-WatcherDrainPriorityGreen14-16GiB`, result
`build/xcode-results/2026-07-14-watcher-drain-priority-green14-16gib.xcresult`,
log sibling, and staged graph archive are all absent. Exactly one serial
twenty-five-test App Store rerun is authorized with those paths. No overlapping
build, archive, launch, owner-vault, runtime matrix, feature/canon, payment,
model/provider, secret, audio, or later execution key is authorized.

### Green14 setup correction, rerun, and exact Red result

The first Green14 invocation was stopped during setup because macOS Bash 3.2
does not provide `mapfile`. The failed selector construction left the selector
array empty, and the command lacked an immediate-exit guard. It began an
unfiltered Xcode setup but executed zero tests, produced no executable, wrote
no graph archive, and performed no source correction. Its exact partial
DerivedData/result/log state was deleted, and broad Epistemos app/archive
inventory returned to zero.

The selector constructor was replaced only in the invocation with a
Bash-3-compatible `while IFS= read -r` loop under immediate-exit mode and was
dry-validated without Xcode: exactly twenty-five total and unique selectors,
with the expected first and last identifiers. A second complete preflight
passed at 11,985.31 MiB swap used, 72% free memory, zero throttled pages, zero
competing processes, zero app/archive products, sufficient disk, exact
branch/local/origin/handoff identity, and absent fresh evidence paths.

The one corrected serial rerun then exited zero. Direct result inspection
reports twenty-five tests, twenty-five passed, zero failed, zero skipped, and
zero expected failures. The console has fifteen Search initializations, all
with `fts5_pages=true fts5_blocks=true fts5_readable_blocks=true`; zero false
FTS flags; zero read-only optimizer errors; zero SQLite client/vnode/descriptor
messages; zero notification-rate text; and one `TEST SUCCEEDED` marker.

Green14 nevertheless remains Red. Direct result-node inspection contains the
same single `Runtime Warning` under
`appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()` at its final
assertion. Directly awaiting `vaultFileSystemProcessorTask.value` did not
remove or alter the warning. That production-drain causal theory is therefore
falsified for this result and must not be presented as a fix.

The retained rerun result is
`build/xcode-results/2026-07-14-watcher-drain-priority-green14-rerun-16gib.xcresult`
at 137,440 KiB. Its 1,515,761-byte log is the sibling `.log` file with SHA-256
`c75e36df41ad1aadd321cac3663563b52c4d401d433d9f173e759cea8294c507`.
Before cleanup, the exact disposable app occupied 475,784 KiB; its 40,344-byte
arm64 executable had SHA-256
`7b8cc40bc3ffaea36d5fcc2fb523dd7789aeaaa189ea09e47037519ab07aa912`,
bundle identifier `com.epistemos.appstore`, build `1`, and version `1.0.0`.
The exact 928,375,752-byte universal arm64/x86_64 graph archive had SHA-256
`3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`,
zero universal/arm64/x86_64 `_sqlite3_*` exports, and zero SQLite symbol-name
strings.

Post-run resources were 12,093.06 MiB swap used, 66% free memory, zero
throttled pages, 671 GiB available disk, and no competing process. The exact
disposable rerun DerivedData/app and graph archive were deleted after identity
capture. Broad app/archive inventory is zero; the failed result and log remain
retained. Overall KEELSTONE remains `INCOMPLETE`, and the Release archive is
still blocked.

### Red14 symbolicated teardown root cause

Read-only diagnostic export and unified-log inspection identify the runtime
checker trigger as `dispatch_semaphore_wait`. Green13 and Green14 preserve the
same sixty-six-frame stack shape after accounting for address-space layout.
System-framework symbolication resolves the causal chain as:

`ModelContainer` finalization ->
`NSPersistentStoreCoordinator.removePersistentStore` ->
`NSSQLCore.willRemoveFromPersistentStoreCoordinator` ->
`NSSQLDefaultConnectionManager.disconnectAllConnections` ->
`_checkoutConnectionOfType` -> dispatch synchronous wait.

The test's real missing-page Recall preparation calls
`VaultIndexActor.fullPageData`, opening the background SwiftData/Core Data
connection. The watcher batch, Recall completion hook, and service stop finish
before the warning. The warning occurs during the `@MainActor` test epilogue,
when local `VaultSyncService`/`ModelContainer` destruction removes the
in-memory persistent store on a User-interactive thread while Core Data drains
Utility work. The backtrace excludes the drain continuation, direct Task
await, `AsyncCompletionProbe`, `NSLock`, completion fence, and FSEvents as the
wait owner.

The exact bounded correction is test-only lifetime ownership. First revert
only the ineffective `processorTask.value` experiment to the prior
all-admissions continuation implementation. Then add one private owner for the
affected test: it retains the in-memory container while a nested test-body
scope owns the service; after that scope and its service-stop defer have ended,
an awaited dedicated Utility-QoS queue releases the owner's final container
reference and resumes through a checked continuation. This must leave no leak,
unstructured task, semaphore, warning suppression, production QoS change, or
production watcher behavior change.

The retained Green14 result is the executable Red. After the surgical revert
and test-only correction, re-read the helper, affected test, drain, and exact
diff; run diff/source checks; remove the temporary 410-MiB diagnostic export;
and perform a complete fresh 16-GiB preflight. The first discriminating build
may run only
`appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()`. It must pass
with zero direct result `Runtime Warning` nodes. Only that result can authorize
a later fresh twenty-five-test regression batch. No archive, launch, runtime
matrix, owner-vault, canon/feature work, payment, model/provider, secret,
audio, or later execution key is authorized.

### Red14 utility-release source checkpoint

The causally falsified production change is removed. The production
`waitForVaultMutationDrain()` is restored exactly to its prior all-admissions
checked-continuation implementation; the watcher processor remains detached at
Utility QoS and no production watcher, drain, Recall, checkpoint, or lifecycle
behavior remains changed by Red14.

One private test-only `UtilityModelContainerOwner` now owns its mutable
container reference behind `NSLock` and provides an awaited release on a
dedicated serial Utility-QoS dispatch queue. The checked continuation resumes
only after the queue has cleared the owner and extended the released reference
through that queue block. There is no semaphore, sleep, polling, detached or
unstructured Task, static container retention, suppression, priority override,
or production seam.

Only `appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()` uses the
new owner. Its unchanged behavior body runs inside the existing `@MainActor`
scope; every normal or throwing exit executes the existing service-stop and
temporary-vault cleanup defer before the enclosing helper performs and awaits
the Utility release. Other container tests are unchanged because current
result evidence identifies no equivalent warning in them.

The complete owner/helper/test/drain regions and exact diff were re-read.
`git diff --check` passes and dirty count remains 117. Current SHA-256 is
`7246b51071b6403a2810d22e569eabb6db4337e568b532cc3adccb1b381c28ec`
for `Epistemos/Sync/VaultSyncService.swift` and
`8f03f473815429989288d80b903601dfd1feb00a80a8f73541e18c24d0532832`
for the App Store test file. No test or build has run after this bounded source
checkpoint.

Exact next action: delete and verify absence of the temporary read-only
diagnostic export, then reconstruct the one exact test selector and fresh
absent DerivedData/result/log paths and run the complete locked 16-GiB
preflight. Only a passing gate may authorize the one serial focused test.

The 410-MiB temporary diagnostic export at
`/private/tmp/Epistemos-Green14-Diagnostics-ReadOnly` is now deleted and its
path is absent. The retained Red result remains 134 MiB and its retained log
digest re-verifies as
`c75e36df41ad1aadd321cac3663563b52c4d401d433d9f173e759cea8294c507`.
Dirty count remains 117 and `git diff --check` passes. The focused selector and
complete fresh preflight are now the exact safe continuation.

### Red14 focused utility-release preflight

Two preflight-script attempts stopped before authorization and before any
Xcode command: the first used an invalid slash-bearing `awk` regular
expression, and the second used zsh's special `path` variable as a loop name,
temporarily replacing command lookup before the final assertion. Neither
attempt built, tested, created an app/archive, or changed source. The scanner
was corrected to match process executable names without slash syntax, use a
non-special loop variable, and call the final numeric checker by absolute path.

The complete corrected gate passed after a fresh origin fetch. Branch is
`feat/goose-surface`; local HEAD, fetched `origin/feat/goose-surface`, and the
handoff publication commit all equal
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 117 and
`git diff --check` passes. The focused selector is exactly
`EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()`
and resolves to exactly one current test function.

Swap used is 12,020.94 MiB, strictly below the locked 16,384-MiB ceiling.
System free memory is 67%, pages throttled are zero, disk availability is
668 GiB, and no competing Xcode build, compiler, model, or Epistemos process
is active. Broad Xcode DerivedData, Xcode Archives, `/private/tmp`, and
repository build-root inventory contains zero Epistemos app/archive products.

The fresh DerivedData path
`/private/tmp/Epistemos-Red14UtilityReleaseFocused-16GiB`, result
`build/xcode-results/2026-07-14-red14-utility-release-focused-16gib.xcresult`,
log sibling, and staged `build-rust/libgraph_engine.a` are all absent. Exactly
one immediate-exit serial focused test is now authorized. No second test,
archive, launch, runtime matrix, owner-vault, canon/feature work, payment,
model/provider, secret, audio, or later execution key is authorized by this
preflight.

### Red14 focused utility-release proof passed

The one authorized serial command exited zero. Direct result-summary
inspection reports `Passed`: one total test, one passed, zero failed, zero
skipped, and zero expected failures. Direct test-tree inspection lists only
`AppStoreKeelstoneLaneTests/appStoreVaultWatcherRecallMissingPageCannotApplyOrCheckpoint()`
as `Passed` in 0.023839 seconds. Targeted test-details independently reports
the same one passing run and contains no issue children.

Exact direct counts are zero for `Runtime Warning` in the full test tree, zero
for `Runtime Warning` in targeted test-details, and zero for priority-
inversion, User-interactive/lower-QoS, or `dispatch_semaphore_wait` text in
targeted details. The console independently contains zero matching runtime-
warning/priority text and records the named Swift Testing case passed, its
suite passed, one test in one suite passed, and one `TEST SUCCEEDED` marker.
This closes the single-test causal discriminator: final SwiftData container
release on the awaited Utility queue removes the exact Red14 warning while all
missing-page Recall/requeue/checkpoint assertions remain green.

Direct build-result inspection reports `succeeded`, zero errors, and the same
three unrelated retained warnings: Rust `block` 0.1.6 future incompatibility,
one unused `try?` result in `LiteParsePDFImportController.swift`, and one
unnecessary `await` in `TextCapturePipeline.swift`. Bootstrap console output
also retains existing duplicate-column migration messages and one metadata
`dev_t` message. They are not normalized into a warning-free product claim and
remain later verification debt; they did not create result issue nodes for the
focused test.

The retained 1,469,740-byte log is
`build/xcode-results/2026-07-14-red14-utility-release-focused-16gib.log` with
SHA-256
`e5680932c6df37cab325ef997191204d5457ed16590169098f73aded42b337de`.
The retained result bundle occupies 576 KiB.

Before cleanup, the exact disposable app occupied 475,808 KiB. Its 40,344-byte
arm64 executable has SHA-256
`c9d3d9f54b8e6ce9b3660a2c5ccff7a5b301927b5c6194618a5d7461f9e16aa0`,
bundle identifier `com.epistemos.appstore`, build `1`, and version `1.0.0`.
The build-created `build-rust/libgraph_engine.a` is a 928,375,752-byte
universal x86_64/arm64 archive with SHA-256
`3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.
Its universal, arm64, and x86_64 exported `_sqlite3_*` counts are each zero,
and an independent symbol-name string scan is also zero.

Post-run resources are 13,003.25 MiB swap used, still strictly below the
16,384-MiB lock; 70% free memory; zero throttled pages; 665 GiB available
disk; and zero competing process. Branch/local/origin/handoff identity remains
exact at `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count remains 117
and `git diff --check` passes.

This focused result does not authorize an archive or runtime matrix. Exact next
action: delete only the disposable focused DerivedData/app and staged graph
archive plus temporary parsed-result JSON, retain the result/log, and verify
empty broad app/archive inventory. Then recover the exact twenty-five Green14
selectors and run a new complete 16-GiB preflight. Only that passing gate may
authorize one fresh serial regression batch requiring 25/25 and zero direct
Runtime Warning nodes.

The exact focused DerivedData/app, staged graph archive, and temporary parsed-
result JSON files are now absent. Broad app/archive inventory across Xcode
DerivedData, Xcode Archives, `/private/tmp`, and the repository build root is
zero. The retained result remains 576 KiB and the retained log digest
re-verifies as
`e5680932c6df37cab325ef997191204d5457ed16590169098f73aded42b337de`.
Cleanup resources are 13,003.25 MiB swap used, 69% free memory, zero throttled
pages, 668 GiB available disk, and zero competing process. Dirty count is 117
and `git diff --check` passes. The exact safe continuation is now selector
recovery and a new complete regression preflight.

### Red14 twenty-five-test regression preflight

The exact Green14 selection was recovered from the retained command line and
audited against current source. It contains twenty-five total and twenty-five
unique `()`-suffixed identifiers; every identifier resolves to exactly one
current App Store test function. Its first selector is
`appStoreCommittedSearchRebuildSurvivesCheckpointMaintenanceFailure()` and its
last is `appStoreLinkedSQLiteProvidesAllSearchFTS5RoundTrips()`.

After a fresh origin fetch, branch/local/origin/handoff identity remains exact
at `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and
`git diff --check` passes. Swap used is 13,003.25 MiB, strictly below the
16,384-MiB ceiling; free memory is 70%; pages throttled are zero; available
disk is 668 GiB; and competing-process and broad stale app/archive inventories
are zero.

Fresh paths are absent for
`/private/tmp/Epistemos-Red14UtilityReleaseRegression25-16GiB`,
`build/xcode-results/2026-07-14-red14-utility-release-regression25-16gib.xcresult`,
its log sibling, and `build-rust/libgraph_engine.a`. Exactly one immediate-
exit serial twenty-five-test regression batch is authorized. It must prove
25/25 with zero failed/skipped/expected failures and zero direct Runtime
Warning nodes while retaining the prior FTS5/SQLite/graph gates. No archive,
launch, runtime matrix, owner-vault, feature/canon work, or later execution key
is authorized by this preflight.

### Red14 twenty-five-test regression passed

The one authorized immediate-exit serial command exited zero. Direct result
summary reports `Passed`: twenty-five total tests, twenty-five passed, zero
failed, zero skipped, and zero expected failures. A recursive direct test-tree
audit independently counts twenty-five Test Case nodes, all `Passed`, zero
non-passing cases, and zero warning/issue/failure nodes. It lists every
requested identifier exactly once. The corrected missing-page Recall test
passed again in 0.021 seconds.

The full direct test tree contains zero `Runtime Warning` strings. Targeted
test-details for the formerly Red case contains zero Runtime Warning nodes and
zero priority-inversion, User-interactive/lower-QoS, or
`dispatch_semaphore_wait` text. The console independently contains zero
matching runtime-warning/QoS text, records twenty-five named Swift Testing
case passes, one 25-test suite pass, one `TEST SUCCEEDED`, and zero failure
markers. Red14 is therefore closed by both a one-test discriminator and a
fresh full selected regression, not by console grep alone.

The console contains fifteen Search initializations, all exactly
`fts5_pages=true fts5_blocks=true fts5_readable_blocks=true`, with zero false
flags. It contains zero read-only/`SQLITE_READONLY` errors, zero SQLite client-
bug/vnode/invalidated-descriptor messages, and zero real notification posting-
rate/per-second warnings. An initially broad `rate.*notification` query had one
false positive in the compiler action name `SwiftExplicitDependencyGeneratePcm
... UserNotifications`; the corrected semantic query returns zero.

Direct build-result inspection reports `succeeded`, zero errors, and the same
three retained warnings: Rust `block` 0.1.6 future incompatibility, an unused
`try?` in `LiteParsePDFImportController.swift`, and an unnecessary `await` in
`TextCapturePipeline.swift`. The test summary also flags two duration outliers
at 0.22 and 0.25 seconds, and bootstrap output retains twelve duplicate-column
migration messages plus one metadata `dev_t` message. These remain explicit
later verification/performance debt and are not converted into a global
warning-free or release-ready claim.

The retained 1,511,031-byte log is
`build/xcode-results/2026-07-14-red14-utility-release-regression25-16gib.log`
with SHA-256
`2f3690e5d835f5ade2321ef0547066b7e3cc894b41698cf1cb4f6c1cc0c657d7`.
The retained result bundle occupies 800 KiB.

Before cleanup, the exact disposable app occupied 475,812 KiB. Its 40,344-byte
arm64 executable has SHA-256
`9d07036d94c49c024581222f08e84cbfe80d7b107e2ab3ea46b3d5d0375ff6ae`,
bundle identifier `com.epistemos.appstore`, build `1`, and version `1.0.0`.
The build-created 928,375,752-byte universal x86_64/arm64 graph archive has
SHA-256
`3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`;
universal, arm64, and x86_64 `_sqlite3_*` export counts and the independent
SQLite symbol-name string count are all zero.

Post-run resources are 12,963.25 MiB swap used, below the 16,384-MiB ceiling;
69% free memory; zero throttled pages; 665 GiB available disk; and zero
competing process. Branch/local/origin/handoff identity remains exact at
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and
`git diff --check` passes.

This closes the bounded Red14 warning leg but is not an archive, full runtime,
manual UI, distribution, or release-readiness pass. Exact next action: delete
only the disposable regression DerivedData/app, staged graph archive, and
temporary parsed-result JSON; retain result/log evidence; and verify zero
broad app/archive products. Then perform a read-only comparison against the
existing KEELSTONE evidence debt to determine whether the one fresh Release
archive gate can open. No archive may start without another complete 16-GiB
preflight and confirmation that no earlier blocking evidence leg remains.

The exact disposable regression DerivedData/app, staged graph archive, and
temporary parsed-result JSON are now absent. Broad app/archive inventory across
Xcode DerivedData, Xcode Archives, `/private/tmp`, and the repository build root
is zero. The retained result remains 800 KiB and the retained log digest
re-verifies as
`2f3690e5d835f5ade2321ef0547066b7e3cc894b41698cf1cb4f6c1cc0c657d7`.
Cleanup resources are 12,963.25 MiB swap used, 69% free memory, zero throttled
pages, 668 GiB available disk, and zero competing process. Dirty count remains
117 and `git diff --check` passes. The exact safe continuation is now the
read-only debt comparison; no archive is authorized until that comparison and
a new complete 16-GiB archive preflight both pass.

### Current-source archive authorization comparison

The read-only comparison is complete. Red14 is closed by the fresh focused
1/1 result and fresh selected 25/25 result, each with zero failed, skipped, or
expected-failure tests and zero direct Runtime Warning nodes. The explicit
owner sequence at this document's historical resumption boundary is narrow
current-source regression, one fresh `Epistemos-AppStore` Release archive,
every artifact gate against that exact archive, and only then the finite
runtime matrix. No earlier retained Red leg remains designated as a
prerequisite to constructing that archive.

Broader non-App-Store suites, Eidos/Spotlight/authoritative-rescan/manual-sync
and structural-recovery coverage, the three retained build warnings, bootstrap
messages, performance/storage soak, manual runtime, distribution, and repeated
zero-fail evidence remain explicit later debt. They prevent a release-ready
verdict but do not reorder the owner's current archive-first evidence chain.

The older handoff checkpoint still describes a removed July 13 archive and
says not to rebuild it. Actual broad inventory is zero, and the current-source
evidence above supersedes that stale artifact instruction. The old archive must
not be reused; the handoff will be reconciled to the exact new artifact after
its result is known.

The archive wrapper, release gate, bundle scanner, project build phases,
scheme, Release settings, entitlements, and privacy manifest have been read in
current source. The sole allowed next action is one new complete 16-GiB
preflight for fresh paths, followed—only if every gate passes—by exactly one
serial unsigned local-evidence archive. No launch is authorized. The intended
fresh paths are:

- DerivedData:
  `/private/tmp/Epistemos-KeelstoneCurrentReleaseArchive-16GiB`
- archive:
  `build/archives/Epistemos-FreeV1-current-2026-07-14.xcarchive`
- result:
  `build/xcode-results/2026-07-14-keelstone-current-release-archive-16gib.xcresult`
- log:
  `build/xcode-results/2026-07-14-keelstone-current-release-archive-16gib.log`

### Current-source Release archive preflight passed

After a fresh origin fetch, branch, local HEAD, fetched origin, and handoff
publication identity are exact at
`668b52cfb43721de95db102260d9f327ae24e13e`. Dirty count is 117 and
`git diff --check` passes. The first inventory-only scanner failed closed before
Xcode because the optional Xcode Archives root is absent and `find` returned
nonzero under `pipefail`; it created no product and changed no source. The
corrected scanner skips absent optional roots.

The complete corrected preflight at 2026-07-14 02:46:39 CDT reports 12,915.25
MiB swap used, strictly below 16,384 MiB; 73% free memory; zero throttled
pages; 667.68 GiB available disk; zero competing Xcode/compiler/model/
Epistemos process; zero app/archive products; and zero fresh-path conflicts.
Xcode is 26.6 (17F113), the SDK is 26.5, and Cargo, Rust, and Node are present.

Exactly one serial local-evidence `Epistemos-AppStore` Release archive is now
authorized at the fresh paths above. It will explicitly disable Apple signing
and use an explicit fresh result bundle. Free V1 does not register the retained
paid-only Llama package, so the wrapper's conditional Llama download does not
run. The prebuild may refresh its pinned generated editor resources; any
resulting worktree delta must be inspected rather than silently normalized.
No second archive, app launch, runtime matrix, vault, provider/model, secret,
audio, canon/feature, payment, or later execution key is authorized.

### Current-source Release archive and exact artifact gates passed

The one authorized wrapper invocation completed its serial package-resolution
step and exactly one `Epistemos-AppStore` Release archive action. It used the
fresh paths recorded above, explicit package-lock/no-plugin-validation flags,
`EPISTEMOS_TIPTAP_DEVELOPMENT=0`, no paid-model source environment, and
`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`. The process exited zero and
the retained console contains exactly one `** ARCHIVE SUCCEEDED **` marker and
no archive-failure marker.

Direct `xcresulttool get build-results` inspection of
`build/xcode-results/2026-07-14-keelstone-current-release-archive-16gib.xcresult`
reports `status=succeeded`, zero errors, and thirteen warnings. The warnings
are one future-incompatibility notice for Rust `block` 0.1.6, one unnecessary
`await` in `TextCapturePipeline.swift`, one unused `try?` in
`LiteParsePDFImportController.swift`, and ten explicit-`Selector` warnings in
`MarkEditShellCompatibility.swift`. They remain verification/code-quality debt;
this evidence is not warning-free and is not a release-readiness verdict.

The unsigned archive identity captured before local signing was:

- archive:
  `build/archives/Epistemos-FreeV1-current-2026-07-14.xcarchive`;
- archive size: 431,748 KiB before signing;
- app size: 153,784 KiB before signing;
- bundle `com.epistemos.appstore`, version `1.0.0`, build `1`;
- universal executable architectures `x86_64 arm64`;
- unsigned 116,682,488-byte executable SHA-256
  `a217d7aac2f56d40b2769cd9a8692e4af7cbd4d00e98865cf5b2b07de9f62b55`.

The exact Release-created graph archive was captured before disposable build
cleanup at `build-rust/libgraph_engine.a`: 312,039,112 bytes, universal
`x86_64 arm64`, SHA-256
`b3daf69e1d1f220278a2e99921e488465178ca9bdcdedbed2ce5814a3160c58e`.
Its universal, arm64, and x86_64 `_sqlite3_*` export counts were each zero, and
an independent `sqlite3_` string-name scan was also zero.

After those identities were captured, only the disposable archive DerivedData
at `/private/tmp/Epistemos-KeelstoneCurrentReleaseArchive-16GiB` and the staged
graph archive were deleted. Both are absent. The retained Release archive,
result, and log remain. Broad inventory now finds exactly one Epistemos
xcarchive and exactly one `Epistemos.app`, which is the app nested in that
archive; no `/private/tmp` or DerivedData app remains.

The exact archive app was then locally ad-hoc signed for evidence with
`Epistemos/Epistemos-AppStore.entitlements`. Strict deep signature verification
passes for the app and both nested dylibs. Current signing identity is ad hoc,
`TeamIdentifier` is not set, and CDHash is
`1e5bf8ec807e1cea25414214c663a554ac5b009b`. Effective entitlements include App
Sandbox, the shared application group, audio input, app-scope bookmarks,
user-selected read/write files, and network client. This is local artifact
evidence only; it is not Apple distribution signing, App Store validation, or
submission proof.

Post-sign exact identity is:

- executable SHA-256
  `16773d596813727bcf8894b6719c2ec329fb5ac29d7a1f124d670fffb28575c8`;
- deterministic file-list app-tree SHA-256
  `f5335879f45df66bc5a290d48f41296a46ba33eb3924bf8fd41559ee0fc1d9cb`;
- app size 154,020 KiB and archive size 431,984 KiB;
- archive `Info.plist` SHA-256
  `baa1ca8be27b50b52bb90e448483a24244c1c405d7c5f35f72602e1eeed9b665`;
- archive scheme `Epistemos-AppStore` and archived application path
  `Applications/Epistemos.app`.

The integrated KEELSTONE release gate and a separately retained fresh bundle
scanner both pass against that exact signed app. Primary direct audit confirms:

- strict deep signature verification passes;
- the main bundled privacy manifest is byte-identical to
  `Epistemos/Resources/PrivacyInfo.xcprivacy`, with SHA-256
  `e1c392f10f990c037d16b804d066770599e1a29e78b6ffd512646a168705c406`;
- the second expected manifest belongs to the nested `GRDB_GRDB.bundle` and has
  SHA-256
  `17784da62e51f74c5859df32fe402e01e25cdf6f797a4add06e2a3ce15c911f4`;
- the main executable is universal `x86_64 arm64` and its exact compile actions
  contain `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`, and `EPISTEMOS_FREE_V1` for
  both architectures;
- paid-only June/model/agent assets and `llama`, `agent_core`, and `omega_mcp`
  linkage are absent;
- test frameworks and quarantine attributes are absent;
- all seven scanner finding files (`forbidden-*` and quarantine) are empty;
- the only executable files are the app executable and the two expected
  `libepistemos_core` and `libepistemos_shadow` dylibs.

The first combined read-only audit stopped after successful plist validation
because it incorrectly treated all nonempty scanner inventory/report files as
findings and assumed one total privacy manifest. That was an audit-assertion
defect, not an artifact failure: scanner inventories such as `all-files.txt`,
`otool-L.txt`, and `nm-gU.txt` are expected to be nonempty, and GRDB carries its
own nested privacy manifest. Rerunning every assertion separately confirmed
zero nonempty finding files and exact main-manifest identity. No archive byte,
source file, signature, or product was changed by this diagnosis.

An independent read-only audit reproduced the strict signature, entitlement,
architecture, privacy, paid-asset/linkage, test-artifact, quarantine, result,
scanner-finding, product-inventory, dirty-state, and diff checks and found no
real artifact red. It independently identified the total-manifest, scanner-
inventory, and literal-scanner-`PASS` assumptions as invalid shell assertions.
Artifact gates are green; the thirteen warnings and absent distribution
identity remain debt rather than being silently relabeled as passes.

Retained artifact evidence:

- archive log: 2,458,874 bytes, SHA-256
  `3f0fb10cd849641c2c4384690bad149bc6e19c7af2e8e97d5a7758e746841641`;
- local-sign/strict-verify log: 1,380 bytes, SHA-256
  `1ea1149771257f2a754fafe78a2726fbe7e25f8eb09a94b8583d6a21dc8b7972`;
- gate log SHA-256
  `3bd36a2b2fef3fe75d73209de48720fad36b2e3ca87453008fb65cff08e5d757`;
- standalone scan log SHA-256
  `4e6138b971da4794814c5ea6ac05e7219e62d1480dacb18eeb50fa0a5d324f28`;
- standalone report directory:
  `build/appstore-audit-2026-07-14-keelstone-current-release-16gib`.

After artifact diagnosis, branch/local/origin/handoff identity remains exact at
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count remains 117 and
`git diff --check` passes. Resources are 13,402.38 MiB swap used, strictly
below the 16,384-MiB owner ceiling; 74% free memory; zero throttled pages;
665 GiB available disk; and zero competing Xcode/compiler/model/Epistemos
process.

This opens only the finite owner-visible Free V1 runtime matrix. Before launch,
run another complete 16-GiB resource/process/product-identity preflight and
keep this archive immutable. If it passes, launch only this archive app, use a
disposable vault, and collect correlated logs for the already-recorded matrix.
Do not access the owner vault, private/removable material, payment/account
state, model/provider/secret paths, or paid June/Browser/ResearchHub features.
Do not begin canon/feature work or another execution key. KEELSTONE remains
`INCOMPLETE` until the finite runtime matrix is recorded.

### Current-source finite runtime preflight passed

After another fresh origin fetch, branch/local/origin/handoff identity remains
exact at `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count is 117 and both
staged and unstaged diff checks pass. Swap used is 13,378.38 MiB, strictly below
the locked 16,384-MiB ceiling; free memory is 75%; pages throttled are zero;
available disk is 665.37 GiB; and no competing Xcode/compiler/model/Epistemos
process exists.

Product and byte identity also pass: exactly one xcarchive and its one nested
app exist, with no `/private/tmp` or DerivedData app; strict deep signing is
valid; app-tree SHA-256 is
`f5335879f45df66bc5a290d48f41296a46ba33eb3924bf8fd41559ee0fc1d9cb`;
executable SHA-256 is
`16773d596813727bcf8894b6719c2ec329fb5ac29d7a1f124d670fffb28575c8`;
architectures are `x86_64 arm64`; and CDHash is
`1e5bf8ec807e1cea25414214c663a554ac5b009b`. The disposable runtime root,
retained runtime-evidence directory, and correlated runtime-log path are all
fresh and absent.

Only the finite Free V1 runtime matrix is now authorized. Launch must set
`EPISTEMOS_APPLICATION_SUPPORT_ROOT` to the disposable runtime root and
`EPISTEMOS_SKIP_VAULT_RESTORE=1` before the exact archive app starts, so the
production binary uses isolated application-support storage and cannot restore
the owner's saved vault bookmark. No paid/AI, account/payment, private/
removable, model/provider/secret, or later-key work is authorized.

### Runtime-isolation preflight blocked launch before owner data access

The source-level launch audit found that the two-variable plan above is safe
from bookmark restore but cannot satisfy the required cross-process restore
leg: `EPISTEMOS_SKIP_VAULT_RESTORE=1` makes `VaultSyncService` use a fresh
random `UserDefaults` suite for every process. A bookmark selected during the
first disposable launch therefore cannot exist on the second launch. The same
mode asks `SavedApplicationStatePurger` to remove saved-state directories for
the production bundle ID. Both currently targeted directories were confirmed
absent, so nothing was deleted, but launching on that basis would still be an
unnecessary mutation risk. The fixed App Group also remains outside the
existing Application Support override.

No app process was started, no runtime log or support/vault directory was
created, and no owner vault, preference, saved state, app-group data, Keychain,
model/provider, audio, private, or removable material was accessed. The prior
runtime authorization is withdrawn until a surgical, test-first isolation seam
provides all of the following together:

1. a validated stable audit-only `UserDefaults` suite that survives relaunch;
2. a validated disposable App Group root;
3. the existing disposable Application Support root;
4. restorable-document suppression without deleting production saved state;
5. normal security-scoped bookmark restoration inside those isolated stores.

This is the failed evidence leg anticipated by the owner instruction to fix
only a failed leg. The exact next action is failing source/unit coverage for
that bounded isolation contract, then the minimal implementation. Before its
replacement build, delete the now-stale sole archive/app under the one-current-
build rule. No unrelated feature, performance, calendar/planner/export, canon,
paid, or later-key work is authorized by this blocker.

### Runtime-audit isolation expected-red evidence

Before the focused test, the previously gated July 14 archive and its nested
app were reverified and deleted under the one-current-build rule. The focused
two-test build then failed at the expected compile boundary: the new audit-only
defaults/App Group environment keys, full-isolation validator, stable defaults
factory, App Group environment injection, and suppress-without-purge state
policy do not yet exist. No test executed and no unrelated source failure was
reported. The retained result contains zero executed tests and result
`unknown`, consistent with compile failure.

Retained expected-red evidence:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-red-16gib.xcresult`;
- log SHA-256:
  `13ca980883717b962a50f3efcd2b75ba6cd2a0c1665671461d2694a568fcb785`;
- disposable arm64 test-app executable SHA-256 before cleanup:
  `48a77aba5a89da185c7da5d8f9eb16f6ce84a7a0fc3b00dbab426d284d66b539`;
- disposable universal staged graph-archive SHA-256 before cleanup:
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

Immediate post-run resources were 13,346.38 MiB swap used, below the strict
16,384-MiB ceiling; 69% free memory; zero throttled pages; and 663 GiB
available disk. The failed build authorizes only the surgical isolation seam
described above, followed by the same narrow two-test proof under a new full
preflight.

### Runtime-audit isolation source correction complete; green proof pending

The bounded source correction now provides one fail-closed full-audit tuple:
`EPISTEMOS_APPLICATION_SUPPORT_ROOT`, `EPISTEMOS_AUDIT_APP_GROUP_ROOT`, and
`EPISTEMOS_AUDIT_DEFAULTS_SUITE`. A request containing either new audit key is
invalid until all three values validate together. Roots are canonicalized
through symlinks, protected Library components are compared case-insensitively,
identical and ancestor/descendant roots are rejected, and an active audit
returns its already-validated Application Support root without a production
fallback. Normal launches retain the prior standard-defaults, App Group, and
Application Support paths.

All product defaults and SwiftUI `@AppStorage` sites now resolve through the
single stable runtime defaults object. Audit mode skips the historical
`Brainiac.epistemos`/`com.lucid.app` bookmark migration, routes App Group data
without invoking the production provider or legacy-copy path, suppresses
restorable documents/window frame autosave, and prevents saved-state deletion
even when a stale skip-restore variable is present. Recovery snapshots return
no production preference-plist URL in active audit mode. The setup assistant's
one-click default vault resolves to `Runtime Audit Vault` beneath the disposable
Application Support root rather than `~/Documents/Epistemos`.

Two final automatic-launch bypasses found by independent read-only review are
also closed. The App Store target no longer compiles or invokes the external
Claude.app font-probe path, while every bundled Matrix, Matrix Bold, Matrix
Dots, Chonky, and other display-font registration remains. A full-audit Release
launch suppresses the optional Metal shader prewarm, so it cannot create the
global `com.epistemos.shader-warmup.lock`; a normal non-audit Release launch
retains that prewarm.

The focused tests now cover full/empty/incomplete request state, invalid suite,
same/colliding/nested roots, case variants, symlink escape, isolated default
vault, normal/audit Metal policy, App Store external-font denial, bundled-font
source presence, suppress-without-purge, audit-vs-standard defaults identity,
same-suite handle persistence, legacy App Group non-copy, and provider
non-invocation. The handle test is deliberately named as same-process evidence;
actual process-one/process-two bookmark restoration remains runtime debt.

Current source sweeps find exactly one intentional `UserDefaults.standard`
reference, inside the normal-launch resolver; zero shorthand standard-default
assignments; zero unscoped product `@AppStorage`; and no direct production
Application Support lookup outside the central normal fallback (plus one
comment). `git diff --check` passes. The dirty inventory is 178 entries and is
preserved as the current in-flight feature state, not treated as cleanup
permission.

No build, test, archive, app launch, model/provider request, Keychain read,
audio operation, or owner/private/removable-data access has occurred since the
expected-red command. Exact next action: fresh origin/Git/resource/process/
product/path preflight under the strict swap-used-below-16,384-MiB ceiling,
then only the same two focused tests. Runtime, archive, canon, feature, paid,
and later-key work remain unauthorized until that proof is green and inspected.

### Runtime-audit isolation first green attempt stopped at compiler boundary

The fresh locked preflight for the first attempted green proof passed: branch,
local HEAD, fetched `origin/feat/goose-surface`, and the handoff publication SHA
were exact at `668b52cfb43721de95db102260d9f327ae24e13e`; dirty state was
179 entries; swap used was 13,314.38 MiB, strictly below the locked
16,384-MiB ceiling; free memory was 75%; pages throttled were zero; available
disk was 665 GiB; and no competing Xcode/compiler/model/Epistemos process or
stale app/archive/graph product existed.

The one serial two-selector command then stopped before test execution. Swift
6 rejected `FoundationSafety.runtimeUserDefaults` because `UserDefaults` is
non-`Sendable`, and explicitly offered `nonisolated(unsafe)` for a property
whose shared mutable access is externally protected. The retained result
reports zero tests, zero passed, zero failed, and result `unknown`; this is a
compiler-red artifact and is not green runtime or test evidence.

Retained failure evidence:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-16gib.log`;
- log SHA-256:
  `096df8720308b1e9e341c15ceace75bdb7e47083cb4014c1210fc5ee9e23d96c`;
- exact diagnostic: static property `runtimeUserDefaults` is not
  concurrency-safe because non-`Sendable` `UserDefaults` may have shared
  mutable state; testing was cancelled because the build failed.

Before cleanup, the failed build contained no
`Contents/MacOS/Epistemos` executable. Its staged graph archive was
928,375,752 bytes, universal `x86_64 arm64`, with SHA-256
`3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.
Post-failure resources remained within the owner lock at 13,314.38 MiB swap
used, 64% free memory, zero throttled pages, and 663 GiB available disk, with
no competing process.

Exact next action: retain the result and log; delete only
`/private/tmp/Epistemos-RuntimeAuditIsolationGreen-16GiB` and the staged graph
archive; apply the compiler-requested `nonisolated(unsafe)` annotation to the
stable shared defaults `static let`; re-read and diff-audit; then run a new
complete 16-GiB preflight before retrying the identical two selectors under
fresh result and DerivedData paths. No archive, launch, canon, feature, paid,
or later execution key is authorized by this failure.

### Runtime-audit isolation compiler correction and fresh retry preflight

The failed build's disposable DerivedData and staged graph archive were deleted
after their identities were reverified; the compiler-red result and log remain.
The source correction is exactly one annotation:
`public nonisolated(unsafe) static let runtimeUserDefaults`. It preserves the
stable process-wide defaults handle and changes no suite, resolver, caller, or
product behavior. Independent read-only review confirmed that a wrapper,
computed factory, global unchecked conformance, or main-actor migration would
be broader and would conflict with existing nonisolated consumers. Source
re-read, semantic defaults/Application Support sweeps, and both diff checks
pass.

The first post-correction preflight collection observed green state but its
final shell assertion did not execute because a loop variable named `path`
temporarily replaced zsh's command-path array. It launched no build or test and
is non-authorizing. A complete corrected preflight was run from the beginning
and passed:

- branch `feat/goose-surface`, local HEAD, fetched
  `origin/feat/goose-surface`, handoff publication, and supplied publication
  SHA all equal `668b52cfb43721de95db102260d9f327ae24e13e`;
- `git pull --ff-only` reports already up to date; dirty count is 179; staged
  and unstaged diff checks pass;
- swap used is 13,234.38 MiB, strictly below 16,384 MiB; free memory is 71%;
  pages throttled are zero; and available disk is 696,667,760 KiB;
- no competing Xcode/compiler/model/Epistemos process exists;
- Epistemos app count, archive count, and staged graph-archive count are each
  zero; all three fresh retry output paths are absent.

This authorizes exactly one serial rerun of the same two focused selectors with
fresh DerivedData, result, and log paths. It does not authorize archive,
launch, canon, feature, paid, model/provider, secret, private/removable-data, or
later-key work.

### Runtime-audit isolation Green2 retry is red; archive gate remains closed

The one serial Green2 command cleared the earlier Swift concurrency diagnostic,
built the complete arm64 test host, and executed exactly the selected two tests.
The result is `Failed`: one test passed and one failed with two recorded
expectations. Both failures show identical canonical filesystem paths with only
the trailing directory-marker representation differing:

- the actual audit App Group URL retains `App Group/` while the expected URL is
  `App Group`;
- the actual default audit-vault URL retains `Runtime Audit Vault/` while the
  expected URL is `Runtime Audit Vault`.

This is red evidence and is not relabeled green. It does not show either path
escaping its disposable root, but the two URL-equality oracles must compare
canonical `.path` values before they can prove the intended boundary.

Retained Green2 evidence and disposable product identity:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-2-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-2-16gib.log`;
- log size 1,276,153 bytes and SHA-256
  `0d097d773956d4eb1007f54d9fa671f9f86c4482697332e4c28728c016e5fa28`;
- result totals: two tests, one passed, one failed, zero skipped, result
  `Failed`;
- disposable app size 476,096 KiB; 40,344-byte arm64 executable SHA-256
  `7847353ee4fdb51e243758760bd58e3fe06db919374067950a485641925d4325`;
- staged graph archive 928,375,752 bytes, universal `x86_64 arm64`, SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

Immediate resources remained inside the owner lock: 13,226.38 MiB swap used,
66% free memory, zero throttled pages, 693,912,304 KiB available disk, and no
competing Xcode/compiler/model/Epistemos process.

The same log exposed a separate evidence-process safety defect before the
selectors: XCTest-host bootstrap announced the production
`~/Library/Group Containers/group.com.epistemos.shared` path. Current source
confirms `prepareSharedSubstrateContainer` called `ensureLayout` and migration
checks there because this test process did not carry the full audit tuple.
The container's top-level modification time was 2026-07-13 05:37:21 -0500,
before the 2026-07-14 04:28:04 -0500 test start, and no owner file contents were
opened. That limited fact does not prove zero nested access. Recursive
metadata-only inspection stalled, was aborted, and all associated probe
processes were terminated; do not inspect the owner container further.

Exact next action: retain the red result/log, delete only the disposable
DerivedData/app and staged graph archive, correct the two test oracles to
compare canonical path strings, and ensure the next XCTest host is isolated
before bootstrap through a fresh valid three-part audit environment or an
equally narrow source-level XCTest fallback. Re-read and diff-audit, then run a
new complete 16-GiB preflight before the same two selectors under fresh paths.
The next log must name only the disposable App Group root. Archive, runtime,
canon, feature, paid, model/provider, secret, owner/private/removable-data, and
later-key work remain unauthorized.

### Runtime-audit isolation Green3 corrected retry preflight passed

Green2 cleanup is complete: its disposable DerivedData/app, staged graph
archive, per-process test runtime, and temporary saved state are absent, while
the red result and log remain. The two failing test oracles now compare only
canonical `.path` strings; source behavior and directory semantics are
unchanged. The changed region was re-read and staged/unstaged diff checks pass.

The Green3 test host will be isolated from process start with:

- Application Support beneath
  `/private/tmp/Epistemos-RuntimeAuditIsolationGreen3-16GiB-Runtime`;
- an App Group sibling beneath that same disposable root;
- audit defaults suite
  `com.epistemos.audit.runtime.keelstone.green3.20260714`.

The suite and runtime root were cleared before the fresh preflight. Branch,
local HEAD, fetched remote, handoff publication, and supplied publication SHA
are exact at `668b52cfb43721de95db102260d9f327ae24e13e`; pull is already up to
date; dirty count is 179. Swap used is 13,226.38 MiB, strictly below 16,384 MiB;
free memory is 67%; pages throttled are zero; disk is 696,326,296 KiB; competing
process count is zero; and app, archive, and staged graph counts are zero. All
fresh output paths are absent.

This authorizes one serial Green3 execution of exactly the same two selectors.
The log must name only the disposable App Group root before selectors; any
production App Group line is an immediate safety failure even if tests pass.
Archive, runtime, canon, feature, paid, model/provider, secret,
owner/private/removable-data, and later-key work remain closed.

The preflight above did not authorize an executed command. Before Green3 began,
independent review found that supplying the tuple only on this command would not
protect future XCTest callers of the shared App Group container. A test-first
injected-provider assertion now requires an XCTest process to keep layout in a
disposable fallback, never call the provider, and never create its returned
production-like path. The source correction is one guard after explicit-audit
precedence: XCTest returns no provider container, so `rootURL` uses the existing
per-process test fallback; normal non-test launches still call the production
provider, and explicit valid audit mode still uses its supplied App Group root.

Those source/test edits invalidate the prior preflight. No Green3 build or test
started under it. A complete re-read, diff/semantic sweep, cleanup confirmation,
and fresh strict-below-16,384-MiB preflight are required before the same two
selectors may run.

The complete replacement preflight now passes after the source/test correction.
Explicit audit precedence, XCTest provider denial, normal-only provider
invocation, canonical path assertions, and central defaults/Application Support
sweeps were re-read; both diff checks pass. Branch/local/origin/handoff/supplied
identity remains exact at `668b52cfb43721de95db102260d9f327ae24e13e`, pull is
already up to date, and dirty count is 179. Swap used is 13,226.38 MiB, free
memory is 68%, throttled pages are zero, disk is 696,325,116 KiB, no competing
process exists, and app/archive/staged-graph counts are zero. The Green3
DerivedData/result/log/runtime root and audit suite are fresh.

This replacement preflight authorizes one serial Green3 run of the same two
selectors under the full process audit tuple. The injected XCTest-only
container in the second selector separately proves that a future test process
without that tuple never invokes the production App Group provider.

### Runtime-audit isolation Green3 tests pass; defaults safety debt remains

Green3 compiled the full arm64 host and passed both selected Swift Testing
cases: two total, two passed, zero failed or skipped, result `Passed`. The
canonical path corrections pass, explicit audit App Group routing still denies
the production provider, and the injected XCTest-only container proves its
provider is never invoked and its layout remains disposable.

Retained Green3 evidence and disposable product identity:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-3-16gib.xcresult`;
- log size 1,274,417 bytes and SHA-256
  `55ea4a46b1b877ef9c299eae7755385a160697a1f7331c53bf2400975337e561`;
- disposable app 476,100 KiB; 40,344-byte arm64 executable SHA-256
  `eff36599ccab3836ad937532cb32b7c7911af3745c8567f8959e886fc4b457f9`;
- staged graph archive 928,375,752 bytes, universal `x86_64 arm64`, SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

The startup log contains zero references to the production App Group and one
`AppBootstrap` line under the PID-scoped
`Epistemos-TestRuntime/62525/Application Support/Epistemos` fallback. This is
direct evidence that the new generic XCTest App Group denial worked.

The same log also contains zero references to the shell-supplied Green3 audit
root, which did not exist after the run. Because explicit audit-root precedence
would have selected that root if the variables reached the hosted app, Xcode
did not propagate the tuple into the test host. In `.notRequested` mode the
central defaults resolver therefore still selected `UserDefaults.standard`.
No production preference contents were inspected, but this is not acceptable
owner-preference isolation and the archive gate remains closed despite 2/2
test success.

Immediate resources are 13,537.38 MiB swap used, below 16,384 MiB; 67% free
memory; zero throttled pages; 693,564,212 KiB available disk; and no competing
process. Exact next action: retain Green3 result/log; delete its disposable
DerivedData/app, staged graph archive, PID test runtime, and temporary saved
state; add a PID-scoped test-only defaults suite with startup and termination
cleanup; extend the same selected test to prove nonstandard same-suite behavior
and cleanup; then re-read/diff-audit and run another complete 16-GiB preflight.
No archive, runtime matrix, canon, feature, paid, model/provider, secret,
owner/private/removable-data, or later-key work is authorized yet.

### PID-scoped XCTest defaults correction complete; Green4 proof pending

Green3 cleanup is complete: its disposable DerivedData/app, staged graph
archive, PID-scoped test runtime, temporary saved state, requested audit root,
and named audit suite are absent. The passing result and log remain.

The bounded source correction extends the existing central defaults seam. When
no audit tuple is requested, an XCTest process now receives
`com.epistemos.test.runtime.<pid>` instead of `UserDefaults.standard`. The
stable global handle removes that PID domain once at startup; the existing
test-only app teardown removes it again before process exit. A valid explicit
audit tuple still has precedence, an invalid request still fails closed, and a
normal non-test launch still returns standard defaults.

The already-selected second test now uses an injected positive PID and XCTest
environment to prove:

- the derived suite name is test-only and the resolved object is not standard;
- startup reset removes a stale sentinel;
- two handles for the same PID suite observe the same isolated value;
- explicit cleanup removes that value;
- the regression itself leaves its injected suite absent.

Source re-read and semantic sweeps find exactly one intentional
`UserDefaults.standard` occurrence in the normal non-test fallback, no unscoped
product `@AppStorage`, and clean staged/unstaged diff checks. App/archive/staged
graph inventory is empty. No build or test has run since this correction.
Exact next action: independent read-only review, then a complete fresh
strict-below-16,384-MiB preflight. If it passes, run only the same two selectors
under fresh Green4 paths; inspect 2/2 result, zero production App Group log
hits, PID-scoped App Group fallback, and absence of the actual PID defaults
suite after termination. Archive/runtime/canon/feature/paid/model/provider/
secret/owner-private-removable/later-key work remains closed.

The complete Green4 preflight now passes. Branch/local/origin/handoff/supplied
identity is exact at `668b52cfb43721de95db102260d9f327ae24e13e`, pull is
already up to date, dirty count is 179, and both diff checks pass. Swap used is
13,537.38 MiB, strictly below 16,384 MiB; free memory is 68%; throttled pages
are zero; available disk is 695,985,676 KiB; no competing process exists; and
app, archive, staged graph, and stale test-defaults plist counts are all zero.
All Green4 paths are fresh.

This authorizes only the same two selectors once under Green4 paths. No
process-level audit tuple will be supplied: actual hosted-app startup must use
the generic PID-scoped App Group and defaults fallbacks, and the post-run check
must prove the actual PID defaults domain is absent after termination.

### Runtime-audit isolation Green4 tests pass; test-harness cleanup is red

The one authorized Green4 command compiled the complete arm64 host and the
authoritative result tree reports `Passed`: two selected Swift Testing cases,
two passed, zero failed, zero skipped, and zero expected failures. The legacy
XCTest `Executed 0 tests` line is bookkeeping and does not contradict the
Swift Testing result tree. The startup log contains zero production App Group
paths and routes AppBootstrap, EventStore, and PaperclipStore beneath the
disposable PID root
`Epistemos-TestRuntime/66878/Application Support/Epistemos`. The generic XCTest
App Group fallback is therefore current evidence.

Retained Green4 evidence and disposable product identity:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-4-16gib.xcresult`;
- log: 1,274,415 bytes, SHA-256
  `9c19705df1b5d0e99bc35d0e4b6f828b3be520eccb390ceb112914a80ee38a79`;
- disposable app 476,128 KiB; 40,344-byte arm64 executable SHA-256
  `eb6cecb40f1f38230cc7f20da8ead1e22091618c2fcc68c3525fa476d82d3435`;
- staged graph archive 928,375,752 bytes, universal `x86_64 arm64`, SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

The result has zero formal errors and three retained warnings: Rust `block`
future compatibility, one unnecessary `await`, and one unused `try?` result.
Its embedded runtime output also retains twelve duplicate-column diagnostics
and one metadata `dev_t` diagnostic. Green4 is test-green but not log-clean,
and it does not close that existing verification debt.

The required post-run cleanup assertion is red. Actual hosted-app PID `66878`
left `com.epistemos.test.runtime.66878` readable, with an 898-byte preference
plist containing 18 keys, SHA-256
`82ba1b186f1e9a316bf1a4d1e1c95855effa0a03a067f2b162258743fce3b9fd`.
Its disposable PID runtime directory also remains. This proves the app
delegate's termination hook is not a reliable XCTest-runner cleanup boundary;
the passing injected helper test cannot substitute for actual-host cleanup.
No production defaults domain or owner container was read.

Post-run resources remain inside the owner lock: swap used is 13,901.25 MiB,
strictly below 16,384 MiB; free memory is 72%; pages throttled are zero;
available disk is 692,886,692 KiB; and the corrected exact-name process scan
is empty. Exact next action: retain Green4 result/log, remove only its
identified disposable app/DerivedData, graph archive, PID runtime, and PID
defaults suite; replace the unreliable app-termination cleanup assumption with
the narrow Swift Testing suite-scope cleanup boundary; re-read and diff-audit;
then require a fresh complete 16-GiB preflight before rerunning only these two
selectors under Green5 paths. Archive, launch, runtime, canon, feature, paid,
model/provider, secret, owner/private/removable-data, and later-key work remain
closed.

Green4 cleanup is now complete. The retained result and log reverify; its
DerivedData/app, staged graph archive, PID runtime directory, and logical PID
defaults domain are absent. `defaults delete` reduced the domain to an empty
42-byte plist, and the exact test-only plist was then removed directly; the
domain remains unreadable. No production preference or owner container was
touched.

The surgical harness correction is confined to
`EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift`. A private
recursive `SuiteTrait`/`TestScoping` trait wraps the existing serialized
KEELSTONE suite and defers `FoundationSafety.clearTestRuntimeDefaultsIfNeeded()`
until the selected test scope exits. This uses the local Xcode Testing
framework's current `TestScoping.provideScope` contract and transfers cleanup
ownership from an app-delegate event the runner bypasses to the test harness
that controls test completion. The production resolver, normal defaults,
explicit audit precedence, app teardown fallback, and product runtime are
unchanged. The changed region was re-read, the focused diff was inspected, and
`git diff --check` is clean. No build or test has run after this correction.

Exact next action: a complete fresh Green5 preflight, including zero stale
test-domain and product state. Only if every strict 16-GiB resource and identity
gate passes may the same two selectors run once under fresh Green5 paths. The
post-run actual PID domain must be unreadable and its plist absent before the
archive gate can reopen.

The preliminary Green5 inventory correctly blocked authorization: it found 73
old PID directories under the explicit disposable `Epistemos-TestRuntime`
namespace and one 42-byte, zero-key synthetic
`com.epistemos.test.runtime.20260714.plist`. The synthetic domain was already
unreadable; no production preference domain was queried. With an empty exact-
name competing-process scan, the disposable runtime root and test-prefix plist
were deleted. Both inventories are now zero.

That empty plist also proved that logical `removePersistentDomain` cleanup
alone can leave a filesystem shell. Before Green5, the test-only helper was
surgically strengthened to synchronize the cleared test domain and remove only
the exact PID-scoped test plist derived from the validated XCTest PID. The
selected regression now forces the injected suite to disk, proves the exact
test-only name and same-suite value, calls cleanup, and requires both the value
and physical plist to be absent. The recursive Testing scope remains the
actual-host lifecycle owner. No wildcard preference enumeration or production
domain access exists in product code, and no build/test/archive has run after
this source change. The preliminary inventory is non-authorizing; a complete
preflight must restart from identity and resources.

The complete replacement Green5 preflight now passes. A fresh fetch and
`--ff-only` pull leave branch, local HEAD, remote, handoff publication, and
supplied publication SHA exact at
`668b52cfb43721de95db102260d9f327ae24e13e`; dirty count remains 179 and both
diff checks pass. Swap used is 13,885.25 MiB, strictly below 16,384 MiB; free
memory is 73%; pages throttled are zero; available disk is 695,677,960 KiB; and
the exact-name competing-process scan is empty. Repository, `/private/tmp`, and
Xcode DerivedData App products; archives; staged graph archive; test-defaults
plists; PID test-runtime directories; temporary saved state; and all four
fresh Green5 output paths each have count zero. Both exact selectors resolve
once. This authorizes one serial Green5 run of only those two selectors with no
process audit tuple. It authorizes no archive, launch, runtime matrix, canon,
feature, paid, model/provider, secret, owner/private/removable-data, or later
execution key.

### Runtime-audit isolation Green5 is red: recursive trait shape crashed the runner

Green5 compiled the full app and test target but exited 65 before either
selected test body ran. The authoritative result is `Failed`: one system-
failure node, zero passed tests, zero skipped tests, and the exact failure
`Early unexpected exit ... test runner crashed while preparing to run tests`.
This is red evidence and does not prove cleanup.

The current system crash report
`~/Library/Logs/DiagnosticReports/Epistemos-2026-07-14-051135.ips` is 42,399
bytes, SHA-256
`399924480c0ddb2ecf232991e69230645c380eb132971f013e02abfbb1caadab`.
It records PID `72121`, `EXC_BREAKPOINT`/`SIGTRAP`, and a triggered cooperative
thread in `Testing.Runner.Plan._recursivelyApplyTraits`. The faulting registers
name both `RuntimeDefaultsCleanupTrait` metadata and the `TestTrait` protocol
descriptor. The custom recursive trait conformed to `SuiteTrait` and
`TestScoping` but not `TestTrait`; the local Xcode 26.6 Testing interface's
recursive scoped built-ins (`IssueHandlingTrait` and `ParallelizationTrait`)
conform to both `TestTrait` and `SuiteTrait`. This directly implicates the
incomplete recursive trait shape, not defaults-plist deletion: the tests never
entered `provideScope` or either selected body.

Retained Green5 evidence and disposable identities:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-5-16gib.xcresult`,
  568 KiB;
- log: 1,273,505 bytes, SHA-256
  `88fb249fe24eac2badd93665b3e86ae841d14ad27f012230bbb88e2a759a07fe`;
- disposable app 476,144 KiB; 40,344-byte arm64 executable SHA-256
  `65ddabae6431f0efc753c1aeefacf0f6dfccfbfffa70aa07d5ccf64f8b7b001a`;
- staged graph archive 928,375,752 bytes, universal `x86_64 arm64`, SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

The log again contains zero production App Group paths and actual PID startup
under disposable `Epistemos-TestRuntime/72121`. Because execution never reached
the trait, the actual PID domain remains readable with an 898-byte, 18-key
plist, SHA-256
`65d69d35cd130cf75c6154236ef2e72bbccac443f7bbb558eb8ea04adc98acdb`;
the PID runtime remains. No owner domain contents were read. Post-run swap is
14,249.19 MiB, below the 16,384-MiB ceiling; free memory is 72%; throttled pages
are zero; disk is 691,071,532 KiB; and no competing process remains.

Exact next action: retain the result/log/crash identity; delete only the
Green5 disposable DerivedData/app, staged graph archive, PID runtime/defaults,
temporary saved state, and diagnostic export; add only the missing `TestTrait`
conformance to the recursive scoped test trait so it matches the current
Testing contract; re-read/diff-audit; then require a new full 16-GiB preflight
before the same two selectors may run as Green6. Archive, launch, runtime,
canon, feature, paid, model/provider, secret, owner/private/removable-data, and
later-key work remain closed.

Green5 cleanup is complete: retained result/log and system crash report
reverify, while its DerivedData/app, graph archive, PID runtime, PID defaults
domain/plist, temporary saved state, and diagnostic export are absent. The
correction is exactly one protocol conformance: the private recursive cleanup
trait now conforms to `TestTrait`, `SuiteTrait`, and `TestScoping`, matching the
current local Testing framework's recursive scoped trait shape. The changed
line and surrounding scope were re-read; the framework interface was
rechecked; staged/unstaged diff checks pass. No command has run after this
correction. Exact next action is a complete fresh Green6 identity, stale-state,
selector, resource, and process preflight before the same two selectors may run
once.

The complete Green6 preflight passes. Fresh fetch/pull and branch/local/remote/
handoff/supplied identity remain exact at `668b52cf...`; dirty count is 179 and
both diff checks pass. Swap used is 14,249.19 MiB, strictly below 16,384 MiB;
free memory is 72%; pages throttled are zero; disk is 693,823,400 KiB; and the
competing-process count is zero. Repository, `/private/tmp`, and Xcode
DerivedData app inventories; archive inventory; staged graph archive; test
plist and PID-runtime inventories; saved state; and every fresh Green6 path are
zero. Both selectors resolve once. Exactly one serial Green6 run of those two
selectors is authorized; every archive/runtime/canon/feature/private/paid/
model/secret/later-key lane remains closed.

### Runtime-audit isolation Green6 tests pass; post-exit empty plist remains red

Green6 compiled the full arm64 host and its authoritative result is `Passed`:
two selected Swift Testing cases, two passed, zero failed, zero skipped, and
zero expected failures. The isolation-rejection node took 0.009970903 seconds;
the defaults/App Group node took 0.019104004 seconds; the two-test suite passed
after 0.029 seconds. The test operation took 4.134 seconds and the full action
took 119.680 seconds.

Retained Green6 evidence and disposable product identity:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-6-16gib.xcresult`;
- log: 1,274,428 bytes, SHA-256
  `35b57730eedaeddd8f401a0ba28032d8c99ef4cafde1f3e69d30182582b4beeb`;
- disposable 40,344-byte arm64 executable, SHA-256
  `d782dee2ba9b2ee53ce26e83bbe44f1517fc03b546cce86691ad2df6e519d9b1`;
- staged graph archive 928,375,752 bytes, universal `x86_64 arm64`, SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

The log and entire result bundle contain zero production App Group identifiers.
Hosted PID `76429` started only beneath the disposable
`Epistemos-TestRuntime/76429/Application Support/Epistemos` root. It records
June disabled, local GGUF runtime disabled, cloud models off, and vault restore
skipped. The result has zero formal errors and three formal warnings: Rust
`block` future compatibility, one unused `try?`, and one unnecessary `await`.
Runtime output retains twelve duplicate-column diagnostics and one metadata
`dev_t` diagnostic.

The independent post-exit check is still red. The actual PID domain is
unreadable and contains no keys, and its PID runtime directory is absent, but a
valid 42-byte zero-key plist appeared at
`~/Library/Preferences/com.epistemos.test.runtime.76429.plist` at
2026-07-14T05:21:14-0500, four seconds after the selected suite passed. Its
SHA-256 is
`9261ecceda608ef174256e5fdc774c1e6e3dcf533409c1bc393d490d01c713f1`.
A separate unique nonexistent-domain probe confirmed that `defaults read`
does not itself create such a plist. This is test-only residue and contains no
owner data, but it disproves complete physical disposal after the test scope.

Post-run resources remain within the owner lock: swap used is 14,233.19 MiB,
strictly below 16,384 MiB; free memory is 74%; pages throttled are zero; and
available disk is 690,721,104 KiB. The initial broad process string scan
matched only the Codex host because its working directory contains
`Epistemos`; no Xcode build was active. A corrected exact-executable scan is
required before any later command.

Exact next action: retain Green6 result/log, delete only the recorded disposable
DerivedData/app, staged graph archive, exact PID test plist, and any remaining
test-only state; add the smallest process-exit cleanup boundary so physical
cleanup occurs after the runner's final preferences flush; re-read and
diff-audit; then require a complete fresh Green7 16-GiB preflight before the
same two selectors may run once. The Release archive, launch, runtime matrix,
canon, feature, private/paid, provider/model/secret, and later-key lanes remain
closed.

Green6 disposable cleanup is complete. Its retained result/log still exist,
while the recorded DerivedData/app, staged graph archive, PID `76429` runtime,
exact test plist/domain, and temporary saved state are absent.

The bounded correction adds a normal-exit cleanup registration only when the
generic XCTest resolver selects `com.epistemos.test.runtime.<pid>`. Registration
occurs before the suite object is created; the callback invokes the existing
validated exact-PID cleanup helper after the runner has completed later app
teardown. The explicit runtime-audit branch is unchanged and deliberately does
not register this cleanup because the finite runtime matrix needs its named
suite to survive process 1 for process 2 restore proof. Normal production
launches still use standard defaults and invalid audit requests still fail
closed.

The selected test's source guard now requires the `Darwin.atexit` callback and
the resolver registration. Apple's current Foundation documentation describes
`UserDefaults` suites as persistent stores, while the Darwin manual defines
`atexit` for normal process exit. This is not a SIGKILL/crash-cleanup claim.
Both changed regions were re-read, focused semantic searches pass, and
`git diff --check` is clean. No Epistemos build/test/archive/launch has run
after this correction. Exact next action is independent read-only review,
followed by a complete fresh Green7 identity, stale-product, selector,
resource, and exact-process preflight. Only the same two selectors may run if
that preflight passes; the Release archive gate is still closed.

The first Green7 preflight is non-authorizing and red on stale state. Branch,
local HEAD, fetched origin, handoff publication, and supplied publication SHA
remain exact at `668b52cf...`; dirty count is 179; both selectors resolve once;
`git diff --check` passes; and app, archive, staged graph, PID runtime,
saved-state, competing-process, and fresh Green7 path inventories are zero.
Swap used is 15,360.00 MiB, strictly below the 16,384-MiB ceiling; free memory
is 75%; throttled pages are zero; and disk is 693,464,856 KiB.

The blocker is one valid 42-byte, zero-key plist named
`com.epistemos.test.runtime.20260714.plist`, SHA-256
`9261ecceda608ef174256e5fdc774c1e6e3dcf533409c1bc393d490d01c713f1`,
created at the Green6 timestamp. It is the selected regression's fixed
synthetic PID suite, not the actual host suite. No preference values or owner
domain were read, and no Green7 test/build started. Exact next action is to
delete only this known test suite, replace the regression's fixed PID with the
actual current process PID so final-process cleanup owns the sole persistent
XCTest suite, strengthen the guard, re-read/diff-audit, and restart every
Green7 preflight check from the beginning.

The complete replacement Green7 preflight passed after deleting only the
synthetic test suite and changing the regression to the actual current PID.
Identity remained exact at `668b52cf...`, dirty count 179, swap 15,360.00 MiB,
free memory 75%, throttled pages zero, disk 693,462,176 KiB, competing process
count zero, and all app/archive/graph/test-plist/PID-runtime/saved-state/fresh-
path inventories zero. Both selectors resolved once and the diff check passed.

### Runtime-audit isolation Green7 is red: callback inherited MainActor

The authorized serial command stopped during `EmitSwiftModule`; no selected
test and no app runtime began. The authoritative test summary is `unknown`
with zero total, passed, failed, or skipped tests. Build results are `failed`
with three errors: test cancellation plus two compiler diagnostics at
`Epistemos/Engine/Extensions.swift:28:29`:

- a C function pointer can only be formed from a function reference or literal
  closure;
- converting `@MainActor @Sendable () -> ()` to
  `@convention(c) () -> Void` loses `MainActor`.

The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. The callback was
top-level but lacked the explicit `nonisolated` modifier already used by other
global helpers in this source tree. This is a compile-shape failure, not a
defaults-cleanup runtime result.

Retained evidence and disposable identities:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-7-16gib.xcresult`,
  472 KiB;
- log: 1,129,057 bytes, SHA-256
  `c4d2fd79104837e18d0d396fe52963d628fb32be82dd4899cfbddcea75d760d0`;
- partial app: 197,176 KiB and 115 files, no executable; 4,644-byte
  `Info.plist` SHA-256
  `63726dbd34a26bb26fa849b7f3b3a6b156a6308eb46773c384bf1f110ca2dedb`;
- staged graph archive: 928,375,752 bytes, universal `x86_64 arm64`, SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

The result retains only the existing Rust future-compatibility warning. Test
plist, PID runtime, and saved-state inventories remain zero because the test
host never launched. Post-run swap is 14,225.19 MiB, below 16,384 MiB; free
memory is 65%; throttled pages are zero; disk is 691,404,364 KiB; and no
competing process remains.

Exact next action: retain Green7 result/log, delete its disposable partial app/
DerivedData and staged graph, add only `nonisolated` to the top-level callback,
re-read/diff-audit, and run no command until a complete fresh Green8 16-GiB
preflight passes. Green8 may run only the same two selectors; every archive,
launch, runtime, canon, feature, private/paid, provider/model/secret, and later-
key lane remains closed.

Green7 disposable cleanup is complete: retained result/log remain, while its
partial DerivedData/app, staged graph, test state, and saved state are absent.
The compiler-proven correction changes only the callback declaration from
`private func` to `private nonisolated func`, matching existing top-level
helpers under this project's default `MainActor` isolation. The selected guard
requires that exact declaration. Registration order, actual-XCTest checks,
retained defaults handle, exact PID cleanup, explicit-audit persistence, and
production defaults remain unchanged. The changed lines were re-read and
`git diff --check` passes. No build/test/archive/launch has run after this
correction. A complete fresh Green8 16-GiB preflight is required before the
same two selectors may run once.

The complete Green8 preflight passed. Branch/local/origin/handoff/supplied
identity remained exact at `668b52cf...`; dirty count was 179; swap was
15,360.00 MiB, free memory 69%, throttled pages zero, disk 693,444,484 KiB,
competing process count zero, all stale and fresh product/test-state counts
zero, both selectors resolved once, and `git diff --check` passed.

### Runtime-audit isolation Green8 is red only on forced plist materialization

Green8 compiled and launched the hosted app. The authoritative result is
`Failed`: two total tests, one passed, one failed, zero skipped or expected
failures. The isolation-rejection test passed. The same-suite test failed at
line 721 because it required the real PID suite plist to exist immediately
after a sentinel set plus `synchronize()`. The later second-handle value check
was not reached, but Green6 already proved same-suite handles; Green8 does not
supersede that evidence.

Retained evidence and disposable identity:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-8-16gib.xcresult`,
  560 KiB;
- log: 1,274,919 bytes, SHA-256
  `10bac63349443e2654911dd65b150c9a6adb848be21a112b2595902754c77645`;
- disposable app 476,168 KiB; 40,344-byte arm64 executable SHA-256
  `59991b20e880c71aa75d70b619f173d3e3e6e88f65d6a7d0ec76bc942c2a4fa0`;
- staged graph archive 928,375,752 bytes, universal `x86_64 arm64`, SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

The log contains zero production App Group identifiers and starts only beneath
`Epistemos-TestRuntime/87086`. It retains three formal warnings, twelve
duplicate-column diagnostics, and one metadata `dev_t` diagnostic. Post-run
swap is 14,582.88 MiB, below 16,384 MiB; free memory is 70%; throttled pages
are zero; disk is 690,672,564 KiB; and competing process count is zero.

After host exit and a 40-second settle interval, the exact PID defaults domain
was unreadable, the PID runtime was absent, and no ByHost plist existed. The
preferences daemon nevertheless wrote a valid 42-byte, zero-key main plist at
05:54:14. This contains no owner data. It proves that a normal-exit callback
can clear the logical domain but cannot promise absence of the system-managed
file after the external daemon's later flush. Apple's UserDefaults contract is
domain/value persistence, not synchronous physical-file creation or deletion.

The honest release-evidence split is now: the hosted process must leave its
test domain empty/unreadable with zero production-domain contact; after the
preferences settle window, the controlling evidence process removes only the
exact known test PID shell and verifies it absent before another build. Exact
next action: retain Green8 result/log, delete its disposable app/DerivedData,
staged graph, exact empty PID plist, and any test-only state; remove only the
invalid pre-cleanup `fileExists` assertion; re-read/diff-audit; then require a
complete fresh Green9 16-GiB preflight before the same two selectors may run.
Archive, launch, runtime, canon, feature, private/paid, provider/model/secret,
and later-key work remain closed.

Green8 cleanup is complete: retained result/log remain, while its disposable
app/DerivedData, staged graph, PID runtime, exact main/ByHost test plists,
logical domain, and saved state are absent. The correction removes only the
invalid demand that Foundation materialize the real PID plist before cleanup.
The test still proves nonstandard identity, startup reset, two-handle replay,
explicit value cleanup, and final in-process absence; the external evidence
leg still owns settle-window inspection and exact test-shell removal. The
changed region was re-read and `git diff --check` passes. No build/test/archive/
launch has run after the correction. A complete fresh Green9 16-GiB preflight
is required before the same two selectors may run once.

The complete Green9 preflight passed. Branch, local HEAD, fetched origin,
handoff publication, and supplied publication SHA were exact at
`668b52cf...`; dirty count was 179; swap was 15,360.00 MiB; free memory 71%;
throttled pages zero; disk 693,422,468 KiB; competing process count zero; every
stale app/archive/graph/test-plist/PID-runtime/saved-state inventory and fresh
Green9 path was zero; both selectors resolved once; and `git diff --check`
passed.

### Runtime-audit isolation Green9 passes 2/2 with external shell hygiene

The authoritative result is `Passed`: two total tests, two passed, zero failed,
zero skipped, and zero expected failures. The build result succeeded with zero
errors and three retained warnings. The selected Swift Testing suite passed
after 0.028 seconds. The legacy `Executed 0 tests` line remains XCTest
bookkeeping and does not contradict the authoritative Swift Testing result.

Retained evidence and disposable identity:

- result:
  `build/xcode-results/2026-07-14-runtime-audit-isolation-green-9-16gib.xcresult`,
  560 KiB;
- log: 1,274,429 bytes, SHA-256
  `170f5f0f31198256e4044171eb7ded55d517892b7456eceb475102af45f1113d`;
- disposable app 476,168 KiB; 40,344-byte arm64 executable SHA-256
  `6d7cb131096fd46ea934f30e4444ae1dbaa0a5e0056949e7f7513c2bd6b38694`;
- staged graph archive 928,375,752 bytes, universal `x86_64 arm64`, SHA-256
  `3d22db42aacdc2d434b6e3312fe481823d37298665f386e12b67faf86d4ef4c1`.

The log and full result bundle contain zero production App Group identifiers.
Hosted PID `89953` used only
`Epistemos-TestRuntime/89953/Application Support/Epistemos`; the log records
June disabled, local GGUF disabled, cloud models off, and test vault restore
skipped. It retains three formal warnings (Rust future compatibility, unused
`try?`, unnecessary `await`), twelve duplicate-column diagnostics, and one
metadata `dev_t` diagnostic.

After the observed settle window, `com.epistemos.test.runtime.89953` was
unreadable and zero-key, ByHost count was zero, and the PID runtime was absent.
The external preferences daemon created the known 42-byte zero-key main shell
at 06:02:14, SHA-256
`9261ecceda608ef174256e5fdc774c1e6e3dcf533409c1bc393d490d01c713f1`.
No owner preference value or production domain was read. This shell is exact
test-artifact hygiene and must be deleted by the controlling evidence process
before another build.

Post-run swap is 14,574.88 MiB, below 16,384 MiB; free memory is 68%; pages
throttled are zero; disk is 690,678,604 KiB; and no competing process remains.
Exact next action: retain Green9 result/log, delete its disposable app/
DerivedData, graph archive, exact PID defaults shell/domain, PID runtime, and
saved state; verify every disposable count is zero; then inspect the current
recorded Release archive command and artifact gates before a fresh 16-GiB
archive preflight. The archive, launch, and runtime matrix remain closed until
their own gates pass.

### Replacement Release archive and artifact gates pass after runtime isolation

The first archive preflight stopped without building because a broad temporary-
state inventory found three isolated XCTest runtime directories from Green6,
Green8, and Green9: PIDs `76429`, `87086`, and `89953`, thirty files, 1,716 KiB
total. No matching process existed. These named test-only directories were
removed exactly; no owner vault, production preference, saved state, App Group,
private/removable material, or retained result/log was opened or deleted. The
complete preflight was then repeated from the beginning and passed.

Fresh fetch/pull and identity checks remained exact at
`668b52cfb43721de95db102260d9f327ae24e13e` for the branch, local HEAD,
`origin/feat/goose-surface`, and handoff publication. Dirty count remained 179
and both diff checks passed. The authorizing preflight recorded 14,566.88 MiB
swap used, 73% free memory, zero throttled pages, 693,442,168 KiB available
disk, zero competing process, and zero app, archive, graph, test-plist,
PID-runtime, saved-state, or fresh-path conflict. Paid/model/audit launch
environment variables were absent.

Exactly one serial unsigned local-evidence archive completed at:

- archive:
  `build/archives/Epistemos-FreeV1-runtime-isolation-current-2026-07-14.xcarchive`;
- result:
  `build/xcode-results/2026-07-14-keelstone-runtime-isolation-release-archive-16gib.xcresult`;
- console log:
  `build/xcode-results/2026-07-14-keelstone-runtime-isolation-release-archive-16gib.log`.

The wrapper performed one package-resolution invocation and one archive
invocation. The console contains exactly one `ARCHIVE SUCCEEDED` marker and no
failure marker. Direct result inspection reports `succeeded`, zero errors, and
thirteen warnings: Rust `block` future compatibility, one unnecessary `await`,
one unused `try?`, and ten explicit-`Selector` warnings. Warning-free and
release-ready claims remain prohibited.

Unsigned identity before evidence signing was bundle `com.epistemos.appstore`,
version 1.0.0 build 1, universal `x86_64 arm64`, with a 116,979,176-byte
executable SHA-256
`8904acefbe253e07c120c202eb501f9f4edcf7048fd112d7e94efeb47e268d45`.
The exact build-created graph archive was 312,039,112 bytes, universal
`x86_64 arm64`, SHA-256
`b3daf69e1d1f220278a2e99921e488465178ca9bdcdedbed2ce5814a3160c58e`,
with zero universal/arm64/x86_64 `_sqlite3_*` exports and zero `sqlite3_`
string names. Disposable DerivedData, the staged graph archive, and the two
temporary thin graph slices were deleted after receipt capture. Exactly one app
then remained inside exactly one archive.

The archive app was signed inside-out with a local ad-hoc evidence signature
and the App Store entitlements. Strict deep app and per-dylib verification
passes. Effective entitlements match the six-key source plist exactly: App
Sandbox, `group.com.epistemos.shared`, audio input, app-scope bookmarks,
user-selected read/write, and network client. `TeamIdentifier` is not set;
CDHash is `493877f23700cc0a8d5803cacf8cdda85dc3c160`. This is not Apple
distribution signing, App Store validation, or submission evidence.

Post-sign identity is:

- executable: 117,156,448 bytes, SHA-256
  `468c76dc6fa2e0982af8bed768ce2ea17eecee50d25314003b16fbfca231bda7`;
- deterministic sorted file-list app-tree SHA-256
  `adaded48d7b114d0ea50cd734b4287b222536b0a75ac8968e141d8e942d16608`;
- app 154,292 KiB; archive 432,928 KiB;
- archive `Info.plist` SHA-256
  `0583481459bbf1613cc3af5ac08f24dc05a1ad1b6665672a884ce4da12d23236`;
- main privacy manifest SHA-256
  `e1c392f10f990c037d16b804d066770599e1a29e78b6ffd512646a168705c406`,
  byte-identical to source.

The integrated KEELSTONE gate, standalone scanner, and independent direct
audit all pass against that exact signed app. Both architecture compile actions
contain `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`, and `EPISTEMOS_FREE_V1`.
The expected main and nested GRDB privacy manifests are present. JuneWeb,
model manifest, DefaultSkills, llama, agent_core, omega_mcp, their linkage,
test bundles/frameworks, quarantine, and all seven scanner finding classes are
absent. Executable inventory is exactly the app plus
`libepistemos_core.dylib` and `libepistemos_shadow.dylib`.

Retained log SHA-256 values are archive
`45fd555b2734a23fd4ae5864efd5ad536bdf96c96e6715b293522a9430e8d344`,
sign/verify
`24b09ba34c9a3adb826c6619a3792681c05e2d8c36c0d5220182bdfdc5c03bf8`,
integrated gate
`5be0cb40a3f43ed0e486f0d07925117b807fe9eb12c850bea56ca8efd2875b72`,
and standalone scan
`0a65dc47502da58c29c20e74b422d8c1b2af58e4a0dc915266154ed05e7184a0`.
Two read-only audit scripts stopped on their own shell assumptions (`codesign`
XML requires the deprecated colon form on this host, and zsh's `path` name
overwrites `PATH`); corrected complete audits passed. Neither altered archive
bytes.

Post-gate branch/remote/handoff identity is still exact, dirty count is 179,
and both diff checks pass. Resources are 15,068.06 MiB swap used, 73% free
memory, zero throttled pages, and 692,166,980 KiB available disk; no competing
process exists. Artifact gates are green. Exact next action is a wholly fresh
16-GiB resource/process/immutable-product/disposable-path preflight, then only
the already-recorded eight-item finite Free V1 runtime matrix against this
archive using all three audit-isolation variables, one stable audit defaults
suite, correlated logs, and a disposable vault. Do not launch if any preflight
or byte-identity check is red. Do not access owner/private/removable data,
paid/provider/secret routes, or begin canon/features/another execution key.

## Finite Free V1 Runtime Matrix Closeout — 2026-07-14

This section is the latest KEELSTONE verdict and supersedes the earlier
runtime-pending checkpoints above.

### Owner lock, exact subject, and isolation boundary

- Canonical execution key remained
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.
- The durable resource lock remained swap used strictly below 16,384 MiB,
  free memory at least 25%, pages throttled zero, and no competing
  Xcode/compiler/model/Epistemos process before each leg.
- Branch, local `HEAD`, fetched `origin/feat/goose-surface`, and the handoff
  publication remained exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`; dirty count was 179.
- The only runtime subject was
  `build/archives/Epistemos-FreeV1-runtime-isolation-current-2026-07-14.xcarchive`.
  Its post-sign executable SHA-256 was
  `468c76dc6fa2e0982af8bed768ce2ea17eecee50d25314003b16fbfca231bda7`,
  deterministic app-tree SHA-256 was
  `adaded48d7b114d0ea50cd734b4287b222536b0a75ac8968e141d8e942d16608`,
  and archive `Info.plist` SHA-256 was
  `0583481459bbf1613cc3af5ac08f24dc05a1ad1b6665672a884ce4da12d23236`.
  Strict deep ad-hoc evidence signing remained valid. This is not Apple
  distribution signing.
- The first attempted external Application Support root under `/private/tmp`
  failed closed at the sandbox boundary before owner data access. The
  continued legs used only the validated three-part audit isolation tuple,
  stable audit defaults suite
  `com.epistemos.audit.runtime.keelstone.freev1.20260714`, corrected writable
  container-owned temporary roots, and disposable vault
  `/private/tmp/Epistemos-KeelstoneFreeV1RuntimeMatrix-20260714/Vault`.
- No owner vault, production preference value, Keychain secret, account,
  payment, private Columbia/VA/funding material, or removable drive was read.
  No source correction, test, build, archive, or replacement product was made
  during this finite runtime matrix.

### Retained exact evidence

The retained root is:

`build/runtime-evidence/2026-07-14-keelstone-free-v1-runtime-isolation`

It contains 21 named screenshots covering onboarding, Free V1 home/settings,
command palette, Epdoc/Source/Preview fidelity, quit/relaunch, Meeting,
Quick Capture, HTML Workspace, graph routing, and Unicode search. Important
red receipts include:

- `06-settings-general-free-v1-contradictions.png`, SHA-256
  `a4da32af6ced5c1d3b47c82c2e94d4fa60273b0579a9d108d4a310674726d90a`;
- `08-new-epdoc-after-40s-open.png`, SHA-256
  `d9591603f3f6b2cf1d7067103a75e73b492a482e407595e9740ec727004c122a`;
- `09-source-markdown-fidelity-failure.png`, SHA-256
  `cc7a2fab0dc41f795b7f6c9d88dfb99e3ab62697b5547a26fa525dd0b46a590a`;
- `11-fidelity-fixture-source-nonverbatim.png`, SHA-256
  `7dd1d59b39c66e85a54108dc58e92f5086d00b2b4c7ba4a49f1ebf63821aa492`;
- `13-quit-dialog-corrupted-heading.png`, SHA-256
  `0bd81ac74f5839a33a14ddff0356c04215493dee61916ef669ddac623dc11b1e`;
- `18-graph-nested-vault-path.jpeg`, SHA-256
  `87a14ac68d13acce56971488ce21353c51b7cf595d4ad51a7e9cff14262db84d`.

Correlated structured logs are:

- process 1: 9,318,297 bytes, SHA-256
  `f639c77a4da4b7bfd1d67978ccbb88b769655b149ec0887ff1158f9b7cde481f`;
- process 2: 675,539,650 bytes, SHA-256
  `b9fbbea119bc6f6ed017f21f4c76ddb27114c099eb2cd5cfb053d58096a5e7ec`;
- process 3: 75,698,421 bytes, SHA-256
  `3fe64714145a1ac5c88ef1dc7eee9511fd01de3b5105a33d28dc7323c6bba602`;
- process 4: 179,940,859 bytes, SHA-256
  `959aca7dcf58f9c0d7ebe352622213a464c9a0127ac83ec9a10a7972b0563765`.

The disposable vault retained a 321-byte fidelity fixture, SHA-256
`9e95e69c8d5a1c312da73d4b7e013d1e8f1d92de54e99541849569a670864b1d`,
and a 139-byte Quick Capture note, SHA-256
`8b141dd0ace0bceb4410f99daff296d414db4dd6ce4d1960eb5c5a3adecf7674`.
The incorrect nested second-save artifact is also retained as proof:
294 bytes, SHA-256
`0b9217577bb472960fc7355a5f0346800a6312bc4107133c9035ef5c34700ce5`.

### Eight-item finite runtime result

| Leg | Result | Current exact evidence |
| --- | --- | --- |
| 1. Normal Free V1 identity | **PASS** | Onboarding explicitly presented “Free V1 Foundation”; Kokoro was truthfully not installed. |
| 2. Paid/AI/Browser/ResearchHub absence | **FAIL** | June, local GGUF, and cloud models logged disabled/off and no provider request occurred, but Home exposed Companions; Settings exposed agent/chat/provenance concepts; Writing Tools/Clip Web Page/Ideas remained visible; Apple NaturalLanguage loaded `NLContextualEmbedding` model `mul_Latn` and Epistemos pushed 512-dimensional embeddings to Rust. This violates the literal no-AI/no-model Free V1 boundary. |
| 3. Disposable vault select/save/relaunch/save | **PARTIAL / FAIL** | Selection, save, graceful quit/relaunch, two-note then three-note restoration, and second-save activity were observed. Raw `/tmp` versus `/private/tmp` string handling produced an absolute-derived nested path inside the vault and later containment/save failures. |
| 4. Epdoc rich-Markdown fidelity across lenses | **FAIL** | Epdoc and Preview rendered the fixture, but Source was not verbatim Markdown: apparent frontmatter/identity was injected, tags were dropped, markup was transformed, the disk file remained unchanged, and clean reactivation diverged from host Markdown. |
| 5. Meeting/Capture/planner/Sync/calendar/PDF/export | **FAIL** | Meeting ready-state, Quick Capture extraction, Sync status, PDF-only chooser entry, HTML live preview, and export menu entry points were visible. Calendar permission/entry was absent from source/archive contracts. No audio operation was intentionally started, yet AVAudioEngine was eagerly configured and microphone permission was queried thousands of times. |
| 6. Graph/search routing | **PARTIAL** | Graph and Unicode full-text search were responsive and opened a real editor. Graph exposed the malformed nested vault path; graph lens controls did not reliably switch; a graph-originated write was not proved. |
| 7. English Kokoro preview/read-aloud | **FAIL / UNPROVEN** | The product truthfully reported Kokoro not installed; no Kokoro asset, synthesis, or audio-start evidence exists. No package download/install was authorized. |
| 8. Correlated negative logs and health | **FAIL** | No June/cloud-provider/Browser/ResearchHub/Kokoro/HTTP endpoint activity was found, but Apple NaturalLanguage embeddings did run, app-owned save/index/containment/Epdoc errors occurred, and the log/performance volume is itself red. |

### Correlated log and performance findings

- The four structured logs total about 922 MiB and 698,569 events. Preference
  traffic alone accounts for 297,562 process-2 events, 38,915 process-3
  events, and 90,183 process-4 events. This is excessive diagnostic volume
  and obscures actionable runtime evidence.
- App-owned error counts were process 1 = 28, process 2 = 9, process 3 = 5,
  and process 4 = 13. Process 1 is the intentionally invalid external-root
  sandbox leg. Later direct product failures include repeated Eidos index-open
  failures, duplicated-path containment errors, six failed file-first saves,
  a Shadow FFI error, and three Epdoc host-Markdown divergence reports.
- Process 4 loaded Apple NaturalLanguage's `mul_Latn` contextual embedding
  model and Epistemos logged three pushes of six 512-dimensional embeddings
  into Rust. This is actual on-device model/runtime activity, not a preference
  read, and is incompatible with the owner's literal no-AI Free V1 lock.
- No microphone capture or running audio engine was proved. Nevertheless, the
  app eagerly connected AVAudioEngine nodes at launch and synchronously queried
  microphone access 3,858 times in process 2, 180 times in process 3, and 804
  times in process 4. This is a privacy/performance-quality failure.
- A new blank Epdoc required about 40 seconds to become interactive. Settings
  inspection twice left the app process alive while the accessibility
  inspection path hung; process 3 and process 4 required controlled SIGTERM.
  Retained logs also contain negative view geometry, SwiftUI lifecycle, WebKit
  process/sandbox, and SQLite migration diagnostics. No broad crash-free claim
  is authorized.
- The product's own empty diagnostics summary does not reconcile these
  correlated OS and app-owned failures and cannot be used as health proof.

### Final KEELSTONE verdict

**INCOMPLETE — RUNTIME MATRIX RED — NOT RELEASE READY**

Artifact gates remain green for the immutable archive, but the owner-visible
runtime done bar failed. Free V1 is not yet an honestly no-AI/no-model surface;
vault containment/save behavior is not safe; Source is not verbatim; calendar
is absent; Kokoro runtime is unproved; and performance, microphone polling,
indexing, save, geometry, and diagnostic-volume failures remain.

All launched Epistemos and correlated-log processes were stopped. The final
closeout recheck recorded 13,625.31 MiB swap used, 70% free memory, zero
throttled pages, 690,706,668 KiB available disk, and zero competing exact-name
processes. Branch/local/origin/handoff identity remained exact, dirty count
was 179, both diff checks passed, and exactly one immutable archive remained
with no DerivedData or temporary app. Strict deep signature verification
passed again and the executable and archive `Info.plist` hashes remained exact.

The mandated stop boundary is now reached. Do not begin the MAS canon, another
feature, another canonical execution key, or another build from this
checkpoint. If the owner explicitly resumes this same KEELSTONE key, the first
test-first surgical repair is the compiled and visible Free V1 boundary:
remove Companions/stale agent surfaces and all embedding-model execution from
the Free build, then eliminate eager audio setup and microphone polling. The
next repair is centralized canonical/symlink-resolved vault-relative path
containment for `/tmp` and `/private/tmp` aliases. Source/Preview must then be
restored to the already-canonical near-verbatim MarkEdit contract without
enabling MarkEdit's unrestricted native file/service/clipboard bridge. Delete
the sole archive only immediately before a later authorized build, as required
by the one-current-build lock.

## Same-Key Repair Continuation — Free V1 Apple Embedding Boundary — 2026-07-14

This continuation remains under canonical execution key
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. The owner explicitly
authorized resuming from the red runtime closeout and continuing the recorded
repairs before any MAS-canon feature work. It does not begin a new execution
key, MarkEdit replacement, LumenLens, Reckoner, Sync, or other feature phase.

Branch, local `HEAD`, fetched `origin/feat/goose-surface`, and handoff
publication were re-grounded at
`668b52cfb43721de95db102260d9f327ae24e13e`. The prior sole archive was removed
immediately before the first new test/build under the one-current-build lock.
There is currently no archive. The only current app product is the disposable
selected-test product at
`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.
It is not a release artifact and has not been used for a manual runtime claim.

### Expected red and bounded correction

The new selected test
`FreeV1ProductCapabilityPolicyTests.graphDefaultsDoNotResolveAppleEmbeddingModels()`
asserts that the Free V1 graph reports semantic clustering unavailable and that
both the direct `EmbeddingService` default and the `GraphState` default expose
zero-dimensional no-model lookups returning no token or text vector.

The first command stopped before compilation because unsigned local evidence
flags were not supplied and no development provisioning profile exists. Its
result is `unknown`, with zero tests executed; this is a command/signing stop,
not red product behavior. Retained paths are:

- result:
  `build/xcode-results/2026-07-14-free-v1-no-embedding-signing-stop-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-no-embedding-signing-stop-16gib.log`,
  SHA-256
  `a7c2a66c9bfda3221553eb72f6a5df1393ac5af1345199ba450b6a3f302b8a09`.

The corrected unsigned local-evidence command compiled and ran exactly that
one test. It failed as expected with one failed test and three issues: the two
defaults exposed dimensions 300 and 512, and the contextual default returned a
real 512-dimensional vector. Retained paths are:

- result:
  `build/xcode-results/2026-07-14-free-v1-no-embedding-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-no-embedding-red-16gib.log`,
  SHA-256
  `6db1d0ba033a743a62cf47677cc05911cb296acf55531f1dfa46c5c8af5b9172`.

The surgical correction conditionally excludes the Apple embedding types and
`NaturalLanguage` import from `EPISTEMOS_FREE_V1`, supplies an explicit
zero-dimensional `NoModelTextEmbeddingLookup`, routes the product default
through an edition-aware factory, marks Swift semantic clustering unavailable
in Free V1, and returns before graph embedding/vector/cluster work can begin.
Paid-build Apple behavior remains present behind the compile condition. No
Rust graph containment, paid runtime route, provider, model bytes, settings
surface, or unrelated graph behavior was changed by this leg.

### Green proof and artifact scan

An initial post-correction run passed 1/1. A subsequent no-task/logging
refinement exposed a missing explicit `return` at compile time; that intermediate
run executed zero tests and is retained rather than hidden. After the one-line
compile correction, Green3 passed 1/1. Its surrounding zsh wrapper then used the
reserved variable name `status` after Xcode had completed; direct result-bundle
inspection, not the wrapper exit, proves Green3 passed. A runtime-code string
scan then found one stale Free diagnostic string, `NLEmbedding unavailable`,
without any embedding API symbol. That diagnostic was compile-gated out of Free
V1 and the exact selected test was rebuilt once more.

The final accepted selected-test proof is Green4:

- result:
  `build/xcode-results/2026-07-14-free-v1-no-embedding-green4-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-no-embedding-green4-16gib.log`,
  SHA-256
  `455e7a01746a7a151aeb41342264282635732db1f1e7a99e64c09b6a00b2c378`;
- direct `xcresulttool` summary: result `Passed`, one passed, zero failed,
  zero skipped, total one;
- Xcode terminal marker: `TEST SUCCEEDED`.

The Free test product's launcher executable is SHA-256
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`.
The actual Debug runtime code library is SHA-256
`255f2f4a219e78fa72c5f8e06f5b7185f8f6fb49d5964bce88b853c3077e3c75`.
Both `strings` and undefined/global-symbol scans over both runtime code files
returned zero matches for `NLContextualEmbedding`, `NLEmbedding`,
`AppleWordEmbeddingLookup`, `AppleContextualEmbeddingLookup`, `mul_Latn`, and
`apple.nl.embedding`. The test plug-in was deliberately not treated as product
runtime code because it contains the test's own assertion names.

Earlier intermediate retained logs remain:

- first green:
  `a020af9f04147c3fc67825c44a06a6ae28623b9af27960fc221da098b4afe3a9`;
- compile-stop Green2:
  `a9ad54ca66d8882d136f936fa5b78850c491f30a4fd368d36e1c33b93599a95f`;
- direct-result Green3:
  `6553ad935b54a2891e717589520d8b8a2beb96dd3435abeb301560869a08eab3`.

Each accepted test/build began only after a complete resource/process preflight,
termination of any stale Epistemos test host, and removal of the preceding
Epistemos app product. Authorizing preflights recorded 14,467.00 MiB swap used,
65–67% free memory, zero throttled pages, ample disk, and no competing
Xcode/compiler/model/Epistemos process. The post-Green4 check records 14,665.69
MiB swap used, 69% free memory, zero throttled pages, 687,930,668 KiB available
disk, no competing process, dirty count 180, and a clean `git diff --check`.

### Current verdict and exact next action

This closes only the Free V1 Apple embedding-model regression. It does not
prove a release archive, normal app launch, full graph behavior, complete
no-AI surface, performance, privacy, vault safety, MarkEdit fidelity, audio,
calendar, Kokoro playback, or release readiness. The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is the already-recorded test-first audio/privacy repair:
prove and implement zero AVAudioEngine graph creation before an explicit
successful Kokoro read-aloud action, and remove all microphone-authorization
polling from SwiftUI render/computed paths while preserving explicit Meeting
capture. Then continue the compiled/visible Free V1 surface boundary and the
centralized vault-path identity repair. Do not begin MarkEdit or other canon
features until the KEELSTONE runtime blockers are genuinely closed.

## Same-Key Repair Continuation — Explicit-Only Audio Resources — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It addresses only the
eager Kokoro playback graph, eager Meeting capture engine, and repeated
microphone-authorization queries proved by the red finite runtime matrix. It
does not claim audible Kokoro playback, successful live microphone capture,
normal-launch silence, or release readiness.

### Expected red

The selected test
`AppStoreKeelstoneLaneTests.appStoreAudioResourcesStayDormantUntilExplicitUserActions()`
first failed on the uncorrected source with one failed test, zero passed, and
nine issues. It proved that the Kokoro engine/player and Meeting audio engine
were eager properties and that Landing, Meeting, and Settings each queried
microphone authorization from presentation code.

- result:
  `build/xcode-results/2026-07-14-keelstone-audio-dormancy-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-keelstone-audio-dormancy-red-16gib.log`,
  SHA-256
  `30ac642cf3ba444dca9cb8bcf7d69fa8ec3c059d70e490d128c4614d1542aa93`;
- terminal marker: `TEST FAILED`.

### Surgical correction

- `EpistemosSpeechSynthesizer` now owns an optional Kokoro playback graph.
  The engine, player, attachment, and connection are created only inside the
  explicit playback path after synthesis has produced a valid buffer. Stop,
  failure, and completion release the graph; idle pause/resume/status reads do
  not allocate it.
- `EpistemosSpeechAnalyzer` now owns an optional capture engine. Explicit
  `startLive` creates it only after microphone permission and model readiness;
  teardown removes the tap, stops the engine, and releases it.
- `LiveVoiceInputService` retains a typed denial result from the explicit
  start path. Landing, Meeting, and Settings no longer call
  `AVCaptureDevice.authorizationStatus(for: .audio)` from computed or render
  paths. The active-capture permission-revocation monitor remains intact.
- The two stale legacy source guards were updated to require deferred
  permission request rather than authorization polling. No entitlement,
  Kokoro package, voice, model, vault, provider, or route was changed.

### Accepted green and bounded evidence

The final strengthened selected test exercises the live process singletons as
well as source contracts: idle `stop`, `pause`, `resume`, and status reads
leave the Kokoro graph unallocated, and analyzer `stop` leaves its engine
unallocated. Direct result-bundle inspection records result `Passed`, one
passed, zero failed, zero skipped, total one.

- result:
  `build/xcode-results/2026-07-14-keelstone-audio-dormancy-green2-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-keelstone-audio-dormancy-green2-16gib.log`,
  SHA-256
  `70516e4b7db0b9dbefd96e52ea5a01e2719eb482f23e49161233c62e89150a08`;
- terminal marker: `TEST SUCCEEDED`;
- selected test duration: 0.062 seconds.

The accepted test-host log contains the expected explicit analyzer-stop line
from the assertion and zero matches for Kokoro playback preparation/start,
audio-engine start, microphone TCC service, or attach/connect/start markers.
The current disposable Debug test app launcher remains SHA-256
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
its rebuilt runtime code library is SHA-256
`a958ee7940da7e8b9375ddd7888ec81cad3cf09dfcde0253849f9cc46c8f6deb`.
This is test-host evidence, not a normal-app unified-log proof.

The post-green resource check recorded 14,633.69 MiB swap used, 65% free
memory, zero throttled pages, ample disk, no competing Xcode/compiler/model/
Epistemos process, dirty count 186, and a clean `git diff --check`. There is
still no archive; the only current app product is the disposable Debug test
app at
`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.

### Current verdict and exact next action

This closes the narrow deterministic explicit-only allocation regression. A
normal Free V1 launch with correlated unified logs, an owner-approved installed
Kokoro package with audible playback, and explicit Meeting capture/start/
teardown remain verification debt. `AmbientFrequencyLivePlayer` also retains
an eager inactive `AVAudioEngine`; audit it later if normal-launch evidence
shows an idle engine-allocation cost, without broadening this repaired leg.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is the compiled and visible Free V1 boundary: preserve
legacy persisted rows while removing Companions, agent/chat, Browser,
ResearchHub, private Writing Tools, and paid diagnostics/settings/resources
from the Free compilation and visible product. Then implement the centralized
vault-path identity repair. MarkEdit Source/Preview work begins only after
those KEELSTONE blockers are current-evidence green.

## Same-Key Repair Continuation — Free V1 Companion Compile Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It removes only the
Companion runtime, Farm presentation, and automatic launch seeding from Free
V1 while retaining the exact `CompanionModel` SwiftData entity for legacy-row
readability. It does not claim that every paid surface or paid localization
string has left the Free artifact.

### Expected red and correction

The selected test
`AppStoreKeelstoneLaneTests.freeV1PreservesCompanionRecordsWithoutCompanionRuntimeSurfaces()`
first failed with one failed test, zero passed, and thirteen issues because no
Companion compile exclusions or Free call-site guards existed.

- result:
  `build/xcode-results/2026-07-14-free-v1-companion-boundary-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-companion-boundary-red-16gib.log`,
  SHA-256
  `f79e9b69d7b44411b1f642ff8a69ddd1c587221d25ae63d4fc75b88a7a3338e7`;
- terminal marker: `TEST FAILED`.

The surgical correction compile-excludes the eleven runtime/UI files under
`State/Companion`, `Views/Landing/Farm`, and
`CompanionAnimationState.swift`. `AppBootstrap`, `AppEnvironment`, and
`LandingView` conditionally omit Companion state construction, model-context
attachment, four-record default seeding, environment injection, dock,
creation/edit overlay, destructive/restore sheets, and Farm helpers from
`EPISTEMOS_FREE_V1`. `CompanionModel.swift` and its entry in
`EpistemosSchema.models` remain unchanged. Project YAML and the current
synchronized-folder membership-exception set contain the same eleven concrete
exclusions.

### Accepted green and compile/artifact proof

The accepted selected test records result `Passed`, one passed, zero failed,
zero skipped, total one:

- result:
  `build/xcode-results/2026-07-14-free-v1-companion-boundary-green-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-companion-boundary-green-16gib.log`,
  SHA-256
  `22bd4400a44f8ff8ae50299438e6ceaebc62e3ddd4bc49fca239b0079d59bc28`;
- terminal marker: `TEST SUCCEEDED`;
- selected test duration: 0.009 seconds.

The exact 762-entry Free Swift input list is SHA-256
`edb0ebe148d1fa1eb1021eee0c95996562405b6bb735723fe8ab9e7c98d904e9`.
It has zero entries for `State/Companion`, `Views/Landing/Farm`, or
`CompanionAnimationState` and retains exactly the storage source
`Models/Companion/CompanionModel.swift`. Xcode explicitly removed the stale
Companion/Farm object and strings-data files from the reused derived-data
location before linking.

The rebuilt Debug runtime library is SHA-256
`7f652c5e5d993b4cbcb0688856580663d073e21f3b828f1bdffa7e3c3316bf58`.
Its global-symbol and runtime-string scans return zero matches for the excluded
Companion state/Farm types, while 99 `CompanionModel` symbol matches confirm
the storage entity remains. The launcher SHA-256 remains
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`.
This is a disposable Debug test product, not an archive or normal-launch
manual proof.

Both serial builds began below the owner's threshold and only after removing
the preceding disposable app product. The green postcheck records 14,625.69
MiB swap used, 66% free memory, zero throttled pages, ample disk, no competing
exact-name process, dirty count 187, and a clean `git diff --check`. There is
still no archive and exactly one current disposable Debug app product.

### Remaining debt and exact next action

`Localizable.xcstrings` still contains Companion copy, so this leg does not
authorize a zero-Companion-string artifact claim. The resource audit also
found that XcodeGen 2.45.4 does not materialize the target-level `resources:`
mapping currently written in `project.yml`; effective Free resource controls
must be source entries/membership exceptions and verified against the built
bundle. Treat this as current project/resource debt, not as an effective
exclusion.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is the smallest remaining interactive Settings leak:
fail-close and compile-exclude the Provenance Console while retaining core
EventStore/provenance records and legacy route compatibility. Then remove the
private/AI Writing Tools route, followed by Browser/ResearchHub compile and
resource boundaries. The centralized vault-path repair remains next after the
Free compiled/visible boundary is closed.

## Same-Key Repair Continuation — Free V1 Provenance Console Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It removes only the
interactive Provenance Console and its projection service from the Free V1
compilation and Settings route. It deliberately retains `EventStore`,
`AgentProvenanceEvent`, AnswerPacket/provenance records, and the legacy
`SettingsSection.provenance` discriminator so stored data and old route values
remain readable.

### Expected red

The selected fail-first batch first proved both the behavior and source
membership were wrong:

- `FreeV1ProductCapabilityPolicyTests.deepLinksCannotBypassThePolicy()` proved
  `.provenance` was visible and a direct selection did not fail closed;
- `AppStoreKeelstoneLaneTests.freeV1ExcludesProvenanceConsoleWithoutDeletingProvenanceData()`
  proved the console view/projection sources were still members and the Free
  detail switch still named the console.

The retained red result contains two failed tests and eight recorded
expectation issues:

- result:
  `build/xcode-results/2026-07-14-free-v1-provenance-boundary-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-provenance-boundary-red-16gib.log`,
  SHA-256
  `892ca8298535a37a8212118d0385e45dfb62311ae673418b33e08186cab33e57`;
- direct `xcresulttool` summary: result `Failed`, zero passed, two failed,
  zero skipped, total two;
- terminal marker: `TEST FAILED`.

### Surgical correction

- `ProductCapability.provenanceConsole` is explicitly classified as
  `futurePaid`.
- Settings appends `.provenance` only when that capability is available and
  redirects unavailable legacy/deep-linked selections to `.general`.
- The Free detail switch compiles `GeneralDetailView` for the retained enum
  value; the non-Free branch remains the only branch that names
  `ProvenanceConsoleView`.
- `project.yml` and the active Xcode synchronized-folder membership exception
  both exclude only
  `Engine/ProvenanceConsoleProjectionService.swift` and
  `Views/Settings/ProvenanceConsoleView.swift`.
- `State/EventStore.swift` and `Models/AgentProvenanceEvent.swift` remain
  compiled and are guarded against accidental exclusion.

### Accepted green and compile/artifact proof

The accepted selected batch added the complete capability-partition test and
passed all three tests with zero failures:

- result:
  `build/xcode-results/2026-07-14-free-v1-provenance-boundary-green-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-provenance-boundary-green-16gib.log`,
  SHA-256
  `86b595f725055c54c1efb3f86a1d23e807277bf3c48c1504c0def9107316ad09`;
- direct `xcresulttool` summary: result `Passed`, three passed, zero failed,
  zero skipped, total three;
- terminal marker: `TEST SUCCEEDED`.

Xcode explicitly removed the stale object, strings-data, and const-values
outputs for both excluded sources before linking. The exact 760-entry Free
Swift input list is SHA-256
`18c1e755f05415a8563ca61fc46b240a4f7bba7367a890a8bc92b7f4ae3f66d1`.
It contains neither console source and still contains
`Models/AgentProvenanceEvent.swift` at entry 308 and `State/EventStore.swift`
at entry 385.

The current disposable Debug runtime library is SHA-256
`5876bd7329009305c0ce2cf3210d1e62d3e1294e91a3e28c0dec0aee1e98d208`;
its global-symbol and runtime-string scans returned zero matches for
`ProvenanceConsoleSnapshot`, `ProvenanceConsoleProjectionService`, or
`ProvenanceConsoleView`. The launcher SHA-256 remains
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`.
This is test-host evidence, not a normal-launch UI or Release-archive claim.

Both serial builds began only after a complete owner-threshold preflight and
removal of the preceding disposable app. The green postcheck recorded
14,660.25 MiB swap used, 65% free memory, zero throttled pages, ample disk,
and no competing Xcode/compiler/model/Epistemos runtime after the evidence
scan. The worktree retained 187 dirty entries and passed `git diff --check`.

### Remaining debt and exact next action

The legacy section discriminator and core provenance terminology intentionally
remain, so this leg does not claim zero provenance strings or deletion of
provenance data. The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is the private/AI Writing Tools boundary. First prove the
native Epistemos bridge and vendored MarkEdit `AppWritingTools`/related private
selectors are still compiled into the Free lane, then compile-exclude or
public-API replace them without removing the App Store-safe MarkEdit editor or
the future narrow native Previewer popover. Browser/ResearchHub boundaries and
centralized vault-path containment remain downstream.

## Same-Key Repair Continuation — Free V1 Private Writing Tools / Restricted MarkEdit Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. The owner clarified that
the MarkEdit restriction is an authority boundary, not a visual downgrade:
Free V1 must retain the restricted MarkEdit Source editor and the later
App-Store-safe eye/Previewer popover while compiling out private Writing Tools,
Foundation Models bridges owned by the donor shell, broad file/service/
clipboard authority, and the donor app shell. The vendored donor sources remain
in the repository for attribution, reference, and a future separately gated
lane; they are not deleted.

### Expected red and narrow compile trap

The selected fail-first guard
`AppStoreKeelstoneLaneTests.freeV1ExcludesWritingToolsWithoutRemovingRestrictedMarkEditEditor()`
first failed because the Free target still compiled the donor shell,
MarkEditKit/MarkEditModules, native Writing Tools bridges, the private-backed
MarkEditCore WebKit extension, and unsafe CoreEditor modules:

- result:
  `build/xcode-results/2026-07-14-free-v1-writing-tools-boundary-red2-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-writing-tools-boundary-red2-16gib.log`,
  SHA-256
  `5816366ff4f14b0da3b23786e23df1c5de4998aefc1c8152d67b6fb4bf1bc605`;
- direct `xcresulttool` summary: result `Failed`, zero passed, one failed,
  zero skipped, total one.

The first intended-green attempt correctly exposed one remaining compile
reference rather than producing a misleading pass. With MarkEditKit removed,
three settings branches guarded only by `canImport(MarkEditKit)` still named
`MarkEditSourceSettingsSheet`. The build stopped before tests with exit 65 and
`TEST FAILED`:

- result:
  `build/xcode-results/2026-07-14-free-v1-writing-tools-boundary-green-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-writing-tools-boundary-green-16gib.log`,
  SHA-256
  `f3c5a840e15271e3d6b55385631d00dbd1dbe77d557edace70b592fbf4a75b8e`.

The surgical repair replaced those availability checks with the explicit
product-policy condition
`EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)`.

### Surgical correction

- The Free app target excludes
  `MarkEdit/MarkEditShellCompatibility.swift`,
  `Views/Notes/WritingToolsBridge.swift`, and the complete donor
  `MarkEditMac/Sources` tree.
- The Free target no longer registers or links MarkEditKit or any
  MarkEditModules product and no longer bundles donor app resources.
  MarkEditCore remains the only linked MarkEdit package.
- MarkEditCore excludes its private-backed
  `Extensions/WebKit+Extension.swift` from this lane while retaining that
  source in the donor tree.
- Prose and Source editor configurations set public
  `writingToolsBehavior = .none` in Free V1. The menu command, observer,
  context-menu bridge, toolbar glyph, and bridge reply cases compile only
  outside Free V1.
- CoreEditor omits its Web API/Writing Tools/Foundation Models/Translation
  modules and their native bridge exports. Preview, tokenizer, history,
  completion, CodeMirror/Lezer, and MarkEdit formatting remain.
- Source uses public `underPageBackgroundColor = .clear`, retains the
  `preview.show` native seam, and preserves donor-equivalent markdown defaults:
  `ui-monospace`, 15-point text, 1.5 line height, and the mapped MarkEdit theme
  families. This leg does not yet claim pixel fidelity or a functioning native
  preview popover.

### Accepted green and exact artifact proof

The accepted selected test passed one test with zero failures and zero skips:

- result:
  `build/xcode-results/2026-07-14-free-v1-writing-tools-boundary-green2-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-writing-tools-boundary-green2-16gib.log`,
  SHA-256
  `7d7ba4547e014f05d7b1154946cc448daa7f9252d1067b247425beb1db420376`;
- direct `xcresulttool` summary: result `Passed`, one passed, zero failed,
  zero skipped, total one;
- terminal marker: `TEST SUCCEEDED`.

The exact 696-entry Free Swift input list is SHA-256
`ecd4d7f3359fd062cf8f4d626d4e6063e8c58970f85667157bf2c5a48b010483`.
It contains zero forbidden donor app inputs and retains the three required
restricted-editor inputs. The exact 12-entry MarkEditCore Swift input list is
SHA-256
`19c79259769e4e10f78ecba07bd69eb5e92c0319fd1ddb73dd790d0bab16b206`
and contains zero private WebKit-extension entries.

The exact rebuilt CoreEditor main chunk is SHA-256
`8b922b9856a413e85f6bd439626087cd5979f5b792410afad0a5d84ad88be591`.
It contains zero forbidden Writing Tools/Foundation Models/Translation/API
bridge markers, eleven retained preview markers, and six retained
`ui-monospace` markers. The rebuilt Debug runtime library is SHA-256
`f743fa66cc54732e58ba0e4cc6876681ba78f946059ab0d644ae2aef14149d00`;
its private Writing Tools marker count and linked MarkEdit donor dependency
count are both zero.

The corrected artifact audit is retained at
`build/xcode-results/2026-07-14-free-v1-writing-tools-boundary-green2-16gib-artifact-audit2.txt`,
SHA-256
`0897c97a447dd01956a3af8732b60abfffeb4423f26f262bf26493584985736d`.
Its production-payload scan excludes the test plug-in and reports zero donor
markers. The two donor source names in the first audit are expected source
fixtures staged inside the test plug-in so the guard can verify that the
excluded source still exists; they are not production app inputs or linked
donor code.

### Honest remaining debt and exact next action

The exact Debug runtime still links
`/System/Library/Frameworks/FoundationModels.framework` and imports live
Foundation Models symbols from other Epistemos sources. That is a real broader
Free V1 no-AI blocker outside the repaired MarkEdit boundary. Therefore this
leg proves only the private Writing Tools/restricted MarkEdit boundary; it does
not prove that the whole Free app contains no AI or that Release is clean.
There is still no Release archive, normal-launch UI proof, or native eye
popover runtime proof.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is the combined Browser/ResearchHub and broader
Foundation Models/general-AI compile boundary: retain Kokoro voice and legacy
data discriminators while removing those paid/AI routes, sources, native
dependencies, and resources from Free V1. Re-run a fail-first selected guard,
compiler-input proof, and exact artifact dependency/symbol scans. The
centralized vault-path containment repair remains next after the compiled and
visible Free boundary is closed. MarkEdit visual fidelity and the narrow public
AppKit/WebKit native eye popover begin only after these KEELSTONE blockers are
current-evidence green.

## Same-Key Repair Continuation — Free V1 Browser / ResearchHub / FoundationModels Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It removes the operational
Browser, arXiv pull/search, DeepResearch/ResearchHub, paid web-tool preset, and
live Apple FoundationModels implementation from Free V1 compilation while
retaining legacy data discriminators, inert route compatibility, normal
user-clicked links, generic PDF/research metadata, Kokoro, and the restricted
MarkEdit editor. The parked paid sources remain in the repository; this leg
does not delete them or activate another execution key.

### Expected red and test-harness red

The selected fail-first test
`AppStoreKeelstoneLaneTests.freeV1ExcludesBrowserResearchHubAndFoundationModelsImplementation()`
first failed one test with 47 recorded `Expectation failed` entries:

- result:
  `build/xcode-results/2026-07-14-free-v1-browser-research-foundationmodels-boundary-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-browser-research-foundationmodels-boundary-red-16gib.log`,
  SHA-256
  `7788f4a3bf76c595c1e4f33ab8f5e08de6a5d78df9dbbbee10ebfdf7d4530a2a`;
- direct `xcresulttool` summary: result `Failed`, zero passed, one failed,
  zero skipped, total one.

The first intended-green result is deliberately retained as a harness failure,
not implementation evidence. Its dynamic test expression was accidentally
parsed by the repository-source staging script as a literal path, so the test
host stopped before executing tests with
`error: missing repository source guard input: Epistemos/\(excludedSource)`:

- result:
  `build/xcode-results/2026-07-14-free-v1-browser-research-foundationmodels-boundary-green-16gib.xcresult`;
- log SHA-256:
  `d24ffbb6425a2d3112e60c86fa47500d6617e03752c05c23dd24982b580e6bfd`;
- direct summary: result `unknown`, zero tests executed.

The corrected staging contract produced one intermediate green result. A
subsequent exact generic-link correction and removal of the paid web-tool
preset from the Free resource membership required the final current green3
artifact; green2 is therefore historical, not the final artifact identity.

### Surgical correction

- `project.yml` and the active app synchronized-folder exception set exclude
  the exact Browser/arXiv/DeepResearch implementation sources plus
  `Resources/best_of_preset.json` from Free compilation/resources without
  deleting their source.
- Shared landing, landing-feature, utility-window, note-window, settings, and
  data-detection call sites now fail closed under `EPISTEMOS_FREE_V1`.
  Explicit user-clicked HTTP(S) links still open through the system browser;
  the in-app Browser route itself remains inert.
- The widget defines `EPISTEMOS_FREE_V1` in both Debug and Release because it
  independently compiles three mixed FoundationModels sources.
- All eight mixed FoundationModels sources use
  `!EPISTEMOS_FREE_V1 && canImport(FoundationModels)`. The complete
  `LanguageModelSession`-bearing function declaration is inside that guard,
  not merely its body.
- Legacy arXiv/PDF front-matter readers, generic research-stage metadata,
  compatibility enums, Kokoro voice, and restricted MarkEdit/WebKit remain by
  design.

### Accepted exact-current green and artifact proof

The final selected test passed one test with zero failures and zero skips:

- result:
  `build/xcode-results/2026-07-14-free-v1-browser-research-foundationmodels-boundary-green3-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-browser-research-foundationmodels-boundary-green3-16gib.log`,
  SHA-256
  `5b470c1a64873dc9f27ee7da72653b8586b00a33074bbdbfd2aa5c5bb031335d`,
  411656 bytes;
- direct `xcresulttool` summary: result `Passed`, one passed, zero failed,
  zero skipped, total one.

The exact 682-entry app Swift input list is SHA-256
`559bc35a8e7efb84d5edba7d36fd5dc7068a2457f67472f7abd2eba298d6b5a2`.
It contains zero excluded Browser/arXiv/DeepResearch/preset inputs while
retaining the eight mixed schema/fallback files, the speech synthesizer,
Kokoro sources, and five restricted MarkEditCoreEditor app sources.

The sole current disposable Debug app is
`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.
Its launcher is 40344 bytes with SHA-256
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
its 257471704-byte Debug runtime library has SHA-256
`bf5127228e4c198562c1cd966f0e907d16bf5a8e076d0044c85ad0d46b722715`.
There is no current archive and no embedded app extension in this exact app.

Exact launcher/runtime inspection reports:

- zero FoundationModels framework linkage and zero undefined FoundationModels
  symbols;
- zero exact qualified Browser/arXiv/DeepResearch implementation types;
- zero arXiv API, Browser tracker, DuckDuckGo in-app search, DeepResearch,
  Tavily, Brave Search, or Perplexity operational markers;
- `best_of_preset.json` absent;
- CoreEditor and Editor resources present;
- WebKit retained for restricted MarkEdit/preview behavior and CoreML retained
  only for the explicit Kokoro exception.

The complete retained audit is
`build/xcode-results/2026-07-14-free-v1-browser-research-foundationmodels-boundary-green3-16gib-artifact-audit.txt`,
SHA-256
`8b39501086e0b27688c40132e396a80486cdf88b10ae85b95d8de1d7d3d43caa`.
The postcheck recorded 14904.81 MiB swap used, 66% free memory, zero throttled
pages, 652 GiB available disk, and a clean `git diff --check` result.

### Honest remaining red debt and exact next action

This boundary is green, but the literal Free V1 no-model/no-AI claim is still
false. The exact app still links NaturalLanguage/libswiftNaturalLanguage and
imports `NLTokenizer`, `NLTagger`, and `NLLanguageRecognizer` operations from
three mixed sources. Generated App Intents metadata still names paid
AI/chat/agent intents/entities, `Assets.car` still includes three AI provider
logos, and broader June/chat/agent/cloud source inputs and paid localization
copy have not yet been proved absent. The selected test-host runtime also logs
duplicate-column migration warnings for `session_metrics` and
`mutation_projection_outbox`, plus a Metadata `dev_t` warning.

There is still no Release archive, normal-launch UI proof, finite runtime
matrix, MarkEdit visual comparison, or native eye-popover proof. The overall
verdict therefore remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is a fail-first broader Free V1 no-model boundary. Add
deterministic Free fallbacks for the three NaturalLanguage mixed sources while
preserving their public schemas, then split or compile-exclude paid App
Intents/entities, provider assets/localizations, and broader
June/chat/agent/cloud execution surfaces. Re-run the selected source guard,
compiler-input proof, and exact artifact dependency/symbol/resource scans.
Centralized vault containment remains next after the compiled and visible Free
boundary is green. Only then begin the App-Store-safe near-verbatim MarkEdit
visual host and native eye/Previewer popover.

## Same-Key Repair Continuation — Free V1 NaturalLanguage Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It removes Apple
NaturalLanguage model-backed tokenization, language recognition, sentiment,
entity inference, and lexical tagging from Free V1 compilation while retaining
the existing capture, note-insight, graph, and personality schemas. The Free
lane uses deterministic lexical fallbacks instead of inferred entities or
model-backed analysis. Kokoro voice, MarkEditCore, WebKit preview
infrastructure, and normal deterministic note behavior remain.

### Expected red

The fail-first selected test
`AppStoreKeelstoneLaneTests.freeV1ExcludesNaturalLanguageModelBackedAnalysis()`
correctly failed before the source correction. It observed live English
language detection, positive sentiment, non-neutral personality sentiment,
unguarded imports, and missing deterministic Free branches:

- result:
  `build/xcode-results/2026-07-14-free-v1-naturallanguage-boundary-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-naturallanguage-boundary-red-16gib.log`,
  SHA-256
  `a8538a7e2ff111e2af5270d8ead13affabcce6640f28db5bfc280ecd760d575f`;
- direct summary: result `Failed`, zero passed, one failed, zero skipped,
  total one;
- recorded issues: 17.

No broad refactor followed. The correction was limited to the eight exact
NaturalLanguage-bearing source files plus the selected guard test.

### Surgical correction

- Every production `import NaturalLanguage` is now inside
  `#if !EPISTEMOS_FREE_V1`.
- `NLAnalysisService` returns no inferred entities, no detected language, and
  neutral sentiment in Free V1; its Free word count deterministically splits
  Unicode letters and numbers.
- `TextCapturePipeline` retains capture, tasks, persistence, source spans, and
  note schemas. Its Free title fallback uses deterministic punctuation/newline
  sentence boundaries and the existing 120-character cap; inferred entities
  are empty.
- `ContentPersonalitySignals` retains literal question density,
  deterministic vocabulary diversity, and frequency-first lexical topics with
  lexicographic tie-breaking. It returns neutral sentiment/formality and no
  inferred entities in Free V1.
- Four otherwise-unused imports in note insight, graph state, and graph
  inspector sources are also guarded so they cannot force-load the Swift
  NaturalLanguage overlay.

### Accepted green and exact artifact proof

The mandatory preflight recorded 14896.81 MiB swap used, 62% free memory,
zero throttled pages, 652 GiB available disk, and no competing Xcode,
compiler, model, or Epistemos process. The stale exact app product was removed
before the serial selected test.

The accepted selected test passed one test with zero failures and zero skips:

- result:
  `build/xcode-results/2026-07-14-free-v1-naturallanguage-boundary-green-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-naturallanguage-boundary-green-16gib.log`,
  SHA-256
  `00e1c8fdd4f34627f4329767374f9dd516bf644eec1c94efafab4d97087f6fdb`,
  411398 bytes;
- direct `xcresulttool` summary: result `Passed`, one passed, zero failed,
  zero skipped, total one;
- terminal marker: `TEST SUCCEEDED`.

The exact 682-entry app Swift input list remains SHA-256
`559bc35a8e7efb84d5edba7d36fd5dc7068a2457f67472f7abd2eba298d6b5a2`.
It retains all eight deterministic/mixed sources, all five
`MarkEditCoreEditor` app sources, `ModelVoicePickerSection`, and six Kokoro
VoicePro sources.

The sole current disposable Debug app is
`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.
Its 40344-byte launcher is SHA-256
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
its 257429400-byte Debug runtime library is SHA-256
`acf1205328e6c9d6ae53bf51c95fdaba93337fe39ce80fa50835134cb8c1e034`.
There is one current app, no current archive, and no embedded app extension.

Exact launcher/runtime inspection reports zero NaturalLanguage framework or
Swift-overlay linkage; zero `NLTagger`, `NLTokenizer`,
`NLLanguageRecognizer`, `NLEmbedding`, `NLContextualEmbedding`, or
`swiftNaturalLanguage` force-load symbols; and zero correlated
NaturalLanguage-model or `mul_Latn` runtime-load events. MarkEdit editor and
KokoroPipeline symbols remain. WebKit remains for restricted MarkEdit preview
behavior and CoreML remains for the explicit Kokoro exception.

The complete retained audit is
`build/xcode-results/2026-07-14-free-v1-naturallanguage-boundary-green-16gib-artifact-audit.txt`,
SHA-256
`2ef4aa0a388fb3154b33b56fcbdf8bbe0074f7e08c066aabdddebe94306c55b2`.
The postcheck recorded 14872.81 MiB swap used, 64% free memory, zero
throttled pages, 651 GiB available disk, and zero active Xcode/compiler/model/
Epistemos processes.

### Honest remaining debt and exact next action

This bounded boundary is green, but generated App Intents metadata still
contains paid AI/chat/agent intents and entities. Paid provider branding,
broader June/chat/agent/cloud source inputs, duplicate-column migration
warnings, and the Metadata `dev_t` warning also remain. There is still no
fresh Release archive, normal-launch UI proof, finite runtime matrix,
MarkEdit visual comparison, or native eye/Previewer popover proof.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is the fail-first Free V1 App Intents compile/metadata
whitelist boundary: retain only deterministic note/journal/panel/document
actions and the four approved shortcuts, while compiling paid AI/chat/agent
intents and entities out rather than merely hiding discovery. Then run the
same mandatory preflight, one serial selected test, exact generated-metadata
whitelist inspection, compiler-input/source proof, and single-artifact audit.
Provider branding/leaf runtime and the broader AI execution-surface split
remain next. MarkEdit visual fidelity and the public native eye/Previewer
popover remain queued immediately after the KEELSTONE blockers close.

## Same-Key Repair Continuation — Free V1 App Intents Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It compiles paid
AI/chat/agent App Intents, entities, queries, focus metadata, and sandbox
controls out of the Free V1 main app while retaining deterministic note,
journal, panel, document, search, and capture integrations. Paid source is
preserved on disk behind target exclusions or explicit paid compile
conditions; it is not deleted.

### Expected red

The mandatory preflight recorded 14872.81 MiB swap used, 65% free memory,
zero throttled pages, 651 GiB available disk, and no competing Xcode,
compiler, model, or Epistemos process. The stale exact app was removed before
the serial two-test run.

Both fail-first tests correctly failed with 27 recorded issues:

- result:
  `build/xcode-results/2026-07-14-free-v1-appintents-boundary-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-appintents-boundary-red-16gib.log`,
  SHA-256
  `2b52470b0c52ca50cd16dea69205efa9a3ea90c3af54fa769cfde20ad83ad662`,
  548240 bytes;
- direct summary: result `Failed`, zero passed, two failed, zero skipped,
  total two;
- stale generated metadata: 61591 bytes, SHA-256
  `cbf50444da7b917ffdf9c1b5ee3e3f91eb6c44ef57e32dd13dabb4299989644f`;
- stale shape: 21 actions, 8 entities, 8 queries, 1 enum, and 4 shortcuts.

That red artifact proved that `isDiscoverable = false` was not a compile or
metadata boundary. It still contained Ask About Notes, Daily Brief,
Summarize Note, four cognitive/agent actions, ChatEntity, BrainDumpEntity,
and the Epistemos focus enum/filter.

### Surgical correction and source preservation

- The Free app target excludes exactly six whole sources in both
  `project.yml` and the live synchronized-folder PBX membership exceptions:
  AnalysisIntents, DailyBriefingIntent, BrainDumpEntity, ChatEntity,
  EpistemosControlWidget, and VisualIntelligenceIntents.
- NoteActionIntents retains deterministic capture/open/move/search and puts
  SummarizeNoteIntent behind `!EPISTEMOS_FREE_V1`.
- CognitiveIntents retains deterministic CaptureBrainDumpIntent and puts
  context/thesis/sandbox/agent actions behind `!EPISTEMOS_FREE_V1`.
- EpistemosFocusKeys remain for stored-state compatibility, while the
  AppEnum, focus intent, AppIntents import, and logger are paid-only.
- The separately declared widget source retains capture and guards the paid
  sandbox control; the exact main-app scheme does not build or embed that
  extension, so its executable proof remains debt.
- EpistemosShortcutsProvider exposes exactly Create Note, System Search,
  Quick Capture, and Capture Brain Dump. Parked paid IntentError cases/copy
  remain source-preserved behind `!EPISTEMOS_FREE_V1`.

### Accepted green and exact artifact proof

The green preflight recorded 15095.38 MiB swap used, 55% free memory, zero
throttled pages, 651 GiB available disk, and no competing process. The stale
exact app was again removed before the serial selected run.

The same two selected tests passed with zero failures and zero skips:

- result:
  `build/xcode-results/2026-07-14-free-v1-appintents-boundary-green-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-appintents-boundary-green-16gib.log`,
  SHA-256
  `f7091f22156fd5b3e77fb1c1b7da04daa0cc4149581d6e586638410b329c6ffc`,
  416844 bytes;
- direct `xcresulttool` summary: result `Passed`, two passed, zero failed,
  zero skipped, total two;
- terminal marker: `TEST SUCCEEDED`.

The freshly generated 36893-byte `extract.actionsdata` is SHA-256
`e9c989d6790f1f927bcb040e9942cd78d50fb014a7ea180e816e1552dd0db511`.
Its exact shape is:

- 13 actions: ArchiveNote, CaptureBrainDump, CreateJournal, CreateNote,
  DeleteNote, MoveNoteToFolder, NotePreviewSnippet, OpenPanel, OpenVaultFile,
  QuickCapture, SearchDocuments, SearchJournal, and SystemSearch;
- 6 entities: Folder, Journal, Note, Panel, WordProcessorDocument, and
  WordProcessorDocumentTemplate;
- the corresponding 6 queries;
- zero enums;
- 4 auto shortcuts in the exact approved order;
- empty `assistantIntents` and `assistantEntities`.

The exact app Swift input list now has 676 entries and SHA-256
`990dc2b00ff6f447f967e363e8675e10a637ca320d428f4e129cbe6c0c11c222`.
It contains none of the six excluded source inputs and retains the four mixed
deterministic sources.

The sole current disposable Debug app remains
`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.
Its 40344-byte launcher is SHA-256
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
its 256911096-byte Debug runtime library is SHA-256
`923305b727d0a814a64eb96935ff69c26609509be3c6dbee69fc3e2d323499ed`.
There is one current app, no archive, and no current `.appex`.

Exact production binary inspection reports zero excluded paid
intent/entity/focus/widget symbols and zero exact excluded title/description
strings. Retained deterministic App Intent and App Shortcut symbols are
present. The excluded source files remain on disk with hashes recorded in the
retained audit.

The complete retained audit is
`build/xcode-results/2026-07-14-free-v1-appintents-boundary-green-16gib-artifact-audit.txt`,
SHA-256
`7f7b6207185fa6448286465ddf1ab8f6811d9767c45824562a3be7bfa76f644c`.
The postcheck recorded 15169.31 MiB swap used, 54% free memory, zero
throttled pages, 650 GiB available disk, and zero active Xcode/compiler/model/
Epistemos processes.

### Honest remaining debt and exact next action

This bounded main-app boundary is green. It does not prove the separately
declared widget extension because the main scheme neither built nor embedded
it. Paid provider logos/branding and leaf runtime inputs remain in the exact
main app; broader June/chat/agent/cloud execution sources also still compile.
The overall no-AI claim is therefore still false. Duplicate-column migration
warnings and the Metadata `dev_t` warning remain, and there is still no fresh
Release archive, normal-launch UI proof, finite runtime matrix, MarkEdit
visual comparison, or native eye/Previewer popover proof.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is the fail-first provider-branding and leaf-runtime
compile boundary: compile the mapped provider views, AgentSurface, XPC,
LocalAgent, and route-profile/settings leaf files out of Free V1; move the
provider imagesets intact into a parked paid catalog outside the synchronized
Free source root; retain Kokoro/voice and MarkEdit; then run exact source-list,
symbol, string, and asset-catalog gates. The broader June/chat/agent/cloud
split follows. The App-Store-safe public MarkEdit eye popover remains queued
after these KEELSTONE blockers rather than restricted out of the product.

## Same-Key Repair Continuation — Free V1 Provider Branding And Leaf Runtime Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It removes
provider branding, provider/agent XPC clients, AgentSurface subprocess
support, LocalAgent routers, route profiles, and runtime-lane settings from
the Free V1 main-app compiler graph. It also moves all 17 provider-logo
imagesets intact into a parked paid catalog outside the synchronized Free
asset root. Kokoro, VoicePro, ModelVoicePickerSection, MarkEditCore, and the
Epistemos editor sources remain compiled.

### Expected red and bounded correction history

The fail-first selected test
`AppStoreKeelstoneLaneTests.freeV1ExcludesProviderBrandingAndLeafRuntimeSources()`
correctly failed before the source correction. Its stale app Swift input list
had 676 entries containing all 16 mapped paid sources, and its `Assets.car`
contained all 17 exact provider-logo names:

- result:
  `build/xcode-results/2026-07-14-free-v1-provider-leaf-boundary-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-provider-leaf-boundary-red-16gib.log`,
  SHA-256
  `44de441316638ab39f5ce7fba29878cd13d30e5e3ae7e16189ff8fa292909539`,
  1083908 bytes;
- direct summary: result `Failed`, zero passed, one failed, zero skipped;
- recorded issues: 47.

The surgical correction added nine declarative Free target exclusions and
the corresponding 16 concrete synchronized-folder membership exceptions,
guarded the cloud-model settings implementation and the two remaining
provider/XPC leaf accessors, and moved the 17 provider imagesets intact into
`ParkedPaidMAS/Assets.xcassets`. No paid Swift source or provider-logo payload
was deleted.

The first correction attempt stopped before compilation because the PBX entry
for `InferenceState+RouteProfiles.swift` needed quoting. Its 1545-byte log is
SHA-256
`319b888203ce11376330a650e4d746a1aa91727b06848f17ca765c7145f526fe`,
and its result contains zero tests with an unknown result. After quoting that
single path, the second correction attempt built the right artifact and
proved all provider assets absent, but failed one overly broad test assertion
that also rejected the required excluded-source filename
`ProviderLogoView.swift` in the project exception list. Its log is SHA-256
`ee261eadfa9fa5425040e2a525bc0e1e1082d8695fb8e6283ec742cbd2e78f3e`,
470252 bytes. Only that test assertion changed before the accepted run; no
production source changed after the second artifact.

### Accepted green and exact artifact proof

The accepted-green preflight recorded 15169.31 MiB swap used, 60% free
memory, zero throttled pages, 649 GiB available disk, and no competing Xcode,
compiler, model, or Epistemos process. The stale exact app was removed before
the serial selected test.

The selected test passed with zero failures and zero skips:

- result:
  `build/xcode-results/2026-07-14-free-v1-provider-leaf-boundary-green3-16gib.xcresult`;
- result Info.plist SHA-256:
  `ee494a142f4ce686c957cd35311967810101d5ede5b11224178ce3256550bb90`;
- log:
  `build/xcode-results/2026-07-14-free-v1-provider-leaf-boundary-green3-16gib.log`,
  SHA-256
  `516caf9b6f740de1ee43f1165d065062ec9b72a50609f404a776c6e442626470`,
  402869 bytes;
- direct `xcresulttool` summary: result `Passed`, one passed, zero failed,
  zero skipped, total one;
- selected-test duration: 0.030 seconds;
- terminal marker: `TEST SUCCEEDED`.

The exact app Swift input list now has 660 entries and SHA-256
`ff45b01f44190315ed83287b95aba3f1466f5d38655669f7c99c1af894b1c6d9`.
All 16 paid inputs are absent. All five MarkEditCoreEditor app sources,
ModelVoicePickerSection, and all six VoicePro sources remain present.

The sole current disposable Debug app is
`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.
Its 40344-byte launcher is SHA-256
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
its 255965208-byte Debug runtime library is SHA-256
`3a0a7cd9d29f9e36567a0ae28bd3f25a3aa9e0ec037f9137b03798ac8a7d72cd`;
and its 2562632-byte `Assets.car` is SHA-256
`a40de6165f6cd7cdf96c9ec3dac8e829f5cbb1f9e2f044bdf507dad72070df6e`.
There is one current app, no archive, no `.appex`, and one embedded selected-
test bundle.

Exact `assetutil`, symbol, and string inspection reports zero matches for all
17 provider asset names and the excluded AgentSurface, XPC, router,
runtime-lane, and provider-branding types. Retained runtime symbols include
MarkEdit editor types, KokoroPipeline, Kokoro CoreML/download types, Kokoro
VoicePro settings, and ModelVoicePickerSection.

All 16 paid Swift sources remain readable and nonempty. Seventeen parked
imagesets contain 34 original payload files; all 34 hashes match their `HEAD`
source-catalog counterparts with zero mismatches. The normalized parked
payload manifest is SHA-256
`26ea038b6f77b020940f9689c6d4555c6b31445998d8b7a91eeb045fb06bb514`.

The complete retained audit is
`build/xcode-results/2026-07-14-free-v1-provider-leaf-boundary-green3-16gib-artifact-audit.txt`,
SHA-256
`f3150f310c0242ae7f5908458d0fe51c6b309baf211ef22c67dfd242c5c6e217`,
8054 bytes.
The postcheck recorded 15145.31 MiB swap used, 63% free memory, zero
throttled pages, 648 GiB available disk, and zero active Xcode/compiler/model/
Epistemos processes.

### Honest remaining debt and exact next action

This bounded boundary is green, but JuneAgent, QuickChat, Goose, and three
legacy AgentWorkspace implementation files remain Free compiler inputs. The
overall no-AI claim is therefore still false. The accepted log also retains
four compiler/package warnings, twelve duplicate-column migration messages,
and one Metadata `dev_t` message. There is still no fresh Release archive,
normal-launch UI proof, finite runtime matrix, Kokoro audible proof, MarkEdit
side-by-side visual comparison, or native eye/Previewer popover proof.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is the fail-first June/QuickChat/Goose and legacy
AgentWorkspace source boundary. Compile all 20 JuneAgent, all 7 QuickChat,
all 3 Goose, and AgentSubscriptionService, AgentWorkspaceSession, and
EpistemosProxyClient out of Free V1 while preserving them on disk. Guard the
remaining RootView, Landing, Substrate Health, Epdoc, Markdown, app memory-
pressure, and read-aloud call sites; deterministically redirect persisted
`.agent` presentation to `.greeting`; retain Kokoro, MarkEdit, capture, and
deterministic search; then run the same preflight, serial selected test,
compiler-input/symbol/string audit, and single-artifact proof.

## Same-Key Repair Continuation — Free V1 June, QuickChat, Goose, And Legacy AgentWorkspace Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It removes all 20
`JuneAgent` sources, all 7 `QuickChat` sources, all 3 `Goose` sources, and
`AgentSubscriptionService`, `AgentWorkspaceSession`, and
`EpistemosProxyClient` from the Free V1 main-app compiler graph without
deleting them. Kokoro, the visible speech synthesizer, MarkEdit, capture,
deterministic search, and `AgentCloudConsent` remain compiled.

### Expected red

The fail-first selected test
`AppStoreKeelstoneLaneTests.freeV1ExcludesJuneQuickChatGooseAndLegacyAgentWorkspaceSources()`
correctly failed before the source correction:

- result:
  `build/xcode-results/2026-07-14-free-v1-june-leaf-boundary-red-16gib.xcresult`;
- log:
  `build/xcode-results/2026-07-14-free-v1-june-leaf-boundary-red-16gib.log`,
  SHA-256
  `282d154defc0bfdaea85015b99ff6c93ad08914c90eac96591833642849183e7`,
  1262634 bytes;
- direct summary: result `Failed`, zero passed, one failed, zero skipped,
  total one;
- recorded issues: 53;
- stale exact app Swift input list: 660 entries containing all 33 mapped paid
  sources.

No source correction, app launch, model load, provider request, secret access,
owner-vault operation, or audio operation occurred during the expected-red
run.

### Surgical correction and compile-red replacement history

The Free app target now excludes the four paid source families through six
declarative `project.yml` patterns and exactly 33 live synchronized-folder PBX
membership exceptions. The remaining Root, Landing, Substrate Health, Epdoc,
Markdown, app memory-pressure, and visible-read-aloud call sites are
`EPISTEMOS_FREE_V1` guarded. Persisted `.agent` presentation redirects to the
non-agent greeting surface. All 33 paid files remain on disk and nonempty.

The first intended green replacement passed its resource preflight and began
only after the stale app was deleted, but stopped before testing on this exact
compile error:

`MarkdownDocumentSurface.swift:116:14: Instance member 'onAppear' cannot be used on type 'View'`.

Its evidence is retained:

- result:
  `build/xcode-results/2026-07-14-free-v1-june-leaf-boundary-green-16gib.xcresult`;
- direct summary: result `unknown`, zero tests;
- log:
  `build/xcode-results/2026-07-14-free-v1-june-leaf-boundary-green-16gib.log`,
  SHA-256
  `fa89ccd6efc5af2f6382f5932c790d3b5cf37653054830e904c021c95fb04334`,
  247572 bytes.

The only correction after that compile stop wrapped the conditional
`EpdocEditorChromeView` branches in a concrete SwiftUI `Group` before applying
the shared modifiers. Free and paid Swift parse checks and `git diff --check`
passed before the replacement run. The failed app product was deleted again.

### Accepted green and exact artifact proof

The accepted-green replacement preflight recorded branch
`feat/goose-surface`, HEAD
`668b52cfb43721de95db102260d9f327ae24e13e`, 311 dirty entries, 14689.31 MiB
swap used, 52% free memory, zero throttled pages, 678421024 KiB available disk,
and no competing Xcode build, compiler, model, or Epistemos process. Exactly
one serial `xcodebuild` ran.

The selected test passed with zero failures and zero skips:

- result:
  `build/xcode-results/2026-07-14-free-v1-june-leaf-boundary-green2-16gib.xcresult`;
- result Info.plist SHA-256:
  `a9891156766ecce8ca73bf3be8213cca91b0cb9cb9dc77c676d6e11453d0c443`;
- log:
  `build/xcode-results/2026-07-14-free-v1-june-leaf-boundary-green2-16gib.log`,
  SHA-256
  `3327ba08427404852535f18f76b757444849edecbb6e07f9625ba734de3e2577`,
  394753 bytes;
- direct `xcresulttool` summary: result `Passed`, one passed, zero failed,
  zero skipped, total one;
- selected-test duration: 0.036 seconds;
- terminal marker: `TEST SUCCEEDED`.

The exact app Swift input list now has 627 entries and SHA-256
`f3a5d439f5046a41cce2beae48fa43281818393c7d3d95ece64f2a2ceb84cea8`.
All 33 mapped paid inputs are absent. KokoroCoreMLSynthesizer,
EpistemosSpeechSynthesizer, MarkEditCoreEditorView, QuickCaptureView,
TextCapturePipeline, SearchIndexService, and AgentCloudConsent remain exact
compiler inputs.

The sole current disposable selected-test app is
`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.
There is one current app and no archive under the active DerivedData root.
Its 40344-byte launcher is SHA-256
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
its 253295864-byte Debug runtime library is SHA-256
`4d4b32eac26ba38e1112890c8391025020a17e1d2b9af788b63bce5127a5709e`.
This test-injected Debug app is not a Release archive and is not distribution
evidence.

Exact raw-byte and external-symbol inspection of the app runtime reports zero
matches for all 33 excluded source/type names and all seven expected retained
type names. All 33 excluded paid files remain readable and nonempty; their
ordered path-and-file-hash manifest is SHA-256
`05d63719e2b6c57188817dba4ea6520e4f40f13b15c1c6718642bb2a7dd046ef`.

The complete retained audit is
`build/xcode-results/2026-07-14-free-v1-june-leaf-boundary-green2-16gib-artifact-audit.txt`,
SHA-256
`00acec7386f811af1022f29519212b6d12600946f188e145bed17265f3a5e9cb`,
9343 bytes.

The postcheck recorded 15466.94 MiB swap used, 57% free memory, zero throttled
pages, 662767532 KiB available disk, and no active Xcode build, compiler,
model, or Epistemos app process.

### Honest remaining debt and exact next action

This bounded compiler-input boundary is green. It does not prove normal-launch
UI hiding, a fresh Release archive, the finite runtime matrix, Kokoro audible
output, MarkEdit visual/native-popover behavior, PDF behavior, or App Store
distribution readiness. The accepted log retains two Rust future-
incompatibility package warnings, two Swift compiler warnings, twelve
duplicate-column migration messages, and one Metadata `dev_t` message.

Artifact inspection also found that the built main-app Info.plist still
declares legacy `INIntentsSupported` names including `AskAboutNotesIntent`,
`DailyBriefingIntent`, `SummarizeNoteIntent`, and `OpenMiniChatIntent`. The
already-green AppIntents extraction-data boundary does not prove this separate
legacy plist declaration inert or hidden.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is a fail-first legacy main-app intent-metadata boundary:
research the current official Apple contract for `INIntentsSupported`, map the
four stale paid/chat names to current source and generated metadata, add a
focused source/artifact assertion, remove only declarations that are invalid
for Free V1, and repeat the 16-GiB preflight, one-build deletion discipline,
serial selected test, and exact built-Info.plist audit. Do not start MarkEdit,
Epdoc/PDF, LumenLens, Reckoner, Sync, or another execution key before this
KEELSTONE metadata seam is proven.

## Same-Key Repair Continuation — Legacy SiriKit Metadata Boundary — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It corrects one false
main-app metadata declaration without removing or weakening the real modern
App Intents and App Shortcuts compiled into Free V1.

### Owner steer and official-contract result

The owner reiterated that Epistemos must remain one deeply integrated MAS app,
retain the fullest legitimate native capability set, continue unsigned local
development while paid signing is unavailable, and make performance part of
the acceptance bar. That steer is now recorded in the intent ledger and both
MAS canon mirrors.

Apple's current `INIntentsSupported` documentation defines the Info.plist key
as the names of `INIntent` subclasses an app handles directly:

`https://developer.apple.com/documentation/bundleresources/information-property-list/inintentssupported`

Current source inspection proved that the App Store target links
AppIntents.framework, not Intents.framework, and has no `.intentdefinition`,
SiriKit intent extension, `INIntentHandler`, `import Intents`, or directly
handled `INIntent` subclass. The entire 13-name `INIntentsSupported` array was
therefore a stale legacy declaration, not modern App Intents registration.

The four initially visible paid/chat contradictions were also mapped exactly:

- `AskAboutNotesIntent` and `DailyBriefingIntent` are whole-file excluded from
  the App Store target and invoke generative work;
- `SummarizeNoteIntent` is enclosed by `#if !EPISTEMOS_FREE_V1`;
- `OpenMiniChatIntent` has no current definition;
- all four were already absent from the generated Free V1 App Intents metadata.

### Expected red

The fail-first test parses the source plist and inspects the built test host:

`AppStoreKeelstoneLaneTests.freeV1AppPlistOmitsLegacySiriKitIntentHandlers()`

Before the production correction it failed exactly as intended:

- result:
  `build/xcode-results/2026-07-14-free-v1-legacy-sirikit-metadata-red-16gib.xcresult`;
- direct summary: result `Failed`, zero passed, one failed, zero skipped,
  total one;
- log:
  `build/xcode-results/2026-07-14-free-v1-legacy-sirikit-metadata-red-16gib.log`,
  SHA-256
  `d0142c20bed888f4fad752d9a95ebf9874a65959f21a5b507ef4c839137db63e`,
  393549 bytes;
- selected-test duration: 0.007 seconds;
- two recorded issues: the source dictionary and exact built Bundle.main each
  exposed all 13 stale names.

No product correction preceded the red result.

### Surgical correction

Only the complete `INIntentsSupported` key/array was removed from
`Epistemos-AppStore-Info.plist`. No AppIntent, AppShortcutsProvider,
capability-policy, target-membership, framework, entitlement, or other product
source changed for this seam. The corrected source plist is 3460 bytes with
SHA-256
`d01f4c1d4e844a9d2d3c776454f6f9bbde7fe1a41a2dbbe7fe1affb4b6501700`.
Plist lint, Swift parse, focused source search, and `git diff --check` passed.

### Accepted green and exact current app proof

The replacement preflight recorded branch `feat/goose-surface`, HEAD/origin/
handoff publication
`668b52cfb43721de95db102260d9f327ae24e13e`, 312 dirty entries, 15497.62 MiB
swap used, 59% free memory, zero throttled pages, 618382968 KiB available disk,
and no competing Xcode, compiler, model, or Epistemos process. The sole stale
red app was deleted before one serial selected-test build; no archive existed.

The selected test passed:

- result:
  `build/xcode-results/2026-07-14-free-v1-legacy-sirikit-metadata-green-16gib.xcresult`;
- result Info.plist SHA-256:
  `d6f09c8e2904e72ae9bcb5c38a8bf59ce186cd04fbd5c4749193b7aed984cd2b`;
- direct summary: result `Passed`, one passed, zero failed, zero skipped,
  total one;
- log:
  `build/xcode-results/2026-07-14-free-v1-legacy-sirikit-metadata-green-16gib.log`,
  SHA-256
  `d750621b724b29f4335a52a87c10c03206fc85c6aa4f7694493da2c8f3d9028d`,
  390416 bytes;
- selected-test duration: 0.001 seconds;
- terminal marker: `TEST SUCCEEDED`.

The exact current built Info.plist is 4092 bytes with SHA-256
`7811e2d8a9eeec7e516dda4fbfc4017e2db9879fd764cefb1fcbb142a3bad5bf`.
Direct lookup proves `INIntentsSupported` absent from both source and built
plists. The app remains `com.epistemos.appstore`, version/build `1.0.0 (1)`.

The exact current generated
`Metadata.appintents/extract.actionsdata` is 36893 bytes with SHA-256
`e122bbb1ff9b5608518da454b65dd0de932c29f2007ba23152f40935552b96f0`.
Its parsed current shape is the approved deterministic Free V1 whitelist:

- 13 actions: ArchiveNoteIntent, CaptureBrainDumpIntent, CreateJournalIntent,
  CreateNoteIntent, DeleteNoteIntent, MoveNoteToFolderIntent,
  NotePreviewSnippet, OpenPanelIntent, OpenVaultFileIntent,
  QuickCaptureIntent, SearchDocumentsIntent, SearchJournalIntent, and
  SystemSearchIntent;
- 6 entities and the corresponding 6 queries;
- zero enums;
- 4 auto shortcuts in order: CreateNoteIntent, SystemSearchIntent,
  QuickCaptureIntent, and CaptureBrainDumpIntent;
- empty assistantIntents and assistantEntities;
- zero exact occurrences of AskAboutNotesIntent, DailyBriefingIntent,
  SummarizeNoteIntent, or OpenMiniChatIntent.

This build's generated-metadata hash differs from the prior App Intents leg,
so no cross-build byte-identity claim is made. The exact current parsed shape
is proven against the exact current app.

The main-app Swift input list remains 627 entries with SHA-256
`f3a5d439f5046a41cce2beae48fa43281818393c7d3d95ece64f2a2ceb84cea8`.
There is exactly one current app, no archive, and no `.appex`. The launcher and
Debug runtime identities remain respectively:

- 40344 bytes, SHA-256
  `54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
- 253295864 bytes, SHA-256
  `4d4b32eac26ba38e1112890c8391025020a17e1d2b9af788b63bce5127a5709e`.

The complete retained audit is
`build/xcode-results/2026-07-14-free-v1-legacy-sirikit-metadata-green-16gib-artifact-audit.txt`,
SHA-256
`c3b2a6fbed861e44833ff32cbac74fa57b548fc5ec57a383e3647ce1927d5eb2`,
8856 bytes.

### Honest remaining debt and exact next action

This bounded metadata seam is green. It does not prove a normal launch,
manual Shortcuts/Siri invocation, a fresh Release archive, signed distribution,
the finite runtime matrix, Kokoro audible output, MarkEdit visual/native-
popover behavior, PDF behavior, or repeated zero-fail closeout.

The current built plist still carries privacy copy for on-device meeting/chat
transcription even though Free V1 admits owner-invoked system dictation and
explicit owned voice-note/meeting audio, but no app-owned/background speech
recognition, chat, provider, or second model. The green log also retains four
warning lines, twelve duplicate-column migration messages, and one Metadata
`dev_t` message. A Homebrew quarantine Swift frontend appeared only after the
accepted build completed; it must be absent before any next build.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is a read-first Free V1 privacy-metadata boundary: map
`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, the
audio-input entitlement, Speech/AVFoundation imports, actual compiled capture
paths, and system-dictation behavior against current official Apple contracts.
Add a fail-first source/built-plist test, correct only demonstrably stale or
misleading metadata while preserving explicit voice-note/meeting recording,
then repeat the 16-GiB preflight, stale-app deletion, one serial selected test,
and exact current plist/artifact audit. Do not start MarkEdit, Epdoc/PDF,
LumenLens, Reckoner, Sync, or another execution key first.

## Same-Key Repair Continuation — Free V1 Privacy Metadata — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It corrects the App Store
privacy declaration to describe only the live, explicit Meeting transcription
organ. It does not remove native speech capability, weaken the audio-input
entitlement, or claim the separately broken Quick Capture Dictate control.

### Owner intent and official contract

The owner requires one deeply integrated, high-performance MAS app with the
fullest legitimate public native capability set, while Free V1 keeps June,
chat, agents, providers, general models, Browser, and ResearchHub hidden and
uncompiled. Kokoro remains the sole bundled/app-owned model exception. Missing
paid signing must not block source, deterministic tests, or unsigned local
build evidence, but distribution-signature and signed-entitlement proof remain
deferred.

Apple's current Speech documentation distinguishes the server-oriented
`SFSpeechRecognizer` authorization path from `SpeechAnalyzer` transcriber
modules, and documents `NSSpeechRecognitionUsageDescription` as the explanation
for sending speech data to Apple's recognition servers:

- `https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition`
- `https://developer.apple.com/documentation/bundleresources/information-property-list/nsspeechrecognitionusagedescription`
- `https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.microphone`

Current source inspection proved that `EpistemosSpeechAnalyzer.startLive()`
requests microphone access only after an explicit owner action, creates
`SpeechTranscriber`, `SpeechAnalyzer`, and a lazy audio engine, and contains no
executable `SFSpeechRecognizer` call. Meeting has the real mounted Start/Stop
UI. Quick Capture's visible Dictate button instead reaches fail-closed
`AudioRecorder` and `AudioTranscriber` stubs in `UnavailableAudioCapture.swift`;
it is a separate App Completeness blocker, not a basis for broader privacy copy.

### Expected red

The fail-first test is:

`AppStoreKeelstoneLaneTests.freeV1PrivacyMetadataMatchesExplicitMeetingTranscription()`

Before the production correction it failed exactly as intended:

- result:
  `build/xcode-results/2026-07-14-free-v1-privacy-metadata-red-16gib.xcresult`;
- direct summary: result `Failed`, zero passed, one failed, zero skipped,
  total one;
- result Info.plist: 715 bytes, SHA-256
  `6615d8290d619ce012f9a90f61fae646db3609d71c5d4e496fde2e86e6da001e`;
- log:
  `build/xcode-results/2026-07-14-free-v1-privacy-metadata-red-16gib.log`,
  394432 bytes, SHA-256
  `1b54e460eba61aaf73a7ad5369c58398e39a9296196a912b8c555f2e267236c7`;
- selected-test duration: 0.010 seconds; suite duration: 0.018 seconds;
- exact expected red: four issues because source and built microphone copy
  both named Quick Capture, while source and built speech-recognition copy
  both named notes and chats.

The same red test already proved the audio-input entitlement remained true,
the active analyzer used `SpeechTranscriber`, microphone permission was lazy,
and no executable `SFSpeechRecognizer` call existed. No production plist
correction preceded this result.

### Surgical correction

Only `Epistemos-AppStore-Info.plist` changed for the product correction:

- `NSMicrophoneUsageDescription` now reads exactly:
  `Epistemos uses the microphone only when you start Meeting transcription, to turn speech into a live transcript on your Mac.`
- `NSSpeechRecognitionUsageDescription` was removed.

No Meeting, speech analyzer, live voice service, Quick Capture, framework,
project, entitlement, target-membership, Kokoro, or audio behavior changed.
The corrected source plist is 3340 bytes with SHA-256
`b03516b0d9684d1e1cf303a914a7b7b3bcc485a3e0691941c5779bbc6f7f281e`.
The source App Store entitlements are 606 bytes with SHA-256
`0c8630d8b59aa24547a0db4e16573509d35a82b3b63b504107e5c0220b065e15`.
Plist lint, Swift parse, focused source inspection, and `git diff --check`
passed before the replacement build.

### Accepted green and exact current artifact

The accepted-green replacement preflight recorded branch
`feat/goose-surface`, local HEAD, origin, and handoff publication all at
`668b52cfb43721de95db102260d9f327ae24e13e`, 279 dirty entries, 15880.19 MiB
swap used, 54% free memory, zero throttled pages, 538484192 KiB available disk,
and no competing Xcode build, compiler, model, or Epistemos process. The stale
red app was deleted before exactly one serial selected-test build; no archive
existed.

The focused replacement passed:

- result:
  `build/xcode-results/2026-07-14-free-v1-privacy-metadata-green-16gib.xcresult`;
- direct summary: result `Passed`, one passed, zero failed, zero skipped,
  total one;
- result Info.plist: 715 bytes, SHA-256
  `9bc55f235bb8ad763cc700dad43d3f68528bbd7c2aba28a0b01f1c67fb91d0e6`;
- log:
  `build/xcode-results/2026-07-14-free-v1-privacy-metadata-green-16gib.log`,
  390530 bytes, SHA-256
  `b16d9b199ca91772f0050422f702424ba9e509257d108dd567dd11f1b53dbb23`;
- selected-test duration: 0.001 seconds; suite duration: 0.002 seconds;
- terminal marker: `TEST SUCCEEDED`.

The sole current selected-test app is
`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`.
There is exactly one app, zero archives, and zero `.appex` products under the
active root. The built Info.plist is 3972 bytes with SHA-256
`116cfce9887925f097299fc0a7b4854861a0552c6c54f259af10bef16ea84906`;
its microphone copy exactly matches source and its speech-recognition key is
absent. The app remains `com.epistemos.appstore`, version/build `1.0.0 (1)`.

The exact runtime still links Speech, AVFoundation, and AVFAudio. Undefined-
symbol and printable-string inspection found zero `SFSpeechRecognizer` or
`SFSpeechRecognitionRequest` matches. The launcher is 40344 bytes with SHA-256
`54798be7b23fc6cccf66228dc9b1266d6e33f1bd6309a190d3ee46e84a5b22b8`;
the 253295864-byte Debug runtime dylib SHA-256 is
`4d4b32eac26ba38e1112890c8391025020a17e1d2b9af788b63bce5127a5709e`.

The exact 36893-byte generated App Intents metadata SHA-256 is
`a2f0263aabe654f72b3a6708a47010b278210858058abb68769387ef0879176f`.
It still proves the approved 13 actions, 6 entities, 6 queries, zero enums,
four approved auto shortcuts, empty assistant metadata, and zero occurrences
of the four paid/chat intent names. The main-app Swift list remains 627 entries,
48565 bytes, SHA-256
`f3a5d439f5046a41cce2beae48fa43281818393c7d3d95ece64f2a2ceb84cea8`.

The complete artifact audit is
`build/xcode-results/2026-07-14-free-v1-privacy-metadata-green-16gib-artifact-audit.txt`,
11278 bytes, SHA-256
`4cc4b915a07dd5ecf38dd47112bdef3cd06cb55f47203eaae5a7652cab72320a`.

The postcheck recorded 15880.19 MiB swap used, 54% free memory, zero
throttled pages, 526875152 KiB available disk, and no competing process. The
test host bootstrapped only to run the focused assertion; there was no normal
interactive launch, and the test did not call `startLive()`, request microphone
access, open an audio engine, load speech/model bytes, contact a provider,
access a secret, or touch the owner's real vault or removable media.

### Honest remaining debt and exact next action

This bounded privacy seam is green. It does not prove signed entitlements,
distribution-time TCC behavior, permission denial/recovery, real Meeting
transcription, cancellation/teardown, privacy labels, Quick Capture voice, a
fresh Release archive, the finite runtime matrix, Kokoro audible output, or
repeated zero-fail closeout. The accepted log retains two Rust future-
compatibility warnings, two Swift warnings, twelve duplicate-column migration
messages, and one Metadata `dev_t` message.

The overall verdict remains:

**INCOMPLETE — RUNTIME MATRIX REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is a fail-first Quick Capture voice-honesty and capture-
ownership boundary under this same key. Map the visible Dictate action and the
Settings voice-support claim to their fail-closed stubs; define a non-
preemptive, owner-scoped capture lease for the shared `LiveVoiceInputService`
before any real Quick Capture wiring; and prove Meeting or another Quick
Capture cannot be stopped, cleared, or stolen. Do not resurrect
`SFSpeechRecognizer`, a subprocess, a sidecar, or a second audio authority. If
the ownership contract cannot be implemented and evidenced within this gate,
hide or truthfully disable the dead control for Free V1 rather than shipping an
overclaim. Pass the strict-below-16,384-MiB preflight and one-current-build
discipline before any next build. Do not start MarkEdit, Epdoc/PDF, LumenLens,
Reckoner, Sync, or another canonical execution key first.

## Same-Key Repair Continuation — Quick Capture Exact-Owner Voice Lease — 2026-07-14

This leg remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It does not start a new
feature key or the later Epdoc/MarkEdit/PDF/native-capability program.

### Expected red retained

The fail-first test is:

`AppStoreKeelstoneLaneTests.freeV1QuickCaptureDictationUsesScopedNativeVoiceCapture()`

It completed with the intended red result before the implementation edits:

- result:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-lease-red-16gib.xcresult`;
- direct summary: result `Failed`, zero passed, one failed, zero skipped,
  total one;
- selected test name: `free V1 Quick Capture dictation is real and cannot
  preempt another capture owner`;
- exact contract result: 13 issues covering the two removed-audio stubs, old
  toggle, absent real button/purpose, absent lease lifecycle, absent analyzer
  session token/stop, and cached-window global stop;
- result Info.plist: 715 bytes, SHA-256
  `15155e26dec959ca0613b91d7d604a84b0184e1700bfa75cee734f0dcfecd46e`;
- result bundle size: 1548 KiB;
- log:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-lease-red-16gib.log`,
  698805 bytes, SHA-256
  `31f20c29a1d92fa03a83b38a7e983d370b1007b69c3d05cc49ad086c4c15c559`;
- selected-test duration: 0.067 seconds; suite duration: 0.067 seconds;
  run duration: 0.068 seconds;
- terminal marker: `TEST FAILED`.

No normal app launch, microphone request, audio operation, model load,
provider request, secret access, external-drive access, or private-data access
ran. The test host only read source contracts after the test build completed.

The sole retained app remains:

`/private/tmp/Epistemos-FreeV1NoEmbedding-Red-16GiB/Build/Products/Debug/Epistemos.app`

There is one app and zero archives under the active build root. This app is the
red, pre-implementation artifact and must not be used as evidence for the
current source. Delete it immediately before the one replacement green build.

### In-flight surgical implementation — not compiled or behavior-proven

Under the previously passing resource gate, the current working source was
advanced toward the red contract:

- `LiveVoiceInputService` now defines typed capture purposes, UUID-bearing
  leases, an exact-owner registry, typed started/busy/permission-denied/
  unavailable/failed/cancelled results, scoped start/stop/teardown/consume,
  and partial-transcript promotion on explicit stop.
- `EpistemosSpeechAnalyzer` now carries a separate session ID through start,
  stop, deferred cleanup, permission/model/format/prepare awaits, result and
  progress tasks, stream termination, configuration change, permission
  monitoring, rearm, and per-session dropped-buffer tracking. The real-time
  audio tap still captures no actor-isolated `self`.
- `VoiceInputButton` now stores its admitted lease in SwiftUI state, receives a
  purpose, ignores non-owner shared observations, drains final text before
  teardown, and always attempts scoped teardown on disappearance.
- Quick Capture removes the fail-closed `AudioRecorder`/`AudioTranscriber`
  route and uses `VoiceInputButton` with `.quickCapture`, showing partial
  listening state and appending bounded final text to the draft.
- Meeting owns a per-attempt `.meeting` lease, maps typed admission failures to
  its own UI state, guards shared transcript reads by ownership, and uses
  scoped stop/consume/teardown.
- Closing the cached Meeting utility panel posts a panel-only lifecycle signal;
  only that hosted Meeting view reacts. The separate embedded Landing Meeting
  view cannot be stopped by closing the utility panel.
- The microphone purpose now truthfully names both explicit routes:
  `Epistemos uses the microphone only when you start Meeting transcription or
  Dictate in Quick Capture.` The server-oriented speech-recognition key remains
  absent.
- A deterministic pure registry test now covers exact-owner admission,
  idempotent re-admission, busy rejection, non-owner release rejection, owner
  release, and subsequent acquisition. Related source guards and Meeting fakes
  were migrated.

These statements describe source shape only. No Swift parse, compile, test,
build, archive, app launch, permission request, or audio operation has run
against the implementation. Current source hashes are retained in the session
record; they are not passing evidence.

### Mandatory resource stop

The replacement verification preflight recorded:

- branch `feat/goose-surface`;
- local HEAD, origin, and handoff publication all
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- 285 default dirty entries and 319 with all untracked files;
- swap: 17163.44 MiB used of 18432 MiB;
- free-memory percentage: 64% on the first sample and 63% on the confirmation
  sample;
- pages throttled: zero;
- available disk: 520385952 KiB;
- no competing Xcode build, Swift/Clang compiler, model runtime, or Epistemos
  process.

Swap exceeds the owner's strict-below-16384-MiB ceiling by 779.44 MiB. A
confirmation sample remained unchanged. Therefore no compiler, test, build,
archive, app, model, microphone, or signing operation began, and no further
product-source edit followed the failed gate. `git diff --check` passed before
the stop.

### Verification debt and exact safe resumption boundary

Before the replacement build, the in-flight source still requires read-first
closure of these unproven items:

1. Re-run the full resource preflight and proceed only when swap is strictly
   below 16384 MiB and every other threshold passes.
2. Re-read the changed regions and correct any static/type issues without
   broad refactoring. The first known diff-review item is Meeting close
   durability: stop and owner-drain the final promoted partial before flushing
   the crash-recovery draft, so the last spoken fragment cannot remain only in
   volatile view state.
3. Add deterministic coverage for denied/cancelled admission, close while
   preparing, non-owner stop/consume/teardown, stale analyzer termination, and
   Meeting-versus-Quick-Capture non-preemption. The pure registry test alone is
   not sufficient behavior proof.
4. Add crash-safe Quick Capture draft restoration before claiming zero-loss
   voice/typed capture.
5. Re-run plist lint, Swift parse, focused source guards, and diff checks.
6. Delete the retained red app immediately before exactly one serial
   replacement build. Run the scoped Quick Capture contract plus the privacy,
   lease-registry, Meeting capture, and voice regression batch; do not run
   competing builds.
7. Audit the exact replacement app's source/built privacy copy, audio-input
   entitlement, App Intents inventory, framework/symbol surface, product count,
   path, hashes, and result/log identities. Do not launch or request the
   microphone unless the artifact gates and a later explicit finite runtime
   leg permit it.

Read-only official Apple research for the later MAS capability canon is
complete for App Intents/Shortcuts, Core Spotlight, WidgetKit, EventKit,
accessibility, SpeechAnalyzer/audio notes, images/drawing, PDFKit/Quick Look,
sharing/services/drag-drop, sandboxed documents, notifications, and
performance instrumentation. It is not yet promoted into the active canon or
implemented; that waits for this same-key repair and KEELSTONE ordering. The
research confirms that source, unit/UI work, unsigned builds, PDF/editor work,
and performance hardening can continue without the paid signing account, while
installed-system discovery, TCC, account-bound capabilities, signed
entitlements, and distribution evidence remain explicitly deferred.

The overall verdict remains:

**INCOMPLETE — RESOURCE-GATED QUICK CAPTURE REPAIR IN PROGRESS — NOT RELEASE READY**

The exact next action is to resume at item 1 above after the resource reset. Do
not raise the ceiling, delete the red artifact early, start another build,
launch the app, access signing/accounts/secrets, or begin another canonical
execution key.

## Owner Resource Override — Continue Without The Swap Stop — 2026-07-14

The owner's newer explicit instruction is:

> “please jsut contieu do nto worry about the limit stop worry about the limit
> do not stop”

This dated steer supersedes only the swap-ceiling stop condition in the
immediately preceding section. Swap remains recorded as diagnostic evidence,
but exceeding 16,384 MiB no longer stops this same-key continuation. The
one-current-build rule, serial Xcode execution, sufficient disk, zero
throttled pages, no competing Xcode/compiler/model/Epistemos process, exact
artifact identity, and honest proof boundaries remain active.

No behavior claim follows from this override. The next authorized action is to
finish the recorded durability and deterministic-test debts, pass static
checks, delete the retained red app immediately before the single replacement
build, and run the focused App Store test batch. A normal app launch,
microphone/audio operation, model/provider/secret/account access, archive, new
execution key, or broad feature implementation is not implied.

## Same-Key Repair Continuation — Quick Capture Focused Verification — 2026-07-14

This continuation remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. Repository identity was
`feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`.

After the owner resource override, the same 13-selector unsigned Debug test
batch was run serially. The retained convergence chain includes ordinary
compile failures, one incomplete interrupted bundle, and two source-guard red
runs. Intermediate invocations originally targeted
`2026-07-14-free-v1-quick-capture-green-current.xcresult` and were renamed to
their retained failure identities after each leg.

The artifact named
`2026-07-14-free-v1-source-changed-during-build-red-compile` is failure
evidence only. Its xcresult does not report an Xcode source-mutation error; it
reports two Swift compiler errors, both `Cannot find
'recoverInterruptedDictation' in scope`, in `QuickCaptureView.swift`. Build
status was failed and zero tests ran. Retained identities:

- `build/xcode-results/2026-07-14-free-v1-source-changed-during-build-red-compile.log`,
  709085 bytes, SHA-256
  `8b65be6c0c65648af2f0b9868023c53571dec6d88199e0ec8ac3d37a8dca7186`;
- matching xcresult `Info.plist`, 715 bytes, SHA-256
  `ae4881f03adf9ea38df691253b20558972399ee56d08b341a2c9c771cc6f890e`.

The next retained source-guard legs compiled and executed all 13 selectors:

- `2026-07-14-free-v1-focused-source-guards-red-tests`: 11 passed, two
  failed, zero skipped, with 15 source-contract issues;
- `2026-07-14-free-v1-source-guards-round2-red-tests`: 12 passed, one failed,
  zero skipped, with five stale Quick Capture restore/scheduling assertions.

After reconciling those assertions to the current exact-owner draft contract,
the fresh R3 command completed successfully:

- result:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r3.xcresult`;
- direct summary: `Passed`, 13 total, 13 passed, zero failed, zero skipped,
  zero expected failures, arm64 macOS 26.3.1;
- result `Info.plist`: 715 bytes, SHA-256
  `b3bf21a502bde2e4e90c2b585cdf2373a9c84056b96d71018957482ea8c9eba7`;
- log:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r3.log`,
  830197 bytes, SHA-256
  `1872065330db8eb2edf41523d07255329dd4b7abd6ac7a2fd57bd9e8794d094f`;
- terminal marker: `TEST SUCCEEDED`.

The sole current app product is:

`/private/tmp/Epistemos-FreeV1-QuickCapture-Focused-Current-R3-2026-07-14/Build/Products/Debug/Epistemos.app`

It is a 463876-KiB arm64 Debug/XCTest product. Its executable SHA-256 is
`d0cb031cbc6c378a3df888ed91e9c4dfa9ab1c65424c3272b971acff2ee90eaf`.
It is linker-ad-hoc signed with no TeamIdentifier and is not a distributable
Release archive. No current xcarchive is retained.

The test host used its disposable test-runtime container, skipped owner-vault
bookmark restoration, and logged the Free V1 model boundary as
`June=DISABLED, local-gguf-runtime=DISABLED, cloud-models=OFF`. This focused
green proves only the selected compile and deterministic/source-contract
batch. It does not prove a fresh Release archive, current artifact gates,
normal owner-visible launch, microphone/TCC behavior, real transcription,
audible Kokoro output, the finite runtime matrix, distribution signing, or
repeated zero-fail closeout.

The overall verdict remains:

**INCOMPLETE — FOCUSED QUICK CAPTURE TEST BATCH GREEN; RELEASE/ARTIFACT/RUNTIME
EVIDENCE STILL OUTSTANDING — NOT RELEASE READY**

## Same-Key Repair Continuation — Expanded Quick Capture Focused Verification — 2026-07-14

This continuation remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` and advances only the
Quick Capture / Meeting voice-capture evidence leg. It does not start MarkEdit,
Epdoc/PDF, LumenLens, Reckoner, Sync, or another canonical execution key.

Before the run, the resource snapshot recorded:

- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- 289 default dirty entries;
- swap: 345.38 MiB used of 1024 MiB;
- free-memory percentage: 73%;
- pages throttled: zero;
- available disk on `/private/tmp`: 527906288 KiB;
- no competing Xcode build, Swift/Clang compiler, model runtime, or Epistemos
  app process.

The prior R3 focused build root and app product were deleted before the new
run, along with any stale R4 build/result path. The new focused R4 command was
then run serially with unsigned Debug settings and 16 selected tests: the prior
13-selector batch plus:

- `tearDownDuringFinalizeStillCommitsSavedStateAndRetiresDraft()`;
- `quickCaptureDraftSessionClaimRejectsSupersededOwner()`;
- `quickCapturePresentationRegistryIsExactOwnerScoped()`.

The R4 result is green:

- result:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r4.xcresult`;
- direct summary: `Passed`, 16 total, 16 passed, zero failed, zero skipped,
  zero expected failures, arm64 macOS 26.3.1;
- result `Info.plist`: 715 bytes, SHA-256
  `60508d913c927bf60c808921a26e7d23c5cf224e82cab88261be1287cebafa4a`;
- result bundle size: 628 KiB;
- log:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r4.log`,
  831352 bytes, SHA-256
  `16f39eb268f15fdd01b41da1c6c0c927c4698342142f5dcedbbbe9a75f9b075e`;
- terminal marker: `TEST SUCCEEDED`.

The sole current app product for this focused leg is:

`/private/tmp/Epistemos-FreeV1-QuickCapture-Focused-Current-R4-2026-07-14/Build/Products/Debug/Epistemos.app`

It is a 463900-KiB arm64 Debug/XCTest product. Its executable SHA-256 is
`88009b534eb0dcfe895f638c3be67def767021c85e9375f0666fa06ce1cbf78a`.
It is linker-ad-hoc signed with no TeamIdentifier and is not a distributable
Release archive. `codesign -dv --verbose=4` reports `Signature=adhoc`,
`TeamIdentifier=not set`, and `Info.plist=not bound`.

The R4 test host used its disposable test-runtime container, skipped
owner-vault bookmark restoration, and logged the Free V1 model boundary as
`June=DISABLED, local-gguf-runtime=DISABLED, cloud-models=OFF`. The accepted
log still includes twelve duplicate-column migration messages and one Metadata
`dev_t` message.

The postcheck recorded 5269.19 MiB swap used of 6144 MiB, 52% free memory,
zero throttled pages, 522759588 KiB available disk on `/private/tmp`, and no
Xcode/compiler/model/Epistemos runtime left behind. An unrelated `rg` search
was present and should be stopped before any heavier archive leg.

This green proves only the selected compile and deterministic/source-contract
batch. It does not prove a fresh Release archive, archive artifact gates,
normal owner-visible launch, microphone/TCC behavior, real transcription,
audible Kokoro output, the finite runtime matrix, distribution signing, or
repeated zero-fail closeout.

The overall verdict remains:

**INCOMPLETE — EXPANDED QUICK CAPTURE FOCUSED TEST BATCH GREEN; RELEASE/
ARTIFACT/RUNTIME EVIDENCE STILL OUTSTANDING — NOT RELEASE READY**

## Same-Key Repair Continuation — App Intents Copy Fix, R5 Focused Verification, And Archive Artifact Red — 2026-07-14

This continuation remains under
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`. It does not start another
canonical execution key and it does not begin MarkEdit, Epdoc/PDF, LumenLens,
Reckoner, Sync, StoreKit/payment, Browser, ResearchHub, June, chat, or any
paid AI feature work.

After R4, a first fresh Release archive was produced and locally ad-hoc signed
for sandbox artifact evidence only. The scripted archive gates passed, but a
manual App Intents metadata scan found stale Free V1 copy in
`Metadata.appintents/extract.actionsdata`:

`Searches across all your Epistemos notes, research, and chat history.`

That copy contradicted the owner’s Free V1 boundary that Browser, ResearchHub,
chat, June, and model-provider surfaces must be hidden from the V1 release. The
archive was therefore invalidated before launch/runtime evidence. No app launch,
model/provider request, secret access, microphone operation, audio operation, or
finite runtime matrix began from that invalidated archive.

The source correction was deliberately narrow:

- `Epistemos/Intents/Schemas/SystemSearchIntent.swift` now describes System
  Search as local notes/documents search instead of notes/research/chat search.
- `EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests.swift` now
  asserts the App Intent source copy includes
  `Searches across your local Epistemos notes and documents.` and excludes
  `chat history` and `notes, research`.

Before the R5 focused verification, the resource snapshot recorded:

- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- 290 default dirty entries;
- swap: 1984.31 MiB used of 3072 MiB;
- free-memory percentage: 75%;
- pages throttled: zero;
- available disk on `/private/tmp`: 525663768 KiB;
- no competing Xcode build, Swift/Clang compiler, model runtime, or Epistemos
  app process.

The invalidated archive/derived-data path and stale R5 test product path were
deleted before the new focused run. R5 then ran the R4 16-selector focused
batch plus
`AppStoreKeelstoneLaneTests.freeV1AppIntentsCompileGraphUsesExactWhitelist()`.

The R5 result is green:

- result:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r5.xcresult`;
- direct summary: `Passed`, 17 total, 17 passed, zero failed, zero skipped,
  zero expected failures, arm64 macOS 26.3.1;
- result `Info.plist`: SHA-256
  `0b2975f85653c9ba5d06fe63fe8d64b5719413916df8447a4d3118831be59f81`;
- log:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r5.log`,
  831566 bytes, SHA-256
  `45c45a19a2ad0ad662a6b4e12aaca7a089eb3684630302c3c11ad2a99c1dca51`;
- terminal marker: `TEST SUCCEEDED`.

Before the corrected Release archive, the resource snapshot recorded:

- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- 290 default dirty entries;
- swap: 1968.31 MiB used of 3072 MiB;
- free-memory percentage: 75%;
- pages throttled: zero;
- available disk on `/private/tmp`: 525206924 KiB;
- no competing Xcode build, Swift/Clang compiler, model runtime, or Epistemos
  app process.

The R5 Debug app product and corrected archive/derived-data paths were deleted
before the archive command. The corrected archive command then succeeded:

- archive:
  `build/appstore-release-archive-2026-07-14-keelstone-current.xcarchive`;
- app:
  `build/appstore-release-archive-2026-07-14-keelstone-current.xcarchive/Products/Applications/Epistemos.app`;
- archive log:
  `build/xcode-results/2026-07-14-keelstone-release-archive-current-r2.log`,
  1335638 bytes, SHA-256
  `35150361540fe958dd770f45209650dd643e07039d13e068bcd820e44cf7824e`;
- archive `ApplicationProperties:ApplicationPath`: `Applications/Epistemos.app`;
- archive `SchemeName`: `Epistemos-AppStore`;
- terminal marker: `** ARCHIVE SUCCEEDED **`.

The corrected archive app was locally ad-hoc signed for sandbox artifact
evidence only. `codesign --verify --deep --strict --verbose=2` passed. The
captured signature report is
`build/xcode-results/2026-07-14-keelstone-codesign-current-r2.txt`, SHA-256
`b3e5b4d5b92ac8f453ebaf6579759b5487f6d005f8f203c74f1daef8224fc518`.
The captured entitlement plist is
`build/xcode-results/2026-07-14-keelstone-entitlements-current-r2.plist`,
SHA-256
`774e5b9308541a7576c531fe50f309c2eea84c620b92fd3d0c54b8195faf83ca`.
The post-sign executable SHA-256 is
`18d5fe531005a62c8243cedb7d8c2b648162c1df5d919c7730c13698d7e8aa10`.

The scripted artifact gates passed on the corrected signed archive:

- release gate:
  `build/xcode-results/2026-07-14-keelstone-release-gate-current-r2.log`,
  3256 bytes, SHA-256
  `5f924efcd7e1808fa11a5ed480ba10d01cf90990f1d70c4791fbf7e4a97d1957`;
- App Store bundle scan:
  `build/xcode-results/2026-07-14-keelstone-appstore-bundle-scan-current-r2.log`,
  671 bytes, SHA-256
  `bea416fc4fcdd1c398007bafc55840829d37d97aff0808de0ea0117f26bf78d8`;
- scripted gate markers included App Sandbox present, no `JuneWeb`, no model
  manifest, no agent skills, no local inference runtime, no `agent_core`, no
  `omega_mcp`, no prohibited runtime strings, no retired-lane strings, no
  1Code strings, no prohibited linkage, and MAS-only gate passed.

The stricter manual artifact scan is:

`build/xcode-results/2026-07-14-keelstone-explicit-artifact-scan-current-r2.txt`

It is 57247 bytes, SHA-256
`a0663845095f17858d04fb28f5da1ceb33b8de324df02d274041bc7c147573d0`.
It verified:

- bundle ID `com.epistemos.appstore`;
- executable `Epistemos`;
- microphone usage copy:
  `Epistemos uses the microphone only when you start Meeting transcription or Dictate in Quick Capture.`;
- `NSSpeechRecognitionUsageDescription` absent;
- `Info.plist` and `PrivacyInfo.xcprivacy` lint OK;
- no forbidden packaged `JuneWeb`, `model_manifest.json`, `DefaultSkills`,
  `llama.framework`, `libagent_core.dylib`, or `libomega_mcp.dylib` resources;
- App Intents metadata now contains
  `Searches across your local Epistemos notes and documents.`;
- App Intents metadata no longer matches the prior stale
  `chat history` / `notes, research` copy;
- `otool -L` has no prohibited runtime linkage;
- packaged frameworks are only `libepistemos_shadow.dylib` and
  `libepistemos_core.dylib`;
- privacy manifest still declares no collected data and no tracking.

However, the same stricter manual scan is red for the owner’s newer Free V1
compile boundary. The signed executable still embeds paid/provider/browser/chat
surface strings and symbols including examples such as:

- `SessionBrowser`;
- `ComposerReferenceBrowser`;
- `_anthropicCodeExecutionEnabled`;
- `_openAIWebSearchEnabled`;
- `_openAICodeInterpreterEnabled`;
- `openAISignInTimeout`;
- `OpenAI response failed.`;
- `Anthropic account access could not be refreshed.`;
- `kimi-k2-turbo-preview`;
- `gemini-3.1-pro-preview`;
- `claude-sonnet-4-5`;
- `openai:gpt-5.5`;
- `Anthropic Skills`;
- `Browser is unavailable in this build.`;
- `The free V1 release has no June, model-provider, ResearchHub, or in-app Browser requests.`;
- `Settings, preferences, and chat history.`;
- `OpenAI and Anthropic models connected to MAS June.`

This red does not prove a runtime leak, request, launch, or secret access. It
does prove the current signed archive still compiles parked paid/provider/
browser/chat surfaces into the Free V1 executable. Under the owner’s
2026-07-14 steer that V1 should have no AI except Kokoro and that June,
Browser, ResearchHub, chat, model-provider, and paid AI surfaces should be
hidden and not compiled into the V1 release, this corrected archive remains
invalid for launch/runtime evidence.

The next exact action is source repair of the Free V1 compile boundary:
preserve the paid code for future editions, but compile-park the paid AI,
provider, chat, Browser, ResearchHub, and session-browser surfaces out of
`Epistemos-AppStore` while retaining Kokoro, Meeting, Quick Capture, local
notes/documents/search, vault/sync, PDF/import, Reckoner, and other Free V1
native surfaces. After that repair, rerun the focused source/build guard,
delete stale products, record a new resource preflight, produce exactly one
fresh corrected Release archive, ad-hoc sign that archive for sandbox artifact
evidence, and rerun both scripted gates plus this stricter executable/App
Intents scan before any launch/runtime matrix.

The overall verdict is now:

**INCOMPLETE — R5 FOCUSED QUICK CAPTURE/APP INTENTS TEST BATCH GREEN; SCRIPTED
ARCHIVE GATES GREEN; STRICT FREE V1 EXECUTABLE SURFACE SCAN RED; NO
LAUNCH/RUNTIME MATRIX STARTED; NOT RELEASE READY**

## 2026-07-14 — Free V1 compile-boundary repair follow-up after strict archive scan

After the strict archive scan found paid/provider/browser/chat strings compiled
into the Free V1 executable, the Free V1 compile boundary was repaired
surgically without deleting parked paid sources. The active source edits
included:

- `project.yml` and `Epistemos.xcodeproj/project.pbxproj`: exclude the paid
  session browser, skill evolution, session views, skills views, and chat
  reference/mention browser leaves from `Epistemos-AppStore` while retaining
  shared MarkEdit/text-rendering files used by Free V1;
- `Epistemos/Engine/LLMService.swift`: compile a Free V1 unavailable stub under
  `EPISTEMOS_FREE_V1` and keep the paid provider implementation behind the
  non-Free branch;
- `Epistemos/Engine/CloudProviderAuthService.swift`: compile a Free V1
  unavailable auth stub with no Keychain/provider implementation dependency;
- `Epistemos/State/InferenceState.swift`: compile provider sign-in/import
  helpers only outside Free V1;
- Rust staging scripts `build-syntax-core.sh`,
  `build-epistemos-code-index.sh`, and `build-substrate-rt.sh`: replace direct
  shared `build-rust` writes / unsafe `mktemp` suffix staging with temp-output
  plus lock-based atomic moves, after R8 exposed a `mktemp` collision in the
  syntax-core phase.

R8:

- build/test command reached the Rust build phase and failed before Swift
  source tests because `build-syntax-core.sh` attempted
  `mktemp ../build-rust/libsyntax_core.XXXXXX.a` and hit `File exists`;
- log:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r8.log`;
- verdict: build-script staging flake, not a Free V1 source compile failure.

R9 preflight was red only because a pre-existing `xcodebuild` from the
pre-crash session was still running on the same checkout. No second build was
started.

R10:

- the pre-existing build completed and `** TEST SUCCEEDED **`;
- selected zero tests because the Swift Testing filter spelling was stale, so
  this run is counted only as compile/build evidence;
- executable:
  `build/derived/free-v1-boundary-compile-r10/Build/Products/Debug/Epistemos.app/Contents/MacOS/Epistemos`;
- executable SHA-256:
  `acee6f87dc6d321077dfb095c6eea5d06d349daf9e327029b81eb752c0f313e8`;
- focused executable scan for the prior red terms was empty, SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

R11:

- clean resource preflight:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r11-preflight.txt`,
  SHA-256
  `29643883de59ccc03e4c8c635e7d251ff1e139966c0e6057f9dfc92cc970806d`;
- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty entries `303`;
- swap `1177.25M` to `1185.25M` used of `2048M` across the R11/R12
  preflights;
- free-memory percentage remained above the owner threshold;
- pages throttled remained `0`;
- no active Xcode/compiler/Epistemos runtime process was present.
- command exited `0` and compiled, but again selected zero tests due stale
  Swift Testing filter spelling;
- log SHA-256:
  `dc13db5091130f33b0691d70e49c6d1dfe2a7c55d8c8751e0897f3e2e13a4385`;
- xcresult JSON SHA-256:
  `60a17fc340927f73991c1039b5370d158dd039e4512d7901cbf13cf8cbf94f02`;
- debug executable SHA-256:
  `6f3c156a8a5840b51a6eb7b0e9e322d63275a94d2bd71b6fa76996fc6aa7afda`;
- focused executable scan for the prior red terms was empty, SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

R12 used the corrected Swift Testing filter spelling with function names ending
in `()`:

```bash
xcrun xcodebuild test \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -parallel-testing-enabled NO \
  -derivedDataPath /private/tmp/Epistemos-FreeV1-Boundary-Compile-R12 \
  -resultBundlePath build/xcode-results/2026-07-14-free-v1-boundary-compile-r12.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  '-only-testing:EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/freeV1ExcludesProviderBrandingAndLeafRuntimeSources()' \
  '-only-testing:EpistemosAppStoreKeelstoneTests/AppStoreKeelstoneLaneTests/freeV1ExcludesJuneQuickChatGooseAndLegacyAgentWorkspaceSources()' \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  -hideShellScriptEnvironment \
  -collect-test-diagnostics never
```

R12 evidence:

- clean resource preflight:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r12-preflight.txt`,
  SHA-256
  `a288603f67ba0c19eda96ae615012192c1a98e0cb9c2ca77470b93da454213d8`;
- log:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r12.log`,
  SHA-256
  `ab9f39f78da8e9d9604211da5d6e3e054ce7ff1c93ff8db74a4c1cf914c0e545`;
- xcresult JSON SHA-256:
  `fd9889c5642adc601f1cb5ed8d477e30ac5531927f5f8aaa56c35554057b80ba`;
- Swift Testing executed 2 tests in 1 suite, both passed:
  - `free V1 excludes provider branding and leaf runtimes without deleting paid source`;
  - `free V1 excludes June QuickChat Goose and legacy agent workspace sources without deleting paid source`;
- debug executable:
  `/private/tmp/Epistemos-FreeV1-Boundary-Compile-R12/Build/Products/Debug/Epistemos.app/Contents/MacOS/Epistemos`;
- debug executable SHA-256:
  `5f941e1627f1015374943d8bee57da33866a299005ff92e281bacc93ef205452`;
- focused executable scan for the prior red paid/provider/browser/chat terms
  was empty:
  `build/xcode-results/2026-07-14-free-v1-boundary-r12-executable-scan.txt`,
  SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

R12 proves the narrow source guard and debug compile boundary are green. It
does not prove Release archive artifact readiness, signing, bundle gates, or
runtime behavior.

The next exact action is to delete stale Epistemos app products/archives for
the active leg, record a fresh resource preflight, produce exactly one fresh
`Epistemos-AppStore` Release archive from the repaired source, ad-hoc sign that
archive for sandbox artifact evidence, and rerun scripted gates plus the
stricter executable/App Intents scan before any launch/runtime matrix.

Current verdict:

**INCOMPLETE — FREE V1 COMPILE-BOUNDARY SOURCE GUARDS GREEN IN R12; DEBUG
EXECUTABLE PRIOR-RED-TERM SCAN EMPTY; RELEASE ARCHIVE AND ARTIFACT GATES STILL
PENDING; NO LAUNCH/RUNTIME MATRIX STARTED; NOT RELEASE READY**

### 2026-07-14 R13–R15 Free V1 explicit artifact-scan repair continuation

After R12, a fresh Release archive was produced and passed the normal scripted
archive gates, but the owner-added strict explicit executable scan was red for
paid/provider/agent/model/browser terminology retained in the Release
executable. That archive is not accepted as a Free V1 release artifact.

The red explicit scan was:

- `build/xcode-results/2026-07-14-keelstone-explicit-artifact-scan-r15.txt`;
- SHA-256
  `240936db4c3d37de83e38a2e468210812d13d7a29c4fba6892bd33fbc5ea34f2`;
- representative red terms included provider/model names, June, ResearchHub,
  browser unavailable copy, prompt-cache/runtime labels, Anthropic font labels,
  and local/cloud model boundary strings.

Owner steer applied before the next edit:

- Free V1 remains Mac App Store-only and must not compile paid AI surfaces into
  the free build;
- Kokoro voice remains retained;
- June, browser, ResearchHub, chat/model provider surfaces, cloud model
  providers, local GGUF model runtime, and paid agent surfaces must be hidden
  and inactive for Free V1 without deleting paid source;
- `InferenceState` is treated as legacy/deprecated for the Free V1 boundary
  unless a narrow helper/foundation-model seam still needs compile
  compatibility.

Surgical repair made for the explicit-scan failure:

- `Epistemos/State/InferenceState.swift`: added Free V1 neutral compatibility
  shims for `CloudModelProvider` and `AIProviderSelection`; retained old case
  names only where shared code still compiles through them, with neutral raw
  values and no active product providers; added missing Free V1 reasoning
  helpers for `CloudTextModelID`.
- `Epistemos/Engine/PromptRenderer.swift`: added a Free V1 unavailable renderer
  stub so paid provider render target labels do not enter the Free V1
  executable.
- `Epistemos/Engine/PromptCache.swift`: added a Free V1 no-op prompt-cache
  stub so paid prompt-cache strings do not enter the Free V1 executable.
- `Epistemos/Goose/GooseMASAgentCoreProviderSlug.swift`: returned `nil` for
  June/provider resolution in Free V1.
- `Epistemos/JuneAgent/JuneEpdocAssist.swift` and
  `Epistemos/Views/Landing/LandingFeatureButtons.swift`: changed unavailable
  paid-workspace copy so the Free V1 executable does not carry June/browser
  unavailable wording.
- `Epistemos/App/AppBootstrap.swift`: changed Free V1 runtime-boundary logging
  to neutral paid-runtime wording.
- `Epistemos/Theme/EpistemosTheme.swift`: changed Free V1 typography labels to
  neutral bundled font names.

R13:

- clean resource preflight:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r13-preflight.txt`;
- SHA-256
  `e0a00f8fefd843451540889860737fed1026e494074c78f4691b532b0487d67a`;
- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- swap `2016.44M` used of `3072M`;
- free-memory percentage above owner threshold;
- pages throttled `0`;
- no active competing Xcode/compiler/model/Epistemos process.

R13 attempted the corrected two-test Free V1 compile/source-guard batch but
failed at Swift compile time after the first prompt-cache stub patch: the real
`PromptCache`/`CacheTTL` body was still visible under the Free V1 branch, and
the Free V1 prompt renderer was missing compatibility case names required by
shared call sites. No archive or runtime launch followed R13.

R14:

- clean resource preflight:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r14-preflight.txt`;
- SHA-256
  `21386860a737e47f8aa50d9f9bb0f0d17bc745b4dea1f5062f097eac5c928add`;
- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- swap `2016.44M` used of `3072M`;
- free-memory percentage above owner threshold;
- pages throttled `0`;
- no active competing Xcode/compiler/model/Epistemos process.

R14 failed at Swift compile time in the Free V1 `InferenceState` compatibility
surface because shared call sites still expected no-argument reasoning helper
members. No archive or runtime launch followed R14.

R15:

- clean resource preflight:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r15-preflight.txt`;
- SHA-256
  `db1f4de1d47367d6adb14af5f4ea9fd6e418d4bcb5564dc17cc708f4f6fddf35`;
- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- swap `2016.44M` used of `3072M`;
- free-memory percentage above owner threshold;
- pages throttled `0`;
- no active competing Xcode/compiler/model/Epistemos process.

R15 command used the same corrected Swift Testing filters as R12, with a fresh
DerivedData path and no automatic package resolution. It exited `0`.

R15 evidence:

- log:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r15.log`,
  SHA-256
  `8c6ebe5c3606bc171f8bd177ffb085304a823227acdaf7c0519247450c4640d4`;
- xcresult JSON:
  `build/xcode-results/2026-07-14-free-v1-boundary-compile-r15.xcresult.json`,
  SHA-256
  `8ca97ff0c7f22feb0405ee5167adf1a40ab8e46f15d09cb6d43781056ee7138f`;
- Swift Testing executed 2 tests in 1 suite, both passed:
  - `free V1 excludes provider branding and leaf runtimes without deleting paid source`;
  - `free V1 excludes June QuickChat Goose and legacy agent workspace sources without deleting paid source`;
- debug executable:
  `/private/tmp/Epistemos-FreeV1-Boundary-Compile-R15/Build/Products/Debug/Epistemos.app/Contents/MacOS/Epistemos`;
- debug executable SHA-256:
  `d616c268e143afb1f7f6c4fa6e43beaf2aa02c6fe20117ad79baec75a5f1a045`;
- strict debug executable scan:
  `build/xcode-results/2026-07-14-free-v1-boundary-r15-executable-strict-scan.txt`,
  SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`;
- strict app-resource scan:
  `build/xcode-results/2026-07-14-free-v1-boundary-r15-app-resource-strict-scan.txt`,
  SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

R15 proves the repaired Free V1 debug compile/source-guard boundary is green
and the actual debug executable/resources are clean for the prior red explicit
paid/provider/June/browser/model terminology scan. It does not prove a fresh
Release archive, signing, artifact gates, App Intents metadata, app launch, or
runtime behavior.

The next exact action is to delete stale Epistemos app products/archives for
the active leg, record a fresh resource preflight, produce exactly one fresh
`Epistemos-AppStore` Release archive from the R15-repaired source, sign it with
the recorded App Store sandbox entitlements for artifact inspection, and rerun
the scripted archive gates, bundle scan, App Intents metadata scan, and strict
explicit executable scan before any launch/runtime matrix.

Current verdict:

**INCOMPLETE — R15 FREE V1 DEBUG COMPILE/SOURCE-GUARD BOUNDARY GREEN AND STRICT
DEBUG EXECUTABLE/RESOURCE SCANS CLEAN; FRESH RELEASE ARCHIVE AND ARTIFACT GATES
PENDING; NO LAUNCH/RUNTIME MATRIX STARTED; NOT RELEASE READY**

---

## Continuation after app/session crash — 2026-07-14 evening CDT

Continuation scope:

- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- canonical execution key:
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`;
- owner safety ceiling retained at swap used strictly below 16 GiB, free memory
  at least 25%, pages throttled zero, and no competing Xcode/compiler/model or
  Epistemos runtime before build/archive/launch;
- no payment, password, Jump, paid-provider, model-provider, secret, or private
  Columbia/VA/funding work was opened.

### R20 stopped preflight

R20 resource preflight:

- log:
  `build/xcode-results/2026-07-14-keelstone-release-archive-preflight-r20.txt`;
- SHA-256
  `e1bfbfaee7c77cdb9386a16dc7076e9596c45a6b8f8d0a2a54c1de567ebc7790`;
- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty entries `311`;
- swap `2872.81M` used of `4096.00M`;
- free-memory percentage `48%`;
- pages throttled `0`;
- available disk about `487Gi`;
- **red condition:** a stale R16 `xcodebuild archive` plus
  `SWBBuildService`/`swift-frontend` processes were still alive.

R20 correctly stopped before a fresh archive. The stale R16 build process was
terminated; no reset or source overwrite was performed.

### R21 clean preflight and exact Release archive

R21 resource preflight:

- log:
  `build/xcode-results/2026-07-14-keelstone-release-archive-preflight-r21.txt`;
- SHA-256
  `3bf63f028eb36e2512efadef85827cbcf047020f55d001793bff598e45d6f3c5`;
- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty entries `311`;
- swap `2856.81M` used of `4096.00M`;
- free-memory percentage `66%`;
- pages throttled `0`;
- available disk about `487Gi`;
- no active Xcode/compiler/model/Epistemos runtime was found. Process matches
  were the preflight shell/`rg`, Codex, and macOS widgets.

The active archive path was:

`/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-14-keelstone-current.xcarchive`

The archive command used the `Epistemos-AppStore` scheme, Release
configuration, generic macOS destination, `EPISTEMOS_PRODUCT_EDITION=FREE_V1`,
and `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=-`.

Xcode printed `** ARCHIVE SUCCEEDED **`, but the shell wrapper then exited `1`
because it attempted to assign zsh's read-only variable name `status`. The
archive itself was immediately verified on disk after the wrapper error.

R21 retained archive hashes before local ad-hoc signing:

- archive log:
  `build/xcode-results/2026-07-14-keelstone-release-archive-r21.log`,
  SHA-256
  `8fa289e54087dc4b02c8d3a474bd80985e20c6f64e317dac84ca2ec44dc29769`;
- archive `Info.plist` SHA-256
  `df548750380e1d765075af800954492de91808f0844a891bc1648eb8e0df91ac`;
- unsigned executable SHA-256
  `ff2a935d867443cf4d80af8c66d5552e663aeeb4129d6b2512c6640d1419e9b3`.

R21 ad-hoc signing:

- entitlements:
  `Epistemos/Epistemos-AppStore.entitlements`;
- log:
  `build/xcode-results/2026-07-14-keelstone-adhoc-codesign-r21.log`;
- SHA-256
  `8eff661474379c7e6b4211fa7ed8be8f9053ce8b2bdeec4d5ce4ac4cccf46ea4`;
- `codesign --verify --deep --strict --verbose=4` passed;
- signature was ad-hoc with no TeamIdentifier;
- entitlements included sandbox, app group `group.com.epistemos.shared`,
  audio-input, app-scope bookmarks, user-selected read-write, and network
  client;
- signed executable SHA-256
  `928d4bac0f486e8a1e80523106c5b3cd18070e77d1c87b0779726626babed994`.

### R21 artifact gates

The first release-gate invocation used the wrong script shape and failed
without changing source:

- log:
  `build/xcode-results/2026-07-14-keelstone-release-gate-r21.log`;
- SHA-256
  `69e52a5d2019407975a6f05883dd43e09eedb6b8edfd6b1a563e23a498e1177c`;
- script response: `Unknown argument`, because the script requires
  `--appstore-app <path>`.

The corrected release gate then passed against the same signed R21 archive app:

- log:
  `build/xcode-results/2026-07-14-keelstone-release-gate-r21b.log`;
- SHA-256
  `507d20d2f335b96792e1e33f0f01fb28705fc1e296a0e90f77e4560edd72b6dc`;
- result: `KEELSTONE MAS-only gate passed for the active product edition.`

The R21 release gate proved:

- exactly one application target, `Epistemos-AppStore`;
- MAS compilation conditions and sandboxing;
- Free V1 edition boundary;
- free V1 skips staged JuneWeb, model manifests, and agent skills;
- in-process MAS Goose runner/source contracts remain source-present;
- normal scheme launches MAS target;
- retired lanes absent;
- built App Store artifact has the App Sandbox entitlement;
- built artifact omits JuneWeb, model manifest, agent skills, local inference
  runtime, `agent_core`, and `omega_mcp`;
- built executable has no paid inference or agent linkage;
- bundle scan found no prohibited runtime strings, parked account/backend
  runtime markers, retired-lane strings, 1Code strings, prohibited runtime
  symbols, or prohibited research/tool resource residue.

Strict explicit executable scan:

- file:
  `build/xcode-results/2026-07-14-keelstone-explicit-artifact-scan-r21.txt`;
- line count `0`;
- SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`;
- scan terms included `SessionBrowser`, `ComposerReferenceBrowser`,
  paid OpenAI/Anthropic/Kimi/Gemini/Claude model/provider terms, Browser
  unavailable wording, old chat-history privacy wording, and old MAS June
  provider copy.

At this point the exact R21 archive artifact gates were green.

### R22 runtime preflight and partial runtime evidence

R22 runtime preflight:

- log:
  `build/xcode-results/2026-07-14-keelstone-runtime-preflight-r22.txt`;
- SHA-256
  `66de0325a27bb6d567317be579e0422207b0d815590958938b2b312b151b5256`;
- branch `feat/goose-surface`;
- HEAD `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty entries `311`;
- swap `3099.38M` used of `4096.00M`;
- free-memory percentage `66%`;
- pages throttled `0`;
- available disk about `486Gi`;
- no active Xcode/compiler/model/Epistemos runtime was found before launch.

The exact signed R21 archive app was launched:

- app process PID observed: `21893`;
- unified-log capture PID: `21889`;
- unified-log file:
  `build/xcode-results/2026-07-14-keelstone-runtime-unified-r22.log`;
- unified-log SHA-256 after stop:
  `5632aa82b6f85dc1e51b9822b9b8b8693ccbacedcdf69e7e86e764fa09e5fb45`;
- log line count after stop: `1`.

Saved UI evidence:

- initial main UI:
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-initial-r22.txt`;
- Settings UI:
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-settings-r22.txt`;
- Vault settings before/after selection:
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-vault-settings-r22.txt`,
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-vault-selected-r22.txt`;
- Notes list:
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-notes-r22.txt`;
- note opened in Epdoc:
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-note-open-r22.txt`;
- Epdoc AX edit attempt:
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-note-edited-r22.txt`,
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-note-saved-r22.txt`;
- Source before/after clean attempts:
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-source-before-clean-r22.txt`,
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-source-clean-saved-r22.txt`,
  `build/xcode-results/2026-07-14-keelstone-runtime-ui-source-keyboard-saved-r22.txt`.

Observed partial runtime facts:

- initial main UI opened to a resume checkpoint and did not expose Browser,
  ResearchHub, chat, model/provider, or June navigation;
- Settings sidebar exposed Capture, Ambient Frequencies, Voice, Landing, Graph,
  Appearance, Privacy & Storage, Vault, Privacy, Advanced, General, and
  Epistemos Foundation; it did not expose model/provider/browser/research
  settings;
- Settings memory row reported process RSS around `306.1 MB of 16 GB`;
- Vault settings initially reported no active vault;
- disposable vault was selected through the app's folder picker:
  `/Users/jojo/Downloads/Epistemos/build/keelstone-disposable-vault-r22`;
- Vault settings reported the exact disposable path and imported `1` `.md`
  file;
- Notes list showed `KEELSTONE-DISPOSABLE-VAULT-R22` and
  `KEELSTONE-RUNTIME-R22`;
- Epdoc displayed the note heading, paragraph, and checkbox;
- using AX `set_value` directly on the rich Epdoc surface produced duplicated
  reshaped content on disk; this is not counted as owner-visible normal typing
  evidence;
- using AX `set_value` directly on the Source/MarkEdit surface collapsed the
  saved file to front matter plus `---`; this is not counted as owner-visible
  normal typing evidence;
- using keyboard-style Source input (`⌘A` then typed text) saved clean Markdown
  to disk with marker `R22 keyboard source edit/save marker 2026-07-14.`;
- clean saved disposable note SHA-256 after keyboard input:
  `ce58017d781dfd0c40307609c2e803decf62419ff2cb173cc2cd6b11624ce421`.

The runtime matrix did not complete. Preview/Prose, quit/relaunch/restore,
second save, Quick Capture, Meeting, task/planner, Sync-status,
calendar-permission, PDF/import/export, graph-to-editor, search/source routing,
Kokoro preview/read-aloud, and full correlated-log assertions remain unproven.

### R22 stop condition

The exact R21 archive disappeared during the runtime leg:

- missing path:
  `/Users/jojo/Downloads/Epistemos/build/appstore-release-archive-2026-07-14-keelstone-current.xcarchive`;
- `ls` reported the archive, `Products`, `Products/Applications`, and
  `Epistemos.app` no longer existed;
- Computer Use then could not continue against the archive app and returned
  that `Epistemos.app` could not be opened because the file was not found.

At the same time, a separate Debug build was observed without being part of the
R22 Keelstone runtime command:

`EPISTEMOS_PRODUCT_EDITION=FREE_V1 xcodebuild build -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -derivedDataPath /private/tmp/Epistemos-FreeV1-InferenceState-R22 ...`

That competing Debug build's own preflight existed at
`build/xcode-results/2026-07-14-free-v1-inference-state-r22-preflight.txt` and
showed the archive app still running as PID `21893` from the missing archive
path, plus a separate lockdown HTTP server on port `8765`. It therefore began
while the Keelstone runtime matrix was active and was invalid under the
no-competing-build/no-competing-runtime rule. It and its child
`SWBBuildService`, script, and `npm run build` processes were stopped.

No direct deletion command for the archive was found in the searched scripts or
logs during this pass. The retained facts are narrower: the R21 archive existed,
was hashed, signed, gated, and launched; later the same path was missing, and a
separate invalid Debug build had appeared while the archive app was still
running.

Because the exact green R21 archive is no longer retained and a competing build
appeared during runtime, the finite runtime matrix cannot be completed or
claimed from R22. The successful R21 artifact gates remain evidence for the
bytes that were hashed and scanned, but the missing archive prevents further
runtime proof against that exact artifact.

Current verdict:

**INCOMPLETE — R21 RELEASE ARCHIVE COMPILED, SIGNED, RETAINED LONG ENOUGH FOR
HASHES AND ARTIFACT GATES, AND PASSED THE KEELSTONE FREE V1 ARTIFACT GATES;
R22 RUNTIME BEGAN AND PROVED DISPOSABLE VAULT SELECTION PLUS CLEAN
KEYBOARD-SOURCE SAVE, BUT THE EXACT ARCHIVE DISAPPEARED DURING RUNTIME AND A
COMPETING DEBUG BUILD APPEARED. FINITE RUNTIME MATRIX REMAINS INCOMPLETE; NOT
RELEASE READY.**

Next exact action:

1. Investigate why
   `build/appstore-release-archive-2026-07-14-keelstone-current.xcarchive`
   disappears after archive/gate/launch, without resetting or overwriting
   source.
2. Keep the R22 disposable-vault evidence isolated; do not treat the AX
   `set_value` corruption as a normal owner-typing claim without a focused
   editor input reproduction.
3. Once the disappearing-archive and competing-build causes are understood,
   rerun a clean resource preflight, produce exactly one fresh Release archive,
   sign and gate that exact retained archive, then rerun only the finite
   runtime matrix.
4. Do not start another canonical execution key, MAS canon feature work, paid
   provider/payment work, or broad performance-hardening phase until the
   Keelstone stop condition is resolved or the owner explicitly redirects.

## Same-Key Quick Capture Focused Compile Continuation — 2026-07-14

This section is the latest authoritative continuation after the out-of-order
crash/restart append above. It does not begin another canonical execution key.

Canonical execution key remains:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

### Owner intent and constraints retained

- Resume Keelstone first; do not begin MAS canon feature expansion before the
  active release-gate evidence is safely checkpointed.
- Preserve Mac App Store Free V1 boundaries: no AI/chat/browser/ResearchHub/
  June/model/provider surfaces compiled or visible for Free V1, except Kokoro
  voice remains retained.
- Keep the one-current-build discipline: before any build/test/archive, stop
  prior Epistemos/Xcode test hosts and delete stale Epistemos app/archive
  products from the active build location.
- Resource preflight remains required before each build/test/archive. The
  current retained ceiling is swap strictly below 16 GiB, at least 25% free
  memory, zero throttled pages, and no competing Xcode/compiler/model/
  Epistemos runtime.
- Do not claim runtime behavior without current exact evidence.

### Surgical source repair applied

The focused R6 build had stopped before tests with:

`Value of type 'InferenceState' has no member 'configuredCloudProviders'`

at `Epistemos/State/AgentCommandCenterState.swift:324`.

Readback confirmed the Free V1 `InferenceState` already exposed neutral cloud
access methods but was missing the matching neutral provider-list property.
The only new source edit in this continuation was:

`Epistemos/State/InferenceState.swift`

- added Free V1 contract property:
  `var configuredCloudProviders: [CloudModelProvider] { [] }`.

This preserves the paid/non-Free contract shape while admitting no Free V1
cloud providers.

`git diff --check` passed after the edit.

### Verification attempts and retained evidence

#### R6 — real source compile failure, now repaired

- Preflight:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r6-preflight.txt`
- Preflight SHA-256:
  `1c0d5ac071cf246f5144843029d637fbe570b659e3e02a1905680b9e284de924`
- Log:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r6.log`
- Log SHA-256:
  `72a9e31b36f651e9062ebc0bfcc4bcfb699510d049f164c89135ae5655165bda`
- Result: `xcodebuild` exited before tests because the Free V1
  `InferenceState` contract lacked `configuredCloudProviders`.

#### R7/R8 — invalid interrupted foreground runs

R7 and R8 were foreground `xcodebuild test` attempts after the source repair.
Both reached substantially past the R6 compile error and then ended with
`** BUILD INTERRUPTED **` / rc `143` before tests. Their `.xcresult` bundles
were incomplete/corrupted and are not test evidence.

Retained identities:

- R7 preflight SHA-256:
  `94e365e2a9738cb4678c9f4cc9d55009aca6b38649fc7aeb257d10caed291ed9`
- R7 log SHA-256:
  `692ab661484670b46aa02224104db576ae3cf1443473c182c0d3225f7f8290d7`
- R8 preflight SHA-256:
  `377626ccdb609a9e2b89ade4e0bc9d1083d1b39a1654762bac59597161a70a66`
- R8 log SHA-256:
  `0639b04b64d44c23d6f34c944b5d12d72a7cc433a8ed560d84f525144e230d49`
- R8 stale-product log SHA-256:
  `bf0e8ad04802ceda84cf1f6f07b4585ab4ed73bdf2fa2275a19ef2d105d2355d`

#### R11 — invalid because a competing build was active

R11 was launched under `tmux` to avoid foreground-session interruption. Its
preflight itself recorded a competing build:

`/private/tmp/Epistemos-FreeV1-InferenceState-R26`

with active `xcodebuild` and child package checkout processes. That violates
the no-competing-Xcode/compiler-build rule, so R11 is invalid as Keelstone
evidence. R11 was stopped intentionally, along with the competing R26 build and
leftover bundle/codegen children.

Retained identities:

- R11 preflight SHA-256:
  `82f8ee2a90539f04ac6bba2ee8e024d3f45998d60a754acdd6f370c1a224be43`
- R11 log SHA-256:
  `ce53c707dba37ebda2d56d4079c11629ed609980c5eb5fc5128b4cb257eafb2a`
- R11 stale-product log SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- Competing R26 build log SHA-256:
  `38e3083bbd1d1af991c9fa15fabf7d7fca58e816310f35b39ad7a6215e4937f1`

#### R12 — uncontaminated tmux-backed run, still interrupted before tests

R12 was started after clearing R26, R11, and their child build processes.
Preflight showed no competing Xcode/compiler/model/Epistemos runtime process
other than the unrelated lockdown HTTP server. Resource values were within the
retained safety thresholds:

- swap used: below 16 GiB;
- free memory: at least 25%;
- pages throttled: `0`;
- disk available: sufficient.

R12 reached package compilation, Rust/JS bundle build steps, resource copying,
asset catalog/Metal compilation, and then ended:

`** BUILD INTERRUPTED **`

`xcodebuild_rc=143`

No tests ran, and the `.xcresult` bundle was incomplete/corrupted.

Retained identities:

- R12 preflight:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r12-preflight.txt`
- R12 preflight SHA-256:
  `b9368cc3ef0ce45ea11e91bc293f123a7c8cab316cae040bbcacfa051e2c0837`
- R12 log:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r12.log`
- R12 log SHA-256:
  `60edaad945626b07daeb6672fb61dc88374a7b57896bcdc39a3c197b80356032`
- R12 stale-product log SHA-256:
  `13dee4b1686d79fac7d68be600482e99e97b9c75154c37ec1e554c154286422e`
- R12 post-interrupt process/resource log:
  `build/xcode-results/2026-07-14-free-v1-quick-capture-focused-current-r12-postinterrupt-processes.txt`
- R12 post-interrupt process/resource log SHA-256:
  `8e868b46b3aa584aca782e54045d1c0cbf176297caed4ec2ae71becc42d9915b`

Post-interrupt observation recorded swap about 3.8 GiB, free memory 72%,
throttled pages `0`, sufficient disk, and only orphaned `ibtoold` helpers from
the interrupted build. Those helpers were cleared.

### Current verdict

**INCOMPLETE — THE FREE V1 `configuredCloudProviders` COMPILE CONTRACT GAP WAS
SURGICALLY REPAIRED, AND LATER BUILDS PROGRESSED PAST THAT R6 SOURCE ERROR,
BUT NO FOCUSED QUICK CAPTURE TEST BATCH HAS COMPLETED. R11 WAS INVALID DUE A
COMPETING BUILD; R12 WAS UNCONTAMINATED BUT STILL INTERRUPTED BEFORE TESTS.
KEELSTONE IS NOT RELEASE READY.**

### Exact next action

1. Do not start MAS canon/feature expansion yet.
2. Before any new build/test, confirm no R26/R11/R12 or other Xcode/compiler/
   bundle child remains active, then delete stale Epistemos app/archive
   products from the active build location.
3. Re-run the same focused Quick Capture/Privacy/Voice batch using a single
   current build lane. Prefer a tmux-backed run; if `BUILD INTERRUPTED` repeats
   with no source error, switch to a lower-concurrency diagnostic run
   (`-jobs 1`) or split the proof into a parse/build-only leg before tests, and
   record that as execution-environment failure rather than source behavior.
4. Only after a focused green compile/test result should the artifact gates,
   archive leg, finite runtime matrix, or broader editor/MAS-canon work resume.
## Same-Key R13-R16 Focused Compile Continuation — 2026-07-14

This checkpoint continues the same canonical execution key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

No MAS canon, paid feature work, archive, runtime matrix, app launch, model
load, provider request, secret access, or audio operation began.

### Owner constraints retained

- Free V1 must keep AI/chat/browser/ResearchHub/June/model/provider surfaces
  hidden/not compiled, except Kokoro voice remains retained.
- One current build remains mandatory: stop prior Epistemos/Xcode test hosts
  and delete stale app/archive products from the active build location before
  any build/test/archive.
- Resource preflight remains mandatory: swap strictly below 16 GiB, free
  memory at least 25%, pages throttled zero, and no competing Xcode/compiler/
  model/Epistemos runtime.
- Do not claim runtime behavior without current exact evidence.

### R13 — real Free V1 compile failure, repaired

R13 was a `tmux`-backed `-jobs 1` retry of the same focused Quick Capture /
Privacy / Voice batch. It stopped with rc `65` before tests because another
paid-provider symbol remained compiled into the Free V1 path:

`Epistemos/State/AgentCommandCenterState.swift:1198:22: error: type
'CloudModelProvider' has no member 'anthropic'`

Surgical repair applied:

- `Epistemos/State/AgentCommandCenterState.swift`
  - `ACCBrainSelection.supportedNativeProviderEfforts` now returns `[]` under
    `#if EPISTEMOS_FREE_V1` before referencing `.anthropic` or `.google`.

This preserves the Free V1 no-provider policy and does not admit cloud
providers.

Retained identities:

- R13 preflight SHA-256:
  `afc0fef72e2fae060f9afb56d224aa87d2921d22f93942a3ef91b91edc01e226`
- R13 log SHA-256:
  `81ba6c5c56c8e2e73df6af827765af1572c7173e1e29ef6cb736f702e54c5d9c`
- R13 stale-product log SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

### R14/R15/R16 — no usable focused test evidence

R14 did not start a durable `xcodebuild` leg. Its first preflight caught a
competing `/private/tmp/Epistemos-FreeV1-InferenceState-R25` build. After that
was cleared, a background launch produced a zero-byte log and no done marker.
R14 is invalid and not counted as test evidence.

R15 started in `tmux` after a passing preflight, but a new competing
`InferenceState-R25/R29` build was spawned by the Codex app server after the
preflight. R15 was stopped as contaminated and is invalid as Keelstone
evidence.

R16 started in `tmux` after a passing preflight:

- swap used: `3851.88M`;
- free memory: `69%`;
- pages throttled: `0`;
- no competing Epistemos/Xcode build/compiler process at launch.

R16 reached package compilation and the `Build Rust Engine` phase, then ended
with:

`** BUILD INTERRUPTED **`

The `.xcresult` bundle is incomplete/corrupt (`Info.plist` missing), no test
summary exists, and no Swift/source error was captured. No tests ran.

Retained identities:

- R14 preflight SHA-256:
  `6bc4b4639c16cbd4231d7e2617c2037e94f218e8ec5dea675f36e7f81437e37b`
- R15 preflight SHA-256:
  `d3db1029cb63f90bb9dc9c7cf37398a97fcd27159cb466c7b3b9eb4d4f6a21af`
- R15 log SHA-256:
  `ff92290a0679555d84c1dcf0bae3677a792871d1e0a16fca3046c4c50844ccd3`
- R16 preflight SHA-256:
  `396a224abca1bf50b92279c9cfa7a781da3a6f4d495a3716df12d95e5b8ecf29`
- R16 log SHA-256:
  `b78abd8033ca39ba440e4f173625bcffe23410c8e3c063720730ec21b80d33d6`
- R16 stale-product log SHA-256:
  `7c030d59e4df8698fff6b4eb72f446c7520adbdd2b8de6c373601bd8d4aedef2`

### Current verdict

**INCOMPLETE.** Two Free V1 compile-boundary gaps have been repaired:

1. `InferenceState.configuredCloudProviders` now exists and returns `[]` for
   Free V1.
2. `ACCBrainSelection.supportedNativeProviderEfforts` no longer references
   paid provider cases under `EPISTEMOS_FREE_V1`.

The focused Quick Capture/Privacy/Voice batch still has no valid green/red
test result. R14/R15 were invalid launch/contamination legs; R16 was an
execution interruption before tests, not a source or runtime pass.

### Exact next action

1. Do not begin MAS canon, archive, runtime matrix, or paid feature work.
2. Confirm no R14/R15/R16/R25/R29 Xcode/compiler children remain.
3. Delete stale Epistemos app/archive products from the active build location.
4. Re-run the same focused batch only after a fresh resource preflight. If the
   same `BUILD INTERRUPTED` condition repeats with no source error, stop and
   treat the blocker as execution-environment/build-script interruption until
   the interruption source is isolated.

## Same-Key R18 Build-Phase Isolation — 2026-07-14

Continue the same key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

R18 was a standalone Free V1 build-phase diagnostic only. It did not run
Swift tests, launch the app, archive, load a model, access secrets, perform
audio, or claim runtime behavior.

Purpose: isolate the R16 `** BUILD INTERRUPTED **` boundary, which occurred as
the Xcode `Build Rust Engine` phase began.

R18 ran the Free V1 subset of the Xcode build-phase script chain directly:

- `build-rust.sh`
- `build-syntax-core.sh`
- `MAS_SANDBOX=1 build-epistemos-core.sh`
- `build-epistemos-shadow.sh`
- `build-epistemos-code-index.sh`
- `build-substrate-rt.sh`
- `build-tiptap-bundle.sh`
- `build-coreeditor-bundle.sh`

Result: `rc=0`. The standalone Free V1 script chain completed. This means R16
is not currently explained by an immediate script-chain failure. The next
focused evidence leg may return to the same narrow Xcode Quick
Capture/Privacy/Voice batch after a fresh resource preflight and stale-product
cleanup.

Retained identities:

- R18 preflight SHA-256:
  `6f351ee47457e980f3ade2306e29d2673ed67c49f4c36d7e10ae928b87526e1f`
- R18 log SHA-256:
  `22de66e46992379a1ea7baae9e9b4ee4a8159e143fff7f224cd6582cd6c8ecb6`

### Current verdict after R18

**INCOMPLETE.** R18 is useful build-phase isolation, not test evidence. The
focused Quick Capture/Privacy/Voice batch still needs a valid green/red result.

### Exact next action after R18

1. Confirm R18 left no active cargo/compiler/build children.
2. Delete stale Epistemos app/archive products from the active build location.
3. Run a fresh resource preflight.
4. If thresholds pass, re-run the same focused Quick Capture/Privacy/Voice
   batch as the next evidence leg.

## Same-Key R19 Focused Retry Contamination — 2026-07-14/15

Continue the same key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

R19 performed a fresh preflight for the same focused Quick
Capture/Privacy/Voice batch:

- branch: `feat/goose-surface`;
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty count: `318`;
- swap used: `3827.88M`;
- free memory: `71%`;
- pages throttled: `0`;
- no competing build/compiler/Epistemos process at preflight time.

The stale Quick Capture derived-data/app product cleanup was performed before
launch.

R19 then started the focused Xcode test command in `tmux` with `-jobs 1`.
After launch, an unrelated stale Codex-app-server child started a competing
Free V1 build using:

`/private/tmp/Epistemos-FreeV1-InferenceState-R25`

The competing command identified itself as:

`RUN_TAG="2026-07-14-free-v1-runtime-state-r33"`

Because the owner threshold requires no competing Xcode/compiler/model/
Epistemos runtime process, R19 was stopped and is invalid as focused test
evidence. R19 produced no usable test result and no done marker.

Retained identities:

- R19 preflight SHA-256:
  `794d7daf4fcbfddd968637560c0a75ae7c9727148770c70e0c59cbf242c42952`
- R19 stale-cleanup SHA-256:
  `a28e29e8af6574e1783aae72933685904a72a9ebebbfcb1f436a29a6852faffa`
- R19 partial log SHA-256:
  `eb72a589c5e23b1cda1ce8abd428a8dd553ae467b583429f0ab86806920b4919`
- Stale `runtime-state-r33` log SHA-256:
  `9419eb2fc797201d6073b799ca3238492a3652632d1143b8f408e47e476cb93b`

### Current verdict after R19

**INCOMPLETE.** R19 is invalid/contaminated. No focused test pass/fail result
exists after the Free V1 source repairs.

### Exact next action after R19

1. Confirm no R19/R25/R33 Xcode/compiler children remain.
2. Run one short no-build-process watch before any retry to ensure the stale
   Codex-app-server command is no longer respawning.
3. If clean, perform a fresh resource preflight and retry the same focused
   Quick Capture/Privacy/Voice batch once.
4. If the R25/R33 ghost build recurs, stop and treat the ghost build source as
   the blocker before further Xcode evidence attempts.

## Same-Key R20 Prewatch Blocker — 2026-07-14/15

Continue the same key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

R20 did not launch any focused test build. It performed the required no-build
quiet-watch after the R19 contamination.

The watch immediately found a new competing Codex-app-server child using the
same stale DerivedData path:

`/private/tmp/Epistemos-FreeV1-InferenceState-R25`

The competing command identified itself as:

`RUN_TAG="2026-07-14-free-v1-runtime-state-r34"`

Because this repeated the R19 contamination pattern before any new focused
test launch, the Keelstone focused evidence chain stopped again under the
owner resource/competition threshold. The R34 process tree was terminated. A
final process check found no active R19/R25/R33/R34 Xcode/compiler/Cargo/
Epistemos child process, and `git diff --check` passed.

Retained identities:

- R20 prewatch SHA-256:
  `fa19e5d12951fa552ed92602528f6d5f051602b9bbc4fc740df1561596cd0358`
- Stale `runtime-state-r34` log SHA-256:
  `4cb4b4cb7dcdb6c970f2f148d7108aa1f65ca2c8fac81055ccb855bde744935a`

### Current verdict after R20

**INCOMPLETE / BLOCKED BY REPEATING GHOST BUILD.** The focused Quick
Capture/Privacy/Voice batch still has no valid green/red test result after the
Free V1 source repairs. R19 and R20 prove that stale Codex-app-server build
commands are respawning on the `InferenceState-R25` path and contaminating the
required one-build evidence lane.

### Exact safe resumption boundary after R20

1. Do not start another Xcode build/test/archive until the Codex-app-server
   stale `runtime-state-r33/r34` build source is gone.
2. Before retry, run a fresh no-build-process watch that remains clean.
3. Then run a fresh resource preflight, delete stale active build products,
   and retry the same focused Quick Capture/Privacy/Voice batch.
4. Do not begin MAS canon, paid features, archive, runtime matrix, app launch,
   model load, provider request, secret access, or audio operation before the
   focused batch has a valid green/red result or the owner explicitly redirects.

## Same-Key Runtime-State Cleanup Evidence — 2026-07-14/15

Continue the same key:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Owner steer: legacy `InferenceState` was believed deprecated/dead and should
be removed from the Free V1 boundary unless foundation helper surfaces such as
embeddings depended on it. The active interpretation was: Free V1 must not
compile or advertise the old inference-state identity; paid/future code may
remain parked behind build-condition boundaries.

Actions taken in this slice:

- Renamed the Free V1 runtime source boundary to
  `Epistemos/State/ProductRuntimeState.swift`.
- Replaced the Free V1 observable runtime type with
  `FreeV1RuntimeState`.
- Retained the old paid `InferenceState` implementation only under the
  non-Free-V1 branch for future paid builds.
- Updated active Free V1 call sites to use `ProductRuntimeState`.
- Neutralized additional Free V1 compiled labels for runtime-state/provider
  leakage, Epdoc assistant suggestion copy, runtime bootstrap filenames, LSP
  unavailable copy, prompt-render/cache stubs, runtime-lane settings copy, and
  app-icon metadata/file names.

Valid build evidence retained:

- R37 preflight SHA-256:
  `161ede1e998780b6586204c58b63e01bc1ad610b86bd355aa40eaecfead8f83b`
- R37 build log SHA-256:
  `f2788d7f4f1141d4634b7d1f9894eab2dd2a7db60fac4738731e19fdd46707de`
- R37 strict scans:
  - AppIntents: 0 hits,
    `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  - MacOS executable/debug dylib: 69 hits,
    `edbcf9b37318d3abd84360154b042dcc2cb41ce2cdd73b761959d109861e525d`
  - Resources: 4 hits,
    `aa25fea7dbde30c4d7a27da37b65186668ff85ac8b75e58696f6699c6e7dcd07`
- R38 preflight SHA-256:
  `7afcd64896a4ed9a53cdcf5c7153e427b28cc1513e31d0f8c12040199f219f71`
- R38 build log SHA-256:
  `104c368ca690284034b49757d461f28316b6b3d3b4c8f5b9082991b4b7100ecf`
- R38 strict scans:
  - AppIntents: 0 hits,
    `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  - MacOS executable/debug dylib: 62 hits,
    `25d04af3a2f0f55df7fe2e6ef118b3064088b0f9adda3a7c98e2d6247a3b8eb8`
  - Resources: 4 hits,
    `9116e773349ffb9bec01fc3911917b1fb09d57fd3d2f956a5f8798174d7b05b6`
- R39 preflight SHA-256:
  `90b4114ce34cf52266e63b77108138c2c0c4c400b2743935dbf58936dd833fa1`
- R39 build log SHA-256:
  `05e1d280f05dd207fa40edc38a63575388233bbb7c598cf3e05f760e56707dbb`
  with `xcodebuild_rc=65`; failure was limited to icon-catalog filename
  references after metadata/file rename.
- R40 preflight SHA-256:
  `0d722f4ffb525db940190c263ecc1e3461ad0829724e83597c1bf7fc7f2c373b`
- R40 build log SHA-256:
  `b0a1fab01a1acf1d49b12014b965587c4a2fd8d76de4f36b636002cba9692eb7`
- R40 strict scans:
  - AppIntents: 0 hits,
    `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  - MacOS executable/debug dylib: 54 hits,
    `e012b18dad69e7ce59c124761327a67fa0058128bf52d563e66653377e290d89`
  - Resources: 1 hit,
    `15494cb286a4194cd214cf3e2287cdea4507af4f912a60fed9ae3d905fd70b0d`

Current proven state:

- Free V1 Debug build succeeds on the fresh neutral path
  `/private/tmp/Epistemos-FreeV1-RuntimeState-R40/Build/Products/Debug/Epistemos.app`.
- Strict AppIntents scan is clean.
- Strict artifact scan has **zero** `InferenceState`, `inferenceState`, or
  `inference state` hits.
- The old `InferenceState` implementation is not the Free V1 runtime state.
- No archive, launch, runtime matrix, model load, provider request, secret
  access, or audio operation was performed in this slice.

Current verification debt:

- Strict MacOS scan still contains paid/runtime residue such as runtime-lane
  GGUF/provider identifiers, paid skill presets, `agent_core` unavailable
  strings, and paid June/provider names. These are not resolved and must stay
  red for release/archive purposes.
- The single remaining resource scan hit is Metal source-path/debug text, not
  a provider/model surface, but it is still recorded as scan debt.
- No focused Quick Capture/Privacy/Voice test batch has been rerun after the
  runtime-state cleanup.

### Current verdict after runtime-state cleanup

**PARTIAL PASS / RELEASE STILL RED.** The owner’s `InferenceState` concern is
resolved for the Free V1 compiled artifact, but Free V1 paid-surface cleanup
and the focused regression batch remain incomplete.

### Exact safe resumption boundary after runtime-state cleanup

1. Continue reducing the remaining Free V1 strict-scan paid/runtime residue.
2. Rebuild with fresh preflight after each meaningful cleanup batch.
3. Do not archive, launch, or begin runtime matrix until strict artifact gates
   are clean or a consciously narrowed artifact-gate exception is recorded.
4. After strict-scan cleanup, rerun the focused Quick Capture/Privacy/Voice
   regression batch with the same one-current-build/resource-preflight rules.

---

## Same-Key Runtime / Provider Identity Cleanup R41-R43 — 2026-07-14/15

Execution key remains:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Owner steer being honored:

> inference state is deprecated it is rll old dead code i beleoive so i want
> it gone unless helper fondatio models like embeddings and thigns like that
> rely on it if not h then it shuld be gone i dotn think the june mas agent
> relies on it iether

Interpreted intent:

- Free V1 must not compile or advertise the old `InferenceState` identity.
- Free V1 must not compile or advertise parked paid cloud/provider/June/GGUF
  identity strings as active product surface.
- Kokoro and local helper/foundation paths may remain when source evidence
  shows they are not paid/chat/provider surfaces.
- Paid future code may remain in source only behind compile gates; this pass
  does not delete the future paid lane.

### R41 retained prior evidence

- Branch: `feat/goose-surface`
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`
- Product path:
  `/tmp/Epistemos-FreeV1-RuntimeState-R41/Build/Products/Debug/Epistemos.app`
- R41 preflight SHA-256:
  `4922e59b80a60f10b6a797116ef279918ffa3126c52ad5483407eac7621641ae`
- R41 build log SHA-256:
  `132c82ff446701efcd5da51b10945f5ae60534cf7c5856a001a842e5b61eea86`
- R41 strict scans:
  - AppIntents: 0 hits,
    `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  - MacOS executable/debug dylib: 51 hits,
    `51780b0ce301f64e857adc39089f4363d3686d078ad427ad3fcec2efb5383000`
  - Resources: 1 hit,
    `15494cb286a4194cd214cf3e2287cdea4507af4f912a60fed9ae3d905fd70b0d`

R41 was still release-red because the executable retained provider/runtime
identity residue even though `InferenceState` itself was already absent.

### R42 failed intermediate build

R42 used a fresh derived-data path:

`/tmp/Epistemos-FreeV1-RuntimeState-R42`

Result: `xcodebuild_rc=1`.

Cause: Swift syntax failure in `Epistemos/Omega/BestOfPreset.swift` after
placing `#if !EPISTEMOS_FREE_V1` directly inside an array literal.

No app artifact from R42 is retained as passing evidence.

### R43 resource preflight

- Branch: `feat/goose-surface`
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`
- Dirty entries: 343
- Swap: `vm.swapusage: total = 5120.00M  used = 3763.88M  free = 1356.12M  (encrypted)`
- `memory_pressure -Q`: system free memory 65%
- `vm_stat`: pages throttled 0
- Disk: `/` and `/tmp` had 473 GiB available
- Process check initially found a stale `ibtoold` from R42; it was stopped
  before R43 build start. No active `xcodebuild`, `swift-frontend`, `clang`,
  model, or `Epistemos` runtime was present at R43 build start.
- Observed but not treated as active competing build: long-lived idle
  `MTLCompilerService` at 0.0% CPU.

### R43 build evidence

Command:

`EPISTEMOS_PRODUCT_EDITION=FREE_V1 xcodebuild build -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -derivedDataPath /tmp/Epistemos-FreeV1-RuntimeState-R43 CODE_SIGNING_ALLOWED=NO`

Result: `** BUILD SUCCEEDED **`

Product:

`/tmp/Epistemos-FreeV1-RuntimeState-R43/Build/Products/Debug/Epistemos.app`

Identity:

- Executable:
  `/private/tmp/Epistemos-FreeV1-RuntimeState-R43/Build/Products/Debug/Epistemos.app/Contents/MacOS/Epistemos`
- Bundle identifier observed by `codesign -dv`: `Epistemos`
- Format: app bundle with Mach-O thin arm64
- Signature: ad-hoc / linker-signed because code signing was disabled
- Size: 379M

R43 build log SHA-256:

`638b87039012f5d732e4c336ab1388c20fe0804f34619785cb7be661796e78dc`

### R43 artifact scans

Strict identity patterns:

`InferenceState|inferenceState|inference state|june|claude|anthropic|openai|kimi|minimax|deepseek|gguf|agent_core|enableWebSearch|OpenAI|Anthropic|Kimi|MiniMax|DeepSeek|Local GGUF|EPISTEMOS_GGUF_TOOL_GRAMMAR_V0`

Results:

- AppIntents identity scan: 0 hits,
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- MacOS executable identity scan: 0 hits,
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- Resources identity scan: 0 hits,
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

The older broader resource scan, which also searched generic terms such as
`search`, `browser`, `chat`, and `research`, reported 5 hits:

`0bd57abf47f50d5be770c23f75fcbd301337cbbefdda7427a0ab618ea9c587f6`

Inspection showed those are bundled editor syntax/completion-library strings
from CodeMirror/editor resources, not Epistemos paid provider, chat, June,
GGUF, or inference-state identity.

### Source changes in this slice

- `LLMProviderType` keeps only `appleIntelligence` and `localMLX` in Free V1;
  paid provider cases are behind `#if !EPISTEMOS_FREE_V1`.
- `IntegrationBrand` uses neutral `paidSkills` in Free V1 instead of compiling
  the Anthropic-specific skill brand case.
- `BestOfPreset` omits the Anthropic skills fallback target and item in Free V1.
- `ProductCapability.june` was renamed to generic `paidAgent` for active
  capability gating.
- FFI-unavailable user/system strings were neutralized to runtime-bridge
  wording.
- Provider-specific prompt/structure summary strings were neutralized.
- The GGUF grammar helpers in `PipelineService` are excluded from Free V1.

### Current proven state after R43

- Free V1 Debug build succeeds from a fresh derived-data path.
- The current app artifact is exactly:
  `/tmp/Epistemos-FreeV1-RuntimeState-R43/Build/Products/Debug/Epistemos.app`.
- AppIntents, executable, and resource identity scans are all zero for the old
  inference/provider/June/GGUF identity terms.
- `InferenceState` is not present in the Free V1 compiled artifact.
- No archive, app launch, runtime matrix, model load, provider request, secret
  access, or audio operation was performed in this slice.

### Current verification debt after R43

- Focused Quick Capture / Privacy / Voice regression batch has not yet been
  rerun after the R43 cleanup.
- No release archive has been produced.
- No artifact gate beyond the Debug build identity scans has been run.
- No manual launch/runtime evidence exists for the R43 app.

### Current verdict after R43

**IDENTITY CLEANUP PASS / RELEASE STILL RED.** The deprecated
`InferenceState` and old paid provider/June/GGUF identity strings are gone from
the Free V1 compiled artifact. Keelstone is still incomplete until the focused
regression batch and later release/archive gates pass.

### Exact safe resumption boundary after R43

1. Re-record resource preflight before any next build/test/archive.
2. Run the focused Quick Capture / Privacy / Voice regression batch only.
3. Keep using one fresh build/test product path; do not rely on R43 for later
   runtime/archive claims.
4. Do not launch the app or begin the runtime matrix until the next artifact
   gates support it.

---

## Epdoc CodeMirror Replacement Evidence R69-R77 — 2026-07-15

Execution key remains:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Owner boundary preserved:

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

This slice replaces only the Epdoc editing canvas with the restricted
MarkEdit/CoreEditor CodeMirror 6 substrate. The Epistemos window chrome,
toolbar, title/info affordances, palette, and Matrix/Chonky/Greetings font
ownership remain Epistemos code. Markdown remains the durable authority and
the former Tiptap Epdoc canvas remains a rollback implementation.

### Synchronization and data-loss corrections proved in this slice

- A CodeMirror transaction delta mirror now maintains the live Epdoc Markdown
  without a full-document Swift bridge copy on every keystroke.
- Save requests obtain and write one exact CodeMirror checkpoint before dirty
  state may clear.
- A dirty page-ID switch checkpoints and writes the old page before replacing
  coordinator ownership.
- A clean same-page external Markdown change is pushed into the visible
  CodeMirror canvas.
- Swift reset rollback is generation-aware: a failed reset can restore the old
  mirror only when no later user mutation has advanced it.
- MarkEdit reset construction remains non-user metadata, while every actual
  CodeMirror `docChanged` transaction is retained even if it occurs during the
  reset paint-settle interval.
- The hosted large-document harness retries only WebKit JavaScript transport
  failures. Its insert/delete operations are idempotent, so a retry cannot
  double-insert or over-delete.

### Fail-first and narrowing chain

- R69: focused CodeMirror/KEELSTONE-scale batch passed 10/10. Retained hashes:
  log `5bd35c3cf979499cdfcb9ac32943154e9aaaddd93c2b8cf8937e4f1590d74f7b`,
  executable `5729ea8045a554a48823000817b55d5db264c3837d68b5aaadc9c9bd9d06391f`,
  result aggregate
  `71ebf118805526828a61d18fcf81069ef5d2c61cbe22dfe9e3f1bd56c2c27a0a`.
- R70: the then-current whole App Store KEELSTONE target passed 192/192.
  Retained hashes: log
  `618b8663e7e107dde3dfad635f529203ec2ec347b10d015140760de3e0698bdd`,
  result aggregate
  `56a5189c90a4bea2da797b7db1036e664ed0bbe9d93e56f256982e9071e90de9`.
- R71: expected fail-first run passed 10 and failed 2. It exposed the dirty
  Save clear-before-write defect and dirty page-switch ownership race. Result
  aggregate:
  `79af92f5e61b3b7bf423a047a8746455750d3740b858d1a74b4696de9d25bd97`.
- R72: focused replacement passed 12/12 after the two P0 ordering fixes.
  Hashes: log
  `4082d57d6ad5b3cfb7c5ae199a91098670ef631a0d9eb49b230d330b5abdd2f2`,
  executable
  `db214da869ec058c38c5fa35a191b4778e6cf00c8180655d25a80b579f5d5b2e`,
  result aggregate
  `e3fa1742a500efe73c0f4afc4e29b9e10b9bc1f3f3175b6bbfe50353e219deec`.
- R73: expected P1 fail-first run passed 11 and failed 3. It exposed the
  clean same-page external-update omission, reset-origin contract gap, and a
  hosted delete JavaScript transport failure. Log SHA-256:
  `a2d2c90ba8cc4b632caf2bc7a7a1909e860216a704c91479e82ed05a4eb84740`;
  result aggregate:
  `233d9e01a529cdbe227f554a1e1a5e1355ca87f5fc2a921aad23ccc0caf8fc6e`.
- R74: 13/14 passed. The remaining large-document test showed that a real
  visible edit during reset paint settling was being suppressed and therefore
  never became dirty. Log SHA-256:
  `3fb9da5715d334e81204bf3a574d24e0841fe2f59f0d395d64e7409dd8b0cd8d`;
  result aggregate:
  `4a9e4bc248b3fc22b336efbdb1451fb632cf8d3ccb3b2e4f54c3b067f3a5ebae`.
- R75: 13/14 passed after retaining visible transactions. The insert became
  dirty and saved exactly; the remaining delete leg failed only because the
  WebKit JavaScript request did not execute. Log SHA-256:
  `b45a2f26529a26cc30845522f21852c0bdd19044638164dbfbf4a37c0c9d474d`;
  result aggregate:
  `af6054616bbf639156bfde6cfbfcb03f74cf5ac7490c60a24710f0867509a634`.
- R76: focused replacement passed 14/14. The hosted KEELSTONE-scale fixture
  loaded, inserted, marked dirty, saved the exact fixture plus sentinel,
  scrolled, recovered from one WebKit transport failure with the idempotent
  delete retry, saved again, and ended at the exact original fixture.
  Hashes: log
  `b5b98f9751e383319354aa2f9bd76918d73e8346de5145b58c85b4986982d5c9`,
  executable
  `2e17101d637103668e8584011981bc96660dd36613df0a527046536752019324`,
  result aggregate
  `fa4e13a1687012bd12ed70757c055f569597b112908e8f73870698f66ba5c5fc`.
- R77: the current whole App Store KEELSTONE target passed 196/196 across 4
  suites, with zero failures, skips, or expected failures. The hosted
  large-document CodeMirror test passed in this broad run and again exercised
  the recoverable WebKit transport retry. Hashes: log
  `914046d76237e490236c16e876590df2870f4762fb9088554cd0b5dc0f3ac45b`,
  executable
  `ddbb6f715be06639153bb1c218ee4308bdd1e2bd623996ec20a799a3aef03424`,
  stable result aggregate
  `e11ac831f64f3cd68e4eef6ac92ca14bb1e2facf4939a354fe81d921dec7cecb`.

### Recorded resource preflights for the final narrowing legs

- R74 at 2026-07-15 02:59:01 CDT: 352 dirty entries, 1,592.69 MiB
  swap used, 71% free memory, zero pages throttled, 436 GiB available, and no
  competing Xcode/compiler/model/Epistemos process.
- R76 at 2026-07-15 03:27:29 CDT: 386 dirty entries, 1,576.69 MiB
  swap used, 63% free memory, zero pages throttled, 434 GiB available, and no
  competing process. The R75 app was removed before the fresh R76 product.
- R77 at 2026-07-15 03:36:23 CDT: branch `feat/goose-surface`, HEAD
  `668b52cfb43721de95db102260d9f327ae24e13e`, 386 dirty entries,
  1,576.69 MiB swap used, 62% free memory, zero pages throttled, 433 GiB
  available, and no competing process. The R76 app was removed before the
  fresh R77 product.

Current sole Debug evidence product:

`/private/tmp/Epistemos-FreeV1-Regressions-R77/Build/Products/Debug/Epistemos.app`

R77 result bundle:

`/private/tmp/Epistemos-FreeV1-Regressions-R77/R77.xcresult`

### Current proven state

- The current Debug App Store test target compiles and passes 196 tests.
- Deterministic tests cover exact checkpoint Save, dirty page switching,
  clean external updates, reset/user transaction separation, concurrent
  flush ordering, deletion persistence, teardown replacement safety, and the
  KEELSTONE-scale hosted insert/delete/scroll/save path.
- `git diff --check` is clean after R77.
- No Release archive, distribution artifact, model/provider request, secret
  access, audio operation, or manual visual acceptance run occurred in this
  slice.

### Verification debt and verdict

- Manual evidence is still required for visible MarkEdit fidelity, retained
  Epistemos chrome/palette/fonts, typing/scrolling/selection stability, title
  and info popovers, lens switching, save/reopen, and representative real
  large documents.
- Release/archive artifact gates, exact-archive identity checks, distribution
  review, and the finite serial runtime matrix remain unrun.
- `MarkEditCoreEditorCoordinator.swift` remains a 1,573-line synchronization
  owner and should later be decomposed behind the now-proven contracts; that
  maintainability work is not mixed into this data-loss correction.

**DEBUG REGRESSION PASS / KEELSTONE STILL INCOMPLETE.** R77 closes the current
Debug synchronization blocker chain. It does not prove visual completion,
Release archive correctness, App Store distribution readiness, or the final
KEELSTONE verdict.

### Exact safe next action after R77

1. Load the Epistemos Release Audit procedure before any ship-readiness work.
2. Re-record the mandatory resource preflight.
3. Stop any stale Epistemos test host and delete the R77 app plus stale
   Epistemos archives immediately before producing exactly one fresh
   `Epistemos-AppStore` Release archive.
4. Run every artifact gate against that exact archive. Do not launch if any
   artifact gate is red.
5. If artifact gates pass, run the finite manual/runtime matrix serially with
   correlated logs, then update this document and stop after the final
   KEELSTONE verdict. Do not start another execution key.

---

## R78 Release Archive and Strict Identity Regression — 2026-07-15

Execution key remains:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Owner boundary remains:

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

### R78 resource preflight and one-build enforcement

- Branch: `feat/goose-surface`
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`
- Dirty entries: 352
- Swap used: 1,576.69 MiB of 2,048 MiB
- `memory_pressure -Q`: 68% free
- `vm_stat`: zero pages throttled
- Disk available: 431 GiB
- No competing Xcode/compiler/model/Epistemos process was active. The observed
  `MTLCompilerService` was idle.
- The R77 Debug app was deleted before the R78 archive command.

### Exact R78 archive

Command:

`EPISTEMOS_PRODUCT_EDITION=FREE_V1 xcodebuild archive -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination 'generic/platform=macOS' -archivePath /private/tmp/Epistemos-AppStore-Release-R78/Epistemos-AppStore.xcarchive -derivedDataPath /private/tmp/Epistemos-AppStore-Release-R78/DerivedData -jobs 1 CODE_SIGNING_ALLOWED=NO`

Result: `** ARCHIVE SUCCEEDED **`

Exact archive:

`/private/tmp/Epistemos-AppStore-Release-R78/Epistemos-AppStore.xcarchive`

Exact app:

`/private/tmp/Epistemos-AppStore-Release-R78/Epistemos-AppStore.xcarchive/Products/Applications/Epistemos.app`

The app is universal `x86_64` + `arm64`, bundle identifier
`com.epistemos.appstore`, version `1.0.0 (1)`, minimum macOS 26.0. The archived
Free V1 compilation conditions include `EPISTEMOS_APP_STORE`, `MAS_SANDBOX`,
`EPISTEMOS_FREE_V1`, and `EPISTEMOS_LINK_SUBSTRATE_RT`; they do not include
`EPISTEMOS_EXPERIMENTAL` or `KINDRED_ENABLED`.

The unsigned local archive was ad-hoc signed only for local artifact
verification. `codesign --verify --deep --strict --verbose=4` passed with the
App Store entitlement file. This is not distribution signing, notarization,
or upload evidence.

### Green R78 artifact legs

- `scripts/keelstone-release-gate.sh --appstore-app <R78 app>` passed. Log:
  `/private/tmp/Epistemos-Evidence-Logs/R78-keelstone-gate.log`.
- `scripts/scan_appstore_bundle.sh <R78 app>` passed. Log:
  `/private/tmp/Epistemos-Evidence-Logs/R78-bundle-scan.log`; report directory:
  `/private/tmp/Epistemos-AppStore-Release-R78/appstore-bundle-scan`.
- The exact app has App Sandbox and omits JuneWeb, model manifests,
  DefaultSkills, llama runtime, `agent_core`, and `omega_mcp` resources.
- The CodeMirror/MarkEdit CoreEditor assets and binary handshake markers are
  present.
- Matrix/Matrix Bold/Chonky and the existing font set are present in the exact
  archive. Runtime font registration remains unproven until a later permitted
  manual launch.
- App and dSYM UUIDs match for both architectures.
- The archived privacy manifest matches the source SHA-256:
  `e1c392f10f990c037d16b804d066770599e1a29e78b6ffd512646a168705c406`.

### Red R78 strict identity leg

R43-compatible strict pattern set:

`InferenceState|inferenceState|inference state|june|claude|anthropic|openai|kimi|minimax|deepseek|gguf|agent_core|enableWebSearch|OpenAI|Anthropic|Kimi|MiniMax|DeepSeek|Local GGUF|EPISTEMOS_GGUF_TOOL_GRAMMAR_V0`

Results:

- AppIntents: 0 matches
- Resources: 0 matches
- Forbidden paths: 0 matches
- Release executable: 32 broad matches, report SHA-256
  `fdca669475c1af14c992a2aba3e7716ba78ff22f104fb2936259cc33f6b0f7cb`

Inspection separates benign substring data such as Turkish localization text
containing `kimi` and `America/Juneau` from genuine exact product identity.
The genuine compiled identifiers include `_claudeManagedSessionsEnabled`,
`epistemos.kimiModel`, `gguf`, `june`, `openai`, `anthropic`, and `claude`.

### Current verdict and safe boundary

**RELEASE ARCHIVE COMPILES / STRICT IDENTITY RED / DO NOT LAUNCH.** R78 is not
valid runtime or ship evidence. The next action is to make the exact executable
identity gate fail deterministically, trace every genuine hit to current
source, surgically restore Free-V1 compile exclusion, rerun the Debug
regression target, then preflight and replace R78 with one fresh archive. No
manual launch or runtime matrix may begin until every artifact gate is green.

---

## R79-R85 Free V1 Identity Repair and Owner Test Build — 2026-07-15

Execution key remains:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Owner boundary remains:

> “i still want my chrome and my epsitemos palette stuff but new surface for
> epdoc”

The Epdoc canvas remains the restricted MarkEdit/CoreEditor CodeMirror 6
replacement. Epistemos still owns the window chrome, toolbar, palette,
title/info affordances, and bundled display fonts. This repair slice changes
only Free V1 compiled identity and the generated UniFFI runtime-kind names
that caused the R78/R83 Release artifact regressions.

### Fail-first and repair chain

- R79 stopped at compile time because Free V1 still referenced the paid-only
  `BackendRuntimeControlPlane` from `AppBootstrap`. The paid construction and
  property were compile-gated out of Free V1.
- R80 stopped at compile time because `TriageService` still referenced the
  paid-only `BackendSteeringHints`. Free V1 now returns no steering-token
  override without parsing that paid payload.
- R81 passed 197 tests in four suites.
- R82 added the explicit no-paid-steering-payload contract and passed 198
  tests in four suites.
- R83 produced a Release archive, but the exact executable identity gate
  remained red on the single whole string `gguf`. Mach-O reflection-string
  tracing mapped it to generated UniFFI `RuntimeKind` case names, not to a
  live Free V1 backend.
- The stable generator boundary now passes `--free-v1` from
  `build-epistemos-core.sh` to `patch-uniffi-bindings.py`. Free generation
  deterministically neutralizes only the three generated runtime-kind names;
  paid generation preserves the original generated names. Direct two-lane and
  idempotence smoke checks passed.
- R84 passed the current complete App Store KEELSTONE test target: 198 tests
  in four suites, zero failures. The hosted large-document CodeMirror test
  passed in 2.495 seconds within that run.

Accepted log SHA-256 values:

- R79 compile-red: `36b63f71afb2df1dc47c8fc532477136b39f7e1575faf831aa4165f7f9940aa4`;
- R80 compile-red: `6b70f2020942efc9088cd45225d55a007afb5ce0a1927610396d3c85af1e4174`;
- R81 green: `0f5e6915ce13801f8be73c18e74367dd1172bda8b00b6d45657a0f3c6a8f5327`;
- R82 green: `a99922e0879188fa5f72885caae3f39daa499c1bbc00dab45992447c87e0dff9`;
- R83 archive: `d87211b563304ccb5555a3385d87b1f9d00d1e2e9309b793388d8fa4b266fe73`;
- R84 green: `15a03f912f9d368536be472b5395b88c97118686f0470301acc3845488ca1c8e`.

The invalid R83 archive and all stale Epistemos build products were removed
before the accepted R84/R85 legs. Retained logs and result evidence were not
deleted.

### Exact R85 Release archive and artifact gates

The fresh R85 preflight passed with branch/local/origin/handoff identity exact
at `668b52cfb43721de95db102260d9f327ae24e13e`, 354 dirty entries,
1,903.56 MiB swap used, 65% free memory, zero throttled pages, 469 GiB
available disk, and no competing Xcode/compiler/model/Epistemos process.

The one retained archive is:

`/private/tmp/Epistemos-AppStore-Release-R85/Epistemos-AppStore.xcarchive`

The exact app is:

`/private/tmp/Epistemos-AppStore-Release-R85/Epistemos-AppStore.xcarchive/Products/Applications/Epistemos.app`

R85 archive result: `** ARCHIVE SUCCEEDED **`. Archive log SHA-256 is
`22925d8315dfc01375fefcd028e10fa94af4705738b5f13d8dad93a5ed623a63`.
The only compiler warnings are the existing unnecessary `await` in
`TextCapturePipeline.swift` and unused `try?` result in
`LiteParsePDFImportController.swift`; warning-free and distribution-ready
claims remain prohibited.

Unsigned identity was bundle `com.epistemos.appstore`, version 1.0.0 build 1,
minimum macOS 26.0, universal `x86_64 arm64`. Unsigned executable SHA-256 was
`c1095f357ff42d638e7996047cb3dea8ca6321eb49675a66d414709fe16ca9ba`.
The archive `Info.plist` SHA-256 is
`d933374b3ae9d57eadb2eed4d0ed39911b921b49ec613dee19ae3c6047befa86`.

The app and nested dylibs were signed inside-out with a local ad-hoc evidence
signature and the App Store entitlements. Strict deep verification passes.
Effective entitlements are App Sandbox, the shared application group, audio
input, app-scope bookmarks, user-selected read/write access, and network
client. There is no TeamIdentifier; this is not Apple distribution signing,
notarization, validation, or upload evidence. Post-sign executable SHA-256 is
`54d8fd592f7bbbb1095e2544a05794233ae4e7de4503f69d968a721cdffc8f72`.
App and dSYM UUIDs match for both architectures.

The integrated KEELSTONE gate and standalone bundle scanner both pass. Their
log SHA-256 values are respectively
`20f66af9341a6f919a6e3fb100a0b1985b021d5255d8aef536c674c65269bc8f`
and
`953175c9cb3863c8c7c3f975d952b3343151c691b4125e44555f4f9bf1f56c19`.
The exact whole-string identity gate is clean for paid provider, June,
inference, agent, and generated `gguf` identity. JuneWeb, model manifests,
agent skills, local inference runtime, `agent_core`, `omega_mcp`, parked/
retired/1Code strings, quarantine, prohibited linkage, and packaged research
residue are absent.

Independent direct audit also proves:

- main privacy manifest is byte-identical to source, SHA-256
  `e1c392f10f990c037d16b804d066770599e1a29e78b6ffd512646a168705c406`;
- `CoreEditor/index.html` and its compiled chunks exist, and both the native
  `epistemosMarkEditCoreEditor` bridge marker and compiled
  `MarkEdit.codemirror` runtime marker are present;
- `ChonkyPixels.ttf`, Matrix Dots, Matrix Bold, and Matrixtype Display are
  present in the exact app;
- deterministic signed app-tree SHA-256 is
  `e2c9e4a7b56e6a876eab19c6486cf5040ce0ec0620eea13353d3c84d88ed86c7`.

The complete launch preflight passed after two read-only assertion corrections
for a minified JavaScript extractor and shell field/process matching. No
archive or source byte changed. At the accepted threshold check, swap used was
1,591.56 MiB, free memory was 64%, pages throttled were zero, and competing
process count was zero. Branch/local/origin/handoff remained exact.

### Owner-visible R85 test session opened

The owner requested:

> “let me test it out please continue building on it byt i want to test it so
> build s i can use”

The fresh isolated runtime tuple is rooted at:

`/Users/jojo/Library/Containers/com.epistemos.appstore/Data/tmp/Epistemos-R85-Owner-Test-20260715-0553`

It uses separate `ApplicationSupport` and `AppGroup` roots and stable suite
`com.epistemos.audit.runtime.keelstone.r85.20260715.owner`. It does not use the
owner's normal vault or production preferences.

Two initial direct-executable launches became active and recorded three
visible windows, but the tool command boundary cleaned up their child
processes. There is no macOS crash report, app crash record, or app-owned
termination event. The corrected launch uses macOS Launch Services, with the
app process parented to PID 1 so it persists independently of the command
session. No source change or new build was needed.

The runtime matrix and owner acceptance remain **IN PROGRESS**. Per the owner:

> “io oet u know when im done.”

Do not touch the visible app until the owner finishes. After that signal,
collect bounded correlated evidence, record the owner's observed behavior,
repair only failed evidence legs, and stop after the final KEELSTONE verdict.
Do not begin another execution key.

---

## R86 Markdown Surface-Routing Compile Proof and Filter Debt — 2026-07-15

Execution key remains:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

Later owner runtime reports supersede the R85 waiting boundary: the app quit or
closed repeatedly, Markdown surfaces stopped switching, and large rich-document
editing retained hangs, restored deletions, disappearing text, and viewport
jumps. The owner then explicitly separated Epdoc into an independent JSON-native
document and required CodeMirror/TextKit-style viewport rendering for its rich
editor. These are active repair requirements, not proven runtime behavior.

### R86 preflight and one-build enforcement

- Branch: `feat/goose-surface`
- HEAD/origin/handoff publication: `668b52cfb43721de95db102260d9f327ae24e13e`
- Dirty entries: 354 at preflight
- Swap used: 1,439.56 MiB
- `memory_pressure -Q`: 63% free
- `vm_stat`: zero pages throttled
- Disk available: 467 GiB
- No active competing Xcode/compiler/model/Epistemos process was observed; the
  retained launchd Metal compiler services were idle at zero CPU.
- The stale R85 archive/app and all enumerated Epistemos DerivedData products
  were removed before the R86 test build. Retained evidence logs/results were
  preserved.

### Exact R86 command and outcome

The focused `Epistemos-AppStore` Debug test command compiled the current app and
test bundle successfully into exactly one current product:

`/tmp/Epistemos-AppStore-R86-DerivedData/Build/Products/Debug/Epistemos.app`

The executable SHA-256 is
`9f46a05a16cd91fb763c88aad5721413ce7800a7bb3a4e3b9efb0c0465df84a2` and
the app occupies 425 MiB. The result bundle is:

`build/xcode-results/2026-07-15-064802-42780.xcresult`

`xcodebuild` returned `** TEST SUCCEEDED **`, but the two individual
`-only-testing` selectors matched the suite and executed zero tests. The result
bundle contains no individual test nodes. Therefore R86 is compile evidence
only; it is not a pass for the new active-surface flush-routing assertions.

### Current verdict and exact next action

**INCOMPLETE — CURRENT SOURCE COMPILES; FOCUSED TEST FILTER EXECUTED ZERO
TESTS; NO RUNTIME OR RELEASE CLAIM.** The next verification leg must select the
whole Swift Testing suite or otherwise prove nonzero execution, after a fresh
resource preflight and one-build cleanup. In parallel, the independent Epdoc
replacement must use a versioned canonical JSON schema and real block viewport
with bounded overscan; legacy `content.pm.json` bytes require a verified,
receipt-bearing migration rather than silent replacement.

---

## R87 Nonzero Surface-Routing Regression Proof — 2026-07-15

Execution key remains:

`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`

The replacement preflight passed on branch `feat/goose-surface` at exact HEAD
`668b52cfb43721de95db102260d9f327ae24e13e`, with 357 dirty entries,
1,439.56 MiB swap used, 60% free memory, zero pages throttled, 473 GiB disk
available, and no active competing Xcode/compiler/model/Epistemos process. The
single R86 app/DerivedData product was deleted before R87. Retained logs and
result bundles were preserved.

The complete App Store KEELSTONE target ran serially from a clean R87 build
location. Exact result bundle:

`build/xcode-results/2026-07-15-070803-49507.xcresult`

Result: `** TEST SUCCEEDED **`; 200 tests in 4 suites passed, zero failed,
zero skipped, and zero expected failures. The two new direct contracts both
executed and passed:

- `visible editor surface owns flush routing even when Markdown Source exists`;
- `Markdown notes expose Prose Preview and Source but not independent Epdoc`.

The hosted `CodeMirror` large-Markdown load/edit/delete/scroll/save test also
executed and passed in 2.635 seconds. That is current hosted Markdown evidence,
not proof for the replacement JSON-rich Epdoc viewport.

Retained hashes:

- test log SHA-256:
  `a18f0c87943b57f4b1a63cae0f869abba4553f025f37a5d06f990ba1439902ca`;
- current Debug executable SHA-256:
  `b412b177d33c067cd5811bd4e792d6c18c0af37a4a1a017635a19d9e240abc9b`.

Exactly one current app product remains at:

`/tmp/Epistemos-AppStore-R87-DerivedData/Build/Products/Debug/Epistemos.app`

### Current verdict and exact next action

**R87 DEBUG REGRESSION GREEN / KEELSTONE STILL INCOMPLETE.** The surface-mode
ownership and routing repair has automated proof. The next source batch is the
independent `.epdoc` storage migration contract: versioned Epistemos rich JSON,
legacy ProseMirror-byte preservation plus receipt, and engine-neutral
projection seams. Only after that contract is green may a viewport-capable
Plate/Slate editor adapter replace the legacy Tiptap canvas and be tested with
the full Keelstone fixture. No Release archive, owner launch, or final runtime
claim was made in R87.
## R88 — JSON-Native Epdoc / TextKit 2 Viewport Vertical Slice (In Progress)

Date: 2026-07-15

Owner-approved architecture now separates standalone Epdoc from the Markdown
lens family. Epdoc uses canonical `content.json`; legacy `content.pm.json`
loads through a one-way migration with the exact original and a digest receipt
under `migrations/`. Standalone Epdoc now has a distinct native TextKit 2
canvas candidate behind the existing Epdoc toolbar. Markdown Document remains
explicitly CodeMirror.

Touched scope for this leg:

- `Epistemos/Models/EpdocContentEnvelope.swift`
- `Epistemos/Models/EpdocContentCompatibilityProjection.swift`
- `Epistemos/Models/EpdocPackage.swift`
- `Epistemos/Views/Epdoc/EpdocTextKit2EditorSession.swift`
- `Epistemos/Views/Epdoc/EpdocTextKit2EditorView.swift`
- `Epistemos/Views/Epdoc/EpdocEditorChromeView.swift`
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Sync/ReadableBlocksProjector.swift`
- `Epistemos/Engine/EpdocGraphProjector.swift`
- `Epistemos/Models/ProseMirrorMarkdownProjector.swift`
- `Epistemos/Views/Notes/MarkdownDocumentSurface.swift`
- `EpistemosTests/EpdocPackageTests.swift`

Current proof is limited to source inspection, `swiftc -parse`, and
`git diff --check`. Deferred verification debt before any behavior claim:

- compile the entire Free V1 App Store target and run a nonzero exact test
  selection after the mandatory resource preflight and one-current-build
  cleanup;
- repair all type/actor errors found by the actual target compiler;
- add runnable App Store target tests for canonical package migration,
  bounded affected-block edits, stable IDs, undo/redo, Unicode/IME, and
  viewport instrumentation;
- prove the exact Keelstone large-document load/edit/backspace/scroll/save/
  reopen matrix in the native canvas;
- prove legacy package rollback and explicit Markdown/PDF export boundaries;
- collect exact Release archive and manual runtime evidence only after those
  narrow gates are green.

Verdict: **INCOMPLETE — implementation and verification continue serially.**

### R88 exact compile result

The clean serial App Store test build stopped before test execution with exit
65. Swift 6 diagnosed twelve default-actor isolation errors in the private
scalar/emptiness helpers of
`EpdocContentCompatibilityProjection.swift`. The failure was contained to the
new compatibility adapter; no app launch or runtime evidence began. Result
bundle:

`build/xcode-results/2026-07-15-075454-71814.xcresult`

The adapter was surgically corrected by moving scalar extraction into the
already `nonisolated` projection type and deciding attribute emptiness from
those extracted values. `swiftc -parse` and `git diff --check` pass for the
correction. The partial R88 product is not evidence and must be deleted before
the next clean build.

### R89 retry preflight

- Branch: `feat/goose-surface`
- HEAD: `668b52cfb43721de95db102260d9f327ae24e13e`
- Dirty entries: 366
- Swap used: 1,423.56 MiB
- `memory_pressure -Q`: 59% free
- Pages throttled: 0
- Disk available: 473 GiB
- No active Xcode build, Swift/Clang/Rust compiler, model runtime, or Epistemos
  app process was observed. A long-lived unrelated Python HTTP server located
  inside the Xcode bundle was idle at zero CPU and is not a compiler/build
  process.

All retained owner thresholds passed. The partial R88 DerivedData/app product
will be deleted before the clean serial R89 command; logs and result bundles
remain retained.

### R89 exact compile result

R89 proved the compatibility adapter correction compiled, then stopped before
tests with exit 65 on one AppKit type mismatch in the new native editor's Find
menu action. `NSFindPanelAction.rawValue` is `UInt` while `NSMenuItem.tag` is
`Int`. Result bundle:

`build/xcode-results/2026-07-15-080115-75448.xcresult`

The line now uses the explicit platform-safe `Int(...)` conversion. The
corrected region was re-read; `swiftc -parse` and `git diff --check` pass. No
runtime or viewport behavior was exercised. The partial R89 app/DerivedData is
not evidence and must be deleted before R90.

### R90 retry preflight

- Branch/HEAD unchanged: `feat/goose-surface` at
  `668b52cfb43721de95db102260d9f327ae24e13e`
- Dirty entries: 366
- Swap used: 1,423.56 MiB
- Free memory: 53%
- Pages throttled: 0
- Disk available: 473 GiB
- No active competing build/compiler/model/Epistemos process; the same idle,
  unrelated Python server remained at zero CPU.

The owner thresholds pass. R89 DerivedData/app will be deleted before the one
clean serial R90 build; no archive exists.

### R90 exact compile and regression result

The clean serial Free V1 `Epistemos-AppStore` Debug test leg completed with
`** TEST SUCCEEDED **`. Exactly 200 tests in 4 suites passed in 7.406 seconds;
zero failures were reported. The hosted CodeMirror Keelstone-scale Markdown
load/edit/delete/scroll/save regression executed and passed in 2.750 seconds.

Retained evidence:

- result bundle:
  `build/xcode-results/2026-07-15-080749-78604.xcresult`;
- test log:
  `build/logs/2026-07-15-epdoc-textkit2-r90.log`;
- test-log SHA-256:
  `d7daf5eda393f508361fdad9a096b0b79085fca54934d99bad2bf8c4a406dfd1`;
- result `Info.plist` SHA-256:
  `ecfe44f472bfa0c5b759fed0de9a3332540461d743b1362df3caa24b23d098a3`;
- Debug executable SHA-256:
  `1727a91900c3cf7f67c8be2a49a44b9e58941ee99f2d6f731f51d584dd82028e`.

Exactly one current app product remains at:

`/private/tmp/Epistemos-AppStore-R90-DerivedData/Build/Products/Debug/Epistemos.app`

It occupies 436,200 KiB. R90 proves that the JSON-native Epdoc/TextKit 2
vertical slice compiles with the Free V1 App Store target and does not regress
the existing 200-test Keelstone suite. It does **not** prove the new native
Epdoc session, viewport behavior, rich JSON migration, 58k/67k-word runtime,
Release behavior, or owner-visible editor quality because those exact tests
are not yet members of the runnable App Store suite.

### Current verdict and exact next action

**R90 DEBUG REGRESSION GREEN / KEELSTONE STILL INCOMPLETE.** Add a narrow,
runnable App Store test seam for the canonical Epdoc envelope, receipt-bearing
legacy migration, affected-block native-session edits, checkpoint encoding,
and viewport instrumentation. Then run the exact large-document native Epdoc
matrix from a fresh one-build/preflight leg. No archive or final runtime claim
has begun.

### R91 canonical Epdoc and native viewport preflight

- Branch/HEAD unchanged: `feat/goose-surface` at
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Dirty entries: 367.
- Swap used: 4,014.44 MiB, below the owner-approved 16,384 MiB ceiling.
- Free memory: 70%.
- Pages throttled: 0.
- Disk available: 469 GiB.
- No active Xcode build, Swift/Clang/Rust compiler, model runtime, or
  Epistemos app process was observed.

All retained thresholds pass. The retained R90 log/result hashes are recorded
above; its single Debug app/DerivedData product will be removed before R91.
The R91 focused suite adds active App Store target coverage for canonical
rich-JSON validation, legacy migration semantics/receipt, affected-block
session checkpoint/reopen, TextKit 2 viewport ownership, and a generated
72,000-word bounded viewport range. These are automated foundation checks, not
yet owner-visible editing/scrolling/runtime proof.

### R91 exact canonical Epdoc and native viewport result

The clean serial Free V1 `Epistemos-AppStore` Debug test leg completed with
`** TEST SUCCEEDED **`. Exactly 205 tests in 5 suites passed in 7.392 seconds;
zero failures were reported. The new `KEELSTONE Canonical Epdoc and Native
Viewport` suite passed all 5 tests in 0.259 seconds:

- canonical rich JSON round-trip and duplicate stable-ID rejection;
- receipt-bearing legacy ProseMirror migration with original-byte and opaque
  payload preservation;
- one-block native-session mutation plus exact checkpoint/reopen;
- ownership of a real TextKit 2 `NSTextViewportLayoutController`;
- a generated 4,500-block, exactly 72,000-word canonical Epdoc projected
  into the native canvas with a nonempty viewport range bounded below the full
  document length. This exact large-document viewport test passed in 0.248
  seconds.

The existing hosted CodeMirror Keelstone-scale Markdown
load/edit/delete/scroll/save regression also passed in 2.552 seconds.

Retained evidence:

- result bundle:
  `build/xcode-results/2026-07-15-epdoc-textkit2-r91.xcresult`;
- test log:
  `build/logs/2026-07-15-epdoc-textkit2-r91.log`;
- test-log SHA-256:
  `48b234475453bdcc420b12950c01c52073fbf093a3c8fa292d532fa7775fcc61`;
- result `Info.plist` SHA-256:
  `77a8fa9a7a7df86ceef67926ee577e052de2d50f368f57dbc3ebfa451d937aca`;
- Debug executable SHA-256:
  `af1dcebc87da9515fb4eed120c4dfc68082365845a961eafe618bbba5d999bbc`.

Exactly one current app product remains at:

`/private/tmp/Epistemos-AppStore-R91-DerivedData/Build/Products/Debug/Epistemos.app`

It occupies 436,436 KiB. R91 proves the native Epdoc canvas is backed by
TextKit 2 viewport layout and that a generated Keelstone-scale rich document
does not require a full-document viewport range in this automated setup. It
does **not** yet prove owner-visible 67k-word typing, backspace persistence,
selection/IME/undo, beginning/middle/end scrolling, save/close/reopen, rich
attachment rendering, or subjective smoothness. No Release archive was
created and no final runtime verdict is claimed.

### Current verdict and exact next action

**R91 NATIVE VIEWPORT FOUNDATION GREEN / KEELSTONE STILL INCOMPLETE.** Extend
the native AppKit harness over the same generated large Epdoc to exercise real
`NSTextView` edit/backspace and beginning/middle/end viewport movement, then
checkpoint and reopen the canonical JSON with exact digest/content checks.
Run that focused matrix only after a fresh resource preflight and deletion of
the R91 DerivedData/app product. Owner-visible manual inspection follows the
automated interaction gate; Release/archive work remains deferred.

### R92 native large-document interaction preflight

- Branch/HEAD unchanged: `feat/goose-surface` at
  `668b52cfb43721de95db102260d9f327ae24e13e`.
- Dirty entries: 367.
- Swap used: 3,982.44 MiB, below the owner-approved 16,384 MiB ceiling.
- Free memory: 74%.
- Pages throttled: 0.
- Disk available: 469 GiB.
- No active Xcode build, Swift/Clang/Rust compiler, model runtime, or
  Epistemos app process was observed.

All retained thresholds pass. The R92 test adds real `NSTextView` navigation
from beginning to middle to end over the generated 72,000-word Epdoc, bounded
viewport assertions at each location, replacement plus backspace through the
native delegate/reconciliation path, and exact canonical checkpoint/reopen
content and revision checks. The R91 app/DerivedData product will be removed
before the one clean serial R92 build; its log and result bundle remain as
retained evidence.

### R92 exact native large-document interaction result

The clean serial Free V1 `Epistemos-AppStore` Debug test leg completed with
`** TEST SUCCEEDED **`. Exactly 206 tests in 5 suites passed in 7.659 seconds;
zero failures were reported. The `KEELSTONE Canonical Epdoc and Native
Viewport` suite passed all 6 tests in 0.647 seconds. Its new real AppKit
interaction leg passed in 0.391 seconds and proved, over a generated
4,500-block, exactly 72,000-word canonical Epdoc, that:

- beginning, middle, and end navigation produce nonempty TextKit 2 viewport
  ranges that advance through the document while remaining bounded below the
  full document length and below the test's 100,000-character viewport cap;
- native `NSTextView.insertText` enters the existing delegate and
  affected-block reconciliation path;
- native `deleteBackward` removes the requested character without the deleted
  source text being restored;
- only the targeted stable block changes, its revision advances by exactly
  two mutations, and the session remains dirty until checkpoint;
- the canonical rich JSON checkpoint reopens with the edited block content
  and revision intact, after which the session is clean.

The five earlier canonical-envelope, legacy-migration, native-session,
TextKit 2 ownership, and bounded large-document viewport checks also passed.
The hosted CodeMirror Keelstone-scale Markdown load/edit/delete/scroll/save
regression passed in 2.433 seconds.

Retained evidence:

- result bundle:
  `build/xcode-results/2026-07-15-epdoc-textkit2-r92.xcresult`;
- test log:
  `build/logs/2026-07-15-epdoc-textkit2-r92.log`;
- test-log SHA-256:
  `c18ef1f8f5d9818b752242b1f189bd31fde16b10329703164a37017e6656b710`;
- result `Info.plist` SHA-256:
  `3d9eab43596a6c6f09998f944ff21c711a10324f475bb84d534b4294d0de1039`;
- Debug executable SHA-256:
  `335ba80ba23303ed0294e0fd679f85545028dfb557558d750d5f2b5b89f4afce`.

Exactly one current app product remains at:

`/private/tmp/Epistemos-AppStore-R92-DerivedData/Build/Products/Debug/Epistemos.app`

It occupies 436,512 KiB. R92 is current exact automated evidence that the
standalone JSON-native Epdoc uses a real TextKit 2 viewport architecture and
that one large-document edit/backspace/checkpoint/reopen path behaves
correctly. It does **not** prove subjective typing/scrolling smoothness in the
owner-visible app, multi-block selection, Shift-selection, IME composition,
Unicode edge cases, undo/redo, structural split/merge identity, rich
attachments/lists/checklists/tables, full `NSDocument` save/close/reopen, or
Release/archive behavior.

### Current verdict and exact next action

**R92 NATIVE LARGE-DOCUMENT INTERACTION GREEN / KEELSTONE STILL INCOMPLETE.**
Use the retained R92 app as the one current product for owner-visible serial
inspection of standalone Epdoc creation, editing, beginning/middle/end
scrolling, backspace persistence, checkpoint/save, close, and reopen. Record
correlated evidence without rebuilding. Fix only a failed evidence leg. If
the manual leg passes, extend narrow automated coverage to selection,
IME/Unicode, undo/redo, structural split/merge, and rich-node rendering before
any Release archive or final Keelstone verdict.

### R93 native semantics implementation and verification debt

The retained R92 app remains the last compiled green artifact and is still the
one current running product. Current source has advanced beyond it and must not
be attributed to R92. No R93 build or test has begun.

The generated R91/R92 fixture count was re-audited: each of 4,500 blocks has a
numeric index plus fifteen `viewport` tokens, so the session counts exactly
72,000 words. Earlier `67.5k` descriptions above were corrected; the test
labels now say `72k-word`. This strengthens the size leg but does not broaden
its behavioral proof.

Current fail-first/implementation batch:

- `EpdocTextKit2EditorSession.swift`: parent/stable-ID indexing plus bounded
  sibling `splitBlock` and `mergeBlocks` operations, UTF-16 scalar-boundary
  validation, exact revision/count maintenance, replacement reindexing, and
  engine-neutral presentation context for list/checklist nesting and table
  cell/header roles. A list marker is assigned only to the first editable leaf
  in its owning item so a multi-paragraph item does not render duplicate
  bullets or checkboxes;
- `EpdocTextKit2EditorView.swift`: semantic marks are no longer erased by
  visual restyling; inline object placeholders carry canonical node JSON so an
  adjacent edit can reconstruct their type, attributes, marks, children, and
  stable ID; marked text is withheld from session reconciliation/checkpoint
  until commit; cross-block replacements are now intercepted before AppKit
  mutates native storage, committed once to the canonical session, projected
  only over the consumed block range, and registered as one exact session
  snapshot undo/redo operation. The projection now maps the noncanonical
  presentation context to native TextKit 2 `NSTextList` paragraph styles and
  bounded table header/cell styling without writing view state into Epdoc JSON;
- `EpdocDocument.swift`: explicit Save now flushes the live native editor
  boundary through the same synchronous provider that every package write,
  autosave, and close uses before taking its package snapshot; both in-memory
  manifest mutations and package writes remove the retired `complexity`
  metadata key while preserving supported metadata;
- `EpdocContentCompatibilityProjection.swift`: canonical bold/italic map to
  ProseMirror `strong`/`em`, matching the Markdown projector;
- `EpdocCanonicalContentTests.swift`: new fail-first coverage for split/merge
  identity, invalid Unicode splits, cross-block semantic selection, Unicode
  edit/undo/redo, atomic cross-block replacement undo/redo with exact block-ID
  restoration, a real `moveToEndOfDocumentAndModifySelection` responder action
  spanning beyond the active large-document viewport while layout remains
  bounded, IME composition deferral, inline attachment preservation,
  nested editable-leaf projection, derived Markdown marks, and an actual
  `NSDocument.write(to:ofType:)` package-disk close/reopen round trip that
  first requires the live-editor flush provider to supply the pending session
  checkpoint, then checks canonical revision/text/marks, package asset bytes,
  document identity, and absence of an autosaved Markdown shadow. The
  nested-rich-block test also requires first-leaf-only native list and
  checklist markers, no duplicate marker on a continuation paragraph in the
  same item, and retained table-cell presentation context.
- `EpdocDocumentTests.swift`: stale ProseMirror and complexity-meter assertions
  now use the versioned canonical Epdoc envelope and require retired complexity
  metadata to be stripped without losing supported manifest metadata.
- `EpdocPackage.swift`: canonical `content.json` is rejected when its
  `document_id` does not equal the owning `manifest.json` ID; the Keelstone
  suite now covers both package-open ownership rejection and live-document
  checkpoint ownership rejection without dirtying or replacing good content.

Source parsing and `git diff --check` pass. The batch is **UNBUILT AND
UNVERIFIED**. Deferred checks: Swift 6 type checking, all new test assertions,
the existing 206-test regression set, exact log/result hashes, and the one
current app identity. The new disk lifecycle test is also unbuilt and is not
yet evidence of successful persistence. The new `NSTextList` marker formats,
ordered-list numbering, table styling, and first-editable-leaf rule are also
unbuilt and not current runtime evidence. Key risks still open even if this
batch passes: cross-container selection policy; list-aware Return semantics
(the current generic split does not yet create or exit canonical list items);
ordered-list continuity; interactive checklist toggling; Shift-Return and
forward-delete structural wiring; marked-text commit behavior under a real
input source; rich native attachment rendering; package disk close/reopen; and
visible performance.

Verification trigger: after the owner-visible R92 inspection process exits,
run a fresh resource preflight, delete the R92 app/DerivedData product under
the one-build rule, and execute exactly one clean serial App Store test leg.

### R92 retained-app memory observation while R93 remains unbuilt

At `2026-07-15T14:48:50Z` through `14:48:54Z`, retained R92 PID `4450` was
idle at `0.0%` CPU and its resident-set samples were `633,808`, `633,776`, and
`633,776` KiB. Earlier in the same run it had sampled near `189,392` KiB. The
process did not emit an Epdoc/error/fault unified-log message in the inspected
15-minute window. The interaction or document state responsible for the
increase was not correlated, so this is an exact observation, **not** a leak
finding, performance pass, or causal claim. Keep it as a prompt for the later
large-document Instruments/owner-visible memory leg; do not attribute the
unbuilt R93 source changes to this running R92 artifact.

### R93 native semantics decisive preflight

After the owner reported that R92 inspection was finished, retained PID
`4450` was no longer present. Only
`/private/tmp/Epistemos-AppStore-R92-DerivedData` remained as an app-product
location; it was removed while the R92 log and `.xcresult` stayed retained.
The decisive preflight immediately before R93 recorded:

- branch/HEAD: `feat/goose-surface` at
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- dirty entries: 368, preserved without reset or overwrite;
- swap used: 3,678.44 MiB, below the 16,384 MiB owner ceiling;
- system free memory: 72%;
- pages throttled: 0;
- available Data-volume disk: 471 GiB;
- no Epistemos app, `xcodebuild`, Xcode build service, Swift/Clang compiler,
  or llama/Ollama/MLX model runtime process; and
- no remaining Epistemos DerivedData app product or retained app/archive under
  the inspected build locations.

All retained thresholds passed. This authorizes exactly one clean serial R93
App Store test build in a fresh DerivedData location; it does not predeclare
the result.

### R93 native semantics compiler result — RED

The one clean serial R93 leg stopped during app compilation with exit code 65;
no test began. Swift 6 rejected the two-argument `NSTextList` bullet and
checklist initializers because `options: []` selected an array literal where
the imported AppKit overload requires an integer option value:

- `EpdocTextKit2EditorView.swift:218:69`: cannot convert `[Any]` to `Int` for
  the bullet marker; and
- `EpdocTextKit2EditorView.swift:228:30`: the same mismatch for the checklist
  marker.

The three-argument ordered-list initializer did not emit this error. No other
compiler or test finding was reached, so R93 proves neither the new semantics
nor a broader regression verdict. Retained failed evidence:

- log: `build/logs/2026-07-15-epdoc-textkit2-r93-compiler-red.log`;
- log SHA-256:
  `d43e35293e251dad2f95c7561b24774e2fdf9313a5c710afe5e76115b79ef038`;
- result:
  `build/xcode-results/2026-07-15-epdoc-textkit2-r93-compiler-red.xcresult`;
- result `Info.plist` SHA-256:
  `5115874a8a16ef0db0281bea8939bbaac5b1d55dfa1b1c8d59525eabe0576631`.

The partial R93 DerivedData/app product was deleted. Exact next action: change
only those two imported-API option arguments to zero, re-run parsing and diff
checks, then perform a fresh resource preflight before one clean serial R94
retry.

### R94 focused compiler-fix retry preflight

The two rejected two-argument `NSTextList` calls now pass `options: 0`; source
parsing and `git diff --check` pass. The fresh retry preflight recorded the
same branch/HEAD and 368 preserved dirty entries, 3,678.44 MiB swap used, 57%
free memory, zero throttled pages, 471 GiB available disk, no competing
Epistemos/Xcode/Swift/Clang/model process, and no remaining Epistemos
DerivedData product. All retained thresholds pass. R94 is authorized as one
clean serial retry and remains unproven until its exact result completes.

### R94 native semantics test result — RED

R94 compiled the production `Epistemos-AppStore` target and the Keelstone test
target, then executed 220 tests in 5 suites. The run failed after 8.628 seconds
with 11 assertion issues in four named test cases representing three native
reconciliation seams:

- cross-block replacement committed the canonical one-block survivor, but the
  visible projection contained an extra trailing newline;
- Unicode edit/undo/redo and marked-text commit did not reconcile the expected
  replacement into the canonical block; and
- an adjacent edit reconstructed only text and dropped the canonical inline
  image node and its stable identity.

The nested list/checklist/table projection test passed, including the
first-editable-leaf-only marker rule. The broader Markdown lens-switching suite
also passed, including the hosted Keelstone-scale CodeMirror edit/delete/
scroll/save test. Those passing neighbors do not override the Epdoc failures.

Retained failed evidence:

- log: `build/logs/2026-07-15-epdoc-textkit2-r94-test-red.log`;
- log SHA-256:
  `9a9d75e4d4f60a4359344f522a44f7258a0ca776501ceebe23272cfcd281dd08`;
- result:
  `build/xcode-results/2026-07-15-epdoc-textkit2-r94-test-red.xcresult`;
- result `Info.plist` SHA-256:
  `2f0600a653209eafb1eecf440d04c085f450f0f60b34700a373a8251d499b0d0`.

The partial R94 DerivedData/app product was deleted. The owner also clarified
that the earlier retained R92 app interaction did not visibly reach Epdoc, so
it must not be counted as owner-visible Epdoc evidence. Exact next action:
inspect the native edit reconciliation path and the fail-first fixtures,
repair only these three seams, run parse/diff guards, then perform a fresh
resource preflight before one clean serial retry. No runnable owner-inspection
artifact exists at this boundary.

### R95 longest-effective-block-range retry preflight

The R94 failures shared one attributed-text boundary: `range(of:in:near:)`
returned the current effective run instead of the longest range carrying the
same canonical block ID. That truncated reconciliation at Unicode/style/
attachment run boundaries and left structural newlines outside cross-block
replacement. The surgical correction now asks `NSTextStorage` for the longest
effective `.epdocBlockID` range, including the fallback lookup; source parsing
and `git diff --check` pass.

The fresh R95 preflight recorded branch `feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, 368 preserved dirty entries,
3,494.38 MiB swap used, 59% free memory, zero pages throttled, 471 GiB
available disk, no competing Epistemos/Xcode/Swift/Clang/model process, and no
retained Epistemos app/archive product in the inspected build locations. All
owner thresholds pass. Exactly one clean serial R95 App Store test retry is
authorized; no result is predeclared.

### R95 longest-effective-block-range result — RED, one issue

R95 compiled and executed the same 220 tests in 5 suites. The longest-effective
block-range correction removed 10 of R94's 11 issues: cross-block replacement,
marked-text commit, inline-image identity/reopen, nested presentation, package
lifecycle, large viewport, and the Markdown lens-switching neighbors all
passed. The run remained red after 8.854 seconds because one assertion in
`nativeUnicodeEditUndoRedoRemainsCanonical` found that AppKit restored the
visible native string on Undo without restoring the canonical session block to
`Beta`.

This is a native-undo/session-registration seam, not evidence that Unicode
editing or attachment preservation still fail. Retained failed evidence:

- log:
  `build/logs/2026-07-15-epdoc-textkit2-r95-unicode-undo-red.log`;
- log SHA-256:
  `b842b83d58d31e831643524718d7e5d11cdaeaec834a7c00d699858306fd4b77`;
- result:
  `build/xcode-results/2026-07-15-epdoc-textkit2-r95-unicode-undo-red.xcresult`;
- result `Info.plist` SHA-256:
  `a6fc330115dc21c235d6f1492693de92166e772f60e9fd9bbf5ed0dc5604d60c`.

The partial R95 DerivedData/app product was deleted. Exact next action: bind an
ordinary native text transaction to the same exact pre-edit canonical snapshot
undo/redo path already used by structural and formatting operations, without
changing the JSON schema or passing tests; then parse, inspect the diff, and
run a fresh preflight before one clean serial retry.

### R96 canonical ordinary-text undo retry preflight

The ordinary native-text path now captures the exact pre-edit canonical
envelope and selection, suppresses the redundant native-storage-only undo
registration during that transaction, and registers the same session snapshot
restore/redo path used by structural and formatting changes after successful
reconciliation. Marked-text composition retains the original pending snapshot
until commit. Detach restores undo registration before releasing the native
view. Source parsing and `git diff --check` pass.

The fresh R96 preflight recorded the same branch/HEAD and 368 preserved dirty
entries, 3,486.38 MiB swap used, 57% free memory, zero pages throttled, 470 GiB
available disk, no competing Epistemos/Xcode/Swift/Clang/model process, and no
retained Epistemos app/archive product. All thresholds pass. One clean serial
R96 App Store test retry is authorized; its result remains unproven.

### R96 green automated result and current runtime toolbar finding

R96 compiled and passed all 220 tests in 5 suites after 8.289 seconds. Retained
automated evidence:

- log: `build/logs/2026-07-15-epdoc-textkit2-r96.log`;
- log SHA-256:
  `d784b33eec2bebba3a46dbf23c755eb9b5a1484259ca29f628ec83ae279e232b`;
- result: `build/xcode-results/2026-07-15-epdoc-textkit2-r96.xcresult`;
- result `Info.plist` SHA-256:
  `51442396258dcbaf878f78c52ba22e27a39690be4872a1f979674ce54959b1ed`;
- app:
  `/private/tmp/Epistemos-AppStore-R96-DerivedData/Build/Products/Debug/Epistemos.app`;
- app size: 437,408 KiB;
- arm64 executable SHA-256:
  `c663855c1a90802684e9dd0d6d5183546b057dd916420ed52bda229c68fb761c`;
- bundle identifier: `com.epistemos.appstore`; Debug executable is
  linker-signed ad hoc and is not distribution-signing evidence.

Computer-use runtime inspection launched that exact app and created the
standalone package `/Users/jojo/mdz-main/Untitled.epdoc` through File → New
Epdoc Document. The visible native TextKit 2 surface accepted and rendered an
emoji and Han-character fixture, and its autosaved `content.json` retained
those scalar bytes. The first input attempt that omitted those characters was
traced to the automation `type_text` delivery path because the omitted bytes
were absent from canonical JSON; the accessibility-value retry rendered and
persisted them. This is a narrow visible/persistence observation, not a broad
toolbar or performance pass.

The same live window exposes new Keelstone blockers: the toolbar is incomplete
or overflow-only at the inspected width, the owner requires the margin slider
and other useful controls to remain, and the owner reports heading selection
can style the whole document. R96's green automated suite contains no complete
toolbar/margin/selection-scope proof, so the Keelstone verdict remains
**INCOMPLETE**. Exact next action: audit the toolbar/controller/selection
contract and local canon, add fail-first scope/layout tests, and repair this
leg before any Release/archive or subsequent execution key.

### R97 toolbar, selection-scope, and presentation-width result — RED

The R97 implementation batch kept Epdoc JSON canonical and made the editor
width a presentation concern across the native Epdoc, Prose, and Source
canvases. It added a shared width control, deterministic resize recentering,
selection-scoped native heading dispatch, multiline structural-paste support,
and narrow source/behavior guards. Epdoc retained the full toolbar host while
Prose and Source received the compact toolbar route requested by the owner.

The resource preflight passed the owner thresholds and one clean serial App
Store test leg was run. The result bundle reports 222 total tests: 219 passed
and 3 failed. The failures were attributable to:

- a stale source-guard shape after the width-mode argument was added;
- multiline paste resolving only the current attributed run instead of the
  longest canonical block range, followed by an unsafe test index after the
  failed count assertion; and
- the hosted CodeMirror Keelstone-scale test failing after the preceding host
  crash/restart, so that failure was not accepted as an independent production
  regression without a clean rerun.

Retained red evidence:

- log: `build/logs/2026-07-15-epdoc-toolbar-width-r97.log`;
- log SHA-256:
  `4d01d246bc3936ade8a6a9d2a573d49c34889d3d18e0ef9368a2bfa683c118e3`;
- result: `build/xcode-results/2026-07-15-epdoc-toolbar-width-r97.xcresult`;
- result `Info.plist` SHA-256:
  `d767be3c6162dcc9ee9183a387adf1f134ed2b7c2468357af5ffe0518ea00b28`.

The R97 app/DerivedData product was deleted. The correction used the existing
longest-range helper, made the test count fail-closed before indexing, and
updated the source guard. Source parsing and `git diff --check` passed before
the next resource preflight.

### R98 clean retry result — RED, test-event grouping only

R98 compiled and executed all 222 tests. 221 passed and one assertion failed
in `nativeMultilinePasteAndHeadingAreStructuralAndScoped`. The clean run proved
that structural multiline paste created the expected sibling blocks, the
heading command changed only the selected `Body` block, the hosted CodeMirror
Keelstone-scale edit/delete/scroll/save test passed, and the other width and
hot-path guards passed. The remaining assertion attempted to undo the heading
after programmatically issuing paste and toolbar commands inside one AppKit
event group; AppKit correctly undid the combined synthetic event and removed
the generated block. This was test-driver grouping debt, not accepted as a
production behavior pass or failure.

Retained red evidence:

- log: `build/logs/2026-07-15-epdoc-toolbar-width-r98.log`;
- log SHA-256:
  `7422ec430ef6a7ccdc137108542417aa1ca4fcbd92eb6152c623be6042f0d28f`;
- result: `build/xcode-results/2026-07-15-epdoc-toolbar-width-r98.xcresult`;
- result `Info.plist` SHA-256:
  `cb314c4efd3d65071d6db2c13e793c917f921dfce4cce4eac0ac68d1149654c7`.

The R98 app/DerivedData product was deleted.

### R99 invalid undo-harness attempt — RED and interrupted

R99 changed the synthetic test to disable event grouping but initially failed
to create explicit undo groups. `NSUndoManager` raised
`NSInternalInconsistencyException` with `invalid state, must begin a group
before registering undo`. The test host did not exit after that exception; it
was stopped before any further build, in accordance with the one-current-build
rule. No completed test-run result exists, and the partial `.xcresult` lacks
an `Info.plist`, so it is retained only as a red/incomplete diagnostic
directory and is not result-bundle evidence.

- log: `build/logs/2026-07-15-epdoc-toolbar-width-r99.log`;
- log SHA-256:
  `7f7a269065347ef663181ec4694135254ebe4d4dc0d6c8ebfd3132256f971b49`;
- incomplete result directory:
  `build/xcode-results/2026-07-15-epdoc-toolbar-width-r99.xcresult`.

The test was corrected to wrap paste and heading dispatch in two explicit undo
groups, accurately representing two user events. Swift parsing and
`git diff --check` passed. The R99 app/DerivedData product was deleted.

### R100 exact toolbar/width narrow regression result — GREEN

The decisive R100 preflight recorded:

- branch/HEAD: `feat/goose-surface` at
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- 372 preserved dirty entries, with no reset or overwrite;
- swap used: 3,072.50 MiB, below the 16,384 MiB owner ceiling;
- system free memory: 54%;
- pages throttled: 0;
- available Data-volume disk: 469 GiB; and
- no active Epistemos app, Xcode build, Swift/Clang compiler, or local-model
  runtime. Idle system services were not treated as competing builds.

One clean serial App Store target test run then passed all 222 tests in 5
suites with zero failures, skips, or expected failures. The Swift Testing run
completed in 10.351 seconds. Current exact automated proof includes:

- structural multiline paste creates stable sibling canonical blocks;
- heading dispatch is scoped to the selected canonical block and has distinct
  undo/redo from the preceding paste event;
- native width changes recenter without changing canonical Epdoc content or
  revision;
- Prose and Source width routes remain presentation-only under their source
  guards;
- the hosted CodeMirror test loads, edits, deletes, scrolls, and saves the
  Keelstone-scale 67k-word Markdown fixture; and
- the existing Markdown lens-switch and dirty-checkpoint neighbors remain
  green in this selected target.

Retained green evidence:

- log: `build/logs/2026-07-15-epdoc-toolbar-width-r100.log`;
- log SHA-256:
  `4a0f7f4300169c0c31c195be4579c150839b0517c7eeef4e36f96481ef6d88eb`;
- result: `build/xcode-results/2026-07-15-epdoc-toolbar-width-r100.xcresult`;
- result `Info.plist` SHA-256:
  `1aca443cec7a82ac752d471f180ab58b67c011a25fe8001d1f7831231c33a318`;
- transient app:
  `/private/tmp/Epistemos-AppStore-R100-DerivedData/Build/Products/Debug/Epistemos.app`;
- arm64 executable SHA-256:
  `7f94e4dd33a67c02f44a3bd17e677781e9af383bb8a17926ac4632b3abeff15e`;
- bundle identity: `com.epistemos.appstore`, version `1.0.0` (`1`).

The transient R100 app/DerivedData product was deleted after identity capture;
the log and result bundle remain. This is a narrow Debug regression pass, not
an archive, signing, distribution, visual, memory, or release pass. The log
also contains WebContent sandbox/TCC/LaunchServices denials and JavaScript
execution-failed messages during the hosted WebKit leg even though its
behavioral assertions passed; those messages remain runtime-correlation debt
and are not silently waived.

### Current toolbar and verification debt after R100

The owner-visible done bar is not met. Native Epdoc currently has proven
selection-scoped heading, basic inline marks, presentation width, and a basic
find-panel route, but code block, quote/list commands, insertion commands, and
complete find/replace behavior still require native implementations and
fail-first coverage. Collapsed-caret typing attributes and toolbar-state
synchronization require an explicit audit. Prose and Source compact toolbar
visuals, normal centered defaults, Epdoc centering at real window sizes, and
non-jumping resize/scroll behavior have not been manually correlated with
runtime logs. The separate `EpistemosTests` target and its new width resolver
tests have not run in this leg. No Release archive, artifact gate, finite
runtime matrix, memory-leak instrument pass, distribution check, or repeated
zero-fail pass has begun.

**R100 NARROW AUTOMATED REGRESSION GREEN / KEELSTONE STILL INCOMPLETE — NOT
RELEASE READY.** Exact next action: add fail-first native toolbar command,
collapsed-caret state, and selection-boundary tests; implement only those
missing Epdoc toolbar paths while keeping Prose/Source compact and width
presentation-only; then parse, inspect the diff, resource-preflight, and run
the next one-build serial verification leg. Do not begin Release/archive or a
new canonical execution key.

### R101 fail-first native toolbar evidence — RED as required

R101 executed the exact next action without first changing production code.
The preflight recorded branch `feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, 373 preserved dirty entries,
3,072.50 MiB swap used, 55% free memory, zero pages throttled, 471 GiB
available disk, and no competing Epistemos/Xcode/compiler/model process. All
owner thresholds passed. One clean serial App Store test build then exercised
three new fail-first native-toolbar cases.

All three cases failed at the intended unimplemented or stale-state seams:

- collapsed-caret Bold did not immediately update toolbar state from native
  typing attributes, and subsequent plain typing retained the stale mark;
- a selection ending at a structural delimiter did not report or restore its
  actual Bold state through undo/redo; and
- the dispatched code-block command remained inert, leaving both selected
  paragraphs unchanged and the canonical revision unadvanced.

The result summary records 3 total and 3 failed tests. Because Swift Testing
restarted the application test host after each failed expectation group, the
`.xcresult` classifies the three runs as external-symbol crashes; the retained
console log contains the exact expectation failures above. No result is
reinterpreted as green.

Retained fail-first evidence:

- log: `build/logs/2026-07-15-epdoc-native-toolbar-r101.log`;
- log SHA-256:
  `4b90eb28121c63cf282ccefbbc6846481a2856099496445561336f919109cc83`;
- result:
  `build/xcode-results/2026-07-15-epdoc-native-toolbar-r101.xcresult`;
- result `Info.plist` SHA-256:
  `e19a15d6aca95f267a1b9ebaa3b1d31164e12615b83029b6388fdc4bf5cc6134`;
- transient Debug app identity: `com.epistemos.appstore`, version `1.0.0`
  (`1`), 428 MiB bundle; it is not signing, archive, or distribution evidence.

The 1.8 GiB R101 DerivedData tree, including the transient app, was deleted
after identity capture. Exact next action: implement typing-attribute-backed
collapsed-caret state, delimiter-safe selected runs with explicit state
resynchronization, and a schema-safe selection-scoped native code-block
toggle. The same batch must replace whole-document formatting/ordinary-edit
undo receipts with localized block receipts before claiming the 67k-word hot
path hardened. Then parse, inspect the diff, preflight again, and run one clean
serial focused retry; no app launch, Release/archive, or new execution key is
authorized yet.

### R102 localized-toolbar retry preflight

The production correction follows the R101 failures and the pre-existing
one-code-card canon. Collapsed-caret state now reads and reapplies AppKit typing
attributes; ordinary typing, inline marks, and heading/paragraph changes use
block-local canonical inverse receipts instead of a full document envelope;
multi-block mark reconciliation is batched into one canonical revision; and a
valid multi-paragraph code selection is structurally replaced by one canonical
Swift code-block node. Parent/child schema guards reject invalid leaf
conversions. Full-document inverse state remains only for structural operations
that add or remove canonical block identities.

Swift parsing and focused `git diff --check` pass. The fresh R102 preflight
recorded branch `feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, 373 preserved dirty entries,
3,056.50 MiB swap used, 54% free memory, zero pages throttled, 470 GiB
available disk, and no competing Epistemos/Xcode/compiler/model process. No
stale Epistemos app/archive or temporary App Store DerivedData product was
found after cleanup. All owner thresholds pass. Exactly one clean serial R102
focused App Store retry is authorized; its result is not predeclared.

### R102 localized-toolbar retry result — RED test-host crash

The clean R102 build compiled the edited Epdoc TextKit 2 session/view and the
focused toolbar test target, linked the App Store Debug app, and passed its
repository source-guard phase. It did not produce a passing test result.
Xcode's result summary records 3 total, 3 failed, 0 passed tests. Each test
process terminated before Swift Testing could record an assertion result:

- `collapsedCaretMarkStateFollowsTypingAttributes()`;
- `selectionStateIgnoresDelimitersAndResynchronizesUndo()`; and
- `codeBlockToggleIsSelectionScopedAndValidated()`.

The three exported crash receipts independently report `EXC_BAD_ACCESS`,
`SIGSEGV`, faulting main thread, with the visible stack beginning at
`objc_release` while the test runner drains an autorelease pool. The action log
contains each test's start but no expectation failure or pass. Therefore R102
does **not** prove or disprove the corrected toolbar assertions; it proves the
production and test code compile while exposing a separate AppKit/Swift
Testing host-lifetime blocker. The earlier R101 fail-first assertions remain
the last exact behavioral result for those three legs.

Retained red evidence:

- action log: `build/logs/2026-07-15-epdoc-native-toolbar-r102.log`;
- action-log SHA-256:
  `1e135afb54bf948ed616b7e518ea9f59c8edad95a2d1dfbae8adc60b167c5f6c`;
- result:
  `build/xcode-results/2026-07-15-epdoc-native-toolbar-r102.xcresult`;
- result `Info.plist` SHA-256:
  `bac89c3053044f1bdddef81bdeef55f7b82fea79bd4a8af1316d1ecf20d05f53`;
- exported crash directory:
  `build/xcode-results/2026-07-15-epdoc-native-toolbar-r102-crashes`;
- crash SHA-256 values: `cb9505b5299906e55a3ff87b3b745ff0b2e57a6c1335da3b75dfa305918b77d3`,
  `c25aff865baa2f5fe646cca18e2ad87d4e1c0b4d64204ccc7ab8a59a53b727a5`,
  and `bf0240a6f54cf9ac69656b4f0c1826b43630772fb19f008951be6abf16989130`;
- transient app identity: `com.epistemos.appstore`, version `1.0.0` (`1`),
  428 MiB bundle; and
- transient executable SHA-256:
  `928cd8e519660d63e7c751d6b0fe16ec55da605bb282a75b0ee82883f71764a8`.

This is not archive, signing, distribution, runtime, memory, or release
evidence. Exact next action: isolate the focused tests from the AppKit window
and application-host lifetime that crashes during autorelease teardown while
preserving real `NSTextView` selection, typing-attribute, and undo behavior;
then parse and source-check the surgical harness correction, perform a new
resource preflight, and run one clean serial focused retry. Do not reinterpret
the crash as toolbar success, launch an app, archive, or begin another
canonical execution key.

### R103 test-window lifetime retry preflight

The R102 crash receipts and repo precedent identify one harness-only lifetime
error: the retained programmatic `NSWindow` was closed with AppKit's
release-on-close behavior still enabled. The surgical correction sets
`isReleasedWhenClosed = false` before the harness retains and later closes the
window. It changes no production editor behavior. Swift parsing and repository
diff hygiene pass.

The fresh R103 preflight records branch `feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, 373 preserved dirty entries,
3,048.50 MiB swap used, 56% free memory, zero pages throttled, and 470 GiB
available Data-volume disk. No active Epistemos app, Xcode build, Swift/Clang
compiler, Metal compiler, or local-model runtime is competing. The process
scan saw only an unrelated idle Python HTTP server launched from inside the
Xcode developer toolchain path; it is not an Xcode build/compiler/model/app
process. No stale temporary App Store DerivedData, Epistemos app product, or
archive was found. All owner thresholds pass. Exactly one clean serial R103
focused retry is authorized; its outcome is not predeclared.

### R103 test-window lifetime retry result — TWO GREEN / ONE BEHAVIORAL RED

The clean R103 run compiled and linked the production editor, focused test
target, and App Store Debug host without a source-guard or test-host crash.
The result summary records 3 total tests: 2 passed, 1 failed, 0 skipped. This
proves that the harness lifetime correction removed the R102 teardown crash
and exposes the exact remaining product behavior instead of an external-symbol
classification.

The delimiter-safe selection/undo test passes, including restored toolbar
state. The multi-paragraph code-block test passes, including one canonical
code block, preserved unrelated siblings and selection, one revision, and the
validated toggle back to paragraph. The collapsed-caret test passes its Bold
typing-attribute and first inserted Bold-character checks, then fails one
expectation: after toggling Bold off, the following `Y` character is still
represented canonically with a Bold mark. R103 is therefore behavioral red;
the two passing legs are not inflated into toolbar completion.

Retained evidence:

- action log: `build/logs/2026-07-15-epdoc-native-toolbar-r103.log`;
- action-log SHA-256:
  `c96679eec3055f4461dc466442f45f24890d79edc8e4d6e33ff8b68bb6a8ff5b`;
- result:
  `build/xcode-results/2026-07-15-epdoc-native-toolbar-r103.xcresult`;
- result `Info.plist` SHA-256:
  `a256d1c4a0f8cfeb70872844af293dbf46013b60100830884a84c556387cc760`;
- transient app identity: `com.epistemos.appstore`, version `1.0.0` (`1`),
  428 MiB bundle; and
- transient executable SHA-256:
  `a20760cc7c1108cb8094a742e1780edbb9757099fdd399f2c90ae02e2183bb19`.

The 1.8 GiB R103 DerivedData tree, including the transient app, was deleted
after identity capture. This is not archive, signing, distribution, visual,
large-document, memory, or release evidence. Exact next action: preserve the
collapsed-caret typing marks as an explicit one-edit semantic override through
AppKit's native insertion, apply that override only to the inserted UTF-16
range before localized canonical reconciliation, add a mixed plain/Bold/plain
regression boundary if needed, parse and inspect the surgical diff, and
perform a fresh preflight before one clean serial focused retry. Do not begin
Release/archive or another execution key.

### R104 collapsed-caret insertion-mark retry preflight

The R103 behavioral failure is isolated to AppKit's native insertion inheriting
the semantic mark from the character to the left after the caret's explicit
typing mark was cleared. The correction records the typing-attribute semantic
marks for one native edit and applies that value only to the exact inserted
UTF-16 range before the existing localized canonical reconciliation. It does
not rebuild the document, broaden the undo receipt, or change another surface.
Swift parsing and repository diff hygiene pass.

The fresh preflight records branch `feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, 373 preserved dirty entries,
3,048.50 MiB swap used, 49% free memory, zero pages throttled, and 469 GiB
available Data-volume disk. No active Epistemos app, Xcode build,
Swift/Clang/Metal compiler, or local-model runtime is competing. The process
scan saw only two ChatGPT computer-use Node kernels whose command arguments
name this repository as their working directory; they are not Epistemos,
compiler, build, or model processes. No stale temporary App Store DerivedData,
Epistemos app product, or archive was found. All owner thresholds pass.
Exactly one clean serial R104 focused retry is authorized; its outcome is not
predeclared.

### R104 collapsed-caret insertion-mark retry result — TEST ORACLE RED

R104 compiled and linked the surgical insertion-mark correction and again
completed without a source-guard or test-host crash. Its result summary remains
3 total, 2 passed, 1 failed, 0 skipped. Selection/undo and code-block behavior
remain green. The sole expectation is identical to R103: it requires the
inserted plain `Y` to exist as a standalone one-character canonical text node.

That requirement is not a canonical contract. Adjacent text with identical
marks may be coalesced during attributed-run reconciliation, so a correct plain
`Y` at the insertion boundary may be represented as the first character of a
plain `Yta` child. The assertion therefore cannot distinguish inherited Bold
from valid adjacent-run coalescing and is a red test oracle, not current proof
that the product behavior remains wrong. R104 is not reclassified as green.

Retained evidence:

- action log: `build/logs/2026-07-15-epdoc-native-toolbar-r104.log`;
- action-log SHA-256:
  `1219fd221b7e974cb7fd35595aff62ccd1ec5d562103a583ee34a0f20ddbf578`;
- result:
  `build/xcode-results/2026-07-15-epdoc-native-toolbar-r104.xcresult`;
- result `Info.plist` SHA-256:
  `ab3dd2b95802ca74f3163ebc8ef71063fa0acbc0f42b12182e9654f3778eb6dc`;
- transient app identity: `com.epistemos.appstore`, version `1.0.0` (`1`),
  428 MiB bundle; and
- transient executable SHA-256:
  `225c9138c219292dbe2e0702a2e10309ef98b117012b2501e1c3e6f5f1ac01ff`.

The 1.8 GiB R104 DerivedData tree, including the transient app, was deleted
after identity capture. Exact next action: replace only the invalid
one-character-node expectation with an offset-aware canonical mark assertion
that locates UTF-16 offset 3 in `BeXYta` and verifies `Y` is plain while `X`
remains Bold. Parse and inspect that harness-only correction, preflight again,
then run one clean serial focused retry. No release or broader behavior claim
opens before that result.

### R105 offset-aware toolbar oracle retry preflight

The harness-only correction now resolves a canonical character offset across
text, hard-break, and inline-node children, then asserts the mark set at the
inserted `X` and `Y` offsets. It no longer constrains valid adjacent plain-text
run coalescing. Production code is unchanged after R104. Swift parsing and
repository diff hygiene pass.

The fresh preflight records branch `feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, 373 preserved dirty entries,
3,048.50 MiB swap used, 46% free memory, zero pages throttled, and 469 GiB
available Data-volume disk. No active Epistemos app, Xcode build,
Swift/Clang/Metal compiler, or local-model runtime is competing. The two
ChatGPT computer-use Node kernels remain unrelated to the app/build/model
process boundary. No stale temporary App Store DerivedData, Epistemos app
product, or archive was found. All owner thresholds pass. Exactly one clean
serial R105 focused retry is authorized; its outcome is not predeclared.

### R105 offset-aware toolbar oracle retry result — NARROW GREEN

R105 compiled and linked the corrected production and harness sources, passed
the repository source-guard phase, and executed all 3 focused tests with 3
passes, 0 failures, and 0 skips. The exact green legs are:

- collapsed-caret Bold activation, Bold `X` insertion, Bold deactivation, and
  plain `Y` insertion verified at their canonical UTF-16 offsets without
  assuming text-node boundaries;
- delimiter-safe multi-block selection state plus undo/redo resynchronization;
  and
- selection-scoped multi-paragraph conversion to one schema-valid canonical
  code block, preservation of unrelated siblings and selection, one revision,
  and a validated toggle back to paragraph.

Retained narrow evidence:

- action log: `build/logs/2026-07-15-epdoc-native-toolbar-r105.log`;
- action-log SHA-256:
  `95a5ba421e0ae56ed6cde3c41e8f05367f7b606bf8e0771031021766a2c1adb4`;
- result:
  `build/xcode-results/2026-07-15-epdoc-native-toolbar-r105.xcresult`;
- result `Info.plist` SHA-256:
  `236bb1b6777a2cd01dd9eeb93f21c0a55ef4802b1aa5a1e1f9e9c0255ad88da7`;
- transient app identity: `com.epistemos.appstore`, version `1.0.0` (`1`),
  428 MiB bundle; and
- transient executable SHA-256:
  `56b1e688df74e3bae6731156f243a2e8596866df069ce77ba475a14f628d8011`.

The 1.8 GiB R105 DerivedData tree, including the transient app, was deleted
after identity capture. This is a narrow Debug regression result, not a
Release archive, artifact gate, visual/manual, large-document, memory,
distribution, or release result. **R105 NARROW TOOLBAR GREEN / KEELSTONE STILL
INCOMPLETE — NOT RELEASE READY.** Exact next action: inspect the complete
touched-file diff and source contracts, then extend the existing serial
regression batch to include these three tests alongside the previously green
Keelstone editor/lens/width set. Only after that broader batch is current may
the evidence chain proceed to one fresh Release archive and artifact gates.

### R106 whole Keelstone test-target regression preflight

The touched-file and nearby-contract audit confirms that ordinary Epdoc text,
mark, and block-style toolbar edits use localized block snapshots and localized
projection reconciliation. Full-document checkpoint envelopes remain confined
to structural edits and full-session undo paths. The focused R105 behavior is
therefore ready to rejoin the existing Keelstone editor/lens/width regression
batch. The two new TextKit files remain large (960 and 1,650 lines), so
Coordinator decomposition is recorded as maintainability debt rather than
being mixed into this surgical behavioral evidence leg. No broad code-quality
or large-document runtime claim is made by this audit.

The fresh R106 preflight records branch `feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, equal to
`origin/feat/goose-surface` and the current handoff publication commit, with
373 preserved dirty entries. Swap use is 3,048.50 MiB, system free memory is
50%, pages throttled are zero, and the Data volume has 469 GiB available. No
active Epistemos app, Xcode build, Swift/Clang/Metal compiler, or local-model
runtime is competing. The process scan saw only two ChatGPT computer-use Node
kernels whose arguments name this repository as their working directory; they
are not Epistemos, compiler, build, or model processes. No stale temporary App
Store DerivedData, Epistemos app product, or archive was found. All
owner-approved resource thresholds pass. Exactly one clean serial R106 whole
`EpistemosAppStoreKeelstoneTests` target run is authorized; its outcome is not
predeclared.

### R106 whole Keelstone test-target regression result — RED

R106 compiled and linked the clean App Store Debug target, completed the
repository source-guard phase, and executed 225 tests across 6 suites. The
exact summary is 222 passed, 3 failed, and 0 skipped. The previously isolated
native-toolbar suite remained green at 3 of 3. The three red legs are:

- both large-Markdown tests reject the current evidence fixture because it is
  now 564,340 UTF-8 bytes while their stale harness ceiling is 550,000 bytes;
  this is a fixture-envelope assertion before either test's intended editor
  behavior proof;
- the native multi-block selection test observes revision 12 where its
  expectation requires initial revision plus two, or 13. The behavior and
  assertion must be inspected before classification; and
- no Release, archive, artifact-gate, visual/manual, distribution, or release
  claim opens from this red batch.

Retained evidence:

- action log: `build/logs/2026-07-15-epdoc-keelstone-broad-r106.log`;
- action-log SHA-256:
  `308bb297a5e5b86d0218bf333b2066ae0ae328628af46e5923c145ec3db22768`;
- result:
  `build/xcode-results/2026-07-15-epdoc-keelstone-broad-r106.xcresult`;
- result `Info.plist` SHA-256:
  `1853b57b7027c17c29ab1b32fb90f29c431443cd74b5bddcf541848dfe0a7754`;
- transient app identity: `com.epistemos.appstore`, version `1.0.0` (`1`),
  428 MiB bundle; and
- transient executable SHA-256:
  `f80c61d08b8e31a89a5295fa91eddbd2ccf0a03793f65e76f545728f11694144`.

The 1.8 GiB R106 DerivedData tree, including the transient app, was deleted
after identity capture. **R106 BROAD REGRESSION RED / KEELSTONE STILL
INCOMPLETE — NOT RELEASE READY.** Exact next action: inspect both fixture
envelope contracts and the native multi-block revision sequence against the
current production/session contracts, correct only proven stale oracle or
failed behavior, parse and diff the surgical change, then perform a fresh
resource preflight before one clean serial focused retry of exactly these three
red tests. Do not begin a Release archive or another execution key.

### R107 three-leg oracle correction and focused-retry preflight

Current-source inspection classifies all three R106 failures as stale test
oracles rather than a production-behavior failure:

- the owner-selected live Keelstone evidence fixture is intentionally durable
  and continues to grow as exact evidence is appended. It now contains 67,985
  whitespace-delimited words and 566,428 bytes. Both tests still prove the
  current exact file is a representative large document by requiring at least
  450,000 UTF-8 bytes and 60,000 words; they no longer impose a 550,000-byte
  ceiling that makes recording more evidence fail before editor behavior runs;
  and
- `replaceInlineContents` validates all selected editable blocks, applies the
  replacements as one atomic transaction, and advances one canonical
  revision. The multi-block mark test now expects one revision and explicitly
  verifies that undo restores the initial revision while redo restores the
  one-transaction revision. Content, stable IDs, selection, semantic marks,
  and reopen checks remain unchanged.

Only those three assertions changed. All three files pass Swift parsing and
repository diff hygiene remains clean.

The fresh R107 preflight records branch `feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, equal to
`origin/feat/goose-surface` and the current handoff publication commit, with
373 preserved dirty entries. Swap use is 3,032.50 MiB, system free memory is
47%, pages throttled are zero, and the Data volume has 469 GiB available. No
active Epistemos app, Xcode build, Swift/Clang/Metal compiler, or local-model
runtime is competing. The two ChatGPT computer-use Node kernels are outside
that boundary. No stale temporary App Store DerivedData, Epistemos app product,
or archive was found. All owner-approved thresholds pass. Exactly one clean
serial R107 retry of the three R106 failures is authorized; its outcome is not
predeclared.

### R107 three-leg focused retry result — GREEN after selector correction

The first R107 `xcodebuild test` command compiled and linked the one clean
App Store Debug product successfully, but its Swift Testing selectors omitted
the enumerated trailing `()` and therefore matched only the three suites. Its
result contained zero tests, so it is explicitly **not** counted as evidence.
Test enumeration against that exact product returned the canonical identifiers
with `()`. A `test-without-building` retry then reused the same single app
product and executed exactly the three intended tests:

- `appStoreLaneKeepsCleanMarkdownDocumentSwitchesReadOnly()` — passed;
- `nativeMultiBlockSelectionPreservesStableBlocksAndMarks()` — passed; and
- `hostedCodeMirrorHandlesKeelstoneScaleMarkdown()` — passed, including load,
  edit, delete, scroll, and save against the current 67,985-word fixture.

The corrected result summary is 3 total, 3 passed, 0 failed, 0 skipped. Exact
retained evidence:

- corrected execution log:
  `build/logs/2026-07-15-epdoc-keelstone-oracles-r107b.log`;
- corrected log SHA-256:
  `56acff21c6006a14aabc40c3b6a8645e82aef594c4663133980a62373a9495da`;
- corrected result:
  `build/xcode-results/2026-07-15-epdoc-keelstone-oracles-r107b.xcresult`;
- corrected result `Info.plist` SHA-256:
  `7df18a55b729a6ea453d4d72de0574ce824dc732a1864001b8bc59d3285d8bee`;
- transient app identity: `com.epistemos.appstore`, version `1.0.0` (`1`),
  428 MiB bundle; and
- transient executable SHA-256:
  `7174e21c92fefa0de7441ec230f899123ab0811b6274fdfd035976917295d940`.

The invalid zero-test selector result remains retained only as an auditable
negative receipt; it is not a green gate. **R107 FOCUSED ORACLE RETRY GREEN /
KEELSTONE STILL INCOMPLETE — NOT RELEASE READY.** Exact next action: delete the
1.8 GiB R107 DerivedData tree and its transient app after the identity capture,
perform a fresh resource preflight, then run one clean serial whole
`EpistemosAppStoreKeelstoneTests` regression. Do not begin a Release archive or
another execution key.

### R108 whole Keelstone test-target regression preflight

The 1.8 GiB R107 DerivedData tree and its transient app were deleted after
identity capture. The fresh R108 preflight records branch
`feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, equal to
`origin/feat/goose-surface` and the current handoff publication commit, with
373 preserved dirty entries. The living evidence fixture now contains 68,489
whitespace-delimited words and 570,450 bytes. Swap use is 3,032.50 MiB,
system free memory is 48%, pages throttled are zero, and the Data volume has
469 GiB available. No active Epistemos app, Xcode build, Swift/Clang/Metal
compiler, or local-model runtime is competing; macOS `modelmanagerd` and the
two unrelated ChatGPT computer-use Node kernels are outside that boundary.
No stale temporary App Store DerivedData, Epistemos app product, or archive
was found. All owner-approved thresholds pass. Exactly one clean serial R108
whole `EpistemosAppStoreKeelstoneTests` regression is authorized; its outcome
is not predeclared.

### R108 whole Keelstone test-target regression result — GREEN

R108 compiled and linked the one clean App Store Debug product and executed
the whole `EpistemosAppStoreKeelstoneTests` target. The exact result is 225
tests across 6 suites: 225 passed, 0 failed, 0 skipped. In particular:

- the 72k-word native Epdoc bounded TextKit 2 viewport test passed in 0.257
  seconds;
- the 72k-word native Epdoc edit, backspace, viewport traversal, and reopen
  test passed in 0.422 seconds;
- native multi-block semantic-mark selection passed in 0.007 seconds;
- the native toolbar delimiter/undo synchronization test passed in 0.005
  seconds; and
- the current 68k-word hosted CodeMirror load, edit, delete, scroll, and save
  test passed in 2.653 seconds.

Exact retained evidence:

- log: `build/logs/2026-07-15-epdoc-keelstone-broad-r108.log`;
- log SHA-256:
  `1fadc9835b5e68681b50e8c0d948594c93a79d80c3ff3ef9bbf62258521ba5ac`;
- result:
  `build/xcode-results/2026-07-15-epdoc-keelstone-broad-r108.xcresult`;
- result `Info.plist` SHA-256:
  `78975e635894ba5497da874e93b306dce8c626a7099f2e9c61725c557bb67574`;
- transient app identity: `com.epistemos.appstore`, version `1.0.0` (`1`),
  428 MiB bundle; and
- transient executable SHA-256:
  `3ed8751c613b7d744d7e32debab00847bdb2db1b5418dbfc0668a953804767e3`.

The test result is green, but this is not a zero-warning release claim. The
log also retains an upstream Rust future-compatibility warning for `block`
0.1.6, two pre-existing Swift warnings in `TextCapturePipeline.swift` and
`LiteParsePDFImportController.swift`, duplicate-column migration diagnostics
from the isolated test database bootstrap, and sandboxed WebContent/macOS
IconRendering diagnostics during the hosted CodeMirror test. None failed a
test; their classification remains verification debt rather than silently
being called clean.

**R108 BROAD REGRESSION GREEN / KEELSTONE STILL INCOMPLETE — NOT RELEASE
READY.** Exact next action: complete the scoped logical/log audit, delete the
1.8 GiB R108 DerivedData tree and transient app after identity capture, then
perform the next fresh resource preflight before the one allowed
`Epistemos-AppStore` Release archive. Do not launch this Debug product, begin a
second archive, or start another execution key.

### R109 exact Release archive preflight

The 1.8 GiB R108 DerivedData tree and transient Debug app were deleted after
identity capture. The fresh archive preflight records branch
`feat/goose-surface` at
`668b52cfb43721de95db102260d9f327ae24e13e`, equal to
`origin/feat/goose-surface` and the current handoff publication commit, with
373 preserved dirty entries. The living evidence fixture now contains 68,902
whitespace-delimited words and 573,782 bytes. Swap use is 3,032.50 MiB,
system free memory is 46%, pages throttled are zero, and the Data volume has
469 GiB available. No active Epistemos app, Xcode build, Swift/Clang/Metal
compiler, or local-model runtime is competing; the two unrelated ChatGPT
computer-use Node kernels are outside that boundary. No stale temporary App
Store DerivedData, Epistemos app product, or archive was found. All
owner-approved thresholds pass. Exactly one clean serial unsigned
local-evidence R109 `Epistemos-AppStore` Release archive is authorized; its
outcome is not predeclared and it makes no Apple distribution-signing claim.

### R109 exact Release archive and artifact-gate result — GREEN WITH EXPLICIT DISTRIBUTION DEBT

Exactly one serial Free V1 Release archive action was run from the authorized
R109 preflight:

```text
EPISTEMOS_PRODUCT_EDITION=FREE_V1 ./scripts/xcodebuild_epistemos.sh archive \
  -project Epistemos.xcodeproj \
  -scheme Epistemos-AppStore \
  -configuration Release \
  -destination generic/platform=macOS \
  -archivePath /private/tmp/Epistemos-AppStore-Release-R109/Epistemos-AppStore.xcarchive \
  -derivedDataPath /private/tmp/Epistemos-AppStore-Release-R109/DerivedData \
  -jobs 1 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

The action ended with `** ARCHIVE SUCCEEDED **`. Exact retained identities
before any local evidence signing were:

- archive:
  `/private/tmp/Epistemos-AppStore-Release-R109/Epistemos-AppStore.xcarchive`;
- app:
  `/private/tmp/Epistemos-AppStore-Release-R109/Epistemos-AppStore.xcarchive/Products/Applications/Epistemos.app`;
- bundle identifier `com.epistemos.appstore`, version `1.0.0` (`1`), minimum
  macOS `26.0`, universal `x86_64` + `arm64`;
- unsigned/linker-ad-hoc main-executable SHA-256
  `667936ddd189bc6c024e9f0ec9c9936b02ffc8b2892a60cfea2291e944dcf8db`;
- archive `Info.plist` SHA-256
  `c7b6688fc7ae44aedf88fad2f6e6a9c4c3c620270a96b014d6102a18aa8b6937`;
- archive log `build/logs/2026-07-15-epdoc-keelstone-release-r109.log`;
- archive-log SHA-256
  `c545e4244ec9a683f6499a5768c6daaee22c41880be926bc4ae05ecdaa0d32ab`;
- archive size 372 MiB and app size 141 MiB.

The exact archive still records the upstream Rust `block` 0.1.6 future-
compatibility warning and the existing no-async-operation `await` and unused
`try?` Swift warnings from `TextCapturePipeline.swift` and
`LiteParsePDFImportController.swift` for both architectures. They did not stop
the archive, but R109 is not a zero-warning result and does not discharge that
verification debt.

For local artifact/runtime evidence only, the two bundled Epistemos dylibs and
the app were ad-hoc signed with the checked-in App Store entitlements. Strict
deep verification passes. The exact post-sign identity is:

- main-executable SHA-256
  `8c305cdcbcc9c3d1171ae7e86b0d382cce6fd1858501fe75abb54bb1a216404f`;
- CDHash `8a8ed91345151351e8c4dd91fc72b6f066072c9b`;
- identifier `com.epistemos.appstore`;
- entitlements: App Sandbox, `group.com.epistemos.shared`, audio input,
  app-scoped bookmarks, user-selected read/write, and network client;
- `TeamIdentifier=not set`.

The absent TeamIdentifier is intentional for this unsigned local-evidence
archive. This is not Apple distribution signing, notarization, App Store
validation, upload, review, or submission proof.

Both artifact gates pass against this exact post-sign app:

- integrated gate:
  `build/logs/2026-07-15-epdoc-keelstone-release-gate-r109.log`, SHA-256
  `7c002c4b95930f014d577b2df3ac65ae256b4050fdbfe1d30047858172712a3d`;
- independent bundle scanner:
  `build/logs/2026-07-15-epdoc-appstore-bundle-scan-r109.log`, SHA-256
  `178c65d57ff393ded150d393e0603bcb71205352b2db8dd3377683ebf155e543`;
- scanner report directory `build/appstore-audit-r109`.

The exact Free V1 artifact omits JuneWeb, the model manifest, DefaultSkills,
llama, `agent_core`, `omega_mcp`, paid-provider/June/inference/agent identity
and linkage, private/research residue, 1Code, retired lanes, prohibited
symbols, prohibited linkage, and prohibited runtime strings. The scanner's
corresponding rejection files are empty and quarantine inspection is clean.

The independent byte and symbol audit also passes:

- the app privacy manifest is byte-identical to
  `Epistemos/Resources/PrivacyInfo.xcprivacy`, both SHA-256
  `e1c392f10f990c037d16b804d066770599e1a29e78b6ffd512646a168705c406`;
- bundled CoreEditor contains `index.html`, its chunk set, the compiled
  `MarkEdit.codemirror` marker, and the native executable contains the
  `epistemosMarkEditCoreEditor` bridge marker;
- requested editor typography assets are present in the exact artifact:
  `MatrixtypeDisplay-9MyE5.ttf`, `MatrixTypeDisplay-Bold.otf`,
  `MatrixDotsDemoRegular.ttf`, `ChonkyPixels.ttf`, and the canon-identified
  greeting font `GNF.ttf`;
- app executable and dSYM UUIDs match exactly:
  `96E59654-C3BD-3E2F-B1CA-E57850946F5B` for `x86_64` and
  `5AF6B363-54E5-36E4-AA2F-A21EAB9EF2F1` for `arm64`;
- the signed app contains 166 files and its deterministic path-plus-file-byte
  tree SHA-256 is
  `481f0a29f76a1a0477a6909538b84fa111a33cb8b7ba195ec0be1ed6320e8082`.

The 2.1 GiB archive-build DerivedData tree was deleted after evidence capture.
Current R109 inventory is exactly one app nested inside exactly one retained
archive under `/private/tmp/Epistemos-AppStore-Release-R109`; no duplicate
DerivedData app remains.

**R109 RELEASE ARCHIVE AND ARTIFACT GATES GREEN / KEELSTONE STILL INCOMPLETE —
NOT RELEASE READY.** Automated artifact evidence does not prove launch,
owner-visible MarkEdit visual fidelity, toolbar interaction, surface switching,
large-document responsiveness in the shipped app, save/reopen behavior,
memory stability, Kokoro behavior, accessibility, or Apple distribution
acceptance. Exact next action: keep the exact archive bytes unchanged, inspect
the retained finite-runtime runbook and prior isolated runtime receipts,
perform a fresh owner-threshold resource preflight, and only if every threshold
passes launch this exact app in the isolated evidence environment for the
finite serial runtime matrix with correlated logs. Do not create another
archive or begin another canonical execution key.

### R110 exact R109-app finite-runtime preflight — GREEN

The retained runbook, current runtime-isolation source, and prior R85/runtime
receipts were re-read before launch. The new isolated root is planned beneath
the app's writable sandbox container at
`/Users/jojo/Library/Containers/com.epistemos.appstore/Data/tmp/Epistemos-R109-Runtime-20260715`.
Its `ApplicationSupport` and `AppGroup` children are separate, and the stable
defaults suite is
`com.epistemos.audit.runtime.keelstone.r109.20260715`. All planned paths were
absent at preflight. The tuple does not use the production defaults domain,
owner vault, saved state, App Group root, Keychain, removable media, or private
material.

The fresh mandatory preflight records:

- branch `feat/goose-surface`;
- local HEAD, `origin/feat/goose-surface`, and handoff publication all exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- 373 preserved dirty entries;
- 4,390.69 MiB swap used, strictly below 16,384 MiB;
- 56% system free memory;
- zero pages throttled;
- 491,026,632 KiB available Data-volume disk;
- no competing Xcode build, Swift/Clang/Metal compiler, local-model runtime,
  or Epistemos process. The process expression observed only its own short-
  lived preflight shell and `awk` process;
- exact inventory of one archive and its one nested app, with no DerivedData;
- strict signature still valid;
- executable SHA-256 still
  `8c305cdcbcc9c3d1171ae7e86b0d382cce6fd1858501fe75abb54bb1a216404f`;
- archive `Info.plist` SHA-256 still
  `c7b6688fc7ae44aedf88fad2f6e6a9c4c3c620270a96b014d6102a18aa8b6937`.

Every owner threshold passes. R110 authorizes only one isolated Launch Services
launch of the unchanged exact R109 app and the already-recorded finite Free V1
runtime matrix with correlated evidence. It does not authorize a build,
archive mutation, production-vault access, paid/model/provider/secret action,
new feature work, or another execution key.

### R110 exact R109-app finite-runtime partial result — PRODUCT CORRECTIONS REQUIRED

The exact retained R109 app launched once through Launch Services with the
authorized isolated tuple. The observed process was PID `68298`, launched at
`2026-07-15T20:33:10Z`, and was subsequently quit. It is now stopped. Retained
screenshots and accessibility evidence are under:

`/Users/jojo/Library/Containers/com.epistemos.appstore/Data/tmp/Epistemos-R109-Runtime-20260715/Evidence`

The uncontaminated runtime observations are:

- onboarding rendered, and the Free V1 home surface exposed no June, Browser,
  Research Hub, provider, or chat entry point;
- the Settings accessibility scan found no June, Browser, Research Hub,
  OpenAI, Anthropic, or Chat label, but still exposed dense/stale copy including
  `Shadow backend`, `ETL unavailable`, and premium-voice language; this remains
  settings-cleanup debt;
- a disposable Markdown note exposed only Prose, Preview, and Source. Small
  Prose typing, backspace, save, and Source switching succeeded;
- Source rendered the hosted MarkEdit editor with line numbers and the native
  title popover supplied Name, Tags, and Where fields;
- Source still exposed a `Source width` toolbar control. The owner has now
  superseded that control with a MarkEdit line-wrapping toggle;
- File > New Epdoc Document existed, but the home surface had no Epdoc shortcut
  and the File command displayed no keyboard equivalent;
- File > New Epdoc Document created
  `Vault/Untitled.epdoc`, but the initial Epdoc window collapsed its rich
  toolbar into overflow at the default window width; and
- neither embedded-graph nor hologram-graph Epdoc navigation was executed, so
  graph source presence remains unproven runtime behavior.

An attempted Epdoc typing/backspace interaction took approximately 45 seconds
while the owner concurrently changed the live UI. Computer-use returned a
user-change warning, and delayed input was then observed in the Markdown Source
window. That leg is contaminated: it is not classified as an Epdoc product
failure, a Markdown corruption failure, or a successful edit. The Epdoc package
still contained revision zero with an empty paragraph when inspected. A later
quit-without-saving dialog showed visually corrupted title text, but the same
session had already crossed the contamination boundary, so that visual is also
recorded as unclassified rather than promoted to a defect claim.

The R109 archive and its automated artifact gates remain exact evidence for
their recorded scope, but this runtime pass is not a complete release gate.
The owner has supplied corrective intent for Source wrapping, Epdoc
discoverability, Epdoc toolbar visibility, and both Epdoc graph routes.

**R110 RUNTIME MATRIX INCOMPLETE / KEELSTONE NOT RELEASE READY.** Exact next
action: update the intent ledger, read the current command/toolbar/MarkEdit and
Epdoc graph contracts, add fail-first behavioral tests, and implement only the
proven corrections. Preserve the R110 screenshots and isolation tuple, then
retire the now-stale R109 product before any fresh build. A new build or test
requires a new exact resource preflight and may produce only one current
Epistemos app artifact.

### R113 owner-correction narrow regression — GREEN

The R109 archive was retired before this build. The fresh mandatory preflight
recorded:

- branch `feat/goose-surface`;
- local HEAD, `origin/feat/goose-surface`, and handoff publication all exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- 381 preserved dirty entries;
- 4,136.31 MiB swap used, strictly below 16,384 MiB;
- 51% system free memory;
- zero pages throttled;
- 467 GiB available Data-volume disk; and
- no competing Xcode build, Swift/Clang/Metal compiler, local-model runtime,
  or Epistemos process.

The one retained build product for this leg is:

- DerivedData `/private/tmp/Epistemos-AppStore-Keelstone-R113`;
- app
  `/private/tmp/Epistemos-AppStore-Keelstone-R113/Build/Products/Debug/Epistemos.app`;
- result bundle
  `build/xcode-results/2026-07-15-keelstone-owner-corrections-r113.xcresult`;
- build/test log
  `build/logs/2026-07-15-keelstone-owner-corrections-r113.log`, SHA-256
  `e781500b0f768095ba00cc664b5116d6b20803009316e30ebece60546296d712`.

The Free V1 App Store target compiled and the following four selected Swift
Testing guards ran and passed:

- Source owns the live MarkEdit wrap toggle and no adjustable Source width;
- Landing exposes the native shortcut hints and canonical Markdown/JSON
  document creation commands;
- graph source preserves and opens Epdoc document nodes; and
- Notes sidebar routes supported files to explicit Home or Multitask
  destinations and exposes exactly Home Graph and Multitask Graph.

The result is `TEST SUCCEEDED`, with four tests in one suite and zero failures.
The Debug DerivedData tree is 1.8 GiB and its sole app product is 429 MiB.

**R113 NARROW REGRESSION GREEN / KEELSTONE STILL INCOMPLETE — NOT RELEASE
READY.** This leg proves compilation and the selected source contracts only.
It does not prove visual fidelity, pointer interaction, runtime Home/Multitask
routing, title animation, Epdoc autosave/save semantics, large-document
responsiveness, scroll/caret stability, memory stability, or distribution.
The exact next action is to preserve this result, finish the source-grounded
Epdoc persistence/performance and historical title audit, add fail-first
coverage, implement the owner's title and duplicate-title corrections in one
batch, then retire R113 before any replacement build. Do not create a Release
archive or begin another canonical execution key until that corrective batch
has current exact evidence.

### July 15 owner scope-reduction and review-pause checkpoint

No Xcode build, test, archive, app launch, audio action, model/provider action,
secret access, or runtime/manual evidence leg was run for this checkpoint. Three
delegated read-only audits and the executive edit owner inspected the current
canon, active source boundaries, current dirty editor batch, retained evidence,
and stale execution assumptions.

Repository identity remained grounded before the checkpoint edits:

- branch `feat/goose-surface`;
- local HEAD, `origin/feat/goose-surface`, and handoff publication all exact at
  `668b52cfb43721de95db102260d9f327ae24e13e`;
- the owner/in-flight dirty worktree was preserved without reset or overwrite.

The owner canceled LumenLens and all AI/agent/model/provider/generative work,
parked Reckoner and spreadsheet/database-product work reversibly, retained all
other requested non-AI work, and requested a pause checkpoint for review. The
decision and evidence classification are recorded in:

- `docs/canon/epistemos_mas_master_canon_2026_07_08/14_OWNER_SCOPE_REDUCTION_AND_PAUSE_CHECKPOINT_2026_07_15.md`;
- the matching attached source-of-truth canon folder;
- `docs/plans/keelstone/INTENT_LEDGER.md`; and
- `docs/handoffs/CURRENT_INFLIGHT_FEATURE_HANDOFF.md`.

R113 remains the newest valid Xcode result and is stale relative to the current
unbuilt editor batch. The latest source work has Swift-parse and `git diff
--check` evidence only; it has no current Xcode typecheck, scheme-member test,
app product, visual/manual pass, large-document runtime result, memory result,
accessibility result, or Release artifact.

The read-only boundary audit found unclosed Free V1 defects: Contextual Shadows
can still present stored chats; AI suggestion/diff/provenance and inert chat/LLM
services remain partly compiled; `.reckoner` remains in active capability truth;
and stale AI/June copy or gate assumptions remain. These findings prevent a
claim that the current source has fully removed AI or Reckoner.

**PAUSED / KEELSTONE INCOMPLETE — NOT RELEASE READY.** The safe next action
after owner review is to continue the same KEELSTONE key by fail-closing the
Free V1 AI/chat/Reckoner compile/query/presentation boundary, finish the retained
non-AI editor batch, retire R113, perform a new mandatory resource preflight,
and produce exactly one current App Store Debug build/test product. Do not start
another canonical execution key.

### July 15 no-stranded-directive coverage checkpoint

No Xcode build, test, archive, app launch, audio operation, model/provider/
secret access, or manual runtime action ran for this documentation-only audit.
Three read-only audits and the executive edit owner compared the chronological
intent ledger, canon 00-14, current P0 source seams, retained dirty work, tests,
and evidence. The complete add/remove/harden/test register is now:

- `docs/canon/epistemos_mas_master_canon_2026_07_08/15_OWNER_DIRECTIVE_COVERAGE_AND_HARDENING_CHECKPOINT_2026_07_15.md`.

It adds explicit coverage for Contextual Shadows and query-runtime leaks,
notebook/restoration compatibility, Free editor/AI compile membership,
bootstrap services, Reckoner policy, stale copy/release gates, deprecated
runtime state, Epdoc migration/export/save truth, 67k-72k-word performance,
MarkEdit Previewer/title/toolbars/Home/graphs, per-capability implementation and
proof status, Kokoro, named KEELSTONE debt, and the final evidence matrix.

The owner separately stated that Settings cleanup is in progress in another
session. Settings files are therefore externally owned in-flight work for this
checkpoint and were not edited, reverted, or absorbed here. Their final state
must be reconciled and tested at the later one-current-build boundary.

**PAUSED / KEELSTONE INCOMPLETE — NOT RELEASE READY.** R113 remains stale. The
safe next implementation action remains canon 15 Step 3 after explicit owner
resumption; no new execution key is authorized.

### July 15 two-lane prompt publication and new owner-observed defects

No production source implementation, Xcode command, app launch, archive,
audio, model/provider/secret, or manual runtime action ran while publishing the
two prompts.

The owner explicitly authorized two non-overlapping implementation sessions
and reported two current runtime defects:

- native Epdoc is visibly bare and lacks the previous rich Tiptap surface's
  robust blocks, header/title, fonts, palettes, toolbar, and behavior; and
- Multitask Graph opens blank.

The durable directive and executable prompts are:

- canon `16_TWO_LANE_REMOVAL_AND_REBUILD_DIRECTIVE_2026_07_15.md`;
- `docs/prompts/FREE_V1_REMOVAL_AND_FAIL_CLOSED_PROMPT_2026_07_15.md`; and
- `docs/prompts/RETAINED_BUILD_EPDOC_AND_MULTITASK_GRAPH_PROMPT_2026_07_15.md`.

Lane R owns canon 15 P0-A/A2/A3 through F. Lane B owns native rich Epdoc and
graph repair. Settings remains externally owned. Neither prompt authorizes
Xcode/app verification while the other lane is editing; one serial integration
artifact follows both stable source checkpoints.

**KEELSTONE REMAINS INCOMPLETE — NOT RELEASE READY.** The prompts remain under
the same KEELSTONE key and make no current behavior claim.

### July 15 sequential-lane correction and notebook boundary

The owner directed the sessions to run one at a time. Lane R removal is now
current; Lane B rich Epdoc/Multitask Graph construction is deferred until Lane
R records a stable source checkpoint. No Xcode command, app launch, archive,
or production implementation was performed while recording this correction.

The removal meaning is also narrowed explicitly: retire the legacy
Chat/Sheet/Body-strip workspace, launchers, stale restoration, and presentation
while preserving bytes and canonical JSON `.epdoc` document/block seams. A
future deterministic Epdoc-native notebook/structured-document feature remains
retained and may not revive Chat, Sheet/Reckoner, Tiptap, AI, or the retired
workspace ontology.

Exact next action: start only
`docs/prompts/FREE_V1_REMOVAL_AND_FAIL_CLOSED_PROMPT_2026_07_15.md`; do not
start Lane B yet.
