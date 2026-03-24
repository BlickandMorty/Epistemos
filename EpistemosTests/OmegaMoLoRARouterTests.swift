import Testing
@testable import Epistemos

@Suite("MoLoRA Router")
@MainActor
struct MoLoRARouterTests {

    private func makeRouter() -> MoLoRARouter {
        let router = MoLoRARouter()
        router.registerAdapter(AdapterInfo(
            id: "knowledge-1",
            name: "Domain Knowledge",
            type: .knowledge,
            path: URL(fileURLWithPath: "/tmp/knowledge.safetensors")
        ))
        router.registerAdapter(AdapterInfo(
            id: "style-1",
            name: "Writing Style",
            type: .style,
            path: URL(fileURLWithPath: "/tmp/style.safetensors")
        ))
        router.registerAdapter(AdapterInfo(
            id: "tool-1",
            name: "Tool Calling",
            type: .toolUse,
            path: URL(fileURLWithPath: "/tmp/tool.safetensors")
        ))
        return router
    }

    @Test("Starts empty")
    func initialState() {
        let router = MoLoRARouter()
        #expect(router.activeAdapters.isEmpty)
        #expect(router.routingWeights.isEmpty)
    }

    @Test("Registers adapters with equal weights")
    func registerAdapters() {
        let router = makeRouter()
        #expect(router.activeAdapters.count == 3)
        // Equal weights for 3 adapters ≈ 0.333
        for (_, weight) in router.routingWeights {
            #expect(abs(weight - 1.0/3.0) < 0.001)
        }
    }

    @Test("Routes knowledge intent to knowledge adapter")
    func routeKnowledge() {
        let router = makeRouter()
        let result = router.route(taskIntent: .knowledge)
        #expect(result != nil)
        #expect(result?.adapterId == "knowledge-1")
    }

    @Test("Routes style intent to style adapter")
    func routeStyle() {
        let router = makeRouter()
        let result = router.route(taskIntent: .style)
        #expect(result != nil)
        #expect(result?.adapterId == "style-1")
    }

    @Test("Routes toolUse intent to tool adapter")
    func routeToolUse() {
        let router = makeRouter()
        let result = router.route(taskIntent: .toolUse)
        #expect(result != nil)
        #expect(result?.adapterId == "tool-1")
    }

    @Test("General intent routes to any adapter")
    func routeGeneral() {
        let router = makeRouter()
        let result = router.route(taskIntent: .general)
        #expect(result != nil)
    }

    @Test("Returns nil when no adapters registered")
    func routeEmpty() {
        let router = MoLoRARouter()
        let result = router.route(taskIntent: .knowledge)
        #expect(result == nil)
    }

    @Test("Unregister removes adapter")
    func unregister() {
        let router = makeRouter()
        #expect(router.activeAdapters.count == 3)
        router.unregisterAdapter(id: "style-1")
        #expect(router.activeAdapters.count == 2)
        #expect(!router.activeAdapters.contains { $0.id == "style-1" })
    }

    @Test("Prevents duplicate registration")
    func noDuplicate() {
        let router = MoLoRARouter()
        let adapter = AdapterInfo(id: "a", name: "A", type: .general, path: URL(fileURLWithPath: "/tmp/a"))
        router.registerAdapter(adapter)
        router.registerAdapter(adapter) // duplicate
        #expect(router.activeAdapters.count == 1)
    }
}
