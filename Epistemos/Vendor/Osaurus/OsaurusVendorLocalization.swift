import Foundation

// Vendor support shim for the Osaurus `direct_import` (see OsaurusVendorProvenance).
// OsaurusCore exposes a global `L(_:)` localization helper; Epistemos vendors only
// the ServerHealth seam, not OsaurusCore's localization layer, so this minimal shim
// satisfies the vendored source's `L("…")` calls. Pro-gated to match the vendored
// seam's MAS/Pro boundary (the only caller is the Pro-only ServerHealth.swift).
#if !EPISTEMOS_APP_STORE
/// Minimal localization shim for vendored Osaurus source — only the vendored
/// Osaurus files call it. Epistemos defines no other global `L(_:)`.
func L(_ key: String) -> String { NSLocalizedString(key, comment: "osaurus-vendored") }
#endif
