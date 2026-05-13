import Testing
import Foundation
@testable import Epistemos

/// RCA2-P0-003 drift gate — Vault Organizer scans must use the
/// local-first triage path so note titles + snippets aren't silently
/// shipped to cloud when the user clicks "Scan Vault."
///
/// Acceptance criterion: scan prompts must be local-only OR
/// explicitly consented. The fix shipped 2026-05-13 routes all three
/// `triage.generateGeneral(...)` call sites in `VaultOrganizerView`
/// through `operatingMode: .fast`, which biases the triage toward
/// localMLX / Apple Intelligence even if the user is currently in
/// Pro/Agent mode for chat.
///
/// Without `operatingMode: .fast` the call would inherit the
/// ambient default and could route to cloud for Pro/Agent users.
/// This drift gate fails CI if any of the three call sites drops
/// the explicit local-first argument.
@Suite("RCA2-P0-003 Vault Organizer Privacy Guard")
struct VaultOrganizerPrivacyGuardTests {

    @Test("All Vault Organizer triage calls pin operatingMode: .fast for local-first routing")
    func vaultOrganizerCallsAreLocalFirst() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/VaultOrganizerView.swift"
        )

        // Count every triage.generateGeneral( call site. The Vault
        // Organizer has three: tag-suggestions, folder-suggestions,
        // new-folder-suggestions. Each one must carry the explicit
        // `operatingMode: .fast` argument.
        let callSites = source.components(separatedBy: "triage.generateGeneral(").count - 1
        #expect(callSites == 3,
            "VaultOrganizerView should have exactly 3 triage.generateGeneral call sites (tag / folder / new-folder); got \(callSites). If you added a new scan operation, give it operatingMode: .fast too — see RCA2-P0-003.")

        // The operatingMode: .fast argument must appear at least
        // three times — once per call site.
        let localFirstArgs = source.components(separatedBy: "operatingMode: .fast").count - 1
        #expect(localFirstArgs >= 3,
            "VaultOrganizerView must pass `operatingMode: .fast` at every triage.generateGeneral call site to keep scan prompts local-first per RCA2-P0-003; found \(localFirstArgs) occurrences")

        // Doctrine cross-reference must remain so a refactor that
        // rewrites the file surfaces the rationale in code review.
        #expect(source.contains("RCA2-P0-003"),
            "VaultOrganizerView must retain its RCA2-P0-003 cross-reference comment so the local-first rationale stays visible to future refactors")
    }

    @Test("Doctrine comment retains the local-first privacy rationale")
    func vaultOrganizerRetainsPrivacyDoctrine() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/VaultOrganizerView.swift"
        )
        // The doctrine block on the first call site spells out why
        // local-first matters: user expectation + cloud-leak
        // prevention. Pin a load-bearing phrase so a refactor that
        // strips the comment surfaces the original concern.
        #expect(source.contains("local-first"),
            "VaultOrganizerView doctrine comment must mention 'local-first' so the privacy rationale survives renames")
        // Doctrine comment wraps across lines (the auto-format engine
        // inserts `// ` at every wrap point), so we look for "note
        // titles" only — enough proof the comment names the
        // data-leak surface without depending on line-wrap behavior.
        #expect(source.contains("note titles"),
            "VaultOrganizerView doctrine comment must spell out what data the prompts carry so future maintainers see the privacy cost — see RCA2-P0-003")
    }
}
