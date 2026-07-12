import Foundation
import llama
import os

// Embedded llama.cpp engine (Plan 1-MAS §2.1). In-process only: no subprocess,
// no server, no JIT — the b9870 framework carries its Metal library embedded
// in the binary, so Metal shader setup needs no filesystem lookup in the
// sandbox.
//
// Threading model: every llama_* call runs on the private serial `queue`
// (llama contexts are not thread-safe). `cancel()` only flips a lock-guarded
// flag, so it is safe from any thread/actor, including mid-generation.
public final class LlamaLocalChatEngine: LocalChatEngine, @unchecked Sendable {
    private struct Snapshot {
        var loaded = false
        var busy = false
        var accounting: LocalChatWindowAccounting?
    }

    private let queue = DispatchQueue(label: "app.epistemos.llama.engine", qos: .userInitiated)
    private let cancelRequested = OSAllocatedUnfairLock(initialState: false)
    private let snapshot = OSAllocatedUnfairLock(initialState: Snapshot())

    // Mutable engine state — touched only on `queue`.
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var contextTokenCapacity = 0

    private static let backendInitOnce: Void = llama_backend_init()

    public init() {}

    deinit {
        // Engine owners call unload(); this is the last-resort teardown.
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
    }

    public var isLoaded: Bool {
        snapshot.withLock { $0.loaded }
    }

    public var windowAccounting: LocalChatWindowAccounting? {
        snapshot.withLock { $0.accounting }
    }

