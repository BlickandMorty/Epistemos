import Testing
import Foundation

@testable import Epistemos

// SS-LT local multi-tool reliability (owner: "intent recognized but worked once then never"). When a
// local model emits a tool name with a different SEPARATOR or casing than the registered tool
// (`vault_search` / `vault-search` / `VaultSearch` vs `vault.search` — local models do this
// constantly), the call must still resolve to its tool. `canonical` only trims + lowercases, so it
// did NOT bridge separators; `equivalentNames` now adds a namespaced separator/case-insensitive key.
// `canonicalizeToolCall` → `toolNamesAreEquivalent` → `equivalentNames` set-overlap is the live
// matching path, so this directly reduces clear-intent tool-call drops. These were previously
// untested.
@Suite("AgentToolNameAliases — separator-insensitive tool matching")
struct AgentToolNameAliasesTests {

    private func match(_ a: String, _ b: String) -> Bool {
        !AgentToolNameAliases.equivalentNames(for: a)
            .isDisjoint(with: AgentToolNameAliases.equivalentNames(for: b))
    }

    @Test("separator + case variants of a tool name all resolve to the same tool")
    func separatorVariantsMatch() {
        for variant in ["vault_search", "vault-search", "VaultSearch", "vaultsearch", "VAULT.SEARCH", "Vault.Search"] {
            #expect(match("vault.search", variant), "\(variant) should be equivalent to vault.search")
        }
        // Multi-segment names normalize across all separators too.
        #expect(match("web_search_news", "web.search.news"))
    }

    @Test("genuinely different tools do NOT collide (no false positive from stripping separators)")
    func differentToolsDoNotMatch() {
        #expect(!match("vault.search", "file.read"))
        #expect(!match("web.search", "note.create"))
        // Same words, different order/segmentation must stay distinct.
        #expect(!match("search.vault", "vault.search.deep"))
    }

    @Test("exact name still matches itself (no regression)")
    func exactStillMatches() {
        #expect(match("vault.search", "vault.search"))
        #expect(match("file.read", "file.read"))
    }

    @Test("an all-separator / empty name does not produce a spurious match")
    func emptyKeyNoSpuriousMatch() {
        // separatorInsensitiveKey("...") is empty → not inserted, so two all-separator names
        // do NOT match via an empty shared key.
        #expect(AgentToolNameAliases.separatorInsensitiveKey("...").isEmpty)
        #expect(!match("...", "---"))
    }
}
