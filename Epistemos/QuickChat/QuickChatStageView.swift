#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)

import SwiftUI

// Surface A — the wave quick chat column (Plan 1-MAS §2.3). One calm column
// on the landing stage: ask · summarize · explain. Zero agent furniture,
// zero model egress — the engine badge says exactly what is answering and
// that it runs on this Mac (§0.6 capability truth; a compliance asset).
struct QuickChatStageView: View {
    @Binding var isPresented: Bool
    let theme: EpistemosTheme
    @Bindable var controller: QuickChatController
    @Bindable var downloads: QuickChatModelDownloadManager

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            transcript
            Divider().opacity(0.25)
            inputBar
        }
        .background(theme.glassBg.opacity(theme.isDark ? 0.32 : 0.22))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    theme.resolved.accent.color.opacity(theme.isDark ? 0.22 : 0.16),
                    lineWidth: 0.8
                )
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.resolved.accent.color)
            Text("Ask")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.resolved.foreground.color)
            Spacer()
            engineBadge
            Button {
                controller.cancel()
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.55))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close quick chat")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var engineBadge: some View {
        switch controller.engineStatus {
        case .ready(let engine):
            Label("Private · \(engine.displayName)", systemImage: "lock.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.resolved.foreground.color.opacity(0.6))
                .labelStyle(.titleAndIcon)
                .help("Answers are generated on this Mac. Nothing leaves your device.")
        case .unavailable:
            Label("No engine available", systemImage: "exclamationmark.triangle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if controller.messages.isEmpty {
                        emptyState
                    }
                    ForEach(controller.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                    if controller.isGenerating {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Thinking on this Mac…")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.resolved.foreground.color.opacity(0.5))
                        }
                        .id("generating")
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: controller.messages.count) {
                if let last = controller.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask anything. Answers are generated privately on this Mac.")
                .font(.system(size: 12))
                .foregroundStyle(theme.resolved.foreground.color.opacity(0.55))
            switch controller.engineStatus {
            case .unavailable:
                // No engine at all — the download is the primary call to action.
                modelDownloadOffer
            case .ready(.appleFM):
                // §9.2: FM works instantly; offer a quiet stronger-local upsell
                // only when no local model is installed yet.
                if controller.ggufBackend.resolvedEntry() == nil {
                    quietLocalModelUpsell
                }
            case .ready:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var quietLocalModelUpsell: some View {
        let entry = GGUFModelCatalog.defaultEntry
        switch downloads.state(for: entry) {
        case .notInstalled:
            Button {
                downloads.beginDownload(entry)
            } label: {
                Label("Want a stronger local model? Download \(entry.displayName)", systemImage: "arrow.down.circle")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.45))
            }
            .buttonStyle(.plain)
            .help("Optional. Runs entirely on this Mac; ~\(entry.approxDownloadBytes / 1_000_000_000) GB.")
        case .downloading, .verifying, .failed:
            modelDownloadOffer
        case .installed:
            EmptyView()
        }
    }

    @ViewBuilder
    private var modelDownloadOffer: some View {
        let entry = GGUFModelCatalog.defaultEntry
        VStack(alignment: .leading, spacing: 8) {
            switch downloads.state(for: entry) {
            case .notInstalled, .failed:
                if case .failed(let reason) = downloads.state(for: entry) {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
                Button {
                    downloads.beginDownload(entry)
                } label: {
                    Label(
                        "Download \(entry.displayName) (~\(entry.approxDownloadBytes / 1_000_000_000) GB)",
                        systemImage: "arrow.down.circle"
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Text("One-time download · runs entirely on this Mac · \(entry.license)")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.45))
            case .downloading(let progress):
                ProgressView(value: progress) {
                    Text("Downloading \(entry.displayName)…")
                        .font(.system(size: 11))
                }
                .progressViewStyle(.linear)
                .frame(maxWidth: 320)
                Button("Cancel") { downloads.cancelDownload(entry) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.5))
            case .verifying:
                Label("Verifying checksum…", systemImage: "checkmark.shield")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.6))
            case .installed:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ message: QuickChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.userBubbleText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(theme.userBubbleBg)
                    }
            }
        case .assistant(let engine):
            VStack(alignment: .leading, spacing: 4) {
                Text(message.text.isEmpty ? "…" : message.text)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(engine.displayName)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.38))
            }
        case .notice:
            Text(message.text)
                .font(.system(size: 11))
                .foregroundStyle(theme.resolved.foreground.color.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
        }
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask, summarize, explain…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .lineLimit(1...4)
                .focused($inputFocused)
                .onSubmit(submit)
            if controller.isGenerating {
                Button {
                    controller.cancel()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.resolved.accent.color)
                }
                .buttonStyle(.plain)
                .help("Stop generating")
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? theme.resolved.foreground.color.opacity(0.25)
                                : theme.resolved.accent.color
                        )
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func submit() {
        let text = draft
        draft = ""
        controller.send(text)
    }
}

#endif
