import Foundation
import Observation
import OSLog

// MARK: - Contradiction Detection Service

/// Service for detecting and managing contradictions in vault knowledge.
/// Wraps the Rust FFI `detect_vault_contradictions` function.
@Observable
@MainActor
final class ContradictionDetectionService {
    
    // MARK: - Properties
    
    private let vaultRegistry: VaultRegistry
    private var activeVaultPath: String?
    
    /// Currently detected contradictions awaiting resolution
    var pendingContradictions: [VaultContradiction] = []
    
    /// Whether contradiction detection is in progress
    var isDetecting = false
    
    /// History of resolved contradictions
    var resolvedContradictions: [ResolvedContradiction] = []
    
    // MARK: - Initialization
    
    init(vaultRegistry: VaultRegistry = .shared) {
        self.vaultRegistry = vaultRegistry
    }
    
    // MARK: - Contradiction Detection
    
    /// Detects contradictions between incoming text and existing vault facts.
    /// - Parameters:
    ///   - incomingText: The new text to check for contradictions
    ///   - vaultIdentity: Which vault to check against
    /// - Returns: Array of detected contradictions
    func detectContradictions(
        incomingText: String,
        in vaultIdentity: VaultIdentity
    ) async -> [VaultContradiction] {
        guard let vaultPath = vaultRegistry.resolveVaultPath(for: vaultIdentity) else {
            Logger.vault.warning("Cannot detect contradictions: vault not found for \(vaultIdentity.displayName, privacy: .public)")
            return []
        }
        
        isDetecting = true
        defer { isDetecting = false }
        
        do {
            // Load existing facts from the vault's knowledge files
            let existingFacts = try await loadExistingFacts(from: vaultPath)
            
            // Convert to FFI format
            let ffiFacts = existingFacts.map { fact in
                VaultFactFFI(
                    filePath: fact.filePath,
                    section: fact.section,
                    content: fact.content,
                    strength: fact.strength,
                    lastAccessedEpoch: fact.lastAccessed.timeIntervalSince1970
                )
            }
            
            // Run contradiction detection through the shared vault bridge.
            let ffiContradictions = detectVaultContradictions(
                incoming: incomingText,
                existingFacts: ffiFacts
            )
            
            // Convert back to Swift types
            let contradictions = ffiContradictions.map { VaultContradiction(from: $0) }
            
            // Add to pending
            await MainActor.run {
                self.pendingContradictions.append(contentsOf: contradictions)
            }
            
            Logger.vault.info("Detected \(contradictions.count) contradictions in \(vaultIdentity.displayName, privacy: .public)")
            return contradictions
            
        } catch {
            Logger.vault.error("Failed to detect contradictions: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Checks a memory write operation for contradictions before applying.
    /// - Parameters:
    ///   - operation: The memory operation being performed
    ///   - vaultIdentity: Target vault
    /// - Returns: Contradictions that would be created, or empty if safe
    func preflightCheck(
        operation: MemoryWriteOperation,
        in vaultIdentity: VaultIdentity
    ) async -> [VaultContradiction] {
        let incomingText = formatOperationForCheck(operation)
        return await detectContradictions(incomingText: incomingText, in: vaultIdentity)
    }
    
    // MARK: - Resolution
    
    /// Resolves a contradiction with the specified strategy.
    /// - Parameters:
    ///   - contradiction: The contradiction to resolve
    ///   - resolution: The resolution strategy
    func resolveContradiction(
        _ contradiction: VaultContradiction,
        with resolution: ConflictResolution
    ) async {
        do {
            switch resolution {
            case .keepExisting:
                // Discard incoming, keep existing
                Logger.vault.info("Resolved contradiction: kept existing fact")
                
            case .acceptNew:
                // Replace existing with incoming
                try await replaceFact(contradiction)
                
            case .keepBoth:
                // Keep both with clarification
                try await mergeFacts(contradiction)
            }
            
            // Record resolution
            let resolved = ResolvedContradiction(
                original: contradiction,
                resolution: resolution,
                timestamp: Date()
            )
            resolvedContradictions.append(resolved)
            
            // Remove from pending
            pendingContradictions.removeAll { $0.id == contradiction.id }
            
        } catch {
            Logger.vault.error("Failed to resolve contradiction: \(error.localizedDescription)")
        }
    }
    
    /// Resolves all pending contradictions at once.
    /// - Parameter resolution: Strategy to apply to all
    func resolveAllPending(with resolution: ConflictResolution) async {
        for contradiction in pendingContradictions {
            await resolveContradiction(contradiction, with: resolution)
        }
    }
    
    // MARK: - Private Helpers
    
    private func loadExistingFacts(from vaultPath: String) async throws -> [VaultFact] {
        // Load from memory/knowledge.md and memory/decisions.md
        let knowledgePath = (vaultPath as NSString).appendingPathComponent("memory/knowledge.md")
        let decisionsPath = (vaultPath as NSString).appendingPathComponent("memory/decisions.md")
        
        var facts: [VaultFact] = []
        
        // Parse knowledge file
        if FileManager.default.fileExists(atPath: knowledgePath) {
            let content = try String(contentsOfFile: knowledgePath, encoding: .utf8)
            facts.append(contentsOf: parseFacts(from: content, filePath: "memory/knowledge.md"))
        }
        
        // Parse decisions file
        if FileManager.default.fileExists(atPath: decisionsPath) {
            let content = try String(contentsOfFile: decisionsPath, encoding: .utf8)
            facts.append(contentsOf: parseFacts(from: content, filePath: "memory/decisions.md"))
        }
        
        return facts
    }
    
    private func parseFacts(from content: String, filePath: String) -> [VaultFact] {
        // Parse markdown sections into facts
        // Format: ## Section Title followed by bullet points
        var facts: [VaultFact] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentSection = "General"
        var currentContent = ""
        
        for line in lines {
            if line.hasPrefix("## ") {
                // Save previous section
                if !currentContent.isEmpty {
                    facts.append(VaultFact(
                        filePath: filePath,
                        section: currentSection,
                        content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        strength: 0.8,
                        lastAccessed: Date()
                    ))
                }
                currentSection = String(line.dropFirst(3))
                currentContent = ""
            } else if line.hasPrefix("- ") {
                currentContent += line + "\n"
            }
        }
        
        // Don't forget last section
        if !currentContent.isEmpty {
            facts.append(VaultFact(
                filePath: filePath,
                section: currentSection,
                content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                strength: 0.8,
                lastAccessed: Date()
            ))
        }
        
        return facts
    }
    
    private func formatOperationForCheck(_ operation: MemoryWriteOperation) -> String {
        switch operation {
        case .add(let content):
            return content
        case .update(let path, let content):
            return "Update \(path): \(content)"
        case .delete(let path):
            return "Delete \(path)"
        }
    }
    
    private func replaceFact(_ contradiction: VaultContradiction) async throws {
        throw ContradictionResolutionError.vaultWriteUnavailable(
            "accepting new facts is not wired to a vault write path for \(contradiction.existingFilePath)"
        )
    }
    
    private func mergeFacts(_ contradiction: VaultContradiction) async throws {
        throw ContradictionResolutionError.vaultWriteUnavailable(
            "keeping both facts is not wired to a vault write path for \(contradiction.existingFilePath)"
        )
    }
}

// MARK: - Supporting Types

private enum ContradictionResolutionError: LocalizedError {
    case vaultWriteUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .vaultWriteUnavailable(let message):
            return message
        }
    }
}

enum MemoryWriteOperation {
    case add(content: String)
    case update(path: String, content: String)
    case delete(path: String)
}

struct VaultFact {
    let filePath: String
    let section: String
    let content: String
    let strength: Double
    let lastAccessed: Date
}

struct ResolvedContradiction: Identifiable {
    let id = UUID()
    let original: VaultContradiction
    let resolution: ConflictResolution
    let timestamp: Date
}

// MARK: - Logger Extension

extension Logger {
    fileprivate static let vault = Logger(subsystem: "com.epistemos", category: "VaultContradiction")
}
