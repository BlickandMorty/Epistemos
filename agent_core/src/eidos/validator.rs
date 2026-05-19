//! Closed-citation validator harness.
//!
//! This is the named emit-gate surface for chat / bridge callers. It wraps
//! `EidosContextPacket::validate_citations` without changing semantics:
//! every citation must validate against the packet or the answer is rejected
//! wholesale with per-index diagnostics.

use super::types::{CitationError, EidosCitation, EidosContextPacket};

#[derive(Debug, PartialEq)]
pub struct ClosedCitationValidation {
    pub accepted_count: usize,
}

#[derive(Debug, PartialEq)]
pub struct ClosedCitationValidationError {
    pub errors: Vec<(usize, CitationError)>,
}

pub fn enforce_closed_citation_contract(
    packet: &EidosContextPacket,
    citations: &[EidosCitation],
) -> Result<ClosedCitationValidation, ClosedCitationValidationError> {
    match packet.validate_citations(citations) {
        Ok(()) => Ok(ClosedCitationValidation {
            accepted_count: citations.len(),
        }),
        Err(errors) => Err(ClosedCitationValidationError { errors }),
    }
}
