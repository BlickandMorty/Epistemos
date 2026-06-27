import Foundation
import Testing
import WebKit
@testable import Epistemos

@Suite("Goose Web route live integration", .serialized)
struct GooseWebRouteLiveIntegrationTests {
    @Test(
        "live Goose WebView renders provider, settings, extensions, and skills routes"
    )
    @MainActor
    func liveGooseWebViewRendersPhase0Routes() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-webview-route-smoke.log")
        try? FileManager.default.removeItem(at: proofURL)

        guard let index = GooseWebUIResolver.indexURL() else {
            throw GooseLiveIntegrationError.runtimeFailed("No staged ACP-mode Goose Web UI artifact was found.")
        }

        try await withLiveGooseRuntime(proofName: "webview-route-smoke") { binary, connection, progressURL in
            let bootstrap = GooseWebBootstrap(
                baseURL: connection.baseURL,
                secretKey: connection.secretKey,
                config: GooseWebConfig(version: "phase0-webview-route-smoke")
            )
            let page = GooseWebSurfaceView.makeBootProbePage(
                bootstrap: bootstrap,
                gooseUIRoot: index.deletingLastPathComponent()
            )
            appendLiveProgress("before route smoke boot", to: progressURL)
            _ = page.load(URLRequest(url: GooseWebSurfaceView.bootURL(for: index)))
            _ = try await waitForGooseWebBootProbe(page: page, progressURL: progressURL)

            let expectations: [GooseWebRouteExpectation] = [
                .init(
                    route: "/configure-providers",
                    requiredText: ["Provider Configuration Settings"],
                    anyText: ["OpenAI", "Anthropic", "Google", "Ollama"],
                    requiredACPMethods: ["_goose/unstable/providers/list"]
                ),
                .init(
                    route: "/settings?section=models",
                    eventView: "settings",
                    eventSection: "models",
                    requiredText: ["Settings"],
                    anyText: ["Models", "Provider", "Model"]
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
                    requiredText: ["Chat history"],
                    anyText: ["No chat sessions found", "Search history", "Loading more sessions"],
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
            ] + routeLines).joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_webview_route_smoke=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live WebView route smoke proof log was not written.")
            }
        }
    }
}

private struct GooseWebRouteExpectation: Sendable {
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
        forbiddenText: [String] = [
            "Epistemos native host has not implemented",
            "Error Loading Recipes",
            "Error Loading Sessions",
            "Error Loading Skills",
            "Error loading apps",
            "Application error",
            "No routes matched location",
        ]
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
    let textLength: Int
    let acpUrlPresent: Bool
    let providerLoadError: String?
    let consoleMessages: [String]
    let socketEvents: [String]
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
            && expectation.forbiddenText.allSatisfy { !contains($0) }
            && expectation.requiredACPMethods.allSatisfy { trace.outgoingMethodCounts[$0, default: 0] > 0 }
    }

    func summary(for expectation: GooseWebRouteExpectation) -> String {
        let forbiddenHits = hits(for: expectation.forbiddenText)
        return [
            "hash=\(hash)",
            "ready=\(readyState)",
            "root=\(rootChildren)",
            "text_chars=\(textLength)",
            "required=\(hits(for: expectation.requiredText).joined(separator: ","))",
            "any=\(hits(for: expectation.anyText).joined(separator: ","))",
            "forbidden=\(forbiddenHits.joined(separator: ","))",
            "acp=\(hitsACPMethods(expectation.requiredACPMethods).joined(separator: ","))",
            "acp_url=\(acpUrlPresent ? "present" : "missing")",
            "provider_error=\(providerLoadError ?? "")",
            "socket=\(socketEvents.suffix(6).joined(separator: ","))",
            "console=\(consoleMessages.suffix(4).joined(separator: " | "))",
            "sample=\(bodyText.prefix(180))",
        ].joined(separator: " ")
    }

    private func contains(_ needle: String) -> Bool {
        bodyText.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
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
    appendLiveProgress("route navigate \(expectation.route)", to: progressURL)

    var lastProbe: GooseWebRouteProbe?
    var stableMatches = 0
    for attempt in 0..<220 {
        if attempt % 5 == 0 {
            try await driveGooseWebRouteNavigation(expectation, page: page)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
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
        const trace = window.epistemos?.goose?.acpTrace?.() ?? { events: [], outgoingMethodCounts: {} };
        const consoleEvents = window.epistemos?.goose?.consoleEvents?.() ?? [];
        return JSON.stringify({
          readyState: document.readyState,
          href: window.location.href,
          hash: window.location.hash,
          rootChildren: document.getElementById('root')?.children?.length ?? -1,
          bodyText,
          textLength: bodyText.length,
          acpUrlPresent: Boolean(window.epistemos?.goose?.acpUrl),
          providerLoadError: window.__epistemosGooseProviderLoadError ?? null,
          consoleMessages: consoleEvents.map((event) => `${event.level}:${event.message}`).slice(-8),
          socketEvents: (trace.events || [])
            .filter((event) => event.direction === 'socket')
            .map((event) => event.detail === null || event.detail === undefined
              ? event.method
              : `${event.method}:${event.detail}`
            )
            .slice(-8),
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
