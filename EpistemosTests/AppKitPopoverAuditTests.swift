import Testing

@Suite("AppKit Popover Audit")
struct AppKitPopoverAuditTests {
    @Test("popover sizing uses a reentrancy guard instead of recursive layout churn")
    func popoverSizingUsesReentrancyGuard() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Shared/AppKitPopover.swift")

        #expect(source.contains("guard !coordinator.isSynchronizingContentSize else { return }"))
        #expect(source.contains("coordinator.isSynchronizingContentSize = true"))
        #expect(source.contains("Task { @MainActor in"))
        #expect(!source.contains("DispatchQueue.main.async"))
    }
}
