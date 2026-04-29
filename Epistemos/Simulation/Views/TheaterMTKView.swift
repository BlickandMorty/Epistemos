//
//  TheaterMTKView.swift
//  Simulation Mode S4 — SwiftUI / NSViewRepresentable wrapper for
//  the placeholder Metal renderer.
//
//  S4 ships this as a **standalone preview view** that exercises
//  the full Rust → SPSC ring → MTLBuffer → Metal pipeline. It is
//  NOT yet wired into the Graph view's segmented control (Nodes /
//  Live / Theater) — that integration is S7. For the S4
//  acceptance gate "synthetic harness: feed 5 mock companions
//  through the reducer; see 5 colored rectangles" the user
//  instantiates `TheaterPreviewView()` from a debug surface and
//  verifies visually.
//

import SwiftUI
import MetalKit

/// SwiftUI wrapper around an MTKView that hosts a
/// `MetalSimulationRenderer`. The renderer is created on view
/// creation and torn down on dismantle.
public struct TheaterMTKView: NSViewRepresentable {

    /// The Rust simulation handle (raw u64 from
    /// `epistemos_simulation_create`). The view borrows but does
    /// not own — caller is responsible for `epistemos_simulation_destroy`
    /// at the end of the parent view's lifecycle.
    public let simulationHandle: UInt64

    public init(simulationHandle: UInt64) {
        self.simulationHandle = simulationHandle
    }

    public func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        // Configuration done inside MetalSimulationRenderer.init,
        // which sets I-16 sampler, MSAA, pixel format, frame rate.

        guard let device = view.device else {
            assertionFailure("Simulation: Metal device unavailable")
            return view
        }
        let ringHandle = epistemosSimulationDeltaRingHandle(handle: simulationHandle)
        guard let bridge = DeltaRingBridge(
            ringHandle: ringHandle,
            device: device
        ) else {
            assertionFailure("Simulation: DeltaRingBridge init failed (ringHandle=\(ringHandle))")
            return view
        }
        do {
            let renderer = try MetalSimulationRenderer(view: view, bridge: bridge)
            context.coordinator.renderer = renderer
        } catch {
            assertionFailure("Simulation: MetalSimulationRenderer init failed — \(error)")
        }
        return view
    }

    public func updateNSView(_ nsView: MTKView, context: Context) {
        // No-op: the renderer drives itself off the SPSC ring.
    }

    public static func dismantleNSView(_ nsView: MTKView, coordinator: Coordinator) {
        nsView.delegate = nil
        coordinator.renderer = nil
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public final class Coordinator {
        public var renderer: MetalSimulationRenderer?
    }
}

/// Top-level preview shell for the S4 acceptance gate. Constructs
/// a Simulation, injects 5 synthetic companions, and renders them
/// via `TheaterMTKView`. The user verifies "5 colored rectangles"
/// visually.
///
/// NOT integrated into Settings / Graph view; S7 handles the
/// canonical placement.
public struct TheaterPreviewView: View {
    @State private var simulationHandle: UInt64 = 0

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Simulation Mode — S4 Theater Preview")
                    .font(.headline)
                Spacer()
                Button("Inject 5 Mock") {
                    if simulationHandle != 0 {
                        epistemosSimulationInjectTestCompanions(
                            handle: simulationHandle, count: 5
                        )
                    }
                }
                .disabled(simulationHandle == 0)
            }
            .padding(.horizontal)

            if simulationHandle != 0 {
                TheaterMTKView(simulationHandle: simulationHandle)
                    .frame(minWidth: 480, minHeight: 240)
            } else {
                Text("Initialising simulation…")
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 480, minHeight: 240)
            }
        }
        .onAppear {
            simulationHandle = epistemosSimulationCreate()
        }
        .onDisappear {
            if simulationHandle != 0 {
                epistemosSimulationDestroy(handle: simulationHandle)
                simulationHandle = 0
            }
        }
    }
}
