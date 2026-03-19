# Safety Audit

## Staged knowledge-core

Good:

- archive access goes through `rkyv::access`
- ring slot writes are bounds-checked before raw copies
- tests cover layout and round-trip correctness

Weak points:

- many older `unsafe` blocks in `lib.rs` still rely on macro conventions rather than local `// SAFETY:` comments
- Swift raw-pointer slot reads are only guarded by layout preconditions and sequence discipline
- no fuzz harness exists for malformed archived payloads

## Verdict

The staged knowledge-core path is safer than the older BTK byte-buffer path. The repo is still short of a full “every unsafe justified” standard.
