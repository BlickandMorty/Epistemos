import Foundation
import Testing
@testable import Epistemos

@Suite("A2UI closed catalog")
struct A2UICatalogTests {
    @Test("Phase 1 catalog validates NoteCard and renders through typed payload")
    func noteCardValidatesAndProjectsToGenUIPayload() throws {
        let props = A2UINoteCardProps(
            claimId: "claim-alpha",
            title: "D3 claim",
            body: "A closed catalog renders the claim instead of inspecting raw JSON.",
            evidence: [
                A2UIEvidenceItem(id: "ev-1", title: "Execution map", excerpt: "D3 requires NoteCard.")
            ],
            retractionStatus: .active
        )
        let component = A2UIComponent.noteCard(id: "root", props: props)

        let validated = try #require(A2UIValidator.validate(component).acceptedComponent)
        #expect(validated.kind == .noteCard)
        #expect(A2UICatalog.allComponents == [.noteCard])

        let payload = A2UICatalog.payload(for: validated)
        #expect(payload.schema == .provenanceTrace)
        #expect(payload.title == "D3 claim")
    }

    @Test("Unknown component returns A2UIValidationFailure audit payload")
    func unknownComponentReturnsValidationFailure() throws {
        let data = Data(#"{"id":"root","component":"RawInspector","title":"Nope"}"#.utf8)
        let failure = try #require(A2UIValidator.validateComponentJSON(data).validationFailure)

        #expect(failure.code == "VALIDATION_FAILED")
        #expect(failure.schema == "RawInspector")
        #expect(failure.auditPayload.schema == .errorReport)
        #expect(failure.auditPayload.title.contains("A2UI validation failed"))
    }

    @Test("A2UI catalog has no AnyView or fallback renderer")
    func sourceGuardNoAnyViewOrFallbackRenderer() throws {
        let files = [
            "Epistemos/A2UI/Catalog.swift",
            "Epistemos/A2UI/Validator.swift",
            "Epistemos/A2UI/Components/NoteCard.swift",
        ]
        let joined = try files
            .map(loadMirroredSourceTextFile)
            .joined(separator: "\n")

        #expect(!joined.contains("AnyView"), "A2UI must stay on typed SwiftUI render paths")
        #expect(!joined.contains("Fallback"), "A2UI unknown schemas must fail validation, not fall back")
        #expect(joined.contains("A2UIValidationFailure"), "Unknown schemas must emit audit findings")
    }
}
