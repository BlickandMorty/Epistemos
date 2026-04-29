//
//  UnwrapAnimationView.swift
//  Simulation Mode S11 — visible 6-phase unwrap animation per
//  DOCTRINE §7.4. The view reads `UnwrapAnimationViewModel.phase`
//  and renders the matching scene. The view never decides when
//  to advance — it just observes the VM's phase changes.
//

import SwiftUI

public struct UnwrapAnimationView: View {
    @State public var viewModel: UnwrapAnimationViewModel
    public let companionId: CompanionId
    public let giftBox: GiftBoxFfi
    public let onDone: () -> Void

    public init(
        viewModel: UnwrapAnimationViewModel,
        companionId: CompanionId,
        giftBox: GiftBoxFfi,
        onDone: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.companionId = companionId
        self.giftBox = giftBox
        self.onDone = onDone
    }

    public var body: some View {
        VStack(spacing: 16) {
            header
            scene
                .frame(minWidth: 320, minHeight: 200)
            phaseLabel
            buttons
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
        .task {
            await viewModel.unwrap(
                companionId: companionId,
                epboxPath: giftBox.absolutePath
            )
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .idle, viewModel.lastOutcome != nil {
                onDone()
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 4) {
            Text(giftBox.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(giftBox.epboxType)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Scene

    @ViewBuilder
    private var scene: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
            switch viewModel.phase {
            case .idle:
                Image(systemName: "shippingbox")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            case .approaching:
                approaching
            case .opening:
                opening
            case .waiting:
                waiting
            case .success:
                success
            case .failure:
                failure
            }
        }
    }

    @ViewBuilder
    private var approaching: some View {
        // Companion sprite walks toward the gift box.
        HStack(spacing: 30) {
            Circle().fill(Color.accentColor).frame(width: 24, height: 24)
                .overlay(Image(systemName: "figure.walk"))
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 36))
                .foregroundStyle(.brown)
        }
    }

    @ViewBuilder
    private var opening: some View {
        // Lid lifts.
        VStack(spacing: 6) {
            Image(systemName: "shippingbox.and.arrow.backward")
                .font(.system(size: 36))
                .foregroundStyle(.brown)
            Text("opening lid…")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var waiting: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse)
            if viewModel.progressChipVisible {
                ProgressView()
                    .controlSize(.small)
                Text("Apply taking longer than expected — still working…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private var success: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Unwrapped.")
                .font(.callout.bold())
        }
    }

    @ViewBuilder
    private var failure: some View {
        VStack(spacing: 6) {
            Image(systemName: "xmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)
            Text("Unwrap failed.")
                .font(.callout.bold())
            if let err = viewModel.lastOutcome?.errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
    }

    // MARK: - Phase label + close

    @ViewBuilder
    private var phaseLabel: some View {
        Text(viewModel.phase.rawValue)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var buttons: some View {
        HStack {
            Spacer()
            Button("Close") {
                viewModel.cancel()
                onDone()
            }
            .disabled(viewModel.phase != .idle
                && viewModel.phase != .success
                && viewModel.phase != .failure)
        }
    }
}
