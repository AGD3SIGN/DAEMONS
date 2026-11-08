# Single-stage Daemons

Paste one stage per image. Generate and approve each stage before the next.

## Dustbunny

````
Create ONE image: a pixel-art battle sprite sheet for ONE creature from my original indie game DAEMONS
(a monster-collecting RPG where technology comes alive: every creature is a real animal fused with
real IT hardware).

== CANVAS AND GRID ==
- Square image, 1024 x 1024 pixels.
- An invisible 4 x 4 grid: 16 cells, each 256 x 256. Do NOT draw grid lines, borders, boxes, panels,
  frames, labels, numbers or any text anywhere in the image.
- Exactly one sprite per cell, centered horizontally. In every cell the feet rest on the same baseline, 16 pixels above the bottom of the cell. Nothing crosses into a
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
Name: Dustbunny. Single stage (does not evolve). Type: Peripheral.
Concept: a scrappy rabbit made of lint and dust that lives behind desktop towers. Sneezy, scrappy and impossible to get rid of.
Body: a small fluffy round rabbit with messy edges and floppy ears.
Size: body height about 45% of the cell (about 29 of the 64 art pixels), same size in every frame.
Signature features (show in every frame where they would be visible):
1. Fluffy dust-ball body with jagged, messy outline tufts.
2. A stray USB cable tangled around it, with the plug end like a tail.
3. A few crumbs and tiny bits stuck in its fur.
4. A pink twitchy nose.
5. Big round dark eyes, each with one white shine pixel.
Palette (exact hex):
#2A2A30 outline | #9A9AA6 dust grey | #6A6A78 dust shadow | #C8C8D2 dust highlight |
#E8E8EE fluff white | #3A3A44 cable black | #B8BEC8 USB metal | #3C8EE0 USB blue |
#E88A9A nose pink | #D8A8B8 inner ear | #141418 eyes | #FFFFFF eye shine |
#F4F4F8 sneeze puff | #A8916A crumb tan | #7A808C metal shadow

