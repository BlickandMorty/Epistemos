//! Biometric FFI placeholders. Swift owns LAContext calls.

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AuthError {
    NotAvailable,
    Denied,
}

pub fn authenticate_biometric(_reason: String) -> Result<bool, AuthError> {
    Err(AuthError::NotAvailable)
}

pub fn detect_biometric_change() -> Result<bool, AuthError> {
    Err(AuthError::NotAvailable)
}
