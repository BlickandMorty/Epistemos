# AgentClone Vendor Record

AgentClone is the full visible Swift Chat foundation for the Epistemos Chat lane.
It is intentionally kept as a complete local package while the UI is transformed
into Epistemos old-chat ontology.

## Source

- Local package: `LocalPackages/AgentClone`
- Upstream study clone: `.research-clones/swift-act/agent-macos26`
- Upstream URL: `https://github.com/macos26/Agent.git`
- Study clone commit: `fc07409a900ba4ed4ecbf851e93aa8f18d1dcd94`
- Upstream license file found: `.research-clones/swift-act/agent-macos26/LICENSE`

## Risk

`LocalPackages/AgentClone/Package.swift` still pins closed or portability-risk
`github.com/macOS26/Agent*` packages. They currently build from local cache, but
a clean machine or release build can fail if those packages are private or
unavailable. Do not call the Chat lane complete until this dependency risk is
resolved, replaced, or explicitly accepted by the owner.

## Integration Rule

AgentClone provides the live shell and current capability stack. It must not
monopolize the Swift Chat lane. Swarm, SwiftedMind, MCP Swift SDK, AgentSDK,
AgentKit, Foundation Models sample, swiftagent-1amageek, and swiftaia-agent
each have separate contracts in `LocalPackages/EpistemosChatDonorContracts` and
`docs/donor-contracts/swift-chat`.
