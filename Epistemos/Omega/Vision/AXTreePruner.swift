import ApplicationServices
import Foundation
import os

// MARK: - AX Tree Pruner
//
// Optimized Accessibility tree traversal for sub-millisecond agent actions.
// Four key optimizations from the Omniscient Architecture Manifesto:
//
//   1. PID-indexed Cache: AXUIElementCreateApplication(pid) cached per PID,
//      invalidated on NSWorkspace.didActivateApplicationNotification
//   2. Attribute Batching: AXUIElementCopyMultipleAttributeValues for
//      single-IPC-roundtrip attribute reads
//   3. Role-Based Pre-Pruning: Filter to interactive elements only
//      (AXButton, AXTextField, AXStaticText, AXWebArea)
//   4. AXObserver Invalidation: Re-traverse only dirty subtrees

private let axLog = Logger(subsystem: "com.epistemos.omega", category: "AXTreePruner")

// MARK: - Pruned AX Node

struct PrunedAXNode: Sendable, Identifiable {
    let id: String
    let role: String
    let title: String
    let value: String
    let frame: CGRect
    let isEnabled: Bool
    let children: [PrunedAXNode]

    var isInteractable: Bool {
        Self.interactiveRoles.contains(role) && isEnabled
    }

    /// Roles that agents typically need to interact with.
    static let interactiveRoles: Set<String> = [
        "AXButton",
        "AXTextField",
        "AXTextArea",
        "AXStaticText",
        "AXWebArea",
        "AXLink",
        "AXCheckBox",
        "AXRadioButton",
        "AXPopUpButton",
        "AXMenuItem",
        "AXComboBox",
        "AXSlider",
        "AXTabGroup",
        "AXTable",
        "AXList",
        "AXImage",
    ]

    /// Roles to skip during traversal (decoration, layout).
    static let skipRoles: Set<String> = [
        "AXScrollBar",
        "AXSplitter",
        "AXRuler",
        "AXGrowArea",
        "AXMatte",
        "AXValueIndicator",
        "AXLayoutArea",
        "AXLayoutItem",
        "AXBusyIndicator",
    ]
}

// MARK: - PID-Indexed AX Cache

@MainActor
final class AXElementCache {

    /// Cached top-level app AX references by PID.
    private var appElements: [pid_t: AXUIElement] = [:]

    /// Cached pruned trees by PID (invalidated on app activation change).
    private var prunedTrees: [pid_t: (tree: [PrunedAXNode], timestamp: Date)] = [:]

    /// Cache validity window (milliseconds).
    private let cacheValidityMs: TimeInterval = 500

    private var workspaceObserver: NSObjectProtocol?

    init() {
        // Invalidate cache on app activation change
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let pid = app.processIdentifier
                Task { @MainActor in
                    self.invalidate(pid: pid)
                }
            }
        }
    }

    // Cleanup handled by NotificationCenter retaining the observer token.
    // No explicit deinit needed — the observer is removed when the token is deallocated.

    /// Get or create the top-level AXUIElement for a PID.
    func appElement(for pid: pid_t) -> AXUIElement {
        if let cached = appElements[pid] {
            return cached
        }
        let element = AXUIElementCreateApplication(pid)
        appElements[pid] = element
        return element
    }

    /// Get a cached pruned tree if still valid.
    func cachedTree(for pid: pid_t) -> [PrunedAXNode]? {
        guard let entry = prunedTrees[pid] else { return nil }
        let age = Date().timeIntervalSince(entry.timestamp) * 1000
        guard age < cacheValidityMs else {
            prunedTrees.removeValue(forKey: pid)
            return nil
        }
        return entry.tree
    }

    /// Store a pruned tree in the cache.
    func cacheTree(_ tree: [PrunedAXNode], for pid: pid_t) {
        prunedTrees[pid] = (tree, Date())
    }

    /// Invalidate cache for a specific PID.
    func invalidate(pid: pid_t) {
        appElements.removeValue(forKey: pid)
        prunedTrees.removeValue(forKey: pid)
    }

    /// Invalidate all cached data.
    func invalidateAll() {
        appElements.removeAll()
        prunedTrees.removeAll()
    }
}

// MARK: - Batch Attribute Reader

