import Foundation
import Testing
import WebKit
@testable import Epistemos

// The Goose WebView surface was intentionally excised in 0b10f728b.
// Keep historical renderer-route coverage opt-in until that surface is restored.
#if EPISTEMOS_LEGACY_GOOSE_WEBVIEW
@Suite("Goose Web route live integration", .serialized)
struct GooseWebRouteLiveIntegrationTests {
    @Test(
        "live Goose WebView renders provider, settings, extensions, and skills routes"
    )
    @MainActor
    func liveGooseWebViewRendersPhase0Routes() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-webview-route-smoke.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withFreshGooseWebUIArtifact(proofName: "webview-route-smoke") { index in
            try await withLiveGooseRuntime(proofName: "webview-route-smoke") { binary, connection, progressURL in
            guard let acpURL = connection.acpWebSocketURL else {
                throw GooseLiveIntegrationError.runtimeFailed("Live Goose runtime did not produce an ACP WebSocket URL.")
            }
            let indexScript = firstGooseWebIndexScript(index)
            appendLiveProgress("goose ui index=\(index.path) script=\(indexScript)", to: progressURL)
            let providerCatalogMarkers = try await fetchLiveProviderCatalogRouteMarkers(acpURL: acpURL)
            let bootstrap = GooseWebBootstrap(
                baseURL: connection.baseURL,
                secretKey: connection.secretKey,
                config: GooseWebConfig(version: "phase0-webview-route-smoke")
            )
            let page = GooseWebSurfaceView.makeBootProbePage(
                bootstrap: bootstrap,
                gooseUIRoot: index.deletingLastPathComponent()
            )
            let uiServer = try await startGooseWebUILoopbackServer(root: index.deletingLastPathComponent())
            defer { uiServer.server.stop() }
            appendLiveProgress("before route smoke boot", to: progressURL)
            _ = page.load(URLRequest(url: GooseWebSurfaceView.loopbackURL(baseURL: uiServer.baseURL, route: "/?")))
            _ = try await waitForGooseWebBootProbe(page: page, progressURL: progressURL)

            let expectations: [GooseWebRouteExpectation] = [
                .init(
                    route: "/configure-providers",
                    requiredText: ["Provider Configuration Settings", "Add Provider"],
                    anyText: ["From template or manual setup"]
                ),
                .init(
                    route: "/settings?section=models",
                    eventView: "settings",
                    eventSection: "models",
                    requiredText: ["Settings"],
                    anyText: ["Models", "Provider", "Model"]
                ),
                .init(
                    route: "/settings?section=auth",
                    eventView: "settings",
                    eventSection: "auth",
                    requiredText: ["Settings", "Provider Credentials"],
                    requiredACPMethods: ["_goose/unstable/providers/config/status"],
                    forbiddenText: GooseWebRouteExpectation.defaultForbiddenText + [
                        "Failed to load provider credentials",
                    ]
                ),
                .init(
                    route: "/extensions",
                    requiredText: ["Extensions"],
                    anyText: ["Default Extensions", "Available Extensions", "developer", "No extensions available"],
                    requiredACPMethods: ["_goose/unstable/config/extensions/list"]
                ),
                .init(
                    route: "/apps",
                    requiredText: ["Apps"],
                    anyText: ["Import App", "No apps available", "Loading apps"]
                ),
                .init(
                    route: "/schedules",
                    requiredText: ["Scheduler"],
                    anyText: ["Create Schedule", "No schedules", "Loading"],
                    requiredACPMethods: ["_goose/unstable/schedules/list"]
                ),
                .init(
                    route: "/recipes",
                    requiredText: ["Recipes"],
                    anyText: ["Create Recipe", "No saved recipes", "Search recipes"],
                    requiredACPMethods: ["_goose/unstable/recipes/list"]
                ),
                .init(
                    route: "/sessions",
                    requiredText: ["Session History"],
                    anyText: ["No chat sessions found", "Search history", "Loading more sessions", "CHATS"],
                    requiredACPMethods: ["session/list"]
                ),
                .init(
                    route: "/skills",
                    requiredText: ["Skills"],
                    requiredACPMethods: ["_goose/unstable/sources/list"]
                ),
            ]

            var probes: [GooseWebRouteProbe] = []
            for expectation in expectations {
                let probe = try await waitForGooseWebRoute(
                    expectation: expectation,
                    page: page,
                    progressURL: progressURL
                )
                probes.append(probe)
            }
            let providerCatalogProbe = try await waitForGooseWebProviderCatalogPicker(
                catalogMarkers: providerCatalogMarkers,
                page: page,
                progressURL: progressURL
            )

            let routeLines = zip(expectations, probes).map { expectation, probe in
                [
                    "route=\(expectation.route)",
                    "hash=\(probe.hash)",
                    "text_chars=\(probe.textLength)",
                    "required_hits=\(probe.hits(for: expectation.requiredText).joined(separator: ","))",
                    "any_hits=\(probe.hits(for: expectation.anyText).joined(separator: ","))",
                    "forbidden_hits=\(probe.hits(for: expectation.forbiddenText).joined(separator: ","))",
                    "required_acp_methods=\(expectation.requiredACPMethods.joined(separator: ","))",
                    "seen_acp_methods=\(probe.hitsACPMethods(expectation.requiredACPMethods).joined(separator: ","))",
                ].joined(separator: " ")
            }
            let proof = ([
                "phase0_live_webview_route_smoke=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "goose_acp_url=\(connection.acpWebSocketURL.map(redactedACPURL) ?? "<missing>")",
                "goose_web_ui_origin=\(uiServer.baseURL.absoluteString)",
                "goose_web_ui_index=\(index.path)",
                "goose_web_ui_index_script=\(indexScript)",
                "provider_markers_source=goose_acp",
                "provider_catalog_markers=\(providerCatalogMarkers.joined(separator: ","))",
                "provider_catalog_picker_text_chars=\(providerCatalogProbe.textLength)",
                "provider_catalog_picker_hits=\(providerCatalogProbe.hits(for: providerCatalogMarkers).joined(separator: ","))",
                "provider_catalog_picker_acp_methods=\(providerCatalogProbe.hitsACPMethods(["_goose/unstable/providers/catalog/list"]).joined(separator: ","))",
            ] + routeLines).joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_webview_route_smoke=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live WebView route smoke proof log was not written.")
            }
            try GoosePhase0CapabilityMatrix.record(
                [.providerCatalog, .mcpApps],
                proofURL: proofURL,
                via: "embedded web UI routes -> goose serve ACP",
                details: ["routes": expectations.map(\.route).joined(separator: ",")]
            )
            }
        }
    }
}

