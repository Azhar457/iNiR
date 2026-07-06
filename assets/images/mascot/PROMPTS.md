# iNiR mascot — generation prompts

Original retro-pixel anime cat girl mascot for the iNiR project. `inir-mascot-base.png`
in this folder is the canonical reference pose (chest-up, three-quarter view,
annoyed/smug expression, "INIR" badge on her uniform).

Generated with an AI image model from the prompts below. Reuse the **identity
lock** block whenever generating a new pose so the character stays
recognizable across assets.

## Base prompt (used for the reference image)

```text
Create a new original character portrait using the same visual language as the references, but do not copy any existing character exactly.

Main style: retro pixelated anime-game portrait, 1990s JRPG / visual novel aesthetic, visible pixel clusters, limited-palette shading, strong clean outlines, purple-shadow shading, old console game look, hand-crafted pixel-art feeling. NO CRT scanlines, NO interlacing, NO screen-door texture: clean flat pixels.

Character: an original anime cat girl for the project "iNiR". She has blonde short-to-medium hair, blue eyes, cat ears, and a cat tail. She wears a Japanese school uniform with dark navy, white, and purple accents. She is looking toward the right in three-quarter view, with a mildly angry, annoyed, smug expression. Her face should feel sharp, expressive, and full of personality, not generic.

Accessories: give her distinctive details that make her recognizable across multiple assets: a dark gem choker, small hoop earrings, and a subtle hair clip. A small badge/emblem with the text "iNiR" is optional only when it sits naturally on a clearly visible uniform panel; omit it when the pose, crop, foreshortening, chibi proportions, or props make placement awkward.

Background: dark background suitable for use as an asset in a GitHub README or Linux shell project. Use very dark charcoal, black, or deep navy with a subtle retro gradient, minimal border, no busy environment, no extra clutter, and strong silhouette separation.

Composition: compact character portrait, chest-up or waist-up, readable as a reusable project mascot asset. The image should work well as branding, documentation art, shell UI art, README art, and repo decoration.

Quality direction: authentic old-anime proportions, crisp pixel rendering, deliberate dithering, strong silhouette, clean retro-game portrait composition. Avoid modern glossy AI rendering, avoid 3D, avoid painterly overrendering, avoid generic anime AI slop, avoid accidental text, and avoid CRT scanlines / interlacing / screen-door overlays of any kind.
```

## Master reusable prompt (new poses, same character)

Fill in `Pose` and `Expression`, keep the rest identical:

```text
Create a new image of the same original mascot character for the project "iNiR".

Character identity lock:
She is an original retro anime cat girl mascot with blonde short-to-medium hair, blue eyes, cat ears, and a cat tail. She wears a Japanese school uniform with dark navy, white, and purple accents. She has a slightly annoyed, smug, confident personality. Her recurring accessories are a dark purple gem choker, small hoop earrings, and a small hair clip. The "iNiR" badge is optional: include it only when it sits naturally on a clearly visible uniform panel, otherwise omit it. Keep her face, hair shape, cat ears, color palette, and personality consistent across images.

Pose:
[DESCRIBE POSE HERE]

Expression:
[DESCRIBE EXPRESSION HERE]

Use case:
This is an asset for a Linux shell / GitHub README / documentation UI. It should work as a clean visual element for a repo, not as a noisy illustration.

Style:
Retro pixelated anime-game portrait, 1990s JRPG / visual novel aesthetic, classic fantasy anime attitude without copying any existing character. Visible pixel clusters, limited palette, sharp black outlines, purple-shadow shading, deliberate dithering, old console game feel, hand-crafted sprite/portrait energy. NO CRT scanlines, NO interlacing, NO screen-door texture: clean flat pixels.

Background:
Dark minimal background, deep navy/charcoal/black, subtle purple gradient or minimal decorative border, no busy scenery, no extra clutter. Strong silhouette separation so the character works as a reusable asset.

Rendering rules:
Keep it pixelated, retro, crisp, expressive, and intentional. Avoid modern AI gloss, avoid smooth digital painting, avoid 3D, avoid generic waifu look, avoid messy details, avoid random accessories, avoid unreadable text, and avoid watermarks. Never force or float the optional "iNiR" badge onto the body.
```

## Identity lock (short form, repeat in every follow-up prompt)

```text
original retro anime cat girl mascot. CONSISTENCY IS CRITICAL — she must be pixel-recognizable as the exact same character as the reference: blonde short-to-medium hair with one tall ahoge, blue eyes, tan cat ears with pale inner fur, tan cat tail. Default outfit and canonical palette: white-lavender long-sleeve sailor top, navy sailor collar with two white stripes, magenta-purple neckerchief, navy pleated skirt. Context-specific outfit variations are allowed when the concept benefits, but they must preserve the navy-white-purple palette and recognizable sailor-uniform DNA rather than becoming a different character. Accessories, ALL mandatory and always visible when their body part is in frame: small dark-purple cat-face hair clip in her bangs on the left side, dark choker with a purple gem, small gold hoop earrings. The gold "iNiR" crest badge is OPTIONAL flavor, not an identity requirement: include it only when it sits naturally on a clearly visible flat uniform chest panel; omit it whenever the pose, crop, props or proportions make placement awkward, and never force, float, duplicate or warp it. Annoyed smug confident personality.
```

