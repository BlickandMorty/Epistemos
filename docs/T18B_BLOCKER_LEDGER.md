| ID | Blocker | Probe | Cadence | First seen | Status | Resolved |
| --- | --- | --- | --- | --- | --- | --- |
| CARGO-PATH | cargo/rustfmt not on sandbox PATH | PATH="$HOME/.cargo/bin:$PATH" cargo --version | every 5 iters | iter-249 | RESOLVED WITH EXPLICIT PATH | iter-249 |
| CARGO-TOOLCHAIN | rustup has no default toolchain in sandbox shell | PATH="$HOME/.cargo/bin:$PATH" cargo +stable --version | every 5 iters | iter-315 | RESOLVED WITH EXPLICIT TOOLCHAIN SELECTOR | iter-315 |
