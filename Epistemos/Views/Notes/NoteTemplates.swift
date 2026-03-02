import Foundation

// MARK: - Note Template Model

struct NoteTemplate: Identifiable {
    let id: String
    let title: String
    let icon: String
    let subtitle: String
    /// Short preview lines shown on the card (3-4 lines, plain text).
    let preview: [String]
    /// Full markdown body inserted into the editor.
    let body: String
}

// MARK: - Built-in Templates

enum NoteTemplates {

    static let all: [NoteTemplate] = [
        brainDump,
        meetingNotes,
        researchPaper,
        weeklyReview,
        readingNotes,
        projectPlan,
    ]

    // MARK: Brain Dump

    private static let brainDump = NoteTemplate(
        id: "brain-dump",
        title: "Brain Dump",
        icon: "brain.head.profile",
        subtitle: "Stream-of-consciousness capture",
        preview: [
            "# Brain Dump",
            "> Just start writing...",
            "## Threads to pull on",
            "## What surprised me",
        ],
        body: """
        # Brain Dump — \(todayString)

        > Don't edit, don't filter — just write. You can organize later.

        ---



        ---

        ## Threads to pull on
        > Re-read what you wrote above. Which ideas have energy? List them here.

        -
        -
        -

        ## What surprised me
        > Often the best ideas are the ones you didn't expect to write.


        ## Connections
        > Link to related notes: [[]]

        """
    )

    // MARK: Meeting Notes

    private static let meetingNotes = NoteTemplate(
        id: "meeting-notes",
        title: "Meeting Notes",
        icon: "person.3.fill",
        subtitle: "Decisions, actions & follow-ups",
        preview: [
            "# Meeting Notes",
            "## Agenda  /  ## Decisions",
            "- [ ] Action items with owners",
            "## Follow-up — next steps",
        ],
        body: """
        # Meeting Notes — \(todayString)

        **Meeting:**
        **Attendees:**
        **Duration:**

        ---

        ## Agenda
        1.
        2.
        3.

        ## Discussion
        > Capture key points, not transcripts. Tag people with **@Name**.

        ### Topic 1:
        -
        -

        ### Topic 2:
        -
        -

        ## Decisions
        > What was agreed? Be specific — future-you needs clarity.

        - **Decision:**
          - Context:
          - Owner:

        ## Action Items
        - [ ] **@** —
        - [ ] **@** —
        - [ ] **@** —

        ## Parking Lot
        > Ideas raised but not discussed — carry forward to next meeting.

        -

        ## Follow-up
        - **Next meeting:**
        - **Pre-work for next time:**

        ---
        *See also:* [[]]
        """
    )

    // MARK: Research Paper

    private static let researchPaper = NoteTemplate(
        id: "research-paper",
        title: "Research Paper",
        icon: "doc.text.magnifyingglass",
        subtitle: "Structured research scaffold",
        preview: [
            "# Research: [Topic]",
            "## Thesis  /  ## Methodology",
            "## Evidence & analysis",
            "## Sources with annotations",
        ],
        body: """
        # Research: [Topic]

        **Status:** Draft
        **Last updated:** \(todayString)

        ## Abstract
        > One paragraph summarizing the research question, approach, and key finding.


        ## Research Question
        > What specific question are you trying to answer?


        ## Thesis
        > Your working hypothesis — it's OK if this evolves.


        ## Background
        > What context does a reader need? What's already known?

        -
        -

        ## Methodology
        > How are you investigating this? What sources, experiments, or analyses?

        1.
        2.

        ## Evidence & Analysis

        ### Supporting evidence
        - **Finding:**
          - Source:
          - Significance:

        - **Finding:**
          - Source:
          - Significance:

        ### Contradicting evidence
        - **Finding:**
          - Source:
          - Why it matters:

        ## Key Arguments
        1.
        2.
        3.

        ## Conclusions
        > What did you find? How confident are you? What remains uncertain?


        ## Open Questions
        - [ ]
        - [ ]

        ## Sources
        > Use `[[note title]]` to link to source notes.

        1. **[Author]** — *[Title]* ([Year]). [[]]
        2. **[Author]** — *[Title]* ([Year]). [[]]
        3. **[Author]** — *[Title]* ([Year]). [[]]

        ## Related Notes
        - [[]]
        """
    )

    // MARK: Weekly Review

