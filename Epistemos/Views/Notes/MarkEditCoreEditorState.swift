import Foundation
import MarkEditCore

struct MarkEditCoreEditorState: Equatable {
    let text: String
    let mode: MarkEditCoreEditorMode
    let themeName: String
    let themePalette: MarkEditCoreEditorThemePalette
    let fontFace: WebFontFace
    let fontSize: Double
    let lineHeight: Double
    let wrapLines: Bool
    let showLineNumbers: Bool
    let showInvisibles: Bool
    let useSpaces: Bool
    let tabWidth: Int
    let isEditable: Bool

    func resetMessageJSON(documentChanged: Bool) -> String? {
        MarkEditCoreEditorResetMessage(
            text: text,
            selectionRange: nil,
            documentChanged: documentChanged
        ).jsonString
    }

    var configJSON: String? {
        MarkEditCoreEditorConfig(
            text: text,
            theme: themeName,
            fontFace: fontFace,
            fontSize: fontSize,
            showLineNumbers: showLineNumbers,
            showActiveLineIndicator: true,
            invisiblesBehavior: showInvisibles ? "always" : "never",
            readOnlyMode: !isEditable,
            typewriterMode: false,
            focusMode: false,
            lineWrapping: wrapLines,
            lineHeight: lineHeight,
            suggestWhileTyping: false,
            standardDirectories: [:],
            runtimeInfo: .current,
            defaultLineBreak: "\n",
            tabKeyBehavior: tabKeyBehavior,
            indentUnit: indentUnit,
            localizable: nil,
            autoCharacterPairs: true,
            indentBehavior: "line",
            headerFontSizeDiffs: nil,
            visibleWhitespaceCharacter: nil,
            visibleLineBreakCharacter: nil,
            searchNormalizers: nil,
            epistemosMode: mode.configMode,
            epistemosCodeLanguage: mode.configCodeLanguage
        ).jsonString
    }

    func replacingText(_ nextText: String) -> MarkEditCoreEditorState {
        MarkEditCoreEditorState(
            text: nextText,
            mode: mode,
            themeName: themeName,
            themePalette: themePalette,
            fontFace: fontFace,
            fontSize: fontSize,
            lineHeight: lineHeight,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            isEditable: isEditable
        )
    }

    func replacingTheme(
        name nextThemeName: String,
        palette nextThemePalette: MarkEditCoreEditorThemePalette
    ) -> MarkEditCoreEditorState {
        MarkEditCoreEditorState(
            text: text,
            mode: mode,
            themeName: nextThemeName,
            themePalette: nextThemePalette,
            fontFace: fontFace,
            fontSize: fontSize,
            lineHeight: lineHeight,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            isEditable: isEditable
        )
    }

    func replacingEditable(_ nextIsEditable: Bool) -> MarkEditCoreEditorState {
        MarkEditCoreEditorState(
            text: text,
            mode: mode,
            themeName: themeName,
            themePalette: themePalette,
            fontFace: fontFace,
            fontSize: fontSize,
            lineHeight: lineHeight,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            isEditable: nextIsEditable
        )
    }

    func replacingLineWrapping(_ nextLineWrapping: Bool) -> MarkEditCoreEditorState {
        MarkEditCoreEditorState(
            text: text,
            mode: mode,
            themeName: themeName,
            themePalette: themePalette,
            fontFace: fontFace,
            fontSize: fontSize,
            lineHeight: lineHeight,
            wrapLines: nextLineWrapping,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            isEditable: isEditable
        )
    }

    // `themeName`, `isEditable`, and `wrapLines` are intentionally excluded here. A theme flip used to
    // force a full `loadEditor` reload, which re-embeds the last-synced text
    // and drops any keystroke typed inside the ~250ms reload window (plus a
    // blank flash). Lease handoffs had the same problem for read-only changes.
    // The coordinator now pushes all three through live CoreEditor config bridges.
    func requiresReload(comparedTo other: MarkEditCoreEditorState) -> Bool {
        mode != other.mode ||
            fontFace != other.fontFace ||
            fontSize != other.fontSize ||
            lineHeight != other.lineHeight ||
            showLineNumbers != other.showLineNumbers ||
            showInvisibles != other.showInvisibles ||
            useSpaces != other.useSpaces ||
            clampedTabWidth != other.clampedTabWidth
    }

    private var clampedTabWidth: Int {
        max(1, min(tabWidth, 8))
    }

    private var indentUnit: String {
        useSpaces ? String(repeating: " ", count: clampedTabWidth) : "\t"
    }

    private var tabKeyBehavior: Int {
        guard useSpaces else { return 0 }
        switch clampedTabWidth {
        case 2:
            return 1
        case 4:
            return 2
        default:
            return 3
        }
    }
}

private struct MarkEditCoreEditorConfig: Encodable {
    let text: String
    let theme: String
    let fontFace: WebFontFace
    let fontSize: Double
    let showLineNumbers: Bool
    let showActiveLineIndicator: Bool
    let invisiblesBehavior: String
    let readOnlyMode: Bool
    let typewriterMode: Bool
    let focusMode: Bool
    let lineWrapping: Bool
    let lineHeight: Double
    let suggestWhileTyping: Bool
    let standardDirectories: [String: String]
    let runtimeInfo: MarkEditCoreEditorRuntimeInfo?
    let defaultLineBreak: String?
    let tabKeyBehavior: Int?
    let indentUnit: String?
    let localizable: [String: String]?
    let autoCharacterPairs: Bool
    let indentBehavior: String
    let headerFontSizeDiffs: [Double]?
    let visibleWhitespaceCharacter: String?
    let visibleLineBreakCharacter: String?
    let searchNormalizers: [String: String]?
    let epistemosMode: String
    let epistemosCodeLanguage: String?
}

private struct MarkEditCoreEditorRuntimeInfo: Encodable {
    let appVersion: String
    let appBuild: String
    let osVersion: String
    let webkitVersion: String

    static var current: MarkEditCoreEditorRuntimeInfo {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return MarkEditCoreEditorRuntimeInfo(
            appVersion: version,
            appBuild: build,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            webkitVersion: ""
        )
    }
}

private struct MarkEditCoreEditorSelectionRange: Encodable {
    let anchor: Int
    let head: Int
}

private struct MarkEditCoreEditorResetMessage: Encodable {
    let text: String
    let selectionRange: MarkEditCoreEditorSelectionRange?
    let documentChanged: Bool
}

private extension Encodable {
    var jsonString: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
