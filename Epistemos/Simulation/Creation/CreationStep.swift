//
//  CreationStep.swift
//  Simulation Mode S8 — compile-time route enum for the §6.1
//  8-step companion creation wizard.
//
//  Per DOCTRINE I-15 production hot paths must NOT use string-keyed
//  dispatch or `AnyView`. The creation flow uses a typed
//  `CreationStepRoute` instead so SwiftUI's NavigationStack picks
//  the destination view via a switch — no AnyView, no
//  string-keyed type lookup, no allocation surprises.
//

import Foundation

/// 8 wizard steps + the start-tile preset picker per §6.1.
public enum CreationStepRoute: Hashable, Sendable, CaseIterable {
    /// Step 1 — preset picker. Doubles as the wizard root, so
    /// `NavigationStack(path:)` is empty when the user is on
    /// this step.
    case presetPick
    /// Step 2.
    case headShape
    /// Step 3.
    case palette
    /// Step 4.
    case eyes
    /// Step 5.
    case arms
    /// Step 6.
    case prop
    /// Step 7.
    case workspace
    /// Step 8.
    case name
    /// Final review / commit screen — what the user sees before
    /// pressing "Create" to fire the §6.3 transaction.
    case review

    /// Human label for the wizard progress chrome (top of the
    /// sheet). Order matches the §6.1 step list.
    public var label: String {
        switch self {
        case .presetPick: return "Start"
        case .headShape:  return "Head"
        case .palette:    return "Palette"
        case .eyes:       return "Eyes"
        case .arms:       return "Arms"
        case .prop:       return "Prop"
        case .workspace:  return "Workspace"
        case .name:       return "Name"
        case .review:     return "Review"
        }
    }

    /// Step index 1…9 for the progress strip. `presetPick` is
    /// step 1; `review` is the post-step-8 commit screen.
    public var stepNumber: Int {
        switch self {
        case .presetPick: return 1
        case .headShape:  return 2
        case .palette:    return 3
        case .eyes:       return 4
        case .arms:       return 5
        case .prop:       return 6
        case .workspace:  return 7
        case .name:       return 8
        case .review:     return 9
        }
    }

    /// Canonical sequence of routes the user advances through.
    public static let sequence: [CreationStepRoute] = [
        .presetPick, .headShape, .palette, .eyes, .arms, .prop,
        .workspace, .name, .review,
    ]

    /// Next step in canonical order, or `nil` at the terminal
    /// `review` step.
    public var next: CreationStepRoute? {
        guard let idx = Self.sequence.firstIndex(of: self) else { return nil }
        let next = idx + 1
        return next < Self.sequence.count ? Self.sequence[next] : nil
    }
}
