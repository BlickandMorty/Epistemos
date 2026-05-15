import Foundation

// SCAFFOLD ONLY — RCA-P2-010 classification 2026-05-14.
//
// Static data table for a slash-menu KaTeX-snippet picker that the
// Tiptap WKWebView editor *would* surface, but the runtime hookup
// (W7.7 — bridge call from KaTeX node to this table) is not wired
// in the shipping build. 0 external Swift callers as of audit
// 2026-05-14. Kept in source as the canonical curated subset
// (~50 entries) so the eventual W7.7 wiring has a single truth
// to import; the table is pure data with no rendering logic.
//
// Re-promote to ACTIVE when the Tiptap math node bridge actually
// requests slash-snippet templates via `KaTeXSnippet.curated()`.
//
// MARK: - KaTeXSnippets
//
// Wave 7.10 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.10,
//  cross-ref Smaug6739/Alexandrie 2026-04-26 scan).
//
// Slash-menu data source for the Tiptap WKWebView editor. Each
// snippet has a slash-trigger (e.g. `/sqrt`), a human-readable
// label (`"Square root √"`), and a LaTeX template inserted into
// the active math node when picked. Templates use `${1}` /
// `${2}` placeholder markers that the Tiptap snippet runtime
// (W7.7 follow-up) jumps the cursor to in order.
//
// Borrowed wholesale from Alexandrie's
// `frontend/app/components/MarkdownEditor/katex-snippets.ts`. We
// pin a curated subset (~50 entries) — the upstream list runs to
// hundreds and most are exotic. The slash-menu's autocomplete
// surfaces the rest from KaTeX's own macro registry at runtime.
//
// Pure data: no rendering logic. The Tiptap math node calls
// `katex.renderToString(template)` after substitution.

nonisolated public struct KaTeXSnippet: Sendable, Hashable {
    /// Slash-trigger as the user types it (without the leading `/`).
    /// Lowercase, ASCII, no spaces.
    public let trigger: String
    /// Display label in the slash-menu UI.
    public let label: String
    /// LaTeX template body. May contain `${1}` / `${2}` placeholders
    /// the Tiptap snippet runtime jumps through after insertion.
    public let template: String
    /// Brief description tooltip (one line).
    public let description: String

    public init(trigger: String, label: String, template: String, description: String) {
        self.trigger = trigger
        self.label = label
        self.template = template
        self.description = description
    }
}

