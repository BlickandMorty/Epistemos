import Foundation

// ============================================================================
// ProvenanceGate record — VENDORED THIRD-PARTY SOURCE
// ----------------------------------------------------------------------------
// Source:    github.com/osaurus-ai/osaurus  (the active repo; dinoki-ai/osaurus
//            is archived/moved)
// License:   MIT
// Posture:   direct_import  (verbatim source; MIT is App-Store/closed-source
//            compatible — unlike the AGPL repos in R-FIELDTHEORY / Khoj)
// Imported:  2026-06-19 — Osaurus P3.0 Act import, Seam A / S2 (smallest real seam)
// Vendored:  Packages/OsaurusCore/Models/Configuration/ServerHealth.swift
//            (the server-health enum the Act bridge reports). Verbatim body; the
//            only Epistemos additions are the `#if !EPISTEMOS_APP_STORE` MAS/Pro
//            boundary wrapper + provenance headers. `L(_:)` (OsaurusCore's
//            localization helper, not vendored) is satisfied by the local shim
//            OsaurusVendorLocalization.swift.
// Boundary:  the vendored runtime-bearing seam is Pro-only — Osaurus's defining
//            powers (HTTP server :1337, Apple Containerization Linux VM, relay
//            tunnels, system plugins) are OUTSIDE the MAS sandbox. On the MAS
//            build, Act stays on the in-process local-agent path. See
//            docs/OSAURUS_P3_IMPORT_PLAN_2026_06_19.md.
//
//   The MIT License (osaurus-ai/osaurus):
//
//   MIT License
//
//   Copyright (c) 2026 Osaurus, Inc.
//
//   Permission is hereby granted, free of charge, to any person obtaining a copy
//   of this software and associated documentation files (the "Software"), to deal
//   in the Software without restriction, including without limitation the rights
//   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//   copies of the Software, and to permit persons to whom the Software is
//   furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all
//   copies or substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//   SOFTWARE.
// ============================================================================

/// Machine-readable provenance for the vendored Osaurus seam (the human record is
/// the header above). Always-compiled so it's inspectable from any build.
nonisolated enum OsaurusVendorProvenance {
    static let sourceRepo = "osaurus-ai/osaurus"
    static let license = "MIT"
    static let posture = "direct_import"
    static let importedDate = "2026-06-19"
}