    public func load(modelURL: URL, contextTokens: Int) async throws {
        _ = Self.backendInitOnce
        let path = modelURL.path
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    try loadOnQueue(path: path, contextTokens: contextTokens)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func stream(prompt: String, maxNewTokens: Int) -> AsyncThrowingStream<LocalChatStreamEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            continuation.onTermination = { [weak self] termination in
                if case .cancelled = termination { self?.cancel() }
            }
            queue.async { [self] in
                runStreamOnQueue(prompt: prompt, maxNewTokens: maxNewTokens, continuation: continuation)
            }
        }
    }

    public func cancel() {
        cancelRequested.withLock { $0 = true }
    }

    public func unload() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [self] in
                if let context { llama_free(context) }
                if let model { llama_model_free(model) }
                context = nil
                model = nil
                contextTokenCapacity = 0
                snapshot.withLock {
                    $0.loaded = false
                    $0.busy = false
                    $0.accounting = nil
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Queue-side implementation

    private func loadOnQueue(path: String, contextTokens: Int) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LocalChatEngineError.modelNotFound(path)
        }

        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
        context = nil
        model = nil

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 999 // all layers on Metal (Apple Silicon only)

        guard let loadedModel = llama_model_load_from_file(path, modelParams) else {
            snapshot.withLock { $0.loaded = false }
            throw LocalChatEngineError.modelLoadFailed(path)
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(max(512, contextTokens))
        contextParams.n_batch = 1024
        let threads = Int32(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads

        guard let createdContext = llama_init_from_model(loadedModel, contextParams) else {
            llama_model_free(loadedModel)
            snapshot.withLock { $0.loaded = false }
            throw LocalChatEngineError.contextCreationFailed
        }

        model = loadedModel
        context = createdContext
        contextTokenCapacity = Int(llama_n_ctx(createdContext))
        snapshot.withLock {
            $0.loaded = true
            $0.accounting = LocalChatWindowAccounting(
                contextTokens: contextTokenCapacity,
                promptTokens: 0,
                generatedTokens: 0
            )
        }
    }

    private func runStreamOnQueue(
        prompt: String,
        maxNewTokens: Int,
        continuation: AsyncThrowingStream<LocalChatStreamEvent, Error>.Continuation
    ) {
        guard let context, let model else {
            continuation.finish(throwing: LocalChatEngineError.notLoaded)
            return
        }
        let alreadyBusy = snapshot.withLock { current -> Bool in
            if current.busy { return true }
            current.busy = true
            return false
        }
        guard !alreadyBusy else {
            continuation.finish(throwing: LocalChatEngineError.busy)
            return
        }
        defer { snapshot.withLock { $0.busy = false } }
        cancelRequested.withLock { $0 = false }

        let vocab = llama_model_get_vocab(model)

        // Fresh single-shot run: clear any prior KV state.
        llama_memory_clear(llama_get_memory(context), true)

        var promptTokens: [llama_token]
        do {
            promptTokens = try tokenize(prompt: prompt, vocab: vocab)
        } catch {
            continuation.finish(throwing: error)
            return
        }

        // Reserve at least a small reply budget inside the window.
        guard promptTokens.count < contextTokenCapacity - 8 else {
            continuation.finish(throwing: LocalChatEngineError.promptTooLong(
                promptTokens: promptTokens.count,
                contextTokens: contextTokenCapacity
            ))
            return
        }

        // Prompt ingestion, chunked by n_batch.
        let batchSize = 1024
        var offset = 0
        while offset < promptTokens.count {
            if cancelRequested.withLock({ $0 }) {
                finishRun(
                    continuation: continuation,
                    promptTokens: promptTokens.count,
                    generated: 0,
                    reason: .cancelled,
                    startedAt: nil
                )
                return
            }
            let length = min(batchSize, promptTokens.count - offset)
            let status = promptTokens.withUnsafeMutableBufferPointer { buffer -> Int32 in
                let batch = llama_batch_get_one(buffer.baseAddress! + offset, Int32(length))
                return llama_decode(context, batch)
            }
            guard status == 0 else {
                continuation.finish(throwing: LocalChatEngineError.decodeFailed(code: status))
                return
            }
            offset += length
        }

        // Generation loop — greedy chain (deterministic; Surface A owns sampling policy later).
        let samplerParams = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(samplerParams) else {
            continuation.finish(throwing: LocalChatEngineError.decodeFailed(code: -1))
            return
        }
        llama_sampler_chain_add(sampler, llama_sampler_init_greedy())
        defer { llama_sampler_free(sampler) }

        var accumulator = UTF8PieceAccumulator()
        var generated = 0
        let started = DispatchTime.now()

        while true {
            if cancelRequested.withLock({ $0 }) {
                guard flushPending(&accumulator, continuation: continuation) else { return }
                finishRun(
                    continuation: continuation,
                    promptTokens: promptTokens.count,
                    generated: generated,
                    reason: .cancelled,
                    startedAt: started
                )
                return
            }

            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) {
                guard flushPending(&accumulator, continuation: continuation) else { return }
                finishRun(
                    continuation: continuation,
                    promptTokens: promptTokens.count,
                    generated: generated,
                    reason: .endOfGeneration,
                    startedAt: started
                )
                return
            }

            if let piece = piece(for: token, vocab: vocab, accumulator: &accumulator), !piece.isEmpty {
                guard yieldEvent(.token(piece), continuation: continuation) else { return }
            }
            generated += 1
            updateAccounting(promptTokens: promptTokens.count, generated: generated)

            if generated >= maxNewTokens {
                guard flushPending(&accumulator, continuation: continuation) else { return }
                finishRun(
                    continuation: continuation,
                    promptTokens: promptTokens.count,
                    generated: generated,
                    reason: .maxTokens,
                    startedAt: started
                )
                return
            }
            if promptTokens.count + generated >= contextTokenCapacity - 1 {
                guard flushPending(&accumulator, continuation: continuation) else { return }
                finishRun(
                    continuation: continuation,
                    promptTokens: promptTokens.count,
                    generated: generated,
                    reason: .contextFull,
                    startedAt: started
                )
                return
            }

            let status = withUnsafeMutablePointer(to: &token) { pointer -> Int32 in
                let batch = llama_batch_get_one(pointer, 1)
                return llama_decode(context, batch)
            }
            guard status == 0 else {
                continuation.finish(throwing: LocalChatEngineError.decodeFailed(code: status))
                return
            }
        }
    }

    private func tokenize(prompt: String, vocab: OpaquePointer?) throws -> [llama_token] {
        let utf8 = Array(prompt.utf8)
        let textLength = Int32(utf8.count)
        let needed = utf8.withUnsafeBufferPointer { buffer -> Int32 in
            buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: utf8.count) { text in
                llama_tokenize(vocab, text, textLength, nil, 0, true, true)
            }
        }
        let capacity = Int(needed < 0 ? -needed : needed)
        guard capacity > 0 else { throw LocalChatEngineError.tokenizationFailed }

        var tokens = [llama_token](repeating: 0, count: capacity)
        let written = utf8.withUnsafeBufferPointer { buffer -> Int32 in
            buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: utf8.count) { text in
                tokens.withUnsafeMutableBufferPointer { tokenBuffer in
                    llama_tokenize(
                        vocab,
                        text,
                        textLength,
                        tokenBuffer.baseAddress,
                        Int32(tokenBuffer.count),
                        true,
                        true
                    )
                }
            }
        }
        guard written > 0 else { throw LocalChatEngineError.tokenizationFailed }
        tokens.removeLast(tokens.count - Int(written))
        return tokens
    }

    private func piece(
        for token: llama_token,
        vocab: OpaquePointer?,
        accumulator: inout UTF8PieceAccumulator
    ) -> String? {
        var buffer = [CChar](repeating: 0, count: 512)
        var length = buffer.withUnsafeMutableBufferPointer { pointer in
            llama_token_to_piece(vocab, token, pointer.baseAddress, Int32(pointer.count), 0, false)
        }
        if length < 0 {
            buffer = [CChar](repeating: 0, count: Int(-length))
            length = buffer.withUnsafeMutableBufferPointer { pointer in
                llama_token_to_piece(vocab, token, pointer.baseAddress, Int32(pointer.count), 0, false)
            }
        }
        guard length > 0 else { return nil }
        let bytes = buffer[0..<Int(length)].map { UInt8(bitPattern: $0) }
        return accumulator.push(bytes)
    }

    private func yieldEvent(
        _ event: LocalChatStreamEvent,
        continuation: AsyncThrowingStream<LocalChatStreamEvent, Error>.Continuation
    ) -> Bool {
        switch continuation.yield(event) {
        case .enqueued:
            return true
        case .dropped:
            continuation.finish(throwing: LocalChatEngineError.streamBackpressure)
            return false
        case .terminated:
            return false
        @unknown default:
            continuation.finish(throwing: LocalChatEngineError.streamBackpressure)
            return false
        }
    }

    private func flushPending(
        _ accumulator: inout UTF8PieceAccumulator,
        continuation: AsyncThrowingStream<LocalChatStreamEvent, Error>.Continuation
    ) -> Bool {
        if let tail = accumulator.flush(), !tail.isEmpty {
            return yieldEvent(.token(tail), continuation: continuation)
        }
        return true
    }

    private func finishRun(
        continuation: AsyncThrowingStream<LocalChatStreamEvent, Error>.Continuation,
        promptTokens: Int,
        generated: Int,
        reason: LocalChatRunStats.FinishReason,
        startedAt: DispatchTime?
    ) {
        updateAccounting(promptTokens: promptTokens, generated: generated)
        var tokensPerSecond = 0.0
        if let startedAt, generated > 0 {
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds) / 1_000_000_000
            if elapsed > 0 { tokensPerSecond = Double(generated) / elapsed }
        }
        guard yieldEvent(.finished(LocalChatRunStats(
            promptTokens: promptTokens,
            generatedTokens: generated,
            finishReason: reason,
            tokensPerSecond: tokensPerSecond
        )), continuation: continuation) else { return }
        continuation.finish()
    }

    private func updateAccounting(promptTokens: Int, generated: Int) {
        let capacity = contextTokenCapacity
        snapshot.withLock {
            $0.accounting = LocalChatWindowAccounting(
                contextTokens: capacity,
                promptTokens: promptTokens,
                generatedTokens: generated
            )
        }
    }
}

// Token pieces are raw bytes and can split UTF-8 scalars mid-sequence; emit
// only the longest valid prefix and carry the remainder into the next piece.
struct UTF8PieceAccumulator {
    private var pending: [UInt8] = []

    mutating func push(_ bytes: [UInt8]) -> String? {
        pending.append(contentsOf: bytes)
        for dropCount in 0...min(3, pending.count) {
            let prefix = pending[0..<(pending.count - dropCount)]
            if let decoded = String(bytes: prefix, encoding: .utf8) {
                pending.removeFirst(prefix.count)
                return decoded.isEmpty ? nil : decoded
            }
        }
        return nil
    }

    mutating func flush() -> String? {
        guard !pending.isEmpty else { return nil }
        defer { pending.removeAll() }
        return String(bytes: pending, encoding: .utf8)
            ?? String(decoding: pending, as: UTF8.self)
    }
}
