import SwiftUI

// MARK: - BrowserCapabilityHealthRow
//
// SS-M / Obscura (owner 2026-06-19): an honest, read-only Settings → Diagnostics row for the browser /
// scraper / privacy capability — what actually works (HTTP fetch/extract/crawl/schema extraction,
// search, private in-app web views) vs what's a stub or Pro-gated (the Obscura stealth engine returns
// NotConfigured; anti-fingerprint isn't built). Reads
// BrowserCapabilityStatus's static, code-verified ledger only (no @Environment → crash-safe in
// Settings). Info-tinted, never a green "complete" check (the stealth browser isn't built) or a red
// "broken" cross (the real scraper genuinely works).

@MainActor
public struct BrowserCapabilityHealthRow: View {

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "network")
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Browser & scraper")
                    .font(.system(size: 13, weight: .medium))
                Text(BrowserCapabilityStatus.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text("\(BrowserCapabilityStatus.liveCount)/\(BrowserCapabilityStatus.capabilities.count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
