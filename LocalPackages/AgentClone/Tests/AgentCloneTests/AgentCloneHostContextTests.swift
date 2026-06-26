import XCTest
import AgentClone

final class AgentCloneHostContextTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = AgentCloneBridge.drainPendingPrompts()
    }

    override func tearDown() {
        _ = AgentCloneBridge.drainPendingPrompts()
        super.tearDown()
    }

    func testSummaryIncludesVaultAndWorkspaceWhenBothArePresent() {
        let context = AgentCloneHostContext(
            appName: "Epistemos",
            workspaceRootPath: "/Users/example",
            vaultRootPath: "/Users/example/Vault",
            appSupportRootPath: "/Users/example/Library/Application Support/Epistemos/AgentClone",
            mode: "Act",
            presentation: "main"
        )

        XCTAssertEqual(context.preferredProjectFolder, "/Users/example/Vault")
        XCTAssertEqual(context.appSupportRootPath, "/Users/example/Library/Application Support/Epistemos/AgentClone")
        XCTAssertEqual(
            context.summary,
            "Epistemos | Act | surface: main | vault: /Users/example/Vault | workspace: /Users/example"
        )
    }

    func testSummaryFallsBackToWorkspaceWhenVaultIsAbsent() {
        let context = AgentCloneHostContext(
            appName: "Epistemos",
            workspaceRootPath: "/Users/example",
            mode: "Chat",
            presentation: "main"
        )

        XCTAssertEqual(context.preferredProjectFolder, "/Users/example")
        XCTAssertEqual(context.summary, "Epistemos | Chat | surface: main | workspace: /Users/example")
    }

    func testBlankContextFieldsAreNormalizedOut() {
        let context = AgentCloneHostContext(
            appName: "Epistemos",
            workspaceRootPath: "   ",
            vaultRootPath: "\n",
            mode: "\t",
            presentation: " "
        )

        XCTAssertNil(context.preferredProjectFolder)
        XCTAssertEqual(context.summary, "Epistemos")
    }

    @MainActor
    func testBridgeStoresCurrentHostContextForViewAppearRecovery() {
        let context = AgentCloneHostContext(
            appName: "Epistemos",
            workspaceRootPath: "/Users/example",
            vaultRootPath: "/Users/example/Vault",
            mode: "Act"
        )

        AgentCloneBridge.updateHostContext(context)

        XCTAssertEqual(AgentCloneBridge.currentHostContext, context)
    }

    func testBridgeDrainsMissedPromptsInSubmissionOrder() {
        let firstID = AgentCloneBridge.submitPrompt("first pending prompt")
        let secondID = AgentCloneBridge.submitPrompt("second pending prompt")

        let drained = AgentCloneBridge.drainPendingPrompts()

        XCTAssertEqual(drained.map(\.id), [firstID, secondID])
        XCTAssertEqual(drained.map(\.text), ["first pending prompt", "second pending prompt"])
        XCTAssertTrue(AgentCloneBridge.drainPendingPrompts().isEmpty)
    }

    func testBridgeCanMarkLiveNotificationPromptConsumed() {
        let consumedID = AgentCloneBridge.submitPrompt("live notification prompt")
        let remainingID = AgentCloneBridge.submitPrompt("missed prompt")

        AgentCloneBridge.markPromptConsumed(id: consumedID)

        let drained = AgentCloneBridge.drainPendingPrompts()
        XCTAssertEqual(drained.map(\.id), [remainingID])
        XCTAssertEqual(drained.map(\.text), ["missed prompt"])
    }
}
