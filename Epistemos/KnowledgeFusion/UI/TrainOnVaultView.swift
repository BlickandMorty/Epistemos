import SwiftUI

// MARK: - TrainOnVaultView

struct TrainOnVaultView: View {
    @Environment(KnowledgeFusionViewModel.self) private var vm

    @State private var selectedVaultURL: URL?
    @State private var pyEnv = PythonEnvironmentManager.shared

    @State private var showAdvanced = true

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            environmentSection
            modelInfoSection
            advancedSettingsSection
            progressSection
            actionSection
        }
        .padding(20)
        .frame(minWidth: 380)
        .task {
            pyEnv.checkExisting()
            vm.autoConfigureForHardware()
        }
    }

    // MARK: - Header

    @State private var showDetails = false

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Knowledge Fusion (Experimental)")
                .font(.title2.weight(.semibold))

            Text("Train a personal adapter from your vault notes")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SettingsDescriptionText(
                text: "This is personalization for your installed local model. Training produces an adapter layered on top of the base model rather than replacing the base model itself."
            )

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showDetails.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text("How does this work?")
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showDetails {
                featureDescription
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var featureDescription: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Knowledge Fusion creates a personal adapter for your local model, running entirely on your MacBook using Apple Silicon. The adapter is a small patch (~50-200 MB) that sits on top of your base model. Your base model never changes; the adapter adjusts its responses based on your data.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                descriptionRow(
                    icon: "pencil.and.outline",
                    title: "Style Adaptation",
                    detail: "Point it at your writing and the adapter picks up on your sentence structure, word choices, and tone. Generated text should better reflect your style."
                )
                descriptionRow(
                    icon: "book.closed",
                    title: "Knowledge Exposure",
                    detail: "The adapter is trained on facts, concepts, and definitions from your notes. This can help the model answer questions about your vault content, though results vary with data quality."
                )
                descriptionRow(
                    icon: "wrench.and.screwdriver",
                    title: "Tool Familiarity",
                    detail: "Document your APIs, workflows, and tool usage patterns. The adapter can help the model suggest relevant tools and parameters based on your documented patterns."
                )
                descriptionRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Background Training",
                    detail: "When enabled, adapter training can run in the background and try different configurations, keeping the best-performing result."
                )
                descriptionRow(
                    icon: "lock.shield",
                    title: "Completely Private",
                    detail: "Everything runs on-device. Your notes never leave your Mac. Training is designed to run during idle time with minimal impact on your work."
                )
            }

            Text("Select a vault folder with your notes, writing samples, or documentation to get started. The more detailed your notes (500+ words each), the better the results.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func descriptionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue.opacity(0.1)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Python Environment

    @ViewBuilder
    private var environmentSection: some View {
        switch pyEnv.state {
        case .unknown:
            VStack(spacing: 8) {
                Label("Training environment not set up yet", systemImage: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(.orange)

                SettingsDescriptionText(
                    text: "This one-time setup installs the local Python and ML pieces used only for adapter training."
                )

                Button {
                    Task { await pyEnv.ensureReady() }
                } label: {
                    Label("Set Up Training Environment", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("Downloads ~200 MB of ML dependencies (one-time setup).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

        case .settingUp(let phase, let progress):
            VStack(spacing: 8) {
                ProgressView(value: progress) {
                    Text(phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.blue)

                Text("This takes 1-3 minutes depending on your internet connection.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

        case .failed(let error):
            VStack(spacing: 6) {
                Label("Environment setup failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)

                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Retry Setup") {
                    Task { await pyEnv.ensureReady() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

        case .ready:
            SettingsDescriptionText(
                text: "Training dependencies are ready. The adapter pipeline can now analyze a vault and launch a local training run."
            )
        }
    }

    // MARK: - Model Info

    @ViewBuilder
    private var modelInfoSection: some View {
        if vm.availableModels.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("No local model installed. Download one from Settings > Inference.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } else if vm.availableModels.count == 1 {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Model: \(vm.availableModels[0].name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SettingsDescriptionText(
                    text: "Training uses the currently installed local model as the base and learns a lightweight adapter that can be activated later."
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.3), in: Capsule())
        } else {
            @Bindable var vm = vm
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Training Model:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $vm.selectedModelIndex) {
                    ForEach(Array(vm.availableModels.enumerated()), id: \.offset) { index, model in
                        Text(model.name).tag(index)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 260)
            }
        }
    }

    // MARK: - Advanced Settings

    @ViewBuilder
    private var advancedSettingsSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text("Advanced Training Settings")
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showAdvanced {
                @Bindable var vm = vm

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "memorychip")
                            .foregroundStyle(.secondary)
                        Text("Detected: \(vm.systemMemoryGB) GB unified memory")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Button("Auto") { vm.autoConfigureForHardware() }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                    }

                    settingRow(
                        title: "Training Iterations",
                        value: $vm.trainingIterations,
                        range: 20...2000,
                        step: 20,
                        desc: "More iterations = better quality but slower. 200 is a good start, 500-1000 for thorough training."
                    )

                    settingRow(
                        title: "LoRA Rank",
                        value: $vm.loraRank,
                        range: 4...64,
                        step: 4,
                        desc: "Adapter capacity. 8 for style cloning, 16 for balanced, 32+ for deep knowledge absorption. Higher = more memory."
                    )

                    settingRow(
                        title: "LoRA Alpha",
                        value: $vm.loraAlpha,
                        range: 8...128,
                        step: 8,
                        desc: "Learning magnitude. Usually 2x the rank. Controls how strongly new knowledge overrides the base model."
                    )

                    settingRow(
                        title: "Batch Size",
                        value: $vm.batchSize,
                        range: 1...8,
                        step: 1,
                        desc: "Examples per step. 1 for 16GB, 2 for 32GB, 4 for 64GB+. Larger = faster but more memory."
                    )

                    settingRow(
                        title: "Max Sequence Length",
                        value: $vm.maxSeqLength,
                        range: 256...4096,
                        step: 256,
                        desc: "Token window per example. 1024 for 16GB, 2048 for 32GB+. Longer captures more context per note."
                    )

                    HStack(spacing: 8) {
                        Text("Hardware Guide")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        hardwareGuideRow("16 GB (M1/M2/M3)", "rank 8-16, batch 1, seq 1024")
                        hardwareGuideRow("24 GB (M2/M3 Pro)", "rank 16-32, batch 2, seq 1024")
                        hardwareGuideRow("32 GB (M1/M2/M3 Max)", "rank 32, batch 2, seq 2048")
                        hardwareGuideRow("64 GB+ (M2/M3/M4 Max)", "rank 32-64, batch 4, seq 2048")
                        hardwareGuideRow("128 GB (M4 Ultra)", "rank 64, batch 8, seq 4096")
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func settingRow(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
            }
            Text(desc)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hardwareGuideRow(_ machine: String, _ config: String) -> some View {
        HStack(spacing: 6) {
            Text(machine)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(config)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        switch vm.trainingState {
        case .idle:
            EmptyView()

        case .parsing, .generating, .training, .evaluating:
            VStack(spacing: 12) {
                ProgressView(value: vm.progress.percentage) {
                    Text(vm.progress.phase)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let eta = vm.progress.eta, eta > 0 {
                    Text("~\(formatDuration(eta)) remaining")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Button("Cancel") {
                    vm.trainingState = .idle
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.vertical, 8)

        case .complete:
            Label("Training complete! Adapter added to your library.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout.weight(.medium))

        case .error:
            VStack(spacing: 4) {
                Label("Training failed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout.weight(.medium))

                if let error = vm.lastTrainingError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionSection: some View {
        let canTrain = pyEnv.isReady && vm.inferenceProvider != nil && vm.detectedModelPath != nil

        if vm.trainingState == .idle || vm.trainingState == .complete || vm.trainingState == .error {
            Button {
                selectVaultFolder()
            } label: {
                Label("Select Vault Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }

        if let url = selectedVaultURL, vm.trainingState == .idle {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
                    Text(url.lastPathComponent)
                        .font(.callout)
                    Spacer()
                    Button("Change") { selectVaultFolder() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

                // Vault analysis results
                if let analysis = vm.lastVaultAnalysis {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            analysisChip("\(analysis.proseFiles) notes", "doc.text")
                            if analysis.codeFiles > 0 { analysisChip("\(analysis.codeFiles) code", "chevron.left.forwardslash.chevron.right") }
                            if analysis.docFiles > 0 { analysisChip("\(analysis.docFiles) PDFs", "doc.richtext") }
                            analysisChip("~\(analysis.estimatedTokens / 1000)k tokens", "number")
                        }

                        Text(analysis.rationale)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Button {
                    startTraining(vaultURL: url)
                } label: {
                    Label("Start Training (Experimental)", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.blue)
                .disabled(!canTrain)

                SettingsDescriptionText(
                    text: "Starting training analyzes the selected vault, prepares local examples, and launches adapter training against the selected base model. The output is an adapter you can activate later."
                )

                if !pyEnv.isReady {
                    Text("Set up the training environment first.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Helpers

    private func selectVaultFolder() {
        // Capture values needed before showing panel
        let memoryGB = vm.systemMemoryGB

        Task { @MainActor in
            // fileImporter/NSOpenPanel alternative: use continuation to avoid runModal() hang
            let url: URL? = await withCheckedContinuation { continuation in
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.message = "Select a vault folder to train on"
                panel.prompt = "Train"
                panel.begin { response in
                    continuation.resume(returning: response == .OK ? panel.url : nil)
                }
            }

            guard let url else { return }
            selectedVaultURL = url

            // Analyze vault off main thread — file I/O can take seconds on large vaults
            let analysis = await Task.detached {
                VaultAnalyzer().analyze(vaultURL: url, systemMemoryGB: memoryGB)
            }.value
            vm.applyVaultAnalysis(analysis)
        }
    }

    private func analysisChip(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }

    private func startTraining(vaultURL: URL) {
        guard let provider = vm.inferenceProvider,
              let modelPath = vm.detectedModelPath else {
            vm.lastTrainingError = "No inference provider or model available."
            vm.trainingState = .error
            return
        }

        // Auto-setup env if needed before training
        if !pyEnv.isReady {
            Task {
                await pyEnv.ensureReady()
                guard pyEnv.isReady else { return }
                vm.startTrainingOnVault(
                    vaultURL: vaultURL,
                    modelPath: modelPath,
                    inferenceProvider: provider
                )
            }
            return
        }

        vm.startTrainingOnVault(
            vaultURL: vaultURL,
            modelPath: modelPath,
            inferenceProvider: provider
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0s" }
        let safeSeconds = max(0, seconds)
        let mins = Int(safeSeconds) / 60
        let secs = Int(safeSeconds) % 60
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }
}
