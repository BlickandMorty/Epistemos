//
//  NativeActLandingView.swift
//  Epistemos — ACT ARCHITECTURE PIVOT, THE ONE CRISP TARGET (owner P0 §2048)
//
//  The act fresh-launch screen: a NATIVE Epistemos landing rendered cream/monospace
//  BY CONSTRUCTION (no theme cascade). Crisp target: landing in native chrome
//  (cream + toolbar + pill), CLICK-ANYWHERE → ACT (no search page). Replaces the
//  dark/no-chrome LandingView on the act surface; the pivot's "fresh native views"
//  (§2029) — not the old LandingView's search-first flow.
//
//  Pro / direct-distribution only.

#if !EPISTEMOS_APP_STORE

import SwiftUI

struct NativeActLandingView: View {
    /// Click-anywhere → enter the native act chat (RootView sets actEntered = true).
    var onEnter: () -> Void = {}

    private let cream = Color(.sRGB, red: 0xFB / 255.0, green: 0xFA / 255.0, blue: 0xF5 / 255.0, opacity: 1)
    private let surface2 = Color(.sRGB, red: 0xF4 / 255.0, green: 0xF3 / 255.0, blue: 0xEE / 255.0, opacity: 1)
    private let ink = Color(.sRGB, red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0, opacity: 1)
    private let muted = Color(.sRGB, red: 0x6E / 255.0, green: 0x6E / 255.0, blue: 0x73 / 255.0, opacity: 1)

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            VStack(spacing: 0) {
                // native toolbar (cream + pill — crisp target #1)
                HStack(spacing: 10) {
                    Text("act")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(surface2, in: Capsule())
                        .overlay(Capsule().stroke(ink.opacity(0.12), lineWidth: 1))
                        .accessibilityIdentifier("act.landing.pill")
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 12)

                Spacer()
                VStack(spacing: 14) {
                    Text("Epistemos")
                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ink)
                    Text("click anywhere to begin")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(muted)
                }
                Spacer()
                Text("act → engine in-process")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(muted)
                    .padding(.bottom, 20)
            }
        }
        // CLICK-ANYWHERE → ACT (crisp target #2: replaces click→search). The whole
        // surface is the entry gesture; no search page.
        .contentShape(Rectangle())
        .onTapGesture { onEnter() }
        .accessibilityIdentifier("act.landing")
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Begin act")
    }
}

#endif
