import Testing

@Suite("GenUI dispatcher invariant source guards")
struct GenUIDispatcherInvariantSourceGuardTests {
    @Test("Dispatcher avoids AnyView hot-path erasure per Simulation I-15")
    func dispatcherAvoidsAnyViewHotPathErasure() throws {
        let dispatcher = try loadMirroredSourceTextFile(
            "Epistemos/Engine/GenUIDispatcher.swift"
        )

        #expect(!dispatcher.contains("AnyView"),
                "GenUIDispatcher must not type-erase renderer factories through AnyView on the hot path")
        #expect(!dispatcher.contains("(GenUIPayload) -> AnyView"),
                "GenUIDispatcher registry must not store AnyView factories")
        #expect(dispatcher.contains("@ViewBuilder"),
                "Dispatcher rendering must remain typed through ViewBuilder")
        #expect(dispatcher.contains("switch payload.schema"),
                "Dispatcher must route by the typed GenUISchema enum, not string-key or erased view dispatch")
    }

    @Test("Hermes Expert Mode structured renderers stay on GenUIPayload")
    func hermesExpertModeRenderersStayOnGenUIPayload() throws {
        let runner = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Hermes/HermesExpertModeRunner.swift"
        )
        let view = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/Hermes/HermesExpertModeView.swift"
        )

        #expect(!runner.contains(".artifact(Artifact("),
                "Hermes Expert Mode structured renderers must not regress to legacy Artifact transcript output")
        #expect(runner.contains("state.append(.payload(.markdownCard("),
                "Hermes help output should remain a typed markdown GenUIPayload")
        #expect(runner.contains("state.append(.payload(.keyValueTable("),
                "Hermes status/config/tokens/cost output should remain typed key-value GenUIPayloads")
        #expect(runner.contains("state.append(.payload(.capabilityList("),
                "Hermes model list output should remain a typed capability-list GenUIPayload")
        #expect(runner.contains("state.append(.payload(.searchResults("),
                "Hermes search output should remain a typed search-results GenUIPayload")
        #expect(view.contains("GenUIDispatcher.shared.render(payload)"),
                "Hermes payload entries must render through the canonical GenUIDispatcher")
    }

    @Test("Approval Modal request payload renders through GenUIDispatcher")
    func approvalModalRequestPayloadRendersThroughGenUIDispatcher() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Approval/ApprovalModalView.swift"
        )

        #expect(source.contains("private var approvalPayloads: [GenUIPayload]"),
                "Approval Modal must expose its request details as typed GenUIPayloads")
        #expect(source.contains("GenUIPayload.keyValueTable("),
                "Approval request metadata should use the canonical key-value GenUI schema")
        #expect(source.contains("title: \"Approval Request\""),
                "Approval request metadata should use the canonical key-value GenUI schema")
        #expect(source.contains("schema: .json"),
                "Approval arguments should stay typed as a JSON GenUIPayload instead of ad hoc Text")
        #expect(source.contains("GenUIDispatcher.shared.render(payload)"),
                "Approval Modal payloads must render through the canonical GenUIDispatcher")
        #expect(!source.contains("GENUI-DEFER"),
                "Approval Modal should not keep a GENUI-DEFER marker after the G.3 priority 2 migration")
    }

    @Test("Landing Daily Brief and Welcome Back render payloads through GenUIDispatcher")
    func landingBriefSurfacesRenderThroughGenUIDispatcher() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Landing/LandingView.swift"
        )

        #expect(source.contains("private func welcomeBackPayload(info: WelcomeBackInfo) -> GenUIPayload"),
                "Welcome Back must expose its session summary as a typed GenUIPayload")
        #expect(source.contains("private var dailyBriefPayload: GenUIPayload"),
                "Daily Brief must expose its brief body as a typed GenUIPayload")
        #expect(source.contains("GenUIPayload.markdownCard(")
                    && source.contains("title: \"Welcome Back\""),
                "Welcome Back should use the canonical markdown GenUI schema")
        #expect(source.contains("GenUIPayload.markdownCard(")
                    && source.contains("title: \"Daily Brief\""),
                "Daily Brief should use the canonical markdown GenUI schema")
        #expect(source.components(separatedBy: "GenUIDispatcher.shared.render(").count >= 3,
                "Landing brief surfaces must render through the canonical GenUIDispatcher")
        #expect(!source.contains("GENUI-DEFER"),
                "Landing brief surfaces should not keep GENUI-DEFER markers after the G.3 priority 4 migration")
    }
}
