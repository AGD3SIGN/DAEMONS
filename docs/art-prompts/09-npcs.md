# Overworld NPC prompts (ChatGPT)

One character per image. Paste the **whole** block (style rules + character) each time.

Save the approved image as `art_src/characters/<id>_gpt_v1.png` (or .webp), then:

    godot --headless -s tools/art_import/import_character.gd -- art_src/characters/<id>_gpt_v1.png <id>
    cd <aseprite-mcp> && set -a && . ./.env && set +a
    PYTHONPATH=. uv run python <repo>/tools/art_import/polish_sheet.py <repo>/assets/sprites/characters/<id>.png --colors 12
    PYTHONPATH=. uv run python <repo>/tools/art_import/polish_sheet.py <repo>/assets/sprites/characters/<id>_battle.png --colors 16

The importer makes the 20x28 walking sheet and the 48x72 battle figure from the same image.

## Style rules (paste first, every time)

```
STYLE RULES (follow exactly):
- Original character for an indie game called DAEMONS, set in a small town where IT and everyday life mix.
- Pixel art in the style of early-2000s handheld RPG overworld sprites (Game Boy Advance era): crisp
  hard-edged pixels, no anti-aliasing, no blur, no gradients, no glow.
- Chibi human, head about 40% of the body height, big readable face, clear silhouette.
- 1-pixel dark outline (dark tint of the nearby color, not pure black). Simple cel shading, light from
  the top-left. Maximum 12 colors plus background. Same palette in every frame.
- Flat #FF00FF magenta background. No ground, no shadows, no scenery, no text, no watermark, no border.
- Must NOT resemble any existing game or anime character.

Make ONE sprite sheet: 3 columns x 4 rows of the same character, evenly spaced with clear gaps:
Columns: Stand, Walk step A (left foot forward), Walk step B (right foot forward).
Rows: facing DOWN (toward viewer), facing UP (back), facing LEFT, facing RIGHT.
Same character, same palette, same size, feet on the same line in every frame.
```

## Missing art (these show as placeholder blocks today)

| id | Where | Character line (paste after the style rules) |
|---|---|---|
| `kevins_mom` | Kevin's house | `CHARACTER: Kevin's mom: a tired but sharp woman in her 40s, blond hair in a messy bun (same blond as her son), teal cardigan over a white tee, reading glasses pushed up on her head, holding a home Wi-Fi router under one arm, grey slacks, slippers.` |
| `gate_guard` | Patch Town north gate | `CHARACTER: a building security guard: broad-shouldered, short black hair, dark slate-grey uniform with a yellow "SECURITY" patch, a badge-reader scanner clipped to the belt, walkie-talkie on the shoulder, arms-crossed stern look, black boots.` |
| `angler` | Patch Town pond | `CHARACTER: an angler: older man with a scruffy auburn beard, bucket hat covered in fishing lures and a few USB sticks, navy fishing vest with many pockets, rolled-up khaki pants, rubber boots, holding a fishing rod made from a long network antenna.` |

## New townsfolk (to fill out the towns)

| id | Suggested spot | Character line |
|---|---|---|
| `cable_tech` | Route 1 / town edge | `CHARACTER: a network cable installer: orange hard hat, hi-vis yellow vest over a blue work shirt, a spool of blue Ethernet cable over one shoulder, tool belt with crimpers, work boots.` |
| `printer_lady` | Help Desk waiting area | `CHARACTER: an office worker fighting the printer: curly red hair, green cardigan, lanyard, holding a jammed stack of paper with a frustrated face, brown skirt, flats.` |
| `retro_gamer` | Onboarding Town | `CHARACTER: a teen retro gamer: purple beanie, oversized black hoodie with a pixel heart, big headphones around the neck, holding a handheld game console, ripped jeans, high-top sneakers.` |
| `mainframe_grandpa` | Patch Town | `CHARACTER: a retired mainframe operator: bald with white side hair and a bushy moustache, short-sleeve white shirt with a pocket protector full of pens, brown suspenders, a punch card in his hand, walking cane.` |
| `delivery_drone_girl` | Route 1 | `CHARACTER: a young drone hobbyist: dark skin, short coily hair with goggles on her forehead, red bomber jacket, cargo shorts, holding a small quadcopter remote, sneakers.` |

## Follow-ups if a sheet drifts

- "Redraw this exact character, same palette and proportions, only changing the pose per frame."
- "The rows must be: down, up, left, right. Keep the gaps between poses even."
- "Remove the shadow under the feet and make the background flat #FF00FF."
