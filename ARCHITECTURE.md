# iNiR Architecture

> A complete desktop shell built on [Quickshell](https://quickshell.outfoxxed.me/) for the [Niri](https://github.com/YaLTeR/niri) Wayland compositor.

**Version**: 2.27.0 · **Stack**: QML (Quickshell), Bash, Python, Go

Originally forked from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse). Secondary Hyprland support is maintained.

---

## Entry Point

`shell.qml` → `ShellRoot` (Quickshell-specific root, not Item/Window).

Startup flow:
1. Environment pragmas configure Qt scale, WebEngine, etc.
2. Singleton services force-instantiated via dummy property bindings
3. `Config.ready` triggers panel loading
4. Theme and icon services applied via `Qt.callLater`
5. Hyprsunset, first-run wizard, and conflict killer loaded

## Panel Families

Two mutually exclusive UI families, switchable at runtime (`Super+Shift+W`):

| | **Material ii** | **Waffle** |
|---|---|---|
| Active when | `panelFamily !== "waffle"` | `panelFamily === "waffle"` |
| Visual tokens | `Appearance.*` | `Looks.*` |
| Styles | material, cards, aurora, inir, angel, zzz | Single fluent style |
| Bar | Top (or vertical) | Bottom (Win11 taskbar) |
| App launcher | Overview | StartMenu with search |
| Right panel | SidebarRight | ActionCenter + NotificationCenter |
| Panels | 29 (iiBar, iiDock, iiSidebarLeft, ...) | 25 (wBar, wStartMenu, wActionCenter, ... + shared ii panels) |

Each panel uses `PanelLoader` (LazyLoader wrapper):
```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```
Loads when ALL conditions are true: `Config.ready` + identifier in `enabledPanels` array + `extraCondition`.

Style dispatch priority: **zzz > angel > inir > aurora > material** (`Appearance.qml`: `zzzEverywhere`/`angelEverywhere`/`inirEverywhere`/`auroraEverywhere` are `globalStyle` checks; `auroraEverywhere` is also true when `globalStyle === "angel"`, so angel must be checked before aurora wherever both matter). Cards is a material variant (no separate dispatch).

## Directory Structure

```
shell.qml                     # Root entry — loads services, selects panel family
ShellIiPanels.qml             # Material Design family (29 panels)
ShellWafflePanels.qml         # Windows 11 family (25 panels)
GlobalStates.qml              # Runtime UI state (panel open/closed booleans)
FamilyTransitionOverlay.qml   # Animated family switch
settings.qml                  # Settings GUI (separate Quickshell config)
welcome.qml                   # First-run wizard
killDialog.qml                # Process kill confirmation

modules/                      # 33 UI module directories
├── common/                   # Shared infrastructure
│   ├── Appearance.qml        # ii visual tokens (1233 lines)
│   ├── Config.qml            # Central config (JsonAdapter, 2329 lines)
│   └── widgets/              # 154 reusable widgets + qmldir
├── bar/                      # Top bar (ii family, 35 files)
├── sidebarLeft/              # AI chat, YT Music, widgets (70 files incl. subdirs)
├── sidebarRight/             # Toggles, calendar, tools (74 files incl. subdirs)
├── settings/                 # All config UI pages (30 files)
├── dock/                     # App dock (all 4 positions)
├── overview/                 # Workspace overview + app search
├── waffle/                   # Windows 11 family
│   ├── bar/                  # Bottom taskbar
│   ├── startMenu/            # Start menu with search
│   ├── actionCenter/         # Quick settings
│   ├── notificationCenter/   # Notification list + calendar
│   ├── looks/Looks.qml       # Waffle visual tokens
│   └── [13 more subdirs]
└── [25 more modules]

services/                     # 61 top-level runtime singletons (+ services/deferred/)
├── qmldir                    # Service module registration
├── Audio.qml                 # PipeWire volume, mute, per-app mixer
├── NiriService.qml           # Niri compositor IPC (1574 lines)
├── CompositorService.qml     # Compositor detection (Niri vs Hyprland)
├── Network.qml               # NetworkManager integration
├── Weather.qml               # Weather polling + privacy-aware location
├── Bluetooth.qml             # BlueZ device management
├── Translation.qml           # i18n string lookup
└── [more services]

scripts/                      # Shell/fish/python helpers (26 top-level entries)
├── inir                      # CLI launcher (bash, IPC + lifecycle commands)
├── colors/                   # Color generation pipeline
│   ├── applycolor.sh         # Orchestrator
│   ├── generate_colors_material.py  # Material You color generation + template rendering
│   ├── modules/              # Per-app theming (terminals, GTK, etc.)
│   └── lib/                  # Shared infrastructure
└── [more scripts]

sdata/                        # Install/update lifecycle
├── lib/                      # Shared bash libraries
├── migrations/               # Numbered scripts (001–031)
├── subcmd-install/           # Install phases
└── subcmd-uninstall/         # Uninstall phases

defaults/                     # Shipped defaults
├── config.json               # Default config (1762 lines, 62 top-level keys)
├── niri/                     # Niri config templates
└── [GTK, KDE, fuzzel, etc.]

translations/                 # i18n strings (15 languages)
distro/arch/                  # Arch PKGBUILDs (dependency manifests)
assets/                       # Icons, wallpapers, systemd unit, desktop entry
docs/                         # User documentation (28 files)
```

