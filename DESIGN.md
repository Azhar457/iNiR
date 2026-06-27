# Design

## Identity

iNiR's public website is a warm anime-adjacent documentation portal: a presentation surface and a docs reader in one. It follows the supplied reference image structurally — fixed dark rail, calm top navigation, illustrated hero scene, compact guide dashboard, and composed footer — without copying literal Japanese decoration.

The mood is: quiet Linux tools, beautiful work, focused desktop craft.

## Themes

The site ships two designed themes, controlled by `html[data-theme]` and persisted in `localStorage` via `web/assets/js/theme.js`.

### Light

- Warm paper background, subtly tinted toward iNiR's teal/peach palette.
- Dark sumi rail for contrast and brand anchoring.
- Hero uses a warm room-like scene with the anime mascot integrated into the right side.
- Cards are paper surfaces with hairline borders, not heavy shadows.

### Dark

- Deep teal-black background, not pure black.
- Same layout and hierarchy as light mode.
- Cards become dark plates with teal links and warm text.
- Mascot and monitor become part of the dark scene, avoiding a separate “dark only” redesign.

## Color Roles

Defined in `web/assets/css/style.css` as CSS custom properties using OKLCH where practical:

- `--bg`, `--bg-soft`: page ground
- `--paper`, `--paper-veil`: cards and top surfaces
- `--ink`, `--ink-soft`, `--muted`, `--faint`: typography hierarchy
- `--rail`, `--rail-2`, `--rail-ink`: left navigation rail
- `--teal`, `--teal-2`: primary action, active state, links
- `--leaf`, `--peach`, `--rose`: supporting warmth, architecture layers, small ornamental moments
- `--line`, `--line-strong`: hairline borders
- `--code`: terminal/code panels

Color usage is restrained but warm: teal owns primary actions and navigation; peach/leaf/rose are supporting notes, never random decoration.

## Typography

- Display: `Source Serif 4` — warm, bookish, serious enough for documentation and presentation.
- Body: `Nunito Sans` — approachable, readable, and less corporate than generic system/Inter defaults.
- Code/UI mono: `JetBrains Mono` — reserved for code panels and technical controls.

Hero headings use a strong serif scale with max clamp below 6rem. Body copy stays readable at 16px+, with constrained measures.

## Layout System

### Desktop

- Fixed left rail: project identity + docs navigation.
- Sticky topbar: primary nav + docs search + theme toggle + GitHub.
- Hero: two-column reference layout, copy left and illustrated scene right.
- Feature strip overlaps the hero bottom edge, matching the reference dashboard rhythm.
- Documentation dashboard uses varied cards: wide quickstart, tall guide cards, compact cards, code/architecture/activity/changelog rows.
- Footer is a quiet multi-column site map.

### Responsive

- Below 860px the rail becomes a drawer and the topbar burger opens both nav and rail.
- Cards collapse to one column on mobile.
- Touch targets stay at least 44px high.
- Core docs/content remains visible; no important feature is hidden only for desktop.

## Components

- `.rail`: dark side navigation and identity surface.
- `.topbar`: sticky site navigation.
- `.theme-toggle`: shared light/dark control.
- `.hero`, `.hero__scene`: reference-driven presentation fold.
- `.feature-strip`: four compact strengths, overlapping the hero.
- `.guide-card`: documentation dashboard card; variants include `--wide`, `--tall`, `compact`, `code-example`, `architecture`, `activity`, and `changelog`.
- `.code-panel`: quick-start terminal with copy action.
- `.docs`, `.docnav`, `.md`, `.doctoc`: documentation reader shell.

## Motion

Motion is intentionally light:

- Reveals enhance already-visible content and never hide content by default.
- Mascot has a subtle floating animation only when reduced motion is not requested.
- Buttons and cards use short ease-out movement for feedback.
- `prefers-reduced-motion: reduce` disables animation and smooth scrolling.

## Accessibility

- Light and dark themes are designed, not inverted.
- Text colors are chosen for readable contrast against their surfaces.
- Search, nav, theme toggle, copy button, and docs drawer are keyboard reachable.
- Images have alt text where they carry content; purely atmospheric internal images are hidden or empty-alt.
- The docs reader supports search query handoff (`docs.html?q=install`) and keyboard-friendly navigation.
