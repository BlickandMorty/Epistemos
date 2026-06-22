//  EpistemosOsaurusChatHost.swift
//  OsaurusCore — EPISTEMOS HOST SEAM
//
//  Owner directive 2026-06-22 ("ACT = OSAURUS IS THE CHAT"): the Epistemos
//  "act" surface must BE the real Osaurus chat UI — the genuine vendored
//  surface, not the old Epistemos `ChatView` with an engine swap behind a
//  toggle. The Osaurus `ChatView` / `ChatWindowState` are `internal` to this
//  package, so the Epistemos module cannot reference them directly even though
//  it links `OsaurusCore`.
//
//  This file is the ONE public entry point that closes that gap. It is purely
//  additive: it modifies no existing Osaurus type and changes no Osaurus
//  behaviour. It owns a stable `ChatWindowState` (held as `@StateObject` so the
//  window/session survive re-renders — the documented SwiftUI ownership rule
//  for `ObservedObject`-backed `ChatView`) and renders the genuine Osaurus
//  `ChatView`. Epistemos's `RootView` mounts `EpistemosOsaurusChatHost()` for
//  the act surface; theme reskin (Epistemos cream palette via a
//  `ThemeProtocol` adapter) and session/vault/Eidos bridging layer on top of
//  this seam in follow-up increments.

import SwiftUI

/// Public host that mounts the real Osaurus chat surface inside the Epistemos
/// app. The hosted view is the genuine Osaurus `ChatView` — same code that
/// runs in standalone Osaurus — so behaviour matches the working app rather
/// than a partial re-integration.
public struct EpistemosOsaurusChatHost: View {
    /// Owned so the window/session state is stable across SwiftUI re-renders.
    /// `ChatView(windowState:)` wraps this in an `ObservedObject`; the owner of
    /// the lifetime must therefore be a `@StateObject` here, not a freshly
    /// constructed value on each `body` evaluation.
    @StateObject private var windowState: ChatWindowState

    /// - Parameters:
    ///   - windowId: stable identity for this chat window. Defaults to a fresh
    ///     UUID; pass a persisted id to reattach an existing window.
    ///   - agentId: the agent to bind. Defaults to Osaurus's built-in default
    ///     agent (`Agent.defaultId`).
    public init(windowId: UUID = UUID(), agentId: UUID? = nil) {
        _windowState = StateObject(
            wrappedValue: ChatWindowState(windowId: windowId, agentId: agentId ?? Agent.defaultId)
        )
    }

    public var body: some View {
        ChatView(windowState: windowState)
    }
}
