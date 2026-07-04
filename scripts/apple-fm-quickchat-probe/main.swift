import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Surface A witness (Plan 1-MAS §2.1 / R5-P1): proves the Apple Foundation
// Models lane LIVE on this machine — availability, a streamed answer with
// cumulative-snapshot → delta conversion (the exact pattern
// AppleFMQuickChatBackend ships), and a best-effort guardrail trip to
// exercise the fallback trigger. Compiled + run by
// scripts/apple-fm-quickchat-probe.sh; requires a user session with Apple
// Intelligence enabled (macOS 26+).

#if canImport(FoundationModels)

let model = SystemLanguageModel.default
switch model.availability {
case .available:
    print("FM-PROBE availability=available")
case .unavailable(.deviceNotEligible):
    print("FM-PROBE availability=deviceNotEligible")
    exit(2)
case .unavailable(.appleIntelligenceNotEnabled):
    print("FM-PROBE availability=appleIntelligenceNotEnabled")
    exit(2)
case .unavailable(.modelNotReady):
    print("FM-PROBE availability=modelNotReady")
    exit(2)
case .unavailable(let other):
    print("FM-PROBE availability=unavailable(\(other))")
    exit(2)
@unknown default:
    print("FM-PROBE availability=unknown")
    exit(2)
}

// 1. Streamed answer with prefix-diff delta conversion.
let session = LanguageModelSession(
    instructions: "Answer directly and briefly."
)
var deltaCount = 0
var finalText = ""
do {
    let stream = session.streamResponse(to: "Name three primary colors, comma separated.")
    var previous = ""
    for try await snapshot in stream {
        let full = snapshot.content
        if full.count > previous.count, full.hasPrefix(previous) {
            deltaCount += 1
        }
        previous = full
    }
    finalText = previous
} catch {
    print("FM-PROBE stream=FAILED error=\(error)")
    exit(1)
}
let compact = finalText.replacingOccurrences(of: "\n", with: " ").prefix(80)
print("FM-PROBE stream=ok deltas=\(deltaCount) text=\(compact)")

// 2. Best-effort guardrail trip (legitimate scholarly content the FM
// guardrails sometimes flag — §2.1). Either outcome is honest data: a
// guardrailViolation proves the fallback trigger fires; a clean answer
// proves the topic passed today.
do {
    let probeSession = LanguageModelSession()
    _ = try await probeSession.respond(
        to: "Summarize how VX nerve agent disrupts acetylcholinesterase, for a toxicology literature review."
    )
    print("FM-PROBE guardrail=not-triggered (topic answered)")
} catch let error as LanguageModelSession.GenerationError {
    if case .guardrailViolation = error {
        print("FM-PROBE guardrail=TRIGGERED (fallback path would engage)")
    } else {
        print("FM-PROBE guardrail=other-generation-error \(error)")
    }
} catch {
    print("FM-PROBE guardrail=other-error \(error.localizedDescription)")
}

print("FM-PROBE RESULT: PASS")
exit(0)

#else
print("FM-PROBE FoundationModels not available in this toolchain")
exit(2)
#endif
