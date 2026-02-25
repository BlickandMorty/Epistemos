import Foundation
import SwiftData
import os

// MARK: - Chat Orchestration
// Handles user query flow: EventBus → Pipeline → streaming → persistence.

extension AppBootstrap {

    // MARK: - EventBus Subscriptions

    /// Subscribe to toast/error events and route to UIState for display.
    func subscribeToToastEvents() {
        eventBus.subscribe(id: "toast") { [weak self] event in
            guard let self else { return }
            switch event {
            case .toast(let message, let type):
                self.uiState.showToast(message, type: type)
            case .error(let message):
                self.uiState.showToast(message, type: .error)
            default:
                break
            }
        }
    }

    /// Subscribe to querySubmitted events and route through PipelineService.
    /// This is the core chat flow: user types → ChatState → EventBus → PipelineService → streaming response.
    func subscribeToPipelineEvents(pipeline: PipelineService, chatState: ChatState) {
        eventBus.subscribe(id: "pipeline") { [weak self] event in
            guard let self else { return }
            switch event {
            case .querySubmitted(_, let query):
                self.handleQuery(query, pipeline: pipeline, chatState: chatState)
            default:
                break
            }
        }
    }

    // MARK: - Query Lifecycle

    /// Cancel the active pipeline query (called by stop button via ChatState callback).
    func cancelActiveQuery() {
        queryTask?.cancel()
        queryTask = nil
    }

    /// Triggered when Notes Mode is enabled. Builds vault manifest and fires auto-briefing.
    func startNotesMode(chatState: ChatState) {
        Task {
            guard let manifest = await vaultSync.buildVaultManifest() else {
                chatState.addErrorMessage("No notes found in vault. Add some notes first.")
                chatState.disableSpecialModes()
                return
            }
            chatState.vaultManifest = manifest
            chatState.submitQuery("[VAULT_BRIEFING]")
        }
    }

