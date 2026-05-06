// EditorSkillChips.swift
//
// Skill chip selector shown above the ask bar when a code file is active.
// Selecting a skill prepends its system prompt and limits available tools.
// Generic chip grid pattern extracted from LocalAgentSkillsView.
//
// 2026-04-06.

import SwiftUI

// MARK: - Editor Skill Chip Bar

struct EditorSkillChips: View {
    @Binding var selectedSkill: EditorSkill?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EditorSkill.allCases) { skill in
                    skillChip(skill)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func skillChip(_ skill: EditorSkill) -> some View {
        let isSelected = selectedSkill == skill
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8)) {
                selectedSkill = (selectedSkill == skill) ? nil : skill
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: skill.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(skill.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}
