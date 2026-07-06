import Foundation
import Testing
import WebKit
@testable import Epistemos

// The Goose WebView surface was intentionally excised in 0b10f728b.
// Keep historical renderer-prompt coverage opt-in until that surface is restored.
#if EPISTEMOS_LEGACY_GOOSE_WEBVIEW
@Suite("Goose Web prompt live integration", .serialized)
struct GooseWebPromptLiveIntegrationTests {
    @Test(
        "live Goose WebView submits a prompt through the renderer and reaches end_turn"
    )
    @MainActor
    func liveGooseWebViewSubmitsPromptThroughRendererToEndTurn() async throws {
        let proofURL = URL(fileURLWithPath: "/tmp/epistemos-goose-phase0-webview-prompt.log")
        try? FileManager.default.removeItem(at: proofURL)

        try await withFreshGooseWebUIArtifact(proofName: "webview-prompt") { index in
            try await withLiveGooseRuntime(proofName: "webview-prompt") { binary, connection, progressURL in
            let bootstrap = GooseWebBootstrap(
                baseURL: connection.baseURL,
                secretKey: connection.secretKey,
                config: GooseWebConfig(version: "phase0-webview-prompt")
            )
            let page = GooseWebSurfaceView.makeBootProbePage(
                bootstrap: bootstrap,
                gooseUIRoot: index.deletingLastPathComponent()
            )
            let uiServer = try await startGooseWebUILoopbackServer(root: index.deletingLastPathComponent())
            defer { uiServer.server.stop() }
            appendLiveProgress("before webview prompt boot", to: progressURL)
            _ = page.load(URLRequest(url: GooseWebSurfaceView.loopbackURL(baseURL: uiServer.baseURL, route: "/?")))
            _ = try await waitForGooseWebBootProbe(page: page, progressURL: progressURL)

            let expectedText = "phase0 live webview goose prompt ready"
            let prompt = "Reply with exactly this phrase and no markdown: \(expectedText)"
            try await submitGooseWebPrompt(prompt, page: page, progressURL: progressURL)
            let probe = try await waitForGooseWebPromptEndTurn(
                page: page,
                expectedText: expectedText,
                progressURL: progressURL
            )

            let proof = [
                "phase0_live_webview_prompt=pass",
                "goose_binary=\(binary.lastPathComponent)",
                "goose_base_url=\(connection.baseURL.absoluteString)",
                "goose_acp_url=\(connection.acpWebSocketURL.map(redactedACPURL) ?? "<missing>")",
                "goose_web_ui_origin=\(uiServer.baseURL.absoluteString)",
                "prompt_request_count=\(probe.trace.promptRequestCount)",
                "prompt_response_count=\(probe.trace.promptResponseCount)",
                "last_prompt_stop_reason=\(probe.trace.lastPromptStopReason ?? "<missing>")",
                "last_prompt_error=\(probe.trace.lastPromptError ?? "<none>")",
                "input_present=\(probe.inputPresent)",
                "body_text_chars=\(probe.textLength)",
                "expected_text_rendered=\(probe.containsExpectedText(expectedText))",
            ].joined(separator: "\n") + "\n"
            try proof.write(to: proofURL, atomically: true, encoding: .utf8)

            guard probe.trace.lastPromptStopReason == "end_turn" else {
                throw GooseLiveIntegrationError.runtimeFailed("WebView prompt did not reach end_turn through the renderer ACP path.")
            }
            guard probe.containsExpectedText(expectedText) else {
                throw GooseLiveIntegrationError.runtimeFailed("WebView prompt reached end_turn but did not render the expected assistant text.")
            }
            guard try String(contentsOf: proofURL, encoding: .utf8).contains("phase0_live_webview_prompt=pass") else {
                throw GooseLiveIntegrationError.runtimeFailed("Live WebView prompt proof log was not written.")
            }
            try GoosePhase0CapabilityMatrix.record(
                [.conversationLoop],
                proofURL: proofURL,
                via: "embedded web UI -> goose serve ACP",
                details: ["stop_reason": probe.trace.lastPromptStopReason ?? "<missing>"]
            )
            }
        }
    }
}

@MainActor
private func submitGooseWebPrompt(
    _ prompt: String,
    page: WebPage,
    progressURL: URL
) async throws {
    try await waitForGooseWebPromptInput(page: page, progressURL: progressURL)
    let result = try await page.callJavaScript(
        """
        const prompt = \(javaScriptStringLiteral(prompt));
        const textarea = document.querySelector('textarea[data-testid="chat-input"]');
        if (!textarea) {
          return JSON.stringify({
            ok: false,
            error: 'chat input missing',
            bodyText: (document.body?.innerText || '').replace(/\\s+/g, ' ').trim().slice(0, 240)
          });
        }
        textarea.focus();
        const valueSetter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value')?.set;
        if (valueSetter) {
          valueSetter.call(textarea, prompt);
        } else {
          textarea.value = prompt;
        }
        const inputEvent = typeof InputEvent === 'function'
          ? new InputEvent('input', { bubbles: true, inputType: 'insertText', data: prompt })
          : new Event('input', { bubbles: true });
        textarea.dispatchEvent(inputEvent);
        textarea.dispatchEvent(new Event('change', { bubbles: true }));
        return await new Promise((resolve) => {
          setTimeout(() => {
            const button = document.querySelector('button[aria-label="Send"]');
            const form = textarea.closest('form');
            if (button && !button.disabled) {
              button.click();
            } else if (form) {
              const event = typeof SubmitEvent === 'function'
                ? new SubmitEvent('submit', { bubbles: true, cancelable: true })
                : new Event('submit', { bubbles: true, cancelable: true });
              form.dispatchEvent(event);
            }
            resolve(JSON.stringify({
              ok: true,
              valueLength: textarea.value.length,
              buttonPresent: !!button,
              buttonDisabled: button ? button.disabled : null,
              formPresent: !!form
            }));
          }, 80);
        });
        """
    )
    guard let json = result as? String,
          let data = json.data(using: .utf8) else {
        throw GooseLiveIntegrationError.runtimeFailed("WebView prompt submit probe did not return JSON.")
    }
    let probe = try JSONDecoder().decode(GooseWebPromptSubmitProbe.self, from: data)
    appendLiveProgress(
        "webview prompt submit ok=\(probe.ok) input_chars=\(probe.valueLength ?? -1) button=\(probe.buttonPresent ?? false) disabled=\(probe.buttonDisabled.map { String($0) } ?? "<nil>") form=\(probe.formPresent ?? false)",
        to: progressURL
    )
    guard probe.ok else {
        throw GooseLiveIntegrationError.runtimeFailed(probe.error ?? "WebView prompt submit failed.")
    }
}

