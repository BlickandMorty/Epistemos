import Foundation
import Testing
@testable import Epistemos

// Verifies WorkEngineResourcesDecoder against the runtime-verified loadResources shape (og-loadresources-probe.mjs):
// providersData{providers:[{id,name,models:Record<id,Model>}], default:Record<provider,model>}, agentsData[], commandsData[].
@Suite("Work engine resources — loadResources bundle decode (model/agent/command picker)")
struct WorkEngineResourcesTests {
    /// The sidecar envelope `{resources:{…}}` with the real bundle shape.
    private let sample = Data(#"""
    {"resources":{
      "providersData":{
        "providers":[{"id":"anthropic","name":"Anthropic","models":{"claude-x":{"id":"claude-x","name":"Claude X"},"claude-y":{"id":"claude-y","name":"Claude Y"}}}],
        "default":{"anthropic":"claude-x"}
      },
      "agentsData":[
        {"name":"build","mode":"primary","description":"default agent","native":true},
        {"name":"secret","hidden":true}
      ],
      "commandsData":[{"name":"init","description":"guided setup","source":"command","template":"do x"}]
    }}
    """#.utf8)

    @Test("decodes providers + models (Record→array) from the {resources} envelope")
    func decodesProviders() {
        let r = WorkEngineResourcesDecoder.decode(sample)
        #expect(r.providers.count == 1)
        #expect(r.providers.first?.id == "anthropic")
        #expect(r.providers.first?.models.count == 2)
        #expect(r.providers.first?.models.contains { $0.id == "claude-x" && $0.name == "Claude X" } == true)
        #expect(r.defaultModelByProvider["anthropic"] == "claude-x")
        #expect(r.flatModels.count == 2) // flattened provider·model for a single compact picker
    }

    @Test("agents exclude hidden; carry name/mode/description")
    func decodesAgents() {
        let r = WorkEngineResourcesDecoder.decode(sample)
        #expect(r.agents.count == 1)                       // "secret" (hidden) excluded
        #expect(r.agents.first?.name == "build")
        #expect(r.agents.first?.mode == "primary")
        #expect(r.agents.first?.description == "default agent")
    }

    @Test("commands decode name + description (slash-command popover)")
    func decodesCommands() {
        let r = WorkEngineResourcesDecoder.decode(sample)
        #expect(r.commands.map(\.name) == ["init"])
        #expect(r.commands.first?.description == "guided setup")
    }

    @Test("lenient: nil / malformed / bare-bundle inputs never crash")
    func lenient() {
        #expect(WorkEngineResourcesDecoder.decode(nil) == .empty)
        #expect(WorkEngineResourcesDecoder.decode(Data("nope".utf8)) == .empty)
        // bare bundle (no envelope) also works
        let bare = Data(#"{"agentsData":[{"name":"plan"}],"commandsData":[],"providersData":{"providers":[]}}"#.utf8)
        #expect(WorkEngineResourcesDecoder.decode(bare).agents.map(\.name) == ["plan"])
    }

    // The model picker must carry the PROVIDER through its selection id: opencode's prompt API expects a
    // SelectedModel {providerID, modelID} OBJECT; a bare model id is silently ignored (falls back to the default
    // model). flatModelOptions keys each option by the composite `providerID/modelID`; send() rebuilds the object.
    @Test("flatModelOptions key each model by the composite providerID/modelID id")
    func flatModelOptionsCarryProvider() {
        let r = WorkEngineResourcesDecoder.decode(sample)
        let ids = Set(r.flatModelOptions.map(\.id))
        #expect(ids == ["anthropic/claude-x", "anthropic/claude-y"])
        // one provider stays compact: model name only
        #expect(r.flatModelOptions.contains { $0.id == "anthropic/claude-x" && $0.name == "Claude X" })
    }

    @Test("flatModelOptions disambiguate labels only when multiple providers are present")
    func flatModelOptionsDisambiguateMultipleProviders() {
        let resources = WorkEngineResources(
            providers: [
                WorkEngineProvider(id: "p1", name: "Provider One", models: [WorkEngineModel(id: "m", name: "Shared")]),
                WorkEngineProvider(id: "p2", name: "Provider Two", models: [WorkEngineModel(id: "m", name: "Shared")]),
            ],
            agents: [],
            commands: [],
            defaultModelByProvider: [:])

        #expect(resources.flatModelOptions.map(\.name) == ["Provider One · Shared", "Provider Two · Shared"])
    }

    @Test("decoder ignores default model ids that were not advertised by that provider")
    func defaultsMustPointAtDecodedModels() {
        let data = Data(#"""
        {"providersData":{
          "providers":[{"id":"p1","name":"Provider","models":{"m1":{"name":"Model One"}}}],
          "default":{"p1":"missing","ghost":"m1"}
        }}
        """#.utf8)

        let resources = WorkEngineResourcesDecoder.decode(data)

        #expect(resources.providers.first?.models.map(\.id) == ["m1"])
        #expect(resources.defaultModelByProvider.isEmpty)
    }

    @Test("decoder trims and rejects blank provider/model/agent/command identities")
    func rejectsBlankResourceIdentities() {
        let data = Data(#"""
        {"providersData":{
          "providers":[
            {"id":"  p1  ","name":"  Provider  ","models":{
              "m1":{"name":"  Model One  "},
              "blankName":{"name":"   "},
              "blankID":{"id":"   ","name":"Model Two"},
              "":{"name":"No ID"}
            }},
            {"id":"   ","name":"Ghost","models":{"m":{"name":"M"}}},
            {"id":"p2","name":"   ","models":{"m":{"name":"M"}}}
          ],
          "default":{"p1":"m1","p2":"m"}
        },
        "agentsData":[{"name":"  build  "},{"name":"   "}],
        "commandsData":[{"name":"  init  "},{"name":"   "}]}
        """#.utf8)

        let resources = WorkEngineResourcesDecoder.decode(data)

        #expect(resources.providers.map(\.id) == ["p1"])
        #expect(resources.providers.first?.name == "Provider")
        #expect(resources.providers.first?.models.map(\.id).sorted() == ["blankID", "blankName", "m1"])
        #expect(resources.providers.first?.models.first { $0.id == "m1" }?.name == "Model One")
        #expect(resources.providers.first?.models.first { $0.id == "blankName" }?.name == "blankName")
        #expect(resources.defaultModelByProvider == ["p1": "m1"])
        #expect(resources.agents.map(\.name) == ["build"])
        #expect(resources.commands.map(\.name) == ["init"])
    }

    @Test("selectionID / splitSelectionID round-trip; split on FIRST slash; reject malformed")
    func selectionIDRoundTrip() {
        let id = WorkEngineResources.selectionID(providerID: "openai", modelID: "gpt-5")
        #expect(id == "openai/gpt-5")
        let parts = WorkEngineResources.splitSelectionID(id)
        #expect(parts?.providerID == "openai")
        #expect(parts?.modelID == "gpt-5")
        // model ids that themselves contain a slash survive (split on the FIRST slash only)
        let slashy = WorkEngineResources.splitSelectionID("anthropic/claude/3.5")
        #expect(slashy?.providerID == "anthropic")
        #expect(slashy?.modelID == "claude/3.5")
        // malformed → nil (no slash, empty halves)
        #expect(WorkEngineResources.splitSelectionID("noslash") == nil)
        #expect(WorkEngineResources.splitSelectionID("/onlymodel") == nil)
        #expect(WorkEngineResources.splitSelectionID("onlyprovider/") == nil)
    }
}