private func firstGooseWebIndexScript(_ index: URL) -> String {
    guard let html = try? String(contentsOf: index, encoding: .utf8),
          let range = html.range(of: #"src="([^"]+)""#, options: .regularExpression) else {
        return "<missing>"
    }
    return String(html[range])
        .replacingOccurrences(of: #"src=""#, with: "")
        .replacingOccurrences(of: #"""#, with: "")
}

@MainActor
private func fetchLiveProviderCatalogRouteMarkers(acpURL: URL) async throws -> [String] {
    let client = GooseACPClient(
        transport: GooseACPURLSessionWebSocketTransport(url: acpURL),
        clientVersion: "phase0-webview-route-provider-catalog-markers"
    )

    do {
        _ = try await withLiveTimeout(
            seconds: 12,
            description: "ACP initialize for provider catalog route markers",
            onTimeout: { await client.close() },
            operation: { try await client.initialize() }
        )
        let catalog = try await withLiveTimeout(
            seconds: 20,
            description: "ACP provider catalog for route markers",
            onTimeout: { await client.close() },
            operation: { try await client.listGooseProviderCatalog(format: "openai") }
        )
        await client.close()

        let markers = catalog.providers.compactMap { provider -> String? in
            let name = provider.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? provider.providerId : name
        }
        let unique = Array(NSOrderedSet(array: markers)) as? [String] ?? markers
        let selected = Array(unique.prefix(10))
        guard !selected.isEmpty else {
            throw GooseLiveIntegrationError.runtimeFailed("Goose ACP provider catalog returned no provider route markers.")
        }
        return selected
    } catch {
        await client.close()
        throw error
    }
}

private struct GooseWebRouteExpectation: Sendable {
    static let defaultForbiddenText: [String] = [
        "Epistemos native host has not implemented",
        "Error Loading Recipes",
        "Error Loading Sessions",
        "Error Loading Skills",
        "Error loading apps",
        "Failed to refresh apps",
        "Failed to import app",
        "Failed to export app",
        "Failed to launch app",
        "Application error",
        "No routes matched location",
        "Provider config key is not available through Goose ACP",
        "Failed to check dictation config",
        "Failed to check telemetry config",
    ]

    let route: String
    let eventView: String
    let eventSection: String?
    let requiredText: [String]
    let anyText: [String]
    let forbiddenText: [String]
    let requiredACPMethods: [String]

    init(
        route: String,
        eventView: String? = nil,
        eventSection: String? = nil,
        requiredText: [String],
        anyText: [String] = [],
        requiredACPMethods: [String] = [],
        forbiddenText: [String] = Self.defaultForbiddenText
    ) {
        self.route = route
        self.eventView = eventView ?? String(route.drop(while: { $0 == "/" }).split(separator: "?").first ?? "")
        self.eventSection = eventSection
        self.requiredText = requiredText
        self.anyText = anyText
        self.forbiddenText = forbiddenText
        self.requiredACPMethods = requiredACPMethods
    }
}

private struct GooseWebRouteProbe: Decodable, Sendable {
    let readyState: String
    let href: String
    let hash: String
    let rootChildren: Int
    let bodyText: String
    let dialogText: String
    let textLength: Int
    let acpUrlPresent: Bool
    let providerLoadError: String?
    let serializedACPEvents: [String]
    let providerInventoryEvents: [String]
    let providerCatalogError: String?
    let providerCatalogEvents: [String]
    let lastProviderCatalogClick: String?
    let consoleMessages: [String]
    let scriptSources: [String]
    let socketEvents: [String]
    let outgoingACPMethods: [String]
    let incomingACPMethods: [String]
    let trace: GooseWebRouteACPTrace

    func hits(for needles: [String]) -> [String] {
        needles.filter { contains($0) }
    }

    func hitsACPMethods(_ methods: [String]) -> [String] {
        methods.filter { trace.outgoingMethodCounts[$0, default: 0] > 0 }
    }

    func matches(_ expectation: GooseWebRouteExpectation) -> Bool {
        rootChildren > 0
            && (readyState == "interactive" || readyState == "complete")
            && expectation.requiredText.allSatisfy(contains)
            && (expectation.anyText.isEmpty || expectation.anyText.contains(where: contains))
            && forbiddenHits(for: expectation.forbiddenText).isEmpty
            && expectation.requiredACPMethods.allSatisfy { trace.outgoingMethodCounts[$0, default: 0] > 0 }
    }

    func summary(for expectation: GooseWebRouteExpectation) -> String {
        let forbiddenHits = forbiddenHits(for: expectation.forbiddenText)
        return [
            "href=\(href)",
            "hash=\(hash)",
            "ready=\(readyState)",
            "root=\(rootChildren)",
            "text_chars=\(textLength)",
            "required=\(hits(for: expectation.requiredText).joined(separator: ","))",
            "any=\(hits(for: expectation.anyText).joined(separator: ","))",
            "forbidden=\(forbiddenHits.joined(separator: ","))",
            "acp=\(hitsACPMethods(expectation.requiredACPMethods).joined(separator: ","))",
            "outgoing=\(outgoingACPMethods.suffix(10).joined(separator: ","))",
            "incoming=\(incomingACPMethods.suffix(10).joined(separator: ","))",
            "acp_url=\(acpUrlPresent ? "present" : "missing")",
            "provider_error=\(providerLoadError ?? "")",
            "serialized_acp=\(serializedACPEvents.suffix(10).joined(separator: ","))",
            "inventory_events=\(providerInventoryEvents.suffix(8).joined(separator: ","))",
            "catalog_error=\(providerCatalogError ?? "")",
            "catalog_events=\(providerCatalogEvents.suffix(8).joined(separator: ","))",
            "scripts=\(scriptSources.suffix(4).joined(separator: ","))",
            "socket=\(socketEvents.suffix(6).joined(separator: ","))",
            "console=\(consoleMessages.suffix(4).joined(separator: " | "))",
            "last_click=\(lastProviderCatalogClick ?? "")",
            "dialog=\(dialogText.prefix(420))",
            "sample=\(bodyText.prefix(260))",
        ].joined(separator: " ")
    }

    private func contains(_ needle: String) -> Bool {
        bodyText.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func forbiddenHits(for needles: [String]) -> [String] {
        needles.filter { needle in
            contains(needle)
                || dialogText.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || consoleMessages.contains { $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
                || (providerLoadError?.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
                || (providerCatalogError?.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
        }
    }
}

private struct GooseWebRouteACPTrace: Decodable, Sendable {
    let outgoingMethodCounts: [String: Int]
}

@MainActor
private func waitForGooseWebRoute(
    expectation: GooseWebRouteExpectation,
    page: WebPage,
    progressURL: URL
) async throws -> GooseWebRouteProbe {
    try await driveGooseWebRouteNavigation(expectation, page: page)
    _ = try await dismissGooseWebTelemetryPromptIfPresent(page: page)
    appendLiveProgress("route navigate \(expectation.route)", to: progressURL)

    var lastProbe: GooseWebRouteProbe?
    var stableMatches = 0
    for attempt in 0..<220 {
        if attempt % 5 == 0 {
            try await driveGooseWebRouteNavigation(expectation, page: page)
            _ = try await dismissGooseWebTelemetryPromptIfPresent(page: page)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        _ = try await dismissGooseWebTelemetryPromptIfPresent(page: page)
        let probe = try await readGooseWebRouteProbe(page)
        lastProbe = probe
        if attempt % 10 == 0 || probe.matches(expectation) {
            appendLiveProgress(
                "route \(expectation.route) attempt=\(attempt) \(probe.summary(for: expectation))",
                to: progressURL
            )
        }
        if probe.matches(expectation) {
            stableMatches += 1
            if stableMatches >= 3 {
                return probe
            }
        } else {
            stableMatches = 0
        }
    }

    let summary = lastProbe?.summary(for: expectation) ?? "no route probe"
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for Goose Web route \(expectation.route): \(summary).")
}

@MainActor
private func waitForGooseWebProviderCatalogPicker(
    catalogMarkers: [String],
    page: WebPage,
    progressURL: URL
) async throws -> GooseWebRouteProbe {
    let route = GooseWebRouteExpectation(
        route: "/configure-providers",
        requiredText: ["Provider Configuration Settings", "Add Provider"],
        anyText: ["From template or manual setup"]
    )
    _ = try await waitForGooseWebRoute(
        expectation: route,
        page: page,
        progressURL: progressURL
    )

    guard try await clickGooseWebElement(
        page: page,
        script: """
        const card = document.querySelector('[data-testid="add-custom-provider-card"]');
        if (card instanceof HTMLElement) {
          card.click();
          return true;
        }
        return false;
        """
    ) else {
        throw GooseLiveIntegrationError.runtimeFailed("Goose Web provider route did not expose the Add Provider card.")
    }
    appendLiveProgress("provider catalog opened add-provider modal", to: progressURL)

    try await waitForGooseWebText(
        ["Start from a provider template", "Configure manually"],
        page: page,
        progressURL: progressURL,
        description: "provider setup choice modal"
    )

    guard try await clickGooseWebElement(
        page: page,
        script: """
        const isVisible = (element) => {
          const rect = element.getBoundingClientRect();
          const style = window.getComputedStyle(element);
          return rect.width > 0 &&
            rect.height > 0 &&
            style.visibility !== 'hidden' &&
            style.display !== 'none';
        };
        const explicit = document.querySelector('[data-testid="provider-catalog-template-choice"]');
        const buttons = Array.from(document.querySelectorAll('[role="dialog"] button, button'))
          .filter((candidate) => candidate instanceof HTMLElement)
          .filter(isVisible);
        const button = explicit instanceof HTMLElement && isVisible(explicit)
          ? explicit
          : buttons.find((candidate) =>
          (candidate.innerText || '').includes('Start from a provider template')
        );
        if (button instanceof HTMLElement) {
          window.__epistemosGooseLastProviderCatalogClick = button.innerText || '';
          button.scrollIntoView({ block: 'center', inline: 'center' });
          for (const type of ['pointerdown', 'mousedown', 'mouseup', 'click']) {
            const event = type.startsWith('pointer')
              ? new PointerEvent(type, { bubbles: true, cancelable: true, pointerType: 'mouse' })
              : new MouseEvent(type, { bubbles: true, cancelable: true });
            button.dispatchEvent(event);
          }
          button.click();
          return true;
        }
        return false;
        """
    ) else {
        throw GooseLiveIntegrationError.runtimeFailed("Goose Web provider modal did not expose the template catalog button.")
    }
    appendLiveProgress("provider catalog clicked template choice", to: progressURL)

    let catalogExpectation = GooseWebRouteExpectation(
        route: "/configure-providers",
        requiredText: ["Choose Provider", "API Format"],
        anyText: catalogMarkers,
        requiredACPMethods: ["_goose/unstable/providers/catalog/list"]
    )
    var lastProbe: GooseWebRouteProbe?
    var stableMatches = 0
    for attempt in 0..<220 {
        if attempt % 5 == 0 {
            _ = try await dismissGooseWebTelemetryPromptIfPresent(page: page)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        let probe = try await readGooseWebRouteProbe(page)
        lastProbe = probe
        if attempt % 10 == 0 || probe.matches(catalogExpectation) {
            appendLiveProgress(
                "provider catalog picker attempt=\(attempt) \(probe.summary(for: catalogExpectation))",
                to: progressURL
            )
        }
        if probe.matches(catalogExpectation) {
            stableMatches += 1
            if stableMatches >= 3 {
                return probe
            }
        } else {
            stableMatches = 0
        }
    }
    let summary = lastProbe?.summary(for: catalogExpectation) ?? "no provider catalog probe"
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for Goose provider catalog picker: \(summary).")
}

@MainActor
private func dismissGooseWebTelemetryPromptIfPresent(page: WebPage) async throws -> Bool {
    try await clickGooseWebElement(
        page: page,
        script: """
        const textOf = (element) => `${element.innerText || ''} ${element.textContent || ''}`;
        const isVisible = (element) => {
          if (!(element instanceof HTMLElement)) return false;
          const rect = element.getBoundingClientRect();
          const style = window.getComputedStyle(element);
          return rect.width > 0 &&
            rect.height > 0 &&
            style.visibility !== 'hidden' &&
            style.display !== 'none';
        };
        const dialogs = Array.from(document.querySelectorAll('[role="dialog"]'))
          .filter((dialog) => /Help improve Epistemos/i.test(dialog.innerText || ''));
        for (const dialog of dialogs) {
          const button = Array.from(dialog.querySelectorAll('button, [role="button"]'))
            .filter(isVisible)
            .find((candidate) => /No thanks/i.test(textOf(candidate)));
          if (button instanceof HTMLElement) {
            button.dispatchEvent(new MouseEvent('pointerdown', { bubbles: true }));
            button.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
            button.click();
            button.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }));
            button.dispatchEvent(new MouseEvent('pointerup', { bubbles: true }));
            return true;
          }
        }
        return false;
        """
    )
}

@MainActor
private func waitForGooseWebText(
    _ requiredText: [String],
    page: WebPage,
    progressURL: URL,
    description: String
) async throws {
    let expectation = GooseWebRouteExpectation(
        route: "/configure-providers",
        requiredText: requiredText
    )
    for attempt in 0..<100 {
        try await Task.sleep(nanoseconds: 100_000_000)
        _ = try await dismissGooseWebTelemetryPromptIfPresent(page: page)
        let probe = try await readGooseWebRouteProbe(page)
        if attempt % 10 == 0 || probe.matches(expectation) {
            appendLiveProgress(
                "\(description) attempt=\(attempt) \(probe.summary(for: expectation))",
                to: progressURL
            )
        }
        if probe.matches(expectation) {
            return
        }
    }
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for Goose Web \(description).")
}

@MainActor
private func clickGooseWebElement(page: WebPage, script: String) async throws -> Bool {
    let result = try await page.callJavaScript(script)
    return (result as? Bool) == true
}

@MainActor
private func driveGooseWebRouteNavigation(
    _ expectation: GooseWebRouteExpectation,
    page: WebPage
) async throws {
    try await page.callJavaScript(
        """
        if (typeof window.electron?.emit === 'function') {
          window.electron.emit(
            'set-view',
            \(javaScriptStringLiteral(expectation.eventView)),
            \(expectation.eventSection.map(javaScriptStringLiteral) ?? "undefined")
          );
        } else {
          window.location.hash = \(javaScriptStringLiteral("#\(expectation.route)"));
        }
        true;
        """
    )
}

@MainActor
private func readGooseWebRouteProbe(_ page: WebPage) async throws -> GooseWebRouteProbe {
    let result = try await page.callJavaScript(
        """
        const bodyText = (document.body?.innerText || '').replace(/\\s+/g, ' ').trim();
        const dialogText = (document.querySelector('[role="dialog"]')?.innerText || '')
          .replace(/\\s+/g, ' ')
          .trim();
        const trace = window.epistemos?.goose?.acpTrace?.() ?? { events: [], outgoingMethodCounts: {} };
        const consoleEvents = window.epistemos?.goose?.consoleEvents?.() ?? [];
        return JSON.stringify({
          readyState: document.readyState,
          href: window.location.href,
          hash: window.location.hash,
          rootChildren: document.getElementById('root')?.children?.length ?? -1,
          bodyText,
          dialogText,
          textLength: bodyText.length,
          acpUrlPresent: Boolean(window.epistemos?.goose?.acpUrl),
          providerLoadError: window.__epistemosGooseProviderLoadError ?? null,
          serializedACPEvents: (window.__epistemosGooseACPRequestSerialization || [])
            .map((event) => `${event.name}:${event.phase}`)
            .slice(-16),
          providerInventoryEvents: (window.__epistemosGooseProviderInventoryEvents || [])
            .map((event) => `${event.name}:${event.detail || ''}`)
            .slice(-12),
          providerCatalogError: window.__epistemosGooseProviderCatalogError ?? null,
          providerCatalogEvents: (window.__epistemosGooseProviderCatalogEvents || [])
            .map((event) => `${event.name}:${event.detail || ''}`)
            .slice(-12),
          lastProviderCatalogClick: window.__epistemosGooseLastProviderCatalogClick ?? null,
          consoleMessages: consoleEvents.map((event) => `${event.level}:${event.message}`).slice(-8),
          scriptSources: Array.from(document.querySelectorAll('script[src]'))
            .map((script) => script.getAttribute('src') || '')
            .slice(-12),
          socketEvents: (trace.events || [])
            .filter((event) => event.direction === 'socket')
            .map((event) => event.detail === null || event.detail === undefined
              ? event.method
              : `${event.method}:${event.detail}`
            )
            .slice(-8),
          outgoingACPMethods: Object.keys(trace.outgoingMethodCounts || {}).sort(),
          incomingACPMethods: Object.keys(trace.incomingMethodCounts || {}).sort(),
          trace
        });
        """
    )
    guard let json = result as? String,
          let data = json.data(using: .utf8) else {
        throw GooseLiveIntegrationError.runtimeFailed("Goose WebView route probe did not return JSON.")
    }
    return try JSONDecoder().decode(GooseWebRouteProbe.self, from: data)
}

private func javaScriptStringLiteral(_ value: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: [value]),
          let json = String(data: data, encoding: .utf8),
          json.first == "[",
          json.last == "]" else {
        return #""""#
    }
    return String(json.dropFirst().dropLast())
}
#endif
