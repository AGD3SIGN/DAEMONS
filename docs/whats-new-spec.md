# WHAT'S NEW screen

Built 2026-11-18 from Brandon's "What's New Screen — Implementation Spec" (Nov 18, 2026). Code:
scripts/ui/whats_new.gd. Data: data/whats_new.json. Tests: tests/test_whats_new.gd.

## What it is
A cream terminal panel shown once on the title screen after an update: dark title bar (WHAT'S NEW + the update
label), a log line (`> patch_notes.log loaded — 6 changes` with a blinking `_`), tagged entries (NEW, UI, BALANCE,
MOVES, AI) with an optional credit sub-line, and a footer with a key hint and OK.
- Desktop / landscape: 860px panel, tag column (112px) beside the text, dashed dividers, hint + OK footer.
- Phone held upright: panel = width - 28, tag above the text, full-width OK (52px tall), no key hint.
- The list scrolls (Up/Down, wheel) when it doesn't fit; the title bar and footer stay put.
- Closes on A / Enter / Space / B / Escape or a click or tap on OK. Taps outside the panel do nothing.
- Opens with a 120ms fade + scale from 96%, closes with an 80ms fade; both skipped with LESS MOTION.
- Optional scanlines over the panel: Options > NEWS LINES (off by default).

## Adding an update
Put a new object at the top of `updates` in data/whats_new.json with a new `id`, a `label` like
`UPDATE · NOV 18`, and `entries` of `{tag, text, credit?}`. One short sentence each, 6 or fewer if possible
(up to 12; past 8 it scrolls). Unknown tags show gray with a warning. Plain ASCII apostrophes and quotes.

## Where the repo overrode the spec
- **Silkscreen Bold** isn't bundled (only Silkscreen Regular and VT323, both OFL, in assets/fonts with their
  licenses). Bold text (title, OK) is drawn as a 1px double strike. Bundling the real Silkscreen-Bold.ttf from
  Google Fonts would match the spec exactly; it needs Brandon's OK to download.
- **Units:** spec px are drawn in a design frame (1280x720 desktop, 390 x screen-height phone) scaled to fit the
  screen, like BattleScene's frames. Scaling is fractional, so on some window sizes a pixel edge can land between
  physical pixels.
- **Phone vs desktop** is picked by orientation (taller than wide = phone), the same rule as BattleLayout, rather
  than "panel narrower than ~560px" (the design frame always has room for 860px).
- **Footer hint** follows the current controller ("Press Enter to continue" on keyboard, "Press A..." etc. on a
  pad) instead of the fixed "Press A / Enter to continue".
- **New players** don't see it (the repo already skipped them); their seen id is set quietly.
- **The seen id** is saved when the screen closes (OK or back), in settings.cfg ([news] last_seen_update).
- No "view What's New" menu entry existed, so none was added.
- Focus ring: drawn as a 3px ring 3px outside OK (rounded rects; no CSS outline in Godot).