## Config System

| Aspect | Details |
|--------|---------|
| Schema | `modules/common/Config.qml` — JsonAdapter, 2329 lines |
| Defaults | `defaults/config.json` — 1762 lines, 62 top-level keys |
| User file | `~/.config/illogical-impulse/config.json` (legacy namespace from fork origin) |
| Read | `Config.options.path.to.key` — schema-declared properties are typed QML properties with defaults |
| Write | `Config.setNestedValue("path.to.key", value)` — writes + fires `configChanged()` signal |
| Ready gate | `Config.ready` — true after JSON loaded (or created if missing) |
| Hot-reload | `watchChanges: true` — external edits auto-apply |
| Debounce | 50ms for both reads and writes |

**Sync rule**: when adding a new config key, always update together:
1. `modules/common/Config.qml` — schema definition
2. `defaults/config.json` — default value
3. Consumer(s) — read/write the key
4. Settings UI if the key is user-facing

## Key Singletons

| Singleton | Dependents | Domain |
|-----------|-----------|--------|
| `Config` | 321+ files | All config read/write |
| `Appearance` | 488+ files | All ii module visuals |
| `Translation` | 350+ files | All i18n strings |
| `GlobalStates` | 160+ files | Panel visibility state |
| `Looks` | waffle modules | Waffle visual tokens |
| `NiriService` | compositor modules | Niri IPC, workspaces, windows |
| `Audio` | medium | PipeWire volume, mute, per-app mixer |
| `CompositorService` | medium | Compositor detection (Niri/Hyprland) |
| `Weather` | medium | Weather polling + privacy-aware location |
| `Network` | medium | NetworkManager integration |
| `Wallpapers` | medium | Wallpaper management + theming pipeline |

These are **stability boundaries** — prefer add-only changes, verify all dependents before reshaping.

## IPC System

Handlers registered via `IpcHandler { target: "name" }` in QML.

Called externally: `inir <target> <function> [args]`

All functions must declare return types (`string`, `int`, `bool`, `real`, `color`, `void`).

Full reference: [docs/IPC.md](docs/IPC.md).

## Theming Pipeline

Colors flow: wallpaper image → `generate_colors_material.py` (materialyoucolor) → `colors.json` → `MaterialThemeLoader` → `Appearance` tokens → UI.

Theme generation orchestrated by `scripts/colors/applycolor.sh`, which runs per-app modules in parallel:
- Terminals (foot, kitty, alacritty)
- Starship prompt
- Fuzzel launcher
- GTK3/4
- Firefox (pywalfox)
- VS Code, Zed, OpenCode (Go generators)
- SDDM login theme
- btop, lazygit, yazi

## Distribution

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup                  # Interactive TUI installer
./setup install -y       # Fully automated
./setup update           # Pull + sync + migrate + restart
./setup doctor           # Diagnose + auto-fix
./setup rollback         # Restore previous snapshot
```

Two install modes tracked in `version.json`:
- **Repo-sync**: `./setup install` → syncs to `~/.config/quickshell/inir/`
- **Package-managed**: `make install` → copies to `/usr/share/quickshell/inir/`

User config for the running QML shell lives at `~/.config/illogical-impulse/config.json` (legacy namespace, persistent across updates). NOTE: the shell scripts/CLI default to `~/.config/inir/` with a legacy fallback — the two sides are not yet unified.

### Multi-Distro Support

| Distro | Strategy |
|--------|----------|
| **Arch** | pacman + AUR helper for fonts |
| **Fedora** | dnf + COPR repos (quickshell, niri) |
| **Debian/Ubuntu** | apt + compile from source (niri, quickshell) |
| **Generic** | Guidance-only dependency checking |

### Migrations

Location: `sdata/migrations/` (numbered scripts: 001–031).
- Append-only — never rename, reorder, or delete existing migrations
- Idempotent — may run again if state is lost
- Next number: `032-descriptive-name.sh`

## Daily Development

```bash
inir run                    # Launch the shell
inir restart                # Graceful restart
inir logs | tail -50        # Check for errors
inir status                 # Runtime health check
inir doctor                 # Auto-diagnose + fix
inir settings               # Open settings GUI

# IPC calls
inir <target> <function> [args...]
inir overview toggle
inir audio volumeUp
```

Never run raw `qs kill -c inir` / `qs -c inir` by hand — iNiR runs under
`inir.service` (systemd --user); a bare `qs` invocation kills or duplicates
the live session outside systemd's supervision. `inir restart` is the only
correct way to force a restart.

## Known Harmless Warnings

These log messages are safe to ignore:
- `Failed to create DBusObjectManagerInterface for "org.bluez"` — no Bluetooth adapter
- `failed to register listener: ...PolicyKit1...` — another polkit agent running
- `QSGPlainTexture: Mipmap settings changed` — Qt cosmetic
- `Cannot open: file:///...coverart/...` — missing album art cache
- `$HYPRLAND_INSTANCE_SIGNATURE is unset` — expected when running on Niri
