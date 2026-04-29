//
//  SessionToggleChipRow.swift
//  Simulation Mode S7 — top-of-theater chip row, one chip per
//  active session (DOCTRINE §3.3.1 v1.6).
//
//  Each chip carries:
//    - lead-companion mascot pin (placeholder rounded square in
//      S7; S10 swaps in the real Tamagotchi atlas tile)
//    - truncated session label
//    - participating-companion count
//    - working-state pulse when an event for this session fired
//      in the last 30 s (per §3.3.1)
//

import SwiftUI

public struct SessionToggleChipRow: View {
    public let rooms: [Room]
    public let focusedSessionId: String?
    public let onTap: (String) -> Void

    public init(
        rooms: [Room],
        focusedSessionId: String?,
        onTap: @escaping (String) -> Void
    ) {
        self.rooms = rooms
        self.focusedSessionId = focusedSessionId
        self.onTap = onTap
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(rooms) { room in
                    chip(for: room)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
        }
    }

    @ViewBuilder
    private func chip(for room: Room) -> some View {
        let isFocused = focusedSessionId == room.sessionId
        Button {
            onTap(room.sessionId)
        } label: {
            HStack(spacing: 6) {
                mascot(for: room)
                    .frame(width: 14, height: 14)
                Text(room.sessionId)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 96)
                Text("\(room.members.count)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                if isWorking(room) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFocused
                          ? Color.accentColor.opacity(0.18)
                          : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused
                            ? Color.accentColor
                            : Color.clear,
                            lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(isFocused ? "Click to return to overview" : "Drill into \(room.sessionId)")
    }

    @ViewBuilder
    private func mascot(for room: Room) -> some View {
        // S7 placeholder — colored rounded square keyed off the
        // session id so distinct sessions render distinguishably.
        // S10 swaps in the lead companion's Tamagotchi tile.
        RoundedRectangle(cornerRadius: 3)
            .fill(stableColor(for: room.sessionId))
    }

    /// Working-state gate per §3.3.1: pulse if any event fired
    /// in the last 30 s. The view model's `lastRefreshAt` is the
    /// wall-clock anchor; `last_event_seq` deltas show staleness
    /// only against `started_seq` — for S7 we approximate
    /// "working" as "session has events beyond start". Real
    /// 30-s gating arrives with the helper-summariser pipe in a
    /// follow-up.
    private func isWorking(_ room: Room) -> Bool {
        room.lastEventSeq > room.startedSeq
    }

    /// Deterministic colour from session id so chips remain
    /// stable across refreshes. Pre-S10 placeholder.
    private func stableColor(for sessionId: String) -> Color {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in sessionId.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        let hue = Double(hash & 0xFFFF) / 65535.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.85)
    }
}