== FRAMES (read left to right, top to bottom) ==
Row 1 - FRONT view (facing the viewer, body turned slightly toward the viewer's left):
 1. Idle A: sitting, fluff bristling, nose twitching.
 2. Idle B: identical to Idle A but 1 art pixel lower and slightly squashed wider (breathing).
 3. Physical attack: a tumbling roll toward the viewer's left, dust trailing.
 4. Special attack: a huge sneeze blasting a cloud of grey dust toward the viewer's left.
Row 2 - FRONT reactions:
 5. Hurt: recoiling to the right, eyes squeezed shut (> <), small white impact star at its upper-left,
    dust puffing off.
 6. Fainted: flattened into a dust pile, eyes as X shapes.
 7. Happy / Victory: bouncing up, eyes closed in happy arcs, fluff puffed.
 8. Asleep (Standby): flattened into a fluffy loaf, eyes closed as flat lines, small pixel "Z z".
Row 3 - BACK view (the player's own creature: seen from behind and slightly above, facing away toward
the upper right; no face visible):
 9. Back Idle A: its fluffy back with the USB-plug tail.
10. Back Idle B: 1 art pixel lower, slightly squashed.
11. Back attack: lunging forward away from the viewer toward the upper right.
12. Back hurt: flinching back toward the viewer (lower-left).
Row 4 - SPECIAL (front view):
13. Signature pose: puffed up twice its size, fluff bristling, mid-sneeze.
14. Overheated: flustered, sweat drop, small white steam puffs rising off it, fluff singed at the tips.
15. Throttled: stiff frozen pose, eyes wide, small zig-zag sparks around the body, tangled in its own cable.
16. Menu icon: head and upper body only, front view, simplified, drawn within a 32 x 32 art-pixel area
    centered in the cell (same 4x pixel size as the other cells).

== CONSISTENCY CHECKLIST (check before finishing) ==
- The same creature in all 16 cells: same proportions, eyes, palette and pixel size; only the pose and
  effects change.
- Messy dust fluff, USB-cable tail and pink nose wherever visible.
- Feet on the same baseline in every cell except Fainted and the Happy hop.
- No text, labels, numbers, grid lines, borders or extra characters. Flat #FF00FF background everywhere.
````

## Fanbat

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
Name: Fanbat. Single stage (does not evolve). Type: Hardware / Power.
Concept: a bat whose wings are 120 mm computer case fans. Swarms hang from server-room ceilings, humming at night.
Body: a small dark bat body with big ears, hanging or hovering between two large round fan wings.
Size: body height about 65% of the cell (about 42 of the 64 art pixels), same size in every frame.
Signature features (show in every frame where they would be visible):
1. Each wing is a square case-fan frame with round blades and an orange hub.
2. A red-and-black power cable tail ending in a small plug.
3. Big pointed ears with orange insides.
4. Two small white fangs.
5. Big yellow eyes with dark pupils and a white shine pixel.
Palette (exact hex):
#1E1A1A outline | #3A3A44 body | #24242C body shadow | #6A6E78 body highlight |
#18181C fan frame | #9EA4B0 fan blade | #D8DCE4 blade highlight | #E0703C fan hub |
#F2C63A power yellow | #D84848 cable red | #B04E28 inner ear | #FFFFFF fangs/shine |
#141418 pupil | #5CE07A LED green | #F4A070 hub highlight

== FRAMES (read left to right, top to bottom) ==
Row 1 - FRONT view (facing the viewer, body turned slightly toward the viewer's left):
 1. Idle A: hovering, fan blades spinning (curved motion lines).
 2. Idle B: identical to Idle A but 1 art pixel lower and slightly squashed wider (breathing).
 3. Physical attack: a diving bite toward the viewer's left.
 4. Special attack: fans at full speed, blasting a gust of air lines toward the viewer's left.
Row 2 - FRONT reactions:
 5. Hurt: recoiling to the right, eyes squeezed shut (> <), small white impact star at its upper-left,
    fans wobbling.
 6. Fainted: lying on the bottom of the cell, fans stopped, eyes as X shapes.
 7. Happy / Victory: spinning in a loop, eyes closed in happy arcs.
 8. Asleep (Standby): hanging upside down, wings folded, eyes closed, small pixel "Z z".
Row 3 - BACK view (the player's own creature: seen from behind and slightly above, facing away toward
the upper right; no face visible):
 9. Back Idle A: its back between the fan wings, the cable tail hanging down.
10. Back Idle B: 1 art pixel lower, slightly squashed.
11. Back attack: lunging forward away from the viewer toward the upper right.
12. Back hurt: flinching back toward the viewer (lower-left).
Row 4 - SPECIAL (front view):
13. Signature pose: wings fully spread, fans glowing, power cable crackling yellow.
14. Overheated: flustered, sweat drop, small white steam puffs rising off it, fan hubs glowing orange.
15. Throttled: stiff frozen pose, eyes wide, small zig-zag sparks around the body, fans stuck, sparks at the hubs.
16. Menu icon: head and upper body only, front view, simplified, drawn within a 32 x 32 art-pixel area
    centered in the cell (same 4x pixel size as the other cells).

== CONSISTENCY CHECKLIST (check before finishing) ==
- The same creature in all 16 cells: same proportions, eyes, palette and pixel size; only the pose and
  effects change.
- Case-fan wings, cable tail, orange ears and yellow eyes wherever visible.
- It hovers at the same height in every cell except Fainted (which lies on the bottom).
- No text, labels, numbers, grid lines, borders or extra characters. Flat #FF00FF background everywhere.
````

## Ramster

````
Create ONE image: a pixel-art battle sprite sheet for ONE creature from my original indie game DAEMONS
(a monster-collecting RPG where technology comes alive: every creature is a real animal fused with
real IT hardware).

== CANVAS AND GRID ==
- Square image, 1024 x 1024 pixels.
- An invisible 4 x 4 grid: 16 cells, each 256 x 256. Do NOT draw grid lines, borders, boxes, panels,
  frames, labels, numbers or any text anywhere in the image.
- Exactly one sprite per cell, centered horizontally. In every cell the feet rest on the same baseline, 16 pixels above the bottom of the cell. Nothing crosses into a
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
Name: Ramster. Single stage (does not evolve). Type: Hardware.
Concept: a hamster fused with a RAM stick. Hyper and tireless; it runs on its wheel to keep its memory refreshed.
Body: a round, chubby hamster with tiny paws and a stub tail.
Size: body height about 55% of the cell (about 35 of the 64 art pixels), same size in every frame.
Signature features (show in every frame where they would be visible):
1. A RAM-module stripe along its back: green board with 4 black chips and a row of gold pins along the bottom edge.
2. A tiny grey exercise wheel it carries or runs in.
3. Chubby cream cheeks.
4. A small orange activity LED on its forehead.
5. Big round dark eyes with a white shine pixel.
Palette (exact hex):
#2A1E1A outline | #E8B878 fur | #B8844A fur shadow | #F8E0B8 fur highlight |
#F8F0E0 belly cream | #2E7A4A PCB green | #1E5232 PCB shadow | #D8A830 gold pins |
#24242C chip black | #9EA4B0 wheel grey | #6A6E78 wheel shadow | #E88A9A nose pink |
#141010 eyes | #FFFFFF eye shine | #E0703C LED orange

== FRAMES (read left to right, top to bottom) ==
Row 1 - FRONT view (facing the viewer, body turned slightly toward the viewer's left):
 1. Idle A: sitting up, paws together, cheeks puffed.
 2. Idle B: identical to Idle A but 1 art pixel lower and slightly squashed wider (breathing).
 3. Physical attack: rolling inside its wheel toward the viewer's left.
 4. Special attack: chips on its back lighting up, firing a stream of small data squares toward the viewer's left.
Row 2 - FRONT reactions:
 5. Hurt: recoiling to the right, eyes squeezed shut (> <), small white impact star at its upper-left,
    LED flickering.
 6. Fainted: flopped on its side, eyes as X shapes, wheel tipped over.
 7. Happy / Victory: running in its wheel with motion lines, eyes closed in happy arcs.
 8. Asleep (Standby): curled in its wheel, eyes closed, small pixel "Z z".
Row 3 - BACK view (the player's own creature: seen from behind and slightly above, facing away toward
the upper right; no face visible):
 9. Back Idle A: its back showing the full RAM-module stripe.
10. Back Idle B: 1 art pixel lower, slightly squashed.
11. Back attack: lunging forward away from the viewer toward the upper right.
12. Back hurt: flinching back toward the viewer (lower-left).
Row 4 - SPECIAL (front view):
13. Signature pose: standing tall, paws raised, all chips lit, wheel spinning behind.
14. Overheated: flustered, sweat drop, small white steam puffs rising off it, RAM chips glowing.
15. Throttled: stiff frozen pose, eyes wide, small zig-zag sparks around the body, frozen mid-run in its wheel.
16. Menu icon: head and upper body only, front view, simplified, drawn within a 32 x 32 art-pixel area
    centered in the cell (same 4x pixel size as the other cells).

== CONSISTENCY CHECKLIST (check before finishing) ==
- The same creature in all 16 cells: same proportions, eyes, palette and pixel size; only the pose and
  effects change.
- RAM-module back stripe, wheel, forehead LED and cheeks wherever visible.
- Feet on the same baseline in every cell except Fainted and the Happy hop.
- No text, labels, numbers, grid lines, borders or extra characters. Flat #FF00FF background everywhere.
````

## Servurtle

````
Create ONE image: a pixel-art battle sprite sheet for ONE creature from my original indie game DAEMONS
(a monster-collecting RPG where technology comes alive: every creature is a real animal fused with
real IT hardware).

== CANVAS AND GRID ==
- Square image, 1024 x 1024 pixels.
- An invisible 4 x 4 grid: 16 cells, each 256 x 256. Do NOT draw grid lines, borders, boxes, panels,
  frames, labels, numbers or any text anywhere in the image.
- Exactly one sprite per cell, centered horizontally. In every cell the feet rest on the same baseline, 16 pixels above the bottom of the cell. Nothing crosses into a
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
Name: Servurtle. Single stage (does not evolve). Type: Hardware.
Concept: a sturdy turtle carrying a 2U rack server as its shell. Slow, reliable and stubborn; it has not been rebooted in years.
Body: a wide, low turtle with thick legs and a big flat server shell.
Size: body height about 75% of the cell (about 48 of the 64 art pixels), same size in every frame.
Signature features (show in every frame where they would be visible):
1. Its shell is a 2U rack server: black chassis, a row of silver drive bays on the front edge with green/amber LEDs.
2. Small rack ears (mounting tabs) sticking out of the shell's front corners.
3. A blue network cable trailing from the back like a tail.
4. A beak-like mouth and a calm expression.
5. Small round dark eyes with a white shine pixel.
Palette (exact hex):
#1E2418 outline | #7A9A6A skin | #4E6A42 skin shadow | #A8C898 skin highlight |
#2A2A30 chassis black | #6A6E78 chassis grey | #9EA4B0 chassis highlight |
#D8DCE4 drive bay silver | #5CE07A LED green | #F2C63A LED amber | #E0703C accent orange |
#C8B078 beak | #141410 eyes | #FFFFFF eye shine | #3C8EE0 cable blue

== FRAMES (read left to right, top to bottom) ==
Row 1 - FRONT view (facing the viewer, body turned slightly toward the viewer's left):
 1. Idle A: standing firm, head out, LEDs blinking.
 2. Idle B: identical to Idle A but 1 art pixel lower and slightly squashed wider (breathing).
 3. Physical attack: a heavy shell-first charge toward the viewer's left.
 4. Special attack: pulling into its shell while the drive-bay LEDs fire a beam of orange light toward the viewer's left.
Row 2 - FRONT reactions:
 5. Hurt: recoiling to the right, eyes squeezed shut (> <), small white impact star at its upper-left,
    LEDs flashing red-orange.
 6. Fainted: flipped on its back, legs up, eyes as X shapes.
 7. Happy / Victory: head raised, eyes closed in happy arcs, all LEDs green.
 8. Asleep (Standby): head and legs pulled into the shell, LEDs dim, small pixel "Z z".
Row 3 - BACK view (the player's own creature: seen from behind and slightly above, facing away toward
the upper right; no face visible):
 9. Back Idle A: the top and back of the server shell with vents and the cable tail.
10. Back Idle B: 1 art pixel lower, slightly squashed.
11. Back attack: lunging forward away from the viewer toward the upper right.
12. Back hurt: flinching back toward the viewer (lower-left).
Row 4 - SPECIAL (front view):
13. Signature pose: standing tall on its hind legs, all drive LEDs lit.
14. Overheated: flustered, sweat drop, small white steam puffs rising off it, vents puffing steam, LEDs amber.
15. Throttled: stiff frozen pose, eyes wide, small zig-zag sparks around the body, half-retracted into its shell.
16. Menu icon: head and upper body only, front view, simplified, drawn within a 32 x 32 art-pixel area
    centered in the cell (same 4x pixel size as the other cells).

== CONSISTENCY CHECKLIST (check before finishing) ==
- The same creature in all 16 cells: same proportions, eyes, palette and pixel size; only the pose and
  effects change.
- Server shell with drive bays and LEDs, rack ears and cable tail wherever visible.
- Feet on the same baseline in every cell except Fainted and the Happy hop.
- No text, labels, numbers, grid lines, borders or extra characters. Flat #FF00FF background everywhere.
````

## If something goes wrong (send as a follow-up)
- **The creature changes between frames:** "Keep the creature exactly as in cell 1 in every cell; only the pose changes. Redraw cells 6 and 11 to match." (name the cells that drifted)
- **It looks blurry or painted:** "Redo as hard-edged pixel art: every art pixel is a crisp 4x4 square, no anti-aliasing, palette colors only."
- **Words or grid lines appear:** "Remove every word, number, line and box. Flat #FF00FF background only."
- **Doesn't match the earlier stage:** "Use the attached earlier stage as the reference: same eyes, face shape and colors. Only make it bigger and add the upgrades."
- **16 frames is too many to keep consistent:** "Only draw rows 1 and 2; leave rows 3 and 4 as plain magenta." Then attach that result and ask for rows 3 and 4 the same way.
