import SwiftUI

nonisolated enum A2UIComponentKind: String, Codable, Sendable, CaseIterable, Hashable {
    case noteCard = "NoteCard"
}

nonisolated enum A2UIRetractionStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case active
    case atRisk
    case retracted
    case unknown
}

nonisolated struct A2UIEvidenceItem: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let excerpt: String
}

nonisolated struct A2UINoteCardProps: Codable, Sendable, Hashable {
    let claimId: String
    let title: String
    let body: String
    let evidence: [A2UIEvidenceItem]
    let retractionStatus: A2UIRetractionStatus
}

nonisolated enum A2UIComponentProps: Codable, Sendable, Hashable {
    case noteCard(A2UINoteCardProps)
}

nonisolated struct A2UIComponent: Sendable, Hashable, Identifiable {
    let id: String
    let kind: A2UIComponentKind
    let props: A2UIComponentProps

    static func noteCard(id: String, props: A2UINoteCardProps) -> A2UIComponent {
        A2UIComponent(id: id, kind: .noteCard, props: .noteCard(props))
    }
}

enum A2UICatalog {
    nonisolated static let allComponents: [A2UIComponentKind] = [.noteCard]

    nonisolated static func payload(for component: A2UIComponent) -> GenUIPayload {
        switch component.props {
        case let .noteCard(props):
            let evidenceRows = props.evidence.map { item in
                [item.id, item.title, item.excerpt]
            }
            let claim = GenUIPayload(
                schema: .keyValueTable,
                title: "Claim",
                body: .keyValues([
                    GenUIKeyValue("id", props.claimId),
                    GenUIKeyValue("status", props.retractionStatus.rawValue),
                    GenUIKeyValue("body", props.body),
                ]),
                metadata: ["a2ui.component": component.kind.rawValue]
            )
            let evidence = GenUIPayload(
                schema: .table,
                title: "Evidence",
                body: .rows(headers: ["id", "title", "excerpt"], cells: evidenceRows),
                metadata: ["a2ui.component": component.kind.rawValue]
            )
            return GenUIPayload(
                schema: .provenanceTrace,
                title: props.title,
                body: .provenanceChain([claim, evidence]),
                metadata: [
                    "a2ui.component": component.kind.rawValue,
                    "claim.id": props.claimId,
                ]
            )
        }
    }

    @MainActor
    @ViewBuilder
    static func render(_ component: A2UIComponent) -> some View {
        switch component.props {
        case let .noteCard(props):
            A2UINoteCard(props: props)
        }
    }
}
