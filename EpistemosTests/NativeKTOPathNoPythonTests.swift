import Testing
import Foundation

@testable import Epistemos

// SS-LS 1b brick 7 (THE FINISH) — KTOTrainer no longer spawns /usr/bin/python3; the
// KTO update runs natively (NativeKTOTrainer). This witnesses the native path: no
// Process / Python anywhere in the KTO trainer, and the native trainer is invoked.
// 1b is "done" only when the spawn is gone AND this test witnesses the native path.
@Suite("KTO native path — no Python spawn (SS-LS 1b)")
struct NativeKTOPathNoPythonTests {

    @Test("KTOTrainer spawns no Python and routes the KTO update to the native trainer")
    func ktoTrainerHasNoPythonSpawn() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/KnowledgeFusion/Alignment/KTOTrainer.swift"
        )
        // The Python subprocess is gone — no executable, no Process, no script, no env.
        #expect(!src.contains("/usr/bin/python3"))
        #expect(!src.contains("Process("))
        #expect(!src.contains("process.run"))
        #expect(!src.contains("train_kto.py"))
        #expect(!src.contains("pythonPath"))
        #expect(!src.contains("PythonEnvironmentManager"))
        // The KTO update is routed to the native, in-process trainer.
        #expect(src.contains("NativeKTOTrainer.train"))
        #expect(src.contains("NativeKTODataPrep.loadFeedbackExamples"))
    }

    @Test("the scheduler constructs KTOTrainer with no python configuration")
    func schedulerUsesNativeKTOTrainer() throws {
        let src = try loadMirroredSourceTextFile(
            "Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift"
        )
        #expect(src.contains("let ktoTrainer = KTOTrainer()"))
        #expect(!src.contains("pythonPath: pyEnv"))
    }
}
