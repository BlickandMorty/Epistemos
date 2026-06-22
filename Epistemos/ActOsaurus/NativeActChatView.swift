//
//  NativeActChatView.swift
//  Epistemos — ACT ARCHITECTURE PIVOT (owner P0, addendum §1994/§2029/§2048)
//
//  The act surface is NATIVE Epistemos SwiftUI (cream/monospace, by construction —
//  no theme cascade) LINKED to the Osaurus ENGINE in-process. This is the "fresh
//  native views, NOT the old ChatView, NOT the mounted Osaurus ChatView" direction
//  (§2029). The engine link is the CERTIFIED 0.4 path: `OsaurusActBridge.
//  runTurnStreamingInProcess` → `OsaurusCore.CoreModelService.generateStream`
//  (the exact call the green send harness, ActOsaurusSendHarnessTests, exercises).
//
//  Renders cream/monospace natively; consumes the engine's streamed output. (Channel
//  splitting — thinking/content/tool-calls into distinct native rows — is the next
//  refinement; this first shippable view renders the streamed content natively.)
//
//  Pro / direct-distribution only (OsaurusCore is not linked into MAS).

#if !EPISTEMOS_APP_STORE

import SwiftUI
import OsaurusCore

struct NativeActChatView: View {
    struct ActMessage: Identifiable {
        let id = UUID()
        let role: String          // "you" | "act"
        var text: String
    }

    @State private var messages: [ActMessage] = []
    @State private var streaming: Bool = false
    @State private var streamTask: Task<Void, Never>? = nil

    /// Back to the Epistemos landing (D6). Provided by the host (RootView).
    var onBack: () -> Void = {}
    /// The owner's selected model id (nil → engine's configured core default,
    /// which bootstrap seeds to the owner's first model).
    var selectedModel: String? = nil

    // Epistemos cream/ink palette — native, by construction (no cascade).
    private let cream = Color(.sRGB, red: 0xFB / 255.0, green: 0xFA / 255.0, blue: 0xF5 / 255.0, opacity: 1)
    private let surface2 = Color(.sRGB, red: 0xF4 / 255.0, green: 0xF3 / 255.0, blue: 0xEE / 255.0, opacity: 1)
    private let ink = Color(.sRGB, red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0, opacity: 1)
    private let muted = Color(.sRGB, red: 0x6E / 255.0, green: 0x6E / 255.0, blue: 0x73 / 255.0, opacity: 1)

    var body: some View {
        HStack(spacing: 0) {
            // GRAFT — SIDE PANEL (pass67 WATCH): the owner's existing native ChatSidebarView
            // (recent chats / search), composed natively. Env-driven (UIState/ChatState/
            // modelContext resolve from RootView, same as ChatInputBar).
            ChatSidebarView()
                .frame(width: 248)
                .background(surface2)
            Divider().overlay(ink.opacity(0.08))
            VStack(spacing: 0) {
                toolbar
                Divider().overlay(ink.opacity(0.08))
                thread
                composer
            }
        }
        .background(cream.ignoresSafeArea())
    }

    // MARK: native toolbar (D3 pill + D6 back)
    private var toolbar: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 9).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(surface2, in: Capsule())
            .overlay(Capsule().stroke(ink.opacity(0.12), lineWidth: 1))
            .accessibilityIdentifier("act.back")
            .accessibilityLabel("Back to landing")

            Text("act")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(surface2, in: Capsule())
                .overlay(Capsule().stroke(ink.opacity(0.12), lineWidth: 1))
                .accessibilityIdentifier("act.pill")

            Spacer()
            Text(selectedModel ?? "owner model")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(muted)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
    }

    // MARK: native thread (cream/mono, by construction)
    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if messages.isEmpty {
                        Text("Ask anything.")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(muted)
                            .padding(.top, 24)
                    }
                    ForEach(messages) { m in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.role)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(muted)
                            Text(m.text.isEmpty && streaming ? "…" : m.text)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(ink)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(m.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.last?.text) { _, _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    // MARK: owner's RICH native composer (ChatInputBar) — pivot §pass66 "compose the
    // owner's existing chrome, not a skeleton." Provides attachments / model picker /
    // inline runtime panel + cream/monospace; drives the ACT ENGINE via `onSubmit`
    // (NOT the old chat coordinator). Its @Environment deps (UIState/ChatState/…) are
    // satisfied by RootView's environment (same as LandingView/old ChatView).
    private var composer: some View {
        ChatInputBar(
            onSubmit: { prompt in handleSend(prompt) },
            onStop: { stopStreaming() },
            isProcessing: streaming
        )
    }

    // MARK: engine link — the CERTIFIED 0.4 path
    private func handleSend(_ raw: String) {
        let prompt = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !streaming else { return }
        messages.append(ActMessage(role: "you", text: prompt))
        messages.append(ActMessage(role: "act", text: ""))
        let replyIndex = messages.count - 1
        streaming = true
        let model = selectedModel
        streamTask = Task {
            do {
                let stream = try await OsaurusActBridge().runTurnStreamingInProcess(
                    prompt: prompt, systemPrompt: nil, maxTokens: 512, requestedModel: model)
                for try await token in stream {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        if messages.indices.contains(replyIndex) { messages[replyIndex].text += token }
                    }
                }
            } catch {
                await MainActor.run {
                    if messages.indices.contains(replyIndex) {
                        messages[replyIndex].text += (messages[replyIndex].text.isEmpty ? "" : "\n")
                            + "⚠︎ \(error.localizedDescription)"
                    }
                }
            }
            await MainActor.run { streaming = false }
        }
    }

    private func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        streaming = false
    }
}

#endif
