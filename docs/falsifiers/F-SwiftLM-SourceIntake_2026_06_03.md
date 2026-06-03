---
falsifier: F-SwiftLM-SourceIntake
status: PASS
artifact: artifacts/falsifiers/swiftlm_source_intake/result.json
command: Tools/falsifiers/f_swiftlm_source_intake.sh
created_on: 2026-06-03
---

# F-SwiftLM-SourceIntake

## Scope

`F-SwiftLM-SourceIntake` is the eighth Research Construction Engine primary
witness. It proves SwiftLM is captured as source-mined motif evidence before
any implementation import, product dependency, runtime route change, or model
byte load.

The witness records SwiftLM as source cards for SSD expert streaming, KV
compression, persistent buffers, and prefetch. Each card carries license/setup
notes, benchmark caveats, route affinities, and a local test-plan hook.

## Artifact

```text
artifacts/falsifiers/swiftlm_source_intake/result.json
```

## What Passed

- Four SwiftLM source cards are present and sorted deterministically.
- The repo card and motif-detail edges bind SSD streaming, KV compression,
  persistent buffers, and prefetch into the source signal graph.
- License, setup, benchmark caveat, and local test-plan metadata are present
  before any code import.
- Duplicate source, missing license, missing benchmark caveat, missing local
  test plan, and implementation-import fixtures reject.
- Runtime/model bytes loaded remain `0`.

## Current Meaning

The default main-only architecture cursor moved from:

```text
F-SwiftLM-SourceIntake
```

to the now-implemented:

```text
F-MetaBreakthrough-CardRegistry
```

The current cursor is:

```text
F-RustRouteKernel-ModelCheck
```

This preserves the large-local-model and 70B cold-assembly research thread
while keeping Qwen/GGUF 128K shard work and provider-reference prompts deferred
unless `EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1` is explicitly set.

## Verification Command

```bash
Tools/falsifiers/f_swiftlm_source_intake.sh
```
