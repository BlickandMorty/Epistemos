import SwiftUI

private enum GooseNativePromptPanelBounds {
    static let maxPermissionOptions = 8
    static let maxPromptTitleCharacters = 160
    static let maxPromptSubtitleCharacters = 240
    static let maxPermissionOptionNameCharacters = 80
    static let maxElicitationMessageCharacters = 240
    static let maxElicitationInputCharacters = 4_096

    static func text(_ value: String?, fallback: String, maxCharacters: Int) -> String {
        let trimmed = (value ?? fallback).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty ? fallback : trimmed
        return String(normalized.prefix(maxCharacters))
    }
}

private func gooseNativePromptPanelShadow(for theme: EpistemosTheme) -> Color {
    let shadowBase = theme.isDark ? theme.resolved.background.color : theme.resolved.foreground.color
    return shadowBase.opacity(theme.isDark ? 0.20 : 0.08)
}

struct GooseACPPermissionPanel: View {
    let promptID: String
    let request: GooseACPRequestPermissionRequest
    let theme: EpistemosTheme
    let onDecision: (String?) -> Void

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let controlShape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(promptTitle)
                        .font(GooseSurfaceStyle.bodyFont(13, weight: .semibold))
                        .foregroundStyle(theme.resolved.foreground.color)
                    Text(promptSubtitle)
                        .font(GooseSurfaceStyle.bodyFont(11))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: permissionButtonColumns, alignment: .leading, spacing: 8) {
                ForEach(boundedOptions, id: \.optionId) { option in
                    Button { onDecision(option.optionId) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.kind.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(optionName(option))
                                .font(GooseSurfaceStyle.bodyFont(11, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(permissionOptionForeground(option.kind))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                    .background {
                        controlShape.fill(permissionOptionFill(option.kind))
                    }
                    .help(optionName(option))
                }

                Button { onDecision(nil) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.plain)
                .background {
                    controlShape.fill(neutralControlFill)
                }
                .help("Cancel")
            }
        }
        .padding(14)
        .frame(width: 460, alignment: .leading)
        .background {
            panelShape.fill(panelFill)
        }
        .clipShape(panelShape)
        .shadow(color: gooseNativePromptPanelShadow(for: theme), radius: 18, y: 8)
    }

    private var boundedOptions: [GooseACPPermissionOption] {
        Array(request.options.prefix(GooseNativePromptPanelBounds.maxPermissionOptions))
    }

    private var permissionButtonColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 122, maximum: 180), spacing: 8, alignment: .leading)]
    }

    private func optionName(_ option: GooseACPPermissionOption) -> String {
        GooseNativePromptPanelBounds.text(
            option.name,
            fallback: option.optionId,
            maxCharacters: GooseNativePromptPanelBounds.maxPermissionOptionNameCharacters
        )
    }

    private var neutralControlFill: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.62 : 0.68)
    }

    private var panelFill: Color {
        GooseSurfaceStyle.background(for: theme, role: .rail).opacity(theme.isDark ? 0.92 : 0.96)
    }

    private func permissionOptionForeground(_ kind: GooseACPPermissionOptionKind) -> Color {
        kind.isReject ? theme.error : theme.resolved.accent.color
    }

    private func permissionOptionFill(_ kind: GooseACPPermissionOptionKind) -> Color {
        if kind.isReject {
            theme.error.opacity(theme.isDark ? 0.18 : 0.10)
        } else {
            theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.11)
        }
    }

    private var promptTitle: String {
        GooseNativePromptPanelBounds.text(
            request.toolCall.title,
            fallback: "Tool permission",
            maxCharacters: GooseNativePromptPanelBounds.maxPromptTitleCharacters
        )
    }

    private var promptSubtitle: String {
        let tool = request.toolCall.toolCallId
        let raw: String
        if let kind = request.toolCall.kind {
            raw = "\(kind.rawValue) · \(tool)"
        } else {
            raw = tool
        }
        return GooseNativePromptPanelBounds.text(
            raw,
            fallback: "Tool call",
            maxCharacters: GooseNativePromptPanelBounds.maxPromptSubtitleCharacters
        )
    }
}

struct GooseACPElicitationPanel: View {
    enum Action {
        case accept([String: JSONValue])
        case decline
        case cancel
    }

    let promptID: String
    let request: GooseACPCreateElicitationRequest
    let fields: [GooseACPElicitationFormField]
    let theme: EpistemosTheme
    let onAction: (Action) -> Void

    @State private var textValues: [String: String]
    @State private var boolValues: [String: Bool]

    init(
        promptID: String,
        request: GooseACPCreateElicitationRequest,
        fields: [GooseACPElicitationFormField],
        theme: EpistemosTheme,
        onAction: @escaping (Action) -> Void
    ) {
        self.promptID = promptID
        self.request = request
        self.fields = fields
        self.theme = theme
        self.onAction = onAction
        _textValues = State(initialValue: Dictionary(uniqueKeysWithValues: fields.map { ($0.id, "") }))
        _boolValues = State(initialValue: Dictionary(uniqueKeysWithValues: fields.map { ($0.id, false) }))
    }

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let controlShape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(messageText)
                        .font(GooseSurfaceStyle.bodyFont(13, weight: .semibold))
                        .foregroundStyle(theme.resolved.foreground.color)
                        .lineLimit(2)
                    Text(request.mode.rawValue)
                        .font(GooseSurfaceStyle.bodyFont(11))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer(minLength: 0)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(fields) { field in
                        fieldControl(field)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 260)

