//! UniFFI-facing Rust API scaffold.

pub mod biometric;
pub mod vault;

pub use biometric::{authenticate_biometric, detect_biometric_change, AuthError};
pub use vault::{create_vault, dispatch_to_vault, lock_vault, unlock_vault, Task, TaskResult, VaultAccessPolicy, VaultError, VaultId};