**Consistency law (2026-07-06, revised same day by maintainer):** identity
comes from face/hair silhouette, ears/tail, outfit colors and the small
accessories — NOT from the badge. The badge is optional garnish: fine on a
clean chest-up uniform panel, omitted everywhere else, and any floating,
duplicated, warped or misplaced badge is a rejection. The cat-face hair clip,
choker and hoop earrings remain mandatory whenever their body part is in
frame. Context outfits may change cut or add a role-specific layer, but must
retain the navy-white-purple palette and sailor-uniform visual DNA. Reject any
generation that drifts on face shape, clip shape, core palette, or identity.

**Creative variation envelope (2026-07-06):** do not solve variety with a
batch of interchangeable waist-up portraits. Camera, crop, body proportions,
staging, outfit details, props, and comedy mechanism may change aggressively.
Use fisheye, worm's-eye, bird's-eye, Dutch angles, foreground foreshortening,
full-body action, edge interaction, zero gravity, manga cut-ins, and abrupt
chibi when the use case benefits. Preserve recognizability through the face,
hair/ahoge, ears/tail, palette, small accessories, and personality—not by
freezing every image into the same model sheet pose.

## Naming convention for new poses

`inir-mascot-<pose-or-context>.png`, e.g. `inir-mascot-waving.png`,
`inir-mascot-settings-empty.png`, `inir-mascot-error.png`. Keep the base
reference (`inir-mascot-base.png`) untouched — it's the identity anchor other
poses are checked against.

## Production recipe for shell and docs surfaces

Use the base image as an image-generation reference, not just a textual style
description. Generate one context-specific pose per call.

For artwork that must sit naturally on themed surfaces, request a cutout on a
perfectly flat `#00ff00` chroma-key background:

```text
Perfectly flat solid #00ff00 background for background removal. No shadows,
gradients, texture, reflections, floor plane, glow, or lighting variation.
Keep every part of the character separated from the background with crisp
pixel-art edges. Do not use green hues in the character. No frame, border,
scenery, background decoration, props, or cast shadow.
```

Then remove the key to a new PNG with alpha:

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input <keyed-source.png> \
  --out <final.png> \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
```

Validate an `srgba` result, transparent corner pixels, clean hair/ear/tail
edges, no green fringe, and no misplaced/floating badge. In QML, use the
shared `MascotImage` widget (`modules/common/widgets/MascotImage.qml`) with
`pose: "<catalog-name>"` — it handles gating and crisp rendering.

Then destripe. Even with the NO-scanlines style wording, the generator can
sneak periodic CRT-style banding back in — the whole pre-2026-07-06 catalog
had it baked in and was cleaned in place. `mascot-destripe.py` (in the
inir-image skill's `scripts/`) measures the stripe period per image via
row-luminance autocorrelation and normalizes it away without touching the
pixel-art clusters:

```bash
python .claude/skills/inir-image/scripts/mascot-destripe.py <raw.png> <clean.png>
```

Finally, optimize for the repo — raw generator output (~2 MB) must never be
committed. Max 640px, 255-color palette, no dither (~150-250 KB, visually
identical at UI sizes for this pixel style). Use a box filter when scaling a
destriped master (point resampling can alias residual banding back in):

```bash
magick <clean.png> -filter box -resize '640x640>' -dither None -colors 255 \
  -strip PNG8:assets/images/mascot/inir-mascot-<name>.png