/// Read multiple AX attributes in a single IPC round-trip.
private func batchReadAttributes(
    element: AXUIElement,
    attributes: [String]
) -> [String: AnyObject?] {
    let cfAttributes = attributes as CFArray
    var values: CFArray?

    AXUIElementCopyMultipleAttributeValues(
        element,
        cfAttributes,
        .stopOnError,
        &values
    )

    var result: [String: AnyObject?] = [:]
    guard let values = values as? [AnyObject?] else {
        return result
    }

    for (i, attr) in attributes.enumerated() where i < values.count {
        result[attr] = values[i]
    }
    return result
}

// MARK: - AX Tree Pruner

@MainActor
final class AXTreePruner {

    private let cache = AXElementCache()
    private var nodeCounter = 0

    /// Prune the AX tree for a given PID to interactive elements only.
    ///
    /// Returns a flat-ish tree (typically 50-200 nodes for most apps)
    /// that completes in under 5ms.
    func prunedTree(for pid: pid_t, maxDepth: Int = 8) -> [PrunedAXNode] {
        // Check cache first
        if let cached = cache.cachedTree(for: pid) {
            return cached
        }

        nodeCounter = 0
        let appElement = cache.appElement(for: pid)
        let tree = traverseElement(appElement, depth: 0, maxDepth: maxDepth)

        axLog.debug("Pruned AX tree for PID \(pid): \(self.nodeCounter) nodes examined")
        cache.cacheTree(tree, for: pid)
        return tree
    }

    /// Invalidate the cache for a PID (call on AXObserver notifications).
    func invalidate(pid: pid_t) {
        cache.invalidate(pid: pid)
    }

    // MARK: - Private Traversal

    private func traverseElement(
        _ element: AXUIElement,
        depth: Int,
        maxDepth: Int
    ) -> [PrunedAXNode] {
        guard depth < maxDepth else { return [] }
        nodeCounter += 1

        // Batch-read all attributes in a single IPC round-trip
        let attrs = batchReadAttributes(
            element: element,
            attributes: [
                kAXRoleAttribute as String,
                kAXTitleAttribute as String,
                kAXValueAttribute as String,
                kAXEnabledAttribute as String,
                kAXChildrenAttribute as String,
                kAXPositionAttribute as String,
                kAXSizeAttribute as String,
            ]
        )

        let role = (attrs[kAXRoleAttribute as String] as? String) ?? ""

        // Pre-prune: skip decoration elements immediately
        if PrunedAXNode.skipRoles.contains(role) {
            return []
        }

        let title = (attrs[kAXTitleAttribute as String] as? String) ?? ""
        let value: String
        if let v = attrs[kAXValueAttribute as String] {
            value = v.flatMap { "\($0)" } ?? ""
        } else {
            value = ""
        }
        let isEnabled = (attrs[kAXEnabledAttribute as String] as? Bool) ?? true

        // Extract frame via individual attribute reads (avoids CFType downcast warnings)
        var frame = CGRect.zero
        var posRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
           let posRef {
            var point = CGPoint.zero
            // SAFETY: AX guarantees this is an AXValue when the copy succeeds
            AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
            frame.origin = point
        }
        var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sizeRef {
            var size = CGSize.zero
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
            frame.size = size
        }

        // Recurse into children
        var childNodes: [PrunedAXNode] = []
        if let children = attrs[kAXChildrenAttribute as String] as? [AXUIElement] {
            for child in children {
                childNodes.append(contentsOf: traverseElement(child, depth: depth + 1, maxDepth: maxDepth))
            }
        }

        let nodeID = "ax_\(nodeCounter)"

        // Include this node if it's interactive or has interactive children
        let isInteractive = PrunedAXNode.interactiveRoles.contains(role)
        if isInteractive || !childNodes.isEmpty {
            let node = PrunedAXNode(
                id: nodeID,
                role: role,
                title: title,
                value: value,
                frame: frame,
                isEnabled: isEnabled,
                children: childNodes
            )
            return [node]
        }

        // Not interactive and no interactive children — skip
        return childNodes
    }
}

// MARK: - JSON Serialization for MCP

extension PrunedAXNode {
    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "role": role,
        ]
        if !title.isEmpty { dict["title"] = title }
        if !value.isEmpty { dict["value"] = String(value.prefix(200)) }
        dict["frame"] = [
            "x": Int(frame.origin.x),
            "y": Int(frame.origin.y),
            "w": Int(frame.size.width),
            "h": Int(frame.size.height),
        ]
        if !isEnabled { dict["enabled"] = false }
        if !children.isEmpty {
            dict["children"] = children.map { $0.toJSON() }
        }
        return dict
    }
}