            HStack(spacing: 8) {
                Button { onAction(.accept(encodedValues())) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Submit")
                            .font(GooseSurfaceStyle.bodyFont(11, weight: .semibold))
                    }
                    .foregroundStyle(theme.resolved.accent.color)
                    .frame(minHeight: 30)
                    .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .disabled(!allRequiredFilled)
                .opacity(allRequiredFilled ? 1 : 0.5)
                .help(allRequiredFilled ? "Submit" : "Fill all required (*) fields to submit")
                .background {
                    controlShape.fill(accentControlFill)
                }

                Button { onAction(.decline) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Decline")
                            .font(GooseSurfaceStyle.bodyFont(11, weight: .semibold))
                    }
                    .foregroundStyle(theme.error)
                    .frame(minHeight: 30)
                    .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
                .background {
                    controlShape.fill(dangerControlFill)
                }

                Spacer(minLength: 0)

                Button { onAction(.cancel) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .background {
                    controlShape.fill(neutralControlFill)
                }
                .help("Cancel")
            }
        }
        .padding(14)
        .frame(width: 460, alignment: .leading)
        .background {
            panelShape.fill(panelFill)
        }
        .clipShape(panelShape)
        .shadow(color: gooseNativePromptPanelShadow(for: theme), radius: 18, y: 8)
    }

    private var messageText: String {
        GooseNativePromptPanelBounds.text(
            request.message,
            fallback: "Input requested",
            maxCharacters: GooseNativePromptPanelBounds.maxElicitationMessageCharacters
        )
    }

    @ViewBuilder
    private func fieldControl(_ field: GooseACPElicitationFormField) -> some View {
        switch field.type {
        case .boolean:
            Toggle(isOn: boolBinding(field.id)) {
                Text(fieldLabel(field))
                    .font(GooseSurfaceStyle.bodyFont(11, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
            }
            .toggleStyle(.checkbox)
            .tint(theme.resolved.accent.color)
        case .string, .number, .unknown:
            VStack(alignment: .leading, spacing: 5) {
                Text(fieldLabel(field))
                    .font(GooseSurfaceStyle.bodyFont(10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                TextField("", text: textBinding(field.id))
                    .textFieldStyle(.plain)
                    .font(GooseSurfaceStyle.bodyFont(12))
                    .tint(theme.resolved.accent.color)
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.resolved.chatSurface.color.opacity(theme.isDark ? 0.70 : 0.76))
                    }
            }
        }
    }

    private var accentControlFill: Color {
        theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.11)
    }

    private var dangerControlFill: Color {
        theme.error.opacity(theme.isDark ? 0.18 : 0.10)
    }

    private var neutralControlFill: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.62 : 0.68)
    }

    private var panelFill: Color {
        GooseSurfaceStyle.background(for: theme, role: .rail).opacity(theme.isDark ? 0.92 : 0.96)
    }

    private func fieldLabel(_ field: GooseACPElicitationFormField) -> String {
        field.isRequired ? "\(field.title) *" : field.title
    }

    private func textBinding(_ id: String) -> Binding<String> {
        Binding(
            get: { textValues[id, default: ""] },
            set: {
                textValues[id] = String($0.prefix(GooseNativePromptPanelBounds.maxElicitationInputCharacters))
            }
        )
    }

    private func boolBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { boolValues[id, default: false] },
            set: { boolValues[id] = $0 }
        )
    }

    // review L4: every REQUIRED field must be non-empty before Submit is allowed (Submit was always
    // enabled, letting blank required fields through as empty strings).
    private var allRequiredFilled: Bool {
        fields.allSatisfy { field in
            guard field.isRequired else { return true }
            switch field.type {
            case .boolean:
                return true // a checkbox always carries a concrete true/false
            case .string, .number, .unknown:
                return !textValues[field.id, default: ""].trimmingCharacters(in: .whitespaces).isEmpty
            }
        }
    }

    private func encodedValues() -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for field in fields {
            switch field.type {
            case .boolean:
                result[field.id] = .bool(boolValues[field.id, default: false])
            case .number:
                // review L4: omit an empty (optional) number instead of sending `.string("")`, which
                // the server's number schema would reject. Required-empty can't reach here (Submit is
                // gated). A non-numeric non-empty value is preserved so the server can report it.
                let raw = textValues[field.id, default: ""].trimmingCharacters(in: .whitespaces)
                if raw.isEmpty { continue }
                if let intValue = Int(raw) {
                    result[field.id] = .int(intValue)
                } else if let doubleValue = Double(raw) {
                    result[field.id] = .double(doubleValue)
                } else {
                    result[field.id] = .string(raw)
                }
            case .string, .unknown:
                // omit empty optional strings rather than emitting `""`.
                let raw = textValues[field.id, default: ""]
                if raw.isEmpty { continue }
                result[field.id] = .string(raw)
            }
        }
        return result
    }
}

private extension GooseACPPermissionOptionKind {
    var iconName: String {
        switch self {
        case .allowOnce, .allowAlways:
            "checkmark"
        case .rejectOnce, .rejectAlways:
            "xmark"
        }
    }

    var isReject: Bool {
        switch self {
        case .allowOnce, .allowAlways:
            false
        case .rejectOnce, .rejectAlways:
            true
        }
    }
}
