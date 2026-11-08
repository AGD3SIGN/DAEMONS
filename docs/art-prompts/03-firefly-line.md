# Glowbit → Scriptfly → Compilume

Paste one stage per image. Generate and approve each stage before the next.

## Glowbit (Stage 1 of 3)

````
Create ONE image: a pixel-art battle sprite sheet for ONE creature from my original indie game DAEMONS
(a monster-collecting RPG where technology comes alive: every creature is a real animal fused with
real IT hardware).

== CANVAS AND GRID ==
- Square image, 1024 x 1024 pixels.
- An invisible 4 x 4 grid: 16 cells, each 256 x 256. Do NOT draw grid lines, borders, boxes, panels,
  frames, labels, numbers or any text anywhere in the image.
- Exactly one sprite per cell, centered horizontally. It flies: in every cell the lowest point of the body hovers at the same height, 40 pixels above the bottom of the cell (no shadow under it). Nothing crosses into a
  neighboring cell.
- Background: one flat, solid magenta #FF00FF filling the whole image, including the space between
  sprites. No floor, no cast shadow, no scenery, no gradient, no vignette.

== PIXEL STYLE ==
- Early-2000s handheld RPG battle sprite (Game Boy Advance era).
- Each sprite is drawn on a 64 x 64 art-pixel grid and scaled up exactly 4x, so every art pixel is a
  crisp 4 x 4 square. The pixel size is identical in all 16 cells.
- Hard edges only: no anti-aliasing, blur, smooth shading, gradients, glow, bloom, noise or texture.
- A 1-art-pixel outline around the creature in a dark tint of its body color, not pure black.
- Cel shading: base color, one shadow, one highlight per material. Light comes from the top-left.
- Maximum 15 colors: use ONLY the palette below, identical in every cell.
- Effects (sparks, impact stars, rings, Zz, steam) are drawn in the same pixel style and palette.
- 100% original: it must not resemble any existing game, cartoon or mascot character.

== CREATURE BIBLE ==
Name: Glowbit. Stage 1 of 3 (basic form). Type: Software.
Concept: a baby firefly whose glowing tail blinks like a text cursor. Curious and quick; it follows whoever types the fastest.
Body: a tiny round bug with an oversized head, two little wings and a big glowing tail segment.
Size: body height about 45% of the cell (about 29 of the 64 art pixels), same size in every frame.
Signature features (show in every frame where they would be visible):
1. Its face is a small black screen showing a green ">_" (a right arrow and an underscore cursor) as its mouth area, with two round eyes above it.
2. A glowing lime tail segment shaped like a rectangular cursor block.
3. Two small rounded translucent-looking wings (flat pale teal, no transparency).
4. Two short antennae with tiny glowing dots at the tips.
5. Big round dark eyes, each with one white shine pixel in the upper-left.
Palette (exact hex):
#142418 outline | #2E6B3E body shadow | #4CC06A body | #8EE89A body highlight |
#C8F86A glow lime | #F8FFD0 glow core | #A8E0D0 wing | #6AA898 wing shadow | #E0F0E8 wing highlight |
#101814 screen black | #5CF07A code green | #F2C63A progress amber | #24382A legs |
#0C140E eyes | #FFFFFF eye shine

