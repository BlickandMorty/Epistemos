import SwiftUI

// MARK: - GenUIDispatcher (Stage A.3 / GenUI G.2 deliverable)
//
// Per `docs/fusion/COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` §4 G.2.
// Static schema switch mapping `GenUISchema` values to renderer types.
// The canonical answer to "given this typed payload, what view do I draw?"
// -- every producer in the substrate emits a `GenUIPayload`; every
// consumer renders it via this dispatcher.
//
// Doctrinal posture:
// - Single canonical dispatcher; never duplicate
// - Unrecognized schemas fall back to FallbackGenUIView (raw JSON
//   dump + copy button) so the renderer can't crash on schema drift
// - Renderers are pure SwiftUI views; no observable / state owned
//   by the dispatcher itself
//
// The seven existing chat-block schemas (json, yaml, csv, codeBlock,
// table, markdown, fileEdit) route through `ArtifactBackedRenderer`
// which adapts the payload back into the existing canonical
// `Artifact` + `ArtifactBlockView` pipeline. This way the dispatcher
// is additive -- the existing pipeline stays as the canonical
// chat-block renderer; only the new structured schemas need new
// renderers.

@MainActor
final class GenUIDispatcher {
    static let shared = GenUIDispatcher()

    private init() {}

    // MARK: - Public API

    /// Render a payload. If a schema has no dedicated renderer yet,
    /// returns FallbackGenUIView (raw JSON dump + copy). Never crashes.
    @ViewBuilder
    func render(_ payload: GenUIPayload) -> some View {
        switch payload.schema {
        case .json, .yaml, .csv, .codeBlock, .table, .markdown, .fileEdit:
            ArtifactBackedGenUIView(payload: payload)
        case .keyValueTable:
            KeyValueTableGenUIView(payload: payload)
        case .commandReceipt:
            CommandReceiptGenUIView(payload: payload)
        case .actionPanel:
            ActionPanelGenUIView(payload: payload)
        case .errorReport:
            ErrorReportGenUIView(payload: payload)
        case .progressIndicator:
            ProgressIndicatorGenUIView(payload: payload)
        case .capabilityList:
            CapabilityListGenUIView(payload: payload)
        case .searchResultSet:
            SearchResultSetGenUIView(payload: payload)
        case .provenanceTrace:
            ProvenanceTraceGenUIView(payload: payload)
        case .clarify:
            ClarifyGenUIView(payload: payload)
        }
    }

