import Foundation
import Testing
@testable import Epistemos

// Verifies WorkPermissionRequestDecoder against the OpenGUI HarnessEvent permission shape
// ({type:"permission.requested", request:{id,sessionID,permission,patterns,always,tool{callID}}}) — the foundation of
// the native permission-card feature (visual target). Pure + lenient: digs to the request wherever it sits; never throws.
@Suite("Work permission request — decode (native permission card)")
struct WorkPermissionRequestTests {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    @Test("decodes the harness-event envelope {type:permission.requested, request:{…}}")
    func decodesEnvelope() {
        let r = WorkPermissionRequestDecoder.decode(data(#"""
        {"type":"permission.requested","request":{
          "id":"perm_1","harnessId":"codex","sessionID":"ses_9","permission":"bash",
          "patterns":["rm -rf build"],"always":["bash"],"tool":{"messageID":"m1","callID":"call_7"}}}
        """#))
        #expect(r?.id == "perm_1")
        #expect(r?.harnessID == "codex")
        #expect(r?.sessionID == "ses_9")
        #expect(r?.permission == "bash")
        #expect(r?.patterns == ["rm -rf build"])
        #expect(r?.alwaysOptions == ["bash"])
        #expect(r?.toolCallID == "call_7")
        #expect(r?.detail == "rm -rf build")     // subtitle = the specific pattern
    }

    @Test("decodes a bare request object + an {event:{request}} wrapper")
    func decodesBareAndNested() {
        let bare = WorkPermissionRequestDecoder.decode(data(
            #"{"id":"p2","sessionID":"s","permission":"edit","patterns":[]}"#))
        #expect(bare?.permission == "edit")
        #expect(bare?.detail == "edit")          // empty patterns → falls back to the permission key
        let nested = WorkPermissionRequestDecoder.decode(data(
            #"{"event":{"type":"permission.requested","request":{"id":"p3","harnessId":"claude-code","sessionID":"s","permission":"webfetch","patterns":["https://x"]}}}"#))
        #expect(nested?.id == "p3")
        #expect(nested?.harnessID == "claude-code")
        #expect(nested?.permission == "webfetch")
    }

    @Test("lenient: nil / malformed / missing id/session/permission → nil")
    func lenient() {
        #expect(WorkPermissionRequestDecoder.decode(nil) == nil)
        #expect(WorkPermissionRequestDecoder.decode(data("nope")) == nil)
        #expect(WorkPermissionRequestDecoder.decode(data(#"{"request":{"sessionID":"s","permission":"bash"}}"#)) == nil) // no id
        #expect(WorkPermissionRequestDecoder.decode(data(#"{"request":{"id":"x","permission":"bash"}}"#)) == nil)         // no session
        #expect(WorkPermissionRequestDecoder.decode(data(#"{"request":{"id":"x","sessionID":"s"}}"#)) == nil)           // no permission
    }

    @Test("decision enum covers allow-once / allow-always / reject")
    func decisions() {
        #expect(Set(WorkPermissionDecision.allCases) == [.allowOnce, .allowAlways, .reject])
    }

    @Test("source documents the live harness event bridge, not the dead per-session API")
    func documentsLiveHarnessEventBridge() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkPermissionRequest.swift")
        #expect(src.contains(#"harness.on("event")"#))
        #expect(!src.contains("subscribeHarnessEvents"))
    }

    @Test("permission card keeps compact stable ask controls")
    func permissionCardControlsStayCompact() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkPermissionCardView.swift")
        #expect(src.contains(#"Image(systemName: "lock.shield")"#))
        #expect(src.contains(".frame(width: 14, height: 14)"))
        #expect(src.contains(".fixedSize(horizontal: true, vertical: false)"))
        #expect(src.contains(#"decisionButton("Allow once""#))
        #expect(src.contains(#"decisionButton("Always""#))
        #expect(src.contains(#"decisionButton("Deny""#))
    }
}
