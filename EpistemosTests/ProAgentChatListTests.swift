import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE
@Suite("ProAgent chat list")
struct ProAgentChatListTests {
    @Test("opencode decoder accepts envelopes, bounds text, skips invalid rows, and ignores legacy version tags")
    func opencodeDecoderBoundsText() {
        let longTitle = String(repeating: "T", count: 240)
        let longDirectory = "/work/" + String(repeating: "nested/", count: 200)
        let rows = ProAgentChatListDecoder.opencodeRows(from: [
            "sessions": [
                [
                    "id": " session-1\n",
                    "title": "Build\u{0007}\nship",
                    "directory": longDirectory,
                    "time": ["updated": 42],
                ],
                [
                    "id": "session-2",
                    "title": longTitle,
                    "directory": "/repo",
                    "version": "legacy-secondary-engine",
                    "time": ["updated": 12.5],
                ],
                [
                    "id": "   ",
                    "title": "ignored",
                ],
            ],
        ])

        #expect(rows.count == 2)
        #expect(rows[0].id == "session-1")
        #expect(rows[0].title == "Build ship")
        #expect(rows[0].directory.count == 1_024)
        #expect(rows[0].updatedAtSeconds == 42)
        #expect(rows[1].title.count == 180)
        #expect(rows[1].title.hasSuffix("..."))
    }

    @Test("all chats sheet delegates fetch and decode to the pure chat list file")
    func allChatsSheetDelegatesFetchAndDecode() throws {
        let sheet = try loadMirroredSourceTextFile("Epistemos/ProAgent/ProAgentAllChatsSheet.swift")
        let chatList = try loadMirroredSourceTextFile("Epistemos/ProAgent/ProAgentChatList.swift")

        #expect(sheet.contains("ProAgentChatListFetcher.fetchRows"))
        #expect(!sheet.contains("JSONSerialization"))
        #expect(!sheet.contains("URLSession.shared.data"))
        #expect(!sheet.lowercased().contains("goose"))
        #expect(chatList.contains("enum ProAgentChatListDecoder"))
        #expect(chatList.contains("request.timeoutInterval = 6"))
        #expect(!chatList.contains("goose-index"))
        #expect(!chatList.contains("fetchGooseRows"))
        #expect(!chatList.contains("gooseRows("))
    }
}
#endif