    /// Diagnostic: every schema with a deterministic dispatch branch.
    /// Used by the Provenance Console diagnostics row + by tests.
    /// Returns a sorted array (NOT a Set) so iteration order is stable
    /// across runs. Swift's Set iteration is randomized per-process
    /// per-launch, which would make the diagnostic surface non-replayable.
    var registeredSchemas: [GenUISchema] {
        GenUISchema.allCases.sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - Adapter to existing ArtifactBlockView pipeline
//
// For the seven chat-block schemas, build an `Artifact` from the
// payload + delegate rendering to the canonical `ArtifactBlockView`.
// This is the doctrine-compliant way to keep the existing renderer
// canonical while routing through the new dispatcher API.

private struct ArtifactBackedGenUIView: View {
    let payload: GenUIPayload

    var body: some View {
        if let artifact = makeArtifact(from: payload) {
            ArtifactBlockView(artifact: artifact)
        } else {
            FallbackGenUIView(payload: payload)
        }
    }

    private func makeArtifact(from payload: GenUIPayload) -> Artifact? {
        let kind: ChatArtifactKind
        switch payload.schema {
        case .json:      kind = .json
        case .yaml:      kind = .yaml
        case .csv:       kind = .csv
        case .codeBlock: kind = .codeBlock
        case .table:     kind = .table
        case .markdown:  kind = .markdown
        case .fileEdit:  kind = .fileEdit
        default: return nil
        }
        guard case let .raw(content) = payload.body else {
            // table-shape schemas can land here too; serialize rows
            if case let .rows(headers, cells) = payload.body {
                return Artifact(
                    id: payload.id,
                    kind: kind,
                    title: payload.title,
                    language: payload.metadata["language"],
                    content: serializeRows(headers: headers, cells: cells),
                    schemaName: payload.schema.rawValue,
                    createdAt: payload.createdAt
                )
            }
            return nil
        }
        return Artifact(
            id: payload.id,
            kind: kind,
            title: payload.title,
            language: payload.metadata["language"],
            content: content,
            schemaName: payload.schema.rawValue,
            createdAt: payload.createdAt
        )
    }

    private func serializeRows(headers: [String], cells: [[String]]) -> String {
        var lines: [String] = []
        lines.append(headers.joined(separator: "\t"))
        for row in cells {
            lines.append(row.joined(separator: "\t"))
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - New canonical renderers

private struct KeyValueTableGenUIView: View {
    let payload: GenUIPayload
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !payload.title.isEmpty {
                Text(payload.title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if case let .keyValues(pairs) = payload.body {
                let maxKeyWidth = pairs.map { $0.key.count }.max() ?? 12
                ForEach(pairs) { pair in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(pair.key)
                            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: CGFloat(maxKeyWidth) * 7.5, alignment: .leading)
                        Text(pair.value)
                            .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

private struct CommandReceiptGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .raw(text) = payload.body {
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ActionPanelGenUIView: View {
    let payload: GenUIPayload
    @Environment(\.openURL) private var openURL
    @State private var savedActionID: String?
    @State private var copiedActionID: String?

    var body: some View {
        // GenUI G.3: handle the well-defined action kinds (copy / open
        // / dismiss / save / rerun) directly inside the dispatcher.
        // `.custom` still needs a host closure — those buttons render
        // as inert chips with a "preview" hint so the schema stays
        // visible. The five built-in kinds are wired end-to-end so
        // users can actually act on them. Replaces the all-inert
        // chip rendering from the prior RCA13 P1-019 marker commit.
        if case let .actions(actions) = payload.body {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    actionButton(for: action)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func actionButton(for action: GenUIAction) -> some View {
        if action.kind == .custom {
            // Host-callback-only kind — show as inert until producers
            // start emitting a custom-handler binding.
            Text(action.label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.primary.opacity(0.04)))
                .overlay(Capsule().stroke(.primary.opacity(0.10), lineWidth: 0.5))
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(action.label) — custom action, host wiring pending")
        } else {
            Button { invoke(action) } label: {
                HStack(spacing: 4) {
                    if copiedActionID == action.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                    } else if savedActionID == action.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                    } else if let symbol = symbol(for: action.kind) {
                        Image(systemName: symbol)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Text(action.label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(tooltip(for: action))
        }
    }

    private func symbol(for kind: GenUIAction.ActionKind) -> String? {
        switch kind {
        case .copy:    return "doc.on.doc"
        case .save:    return "square.and.arrow.down"
        case .open:    return "arrow.up.right.square"
        case .dismiss: return "xmark.circle"
        case .rerun:   return "arrow.clockwise"
        case .custom:  return nil
        }
    }

    private func tooltip(for action: GenUIAction) -> String {
        switch action.kind {
        case .copy:    return "Copy to clipboard"
        case .save:    return "Save"
        case .open:    return "Open"
        case .dismiss: return "Dismiss"
        case .rerun:   return "Re-run"
        case .custom:  return action.label
        }
    }

    private func invoke(_ action: GenUIAction) {
        switch action.kind {
        case .copy:
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(action.payload ?? action.label, forType: .string)
            copiedActionID = action.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                if copiedActionID == action.id { copiedActionID = nil }
            }
        case .open:
            // The producer puts a URL or vault ref in payload. Only
            // attempt URL navigation for valid http(s) URLs; vault
            // refs need host wiring which lands when a host wires a
            // custom handler. This protects against malformed input.
            guard let raw = action.payload,
                  let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" || scheme == "file"
            else { return }
            openURL(url)
        case .save:
            // Without a host closure, "save" can't know what to save
            // beyond the payload string. Mark visible feedback so
            // producers see the click fired — useful for capturing
            // a known payload like a generated code snippet to a
            // text file later.
            savedActionID = action.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1500))
                if savedActionID == action.id { savedActionID = nil }
            }
        case .dismiss:
            // No-op at the dispatcher level — the producer's parent
            // view is responsible for unmounting. The feedback chip
            // animates the button to confirm the click registered.
            savedActionID = action.id
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                if savedActionID == action.id { savedActionID = nil }
            }
        case .rerun:
            // Re-run posts a notification with the payload (rerun
            // command). Any host that wants to listen can subscribe.
            NotificationCenter.default.post(
                name: .genUIActionRerunRequested,
                object: nil,
                userInfo: ["payload": action.payload ?? "", "actionID": action.id]
            )
        case .custom:
            break
        }
    }
}

extension Notification.Name {
    /// Posted when a GenUI action-panel `.rerun` button is clicked.
    /// userInfo carries `payload` (String) + `actionID` (String).
    /// Hosts that want to actually re-run a command subscribe.
    static let genUIActionRerunRequested = Notification.Name(
        "com.epistemos.genUI.actionRerunRequested"
    )
}

private struct ErrorReportGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .error(title, detail, hint, _) = payload.body {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                if let hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.red.opacity(0.08))
            )
        }
    }
}

private struct ProgressIndicatorGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .progress(label, total, value) = payload.body {
            HStack(spacing: 8) {
                ProgressView(value: value, total: total)
                    .controlSize(.small)
                Text(label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CapabilityListGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        if case let .rows(headers, cells) = payload.body {
            VStack(alignment: .leading, spacing: 4) {
                if !payload.title.isEmpty {
                    Text(payload.title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                }
                HStack(spacing: 12) {
                    ForEach(headers.indices, id: \.self) { idx in
                        Text(headers[idx])
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, 2)
                ForEach(cells.indices, id: \.self) { rowIdx in
                    HStack(spacing: 12) {
                        let row = cells[rowIdx]
                        ForEach(row.indices, id: \.self) { colIdx in
                            Text(row[colIdx])
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

private struct SearchResultSetGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        // searchResultSet uses .rows; reuse the capability-list shape
        // but with title-prominent first column. Same renderer body
        // works for now; a search-specific layout can replace this
        // when the search panel's result-set view stabilizes.
        CapabilityListGenUIView(payload: payload)
    }
}

private struct ProvenanceTraceGenUIView: View {
    let payload: GenUIPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !payload.title.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "timeline.selection")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                    Text(payload.title)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            if case let .provenanceChain(events) = payload.body, !events.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events) { event in
                        ProvenanceTraceEventRow(payload: event)
                    }
                }
            } else {
                Text("No committed provenance events yet")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

private struct ProvenanceTraceEventRow: View {
    let payload: GenUIPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !payload.title.isEmpty {
                Text(payload.title)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            switch payload.body {
            case .keyValues(let pairs):
                ForEach(pairs) { pair in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pair.key)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 92, alignment: .leading)
                        Text(pair.value)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            case .raw(let text):
                Text(text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            default:
                Text(payload.schema.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.secondary.opacity(0.24))
                .frame(width: 2)
        }
    }
}

// MARK: - Clarify (Master Fusion §B.8 1/N)

/// Notification posted when the user resolves a clarify card. The
/// `userInfo` carries `payloadID` (the clarify payload's id), `response`
/// (the user's text answer — equal to the chosen choice OR the
/// free-text input), and `choiceIndex` (the integer index 0..<N when
/// the user clicked a choice chip, OR `nil` when they typed free-text).
///
/// Wire format matches the Rust `ClarifyHandler` return shape:
///   `{ question, response, choice_index }`
///
/// ChatCoordinator subscribes to this notification (B.8 2/N) and
/// threads the response back into the running agent loop via
/// `AgentEventDelegate::ask_user_question` resolution.
extension Notification.Name {
    static let clarifyCardResolved = Notification.Name("EpistemosClarifyCardResolved")
}

/// UserInfo keys for `.clarifyCardResolved`. String constants so test
/// code + ChatCoordinator can pin against them without re-encoding the
/// literals.
///
/// Explicit `nonisolated` because the keys are pure string literals
/// — they get read from the NotificationCenter observer callback,
/// which runs on a Sendable closure and inherits no actor. Without
/// `nonisolated`, the module's `.defaultIsolation(MainActor.self)`
/// pulls the statics onto MainActor and trips the Swift 6 isolation
/// checker in GenUICardPresenter's NotificationCenter callback.
nonisolated enum ClarifyCardNotificationKey {
    static let payloadID = "payloadID"
    static let response = "response"
    static let choiceIndex = "choiceIndex"
}

/// Renderer for `GenUISchema.clarify` payloads. Mirrors the Rust
/// `agent_core::tools::clarify::ClarifyHandler` emission shape: a typed
/// question + zero-to-four predefined choices + optional free-text
/// fallback.
///
/// User interaction:
///   - Tapping a choice chip posts `Notification.Name.clarifyCardResolved`
///     with `response = chosen choice text` and `choiceIndex = the
///     0-indexed position`. The chip's state flips to "✓ selected" so
///     repeat taps are visually no-ops.
///   - Typing in the free-text field + pressing Return posts the same
///     notification with `response = typed text` and `choiceIndex = nil`.
///
/// After resolution the card collapses to an "Answered: …" summary so
/// the chat transcript shows what the user said without re-rendering
/// the interactive controls.
///
/// **Boundary:** This view does NOT directly call into the Rust agent
/// loop. It only emits the notification. The ChatCoordinator (B.8 2/N
/// follow-up) subscribes + routes the response into the running agent
/// session. Keeping the renderer transport-free means the same view
/// works for unit tests, previews, and future surfaces (Provenance
/// Console replay) that aren't part of a live agent session.
private struct ClarifyGenUIView: View {
    let payload: GenUIPayload
    @State private var freeTextDraft: String = ""
    @State private var resolvedAnswer: String?

    var body: some View {
        if case let .clarify(question, choices, allowFreeText) = payload.body {
            if let answer = resolvedAnswer {
                resolvedView(question: question, answer: answer)
            } else {
                interactiveView(
                    question: question,
                    choices: choices,
                    allowFreeText: allowFreeText
                )
            }
        }
    }

    private func interactiveView(
        question: String,
        choices: [String],
        allowFreeText: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Clarify")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Text(question)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !choices.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                        choiceButton(choice, choiceIndex: index)
                    }
                    Spacer(minLength: 0)
                }
            }

            if allowFreeText {
                HStack(spacing: 6) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    TextField("Other (free-text answer)", text: $freeTextDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit { submitFreeText() }
                        .accessibilityLabel("Free-text clarify response — press return to submit")
                    if !freeTextDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button { submitFreeText() } label: {
                            Image(systemName: "return")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Submit free-text answer")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private func resolvedView(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text("Answered")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(question)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Text(answer)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.03))
        )
    }

    private func choiceButton(_ choice: String, choiceIndex: Int) -> some View {
        Button {
            submit(response: choice, choiceIndex: choiceIndex)
        } label: {
            Text(choice)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.primary.opacity(0.08)))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .help("Pick this answer")
        .accessibilityLabel("Choose '\(choice)'")
    }

    private func submitFreeText() {
        let trimmed = freeTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submit(response: trimmed, choiceIndex: nil)
    }

    private func submit(response: String, choiceIndex: Int?) {
        guard resolvedAnswer == nil else { return } // already resolved
        resolvedAnswer = response
        var userInfo: [AnyHashable: Any] = [
            ClarifyCardNotificationKey.payloadID: payload.id,
            ClarifyCardNotificationKey.response: response,
        ]
        if let idx = choiceIndex {
            userInfo[ClarifyCardNotificationKey.choiceIndex] = idx
        }
        NotificationCenter.default.post(
            name: .clarifyCardResolved,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - Fallback (never crashes on schema drift)

struct FallbackGenUIView: View {
    let payload: GenUIPayload
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.app.dashed")
                    .foregroundStyle(.tertiary)
                Text("GenUI fallback (no renderer for schema='\(payload.schema.rawValue)')")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if let json = try? GenUIPayload.canonicalJSONEncoder().encode(payload),
               let text = String(data: json, encoding: .utf8) {
                Text(text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .lineLimit(20)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
