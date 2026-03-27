import Foundation

/// Translates NSTextStorage edits into BTK ops via FFI.
/// One instance per open page, held by the active note editor coordinator.
@MainActor
final class BlockEditTranslator {
    private static var initializedPageIDsByEngine: [Int: Set<String>] = [:]

    private let pageId: String
    private weak var graphState: GraphState?
    private var initialized = false

    init(pageId: String, graphState: GraphState) {
        self.pageId = pageId
        self.graphState = graphState
    }

    /// Initialize BTK for this page. Call once on first edit.
    func initIfNeeded(existingBlocks: [SDBlock]) {
        guard !initialized, let engine = graphState?.engineHandle else { return }

        _ = pageId.withCString { pageIdPtr in
            graph_engine_btk_init(engine, pageIdPtr)
        }

        // Load existing blocks from SwiftData
        if !existingBlocks.isEmpty {
            var ffiBlocks: [BlockFFI] = existingBlocks.map { block in
                var ffi = BlockFFI()
                // Convert UUID string to 16 bytes
                if let uuid = UUID(uuidString: block.id) {
                    let (b0, b1, b2, b3, b4, b5, b6, b7,
                         b8, b9, b10, b11, b12, b13, b14, b15) = uuid.uuid
                    ffi.id = (b0, b1, b2, b3, b4, b5, b6, b7,
                              b8, b9, b10, b11, b12, b13, b14, b15)
                }
                if let parentId = block.parentBlockId, let uuid = UUID(uuidString: parentId) {
                    let (b0, b1, b2, b3, b4, b5, b6, b7,
                         b8, b9, b10, b11, b12, b13, b14, b15) = uuid.uuid
                    ffi.parent_id = (b0, b1, b2, b3, b4, b5, b6, b7,
                                     b8, b9, b10, b11, b12, b13, b14, b15)
                } else {
                    ffi.parent_id = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                }
                ffi.depth = UInt16(block.depth)
                ffi.order = UInt32(block.order)
                return ffi
            }

            // Note: content_ptr lifetime must span the FFI call.
            // Use strdup for each block's content, lockstep with ffiBlocks.
            var cStrings: [UnsafeMutablePointer<CChar>?] = []
            for (i, block) in existingBlocks.enumerated() {
                let cs = strdup(block.content)
                cStrings.append(cs)
                if let cs {
                    ffiBlocks[i].content_ptr = UnsafePointer(cs)
                }
            }

            _ = pageId.withCString { pageIdPtr in
                ffiBlocks.withUnsafeBufferPointer { buf in
                    graph_engine_btk_load_blocks(
                        engine, pageIdPtr,
                        buf.baseAddress, UInt32(buf.count)
                    )
                }
            }

            for cs in cStrings { if let cs { free(cs) } }
        }

        initialized = true
        Self.markPageInitialized(pageId, engine: engine)
    }

    /// Called from textDidChange. Translates the NSTextStorage edit into block ops.
    func translateEdit(offset: Int, oldLength: Int, newText: String) {
        guard initialized, let engine = graphState?.engineHandle else { return }

        _ = pageId.withCString { pageIdPtr in
            newText.withCString { textPtr in
                graph_engine_btk_translate_edit(
                    engine, pageIdPtr,
                    UInt32(offset), UInt32(oldLength), textPtr
                )
            }
        }
    }

    /// Directly update a specific block's content by UUID.
    /// Used for transclusion edits where the block belongs to a specific page.
    static func updateBlock(
        blockId: String,
        pageId: String,
        newContent: String,
        engine: OpaquePointer
    ) -> Bool {
        guard isPageInitialized(pageId, engine: engine) else { return false }
        guard let uuid = UUID(uuidString: blockId) else { return false }
        let (b0, b1, b2, b3, b4, b5, b6, b7,
             b8, b9, b10, b11, b12, b13, b14, b15) = uuid.uuid
        let bytes: [UInt8] = [b0, b1, b2, b3, b4, b5, b6, b7,
                              b8, b9, b10, b11, b12, b13, b14, b15]

        let result = pageId.withCString { pageIdPtr in
            newContent.withCString { contentPtr in
                bytes.withUnsafeBufferPointer { buf in
                    graph_engine_btk_update_block(engine, pageIdPtr, buf.baseAddress, contentPtr)
                }
            }
        }
        return result == 1
    }

    private static func markPageInitialized(_ pageId: String, engine: OpaquePointer) {
        let key = Int(bitPattern: engine)
        var pageIds = initializedPageIDsByEngine[key] ?? []
        pageIds.insert(pageId)
        initializedPageIDsByEngine[key] = pageIds
    }

    private static func isPageInitialized(_ pageId: String, engine: OpaquePointer) -> Bool {
        initializedPageIDsByEngine[Int(bitPattern: engine)]?.contains(pageId) == true
    }
}
