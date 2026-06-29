//
//  EditorChunkLoader.swift
//  MarkEditMac
//
//  Created by cyan on 9/2/24.
//

import WebKit
import MarkEditKit

/// URL scheme handler to load bundle chunks.
///
/// E.g., chunk-loader://chunks/index-DN_-g6jS.js
final class EditorChunkLoader: NSObject, WKURLSchemeHandler {
  static let scheme = "chunk-loader"

  func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
    guard let url = urlSchemeTask.request.url,
          let relativePath = Self.relativePath(for: url),
          let fileURL = Self.fileURL(relativePath: relativePath, lastPathComponent: url.lastPathComponent) else {
      urlSchemeTask.didFailWithError(Self.error(for: urlSchemeTask.request.url))
      return
    }

    guard let fileData = try? Data(contentsOf: fileURL) else {
      urlSchemeTask.didFailWithError(Self.error(for: url))
      return
    }

    guard let contentType = Self.mimeTypes[url.pathExtension] else {
      urlSchemeTask.didFailWithError(Self.error(for: url))
      return
    }

    let headerFields = Self.accessControl.merging(["Content-Type": contentType]) { current, _ in
      current
    }

    let response = HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: headerFields
    ) ?? URLResponse(
      url: url,
      mimeType: nil,
      expectedContentLength: 0,
      textEncodingName: nil
    )

    Logger.log(.info, "[\(Self.scheme)] Successfully loaded: \(url)")
    urlSchemeTask.didReceive(response)
    urlSchemeTask.didReceive(fileData)
    urlSchemeTask.didFinish()
  }

  func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    // no-op
  }
}

// MARK: - Private

private extension EditorChunkLoader {
  static func relativePath(for url: URL) -> String? {
    guard let host = url.host(), host == "chunks" else { return nil }
    let pathComponents = url.pathComponents.filter { $0 != "/" }
    guard !pathComponents.isEmpty,
          pathComponents.allSatisfy(isSafeRelativePathComponent) else { return nil }
    return ([host] + pathComponents).joined(separator: "/")
  }

  static func fileURL(relativePath: String, lastPathComponent: String) -> URL? {
    let candidates = [
      Bundle.main.url(forResource: relativePath, withExtension: nil),
      Bundle.main.url(forResource: lastPathComponent, withExtension: nil),
      Bundle.main.resourceURL?
        .appendingPathComponent("CoreEditor", isDirectory: true)
        .appendingPathComponent(relativePath),
      Bundle.main.resourceURL?
        .appendingPathComponent("CoreEditor", isDirectory: true)
        .appendingPathComponent(lastPathComponent),
      Bundle.main.resourceURL?.appendingPathComponent(relativePath),
      Bundle.main.resourceURL?.appendingPathComponent(lastPathComponent),
    ].compactMap { $0?.resolvingSymlinksInPath().standardizedFileURL }

    return candidates.first(where: isRegularFile)
  }

  static func isSafeRelativePathComponent(_ component: String) -> Bool {
    !component.isEmpty &&
      component != "." &&
      component != ".." &&
      !component.contains("\\")
  }

  static func isRegularFile(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
  }

  static func error(for url: URL?) -> NSError {
    NSError(
      domain: "EditorChunkLoader",
      code: 1,
      userInfo: [NSURLErrorKey: url?.absoluteString ?? ""]
    )
  }

  static let mimeTypes = [
    "js": "text/javascript",
    "css": "text/css",
    "woff2": "font/woff2",
  ]

  static let accessControl = [
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Headers": "*",
    "Access-Control-Allow-Methods": "*",
    "Access-Control-Allow-Origin": "*",
  ]
}
