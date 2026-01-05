Product Design Requirements (PDR) – Drywich2.01 UI Refresh
Project Title

Drywich2.01 – Light Mode UI Refresh Using Blue Palette

Objective

Refresh the UI of the Drywich2.01 app using a clean, modern, light-mode-only design while preserving the existing structure, layouts, and functionality.

The goal is to improve visual consistency, clarity, and polish without making the UI extremely minimalistic or changing critical layouts.

Design Direction
Style

Neat & Modern

Clean but not overly minimal

Professional, calm, and readable

Familiar UI with improved polish (not a redesign from scratch)

Color Palette (Mandatory)

Only the following colors are allowed:

<palette>
  <color name="Steel Blue" hex="#2D7DD2" />
  <color name="Alice Blue" hex="#EDF5FC" />
  <color name="Midnight Violet" hex="#210124" />
  <color name="White" hex="#FFFFFF" />
</palette>

Color Roles

#FFFFFF (White)
→ Main background (entire app)

#EDF5FC (Alice Blue)
→ Secondary backgrounds, sections, containers, input backgrounds

#2D7DD2 (Steel Blue)
→ Primary actions, highlights, selected states, navigation accents

#210124 (Midnight Violet)
→ Primary text, headings, important labels

Global Rules (Very Important)
🚫 Layout & Size Constraints

DO NOT change card sizes in the Order Screen

No resizing, no reflow, no layout restructuring

Only colors, typography, shadows, and spacing refinements are allowed

This rule is strict.

Buttons & Icons
Buttons

Button background: #2D7DD2

Button text/icons: #FFFFFF

Secondary buttons: outlined or lighter background (#EDF5FC)

Button icon colors must be updated to match the new palette

Icons

Default icons: #2D7DD2

Active icons: #2D7DD2 (strong emphasis)

Red delete icons MUST stay red (do not recolor)

Icons should feel modern and consistent (Material Symbols / updated Material Icons)

Dashboard Constraints
Metrics Cards (Dashboard)

Keep existing icon colors

Do NOT recolor metric icons

Only update:

Card background

Typography

Shadows

Spacing

Inputs & Forms

Inputs must have unified visibility

Same background, border style, focus state across the app

Recommended:

Background: #EDF5FC

Border or focus highlight: #2D7DD2

Inputs must always be clearly visible on white backgrounds

AppBar

Change AppBar color ONLY in main.dart

AppBar color must match the overall UI (no default dark/Material color)

Use:

Background: #FFFFFF or #EDF5FC

Text & icons: #210124 or #2D7DD2

No per-screen AppBar color changes unless already implemented.

Bottom Navigation

Use better, more modern icons

Icons must be:

Clear

Consistent style

Easy to recognize

Active tab:

Color: #2D7DD2

Inactive tabs:

Reduced opacity or softer tone

Screen-Specific Notes
Dashboard (dashboard_screen.dart)

Keep layout structure

Improve:

Card polish

Typography hierarchy

Spacing

Do not over-minimize

Products (products_screen.dart)

Card-based layout stays

Improve contrast and readability

Clear selected/active states

Order Screen (order_screen.dart)

DO NOT CHANGE PRODUCT CARD SIZE

Improve visuals only:

Colors

Shadows

Text clarity

Button/icon colors

History & Settings

Group content clearly

Consistent card and input styling

Clear separation via spacing, not heavy borders

Typography

Sans-serif (Inter / Poppins)

Clear hierarchy:

Headings: strong, readable

Body: clean and comfortable

No ultra-thin fonts

Motion & Interaction

Subtle animations only

Simple tap feedback

No flashy or distracting transitions