    private static let weeklyReview = NoteTemplate(
        id: "weekly-review",
        title: "Weekly Review",
        icon: "calendar.badge.checkmark",
        subtitle: "Reflect, reset, refocus",
        preview: [
            "# Weekly Review",
            "## Wins  /  ## Struggles",
            "## Energy audit (what drained me?)",
            "## Next week's top 3",
        ],
        body: """
        # Weekly Review — \(weekString)

        > Take 15 minutes. Be honest with yourself.

        ## Wins
        > What went well? What are you proud of?

        -
        -
        -

        ## Struggles
        > What was hard? What didn't go as planned?

        -
        -

        ## Lessons Learned
        > If you could tell last-Monday-you one thing, what would it be?


        ## Energy Audit
        > What gave you energy this week? What drained it?

        | Energizing | Draining |
        |------------|----------|
        |            |          |
        |            |          |

        ## Loose Ends
        > Unfinished tasks or dangling threads to carry forward.

        - [ ]
        - [ ]
        - [ ]

        ## Next Week's Top 3
        > If you could only accomplish three things next week, what would they be?

        1. **#1:**
        2. **#2:**
        3. **#3:**

        ## Gratitude
        > One thing you're grateful for this week.


        ---
        *Previous review:* [[]]
        """
    )

    // MARK: Reading Notes

    private static let readingNotes = NoteTemplate(
        id: "reading-notes",
        title: "Reading Notes",
        icon: "book.fill",
        subtitle: "Capture ideas from any source",
        preview: [
            "# Reading: [Title]",
            "## Key ideas with page refs",
            "## Quotes I want to remember",
            "## How this connects to...",
        ],
        body: """
        # Reading: [Title]

        **Author:**
        **Type:** Book / Article / Paper / Podcast / Video
        **Date read:** \(todayString)
        **Rating:** /5

        ## Why I'm reading this
        > What question or curiosity brought you here?


        ## Summary
        > In 2-3 sentences, what is this about?


        ## Key Ideas

        ### Idea 1:
        > Page/timestamp:

        -

        ### Idea 2:
        > Page/timestamp:

        -

        ### Idea 3:
        > Page/timestamp:

        -

        ## Quotes
        > Passages worth remembering verbatim.

        > "[Quote]" — p.

        > "[Quote]" — p.

        ## My Reactions
        > What do you agree with? Disagree with? What surprised you?


        ## How This Connects
        > Link to existing notes, ideas, or projects this relates to.

        - Reminds me of [[]]
        - Contradicts [[]]
        - Useful for [[]]

        ## Action Items
        > What will you do differently because of this?

        - [ ]
        - [ ]

        ---
        *Source:* [[]]
        """
    )

    // MARK: Project Plan

    private static let projectPlan = NoteTemplate(
        id: "project-plan",
        title: "Project Plan",
        icon: "checklist",
        subtitle: "Scope, milestones & tracking",
        preview: [
            "# Project: [Name]",
            "## Goal / success criteria",
            "## Milestones with checkboxes",
            "## Risks & mitigations",
        ],
        body: """
        # Project: [Name]

        **Status:** Planning
        **Owner:**
        **Started:** \(todayString)
        **Target completion:**

        ## Goal
        > What does "done" look like? Be specific.


        ## Success Criteria
        > How will you know this succeeded?

        - [ ]
        - [ ]
        - [ ]

        ## Scope
        > What's included? What's explicitly NOT included?

        ### In scope
        -
        -

        ### Out of scope
        -
        -

        ## Milestones

        ### Phase 1:
        - [ ]
        - [ ]
        - [ ]

        ### Phase 2:
        - [ ]
        - [ ]

        ### Phase 3:
        - [ ]
        - [ ]

        ## Resources
        > People, tools, budget, dependencies.

        -
        -

        ## Risks & Mitigations
        > What could go wrong? What's your plan B?

        | Risk | Impact | Mitigation |
        |------|--------|------------|
        |      |        |            |
        |      |        |            |

        ## Open Questions
        - [ ]
        - [ ]

        ## Log
        > Running journal of progress, decisions, and pivots.

        ### \(todayString)
        - Project created

        ---
        *Related:* [[]]
        """
    )

    // MARK: - Date Helpers

    private static var todayString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: Date())
    }

    private static var weekString: String {
        let f = DateFormatter()
        f.dateFormat = "'W'ww, yyyy"
        return f.string(from: Date())
    }
}
