---
name: frontend-design
description: "Guidance for distinctive, intentional visual design when building or reshaping UI. Use when the user is making aesthetic decisions, choosing typography, picking colours, designing components, laying out pages, or wants their UI to not look like a default template. Also use for accessibility review of visual design."
globs: ["*.tsx", "*.jsx", "*.vue", "*.svelte", "*.css", "*.scss", "*.html"]
alwaysApply: false
---

# Frontend Design

Guide intentional visual design decisions. The goal: UI that looks designed, not templated.

## When This Activates

Use this skill when making visual design decisions — not for every frontend code change. A utility function refactor doesn't need this. A new page layout does.

## Process

### 1. Understand the Context

Before proposing any design:
- What's the product? Who uses it? What's the emotional register? (A finance dashboard reads differently than a creative portfolio.)
- Is there an existing design system, brand guide, or design tokens? If yes, work within them.
- What's the viewport priority? (Mobile-first unless explicitly otherwise.)

### 2. Aesthetic Direction

Make explicit choices about:

**Typography**
- Pick a type scale with clear hierarchy (heading, subheading, body, caption, small).
- Limit to 2 typefaces maximum. One is often enough.
- Set line-height for readability: 1.5-1.6 for body text, 1.2-1.3 for headings.
- Don't use the framework's default font stack without a conscious decision.

**Colour**
- Start with a constrained palette: 1 primary, 1-2 neutrals, 1 accent, semantic colours (success/warning/error/info).
- Check contrast ratios. WCAG AA minimum: 4.5:1 for body text, 3:1 for large text.
- Design for light AND dark mode from the start — retrofitting is painful.
- Use CSS custom properties / design tokens, not hardcoded values.

**Spacing**
- Use a consistent spacing scale (4px or 8px base). Don't eyeball it.
- Generous whitespace reads as polished. Cramped layouts read as amateur.
- Group related elements with tighter spacing; separate unrelated groups with wider gaps.

**Shape and Depth**
- Pick a border-radius convention and stick to it (e.g., 4px for inputs, 8px for cards, full for avatars).
- Use shadows sparingly and consistently. One shadow style for elevation, not five.

### 3. Component Design

- Every component should have a clear purpose. If you can't name it in 2 words, it's doing too much.
- Design states: default, hover, focus, active, disabled, loading, error, empty. Don't ship a component missing states.
- Interactive elements need visible focus indicators. Don't remove `outline` without replacing it.
- Animations: use for feedback (button press, page transition), not decoration. Keep under 300ms for UI responses.

### 4. Accessibility

Non-negotiable baseline (WCAG AA):
- Colour contrast ratios met
- All interactive elements keyboard-accessible
- Semantic HTML elements used correctly
- Images have alt text
- Form inputs have associated labels
- Focus order follows visual order
- No information conveyed by colour alone

### 5. Review Checklist

Before declaring UI work done:
- [ ] Looks intentional, not default
- [ ] Typography hierarchy is clear
- [ ] Colour palette is constrained and consistent
- [ ] Spacing follows the scale
- [ ] All component states designed
- [ ] Accessibility baseline met
- [ ] Responsive: tested at 320px, 768px, 1024px, 1440px
- [ ] Dark mode works (if applicable)

## Constraints

- Don't redesign what isn't being changed. Stay focused on the task.
- Don't add animation libraries for a single transition. CSS transitions cover 90% of UI animation needs.
- Don't propose a design system overhaul when the user asked for a button style.
