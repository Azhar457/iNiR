# Product

## Register

product

## Users

Linux power users on the Niri Wayland compositor — people who manage their own
system, read logs, write keybinds, and expect a shell they can audit and bend.
Their context: a tiling desktop they've already customized, multiple monitors,
a terminal one keystroke away, and a low tolerance for docs that patronize or
drift. The job to be done: install iNiR confidently, configure it without
guessing, theme the whole system, and — when something breaks — find the
single authoritative page that explains how it actually works. Secondary
users: contributors extending modules or porting panel families, who need the
architecture internals, not the marketing layer.

## Product Purpose

The iNiR Wiki is the canonical reference surface for the iNiR desktop shell:
installation, packages, architecture, shell/IPC/module reference, theming
pipeline, and contributor guide. It exists because iNiR is a large, layered
system (760+ QML files, 70+ service singletons, two panel families, a
wallpaper-to-color pipeline) and drift between docs and code is the primary
trust failure. Success: any user can go from `git clone` to a working,
themed, understood desktop without leaving the wiki, and trust that what they
read matches the running shell.

## Brand Personality

Calm authority. Crafted, not templated. The existing wabi-sabi direction —
washi (undyed paper) in light mode, sumi (ink night) in dark, a single
teal/mint accent as the thread through both — is the committed identity,
preserved and elevated to professional reference quality. Voice is
matter-of-fact and precise: "Docs drift; code at least has the decency to
crash." Three words: *composed, precise, lived-in*.

## Anti-references

- **The mkdocs-Material default.** Indigo primary on slate header, the
  out-of-the-box `mkdocs-material` look a thousand projects ship unchanged.
  iNiR already overrides this; the elevation must widen the gap, not narrow it.
- **ReadTheDocs utility.** Dense, unstyled, default-bootstrap references that
  read as "the docs were an afterthought."
- **Generic SaaS-cream docs.** Warm-neutral near-white body bg, identical
  icon-heading-text card grids, hero-metric templates, the 2026 saturated AI
  docs aesthetic. iNiR's warmth comes from accent + typography + the paper
  metaphor, never from a default warm-neutral body.
- **Decorative docs.** Sites where motion, illustration, or chrome compete
  with the reference content the user came to read.

## Design Principles

1. **Calm authority.** A reference surface you trust because it doesn't
   shout. Information density achieved through rhythm and hierarchy, never
   visual noise. Density without calm is clutter; calm without density is
   empty prettiness.
2. **Crafted, not templated.** Resist the mkdocs/RTD defaults at every layer
   — header, tabs, sidebar, code, admonitions, cards — so each earns its
   place rather than inheriting the framework's voice.
3. **Show the system, don't narrate it.** iNiR is a dual-family,
   wallpaper-driven, layered shell. The docs' structure, density, and
   dual-mode (sumi/kinari) mirror that: two equal modes, one accent threading
   them, layered information that reveals depth on demand.
4. **Dark and light as equals.** Sumi (ink night) and kinari (undyed paper)
   are both first-class surfaces, designed in parallel — never a dark mode
   retrofitted onto a light default or vice versa.
5. **The accent is the thread, not the decoration.** Teal/mint appears
   sparingly to guide attention (links, active state, the drop cap, current
   section) and never as fill, gradient, or ornament.

## Accessibility & Inclusion

WCAG 2.1 AA. Body text ≥4.5:1 against bg in both modes; the current warm-paper
`#2B2622` on `#F5F0E6` and sumi `#E5DDD0` on `#1A1714` must hold or be
corrected toward the ink end. Reduced-motion fully respected (the existing
`prefers-reduced-motion` block stays and grows). Teal/mint accent tested
against deuteranopia/protanopia (green-cyan is generally safe; verify the
deep-teal `#1E7A66` against the paper bg specifically). Keyboard parity for
every nav, search, tab, and card affordance. RTL/i18n: the repo ships 11
README locale translations and i18n is a live concern — layout must not
hard-code direction or break on translated string lengths.
