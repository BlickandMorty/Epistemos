import Foundation
import AXorcist
import AppKit

// MARK: - AXorcist Bridge

/// AXorcist-powered accessibility bridge for Epistemos Omega.
///
/// Replaces omega-ax Rust FFI for AX tree queries with AXorcist's native Swift API.
/// omega-ax is retained for CGEvent input simulation (simulateClick, simulateTypeText,
/// simulateKeyPress, clickElementByName, runShortcutByName).
///
/// AXorcist provides:
/// - Native Swift AX tree walking via Element type with typed properties
/// - Fuzzy element matching (contains, regex, prefix, suffix, containsAny)
/// - Direct action execution (press, pick, showMenu, setValue)
/// - Async permission monitoring
@MainActor
final class AXorcistBridge {

    static let shared = AXorcistBridge()

    private let axorcist = AXorcist.shared

    // MARK: - Permissions

    /// Check if accessibility permissions are granted.
    /// Uses cached result to avoid blocking main thread on every access.
    /// Refresh via `refreshAccessibilityPermissions()`.
    private(set) var hasAccessibilityPermissions: Bool = false

    /// Refresh the cached accessibility permission status off the main thread.
    func refreshAccessibilityPermissions() async {
        let trusted = await Task.detached(priority: .userInitiated) {
            AXIsProcessTrusted()
        }.value
        hasAccessibilityPermissions = trusted
    }

    // MARK: - Tree Walking (omega-ax compatible JSON)

    /// Walk the full AX tree for a process using AXorcist's Element API.
    /// Returns JSON in the same format as omega-ax's walkAxTreeJson(pid:)
    /// for backward compatibility with Screen2AXFusion and AXSemanticSelector.
    func walkTree(pid: pid_t) -> String {
        let appRef = AXUIElementCreateApplication(pid)
        let root = Element(appRef)

        var elements: [[String: Any]] = []
        walkElement(root, into: &elements, depth: 0, parentIndex: nil)

        let appName = NSWorkspace.shared.runningApplications
            .first { $0.processIdentifier == pid }?
            .localizedName ?? "Unknown"

        let interactiveCount = elements.filter { ($0["is_interactive"] as? Bool) == true }.count

        let tree: [String: Any] = [
            "app_name": appName,
            "app_pid": Int(pid),
            "elements": elements,
            "is_sparse": interactiveCount < sparseThreshold,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: tree),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"elements\":[]}"
        }
        return json
    }

    private let sparseThreshold = 10

    // MARK: - Fuzzy Element Queries

    /// Find elements using AXorcist's fuzzy matching via command system.
    func findElements(
        bundleID: String,
        role: String? = nil,
        title: String? = nil,
        titleMatch: JSONPathHintComponent.MatchType = .contains,
        maxResults: Int = 20
    ) -> AXResponse {
        var criteria: [Criterion] = []

        if let role {
            criteria.append(Criterion(attribute: "AXRole", value: role))
        }
        if let title {
            criteria.append(Criterion(attribute: "AXTitle", value: title, matchType: titleMatch))
        }

        let query = QueryCommand(
            appIdentifier: bundleID,
            locator: Locator(criteria: criteria)
        )

        let envelope = AXCommandEnvelope(
            commandID: UUID().uuidString,
            command: .query(query)
        )

        return axorcist.runCommand(envelope)
    }

    /// Collect all elements from an app, filtered by criteria.
    func collectAll(
        bundleID: String,
        maxDepth: Int = 10,
        filterCriteria: [String: String]? = nil
    ) -> AXResponse {
        let cmd = CollectAllCommand(
            appIdentifier: bundleID,
            maxDepth: maxDepth,
            filterCriteria: filterCriteria
        )

        let envelope = AXCommandEnvelope(
            commandID: UUID().uuidString,
            command: .collectAll(cmd)
        )

        return axorcist.runCommand(envelope)
    }

    // MARK: - Direct Element Actions

    /// Find and press an element by title using AXorcist fuzzy match.
    func pressElement(bundleID: String, title: String) -> AXResponse {
        let cmd = PerformActionCommand(
            appIdentifier: bundleID,
            locator: Locator(criteria: [
                Criterion(attribute: "AXTitle", value: title, matchType: .contains),
            ]),
            action: "AXPress"
        )

        let envelope = AXCommandEnvelope(
            commandID: UUID().uuidString,
            command: .performAction(cmd)
        )
        return axorcist.runCommand(envelope)
    }

    /// Get the currently focused element of the frontmost application.
    func getFocusedElement(bundleID: String? = nil) -> AXResponse {
        let cmd = GetFocusedElementCommand(
            appIdentifier: bundleID
        )

        let envelope = AXCommandEnvelope(
            commandID: UUID().uuidString,
            command: .getFocusedElement(cmd)
        )
        return axorcist.runCommand(envelope)
    }

    /// Type text into the focused element using AXorcist's setFocusedValue.
    func setFocusedValue(_ text: String, bundleID: String) -> AXResponse {
        let cmd = SetFocusedValueCommand(
            appIdentifier: bundleID,
            locator: Locator(criteria: []),
            value: text
        )

        let envelope = AXCommandEnvelope(
            commandID: UUID().uuidString,
            command: .setFocusedValue(cmd)
        )
        return axorcist.runCommand(envelope)
    }

    // MARK: - Private Tree Walking

    private static let interactiveRoles: Set<String> = [
        "AXButton", "AXLink", "AXTextField", "AXTextArea", "AXCheckBox",
        "AXRadioButton", "AXPopUpButton", "AXComboBox", "AXSlider",
        "AXTab", "AXMenuItem", "AXMenuButton", "AXDisclosureTriangle",
        "AXIncrementor", "AXColorWell", "AXSegmentedControl",
        "AXMenuBarItem", "AXToolbar",
    ]

    /// Recursively walk an Element tree, building omega-ax-compatible JSON array.
    private func walkElement(
        _ element: Element,
        into elements: inout [[String: Any]],
        depth: Int,
        parentIndex: Int?
    ) {
        guard depth <= 10 else { return }
        guard elements.count < 2048 else { return }

        let role = element.role() ?? ""
        let title = element.title() ?? ""

        var entry: [String: Any] = [
            "role": role,
            "title": title,
            "is_interactive": Self.interactiveRoles.contains(role),
        ]

        if let desc = element.descriptionText(), !desc.isEmpty {
            entry["description"] = desc
        }

        if let val = element.value() {
            entry["value"] = "\(val)"
        }

        if let pos = element.position() {
            entry["position_x"] = Double(pos.x)
            entry["position_y"] = Double(pos.y)
        }

        if let sz = element.size() {
            entry["size_width"] = Double(sz.width)
            entry["size_height"] = Double(sz.height)
        }

        if let parentIndex {
            entry["parent_index"] = parentIndex
        }

        let currentIndex = elements.count
        elements.append(entry)

        guard let children = element.children() else { return }
        for child in children {
            walkElement(child, into: &elements, depth: depth + 1, parentIndex: currentIndex)
        }
    }
}
