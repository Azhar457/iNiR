# iNiR

<div class="inir-home" markdown>

<section class="inir-masthead" aria-labelledby="inir-title" markdown>
<div class="inir-masthead__mark" aria-hidden="true">
  <span>入</span>
  <span>理</span>
</div>
<div class="inir-masthead__copy" markdown>
<p class="inir-kicker">Niri desktop shell · Quickshell/QML · static reference</p>

<h1 id="inir-title">A whole desktop, documented like a system you can trust.</h1>

<p class="inir-lede">iNiR is not a theme and not a dotfiles bundle. It is the full desktop surface for Niri: bar, dock, sidebars, notifications, settings, wallpapers, overview, lock screen, IPC, updates, and theming, all running inside one Quickshell process.</p>

<div class="inir-actions" markdown>
[Install iNiR](INSTALL.md){ .md-button .md-button--primary }
[Open the reference](IPC.md){ .md-button }
[View on GitHub](https://github.com/snowarch/inir){ .md-button }
</div>
</div>

<aside class="inir-command" aria-label="First run command" markdown>
<span>first run</span>

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
inir run
```

Arch is the automated path. Other distros, package-managed installs, and NixOS are covered in the install docs.
</aside>
</section>

<section class="inir-routebook" aria-labelledby="routebook-title" markdown>
<div markdown>

## Choose the right page

The wiki is organized around what you are trying to do: get a shell on screen, understand the runtime, script it, or extend it without breaking both panel families.

</div>

<nav class="routebook-grid" aria-label="Documentation routes">
  <a href="INSTALL/"><strong>Install</strong><span>Clone, dependencies, first run, package-managed mode.</span></a>
  <a href="SETUP/"><strong>Maintain</strong><span>Updates, rollback, migrations, doctor, service control.</span></a>
  <a href="ARCHITECTURE_OVERVIEW/"><strong>Understand</strong><span>Shell entrypoint, services, modules, startup order.</span></a>
  <a href="PANEL_FAMILIES/"><strong>Switch families</strong><span>Material ii and Waffle as separate runtime compositions.</span></a>
  <a href="THEMING_ARCHITECTURE/"><strong>Theme it</strong><span>Wallpaper extraction, presets, QML tokens, external app targets.</span></a>
  <a href="IPC/"><strong>Script it</strong><span>Targets and functions callable from keybinds or terminal.</span></a>
</nav>
</section>

<section class="inir-split" aria-labelledby="runtime-title" markdown>
<div markdown>

## Runtime Shape

iNiR is intentionally one process. The shell keeps its state in shared QML singletons, panel loaders choose one family at a time, and services bridge the desktop to Niri, D-Bus, sockets, subprocesses, and generated theme files.

</div>

<ol class="runtime-flow">
  <li><span>shell.qml</span><p>Boots the shell, waits for config, applies theme, selects the active family.</p></li>
  <li><span>Config + services</span><p>Own persistent intent and live system state: audio, network, Niri IPC, wallpapers.</p></li>
  <li><span>Panel loaders</span><p>Material ii or Waffle loads on demand. Only enabled panels materialize.</p></li>
  <li><span>Modules</span><p>Bars, panels, overview, settings, notifications, widgets, and lock surfaces render it.</p></li>
</ol>
</section>

<section class="family-kakejiku" aria-labelledby="families-title" markdown>

## Two Families

<div class="family-kakejiku__panels">
  <article>
    <small>Material ii</small>
    <h3>Spacious, layered, expressive.</h3>
    <p>Top bar, Overview launcher, sidebars, Material You color and six visual styles: <code>material</code>, <code>cards</code>, <code>aurora</code>, <code>inir</code>, <code>angel</code>, <code>zzz</code>.</p>
  </article>
  <article>
    <small>Waffle</small>
    <h3>Dense, mechanical, familiar.</h3>
    <p>Bottom taskbar, Start menu, Action Center, Notification Center, and its own Fluent-inspired density, motion, and chrome.</p>
  </article>
</div>

Switch at runtime with <code>Super+Shift+W</code>. The services layer and config backend stay shared; the visible shell composition changes.
</section>

<section class="inir-ledger" aria-labelledby="ledger-title" markdown>

## Operator Notes

<div class="ledger-table" markdown>

| Need | Page | Why it matters |
|------|------|----------------|
| Package inventory | [Packages](PACKAGES.md) | Every required and optional dependency grouped by role. |
| Config writes | [Config System](CONFIG_SYSTEM.md) | `Config.setNestedValue()` is the persistence boundary. |
| Service catalog | [Services](SERVICES.md) | The shared runtime truth used by modules. |
| Module catalog | [Modules](MODULES.md) | The user-visible QML surface. |
| Known limits | [Limitations](LIMITATIONS.md) | What is unsupported, experimental, or compositor-specific. |
| Performance | [QML Performance](OPTIMIZATION.md) | Patterns for keeping the single QML runtime responsive. |

</div>

If a page disagrees with the running shell, trust the running shell and open an issue. Docs drift; code at least has the decency to crash.
</section>

</div>
