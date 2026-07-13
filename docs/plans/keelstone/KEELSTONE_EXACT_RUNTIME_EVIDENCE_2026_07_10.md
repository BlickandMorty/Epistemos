# KEELSTONE Exact Runtime Evidence — 2026-07-10

Current canonical execution key:
`EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08`.

Current final verdict: **INCOMPLETE**.

The original 2026-07-10 pass stopped at its mandatory resource preflight. The
owner authorized exact continuation after a forced restart on 2026-07-12. That
continuation restored the developer prerequisites and June source/stage,
completed the narrow Debug compile/regression leg, and then stopped before the
Release archive because this Mac has no Apple signing identity or provisioning
profile. No Release archive, archive artifact gate, owner-visible runtime
matrix, model load, provider request, Keychain-secret read, owner-vault
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

## Final KEELSTONE Verdict

**INCOMPLETE**

Reason: the post-reset resource gate and narrow Debug compile/regression leg
now pass, but Apple signing remains absent. No current signed Release archive,
archive artifact-gate pass, or finite owner-visible runtime matrix exists.
KEELSTONE therefore remains incomplete at the Release-archive signing
boundary.

No recommendation to begin another canonical execution key is made.
