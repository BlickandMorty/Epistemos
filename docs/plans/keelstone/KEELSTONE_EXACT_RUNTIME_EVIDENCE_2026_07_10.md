# KEELSTONE Exact Runtime Evidence — 2026-07-10

Current canonical execution key:
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.

Current final verdict: **INCOMPLETE**.

The original 2026-07-10 pass stopped at its mandatory resource preflight. The
owner authorized exact continuation after a forced restart on 2026-07-12, then
dated a controlling free-V1 product boundary on 2026-07-13: June, generative
AI, models, Browser, and ResearchHub are paid-only and hidden/inert; Kokoro and
the deterministic local capability ring remain free. The latest continuation
now has a passing narrow free-V1 regression result, exactly one current Release
archive, a verified local ad-hoc sandbox signature, and a green exact-artifact
gate. The owner-visible runtime matrix did not begin because macOS was locked.
No model load, provider request, Keychain-secret read, owner-vault operation,
or audio operation was performed.

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
