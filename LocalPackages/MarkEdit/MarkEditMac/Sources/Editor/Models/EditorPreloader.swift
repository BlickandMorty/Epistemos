//
//  EditorPreloader.swift
//  MarkEditMac
//
//  Created by cyan on 12/15/22.
//

import AppKit
import MarkEditKit

/**
 Preloads an `EditorViewController` so the next document can open without paying the WebView load cost.
 */
@MainActor
final class EditorPreloader {
  static let shared = EditorPreloader()

  func warmUp() {
    // Start loading an editor early so prepareViewController() can return faster.
    Task {
      await prepareViewController()
    }
  }

  /// Ensure the preloaded controller has finished loading,
  /// call this before ``takeViewController()`` to guarantee readiness.
  func prepareViewController() async {
    if preloadedController == nil {
      preloadedController = EditorViewController()
    }

    await preloadedController?.waitUntilLoaded()
  }

  func takeViewController() -> EditorViewController {
    let controller = preloadedController ?? EditorViewController()
    preloadedController = EditorViewController(preloadDelay: 0.2)

    return controller
  }

  func registerExternalViewController(_ controller: EditorViewController) {
    externalControllers.add(controller)
  }

  func unregisterExternalViewController(_ controller: EditorViewController) {
    externalControllers.remove(controller)
  }

  /// All editors, whether with or without a visible window.
  func viewControllers() -> [EditorViewController] {
    let windows = NSApp.windows.compactMap {
      $0 as? EditorWindow
    }

    let controllers = windows.compactMap {
      $0.contentViewController as? EditorViewController
    }

    let externalControllers = externalControllers.allObjects
    let visibleControllers = controllers.filter { $0 !== preloadedController }
    let candidates = visibleControllers + externalControllers + [preloadedController].compactMap { $0 }
    var seen = Set<ObjectIdentifier>()

    return candidates.filter { controller in
      let identifier = ObjectIdentifier(controller)
      guard !seen.contains(identifier) else {
        return false
      }
      seen.insert(identifier)
      return true
    }
  }

  // MARK: - Private

  private var preloadedController: EditorViewController?
  private let externalControllers = NSHashTable<EditorViewController>.weakObjects()

  private init() {}
}
