import Darwin
import Foundation
@preconcurrency import llama

public struct GGUFSessionParameters: Sendable, Equatable {
    public var context: Int
    public var batch: Int
    public var temperature: Float
    public var topK: Int
    public var topP: Float
    public var typicalP: Float
    public var penaltyLastN: Int
    public var penaltyRepeat: Float
    public var numberOfThreads: Int?
    public var seed: Int?

    public init(
        context: Int,
        batch: Int = 512,
        temperature: Float = 0.2,
        topK: Int = 40,
        topP: Float = 0.9,
        typicalP: Float = 1,
        penaltyLastN: Int = 64,
        penaltyRepeat: Float = 1.05,
        numberOfThreads: Int? = nil,
        seed: Int? = nil
    ) {
        self.context = context
        self.batch = batch
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.typicalP = typicalP
        self.penaltyLastN = penaltyLastN
        self.penaltyRepeat = penaltyRepeat
        self.numberOfThreads = numberOfThreads
        self.seed = seed
    }
}

public actor GGUFSessionBridge {
    nonisolated(unsafe) private static var backendInitialized = false
    nonisolated private static let backendInitializationLock = NSLock()

    private final class SessionResources: @unchecked Sendable {
        let model: OpaquePointer
        let context: OpaquePointer
        let vocab: OpaquePointer
        var batch: llama_batch
        let sampler: UnsafeMutablePointer<llama_sampler>
        let cursorPointer: UnsafeMutableBufferPointer<llama_token_data>

        init(
            model: OpaquePointer,
            context: OpaquePointer,
            vocab: OpaquePointer,
            batch: llama_batch,
            sampler: UnsafeMutablePointer<llama_sampler>,
            cursorPointer: UnsafeMutableBufferPointer<llama_token_data>
        ) {
            self.model = model
            self.context = context
            self.vocab = vocab
            self.batch = batch
            self.sampler = sampler
            self.cursorPointer = cursorPointer
        }

        deinit {
            cursorPointer.deallocate()
            llama_sampler_free(sampler)
            llama_batch_free(batch)
            llama_free(context)
            llama_model_free(model)
        }
    }

    private let session: SessionResources
    private let parameters: GGUFSessionParameters

    private var model: OpaquePointer { session.model }
    private var context: OpaquePointer { session.context }
    private var vocab: OpaquePointer { session.vocab }
    private var batch: llama_batch {
        get { session.batch }
        set { session.batch = newValue }
    }
    private var sampler: UnsafeMutablePointer<llama_sampler> { session.sampler }
    private var cursorPointer: UnsafeMutableBufferPointer<llama_token_data> { session.cursorPointer }

    public init(modelURL: URL, parameters: GGUFSessionParameters) async throws {
        Self.initializeBackendIfNeeded()

        var modelParameters = llama_model_default_params()
        modelParameters.use_mmap = true
        modelParameters.use_mlock = llama_supports_mlock()
        modelParameters.check_tensors = false
        modelParameters.n_gpu_layers = llama_supports_gpu_offload() ? 9_999 : 0

        guard let model = llama_model_load_from_file(modelURL.path(), modelParameters) else {
            throw GGUFSessionError.failedToLoadModel(modelURL)
        }

        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = UInt32(max(1, parameters.context))
        contextParameters.n_batch = UInt32(max(1, parameters.batch))
        contextParameters.n_ubatch = UInt32(max(1, parameters.batch))
        contextParameters.n_seq_max = 1
        contextParameters.n_threads = Self.recommendedThreadCount(explicit: parameters.numberOfThreads)
        contextParameters.n_threads_batch = contextParameters.n_threads
        contextParameters.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED

        guard let context = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            throw GGUFSessionError.failedToCreateContext
        }

        guard let vocab = llama_model_get_vocab(model) else {
            llama_free(context)
            llama_model_free(model)
            throw GGUFSessionError.failedToCreateContext
        }
        let batch = llama_batch_init(Int32(max(1, parameters.batch)), 0, 1)
        guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
            llama_batch_free(batch)
            llama_free(context)
            llama_model_free(model)
            throw GGUFSessionError.failedToCreateContext
        }
        let minKeep = 1
        let penaltyFrequency: Float = 0
        let penaltyPresence: Float = 0

        llama_sampler_chain_add(sampler, llama_sampler_init_temp_ext(parameters.temperature, 0, 1.0))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(Int32(parameters.topK)))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(parameters.topP, minKeep))
        llama_sampler_chain_add(sampler, llama_sampler_init_min_p(max(0, 1 - parameters.topP), minKeep))
        llama_sampler_chain_add(sampler, llama_sampler_init_typical(parameters.typicalP, minKeep))
        llama_sampler_chain_add(
            sampler,
            llama_sampler_init_penalties(
                Int32(parameters.penaltyLastN),
                parameters.penaltyRepeat,
                penaltyFrequency,
                penaltyPresence
            )
        )
        let seed = parameters.seed.map(UInt32.init) ?? LLAMA_DEFAULT_SEED
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(seed))

        self.session = SessionResources(
            model: model,
            context: context,
            vocab: vocab,
            batch: batch,
            sampler: sampler,
            cursorPointer: .allocate(capacity: Int(llama_vocab_n_tokens(vocab)))
        )
        self.parameters = parameters
    }

    public func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        var output = ""
        let stream = stream(prompt: prompt, systemPrompt: systemPrompt, maxTokens: maxTokens)
        for try await chunk in stream {
            output += chunk
        }
        return output
    }

    public func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let promptText = try self.preparePrompt(
                        prompt: prompt,
                        systemPrompt: systemPrompt
                    )
                    try self.beginGeneration(with: promptText)

                    var emittedTokens = 0
                    var partialBytes: [CChar] = []

                    while maxTokens <= 0 || emittedTokens < maxTokens {
                        if Task.isCancelled {
                            throw CancellationError()
                        }

                        let token = try self.sampleNextToken()
                        if self.isEndOfGeneration(token) {
                            break
                        }

                        partialBytes.append(contentsOf: self.tokenPiece(token))
                        if let chunk = Self.makeString(from: partialBytes) {
                            partialBytes.removeAll(keepingCapacity: true)
                            continuation.yield(chunk)
                        } else if let chunk = Self.makeDecodableChunk(from: &partialBytes) {
                            continuation.yield(chunk)
                        }

                        emittedTokens += 1
                        if maxTokens > 0, emittedTokens >= maxTokens {
                            break
                        }

                        try self.enqueueAndDecode(token: token)
                    }

                    if let remainder = Self.makeString(from: partialBytes) {
                        continuation.yield(remainder)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func preparePrompt(
        prompt: String,
        systemPrompt: String?
    ) throws -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw GGUFSessionError.emptyPrompt
        }

        let trimmedSystemValue = systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSystem = trimmedSystemValue?.isEmpty == false ? trimmedSystemValue : nil

        if let templated = try applyChatTemplate(
            prompt: trimmedPrompt,
            systemPrompt: trimmedSystem
        ) {
            return templated
        }

        return Self.fallbackPrompt(prompt: trimmedPrompt, systemPrompt: trimmedSystem)
    }

    private func beginGeneration(with prompt: String) throws {
        clearContext()
        llama_sampler_reset(sampler)
        try decode(text: prompt)
    }

    private func enqueueAndDecode(token: llama_token) throws {
        batch.add(id: token, pos: currentPosition, seqIDs: [0], logits: true)
        try decodeBatch()
    }

    private func sampleNextToken() throws -> llama_token {
        let logits = llama_get_logits_ith(context, -1)
        guard let logits else {
            throw GGUFSessionError.failedToDecode("Missing logits for sampling")
        }

        for tokenIndex in cursorPointer.indices {
            cursorPointer[tokenIndex] = llama_token_data(
                id: Int32(tokenIndex),
                logit: logits[tokenIndex],
                p: 0
            )
        }

        var tokenDataArray = llama_token_data_array(
            data: cursorPointer.baseAddress,
            size: cursorPointer.count,
            selected: -1,
            sorted: false
        )

        llama_sampler_apply(sampler, &tokenDataArray)
        guard tokenDataArray.selected >= 0 else {
            throw GGUFSessionError.failedToDecode("Sampler did not select a token")
        }

        let selected = tokenDataArray.data[Int(tokenDataArray.selected)].id
        llama_sampler_accept(sampler, selected)
        return selected
    }

    private func tokenPiece(_ token: llama_token) -> [CChar] {
        token.piece(vocab: vocab, special: true)
    }

    private func decode(text: String) throws {
        let tokens = tokenize(text: text, addBos: false, special: true)
        guard !tokens.isEmpty else { return }

        let chunkSize = max(1, parameters.batch)
        for chunkStart in stride(from: 0, to: tokens.count, by: chunkSize) {
            let chunkEnd = min(tokens.count, chunkStart + chunkSize)
            let chunk = tokens[chunkStart..<chunkEnd]
            let basePosition = currentPosition

            for (index, token) in chunk.enumerated() {
                let isLastToken = chunkEnd == tokens.count && index == (chunk.count - 1)
                batch.add(
                    id: token,
                    pos: basePosition + Int32(index),
                    seqIDs: [0],
                    logits: isLastToken
                )
            }

            try decodeBatch()
        }
    }

    private func decodeBatch() throws {
        guard batch.n_tokens > 0 else { return }
        guard currentPosition + batch.n_tokens <= Int32(parameters.context) else {
            batch.clear()
            throw GGUFSessionError.contextLimitExceeded
        }

        let result = llama_decode(context, batch)
        batch.clear()

        guard result == 0 else {
            throw GGUFSessionError.failedToDecode("llama_decode returned \(result)")
        }
    }

    private func clearContext() {
        batch.clear()
        if let memory = llama_get_memory(context) {
            llama_memory_clear(memory, true)
        }
    }

    private var currentPosition: Int32 {
        guard let memory = llama_get_memory(context) else { return 0 }
        let current = llama_memory_seq_pos_max(memory, 0)
        return current < 0 ? 0 : current + 1
    }

    private func applyChatTemplate(
        prompt: String,
        systemPrompt: String?
    ) throws -> String? {
        var roles: [String] = []
        var contents: [String] = []

        if let systemPrompt {
            roles.append("system")
            contents.append(systemPrompt)
        }
        roles.append("user")
        contents.append(prompt)

        let rolePointers: [UnsafeMutablePointer<CChar>?] = roles.map { strdup($0) }
        let contentPointers: [UnsafeMutablePointer<CChar>?] = contents.map { strdup($0) }
        defer {
            for pointer in rolePointers {
                free(pointer)
            }
            for pointer in contentPointers {
                free(pointer)
            }
        }

        var messages = zip(rolePointers, contentPointers).map { rolePointer, contentPointer in
            llama_chat_message(role: rolePointer, content: contentPointer)
        }

        var capacity = max(2_048, contents.reduce(0) { $0 + $1.utf8.count } * 2 + 256)
        for _ in 0..<4 {
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
            defer { buffer.deallocate() }

            let renderedCount = llama_chat_apply_template(
                nil,
                &messages,
                messages.count,
                true,
                buffer,
                Int32(capacity)
            )

            if renderedCount < 0 {
                return nil
            }
            if Int(renderedCount) < capacity {
                return String(cString: buffer)
            }

            capacity = Int(renderedCount) + 1
        }

        throw GGUFSessionError.failedToRenderPrompt
    }

    private func tokenize(
        text: String,
        addBos: Bool,
        special: Bool
    ) -> [llama_token] {
        let utf8Count = text.utf8.count
        let tokenCapacity = max(utf8Count + (addBos ? 1 : 0) + 1, 8)
        return [llama_token](unsafeUninitializedCapacity: tokenCapacity) { buffer, initializedCount in
            let tokenCount = llama_tokenize(
                vocab,
                text,
                Int32(utf8Count),
                buffer.baseAddress,
                Int32(tokenCapacity),
                addBos,
                special
            )
            initializedCount = max(0, Int(tokenCount))
        }
    }

    private nonisolated static func initializeBackendIfNeeded() {
        backendInitializationLock.lock()
        defer { backendInitializationLock.unlock() }
        guard !backendInitialized else { return }
        llama_backend_init()
        backendInitialized = true
    }

    private nonisolated static func recommendedThreadCount(explicit: Int?) -> Int32 {
        if let explicit {
            return Int32(max(1, explicit))
        }
        let processors = ProcessInfo.processInfo.processorCount
        return Int32(max(1, min(8, processors - 2)))
    }

    private nonisolated static func makeString(from partialBytes: [CChar]) -> String? {
        guard !partialBytes.isEmpty else { return nil }
        return String(utf8String: partialBytes + [0])
    }

    private nonisolated static func makeDecodableChunk(from partialBytes: inout [CChar]) -> String? {
        guard partialBytes.count > 1 else { return nil }
        for suffixLength in 1..<partialBytes.count {
            let suffix = Array(partialBytes.suffix(suffixLength))
            guard String(utf8String: suffix + [0]) != nil else {
                continue
            }

            let chunk = Self.makeString(from: partialBytes) ?? ""
            partialBytes.removeAll(keepingCapacity: true)
            return chunk.isEmpty ? nil : chunk
        }
        return nil
    }

    private func isEndOfGeneration(_ token: llama_token) -> Bool {
        llama_vocab_is_eog(vocab, token)
    }

    private nonisolated static func fallbackPrompt(
        prompt: String,
        systemPrompt: String?
    ) -> String {
        let systemBlock = systemPrompt.map { current in
            "<|im_start|>system\n\(current)\n<|im_end|>\n"
        } ?? ""
        return """
        \(systemBlock)<|im_start|>user
        \(prompt)
        <|im_end|>
        <|im_start|>assistant
        """
    }
}