nonisolated public enum KaTeXSnippets {

    /// Curated KaTeX snippet catalogue surfaced by the editor's
    /// slash-menu when the cursor is inside a math node. Order
    /// matters — the menu renders entries top-to-bottom; the most
    /// commonly used macros sit at the top.
    public static let all: [KaTeXSnippet] = [
        // — Roots, exponents, fractions —
        KaTeXSnippet(trigger: "sqrt", label: "Square root √",
                     template: "\\sqrt{${1}}", description: "Square root of an expression"),
        KaTeXSnippet(trigger: "cbrt", label: "Cube root ∛",
                     template: "\\sqrt[3]{${1}}", description: "Cube root"),
        KaTeXSnippet(trigger: "nthroot", label: "n-th root",
                     template: "\\sqrt[${1}]{${2}}", description: "Generic n-th root"),
        KaTeXSnippet(trigger: "frac", label: "Fraction a/b",
                     template: "\\frac{${1}}{${2}}", description: "Fraction with numerator + denominator"),
        KaTeXSnippet(trigger: "tfrac", label: "Inline fraction (tight)",
                     template: "\\tfrac{${1}}{${2}}", description: "Smaller, inline-friendly fraction"),
        KaTeXSnippet(trigger: "dfrac", label: "Display fraction (large)",
                     template: "\\dfrac{${1}}{${2}}", description: "Display-style large fraction"),
        KaTeXSnippet(trigger: "exp", label: "Exponent e^x",
                     template: "e^{${1}}", description: "Natural exponential"),
        KaTeXSnippet(trigger: "pow", label: "Power x^n",
                     template: "{${1}}^{${2}}", description: "Generic exponent"),
        KaTeXSnippet(trigger: "sub", label: "Subscript x_n",
                     template: "{${1}}_{${2}}", description: "Generic subscript"),

        // — Sums, products, integrals —
        KaTeXSnippet(trigger: "sum", label: "Summation Σ",
                     template: "\\sum_{${1}=${2}}^{${3}} ${4}", description: "Indexed summation"),
        KaTeXSnippet(trigger: "prod", label: "Product ∏",
                     template: "\\prod_{${1}=${2}}^{${3}} ${4}", description: "Indexed product"),
        KaTeXSnippet(trigger: "integral", label: "Definite integral ∫",
                     template: "\\int_{${1}}^{${2}} ${3}\\,d${4}", description: "Definite integral"),
        KaTeXSnippet(trigger: "iintegral", label: "Indefinite integral ∫",
                     template: "\\int ${1}\\,d${2}", description: "Indefinite integral"),
        KaTeXSnippet(trigger: "oint", label: "Contour integral ∮",
                     template: "\\oint_{${1}} ${2}\\,d${3}", description: "Contour / line integral"),
        KaTeXSnippet(trigger: "lim", label: "Limit lim",
                     template: "\\lim_{${1} \\to ${2}} ${3}", description: "Limit as x → value"),

        // — Greek letters —
        KaTeXSnippet(trigger: "alpha",   label: "α alpha",   template: "\\alpha",   description: "Greek alpha"),
        KaTeXSnippet(trigger: "beta",    label: "β beta",    template: "\\beta",    description: "Greek beta"),
        KaTeXSnippet(trigger: "gamma",   label: "γ gamma",   template: "\\gamma",   description: "Greek gamma"),
        KaTeXSnippet(trigger: "delta",   label: "δ delta",   template: "\\delta",   description: "Greek delta"),
        KaTeXSnippet(trigger: "epsilon", label: "ε epsilon", template: "\\epsilon", description: "Greek epsilon"),
        KaTeXSnippet(trigger: "theta",   label: "θ theta",   template: "\\theta",   description: "Greek theta"),
        KaTeXSnippet(trigger: "lambda",  label: "λ lambda",  template: "\\lambda",  description: "Greek lambda"),
        KaTeXSnippet(trigger: "mu",      label: "μ mu",      template: "\\mu",      description: "Greek mu"),
        KaTeXSnippet(trigger: "pi",      label: "π pi",      template: "\\pi",      description: "Greek pi"),
        KaTeXSnippet(trigger: "sigma",   label: "σ sigma",   template: "\\sigma",   description: "Greek sigma"),
        KaTeXSnippet(trigger: "phi",     label: "φ phi",     template: "\\phi",     description: "Greek phi"),
        KaTeXSnippet(trigger: "omega",   label: "ω omega",   template: "\\omega",   description: "Greek omega"),

        // — Operators + relations —
        KaTeXSnippet(trigger: "infty", label: "Infinity ∞",
                     template: "\\infty", description: "Infinity symbol"),
        KaTeXSnippet(trigger: "neq", label: "≠ not equal",
                     template: "\\neq", description: "Not equal to"),
        KaTeXSnippet(trigger: "leq", label: "≤ less or equal",
                     template: "\\leq", description: "Less than or equal"),
        KaTeXSnippet(trigger: "geq", label: "≥ greater or equal",
                     template: "\\geq", description: "Greater than or equal"),
        KaTeXSnippet(trigger: "approx", label: "≈ approx",
                     template: "\\approx", description: "Approximately equal"),
        KaTeXSnippet(trigger: "equiv", label: "≡ equivalent",
                     template: "\\equiv", description: "Equivalent to / congruent"),
        KaTeXSnippet(trigger: "in", label: "∈ in",
                     template: "\\in", description: "Element of a set"),
        KaTeXSnippet(trigger: "notin", label: "∉ not in",
                     template: "\\notin", description: "Not an element of"),
        KaTeXSnippet(trigger: "subset", label: "⊂ subset",
                     template: "\\subset", description: "Proper subset"),
        KaTeXSnippet(trigger: "supset", label: "⊃ superset",
                     template: "\\supset", description: "Proper superset"),
        KaTeXSnippet(trigger: "cup", label: "∪ union",
                     template: "\\cup", description: "Set union"),
        KaTeXSnippet(trigger: "cap", label: "∩ intersection",
                     template: "\\cap", description: "Set intersection"),
        KaTeXSnippet(trigger: "to", label: "→ to",
                     template: "\\to", description: "Right arrow / mapping"),
        KaTeXSnippet(trigger: "implies", label: "⟹ implies",
                     template: "\\implies", description: "Logical implies"),

        // — Vectors, matrices, derivatives —
        KaTeXSnippet(trigger: "vec", label: "Vector ⃗",
                     template: "\\vec{${1}}", description: "Vector overarrow"),
        KaTeXSnippet(trigger: "hat", label: "Hat ̂",
                     template: "\\hat{${1}}", description: "Hat / unit vector"),
        KaTeXSnippet(trigger: "bar", label: "Bar ̄",
                     template: "\\bar{${1}}", description: "Overbar"),
        KaTeXSnippet(trigger: "dot", label: "Dot derivative",
                     template: "\\dot{${1}}", description: "Time derivative"),
        KaTeXSnippet(trigger: "ddot", label: "Double-dot derivative",
                     template: "\\ddot{${1}}", description: "Second time derivative"),
        KaTeXSnippet(trigger: "matrix", label: "Matrix",
                     template: "\\begin{pmatrix} ${1} & ${2} \\\\ ${3} & ${4} \\end{pmatrix}",
                     description: "2×2 parenthesised matrix"),
        KaTeXSnippet(trigger: "bmatrix", label: "Bracketed matrix",
                     template: "\\begin{bmatrix} ${1} & ${2} \\\\ ${3} & ${4} \\end{bmatrix}",
                     description: "2×2 bracketed matrix"),
        KaTeXSnippet(trigger: "cases", label: "Cases / piecewise",
                     template: "\\begin{cases} ${1} & \\text{if } ${2} \\\\ ${3} & \\text{otherwise} \\end{cases}",
                     description: "Piecewise definition"),
        KaTeXSnippet(trigger: "partial", label: "Partial derivative ∂",
                     template: "\\frac{\\partial ${1}}{\\partial ${2}}", description: "Partial derivative"),
        KaTeXSnippet(trigger: "nabla", label: "Nabla ∇",
                     template: "\\nabla", description: "Nabla / del operator"),

        // — Sets + number systems —
        KaTeXSnippet(trigger: "reals", label: "ℝ reals",
                     template: "\\mathbb{R}", description: "Real numbers"),
        KaTeXSnippet(trigger: "naturals", label: "ℕ naturals",
                     template: "\\mathbb{N}", description: "Natural numbers"),
        KaTeXSnippet(trigger: "integers", label: "ℤ integers",
                     template: "\\mathbb{Z}", description: "Integers"),
        KaTeXSnippet(trigger: "rationals", label: "ℚ rationals",
                     template: "\\mathbb{Q}", description: "Rationals"),
        KaTeXSnippet(trigger: "complex", label: "ℂ complex",
                     template: "\\mathbb{C}", description: "Complex numbers"),
    ]

    /// Lookup by trigger (case-insensitive). The slash-menu autocompletes
    /// the user's prefix and feeds the full snippet to the editor.
    public static func snippet(forTrigger trigger: String) -> KaTeXSnippet? {
        let needle = trigger.lowercased()
        return all.first { $0.trigger == needle }
    }

    /// Filter by prefix — drives the live slash-menu autocompletion.
    /// Returns matching snippets in the canonical order they appear in
    /// `all` (no relevance scoring; the curation is the order).
    public static func snippets(matchingPrefix prefix: String) -> [KaTeXSnippet] {
        let needle = prefix.lowercased()
        return all.filter { $0.trigger.hasPrefix(needle) }
    }
}
