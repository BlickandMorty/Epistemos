import SwiftUI

struct BrowserUseSettingsView: View {
    @State private var status = BrowserUseProGateStatus.status()
    @State private var manifestURL = BrowserUseProGateStatus.defaultManifestURL()
    @State private var manifest: BrowserUseVendorManifest?
    @State private var manifestReadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                gateCard
                sourceCard
                packagingCard
                settingsContractCard
                boundaryCard
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .topLeading)
        }
        .task {
            refresh()
        }
    }

    private var headerCard: some View {
        SettingsSurfaceCard {
            HStack(alignment: .top, spacing: 14) {
                IntegrationBrandMarkView(brand: .browserUse, size: 32)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("browser-use Pro")
                        .font(.headline)
                    Text("Developer ID automation lane for the vendored browser-use Chromium robot. The App Store Browser tab stays a separate, human-driven WKWebView.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        ChannelStatusPill(title: "Pro only", tint: .orange)
                        ChannelStatusPill(title: "Chromium/CDP", tint: .secondary)
                        ChannelStatusPill(title: "Separate browser", tint: .blue)
                    }
                }
                Spacer()
                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh browser-use Pro status")
            }
        }
    }

    private var gateCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Gate Status")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(
                        title: status.isActive ? "Ready" : "Inactive",
                        tint: status.isActive ? .green : .orange
                    )
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(status.headline)
                        .font(.subheadline.weight(.semibold))
                    Text(status.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ChannelStatusPill(title: BrowserUseProGateStatus.flagName, tint: .secondary)
            }
        }
    }

    private var sourceCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Vendored Source")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(title: "Full clone required", tint: .blue)
                }

                if let manifest {
                    ForEach(manifest.components, id: \.name) { component in
                        HStack(alignment: .top, spacing: 12) {
                            IntegrationBrandMarkView(brand: .browserUse, size: 22)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(component.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(component.repo) @ \(component.commit.prefix(12))")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            ChannelStatusPill(title: component.license, tint: .secondary)
                            ChannelStatusPill(
                                title: component.fullClone ? "full clone" : "partial",
                                tint: component.fullClone ? .green : .red
                            )
                            ChannelStatusPill(title: "\(component.fileCount) files", tint: .blue)
                        }
                        if component.name != manifest.components.last?.name {
                            Divider()
                        }
                    }
                } else {
                    statusMessage(
                        title: "Vendor manifest unavailable",
                        detail: manifestReadError ?? "No browser-use manifest was found in the app bundle or source tree.",
                        tint: .orange
                    )
                }
            }
        }
    }

    private var packagingCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Pro Payload Packaging")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(
                        title: manifest?.isProPayloadStaged == true ? "Staged" : "Not staged",
                        tint: manifest?.isProPayloadStaged == true ? .green : .orange
                    )
                }

                if let manifest {
                    packagingRow("requirements.lock", artifact: manifest.packagingArtifacts.requirementsLock)
                    Divider()
                    packagingRow("wheels", artifact: manifest.packagingArtifacts.wheelhouse)
                    Divider()
                    packagingRow("Playwright Chromium", artifact: manifest.packagingArtifacts.playwrightChromium)
                } else {
                    statusMessage(
                        title: "Packaging state unknown",
                        detail: "The manifest must be readable before the Pro payload can be considered staged.",
                        tint: .orange
                    )
                }
            }
        }
    }

    private var settingsContractCard: some View {
        let defaults = BrowserUseSettings.default

        return SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Settings Contract")
                        .font(.headline)
                    Spacer()
                    ChannelStatusPill(title: "Env renderer", tint: .blue)
                    ChannelStatusPill(title: "Keychain secrets", tint: .green)
                }

                settingsFactRow(
                    "Default LLM",
                    value: defaults.providers.defaultLLM,
                    detail: "Preserves the web-ui DEFAULT_LLM selector."
                )
                Divider()
                settingsFactRow(
                    "Privacy defaults",
                    value: "Telemetry off, cloud sync off, version checks off",
                    detail: "Epistemos writes the browser-use environment from explicit settings at Pro launch."
                )
                Divider()
                settingsFactRow(
                    "Browser profile",
                    value: "\(defaults.browser.resolution), CDP \(defaults.browser.debuggingHost):\(defaults.browser.debuggingPort)",
                    detail: "Keeps browser path, user data, own-browser, CDP, and browser-use executable settings."
                )
                Divider()
                settingsFactRow(
                    "Secret bindings",
                    value: "\(BrowserUseSecretBinding.allCases.count) Keychain environment keys",
                    detail: "Provider keys, cloud keys, proxy credentials, AWS credentials, and VNC password are not stored in manifests."
                )
                Divider()
                settingsFactRow(
                    "Non-secret settings",
                    value: "\(defaults.nonSecretEnvironmentPairs.count) environment keys",
                    detail: "Saved as BrowserUsePro settings JSON and rendered with Keychain secrets into a launch-time .env."
                )
            }
        }
    }

    private var boundaryCard: some View {
        SettingsSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Boundary")
                    .font(.headline)

                boundaryRow(
                    symbol: "safari",
                    title: "Native Browser tab",
                    detail: "Human-driven WKWebView for App Store builds. browser-use does not drive it."
                )
                boundaryRow(
                    symbol: "terminal",
                    title: "Pro runtime",
                    detail: "Python, Playwright, Chromium, and subprocess launch remain outside the MAS path."
                )
                boundaryRow(
                    symbol: "key",
                    title: "Secrets",
                    detail: "Provider keys, browser-use cloud keys, and proxy credentials belong in Keychain, not manifests or logs."
                )
            }
        }
    }

    @ViewBuilder
    private func packagingRow(
        _ title: String,
        artifact: BrowserUseVendorManifest.PackagingArtifact
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(artifact.expectedPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let notes = artifact.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            ChannelStatusPill(title: artifact.status, tint: artifact.status == "staged" ? .green : .orange)
        }
    }

    private func boundaryRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsFactRow(_ title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusMessage(title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func refresh() {
        status = BrowserUseProGateStatus.status()
        manifestURL = BrowserUseProGateStatus.defaultManifestURL()
        guard let manifestURL else {
            manifest = nil
            manifestReadError = nil
            return
        }

        do {
            manifest = try BrowserUseVendorManifest.load(from: manifestURL)
            manifestReadError = nil
        } catch {
            manifest = nil
            manifestReadError = BrowserUseDiagnostics.statusMessage(for: error, fallback: "manifest read failed")
        }
    }
}
