//
//  MailroomView.swift
//  Simulation Mode S11 — Mailroom inventory surface per
//  DOCTRINE §7.4. Lists pending gift-boxes for one companion;
//  the user picks one to unwrap and the Unwrap button hands
//  control to UnwrapAnimationView.
//

import SwiftUI

public struct MailroomView: View {
    public let companion: CompanionFarmEntry
    public let bridge: CompanionRegistryBridge

    @State private var viewModel: MailroomViewModel
    @State private var unwrapping: GiftBoxFfi?
    @State private var unwrapVM: UnwrapAnimationViewModel

    public init(companion: CompanionFarmEntry, bridge: CompanionRegistryBridge) {
        self.companion = companion
        self.bridge = bridge
        let mailroom = MailroomViewModel(bridge: bridge)
        let unwrap = UnwrapAnimationViewModel(bridge: bridge)
        self._viewModel = State(initialValue: mailroom)
        self._unwrapVM = State(initialValue: unwrap)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider().padding(.vertical, 4)
            if viewModel.inbox.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.inbox, id: \.id) { box in
                            row(box)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 320, minHeight: 240)
        .task { await viewModel.refresh(for: companion.id) }
        .sheet(item: $unwrapping) { box in
            UnwrapAnimationView(
                viewModel: unwrapVM,
                companionId: companion.id,
                giftBox: box,
                onDone: {
                    if unwrapVM.lastOutcome?.didSucceed == true {
                        viewModel.remove(epboxId: box.id)
                    }
                    unwrapping = nil
                }
            )
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("\(companion.name)'s Mailroom")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                Task { await viewModel.refresh(for: companion.id) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Text("No gift boxes waiting.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("New adapters will appear here when they arrive.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func row(_ box: GiftBoxFfi) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(originColor(box.originClass))
                .font(.system(size: 18))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(box.title)
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 6) {
                    Text(box.epboxType)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(box.applyDurationEstimateMs) ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if box.reversible {
                        Text("· reversible")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                Text(box.origin)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Unwrap") {
                unwrapping = box
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private func originColor(_ origin: String) -> Color {
        switch origin {
        case "Official":  return .green
        case "Community": return .orange
        case "UserLocal": return .blue
        default:          return .gray
        }
    }
}

extension GiftBoxFfi: Identifiable {}
