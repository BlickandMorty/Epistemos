//
//  GraphTheaterView.swift
//  Simulation Mode S7 — top-level Graph Live Theater surface
//  (DOCTRINE §3.3 + §3.3.1 + §3.3.3 v1.6).
//
//  Composition:
//
//    [Session-toggle chip row]              ← top, one chip per
//                                             active session
//    [Empty state OR multi-room MTKView]    ← center, single
//                                             MTKView with
//                                             viewport tiling
//    [Per-tile SwiftUI overlay chrome]      ← title strip,
//                                             working-state
//                                             badge (overview)
//                                             OR full inspector
//                                             chrome (drill-in)
//
//  Per DOCTRINE §3.3.1 v1.6: ONE MTKView, ONE pipeline state.
//  The renderer iterates rooms in a single render pass and sets
//  per-tile viewport + camera + buffer-region. SwiftUI overlays
//  are drawn on top for the title strip / badges (NOT in Metal —
//  text-rendering Metal is out of scope).
//

import MetalKit
import SwiftUI

public struct GraphTheaterView: View {
    @State public var viewModel: GraphTheaterViewModel
    public let bridge: SimulationBridge

    public init(viewModel: GraphTheaterViewModel, bridge: SimulationBridge) {
        self._viewModel = State(initialValue: viewModel)
        self.bridge = bridge
    }

    public var body: some View {
        VStack(spacing: 0) {
            SessionToggleChipRow(
                rooms: viewModel.rooms,
                focusedSessionId: focusedSessionId,
                onTap: { sessionId in
                    withAnimation(.easeOut(duration: 0.22)) {
                        viewModel.toggleFocus(sessionId: sessionId)
                    }
                }
            )
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 12)

            stage
        }
        .frame(minWidth: 480, minHeight: 320)
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    // MARK: - Stage

