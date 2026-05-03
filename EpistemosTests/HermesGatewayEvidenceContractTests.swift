import Testing
@testable import Epistemos

/// Hermes Gateway Evidence Contract — proves the **architectural composition**
/// invariants the user liked: local substrate stays direct/in-process, every
/// cloud provider AND every external tool routes through the unified Hermes
/// gateway with structured evidence provenance, and the Surface enum cannot
/// silently grow a new case that bypasses policy classification.
///
/// Doctrine §7 lane: Pro track — Hermes subprocess / cloud gateway integration
/// preflight. Sister suite: `HermesGatewayPolicyTests` (per-surface decisions),
/// `CoreMASBoundarySourceGuardTests` (source-text guards). This suite is the
/// **set-algebra layer** — partition coverage, mutual exclusion, and tier
/// alignment across every surface.
@Suite("Hermes Gateway Evidence Contract")
nonisolated struct HermesGatewayEvidenceContractTests {

    // MARK: - Set-algebra partition coverage

    @Test("every Surface case falls into exactly one policy bucket")
    func everySurfaceFallsIntoExactlyOnePolicyBucket() {
        // Three buckets:
        //   1. Local substrate (Core, direct).
        //   2. Local prompt formatting (Core, in-process).
        //   3. External gateway surfaces (Pro/Research, hermesGateway).
        //
        // The contract is that every case in HermesGatewayPolicy.Surface.allCases
        // belongs to exactly one. If a future patch adds a case but forgets to
        // wire it into externalGatewaySurfaces, this test catches it before
        // the case can leak past the gateway.
        let local: Set<HermesGatewayPolicy.Surface> = [
            .deterministicLocalSubstrate,
            .localPromptFormatting,
        ]
        let external = Set(HermesGatewayPolicy.Surface.externalGatewaySurfaces)
        let allCases = Set(HermesGatewayPolicy.Surface.allCases)

        #expect(local.intersection(external).isEmpty,
                "Local and external surface sets must be disjoint")
        #expect(local.union(external) == allCases,
                "Every Surface case must be classified as either local or external — orphan cases bypass policy")
        #expect(local.count + external.count == allCases.count,
                "Sum of bucket sizes must equal total surface count (no double-counting)")
    }

    @Test("cloud provider surfaces are a strict subset of external gateway surfaces")
    func cloudProvidersAreStrictSubsetOfExternalGateway() {
        let cloud = Set(HermesGatewayPolicy.Surface.cloudProviderSurfaces)
        let external = Set(HermesGatewayPolicy.Surface.externalGatewaySurfaces)

        #expect(cloud.isSubset(of: external),
                "Cloud provider surfaces must be a subset of external gateway surfaces")
        #expect(cloud != external,
                "External gateway surfaces must include non-cloud entries (CLI/MCP/browser/Docker/subprocess)")
        #expect(external.subtracting(cloud).count >= 5,
                "External gateway must include at least 5 non-cloud surfaces (CLI, MCP, Hermes subprocess, browser, Docker, explicit) — found \(external.subtracting(cloud).count)")
    }

    @Test("non-cloud external surfaces include CLI MCP Hermes browser Docker explicit")
    func nonCloudExternalSurfacesAreEnumerated() {
        let cloud = Set(HermesGatewayPolicy.Surface.cloudProviderSurfaces)
        let external = Set(HermesGatewayPolicy.Surface.externalGatewaySurfaces)
        let nonCloudExternal = external.subtracting(cloud)

        // The doctrine §7 Pro track lists these exact six non-cloud surfaces
        // as the gateway-bound external set. If one disappears, the gateway
        // pattern has been weakened; if a seventh appears, this test surfaces
        // the addition for review.
        let expected: Set<HermesGatewayPolicy.Surface> = [
            .cliDelegation,
            .mcpWebTool,
            .hermesSubprocess,
            .browserComputerUse,
            .dockerDevcontainer,
            .explicitExternalSideEffect,
        ]
        #expect(nonCloudExternal == expected,
                "Non-cloud external surfaces must equal the doctrine-declared set: expected \(expected), got \(nonCloudExternal)")
    }

    // MARK: - Tier alignment invariants

    @Test("every Pro/Research surface declares network or subprocess need")
    func everyProResearchSurfaceDeclaresNetworkOrSubprocess() {
        // The whole point of Pro/Research tier is that something external is
        // happening — network call, subprocess spawn, or both. A Pro/Research
        // surface that declares neither would be indistinguishable from Core
        // at runtime, which would mean the tier classification is performative.
        for surface in HermesGatewayPolicy.Surface.allCases {
            let decision = HermesGatewayPolicy.decision(for: surface)
            guard decision.tier == .proResearch else { continue }

            #expect(decision.requiresNetwork || decision.requiresSubprocess,
                    "Pro/Research surface \(surface) must require network or subprocess — otherwise tier classification is meaningless")
        }
    }

    @Test("every Core surface refuses both network and subprocess")
    func everyCoreSurfaceRefusesBothNetworkAndSubprocess() {
        // Core builds run inside the App Store sandbox with no subprocess
        // capability. A Core surface that flips on either flag is leakage.
        for surface in HermesGatewayPolicy.Surface.allCases {
            let decision = HermesGatewayPolicy.decision(for: surface)
            guard decision.tier == .core else { continue }

            #expect(!decision.requiresNetwork,
                    "Core surface \(surface) must not require network — App Store sandbox has no general network capability for tools")
            #expect(!decision.requiresSubprocess,
                    "Core surface \(surface) must not require subprocess — App Store sandbox forbids subprocess")
            #expect(decision.preservesDirectSubstratePath,
                    "Core surface \(surface) must preserve the direct substrate path")
        }
    }

    // MARK: - Allowance identity invariants

    @Test("isAllowedInCoreAppStoreBuild equals exactly the two local Core surfaces")
    func coreAppStoreAllowanceEqualsExactlyLocalCoreSet() {
        // The Core App Store allowlist is an *identity*: it must match exactly
        // the local-substrate + local-prompt pair. If a future Pro/Research
        // surface accidentally satisfies all four conditions of
        // isAllowedInCoreAppStoreBuild (e.g., someone flips
        // preservesDirectSubstratePath to true on a cloud surface), this
        // assertion catches it.
        let allowed = HermesGatewayPolicy.Surface.allCases.filter {
            HermesGatewayPolicy.isAllowedInCoreAppStoreBuild($0)
        }
        let expected: [HermesGatewayPolicy.Surface] = [
            .deterministicLocalSubstrate,
            .localPromptFormatting,
        ]
        #expect(Set(allowed) == Set(expected),
                "Core App Store allowlist must equal exactly {deterministicLocalSubstrate, localPromptFormatting} — got \(allowed)")
    }

    @Test("Hermes gateway route is used by exactly the external gateway surfaces")
    func hermesGatewayRouteIsUsedByExactlyExternalSurfaces() {
        let usingGateway = HermesGatewayPolicy.Surface.allCases.filter {
            HermesGatewayPolicy.usesHermesGateway($0)
        }
        let external = Set(HermesGatewayPolicy.Surface.externalGatewaySurfaces)

        #expect(Set(usingGateway) == external,
                "Hermes gateway route must be used by exactly the external surfaces — got \(usingGateway), expected \(external)")
    }

    @Test("structured evidence is required by exactly the external gateway surfaces")
    func structuredEvidenceRequiredByExactlyExternalSurfaces() {
        let requiringEvidence = HermesGatewayPolicy.Surface.allCases.filter {
            HermesGatewayPolicy.requiresStructuredEvidenceReturn($0)
        }
        let external = Set(HermesGatewayPolicy.Surface.externalGatewaySurfaces)

        #expect(Set(requiringEvidence) == external,
                "Structured evidence requirement must equal the external surface set — got \(requiringEvidence), expected \(external)")
    }

    // MARK: - Decision quality contract

    @Test("every decision carries a non-empty reason explaining the routing")
    func everyDecisionCarriesNonEmptyReason() {
        // Reason text feeds logs, settings diagnostics, and Codex deliberation
        // briefs. A blank reason is a UX bug AND a deliberation-readability
        // bug — Codex can't audit a routing decision it can't read.
        for surface in HermesGatewayPolicy.Surface.allCases {
            let decision = HermesGatewayPolicy.decision(for: surface)
            let trimmed = decision.reason.trimmingCharacters(in: .whitespacesAndNewlines)

            #expect(!trimmed.isEmpty,
                    "Surface \(surface) decision must carry a non-empty reason")
            #expect(trimmed.count >= 20,
                    "Surface \(surface) decision reason must be substantive (≥ 20 chars) — got: \"\(trimmed)\"")
        }
    }

    @Test("evidence return enum maps deterministically per route")
    func evidenceReturnMapsDeterministicallyPerRoute() {
        // The route → evidence-return mapping must be a function (no two
        // surfaces with the same route disagree on evidence return). Otherwise
        // downstream consumers that group by route get inconsistent evidence
        // expectations.
        var routeToEvidence: [HermesGatewayPolicy.Route: HermesGatewayPolicy.EvidenceReturn] = [:]
        for surface in HermesGatewayPolicy.Surface.allCases {
            let decision = HermesGatewayPolicy.decision(for: surface)
            if let prior = routeToEvidence[decision.route] {
                #expect(prior == decision.evidenceReturn,
                        "Route \(decision.route) must map to a single evidence-return kind — surface \(surface) disagrees: \(decision.evidenceReturn) vs prior \(prior)")
            } else {
                routeToEvidence[decision.route] = decision.evidenceReturn
            }
        }

        // Sanity: the three known routes each map to a distinct evidence kind.
        #expect(routeToEvidence[.directSubstrate] == HermesGatewayPolicy.EvidenceReturn.none)
        #expect(routeToEvidence[.inProcessLocalPrompt] == HermesGatewayPolicy.EvidenceReturn.inProcessPromptContext)
        #expect(routeToEvidence[.hermesGateway] == HermesGatewayPolicy.EvidenceReturn.structuredEvidenceProvenance)
    }

    // MARK: - Surface count stability

    @Test("Surface enum count matches the doctrine-declared set")
    func surfaceEnumCountMatchesDoctrineDeclaredSet() {
        // The doctrine §7 + Annex enumerates 14 surfaces:
        //   2 local (deterministicLocalSubstrate, localPromptFormatting)
        //   6 cloud providers (cloud / openAI / anthropic / google /
        //                      openAICompatible / codexAccount)
        //   6 non-cloud external (CLI / MCP / Hermes subprocess /
        //                         browserComputerUse / docker / explicit)
        // = 14 total. A new case requires a deliberation brief to update the
        // doctrine + this test in the same patch.
        #expect(HermesGatewayPolicy.Surface.allCases.count == 14,
                "Surface enum must have 14 cases — if you intentionally added one, update the doctrine §7 build-order graph and this test in the same patch")
    }

    // MARK: - Cloud provider parity

    @Test("every cloud provider satisfies the same routing contract")
    func everyCloudProviderSatisfiesIdenticalRoutingContract() {
        // The point of the cloud provider grouping is that NO provider gets
        // its own architecture. They all share: Pro/Research tier,
        // hermesGateway route, requires network, no subprocess, structured
        // evidence return. Any deviation is a custom path that must be
        // justified in a deliberation brief.
        for surface in HermesGatewayPolicy.Surface.cloudProviderSurfaces {
            let decision = HermesGatewayPolicy.decision(for: surface)

            #expect(decision.tier == .proResearch,
                    "Cloud provider \(surface) must be Pro/Research tier")
            #expect(decision.route == .hermesGateway,
                    "Cloud provider \(surface) must route through the Hermes gateway")
            #expect(decision.requiresNetwork,
                    "Cloud provider \(surface) must require network")
            #expect(!decision.requiresSubprocess,
                    "Cloud provider \(surface) must not require subprocess (cloud calls are HTTP, not exec)")
            #expect(!decision.preservesDirectSubstratePath,
                    "Cloud provider \(surface) must not preserve the direct substrate path")
            #expect(decision.evidenceReturn == .structuredEvidenceProvenance,
                    "Cloud provider \(surface) must return structured evidence provenance")
            #expect(!HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(surface),
                    "Cloud provider \(surface) must not be allowed in Core App Store builds")
        }
    }

    // MARK: - Local substrate non-overlap

    @Test("local substrate and local prompt formatting use distinct in-process routes")
    func localSubstrateAndPromptUseDistinctRoutes() {
        // Both are Core, both stay direct, but they take different routes —
        // .directSubstrate (already-local answers) vs .inProcessLocalPrompt
        // (Hermes-family prompt grammar over local context). Collapsing them
        // to a single route would lose the diagnostic distinction Codex needs
        // to audit which Core surface is doing the work.
        let substrate = HermesGatewayPolicy.decision(for: .deterministicLocalSubstrate)
        let prompt = HermesGatewayPolicy.decision(for: .localPromptFormatting)

        #expect(substrate.route == .directSubstrate)
        #expect(prompt.route == .inProcessLocalPrompt)
        #expect(substrate.route != prompt.route,
                "Local substrate and prompt formatting must use distinct routes for diagnostic clarity")

        #expect(substrate.evidenceReturn == .none,
                "Direct substrate answers ARE the evidence — no return needed")
        #expect(prompt.evidenceReturn == .inProcessPromptContext,
                "Local prompt formatting returns in-process prompt context, not structured external evidence")
    }
}
