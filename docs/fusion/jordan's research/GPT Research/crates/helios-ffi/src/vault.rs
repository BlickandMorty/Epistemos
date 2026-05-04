//! Vault FFI operations. Real security-scoped bookmark resolution is implemented in Swift/macOS.

pub type VaultId = u64;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct VaultAccessPolicy {
    pub requires_biometric: bool,
    pub bookmark_data_base64: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Task {
    pub prompt: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskResult {
    pub text: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum VaultError {
    Locked,
    InvalidPath,
    PermissionDenied,
}

#[must_use]
pub fn create_vault(path: String, _policy: VaultAccessPolicy) -> VaultId {
    stable_id(path.as_bytes())
}

pub fn unlock_vault(_id: VaultId) -> Result<(), VaultError> { Ok(()) }
pub fn lock_vault(_id: VaultId) -> Result<(), VaultError> { Ok(()) }

pub fn dispatch_to_vault(_id: VaultId, task: Task) -> Result<TaskResult, VaultError> {
    Ok(TaskResult { text: format!("queued: {}", task.prompt) })
}

fn stable_id(bytes: &[u8]) -> VaultId {
    let mut hash = 0xcbf2_9ce4_8422_2325_u64;
    for byte in bytes {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x1000_0000_01b3);
    }
    hash
}
