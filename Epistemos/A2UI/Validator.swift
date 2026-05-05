import Foundation

nonisolated struct A2UIValidationFailure: Error, Codable, Sendable, Hashable {
    let code: String
    let schema: String
    let reason: String

    init(schema: String, reason: String, code: String = "VALIDATION_FAILED") {
        self.code = code
        self.schema = schema
        self.reason = reason
    }

    var auditPayload: GenUIPayload {
        GenUIPayload(
            schema: .errorReport,
            title: "A2UI validation failed",
            body: .error(
                title: "A2UI validation failed",
                detail: "\(schema): \(reason)",
                hint: "Regenerate against the closed A2UI catalog.",
                options: []
            )
        )
    }
}

nonisolated enum A2UIValidationResult: Sendable, Hashable {
    case accepted(A2UIComponent)
    case rejected(A2UIValidationFailure)

    var acceptedComponent: A2UIComponent? {
        if case let .accepted(component) = self {
            component
        } else {
            nil
        }
    }

    var validationFailure: A2UIValidationFailure? {
        if case let .rejected(failure) = self {
            failure
        } else {
            nil
        }
    }
}

nonisolated enum A2UIValidator {
    private struct Header: Decodable {
        let component: String
    }

    private struct NoteCardEnvelope: Decodable {
        let id: String
        let component: String
        let claimId: String
        let title: String
        let body: String
        let evidence: [A2UIEvidenceItem]
        let retractionStatus: A2UIRetractionStatus
    }

    static func validate(_ component: A2UIComponent) -> A2UIValidationResult {
        guard A2UICatalog.allComponents.contains(component.kind) else {
            return .rejected(A2UIValidationFailure(
                schema: component.kind.rawValue,
                reason: "Component is not registered."
            ))
        }
        return .accepted(component)
    }

    static func validateComponentJSON(_ data: Data) -> A2UIValidationResult {
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data) else {
            return .rejected(A2UIValidationFailure(
                schema: "unknown",
                reason: "Missing component discriminator."
            ))
        }
        guard let kind = A2UIComponentKind(rawValue: header.component) else {
            return .rejected(A2UIValidationFailure(
                schema: header.component,
                reason: "Unknown component."
            ))
        }

        switch kind {
        case .noteCard:
            guard let envelope = try? decoder.decode(NoteCardEnvelope.self, from: data) else {
                return .rejected(A2UIValidationFailure(
                    schema: kind.rawValue,
                    reason: "NoteCard payload does not match schema."
                ))
            }
            let props = A2UINoteCardProps(
                claimId: envelope.claimId,
                title: envelope.title,
                body: envelope.body,
                evidence: envelope.evidence,
                retractionStatus: envelope.retractionStatus
            )
            return validate(.noteCard(id: envelope.id, props: props))
        }
    }
}
