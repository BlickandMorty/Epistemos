# Resource Runtime Phase R Bridge — 2026-05-04

Track: T2 Sovereign Gate / Phase R resource runtime.

This bridge promotes the `codex/runtime-input-audit` Resource Runtime work into
fusion. Much of the code is already present in main; the bridge names the live
contract so future recovery can harden it instead of rediscovering it.

## Donor / Live Authority

Sources:

- branch `codex/runtime-input-audit`
- `agent_core/src/resources/bridge.rs`
- `agent_core/src/runtime/write_pipeline.rs`
- commits `8e4c5052`, `4d6cbec8`, `70c98ea2`

Current main evidence:

- `agent_core/src/resources/bridge.rs` contains the UniFFI permission-store
  bridge.
- `agent_core/src/runtime/write_pipeline.rs` contains verified-write and
  resource audit log primitives.

## Permission Store Contract

The bridge exposes purpose-specific functions rather than a broad Swift mirror
of the Rust `PermissionService` trait:

- list active grants;
- check a resource + capability;
- record a user-grant statement;
- revoke grants;
- initialize persistent storage at an app-container-safe path.

Grant summaries include:

- grant id;
- subject;
- scope (`Turn`, `Session`, `Persistent`);
- selector (`resource:`, `prefix:`, `vault:`, or `kind:`);
- capabilities (`Read`, `Write`, `Delete`, `Create`, `Search`);
- grant source and timestamps.

Fail-closed remains the rule for mutating resource operations.

## Verified Write Contract

`verified_write` enforces:

1. permission check for `Capability::Write`;
2. version-aware write through the resource service;
3. readback verification via checksum;
4. audit record for success, denial, conflict, resource error, or verification
   failure.

Audit rows record:

- actor;
- tool;
- resource URI;
- operation;
- before/after version;
- approval source;
- result;
- timestamp.

## Recovery Placement

Recovery status:

- The Rust bridge and verified-write pipeline exist in main.
- The next work is visibility and trust-hardening, not raw porting.

Next slices:

1. Ensure Swift initializes persistent permission storage before grants are
   recorded.
2. Ensure user-facing Settings / Provenance Console surfaces Rust-backed grants
   rather than hard-coded rows.
3. Attach ExecutionReceipt signing to verified mutating writes.
4. Add source guards for fail-closed mutating resource tools.
5. Preserve MAS/Pro separation for any resource kind that crosses sandbox or
   provider boundaries.

## Non-Negotiables

- No mutating write without a matching grant.
- No "approval in chat text" without persisted grant interpretation.
- No success claim before readback verification.
- No hidden broad grant when the user granted a narrow resource.
- No bypass of the Sovereign Gate in Swift.
