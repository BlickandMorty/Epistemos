//
//  AtomicVaultWriter.swift
//  Epistemos — KEELSTONE spine
//
//  The durable write core. Every note write goes through here. Never call
//  Data.write(atomically:) or String.write(to:) directly against a vault file —
//  those can truncate on a mid-write kill, and they don't coordinate with
//  iCloud's daemon or with a registered NSFilePresenter.
//
//  Contract (all three parts are mandatory):
//    1. Coordinate — wrap the write in NSFileCoordinator .forReplacing so the
//       app and any sync daemon / presenter don't collide.
//    2. Temp-then-replace — write bytes to a scratch file in an item-replacement
//       directory on the SAME volume, then FileManager.replaceItemAt. On APFS
//       this is an atomic rename: after a crash you get the OLD full file or the
//       NEW full file, never a truncated interleave.
//    3. Off @MainActor — replace/move are synchronous filesystem ops; this whole
//       type is an actor so they never run on the main thread.
//
//  Beginning an activity around the write keeps a suspended/App-Nap'd process
//  from being torn down mid-commit (the 0xDEAD10CC / file-lock-on-suspension
//  failure mode; primarily a concern for the Experimental helper, cheap
//  insurance everywhere).
//

import Foundation

public enum AtomicWriteError: Error, Sendable {
    case coordination(Error)
    case write(Error)
    case replace(Error)
}

public actor AtomicVaultWriter {

    public init() {}

    /// Atomically replace the contents of `targetURL` with `content`.
    /// `targetURL` must already be inside a security-scoped, access-held vault.
    public func write(_ content: String, to targetURL: URL) throws {
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Epistemos atomic note commit"
        )
        defer { ProcessInfo.processInfo.endActivity(activity) }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var thrown: Error?

        coordinator.coordinate(
            writingItemAt: targetURL,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                let fm = FileManager.default

                // Scratch dir on the SAME volume as the target — required for
                // the replace to be an atomic rename rather than a copy.
                let scratchDir = try fm.url(
                    for: .itemReplacementDirectory,
                    in: .userDomainMask,
                    appropriateFor: coordinatedURL,
                    create: true
                )
                defer { try? fm.removeItem(at: scratchDir) }

                let scratch = scratchDir.appendingPathComponent(
                    UUID().uuidString + "." + coordinatedURL.pathExtension
                )

                do {
                    try content.write(to: scratch, atomically: false, encoding: .utf8)
                } catch {
                    thrown = AtomicWriteError.write(error)
                    return
                }

                do {
                    _ = try fm.replaceItemAt(
                        coordinatedURL,
                        withItemAt: scratch,
                        backupItemName: nil,
                        options: [.usingNewMetadataOnly]
                    )
                } catch {
                    thrown = AtomicWriteError.replace(error)
                    return
                }
            } catch {
                thrown = AtomicWriteError.write(error)
            }
        }

        if let coordinationError { throw AtomicWriteError.coordination(coordinationError) }
        if let thrown { throw thrown }
    }
}