```

Keep the full-resolution original outside the repo as a master for future
re-exports and as a generation reference. Banners/scenes may go up to 1280px
and skip quantization when gradients band.

Make the emotion explicit and context-specific:

- About: confident playful smirk, narrowed bright eyes, faint blush.
- Empty/success: wink, relieved smile, playful hand gesture.
- Guide/onboarding: warm charismatic smile, attentive eyes, presenting hand.

Avoid neutral model-face expressions. Keep the character mature, expressive,
and waifu-like without drifting into glossy modern anime rendering.

## Personality and visual comedy

The mascot is not generically cute. Her baseline is competent, smug, nosy,
deadpan, and mildly roasting. The joke should come from contrast: polished
anime heroine design versus mundane shell failures, questionable user choices,
awkward waiting, physical defeat, or an absurd camera angle.

Vary the comedy mechanism instead of recycling the same bust:

- hard cut from normal proportions to chibi reaction;
- extreme fisheye, foreground hand, or face too close to the lens;
- full-body physical comedy, collapse, stumble, dangling legs;
- deadpan interaction with a panel edge or corner;
- asymmetric peeks from left, right, or top;
- empty manga balloons whose translated roast is rendered by QML;
- calm expression in an absurd pose, or absurd expression in a normal pose.

Keep the roast playful and aimed at the situation, never the user's identity.
Different areas should use different phases:

- welcome/help: nosy, teasing, warm;
- settings: confident, judging taste;
- loading/search: suspiciously patient;
- warning/privacy: serious with dry understatement;
- errors/crashes: exasperated, defeated, cartoon-dead;
- success: smug victory rather than generic celebration;
- media/game mode: absorbed, competitive, chaotic;
- low battery/offline: visibly deteriorating but funny.

## Render modes

Use one skill and one identity system for every mode:

1. **Canonical portrait** — chest/waist-up, emotional UI states.
2. **Full-body action** — physical comedy and panel-edge interaction.
3. **Edge cutout** — peeking or sitting against an implied UI boundary; never
   draw the boundary into the asset.
4. **Chibi reaction** — super-deformed proportions for abrupt comic emphasis;
   simplify detail but preserve hair, ears, palette, choker, hoops, and clip.
5. **Manga cut-in** — extreme lens/perspective or empty speech balloon.

Do not keep every accessory in every mode. The optional badge is usually
omitted in chibi, extreme perspective, full-body action, and prop-heavy scenes.
Consistency comes from the identity priority, not from stamping a logo.

Speech balloons stay empty. Render copy in QML so it remains translated,
accessible, theme-aware, and replaceable. Give the balloon a clean interior
and a stable tail direction, then place text as a separate UI layer.

## Approved pose catalog

These transparent PNGs are the current reusable emotional vocabulary:

| Asset | Intended surfaces |
|---|---|
| `inir-mascot-about-confident.png` | About, project identity, credits |
| `inir-mascot-docs-guide.png` | Documentation, help, onboarding routes |
| `inir-mascot-notifications-clear.png` | Empty notifications, all-caught-up |
| `inir-mascot-welcome-wave.png` | Welcome, first run, greeting |
| `inir-mascot-thinking.png` | Loading, search, AI, processing |
| `inir-mascot-error-annoyed.png` | Errors, failed actions, troubleshooting |
| `inir-mascot-warning-concerned.png` | Warnings, confirmation, risky actions |
| `inir-mascot-success-celebrate.png` | Saved, connected, completed, success |
| `inir-mascot-sleep-dnd.png` | Do Not Disturb, paused, idle, night |
| `inir-mascot-music-vibe.png` | Media, audio, volume, music |
| `inir-mascot-update-ready.png` | Updates, downloads, packages, changelog |
| `inir-mascot-battery-low.png` | Low battery, power saving, exhaustion |
| `inir-mascot-network-offline.png` | Offline, missing device, no results |
| `inir-mascot-privacy-lock.png` | Lock, authentication, permissions, secrets |
| `inir-mascot-theme-artist.png` | Wallpaper, themes, colors, customization |
| `inir-mascot-camera-boop.png` | Screenshot, camera, intrusive roast cut-in |
| `inir-mascot-dead-crash.png` | Crash, killed process, total failure |
| `inir-mascot-panel-sitter.png` | Panel/card top edge, long empty states |
| `inir-mascot-edge-peek.png` | Drawer edge, hints, tooltips, docs callouts |
| `inir-mascot-top-peek.png` | Bar/top edge, surprise hint |
| `inir-mascot-chibi-rage.png` | Repeated failure, denial, comic rage |
| `inir-mascot-chibi-roast-bubble.png` | Dynamic translated roast or hint |
| `inir-mascot-settings-judging.png` | Settings, preferences, questionable choices |
| `inir-mascot-fisheye-inspect.png` | Search, diagnostics, hidden details, suspicious results |
| `inir-mascot-cable-defeat.png` | Disconnected devices, audio/network failures, troubleshooting |
| `inir-mascot-upside-down-peek.png` | Top bars, dropdowns, update notices, onboarding hints |
| `inir-mascot-quota-empty.png` | Rate limits, AI/quota exhaustion, "out for today" states |
| `inir-mascot-goodbye-wave.png` | Session screen, logout, shutdown, reboot |
| `inir-mascot-workspace-juggle.png` | Workspace switcher, overview juggling multiple tasks |
| `inir-mascot-chibi-happy.png` | Celebration, victory, rare pure joy |
| `inir-mascot-chibi-cry.png` | Comic failure, data loss humor, overdramatic defeat |
| `inir-mascot-chibi-thumbsup.png` | Confirmation, all-good, approve with attitude |
| `inir-mascot-chibi-shrug.png` | Unknown, ambiguous result, "beats me" |
| `inir-mascot-chibi-love.png` | Affection, valentine, fan appreciation |
| `inir-mascot-chibi-sleepy.png` | Long idle, overnight AFK, sleepy nod |
| `inir-mascot-bottom-rise.png` | Bottom-edge peek, drawer-rise, mid-screen surprise |
| `inir-mascot-bottom-corner-lean.png` | Bottom-corner casual, dock lean, low-key watch |
| `inir-mascot-speech-bubble-calm.png` | Help, announcements, guided hints, talking |
| `inir-mascot-facepalm.png` | Repeated errors, user failure, hopeless config |
| `inir-mascot-popcorn-watch.png` | Watching a disaster unfold, observing drama |
| `inir-mascot-detective-glass.png` | Inspecting, auditing, suspicious results |
| `inir-mascot-box-hideout.png` | Minimized/collapsed panels, idle states, hidden/tucked-away UI |
| `inir-mascot-community-highfive.png` | Community, Discord, README greeting, contributor thanks |
| `inir-mascot-dock-hang.png` | Dock edge interaction, taskbar empty/hidden states |
| `inir-mascot-hero-banner.png` | README/docs hero banner — wide scene with the iNiR logotype, not a cutout |
| `inir-mascot-cheatsheet-sensei.png` | Cheatsheet, keybinds, tutorials, "you should know this" |
| `inir-mascot-todo-done.png` | Empty todo list, all tasks done, relaxed idle |
| `inir-mascot-weather-umbrella.png` | Weather loading/disabled, forecast, rainy states |
| `inir-mascot-gaming-focus.png` | Game mode, fullscreen detection, performance states |
| `inir-mascot-annoyed-poked.png` | Companion click reaction, mild protest |
| `inir-mascot-heart-eyes-pat.png` | Companion pat reaction, affection, favourites |
| `inir-mascot-late-night.png` | Late-night hours, sleep reminders, night states |
| `inir-mascot-morning-coffee.png` | Morning hours, slow starts, first coffee |
| `inir-mascot-hanging-claws.png` | Top-edge companion peek, precarious states |
| `inir-mascot-right-edge-peek.png` | Right-edge companion peek (native, unmirrored) |
| `inir-mascot-tea-break.png` | Long idle, calm empty states, patience |
| `inir-mascot-mate-break.png` | Mate sipping — long idle, calm breaks, Argentine flavor |
| `inir-mascot-purr-content.gif` | Purring loop — pat reaction, affection, contentment |
| `inir-mascot-typing-loop.gif` | Typing loop — busy states, loading, "working on it" |
| `inir-mascot-chibi-bounce.gif` | Bounce loop — hyper mood, success bursts, excitement |
| `inir-mascot-gossip-phone.png` | Phone snooping — notifications, gossip, feed scrolling |
| `inir-mascot-stretching-break.png` | Full-body stretch — break reminders, long sessions |
| `inir-mascot-laughing-roast.png` | Comic failures, roast moments |
| `inir-mascot-salute-ready.png` | Command executed, service started, readiness |
| `inir-mascot-shy-flustered.png` | Rare compliment/easter-egg reaction |
| `inir-mascot-guide-point-side.png` | Welcome wizard side callouts (mirror in QML for the other side) |
| `inir-mascot-guide-point-up.png` | Wizard bar callouts, pointing at the top, sharing a tip |
| `inir-mascot-guide-point-down.png` | Wizard dock/bottom callouts, "look down there" |
| `inir-mascot-follow-me.png` | Wizard tour start, next-step transitions, guided navigation |
| `inir-mascot-checklist-steps.png` | Wizard progress, setup steps, multi-step sequences |
| `inir-mascot-wizard-complete.png` | Wizard finale, setup complete, release celebration |
| `inir-mascot-terminal-demo.png` | CLI/IPC docs, terminal how-tos, command demos |
| `inir-mascot-bug-net.png` | Troubleshooting docs, bug reports, issue templates |
| `inir-mascot-doctor-checkup.png` | `inir doctor`, diagnostics, health checks |
| `inir-mascot-rocket-ride.png` | Boot/startup docs, launch, fast-start states |
| `inir-mascot-marshaller-windows.png` | Window management/workspaces docs, niri keybind guides |
| `inir-mascot-map-explorer.png` | Documentation routes, navigation, onboarding maps |
| `inir-mascot-waffle-snack.png` | Waffle family identity, breaks, playful empty states |
| `inir-mascot-tail-sway.gif` | Idle loop animation (tail) |
| `inir-mascot-ear-twitch.gif` | Idle loop animation (ears), subtle alive |
| `inir-mascot-sleepy-nod.gif` | DND/night dozing loop |
| `inir-mascot-wave-loop.gif` | Boot greeting, welcome loop |

Reuse an approved pose when its emotion matches. Generate a sibling only when
the new surface needs a genuinely different emotional or physical action.

## Pose log

Record the exact pose/expression text used for every new asset here, so a
consistent sibling or re-export can be regenerated later. Entries before
2026-07-06 predate the log.

- **hero-banner** (scene, 1536x1024, kept at 1280px quantized): Pose: "Wide
  horizontal hero banner composition for a GitHub README. The mascot occupies
  the right third of the frame, leaning casually with one elbow on top of a
  huge blocky retro pixel-art logotype that spells exactly: iNiR. The logotype
  is chunky 8-bit style lettering in white and purple with a dark navy bevel,
  sitting on the baseline of the frame. The left two thirds of the frame stay
  clean and dark with a subtle purple CRT grid and faint scanlines, usable as
  negative space. Her tail curls playfully around one letter." Expression:
  "Confident smug half-smile, one eyebrow raised, looking straight at the
  viewer like she owns the repository."
- **cheatsheet-sensei** (cutout): Pose: "Standing at three-quarter view like a
  strict teacher in front of an invisible blackboard, holding a long wooden
  pointer stick with one hand and tapping it against her other palm. Waist-up
  composition with clear margins." Expression: "Stern but amused sensei look,
  one eye slightly narrowed, faint smug smile, as if about to quiz the viewer
  on keyboard shortcuts they should already know."
- **todo-done** (cutout): Pose: "Leaning far back in a relaxed stretch, both
  arms raised behind her head, eyes half closed, tail hanging loose and
  completely limp. Waist-up composition, body language of someone with
  absolutely nothing left on her list." Expression: "Deeply satisfied lazy
  smile, eyes almost shut, pure smug contentment of finished work."
- **weather-umbrella** (cutout): Pose: "Holding a small transparent umbrella
  over her head with one hand while a few pixel raindrops bounce off it,
  other hand extended palm-up checking for rain. Waist-up composition."
  Expression: "Deadpan unimpressed stare at the sky, ears slightly flattened,
  the face of someone who did not order this weather."
- **gaming-focus** (cutout): Pose: "Hunched forward gripping a retro game
  controller with both hands, cable dangling, shoulders tense, ears pointing
  straight forward in maximum concentration. Waist-up composition."
  Expression: "Locked-in competitive stare with tiny clenched teeth, absorbed
  and slightly unhinged gamer intensity."
- **annoyed-poked** (cutout): Pose: "Leaning slightly away from the viewer
  with one cheek squished as if an invisible finger just poked it, arms
  crossed. Chest-up composition." Expression: "Annoyed side-eye glare with
  puffed cheek, visibly offended but tolerating it, one ear folded back."
- **heart-eyes-pat** (cutout): Pose: "Leaning slightly toward the viewer,
  eyes closed happily, hands clasped under her chin, tail curled up in a
  heart-like shape behind her. Chest-up composition." Expression: "Melting
  happy smile with faint blush and tiny pixel hearts floating around her
  head, dignity temporarily abandoned."
- **late-night** (cutout): Pose: "Slumped slightly forward mid-yawn, one hand
  covering her mouth, the other rubbing an eye, a tiny pixel crescent moon
  and one star floating beside her head. Chest-up composition." Expression:
  "Heavy-lidded sleepy eyes with tears at the corners from yawning, ears
  drooped completely."
- **morning-coffee** (cutout): Pose: "Holding a big steaming mug with both
  hands close to her face, steam rising in pixel wisps. Chest-up
  composition." Expression: "Half-awake deadpan stare over the rim of the
  mug, hair slightly messier than usual, judging the morning itself."
- **hanging-claws** (cutout): Pose: "Hanging from the top edge of the frame
  by her fingertips like a cat that climbed too high, body dangling, tail
  hanging straight down, legs slightly swinging. Full-body composition
  entering from the top edge." Expression: "Wide-eyed feigned innocence,
  tiny sweat drop, pretending this was intentional."
- **right-edge-peek** (cutout): Pose: "Peeking in from the RIGHT side of the
  frame, one hand gripping the implied right edge, half her face and one ear
  visible, body hidden beyond the right border. Cutout composition entering
  from the right edge." Expression: "Sly narrow-eyed smirk, caught mid-snoop
  and completely unashamed."
- **tea-break** (cutout): Pose: "Sitting cross-legged and relaxed holding a
  small teacup with saucer, pinky slightly raised, tail wrapped neatly
  around herself. Full-body composition." Expression: "Serene closed-eyes
  contentment with a refined tiny smile, self-declared elegance."
- **laughing-roast** (cutout): Pose: "Doubled slightly over laughing hard,
  one hand pointing straight at the viewer, other hand holding her stomach.
  Chest-up composition." Expression: "Open-mouth cackling laugh with
  squeezed-shut eyes and a fang showing, absolutely delighted at someone's
  mistake."
- **salute-ready** (cutout): Pose: "Standing straight with a crisp two-finger
  salute at her brow, other hand on hip, chest out, tail upright and proud.
  Chest-up composition." Expression: "Confident smirk with one raised
  eyebrow, mock-military competence, ready to execute."
- **shy-flustered** (cutout): Pose: "Turned three-quarters away hugging her
  own tail in front of her like a shield, shoulders raised. Chest-up
  composition." Expression: "Deep blush across the whole face, wide flustered
  eyes looking sideways at the viewer, ears flattened, caught off guard by a
  compliment."
- **tail-sway** (2x2 GIF): Base: "Standing relaxed in three-quarter view,
  arms loosely at her sides, calm confident tiny smile, tail raised behind
  her." Animate: "Only the tail position: it sways smoothly from left, to
  center-left, to center-right, to right, forming a seamless swaying loop."
- **ear-twitch** (2x2 GIF): Base: "Chest-up three-quarter view, arms crossed,
  calm smug expression, eyes open, tail curled at her side." Animate: "Only
  the cat ears: frame 1 both up, frame 2 left ear flicks down, frame 3 both
  up, frame 4 right ear flicks down."
- **sleepy-nod** (2x2 GIF): Base: "Sitting with arms folded on an invisible
  surface in front of her, head upright, eyes half closed, one strand of
  hair drooping." Animate: "Only the head and eyelids: the head slowly tips
  forward as the eyes close, then snaps back upright with eyes briefly wide,
  then settles half-closed again."
- **wave-loop** (2x2 GIF, v2 2026-07-06): Base: "Chest-up three-quarter view,
  warm smile, her RIGHT hand raised beside her head palm out in every single
  frame, other arm relaxed at her side." Animate: "Only the raised right hand
  and forearm tilt: frame 1 tilted left, frame 2 upright, frame 3 tilted
  right, frame 4 upright again; the hand stays raised on the same side in all
  four frames."
- **idle-breathe** (2x2 GIF): Base: "Chest-up three-quarter view, arms
  relaxed, calm content micro-smile, eyes open looking slightly aside."
  Animate: "Only a subtle breathing motion: the shoulders and chest rise a
  few pixels through frames 1-2 and settle back down through frames 3-4."
- **dock-hang** (v2): Pose: "Hanging relaxed by both hands from the top edge
  of the frame, arms straight up gripping the implied edge, body dangling
  straight down, tail curled calmly to one side. Full-body entering from the
  top edge." Expression: "Calm unbothered smug look straight at the viewer."
- **community-highfive** (v2): Pose: "Facing the viewer offering a big
  open-palm high five with one hand raised toward the camera, the other hand
  on her hip. Chest-up." Expression: "Bright confident grin with eyes locked
  on the viewer, genuinely welcoming for once."
- **upside-down-peek** (v2): Pose: "Only her head, shoulders and one gripping
  hand visible, entering UPSIDE-DOWN from the top edge of the frame, hair
  hanging downward with gravity. Compact cutout entering from the top edge."
  Expression: "Playful smug grin while upside down, one eyebrow raised."
- **goodbye-wave** (v2): Pose: "Chest-up, one hand raised beside her head
  waving farewell, the other arm relaxed, tail drooping softly." Expression:
  "Soft bittersweet smile with a faint sparkle in her eyes, a warm
  see-you-later rather than a sad goodbye."
- **workspace-juggle** (v2): Pose: "Juggling three small glowing pixel blocks
  numbered 1, 2 and 3 in an arc above her head with both hands. Waist-up."
  Expression: "Focused playful concentration with the tip of her tongue
  slightly out, showing off."

- **chibi-happy** (v3): Pose: "Super-deformed chibi proportions, jumping with both arms up in pure joy, pixel sparkles around her. Full chibi body."
  Expression: "Huge closed-eyes open-mouth smile of absolute victory."
- **chibi-cry** (v3): Pose: "Super-deformed chibi proportions, sitting on the floor with comic waterfall tears streaming from both eyes, tiny fists rubbing them. Full chibi body."
  Expression: "Exaggerated wailing anime cry, completely overdramatic."
- **chibi-thumbsup** (v3): Pose: "Super-deformed chibi proportions, standing proud giving a big thumbs up with one hand, other fist on hip. Full chibi body."
  Expression: "Confident closed-eyes grin with a tiny fang."
- **chibi-shrug** (v3): Pose: "Super-deformed chibi proportions, both tiny palms up in an exaggerated shrug, tail forming a question-mark shape. Full chibi body."
  Expression: "Deadpan flat stare, completely unimpressed, who-knows energy."
- **chibi-love** (v3): Pose: "Super-deformed chibi proportions, hugging a big pixel heart almost her own size. Full chibi body."
  Expression: "Blissful heart-shaped eyes and tiny blush."
- **chibi-sleepy** (v3): Pose: "Super-deformed chibi proportions, standing asleep while upright, a large pixel Z Z Z bubble floating above her head, tiny drool. Full chibi body."
  Expression: "Peacefully sleeping face with closed eyes, completely gone."
- **bottom-rise** (v3): Pose: "Only her head, ears and both hands visible rising from the BOTTOM edge of the frame, fingers gripping the implied bottom edge like peeking over a wall, everything below hidden beyond the bottom border. Compact cutout entering from the bottom edge."
  Expression: "Mischievous narrow-eyed smirk, only eyes and smile visible over the edge."
- **bottom-corner-lean** (v3): Pose: "Visible from the waist up, leaning casually sideways into the frame from the bottom-left corner as if resting her elbow on the implied bottom edge, body cut by the bottom border. Cutout anchored to the bottom edge."
  Expression: "Relaxed smug side-glance at the viewer, totally at home."
- **speech-bubble-calm** (v3): Pose: "Chest-up, gesturing politely with one open palm toward a large EMPTY round speech balloon beside her head with a clean white interior and stable tail pointing at her mouth. The balloon must be completely empty."
  Expression: "Composed helpful smile, professional announcer energy."
- **facepalm** (v3): Pose: "Chest-up, one hand covering her whole face mid-facepalm, other arm crossed, ears drooped sideways. Chest-up composition."
  Expression: "Visible only around the hand: gritted teeth and one twitching eyebrow, maximum disappointment."
- **popcorn-watch** (v3): Pose: "Chest-up, holding a striped pixel popcorn bucket in one arm and lifting a piece of popcorn to her mouth with the other hand. Chest-up composition."
  Expression: "Wide entertained eyes locked on the viewer's disaster, thoroughly enjoying the show."
- **detective-glass** (v3): Pose: "Chest-up, holding a large magnifying glass up to one eye, which appears comically enlarged through the lens, other hand behind her back. Chest-up composition."
  Expression: "Serious detective squint through the lens, deducing something incriminating."
- **mate-break** (v4, first born-clean batch): Pose: "Sitting relaxed and comfortable, chest-up composition, holding a traditional Argentine mate gourd (calabaza with metal bombilla straw) in both hands close to her chest, about to sip from the bombilla."
  Expression: "Serene, content, quietly smug half-smile, eyes relaxed and half-closed in enjoyment."
- **gossip-phone** (v4): Pose: "Leaning forward conspiratorially, chest-up composition, holding a small glowing retro smartphone in both hands, thumb mid-scroll, screen light reflecting on her face."
  Expression: "Nosy delighted grin, wide sparkling eyes locked onto the screen, one ear perked up."
- **stretching-break** (v4): Pose: "Standing full-body stretch, both arms raised high overhead with fingers interlocked, back slightly arched, tail stretched out straight behind her."
  Expression: "Mid-yawn with one eye closed, relaxed and unbothered."
- **purr-content** (v4, GIF): Base pose: "Sitting curled up and content, chest-up composition, eyes closed with a soft happy smile, hands resting in her lap, tail wrapped around beside her." Animate: "A gentle purring rhythm: her shoulders and cheeks rise and settle subtly, her ears relax and perk in a soft cycle, and the tip of her tail curls and uncurls slightly." Delays 25×4.
- **typing-loop** (v4, GIF): Base pose: "Seated at a small retro computer, three-quarter view, chest-up composition, hands resting on a chunky beige keyboard, face lit by the soft glow of a CRT-less flat pixel screen." Animate: "Her hands type on the keyboard in a steady rhythm while her eyes track across the screen; the screen glow flickers very subtly." Delays 14×4.
- **chibi-bounce** (v4, GIF): Base pose: "Chibi proportions, full tiny body facing the viewer, standing centered with a big happy open-mouth grin and clenched excited fists." Animate: "She bounces up and down energetically in place: knees bend, body rises and lands, hair and ears bob with the bounce, tail springs." Delays 10×4.

- **guide-point-side** (v5, use-case batch): Pose: "Waist-up three-quarter view, body angled toward the viewer, one arm fully extended sideways to the LEFT of the frame with an open presenting palm, like a tour host showing off a feature beside her. Other hand resting on her hip. Clear margins around the extended arm."
  Expression: "Warm charismatic hostess smile with attentive bright eyes, proud of what she is presenting."
- **guide-point-up** (v5): Pose: "Waist-up composition, one arm raised high pointing straight UP above her head with the index finger, eyes following her own finger upward, other hand cupped beside her mouth like sharing a secret tip."
  Expression: "Playful conspiratorial smile while looking up, one eyebrow raised."
- **guide-point-down** (v5): Pose: "Waist-up composition, leaning slightly forward and pointing straight DOWN below the frame with the index finger, other arm folded behind her back, tail curling downward following the gesture."
  Expression: "Knowing teacher smirk, eyes on the viewer while pointing down, as if saying: look down there."
- **follow-me** (v5): Pose: "Full-body composition, caught mid-step walking away but turned back toward the viewer, one hand beckoning with a come-along curled finger gesture, the other holding the strap of a small pixel satchel, tail high and confident."
  Expression: "Over-the-shoulder playful smirk with narrowed inviting eyes, tour guide who will not wait."
- **checklist-steps** (v5): Pose: "Waist-up composition, holding a clipboard with a paper showing three large empty pixel checkboxes connected by a dotted line (no text anywhere on the paper), ticking the top checkbox with an oversized pencil in the other hand."
  Expression: "Focused competent look with a satisfied tiny smile, methodically in control."
- **wizard-complete** (v5): Pose: "Waist-up composition, pulling a party cracker popper that bursts with pixel confetti and thin streamers above her head, one eye squinting at the pop, shoulders slightly raised."
  Expression: "Smug triumphant grin, congratulating the viewer for finally finishing setup."
- **terminal-demo** (v5): Pose: "Waist-up composition, standing beside a floating dark retro computer window with a plain title bar and a single blinking block cursor inside (absolutely no readable text or letters on the screen), gesturing at it with an open palm like a weather presenter."
  Expression: "Confident lecturing look, eyes on the viewer, mid-explanation."
- **bug-net** (v5): Pose: "Waist-up composition, holding up a butterfly net in one hand with a single fat cartoon pixel bug trapped inside the net, inspecting it at eye level, other hand on her hip."
  Expression: "Deadpan unimpressed stare at the captured bug, mildly disgusted, case closed energy."
- **doctor-checkup** (v6, creative batch): Pose: "Waist-up composition, pressing a retro stethoscope chest piece against an invisible surface beside her with one hand, the earpieces in her cat ears, other hand raised in a wait-for-it gesture."
  Expression: "Focused diagnostic squint, listening intently, one ear twitched toward the sound."
- **rocket-ride** (v6): Pose: "Full-body composition, clinging with both arms to a small chunky pixel rocket blasting diagonally upward, her legs trailing behind in the wind, tail streaming, a short pixel exhaust flame below the rocket."
  Expression: "Thrilled wide-eyed grin mixed with mild panic, hair blown back."
- **marshaller-windows** (v6): Pose: "Waist-up composition, directing traffic like an airport marshaller with two short glowing pixel light batons, one arm extended to the side, the other signaling overhead."
  Expression: "Dead serious professional focus with a hint of enjoying the authority."
- **map-explorer** (v7): Pose: "Waist-up composition, holding a large unfolded pixel paper map with both hands, the map showing only a dotted route line and a few plain landmark dots (no text or letters), one finger tracing the route, ears perked forward."
  Expression: "Curious focused eyes scanning the map, tip of her tongue slightly visible in concentration."
- **waffle-snack** (v7): Pose: "Waist-up composition, holding a small plate with a golden square pixel waffle topped with a pat of butter in one hand, a fork raised in the other hand, about to take the first bite."
  Expression: "Delighted anticipation with sparkling eyes locked on the waffle, completely absorbed."

## Imported pre-generated assets (2026-07-06 audit batch)

These assets were generated in earlier imagegen batches, audited visually
on 2026-07-06, and re-pipelined through chroma-key removal + 640px PNG8
optimization. Identity verified against `inir-mascot-base.png`.

| File | Pose | Best use context |
|---|---|---|
| `inir-mascot-peace-wink.png` | peace-wink | About / credits / friendly greeting |
| `inir-mascot-gift-giving.png` | gift-giving | Update ready / new feature rollout |
| `inir-mascot-reading.png` | reading | Idle / docs / loading |
| `inir-mascot-expression-sheet.png` | expression-sheet | Visual reference only (composite 2x2) |
| `inir-mascot-chibi-arms-crossed.png` | chibi-arms-crossed | Error state / refusal / mini reaction |
| `inir-mascot-chibi-mallet.png` | chibi-mallet | Warning before destructive action / playful threat |
| `inir-mascot-bored-chin-rest.png` | bored-chin-rest | Idle / waiting / loading long task |
| `inir-mascot-waving-hi.png` | waving-hi | Welcome / first-run |
| `inir-mascot-thinking-pose.png` | thinking-pose | Search / processing / considering |
| `inir-mascot-tired-dev.png` | tired-dev | Long-running task / late-night session |
| `inir-mascot-presenting.png` | presenting | Onboarding / introducing feature |
| `inir-mascot-fist-pump.png` | fist-pump | Task success / build passed |
| `inir-mascot-presenting-warm.png` | presenting-warm | Onboarding / docs welcome |
| `inir-mascot-arms-crossed-confident.png` | arms-crossed-confident | About / confidence / judging |
| `inir-mascot-seated-thinking.png` | seated-thinking | Idle / calm / search |
| `inir-mascot-shrug-annoyed.png` | shrug-annoyed | Not found / 404 / confused |
| `inir-mascot-point-at-viewer.png` | point-at-viewer | Direct call-to-action / 'you' |
| `inir-mascot-chibi-pointing-laugh.png` | chibi-pointing-laugh | Mocking reaction / comedic beat |
| `inir-mascot-sit-pointing.png` | sit-pointing | Idle / seated / explaining |
| `inir-mascot-welcoming.png` | welcoming | First-run / help / onboarding |
| `inir-mascot-chibi-frustrated.png` | chibi-frustrated | Error retry / minor failure |
| `inir-mascot-fisheye-reach.png` | fisheye-reach | Close inspection / camera angle joke |
| `inir-mascot-upside-down-hang.png` | upside-down-hang | Idle hang / playful lurking |
| `inir-mascot-heroic-run.png` | heroic-run | Loading / launching / startup action |
| `inir-mascot-shh-finger.png` | shh-finger | Quiet / DND / focus mode |
| `inir-mascot-smug-hand-raised.png` | smug-hand-raised | Confident about / smug explanation |

## Maintainer-supplied assets (2026-07-06, kira-images-inir drop)

Provided directly by the maintainer (ChatGPT-generated, 3 sprite sheets +
2 singles in `~/Descargas/kira-images-inir/`). Cut with grid-seam XY
splitting, cross-cell contamination erased manually (stray shoes, the
chef's pan initially landed in the neighbouring cell), then run through
the standard pipeline: chroma-key removal (`--auto-key border
--soft-matte --despill`), corner/alpha validation, destripe, master
archive, BOX 640px PNG8. `plant-care` needed strict thresholds
(`--transparent-threshold 4 --opaque-threshold 60`, no despill) because
the plant's green leaves sat on the green chroma background. Several use
context outfits (chef, punk, skater, gamer) under the creative variation
envelope — identity anchors (face, ahoge, ears/tail, palette, hairclip,
choker, earrings) verified per pose.

| File | Pose | Best use context |
|---|---|---|
| `inir-mascot-hand-on-hip.png` | hand-on-hip | Idle confident / judging your setup |
| `inir-mascot-battle-point.png` | battle-point | Gaming / challenge / rivalry callout |
| `inir-mascot-standing-unimpressed.png` | standing-unimpressed | Idle / unimpressed full-body stare |
| `inir-mascot-crouch-inspect.png` | crouch-inspect | Inspecting something low / debugging |
| `inir-mascot-sit-peace-wink.png` | sit-peace-wink | Success / relaxed victory |
| `inir-mascot-spyglass-search.png` | spyglass-search | Search / overview / hunting a window |
| `inir-mascot-sticky-notes.png` | sticky-notes | Todo overload / notification pileup |
| `inir-mascot-paint-roller.png` | paint-roller | Wallpaper change / theming repaint |
| `inir-mascot-heavy-lift.png` | heavy-lift | Heavy load / big task / many windows |
| `inir-mascot-music-conductor.png` | music-conductor | Music playing / conducting the vibe |
| `inir-mascot-plant-care.png` | plant-care | Idle care / growth / gentle moment |
| `inir-mascot-key-offer.png` | key-offer | Lock / auth / permissions moment |
| `inir-mascot-stand-pout.png` | stand-pout | Idle pout / mild disapproval |
| `inir-mascot-visualizer-surf.png` | visualizer-surf | Music / visualizer / audio energy |
| `inir-mascot-low-angle-guard.png` | low-angle-guard | Dramatic idle / guarding the desktop |
| `inir-mascot-magic-hat.png` | magic-hat | Launcher / plugins / "anything can appear" |
| `inir-mascot-energy-drink.png` | energy-drink | Hyper mood / caffeine hours |
| `inir-mascot-handheld-gaming.png` | handheld-gaming | Gaming session / game mode |
| `inir-mascot-chef-flambe.png` | chef-flambe | Building / cooking something up |
| `inir-mascot-skater-trick.png` | skater-trick | Hyper mood / speed / fast startup |
| `inir-mascot-punk-reach.png` | punk-reach | Rare alt-style idle / edgy reach |

## Transparent animation workflow

For a short loop, generate a 2x2 sprite sheet on the same flat chroma key.
Require the same pose, scale, crop, lighting, outfit, hair, accessories, and
tail in all quadrants; vary only the animated feature. Read frames
left-to-right, then top-to-bottom.

The approved blink sequence is:

1. eyes open;
2. eyelids lowering;
3. eyes closed;
4. eyes open.

Crop equal quadrants before removing the key:

```bash
magick <sheet.png> -crop <half-width>x<half-height> +repage frame-%02d-key.png
```

Run the normal chroma-removal command on every frame, save the PNG sequence
under `assets/images/mascot/frames/<animation>/`, then assemble the GIF:

```bash
magick -dispose background \
  -delay 110 frame-00.png \
  -delay 8 frame-01.png \
  -delay 12 frame-02.png \
  -delay 8 frame-03.png \
  -loop 0 -layers Optimize inir-mascot-idle-blink.gif
```

Validate frame count, transparent corners, loop timing, stable canvas size,
and identity continuity. Keep the PNG frames: QML may later need controlled
frame playback even when the GIF is also shipped.