== FRAMES (read left to right, top to bottom) ==
Row 1 - FRONT view (facing the viewer, body turned slightly toward the viewer's left):
 1. Idle A: hovering, wings mid-beat, tail glowing.
 2. Idle B: identical to Idle A but 1 art pixel lower and slightly squashed wider (breathing).
 3. Physical attack: a quick dart toward the viewer's left, leaving a short trail of green pixels.
 4. Special attack: tail glow flaring, firing a stream of small green code blocks toward the viewer's left.
Row 2 - FRONT reactions:
 5. Hurt: recoiling to the right, eyes squeezed shut (> <), small white impact star at its upper-left,
    glow flickering off.
 6. Fainted: lying on the bottom of its cell, eyes as X shapes, tail glow dark, wings limp, a small "no signal" swirl above it.
 7. Happy / Victory: looping upward, eyes closed in happy arcs, tail glow at full brightness with sparkles.
 8. Asleep (Standby): hovering lower than usual, eyes closed as flat lines, tail glow dim, small pixel "Z z" shapes above.
Row 3 - BACK view (the player's own creature: seen from behind and slightly above, facing away toward
the upper right; no face visible):
 9. Back Idle A: back of the bug, wings spread, the glowing cursor tail facing the viewer.
10. Back Idle B: 1 art pixel lower, slightly squashed.
11. Back attack: lunging forward away from the viewer toward the upper right.
12. Back hurt: flinching back toward the viewer (lower-left).
Row 4 - SPECIAL (front view):
13. Upgrading (evolution): arms/wings raised, the whole body filled flat white #FFFFFF with only the outline kept, short energy lines radiating outward.
14. Overheated: flustered, sweat drop, small white steam puffs rising off it, tail glow flashing amber.
15. Throttled: stiff frozen pose, eyes wide, small zig-zag sparks around the body, wings frozen mid-beat, glow stuttering.
16. Menu icon: head and upper body only, front view, simplified, drawn within a 32 x 32 art-pixel area
    centered in the cell (same 4x pixel size as the other cells).

== CONSISTENCY CHECKLIST (check before finishing) ==
- The same creature in all 16 cells: same proportions, eyes, palette and pixel size; only the pose and
  effects change.
- The >_ screen face, cursor-block glowing tail, small wings and glowing antennae wherever visible.
- It hovers at the same height in every cell except Fainted (which lies on the bottom).
- No text, labels, numbers, grid lines, borders or extra characters. Flat #FF00FF background everywhere.
````

## Scriptfly (Stage 2 of 3)

Attach the approved Glowbit sheet(s) first.

````
Create ONE image: a pixel-art battle sprite sheet for ONE creature from my original indie game DAEMONS
(a monster-collecting RPG where technology comes alive: every creature is a real animal fused with
real IT hardware).

ATTACHED: the approved sprite sheet(s) for Glowbit (the earlier stage(s) of this SAME creature). Match their face, eyes, palette and pixel style exactly; only grow and upgrade it as described.

== CANVAS AND GRID ==
- Square image, 1024 x 1024 pixels.
- An invisible 4 x 4 grid: 16 cells, each 256 x 256. Do NOT draw grid lines, borders, boxes, panels,
  frames, labels, numbers or any text anywhere in the image.
- Exactly one sprite per cell, centered horizontally. It flies: in every cell the lowest point of the body hovers at the same height, 40 pixels above the bottom of the cell (no shadow under it). Nothing crosses into a
  neighboring cell.
- Background: one flat, solid magenta #FF00FF filling the whole image, including the space between
  sprites. No floor, no cast shadow, no scenery, no gradient, no vignette.

== PIXEL STYLE ==
- Early-2000s handheld RPG battle sprite (Game Boy Advance era).
- Each sprite is drawn on a 64 x 64 art-pixel grid and scaled up exactly 4x, so every art pixel is a
  crisp 4 x 4 square. The pixel size is identical in all 16 cells.
- Hard edges only: no anti-aliasing, blur, smooth shading, gradients, glow, bloom, noise or texture.
- A 1-art-pixel outline around the creature in a dark tint of its body color, not pure black.
- Cel shading: base color, one shadow, one highlight per material. Light comes from the top-left.
- Maximum 15 colors: use ONLY the palette below, identical in every cell.
- Effects (sparks, impact stars, rings, Zz, steam) are drawn in the same pixel style and palette.
- 100% original: it must not resemble any existing game, cartoon or mascot character.

== CREATURE BIBLE ==
Name: Scriptfly. Stage 2 of 3 (middle form). Type: Software.
Concept: the SAME firefly grown into a sleek adult. Clever and talkative; it writes glowing script in the air as it flies.
Body: a longer, slimmer firefly body with a defined thorax, six thin legs and two pairs of wings.
Size: body height about 70% of the cell (about 45 of the 64 art pixels), same size in every frame.
KEEP FROM PREVIOUS STAGE: the same >_ screen face, eye shape and shine, the same green/lime palette, the glowing tail and the glowing antennae.
Signature features (show in every frame where they would be visible):
1. Its two pairs of wings look like small code windows: dark rectangles with pale borders and 2-3 lines of green "text" dashes (not readable letters).
2. A longer glowing tail that leaves a short dotted green line behind it.
3. Long curling antennae with glowing tips.
4. The >_ screen face, now with the cursor blinking larger.
5. Big round dark eyes with a white shine pixel.
Palette (exact hex):
#142418 outline | #2E6B3E body shadow | #4CC06A body | #8EE89A body highlight |
#C8F86A glow lime | #F8FFD0 glow core | #A8E0D0 wing | #6AA898 wing shadow | #E0F0E8 wing highlight |
#101814 screen black | #5CF07A code green | #F2C63A progress amber | #24382A legs |
#0C140E eyes | #FFFFFF eye shine

== FRAMES (read left to right, top to bottom) ==
Row 1 - FRONT view (facing the viewer, body turned slightly toward the viewer's left):
 1. Idle A: hovering upright, wings open, writing a short glowing squiggle in the air.
 2. Idle B: identical to Idle A but 1 art pixel lower and slightly squashed wider (breathing).
 3. Physical attack: spinning forward toward the viewer's left, wings edge-first.
 4. Special attack: drawing a glowing green rune of code dashes in the air and launching it toward the viewer's left.
Row 2 - FRONT reactions:
 5. Hurt: recoiling to the right, eyes squeezed shut (> <), small white impact star at its upper-left,
    glow flickering off.
 6. Fainted: lying on the bottom of its cell, eyes as X shapes, tail glow dark, wings limp, a small "no signal" swirl above it.
 7. Happy / Victory: looping upward, eyes closed in happy arcs, tail glow at full brightness with sparkles.
 8. Asleep (Standby): hovering lower than usual, eyes closed as flat lines, tail glow dim, small pixel "Z z" shapes above.
Row 3 - BACK view (the player's own creature: seen from behind and slightly above, facing away toward
the upper right; no face visible):
 9. Back Idle A: back of the body with both pairs of code-window wings spread.
10. Back Idle B: 1 art pixel lower, slightly squashed.
11. Back attack: lunging forward away from the viewer toward the upper right.
12. Back hurt: flinching back toward the viewer (lower-left).
Row 4 - SPECIAL (front view):
13. Upgrading (evolution): arms/wings raised, the whole body filled flat white #FFFFFF with only the outline kept, short energy lines radiating outward.
14. Overheated: flustered, sweat drop, small white steam puffs rising off it, tail glow flashing amber.
15. Throttled: stiff frozen pose, eyes wide, small zig-zag sparks around the body, wings frozen mid-beat, glow stuttering.
16. Menu icon: head and upper body only, front view, simplified, drawn within a 32 x 32 art-pixel area
    centered in the cell (same 4x pixel size as the other cells).

== CONSISTENCY CHECKLIST (check before finishing) ==
- The same creature in all 16 cells: same proportions, eyes, palette and pixel size; only the pose and
  effects change.
- Code-window wings, >_ face, long glowing tail and antennae wherever visible.
- It hovers at the same height in every cell except Fainted (which lies on the bottom).
- No text, labels, numbers, grid lines, borders or extra characters. Flat #FF00FF background everywhere.
````

## Compilume (Stage 3 of 3)

Attach the approved Glowbit and Scriptfly sheet(s) first.

````
Create ONE image: a pixel-art battle sprite sheet for ONE creature from my original indie game DAEMONS
(a monster-collecting RPG where technology comes alive: every creature is a real animal fused with
real IT hardware).

ATTACHED: the approved sprite sheet(s) for Glowbit and Scriptfly (the earlier stage(s) of this SAME creature). Match their face, eyes, palette and pixel style exactly; only grow and upgrade it as described.

== CANVAS AND GRID ==
- Square image, 1024 x 1024 pixels.
- An invisible 4 x 4 grid: 16 cells, each 256 x 256. Do NOT draw grid lines, borders, boxes, panels,
  frames, labels, numbers or any text anywhere in the image.
- Exactly one sprite per cell, centered horizontally. It flies: in every cell the lowest point of the body hovers at the same height, 40 pixels above the bottom of the cell (no shadow under it). Nothing crosses into a
  neighboring cell.
- Background: one flat, solid magenta #FF00FF filling the whole image, including the space between
  sprites. No floor, no cast shadow, no scenery, no gradient, no vignette.

== PIXEL STYLE ==
- Early-2000s handheld RPG battle sprite (Game Boy Advance era).
- Each sprite is drawn on a 64 x 64 art-pixel grid and scaled up exactly 4x, so every art pixel is a
  crisp 4 x 4 square. The pixel size is identical in all 16 cells.
- Hard edges only: no anti-aliasing, blur, smooth shading, gradients, glow, bloom, noise or texture.
- A 1-art-pixel outline around the creature in a dark tint of its body color, not pure black.
- Cel shading: base color, one shadow, one highlight per material. Light comes from the top-left.
- Maximum 15 colors: use ONLY the palette below, identical in every cell.
- Effects (sparks, impact stars, rings, Zz, steam) are drawn in the same pixel style and palette.
- 100% original: it must not resemble any existing game, cartoon or mascot character.

== CREATURE BIBLE ==
Name: Compilume. Stage 3 of 3 (final form). Type: Software.
Concept: the SAME firefly as a giant, ancient firefly, fused with a compiler. Patient and powerful; it can build anything from raw code.
Body: a large, armored firefly with a heavy thorax, broad wings and a huge glowing abdomen.
Size: body height about 85% of the cell (about 54 of the 64 art pixels), same size in every frame.
KEEP FROM PREVIOUS STAGE: the same >_ screen face, eye shape and shine, the same green/lime palette, the glowing tail and the glowing antennae.
Signature features (show in every frame where they would be visible):
1. Its huge abdomen is a horizontal build-progress bar: segmented, about 3/4 filled with glowing lime, the rest dark.
2. Antennae curved into the shape of curly braces { }.
3. Broad wings with code-window panels.
4. Armored thorax plates edged in amber.
5. The >_ screen face and big dark eyes with a white shine pixel.
Palette (exact hex):
#142418 outline | #2E6B3E body shadow | #4CC06A body | #8EE89A body highlight |
#C8F86A glow lime | #F8FFD0 glow core | #A8E0D0 wing | #6AA898 wing shadow | #E0F0E8 wing highlight |
#101814 screen black | #5CF07A code green | #F2C63A progress amber | #24382A legs |
#0C140E eyes | #FFFFFF eye shine

== FRAMES (read left to right, top to bottom) ==
Row 1 - FRONT view (facing the viewer, body turned slightly toward the viewer's left):
 1. Idle A: hovering heavily, wings wide, progress bar glowing.
 2. Idle B: identical to Idle A but 1 art pixel lower and slightly squashed wider (breathing).
 3. Physical attack: a heavy body-slam dive toward the viewer's left, abdomen first.
 4. Special attack: the progress bar filling to 100%, then blasting a wide beam of lime light toward the viewer's left.
Row 2 - FRONT reactions:
 5. Hurt: recoiling to the right, eyes squeezed shut (> <), small white impact star at its upper-left,
    glow flickering off.
 6. Fainted: lying on the bottom of its cell, eyes as X shapes, tail glow dark, wings limp, a small "no signal" swirl above it.
 7. Happy / Victory: looping upward, eyes closed in happy arcs, tail glow at full brightness with sparkles.
 8. Asleep (Standby): hovering lower than usual, eyes closed as flat lines, tail glow dim, small pixel "Z z" shapes above.
Row 3 - BACK view (the player's own creature: seen from behind and slightly above, facing away toward
the upper right; no face visible):
 9. Back Idle A: its broad back and wings, the glowing progress-bar abdomen facing the viewer.
10. Back Idle B: 1 art pixel lower, slightly squashed.
11. Back attack: lunging forward away from the viewer toward the upper right.
12. Back hurt: flinching back toward the viewer (lower-left).
Row 4 - SPECIAL (front view):
13. Signature pose (final form): wings fully spread, progress bar at 100% and glowing bright, { } antennae raised.
14. Overheated: flustered, sweat drop, small white steam puffs rising off it, tail glow flashing amber.
15. Throttled: stiff frozen pose, eyes wide, small zig-zag sparks around the body, wings frozen mid-beat, glow stuttering.
16. Menu icon: head and upper body only, front view, simplified, drawn within a 32 x 32 art-pixel area
    centered in the cell (same 4x pixel size as the other cells).

== CONSISTENCY CHECKLIST (check before finishing) ==
- The same creature in all 16 cells: same proportions, eyes, palette and pixel size; only the pose and
  effects change.
- Progress-bar abdomen, { } antennae, code-window wings and >_ face wherever visible.
- It hovers at the same height in every cell except Fainted (which lies on the bottom).
- No text, labels, numbers, grid lines, borders or extra characters. Flat #FF00FF background everywhere.
````

## If something goes wrong (send as a follow-up)
- **The creature changes between frames:** "Keep the creature exactly as in cell 1 in every cell; only the pose changes. Redraw cells 6 and 11 to match." (name the cells that drifted)
- **It looks blurry or painted:** "Redo as hard-edged pixel art: every art pixel is a crisp 4x4 square, no anti-aliasing, palette colors only."
- **Words or grid lines appear:** "Remove every word, number, line and box. Flat #FF00FF background only."
- **Doesn't match the earlier stage:** "Use the attached earlier stage as the reference: same eyes, face shape and colors. Only make it bigger and add the upgrades."
- **16 frames is too many to keep consistent:** "Only draw rows 1 and 2; leave rows 3 and 4 as plain magenta." Then attach that result and ask for rows 3 and 4 the same way.
