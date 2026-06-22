import Testing
import Foundation
@testable import Epistemos

/// Direct semantics of the shared in-app-toggle override helper that the act + work gates delegate to.
/// (The gates' own suites cover it indirectly; this locks the helper itself so a future change can't silently
/// shift override > env > off for BOTH gates at once.)
@Suite("FeatureGateOverride — shared act/work gate override semantics")
struct FeatureGateOverrideTests {
    @Test("isTruthy accepts the canonical on-values, rejects everything else")
    func truthy() {
        for on in ["1", "true", "yes", "on", " On ", "TRUE"] {
            #expect(FeatureGateOverride.isTruthy(on), "\(on) should be truthy")
        }
        for off in [nil, "", "0", "false", "no", "off", "maybe"] {
            #expect(!FeatureGateOverride.isTruthy(off), "\(off ?? "nil") should be falsy")
        }
    }

    @Test("value/set is a tri-state round-trip (set true/false, clear with nil)")
    func roundTrip() {
        let suite = "test.featuregate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "k"

        #expect(FeatureGateOverride.value(forKey: key, defaults: defaults) == nil)  // absent
        FeatureGateOverride.set(true, forKey: key, defaults: defaults)
        #expect(FeatureGateOverride.value(forKey: key, defaults: defaults) == true)
        FeatureGateOverride.set(false, forKey: key, defaults: defaults)
        #expect(FeatureGateOverride.value(forKey: key, defaults: defaults) == false)
        FeatureGateOverride.set(nil, forKey: key, defaults: defaults)  // clear
        #expect(FeatureGateOverride.value(forKey: key, defaults: defaults) == nil)
    }

    @Test("resolved: override > env > off")
    func resolution() {
        let suite = "test.featuregate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "k"

        // no override → defer to env.
        #expect(!FeatureGateOverride.resolved(overrideKey: key, envValue: nil, defaults: defaults))
        #expect(FeatureGateOverride.resolved(overrideKey: key, envValue: "1", defaults: defaults))
        // override WINS over env.
        FeatureGateOverride.set(true, forKey: key, defaults: defaults)
        #expect(FeatureGateOverride.resolved(overrideKey: key, envValue: nil, defaults: defaults))
        FeatureGateOverride.set(false, forKey: key, defaults: defaults)
        #expect(!FeatureGateOverride.resolved(overrideKey: key, envValue: "1", defaults: defaults))
    }
}