    /// Process a user query through the 6-pass pipeline, streaming tokens back to ChatState.
    func handleQuery(_ query: String, pipeline: PipelineService, chatState: ChatState) {
        queryTask?.cancel()

        // Early guard: if the selected provider needs an API key and we have none,
        // AND Apple Intelligence isn't available as a fallback, show an error immediately.
        let aiFresh = AppleIntelligenceService.shared.checkAvailability()
        inferenceState.appleIntelligenceAvailable = aiFresh.available
        inferenceState.appleIntelligenceUnavailableReason = aiFresh.reason
        if inferenceState.needsApiKey && inferenceState.apiKey.isEmpty && !aiFresh.available {
            chatState.addErrorMessage("No API key configured for \(inferenceState.apiProvider.rawValue.capitalized). Add one in Settings, or use a Mac with Apple Intelligence.")
            return
        }

        let isVaultBriefing = query == "[VAULT_BRIEFING]"
        chatState.isCurrentVaultBriefing = isVaultBriefing
        chatState.startStreaming()

        if chatState.isResearchMode {
            chatState.researchStartTime = Date()
        }

        queryTask = Task {
            do {
                let mode = inferenceState.inferenceMode
                let isResearch = chatState.isResearchMode
                let isNotes = chatState.isNotesMode
                Log.pipeline.warning("🔬 handleQuery — isResearch=\(isResearch) isNotes=\(isNotes) skipEnrichment=\(!isResearch)")

                let notesContext: String?
                let resolvedQuery: String
                if isNotes {
                    let (ctx, cleaned) = await self.buildNotesContext(query: query, chatState: chatState)
                    notesContext = ctx
                    resolvedQuery = cleaned
                } else {
                    notesContext = nil
                    resolvedQuery = query
                }

                let effectiveQuery = isVaultBriefing
                    ? "Analyze my vault and provide a briefing: find cross-note connections, recurring themes, contradictions, topic gaps, stale notes worth revisiting, and notes that could be merged or split. Be specific — reference notes by title."
                    : resolvedQuery

                let stream = pipeline.run(
                    query: effectiveQuery,
                    mode: mode,
                    controls: .defaults,
                    notesContext: notesContext,
                    skipEnrichment: !isResearch
                )

                let capturedChatId = chatState.activeChatId

                for try await event in stream {
                    switch event {
                    case .textDelta(let token):
                        chatState.appendStreamingText(token)

                    case .reasoningDelta(let token):
                        chatState.startReasoning()
                        chatState.appendReasoningText(token)

                    case .enriched(let dual, let truth):
                        Log.pipeline.info("[enriched] Event received — layman=\(dual.laymanSummary != nil) rawLen=\(dual.rawAnalysis.count) truth=\(Int(truth.overallTruthLikelihood * 100))% msgCount=\(chatState.messages.count)")
                        chatState.enrichLastMessage(dualMessage: dual, truthAssessment: truth)
                        Log.pipeline.info("[enriched] enrichLastMessage complete — last msg layman=\(chatState.messages.last?.dualMessage?.laymanSummary != nil)")
                        if !chatState.isIncognito {
                            self.persistEnrichment(
                                chatId: capturedChatId,
                                dualMessage: dual,
                                truthAssessment: truth
                            )
                        }

                    case .stageAdvanced, .signalUpdate, .soarEvent, .deliberationDelta:
                        break

                    case .completed(let dual, let truth):
                        let confidence = truth?.overallTruthLikelihood ?? 0.5
                        let grade = Self.gradeFromConfidence(confidence)
                        chatState.completeProcessing(
                            dualMessage: dual,
                            confidence: confidence,
                            grade: grade,
                            mode: mode,
                            truthAssessment: truth,
                            isResearchResult: isResearch
                        )

                        if let lastMsg = chatState.messages.last {
                            let processed = self.executeVaultActions(in: lastMsg.content)
                            if processed != lastMsg.content {
                                chatState.updateLastMessageContent(processed)
                            }
                        }

                        eventBus.emit(.pipelineComplete)

                        if !chatState.isIncognito {
                            self.persistChatCompletion(
                                chatId: capturedChatId,
                                query: query,
                                answer: chatState.messages.last?.content ?? "",
                                dual: dual,
                                truth: truth,
                                confidence: confidence,
                                grade: grade,
                                mode: mode,
                                isResearch: isResearch,
                                isNotes: isNotes
                            )
                        }

                        if chatState.chatTitle == nil {
                            self.generateChatTitle(query: query, chatId: capturedChatId, chatState: chatState)
                        }

                    case .error(let msg):
                        chatState.addErrorMessage(msg)
                    }
                }
            } catch is CancellationError {
                // User pressed stop — clean exit
            } catch {
                chatState.addErrorMessage("Analysis failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Chat Title Generation

    /// Fire-and-forget: generates a short chat title from the user's query via LLM.
    func generateChatTitle(query: String, chatId: String?, chatState: ChatState) {
        Task {
            let prompt = """
            Generate a very short title (2-6 words) for a chat conversation that starts with this query. \
            Return ONLY the title, no quotes, no punctuation at the end, no explanation. \
            Examples: "Quantum entanglement basics", "Fix SwiftUI layout bug", "Essay on stoicism", \
            "React vs Vue comparison", "Morning routine ideas"

            Query: \(query)
            """

            do {
                let title = try await llmService.generate(
                    prompt: prompt,
                    systemPrompt: "You generate concise chat titles. Return only the title text, nothing else.",
                    maxTokens: 30
                )
                let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
                guard !cleaned.isEmpty else { return }

                chatState.chatTitle = cleaned

                if let chatId {
                    let context = modelContainer.mainContext
                    let predicate = #Predicate<SDChat> { $0.id == chatId }
                    let descriptor = FetchDescriptor<SDChat>(predicate: predicate)
                    if let sdChat = try? context.fetch(descriptor).first {
                        sdChat.title = cleaned
                        try? context.save()
                    }
                }
            } catch {
                Log.pipeline.debug("Chat title generation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