private extension llama_batch {
    mutating func clear() {
        n_tokens = 0
    }

    mutating func add(
        id: llama_token,
        pos: llama_pos,
        seqIDs: [llama_seq_id],
        logits: Bool
    ) {
        let index = Int(n_tokens)
        token[index] = id
        self.pos[index] = pos
        n_seq_id[index] = Int32(seqIDs.count)
        for (offset, sequenceID) in seqIDs.enumerated() {
            seq_id[index]?[offset] = sequenceID
        }
        self.logits[index] = logits ? 1 : 0
        n_tokens += 1
    }
}

private extension llama_token {
    func piece(vocab: OpaquePointer, special: Bool) -> [CChar] {
        var result = [CChar](repeating: 0, count: 8)
        let pieceCount = llama_token_to_piece(vocab, self, &result, 8, 0, special)
        if pieceCount < 0 {
            result = [CChar](repeating: 0, count: Int(-pieceCount))
            _ = llama_token_to_piece(vocab, self, &result, -pieceCount, 0, special)
            return result
        }
        return Array(result[0..<Int(pieceCount)])
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        switch self {
        case let .some(value) where !value.isEmpty:
            value
        default:
            nil
        }
    }
}

private enum GGUFSessionError: LocalizedError {
    case emptyPrompt
    case failedToLoadModel(URL)
    case failedToCreateContext
    case failedToRenderPrompt
    case failedToDecode(String)
    case contextLimitExceeded

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "The GGUF runtime received an empty prompt."
        case let .failedToLoadModel(url):
            return "Failed to load GGUF model at \(url.path)."
        case .failedToCreateContext:
            return "Failed to allocate the GGUF inference context."
        case .failedToRenderPrompt:
            return "Failed to render the chat prompt for the GGUF model."
        case let .failedToDecode(reason):
            return "GGUF decoding failed: \(reason)"
        case .contextLimitExceeded:
            return "GGUF generation exceeded the configured context window."
        }
    }
}