    @ViewBuilder
    private var stage: some View {
        if viewModel.rooms.isEmpty {
            emptyState
        } else {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Single MTKView covering the full stage. The
                    // renderer reads its `tiles` array each frame
                    // and sets viewports per-tile, so a single
                    // MTKView correctly draws all rooms in one
                    // pass per §3.3.1 v1.6.
                    MultiRoomTheaterMTKView(
                        bridge: bridge,
                        viewModel: viewModel,
                        bounds: geo.frame(in: .local)
                    )
                    .ignoresSafeArea()

                    // Per-tile SwiftUI overlay chrome.
                    ForEach(viewModel.layout(in: geo.frame(in: .local)), id: \.sessionId) { tile in
                        if let room = viewModel.rooms.first(where: { $0.sessionId == tile.sessionId }) {
                            tileChrome(room: room, tile: tile)
                                .frame(width: tile.frame.width, height: tile.frame.height)
                                .position(
                                    x: tile.frame.midX,
                                    y: tile.frame.midY
                                )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No active agents.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Start a session to bring this stage to life.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Per-tile chrome

    @ViewBuilder
    private func tileChrome(room: Room, tile: RoomTileLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title strip — top of the tile.
            HStack(spacing: 6) {
                Text(room.sessionId)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(room.members.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial)
            Spacer(minLength: 0)
            // Working-state badge — bottom-right corner per
            // §3.3.3 v1.6 overview chrome.
            HStack {
                Spacer()
                if room.lastEventSeq > room.startedSeq {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .padding(.trailing, 8)
                        .padding(.bottom, 6)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var focusedSessionId: String? {
        if case .drillIn(let sessionId) = viewModel.mode {
            return sessionId
        }
        return nil
    }
}

// MARK: - MTKView wrapper (multi-room)

private struct MultiRoomTheaterMTKView: NSViewRepresentable {
    let bridge: SimulationBridge
    let viewModel: GraphTheaterViewModel
    let bounds: CGRect

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        guard let device = view.device else {
            assertionFailure("Simulation: Metal device unavailable")
            return view
        }
        let ringHandle = bridge.deltaRingHandle()
        guard let ringBridge = DeltaRingBridge(
            ringHandle: ringHandle, device: device
        ) else {
            assertionFailure("Simulation: DeltaRingBridge init failed (ringHandle=\(ringHandle))")
            return view
        }
        do {
            let renderer = try MetalSimulationRenderer(view: view, bridge: ringBridge)
            context.coordinator.renderer = renderer
            updateTiles(renderer: renderer, view: view)
        } catch {
            assertionFailure("Simulation: MetalSimulationRenderer init failed — \(error)")
        }
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        // Re-derive tiles whenever the SwiftUI host re-evaluates
        // (rooms changed, mode changed, drawable resized).
        if let renderer = context.coordinator.renderer {
            updateTiles(renderer: renderer, view: nsView)
        }
    }

    static func dismantleNSView(_ nsView: MTKView, coordinator: Coordinator) {
        nsView.delegate = nil
        coordinator.renderer = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var renderer: MetalSimulationRenderer?
    }

    /// Re-derive `MTLViewport` rectangles from the current
    /// SwiftUI bounds + view-model layout. Caller guarantees the
    /// renderer is initialised. Per §3.3.1 v1.6 each room is
    /// one viewport tile within the shared drawable.
    private func updateTiles(renderer: MetalSimulationRenderer, view: MTKView) {
        // Choose the local point bounds the SwiftUI parent
        // measured (matches the viewModel.layout call site
        // above — they MUST agree so chrome aligns with the
        // Metal-rendered tile).
        let pointBounds = bounds == .zero ? CGRect(origin: .zero, size: view.bounds.size) : bounds
        let layouts = viewModel.layout(in: pointBounds)
        let scale = view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
        renderer.tiles = layouts.compactMap { tile in
            guard let room = viewModel.rooms.first(where: { $0.sessionId == tile.sessionId }) else {
                return nil
            }
            let originX = tile.frame.minX * scale
            // MTLViewport y origin is at the top of the
            // drawable; SwiftUI uses the same convention so no
            // flip is needed.
            let originY = tile.frame.minY * scale
            let width = tile.frame.width * scale
            let height = tile.frame.height * scale
            let viewport = MTLViewport(
                originX: Double(originX),
                originY: Double(originY),
                width: Double(width),
                height: Double(height),
                znear: 0.0,
                zfar: 1.0
            )
            let keys = Set(room.members.map { $0.key })
            return RenderTile(
                sessionId: room.sessionId,
                viewport: viewport,
                agentKeys: keys
            )
        }
    }
}

// MARK: - Standalone preview shell

/// Acceptance-gate harness for the S7 multi-room theater.
/// Constructs a `SimulationBridge`, opens 2 mock sessions with
/// a few participants each, and renders the `GraphTheaterView`.
/// User verifies "two viewport tiles, each with sprite motion,
/// chip row at top, click chip to drill in".
public struct GraphTheaterPreviewView: View {
    @State private var bridge: SimulationBridge?
    @State private var viewModel: GraphTheaterViewModel?
    @State private var setupError: String?

    public init() {}

    public var body: some View {
        Group {
            if let bridge = bridge, let vm = viewModel {
                VStack(spacing: 4) {
                    HStack {
                        Text("Simulation Mode — S7 Multi-room Theater")
                            .font(.headline)
                        Spacer()
                        Button("Inject 2 sessions") {
                            inject(bridge: bridge)
                            vm.refresh()
                        }
                    }
                    .padding(.horizontal, 12)
                    GraphTheaterView(viewModel: vm, bridge: bridge)
                }
            } else if let err = setupError {
                VStack {
                    Text("Initialisation failed").font(.headline)
                    Text(err).foregroundStyle(.red)
                }
            } else {
                ProgressView("Loading simulation…")
                    .task { await initialise() }
            }
        }
    }

    @MainActor
    private func initialise() async {
        guard let b = SimulationBridge() else {
            self.setupError = "Could not create simulation"
            return
        }
        self.bridge = b
        self.viewModel = GraphTheaterViewModel(bridge: b)
    }

    /// Open two mock sessions with a handful of participants
    /// each so the preview shows the multi-room layout.
    private func inject(bridge: SimulationBridge) {
        for (sessionId, count) in [("kimi-preview", 4), ("claude-preview", 1)] {
            let openJson = """
            {"type":"session_started","payload":{"session_id":"\(sessionId)","mode":"Chat"}}
            """
            _ = bridge.processEventJson(openJson)
            for _ in 0..<count {
                bridge.injectTestCompanions(count: 1)
            }
        }
    }
}