@MainActor
private func waitForGooseWebPromptInput(page: WebPage, progressURL: URL) async throws {
    var lastProbe: GooseWebPromptProbe?
    for attempt in 0..<120 {
        let probe = try await readGooseWebPromptProbe(page)
        lastProbe = probe
        if attempt % 10 == 0 || probe.inputPresent {
            appendLiveProgress(
                "webview prompt input attempt=\(attempt) present=\(probe.inputPresent) href=\(probe.href) text_chars=\(probe.textLength) sample=\(probe.bodyText.prefix(180))",
                to: progressURL
            )
        }
        if probe.inputPresent {
            return
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
    let summary = lastProbe.map {
        "href=\($0.href) text_chars=\($0.textLength) sample=\($0.bodyText.prefix(260))"
    } ?? "no prompt input probe"
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for WebView chat input: \(summary).")
}

@MainActor
private func waitForGooseWebPromptEndTurn(
    page: WebPage,
    expectedText: String,
    progressURL: URL
) async throws -> GooseWebPromptProbe {
    var lastProbe: GooseWebPromptProbe?
    for attempt in 0..<1_200 {
        try await Task.sleep(nanoseconds: 100_000_000)
        let probe = try await readGooseWebPromptProbe(page)
        lastProbe = probe
        if attempt % 10 == 0 || probe.reachedEndTurn {
            appendLiveProgress(
                "webview prompt attempt=\(attempt) stop=\(probe.trace.lastPromptStopReason ?? "<nil>") req=\(probe.trace.promptRequestCount) res=\(probe.trace.promptResponseCount) expected=\(probe.containsExpectedText(expectedText)) text_chars=\(probe.textLength) error=\(probe.trace.lastPromptError ?? "<nil>")",
                to: progressURL
            )
        }
        if probe.reachedEndTurn && probe.containsExpectedText(expectedText) {
            return probe
        }
        if let error = probe.trace.lastPromptError {
            throw GooseLiveIntegrationError.runtimeFailed("WebView prompt returned ACP error: \(error).")
        }
    }
    let summary = lastProbe.map {
        "stop=\($0.trace.lastPromptStopReason ?? "<nil>") req=\($0.trace.promptRequestCount) res=\($0.trace.promptResponseCount) text_chars=\($0.textLength) sample=\($0.bodyText.prefix(180))"
    } ?? "no prompt probe"
    throw GooseLiveIntegrationError.runtimeFailed("Timed out waiting for WebView prompt end_turn: \(summary).")
}

@MainActor
private func readGooseWebPromptProbe(_ page: WebPage) async throws -> GooseWebPromptProbe {
    let result = try await page.callJavaScript(
        """
        const bodyText = (document.body?.innerText || '').replace(/\\s+/g, ' ').trim();
        return JSON.stringify({
          readyState: document.readyState,
          href: window.location.href,
          inputPresent: !!document.querySelector('textarea[data-testid="chat-input"]'),
          bodyText,
          textLength: bodyText.length,
          trace: window.epistemos?.goose?.acpTrace?.() ?? {
            promptRequestCount: 0,
            promptResponseCount: 0,
            lastPromptStopReason: null,
            lastPromptError: 'missing ACP trace'
          }
        });
        """
    )
    guard let json = result as? String,
          let data = json.data(using: .utf8) else {
        throw GooseLiveIntegrationError.runtimeFailed("WebView prompt probe did not return JSON.")
    }
    return try JSONDecoder().decode(GooseWebPromptProbe.self, from: data)
}

private struct GooseWebPromptSubmitProbe: Decodable, Sendable {
    let ok: Bool
    let error: String?
    let valueLength: Int?
    let buttonPresent: Bool?
    let buttonDisabled: Bool?
    let formPresent: Bool?
}

private struct GooseWebPromptProbe: Decodable, Sendable {
    let readyState: String
    let href: String
    let inputPresent: Bool
    let bodyText: String
    let textLength: Int
    let trace: GooseWebPromptTrace

    var reachedEndTurn: Bool {
        trace.lastPromptStopReason == "end_turn"
    }

    func containsExpectedText(_ expectedText: String) -> Bool {
        bodyText.range(of: expectedText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

private struct GooseWebPromptTrace: Decodable, Sendable {
    let promptRequestCount: Int
    let promptResponseCount: Int
    let lastPromptStopReason: String?
    let lastPromptError: String?
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
