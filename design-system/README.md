# iNiR · zzz Design System (local reference)

Visual, browsable reference for iNiR's bespoke **`zzz`** poster style. Use it when
building new zzz surfaces so new work matches the declared design language instead
of being re-derived from memory.

- **Source of truth:** `modules/common/Appearance.qml` (the `zzz` QtObject) for tokens,
  and `modules/common/widgets/Zzz*.qml` for components. The cards here are a *faithful
  preview*, not the implementation — when in doubt, the QML wins.
- **Synced to:** Claude Design System project `iNiR Design System`
  (`fe69e036-3910-48fe-ae2a-c15e6d975f09`) via the `/design-sync` skill.
- Each `*/index.html` is self-contained and carries a `<!-- @dsCard group="…" -->`
  marker on its first line so the Design System pane self-indexes.

> Colors in the cards are a **representative instance** (warm/lime). Real zzz tokens
> are wallpaper-generated at runtime — capture *roles*, never frozen hexes.

## Card → widget map

| Card | Group | QML widget | Role |
|------|-------|-----------|------|
| tokens | Foundations | `Appearance.qml` (zzz) | palette roles, type (Oxanium), shape/chamfer |
| section-header | Foundations | `ZzzSectionHeader` | glyph badge + italic title + index code |
| plate | Surfaces | `ZzzPlate` | chamfered signature surface (45° cut) |
| plate-card | Surfaces | `ZzzPlateCard` | composed card on the plate |
| card | Surfaces | `ZzzCard` | calm unified surface, elevation ramp |
| graphic-plate | Surfaces | `ZzzGraphicPlate` | clean plate + left accent bar, opt-in ornaments |
| tech-frame | Surfaces | `ZzzTechFrame` | registration marks + engineering grid |
| panel-backdrop | Surfaces | `ZzzPanelBackdrop` | console ground (hatch, hazard, hue bloom) |
| glass-wash | Surfaces | `ZzzGlassWash` | blurred wallpaper-hue wash on chamfer mask |
| signal-button | Signals | `ZzzSignalButton` | actionable poster control on the plate |
| glyph-button | Signals | `ZzzGlyphButton` | actionable square glyph carrier |
| glyph-badge | Signals | `ZzzGlyphBadge` | decorative square glyph carrier |
| data-chip | Signals | `ZzzDataChip` | capsule key/value label |
| stat-bar | Signals | `ZzzStatBar` | metric row + 18-segment rail |
| diagonal-pattern | Graphics | `ZzzDiagonalPattern` | hatching / hazard rails |
| burst | Graphics | `ZzzBurst` | starburst emphasis stamp |
| surface-accent | Graphics | `ZzzSurfaceAccent` | registration rail + role sticker |
| ghost-mark | Graphics | `ZzzGhostMark` | giant faint wordmark watermark |

## Re-syncing

Run `/design-sync` after meaningful zzz changes. It rebuilds the diff and pushes
only what changed — never a wholesale replace.
