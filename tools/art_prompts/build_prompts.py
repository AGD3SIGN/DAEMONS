"""Builds the paste-ready ChatGPT sprite prompts in docs/art-prompts/ (one file per evolution line,
one full prompt per stage). Edit the creature data below and rerun:

    python3 tools/art_prompts/build_prompts.py

Every prompt repeats the full canvas/style/frame rules on purpose: ChatGPT forgets rules from earlier
messages, so each stage is pasted whole.
"""
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[2] / "docs" / "art-prompts"

SIZE_PX = {45: 29, 50: 32, 55: 35, 65: 42, 70: 45, 75: 48, 80: 51, 85: 54}

HEADER = """Create ONE image: a pixel-art battle sprite sheet for ONE creature from my original indie game DAEMONS
(a monster-collecting RPG where technology comes alive: every creature is a real animal fused with
real IT hardware).
{attach}
== CANVAS AND GRID ==
- Square image, 1024 x 1024 pixels.
- An invisible 4 x 4 grid: 16 cells, each 256 x 256. Do NOT draw grid lines, borders, boxes, panels,
  frames, labels, numbers or any text anywhere in the image.
- Exactly one sprite per cell, centered horizontally. {ground_rule} Nothing crosses into a
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
"""

FRAMES = """== FRAMES (read left to right, top to bottom) ==
Row 1 - FRONT view (facing the viewer, body turned slightly toward the viewer's left):
 1. Idle A: {idle}
 2. Idle B: identical to Idle A but 1 art pixel lower and slightly squashed wider (breathing).
 3. Physical attack: {phys}
 4. Special attack: {special}
Row 2 - FRONT reactions:
 5. Hurt: recoiling to the right, eyes squeezed shut (> <), small white impact star at its upper-left,
    {hurt}.
 6. Fainted: {faint}
 7. Happy / Victory: {happy}
 8. Asleep (Standby): {sleep}
Row 3 - BACK view (the player's own creature: seen from behind and slightly above, facing away toward
the upper right; no face visible):
 9. Back Idle A: {back}
10. Back Idle B: 1 art pixel lower, slightly squashed.
11. Back attack: lunging forward away from the viewer toward the upper right.
12. Back hurt: flinching back toward the viewer (lower-left).
Row 4 - SPECIAL (front view):
13. {frame13}
14. Overheated: flustered, sweat drop, small white steam puffs rising off it, {hot}.
15. Throttled: stiff frozen pose, eyes wide, small zig-zag sparks around the body, {throttle}.
16. Menu icon: head and upper body only, front view, simplified, drawn within a 32 x 32 art-pixel area
    centered in the cell (same 4x pixel size as the other cells).

== CONSISTENCY CHECKLIST (check before finishing) ==
- The same creature in all 16 cells: same proportions, eyes, palette and pixel size; only the pose and
  effects change.
- {check}
- {ground_check}
- No text, labels, numbers, grid lines, borders or extra characters. Flat #FF00FF background everywhere.
"""

GROUND = {
    "feet": ("In every cell the feet rest on the same baseline, 16 pixels above the bottom of the cell.",
             "Feet on the same baseline in every cell except Fainted and the Happy hop."),
    "body": ("In every cell the lowest part of the body rests on the same baseline, 16 pixels above the "
             "bottom of the cell.",
             "The body rests on the same baseline in every cell."),
    "hover": ("It flies: in every cell the lowest point of the body hovers at the same height, 40 pixels "
              "above the bottom of the cell (no shadow under it).",
              "It hovers at the same height in every cell except Fainted (which lies on the bottom)."),
}

UPGRADING = ("Upgrading (evolution): arms/wings raised, the whole body filled flat white #FFFFFF with only "
             "the outline kept, short energy lines radiating outward.")


def stage(**kw):
    return kw


# ---------------------------------------------------------------------------------------------------
# Creature data. Each line: name, type, palette (15 colors), shared frame text, and stages.
# Stage keys: name, n, of, concept, body, size, features, plus optional frame overrides.
# ---------------------------------------------------------------------------------------------------

LINES = [
    dict(
        file="01-chipmunk-line", title="Chipmunk → Munkboard → Mainmunk", type="Hardware", ground="feet",
        palette="#2A1E1A outline | #E0703C fur | #B04E28 fur shadow | #F4A070 fur highlight |\n"
                "#F8E8C8 cream belly | #D8BC94 belly shadow | #9EA4B0 heatsink metal | #6A6E78 metal shadow |\n"
                "#D8DCE4 metal highlight | #D8A830 gold pins/traces | #3A3A44 chip black | #1A1214 eyes |\n"
                "#FFFFFF eye shine | #5CE07A status LED | #E88A8A nose",
        frames=dict(
            hurt="fins rattling",
            faint="flopped on its side on the baseline, eyes as X shapes, fans stopped, a thin grey smoke "
                  "wisp above it.",
            happy="hopping 2 art pixels above the baseline, eyes closed in happy arcs, paws up, tail fan "
                  "spinning (motion lines).",
            sleep="curled up with its tail wrapped around it, eyes closed as flat lines, small pixel "
                  "\"Z z\" shapes above, LEDs dim.",
            hot="cheek heatsinks glowing orange, fur puffed up",
            throttle="tail fan stuck mid-spin",
        ),
        stages=[
            stage(name="Chipmunk", n=1, of=3,
                  concept="a baby chipmunk fused with a CPU heatsink. Warm, eager and a little smug; it "
                          "stores waste heat in its cheeks.",
                  body="small and round, big head, puffy cheeks, short legs, a long curled tail.",
                  size=55,
                  features=["Puffy cheeks made of finned aluminum heatsinks (grey fins, light from the "
                            "top-left).",
                            "A square CPU chip pattern on its cream belly with tiny gold pins along the edges.",
                            "A small orange cable-coil tail ending in a tiny spinning fan.",
                            "Copper-gold trace lines running down its back like chipmunk stripes.",
                            "Big round dark eyes, each with one white shine pixel in the upper-left."],
                  idle="standing on its hind legs, paws together at its chest, tail curled up behind it.",
                  phys="tackling forward toward the viewer's left, cheeks puffed, tail fan streaking behind.",
                  special="cheeks puffed full, blowing a short blast of orange heat waves (stepped pixel "
                          "lines) toward the viewer's left.",
                  back="back of the head and body with the gold trace stripes, the fan tail curled up on the "
                       "right.",
                  check="Heatsink cheeks, CPU belly, fan tail and trace stripes wherever they would be visible."),
            stage(name="Munkboard", n=2, of=3,
                  concept="the SAME chipmunk grown into a strong young adult, now fused with a desktop "
                          "motherboard. Confident and protective; it stuffs spare parts in its cheeks.",
                  body="taller and sturdier, broad chest, longer limbs, a thick fluffy tail.",
                  size=70,
                  keep="the same face, eye shape and shine, the same orange/cream/metal palette, heatsink "
                       "cheeks, the trace stripes and the fan tail.",
                  features=["Its back and shoulders are covered by a motherboard plate in "
                            "orange, copper and gold traces (no green), with 3 small dark chip squares.",
                            "Cheek pouches stuffed with 2 small RAM sticks poking out (dark chips, gold pins).",
                            "A bigger 2-blade-ring fan at the tail tip.",
                            "A small square CPU socket plate on its belly with gold pins.",
                            "Big round dark eyes, each with one white shine pixel in the upper-left."],
                  idle="standing upright, fists ready, tail arched up behind it.",
                  phys="a two-handed shoulder charge toward the viewer's left, traces lit up.",
                  special="slamming its paws down, orange circuit-trace lines racing across the ground "
                          "toward the viewer's left.",
                  back="back of the head and the motherboard plate on its back, fan tail raised on the right.",
                  check="Motherboard back plate, RAM cheek pouches, CPU belly and big fan tail wherever "
                        "visible."),
            stage(name="Mainmunk", n=3, of=3,
                  concept="the SAME chipmunk as a huge, wise elder, fused with a room-sized mainframe. "
                          "Calm, ancient and unshakable; it has never once rebooted.",
                  body="massive and heavy-set, sitting-upright bulk, thick arms, a huge plume tail.",
                  size=85,
                  keep="the same face, eye shape and shine, the same orange/cream/metal palette, heatsink "
                       "cheeks (now larger), the trace stripes and the fan tail.",
                  features=["Its chest is a server-cabinet front with rows of tiny blinking green LEDs.",
                            "A mane of bundled cables around its neck and shoulders, ending in small plugs.",
                            "A plume tail with TWO fans stacked along it.",
                            "Large heatsink cheeks and copper trace stripes down its back.",
                            "Big round dark eyes with a white shine pixel, with heavier brows (elder look)."],
                  idle="sitting tall and heavy, paws resting on its knees, LEDs blinking.",
                  phys="a huge downward paw slam toward the viewer's left, cables swinging.",
                  special="every chest LED lit, firing a beam of orange data blocks from its chest toward "
                          "the viewer's left.",
                  back="its broad back with trace stripes and the cable mane, the double-fan tail on the "
                       "right.",
                  frame13="Signature pose (final form): standing at full height, arms wide, all LEDs lit, "
                          "fans spinning (motion lines).",
                  check="Server-cabinet chest LEDs, cable mane, double-fan tail and heatsink cheeks wherever "
                        "visible."),
        ],
    ),
    dict(
        file="02-pingo-line", title="Pingo → Pengwan → Emperoute", type="Network", ground="feet",
        palette="#1B2A44 outline | #3C8EE0 body | #2A64A8 body shadow | #7DB8F0 body highlight |\n"
                "#F4F8FC belly | #C8D4E0 belly shadow | #F2A23A beak/feet | #C8702A beak/feet shadow |\n"
                "#9AA4B4 antenna/metal | #5A6474 metal shadow | #5CE07A LED green | #F2C63A LED amber/gold |\n"
                "#141A24 eyes | #FFFFFF eye shine | #6FE0F0 signal/effect cyan",
        frames=dict(
            hurt="antennas bent",
            faint="flopped onto its side on the baseline, eyes as X shapes, all LEDs dark grey, antennas "
                  "drooping, a small cyan \"no signal\" swirl above it.",
            happy="hopping 2 art pixels above the baseline, eyes closed in happy arcs, flippers raised, all "
                  "LEDs green.",
            sleep="sitting, eyes closed as flat lines, head tilted, small pixel \"Z z\" shapes above, LEDs "
                  "dim amber.",
            hot="LEDs amber, orange #F2A23A flush on the cheeks",
            throttle="one antenna crooked, cyan sparks",
        ),
        stages=[
            stage(name="Pingo", n=1, of=3,
                  concept="a baby penguin chick fused with a home Wi-Fi router. Anxious and eager; it "
                          "\"pings\" everything and waits nervously for a reply.",
                  body="a very round chick, almost a ball; head and body are one shape. Short stubby "
                       "flippers, tiny feet.",
                  size=55,
                  features=["Two thin router antennas on top of the head, grey with rounded tips, angled "
                            "slightly apart.",
                            "A white belly patch with a horizontal row of 4 tiny square status LEDs: green, "
                            "green, amber, green.",
                            "Big round dark eyes, each with one white shine pixel in the upper-left.",
                            "A small orange beak and small orange feet.",
                            "A little tuft of fluffy down between the antennas."],
                  idle="standing neutral, antennas upright, flippers relaxed at its sides.",
                  phys="belly-flop lunge toward the viewer's left, flippers swept back, determined eyes.",
                  special="antenna tips glowing cyan, 3 cyan \"ping\" arcs radiating from the antennas "
                          "toward the viewer's left, beak open.",
                  back="back of the head and body, both antennas visible, flipper edges at the sides.",
                  check="Two antennas, belly LEDs, orange beak and feet wherever they would be visible."),
            stage(name="Pengwan", n=2, of=3,
                  concept="the SAME penguin grown into a young adult, now fused with an office network "
                          "switch. Confident and organized; it routes everything.",
                  body="an upright, sleeker adult penguin with a defined neck and longer flippers.",
                  size=70,
                  keep="the same eye shape and shine, the same blue/white/orange palette, the antenna idea, "
                       "the belly LED idea, the beak and feet shape and colors.",
                  features=["Four shorter antennas in a row across the top of the head, like a crown.",
                            "The belly patch is a switch front panel: 2 rows of 4 tiny dark square ports "
                            "(outline color), each with a green or amber LED dot above it.",
                            "Thin blue cable cuffs around both flippers, ending in small plug shapes.",
                            "A small plain label-sticker shape on the chest (no text on it).",
                            "Big round dark eyes with a white shine pixel; orange beak and feet."],
                  idle="standing tall and proud, flippers slightly out, antennas upright.",
                  phys="a sweeping flipper slap toward the viewer's left, cable cuffs trailing.",
                  special="a stream of small cyan data cubes fired along a cable from its flipper toward "
                          "the viewer's left.",
                  back="back of the head with the antenna crown, sleek back, cable cuffs on the flippers.",
                  check="Antenna crown, port-panel belly, cable cuffs, orange beak and feet wherever visible."),
            stage(name="Emperoute", n=3, of=3,
                  concept="the SAME penguin as a towering emperor penguin, fused with the internet "
                          "backbone. Regal and calm; it carries the whole valley's traffic.",
                  body="tall and majestic emperor-penguin build, broad chest, long flippers, upright posture.",
                  size=85,
                  keep="the same eye shape and shine, the same blue/white/orange palette, the antenna idea, "
                       "the belly LEDs, the beak and feet.",
                  features=["A small satellite-dish crest on top of its head with a short antenna in the "
                            "middle.",
                            "A long cape down its back made of thin fiber-optic strands with cyan glowing "
                            "tips.",
                            "A gold #F2C63A patch on each side of its neck (emperor markings).",
                            "A tall white belly with a vertical column of status LEDs.",
                            "Big round dark eyes with a white shine pixel, calm half-lidded look."],
                  idle="standing tall, flippers folded in front, cape draped behind.",
                  phys="a crushing double-flipper strike toward the viewer's left, cape flaring.",
                  special="the dish crest aimed forward, firing a thick cyan beam of light pulses toward the "
                          "viewer's left, cape strands glowing.",
                  back="its back covered by the fiber-optic cape, dish crest on top.",
                  frame13="Signature pose (final form): flippers spread wide, cape fanned out, dish crest "
                          "glowing, cyan rings around it.",
                  check="Dish crest, fiber cape, gold neck patches, LED belly, orange beak and feet wherever "
                        "visible."),
        ],
    ),
    dict(
        file="03-firefly-line", title="Glowbit → Scriptfly → Compilume", type="Software", ground="hover",
        palette="#142418 outline | #2E6B3E body shadow | #4CC06A body | #8EE89A body highlight |\n"
                "#C8F86A glow lime | #F8FFD0 glow core | #A8E0D0 wing | #6AA898 wing shadow | #E0F0E8 wing "
                "highlight |\n#101814 screen black | #5CF07A code green | #F2C63A progress amber | #24382A legs |\n"
                "#0C140E eyes | #FFFFFF eye shine",
        frames=dict(
            hurt="glow flickering off",
            faint="lying on the bottom of its cell, eyes as X shapes, tail glow dark, wings limp, a small "
                  "\"no signal\" swirl above it.",
            happy="looping upward, eyes closed in happy arcs, tail glow at full brightness with sparkles.",
            sleep="hovering lower than usual, eyes closed as flat lines, tail glow dim, small pixel \"Z z\" "
                  "shapes above.",
            hot="tail glow flashing amber",
            throttle="wings frozen mid-beat, glow stuttering",
        ),
        stages=[
            stage(name="Glowbit", n=1, of=3,
                  concept="a baby firefly whose glowing tail blinks like a text cursor. Curious and quick; "
                          "it follows whoever types the fastest.",
                  body="a tiny round bug with an oversized head, two little wings and a big glowing tail "
                       "segment.",
                  size=45,
                  features=["Its face is a small black screen showing a green \">_\" (a right arrow and an "
                            "underscore cursor) as its mouth area, with two round eyes above it.",
                            "A glowing lime tail segment shaped like a rectangular cursor block.",
                            "Two small rounded translucent-looking wings (flat pale teal, no transparency).",
                            "Two short antennae with tiny glowing dots at the tips.",
                            "Big round dark eyes, each with one white shine pixel in the upper-left."],
                  idle="hovering, wings mid-beat, tail glowing.",
                  phys="a quick dart toward the viewer's left, leaving a short trail of green pixels.",
                  special="tail glow flaring, firing a stream of small green code blocks toward the viewer's "
                          "left.",
                  back="back of the bug, wings spread, the glowing cursor tail facing the viewer.",
                  check="The >_ screen face, cursor-block glowing tail, small wings and glowing antennae "
                        "wherever visible."),
            stage(name="Scriptfly", n=2, of=3,
                  concept="the SAME firefly grown into a sleek adult. Clever and talkative; it writes "
                          "glowing script in the air as it flies.",
                  body="a longer, slimmer firefly body with a defined thorax, six thin legs and two pairs of "
                       "wings.",
                  size=70,
                  keep="the same >_ screen face, eye shape and shine, the same green/lime palette, the "
                       "glowing tail and the glowing antennae.",
                  features=["Its two pairs of wings look like small code windows: dark rectangles with "
                            "pale borders and 2-3 lines of green \"text\" dashes (not readable letters).",
                            "A longer glowing tail that leaves a short dotted green line behind it.",
                            "Long curling antennae with glowing tips.",
                            "The >_ screen face, now with the cursor blinking larger.",
                            "Big round dark eyes with a white shine pixel."],
                  idle="hovering upright, wings open, writing a short glowing squiggle in the air.",
                  phys="spinning forward toward the viewer's left, wings edge-first.",
                  special="drawing a glowing green rune of code dashes in the air and launching it toward "
                          "the viewer's left.",
                  back="back of the body with both pairs of code-window wings spread.",
                  check="Code-window wings, >_ face, long glowing tail and antennae wherever visible."),
            stage(name="Compilume", n=3, of=3,
                  concept="the SAME firefly as a giant, ancient firefly, fused with a compiler. Patient and "
                          "powerful; it can build anything from raw code.",
                  body="a large, armored firefly with a heavy thorax, broad wings and a huge glowing abdomen.",
                  size=85,
                  keep="the same >_ screen face, eye shape and shine, the same green/lime palette, the "
                       "glowing tail and the glowing antennae.",
                  features=["Its huge abdomen is a horizontal build-progress bar: segmented, about 3/4 "
                            "filled with glowing lime, the rest dark.",
                            "Antennae curved into the shape of curly braces { }.",
                            "Broad wings with code-window panels.",
                            "Armored thorax plates edged in amber.",
                            "The >_ screen face and big dark eyes with a white shine pixel."],
                  idle="hovering heavily, wings wide, progress bar glowing.",
                  phys="a heavy body-slam dive toward the viewer's left, abdomen first.",
                  special="the progress bar filling to 100%, then blasting a wide beam of lime light toward "
                          "the viewer's left.",
                  back="its broad back and wings, the glowing progress-bar abdomen facing the viewer.",
                  frame13="Signature pose (final form): wings fully spread, progress bar at 100% and "
                          "glowing bright, { } antennae raised.",
                  check="Progress-bar abdomen, { } antennae, code-window wings and >_ face wherever visible."),
        ],
    ),
    dict(
        file="04-wormby-line", title="Wormby → Wormhole", type="Malware", ground="body",
        palette="#2A0E1C outline | #B23A6B body | #7E2449 body shadow | #E07AA4 body highlight |\n"
                "#5A2A6E band purple | #8B5AA0 band highlight | #6FE0F0 glitch cyan | #A8F05A glitch lime |\n"
                "#2A2A30 cable black | #6A6A78 cable grey | #140810 eyes | #FFFFFF eye shine |\n"
                "#F4E8F0 packet white | #1A0A2E warp dark | #F8E8FF warp star",
        frames=dict(
            hurt="segments scattering slightly",
            faint="lying flat in an S-shape on the baseline, eyes as X shapes, glitch pixels fading.",
            happy="bouncing up in a happy arch, eyes closed in happy arcs, a few glitch sparkles.",
            sleep="coiled into a loop, eyes closed as flat lines, small pixel \"Z z\" shapes above.",
            hot="segments glowing brighter magenta",
            throttle="body frozen in a zig-zag, glitch pixels stuck in place",
        ),
        stages=[
            stage(name="Wormby", n=1, of=2,
                  concept="a small worm that tunnels through cable jackets and copies itself. Sneaky and "
                          "mischievous; where there's one, there are soon a hundred.",
                  body="a short, chubby segmented worm, raised up in a curious S-curve, no legs.",
                  size=45,
                  features=["Its body is 5 round segments, like chained data packets, each with a purple "
                            "band.",
                            "Glitchy eyes: big round eyes with a few misaligned cyan/lime pixels at the edges.",
                            "A short frayed cable sticking out of its tail end.",
                            "A tiny copy of itself (2-pixel-tall silhouette) peeking from behind in some "
                            "frames.",
                            "Each eye has one white shine pixel in the upper-left."],
                  idle="raised up in an S-curve, head tilted curiously.",
                  phys="lunging head-first toward the viewer's left like a spring.",
                  special="splitting a small glitchy copy of itself that flies toward the viewer's left.",
                  back="its segmented back curving away, the frayed cable tail toward the viewer.",
                  check="Packet segments with purple bands, glitch eyes and frayed cable tail wherever "
                        "visible."),
            stage(name="Wormhole", n=2, of=2,
                  concept="the SAME worm grown long and powerful, now able to fold the network so distant "
                          "hosts touch. Eerie and smug; packets arrive before they were sent.",
                  body="a long, thick segmented worm coiled in a big loop, raised head, no legs.",
                  size=75,
                  keep="the same glitch eyes and shine, the same magenta/purple palette, the packet segments "
                       "with purple bands and the cable tail.",
                  features=["A swirling dark portal ring (warp dark with tiny white stars) floating where its "
                            "coil loops, as if it passes through space.",
                            "8 or more packet segments with purple bands.",
                            "Glitch pixels trailing from its body edges.",
                            "A wider mouth ringed with small teeth-like pixel nubs.",
                            "Glitch eyes with a white shine pixel."],
                  idle="coiled through its portal loop, head raised high.",
                  phys="diving into a portal and bursting out toward the viewer's left.",
                  special="opening a big portal in front of itself that pulls stars and packets toward the "
                          "viewer's left.",
                  back="its long coiled back and the portal loop, seen from behind.",
                  frame13="Signature pose (final form): fully coiled around a large portal, glitch pixels "
                          "orbiting.",
                  check="Portal loop, packet segments, glitch eyes and cable tail wherever visible."),
        ],
    ),
    dict(
        file="05-pigeon-line", title="Spigeon → Botgeon", type="Malware", ground="feet",
        palette="#2A1420 outline | #8A7A90 feathers | #5E5068 feather shadow | #B8AEC0 feather highlight |\n"
                "#B23A6B neck sheen magenta | #7A4FA0 neck sheen purple | #F4F0E8 envelope white |\n"
                "#C8C0B0 envelope shadow | #D84848 stamp red | #E8A060 beak/feet | #B8703C beak/feet shadow |\n"
                "#F07830 eye iris | #140A10 pupil | #FFFFFF eye shine | #9AA4B4 dish metal",
        frames=dict(
            hurt="loose letters flying off",
            faint="flopped on its side on the baseline, eyes as X shapes, envelopes scattered around it.",
            happy="puffed-up chest, eyes closed in happy arcs, wings raised, a few letters tossed up like "
                  "confetti.",
            sleep="fluffed into a ball, head tucked, eyes closed as flat lines, small pixel \"Z z\" shapes "
                  "above.",
            hot="feathers ruffled, red stamp glowing",
            throttle="frozen mid-coo, small cyan error sparks",
        ),
        stages=[
            stage(name="Spigeon", n=1, of=2,
                  concept="a scruffy young city pigeon stuffed with junk mail. Pushy and cheerful; it keeps "
                          "delivering letters nobody asked for.",
                  body="a plump pigeon with a round chest, small head, short legs.",
                  size=50,
                  features=["Its wings are folded white envelopes with a V-shaped flap line.",
                            "Junk letters (small white rectangles) poking out of its chest feathers.",
                            "A small red stamp-shaped patch on its chest.",
                            "Iridescent magenta/purple sheen on its neck (two flat color bands).",
                            "Orange eyes with a dark pupil and one white shine pixel; orange beak and feet."],
                  idle="standing with chest puffed out, head bobbed forward.",
                  phys="a pecking lunge toward the viewer's left.",
                  special="flapping its envelope wings, launching 3 small white envelopes toward the "
                          "viewer's left.",
                  back="back of the pigeon with the envelope wings folded, tail feathers toward the viewer.",
                  check="Envelope wings, junk letters, red stamp patch and neck sheen wherever visible."),
            stage(name="Botgeon", n=2, of=2,
                  concept="the SAME pigeon grown huge, now commanding a botnet. Loud and bossy; one coo and "
                          "every inbox in the valley fills.",
                  body="a large, broad-chested pigeon, puffed and imposing, thick legs.",
                  size=80,
                  keep="the same eye design and shine, the same grey/magenta/purple palette, the envelope "
                       "wings, the junk letters and the neck sheen.",
                  features=["Three small grey satellite-dish shapes among its back feathers.",
                            "A crest of three tall feathers shaped like \"! ! !\" (red tips).",
                            "Larger envelope wings with red stamps on them.",
                            "A big puffed chest stuffed with many letters.",
                            "Orange eyes with a dark pupil and a white shine pixel; orange beak and feet."],
                  idle="standing tall, chest puffed, crest raised.",
                  phys="a heavy wing-buffet toward the viewer's left, letters flying.",
                  special="cooing with its beak open while a swarm of small envelopes streams out toward "
                          "the viewer's left.",
                  back="its broad back with the dish feathers and the !!! crest.",
                  frame13="Signature pose (final form): wings spread wide, crest up, envelopes orbiting it.",
                  check="Dish feathers, !!! crest, envelope wings, letters and neck sheen wherever visible."),
        ],
    ),
    dict(
        file="06-cablesnake-line", title="Cablesnake → Patchviper", type="Network", ground="body",
        palette="#142238 outline | #3C8EE0 cable blue | #2A64A8 cable shadow | #7DB8F0 cable highlight |\n"
                "#F4F8FC jacket stripe | #C8E4F0 plug clear | #8AB0C8 plug shadow | #D8A830 gold contacts |\n"
                "#E05A5A tongue | #F2C63A eye yellow | #141A24 pupil | #FFFFFF eye shine |\n"
                "#9AA4B4 panel grey | #3A4454 panel dark | #5CE07A LED green",
        frames=dict(
            hurt="coils loosening",
            faint="lying limp in a loose tangle on the baseline, eyes as X shapes, plug head unplugged and "
                  "drooping.",
            happy="swaying up tall in a happy S, eyes closed in happy arcs, tongue out.",
            sleep="coiled in a neat loop like a tied cable, eyes closed as flat lines, small pixel \"Z z\" "
                  "shapes above.",
            hot="cable jacket glowing warm",
            throttle="body frozen in a tangled knot",
        ),
        stages=[
            stage(name="Cablesnake", n=1, of=2,
                  concept="a young snake made of tangled Ethernet cable. Shy but snappy; it bites when "
                          "unplugged.",
                  body="a medium snake coiled loosely, head raised, no limbs.",
                  size=55,
                  features=["Its body is a blue Ethernet cable with a thin white stripe running along it.",
                            "Its head is shaped like a clear RJ45 plug with gold contact lines on the top.",
                            "A small locking-clip tab on the back of its head.",
                            "A forked red tongue.",
                            "Yellow eyes with dark slit pupils and one white shine pixel each."],
                  idle="coiled, head raised and swaying.",
                  phys="a fast strike with its plug head toward the viewer's left.",
                  special="a crackling blue data pulse running down its body and leaping toward the "
                          "viewer's left.",
                  back="its coiled back, the plug head raised and turned away.",
                  check="Blue cable body with white stripe, RJ45 plug head and yellow eyes wherever visible."),
            stage(name="Patchviper", n=2, of=2,
                  concept="the SAME snake grown into a big viper that coils around patch panels and decides "
                          "which ports may talk. Proud and strict.",
                  body="a long, thick viper with a wide hood, coiled high.",
                  size=75,
                  keep="the same eyes and shine, the same blue/white palette, the cable body with a stripe and "
                       "the RJ45 plug head.",
                  features=["Its hood is a patch panel: a row of small dark square ports with green LEDs.",
                            "Short patch cables hanging from the hood ports like fringe.",
                            "A larger RJ45 plug head with gold contacts and a locking-clip crest.",
                            "A forked red tongue.",
                            "Yellow eyes with slit pupils and a white shine pixel."],
                  idle="coiled high with its patch-panel hood spread.",
                  phys="a heavy plug-head strike toward the viewer's left.",
                  special="every hood LED lighting up, firing blue pulses down the dangling cables toward "
                          "the viewer's left.",
                  back="the back of the hood (plain panel back) and the long coiled body.",
                  frame13="Signature pose (final form): hood fully flared, all port LEDs lit, coiled tall.",
                  check="Patch-panel hood with LEDs, dangling patch cables, plug head and yellow eyes "
                        "wherever visible."),
        ],
    ),
    dict(
        file="07-hare-line", title="Floppit → Ziphare → Discohare", type="Legacy", ground="feet",
        palette="#2A2218 outline | #D8C8A8 fur | #A8916A fur shadow | #F4ECD8 fur highlight |\n"
                "#3A8C8C 90s teal | #286464 teal shadow | #B8BEC8 metal silver | #7A808C metal shadow |\n"
                "#F8F8F0 label white | #E88A9A nose pink | #1A140E eyes | #FFFFFF eye shine |\n"
                "#4A6AB0 zip blue | #E070C8 disc pink sheen | #6FE0F0 disc cyan sheen",
        frames=dict(
            hurt="ears snapping flat",
            faint="flopped on its side on the baseline, eyes as X shapes, ears limp, a small \"disk error\" "
                  "swirl above it.",
            happy="hopping 3 art pixels above the baseline, eyes closed in happy arcs, ears straight up.",
            sleep="curled up with ears folded over its face, eyes closed as flat lines, small pixel \"Z z\" "
                  "shapes above.",
            hot="ears glowing warm, a whirring motion line",
            throttle="frozen mid-hop, a small clicking spark",
        ),
        stages=[
            stage(name="Floppit", n=1, of=3,
                  concept="a baby bunny with 3.5-inch floppy-disk ears. Sweet and old-fashioned; it holds "
                          "exactly 1.44 MB of memories.",
                  body="a small round bunny, big head, short legs, a little puff tail.",
                  size=50,
                  features=["Its two ears are tall teal floppy disks with a silver sliding metal shutter "
                            "near the top.",
                            "A small white label-sticker shape on its back (no text).",
                            "A pink nose and cream-beige fur.",
                            "A tiny square write-protect notch on one ear.",
                            "Big round dark eyes, each with one white shine pixel in the upper-left."],
                  idle="sitting upright, ears tall, nose twitching.",
                  phys="a quick headbutt hop toward the viewer's left.",
                  special="shutters sliding open on its ears, firing small teal data squares toward the "
                          "viewer's left.",
                  back="back of the bunny with the label sticker and the back of its floppy ears.",
                  check="Floppy-disk ears with silver shutters, label sticker and pink nose wherever visible."),
            stage(name="Ziphare", n=2, of=3,
                  concept="the SAME bunny grown into a lean hare, fused with a zip disk. Proud and stubborn; "
                          "it insists the old format was better.",
                  body="a taller, leaner hare with long legs and big feet.",
                  size=65,
                  keep="the same eyes and shine, the same beige/teal/silver palette, disk ears with shutters, "
                       "the label sticker and the pink nose.",
                  features=["Its ears are taller, chunkier zip disks in zip blue with a silver shutter and a "
                            "rounded top.",
                            "Its belly is a disk-drive front: a dark horizontal slot and one small green "
                            "activity light.",
                            "A larger label sticker on its back.",
                            "Strong hind feet.",
                            "Big round dark eyes with a white shine pixel."],
                  idle="standing tall on long legs, ears up, alert.",
                  phys="a powerful double-foot kick toward the viewer's left.",
                  special="its belly slot ejecting a spinning zip disk toward the viewer's left.",
                  back="back of the hare with the label sticker and the zip-disk ears.",
                  check="Zip-disk ears with shutters, drive-slot belly and label sticker wherever visible."),
            stage(name="Discohare", n=3, of=3,
                  concept="the SAME hare as a stylish elder jackrabbit, fused with optical discs. Flashy and "
                          "dramatic; it skips mid-sentence if scratched.",
                  body="a tall, lanky jackrabbit with very long ears and a confident stance.",
                  size=80,
                  keep="the same eyes and shine, the same beige/teal/silver palette, the label sticker and the "
                       "pink nose; the ears are still storage media.",
                  features=["Its very long ears end in round shiny silver discs with pink and cyan rainbow "
                            "sheen bands and a center hole.",
                            "A 90s teal-and-pink zigzag pattern on its chest fur.",
                            "A small disc-tray shape on its belly.",
                            "Long elegant hind legs.",
                            "Big round dark eyes with a white shine pixel and a confident look."],
                  idle="posing on one leg, one ear tilted, disc ears catching the light.",
                  phys="a spinning roundhouse kick toward the viewer's left.",
                  special="its disc ears spinning and flashing a rainbow beam (pink and cyan bands) toward "
                          "the viewer's left.",
                  back="its back with the label sticker and the disc ears from behind.",
                  frame13="Signature pose (final form): disco pose, one arm up, disc ears flashing, small "
                          "sparkles around it.",
                  check="Rainbow disc ears, teal-pink zigzag chest, disc tray and label sticker wherever "
                        "visible."),
        ],
    ),
    dict(
        file="08-singles", title="Single-stage Daemons", type=None, ground=None, palette=None, frames=None,
        stages=[
            stage(name="Dustbunny", n=1, of=1, type="Peripheral", ground="feet",
                  palette="#2A2A30 outline | #9A9AA6 dust grey | #6A6A78 dust shadow | #C8C8D2 dust highlight |\n"
                          "#E8E8EE fluff white | #3A3A44 cable black | #B8BEC8 USB metal | #3C8EE0 USB blue |\n"
                          "#E88A9A nose pink | #D8A8B8 inner ear | #141418 eyes | #FFFFFF eye shine |\n"
                          "#F4F4F8 sneeze puff | #A8916A crumb tan | #7A808C metal shadow",
                  concept="a scrappy rabbit made of lint and dust that lives behind desktop towers. Sneezy, "
                          "scrappy and impossible to get rid of.",
                  body="a small fluffy round rabbit with messy edges and floppy ears.",
                  size=45,
                  features=["Fluffy dust-ball body with jagged, messy outline tufts.",
                            "A stray USB cable tangled around it, with the plug end like a tail.",
                            "A few crumbs and tiny bits stuck in its fur.",
                            "A pink twitchy nose.",
                            "Big round dark eyes, each with one white shine pixel."],
                  idle="sitting, fluff bristling, nose twitching.",
                  phys="a tumbling roll toward the viewer's left, dust trailing.",
                  special="a huge sneeze blasting a cloud of grey dust toward the viewer's left.",
                  back="its fluffy back with the USB-plug tail.",
                  hurt="dust puffing off", faint="flattened into a dust pile, eyes as X shapes.",
                  happy="bouncing up, eyes closed in happy arcs, fluff puffed.",
                  sleep="flattened into a fluffy loaf, eyes closed as flat lines, small pixel \"Z z\".",
                  hot="fluff singed at the tips", throttle="tangled in its own cable",
                  frame13="Signature pose: puffed up twice its size, fluff bristling, mid-sneeze.",
                  check="Messy dust fluff, USB-cable tail and pink nose wherever visible."),
            stage(name="Fanbat", n=1, of=1, type="Hardware / Power", ground="hover",
                  palette="#1E1A1A outline | #3A3A44 body | #24242C body shadow | #6A6E78 body highlight |\n"
                          "#18181C fan frame | #9EA4B0 fan blade | #D8DCE4 blade highlight | #E0703C fan hub |\n"
                          "#F2C63A power yellow | #D84848 cable red | #B04E28 inner ear | #FFFFFF fangs/shine |\n"
                          "#141418 pupil | #5CE07A LED green | #F4A070 hub highlight",
                  concept="a bat whose wings are 120 mm computer case fans. Swarms hang from server-room "
                          "ceilings, humming at night.",
                  body="a small dark bat body with big ears, hanging or hovering between two large round "
                       "fan wings.",
                  size=65,
                  features=["Each wing is a square case-fan frame with round blades and an orange hub.",
                            "A red-and-black power cable tail ending in a small plug.",
                            "Big pointed ears with orange insides.",
                            "Two small white fangs.",
                            "Big yellow eyes with dark pupils and a white shine pixel."],
                  idle="hovering, fan blades spinning (curved motion lines).",
                  phys="a diving bite toward the viewer's left.",
                  special="fans at full speed, blasting a gust of air lines toward the viewer's left.",
                  back="its back between the fan wings, the cable tail hanging down.",
                  hurt="fans wobbling", faint="lying on the bottom of the cell, fans stopped, eyes as X shapes.",
                  happy="spinning in a loop, eyes closed in happy arcs.",
                  sleep="hanging upside down, wings folded, eyes closed, small pixel \"Z z\".",
                  hot="fan hubs glowing orange", throttle="fans stuck, sparks at the hubs",
                  frame13="Signature pose: wings fully spread, fans glowing, power cable crackling yellow.",
                  check="Case-fan wings, cable tail, orange ears and yellow eyes wherever visible."),
            stage(name="Ramster", n=1, of=1, type="Hardware", ground="feet",
                  palette="#2A1E1A outline | #E8B878 fur | #B8844A fur shadow | #F8E0B8 fur highlight |\n"
                          "#F8F0E0 belly cream | #2E7A4A PCB green | #1E5232 PCB shadow | #D8A830 gold pins |\n"
                          "#24242C chip black | #9EA4B0 wheel grey | #6A6E78 wheel shadow | #E88A9A nose pink |\n"
                          "#141010 eyes | #FFFFFF eye shine | #E0703C LED orange",
                  concept="a hamster fused with a RAM stick. Hyper and tireless; it runs on its wheel to keep "
                          "its memory refreshed.",
                  body="a round, chubby hamster with tiny paws and a stub tail.",
                  size=55,
                  features=["A RAM-module stripe along its back: green board with 4 black chips and a row of "
                            "gold pins along the bottom edge.",
                            "A tiny grey exercise wheel it carries or runs in.",
                            "Chubby cream cheeks.",
                            "A small orange activity LED on its forehead.",
                            "Big round dark eyes with a white shine pixel."],
                  idle="sitting up, paws together, cheeks puffed.",
                  phys="rolling inside its wheel toward the viewer's left.",
                  special="chips on its back lighting up, firing a stream of small data squares toward the "
                          "viewer's left.",
                  back="its back showing the full RAM-module stripe.",
                  hurt="LED flickering", faint="flopped on its side, eyes as X shapes, wheel tipped over.",
                  happy="running in its wheel with motion lines, eyes closed in happy arcs.",
                  sleep="curled in its wheel, eyes closed, small pixel \"Z z\".",
                  hot="RAM chips glowing", throttle="frozen mid-run in its wheel",
                  frame13="Signature pose: standing tall, paws raised, all chips lit, wheel spinning behind.",
                  check="RAM-module back stripe, wheel, forehead LED and cheeks wherever visible."),
            stage(name="Servurtle", n=1, of=1, type="Hardware", ground="feet",
                  palette="#1E2418 outline | #7A9A6A skin | #4E6A42 skin shadow | #A8C898 skin highlight |\n"
                          "#2A2A30 chassis black | #6A6E78 chassis grey | #9EA4B0 chassis highlight |\n"
                          "#D8DCE4 drive bay silver | #5CE07A LED green | #F2C63A LED amber | #E0703C accent orange |\n"
                          "#C8B078 beak | #141410 eyes | #FFFFFF eye shine | #3C8EE0 cable blue",
                  concept="a sturdy turtle carrying a 2U rack server as its shell. Slow, reliable and stubborn; "
                          "it has not been rebooted in years.",
                  body="a wide, low turtle with thick legs and a big flat server shell.",
                  size=75,
                  features=["Its shell is a 2U rack server: black chassis, a row of silver drive bays on the "
                            "front edge with green/amber LEDs.",
                            "Small rack ears (mounting tabs) sticking out of the shell's front corners.",
                            "A blue network cable trailing from the back like a tail.",
                            "A beak-like mouth and a calm expression.",
                            "Small round dark eyes with a white shine pixel."],
                  idle="standing firm, head out, LEDs blinking.",
                  phys="a heavy shell-first charge toward the viewer's left.",
                  special="pulling into its shell while the drive-bay LEDs fire a beam of orange light toward "
                          "the viewer's left.",
                  back="the top and back of the server shell with vents and the cable tail.",
                  hurt="LEDs flashing red-orange", faint="flipped on its back, legs up, eyes as X shapes.",
                  happy="head raised, eyes closed in happy arcs, all LEDs green.",
                  sleep="head and legs pulled into the shell, LEDs dim, small pixel \"Z z\".",
                  hot="vents puffing steam, LEDs amber", throttle="half-retracted into its shell",
                  frame13="Signature pose: standing tall on its hind legs, all drive LEDs lit.",
                  check="Server shell with drive bays and LEDs, rack ears and cable tail wherever visible."),
        ],
    ),
]


def build_prompt(line, st, prev_names):
    ground = st.get("ground") or line["ground"]
    palette = st.get("palette") or line["palette"]
    ctype = st.get("type") or line["type"]
    frames = dict(line.get("frames") or {})
    for k in ("hurt", "faint", "happy", "sleep", "hot", "throttle"):
        if k in st:
            frames[k] = st[k]
    attach = ""
    if prev_names:
        attach = ("\nATTACHED: the approved sprite sheet(s) for " + " and ".join(prev_names) +
                  " (the earlier stage(s) of this SAME creature). Match their face, eyes, palette and pixel "
                  "style exactly; only grow and upgrade it as described.\n")
    stage_word = {1: "basic", 2: "middle", 3: "final"}[st["n"]] if st["of"] > 1 else "single-stage"
    if st["of"] > 1 and st["n"] == st["of"]:
        stage_word = "final"
    px = SIZE_PX[st["size"]]
    bible = [
        "== CREATURE BIBLE ==",
        f"Name: {st['name']}. " + (f"Stage {st['n']} of {st['of']} ({stage_word} form). " if st["of"] > 1
                                   else "Single stage (does not evolve). ") + f"Type: {ctype}.",
        f"Concept: {st['concept']}",
        f"Body: {st['body']}",
        f"Size: body height about {st['size']}% of the cell (about {px} of the 64 art pixels), same size in "
        "every frame.",
    ]
    if st.get("keep"):
        bible.append(f"KEEP FROM PREVIOUS STAGE: {st['keep']}")
    bible.append("Signature features (show in every frame where they would be visible):")
    bible += [f"{i}. {f}" for i, f in enumerate(st["features"], 1)]
    bible.append("Palette (exact hex):")
    bible.append(palette)
    frame13 = st.get("frame13") or UPGRADING
    text = HEADER.format(attach=attach, ground_rule=GROUND[ground][0]) + "\n" + "\n".join(bible) + "\n\n" + \
        FRAMES.format(idle=st["idle"], phys=st["phys"], special=st["special"], back=st["back"],
                      frame13=frame13, check=st["check"], ground_check=GROUND[ground][1], **frames)
    return text


FIXES = """## If something goes wrong (send as a follow-up)
- **The creature changes between frames:** "Keep the creature exactly as in cell 1 in every cell; only the pose changes. Redraw cells 6 and 11 to match." (name the cells that drifted)
- **It looks blurry or painted:** "Redo as hard-edged pixel art: every art pixel is a crisp 4x4 square, no anti-aliasing, palette colors only."
- **Words or grid lines appear:** "Remove every word, number, line and box. Flat #FF00FF background only."
- **Doesn't match the earlier stage:** "Use the attached earlier stage as the reference: same eyes, face shape and colors. Only make it bigger and add the upgrades."
- **16 frames is too many to keep consistent:** "Only draw rows 1 and 2; leave rows 3 and 4 as plain magenta." Then attach that result and ask for rows 3 and 4 the same way.
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    index = ["# Sprite prompts for ChatGPT", "",
             "Generated by `tools/art_prompts/build_prompts.py` (edit the creature data there and rerun).",
             "", "## How to use", "",
             "1. One image = ONE stage. Paste that stage's whole prompt into ChatGPT (image generation).",
             "2. Fix it with the follow-up lines at the bottom of each file until you approve it.",
             "3. Next stage: in the same chat, or a new chat with the approved sheet(s) attached, paste the "
             "next stage's whole prompt. Always paste the whole prompt; ChatGPT forgets earlier rules.",
             "4. Save each approved sheet, shrink it in Aseprite (Sprite Size 25%, Nearest Neighbor → 64x64 "
             "frames), and log it in the vault's Daemon-Log.",
             "", "Sheet layout: 1024x1024, invisible 4x4 grid of 256x256 cells, each sprite 64x64 art pixels "
             "at 4x. Rows: front poses · front reactions · back view · specials (evolution glow or final-form "
             "pose, overheated, throttled, menu icon).", "", "## Files", ""]
    for line in LINES:
        lines = [f"# {line['title']}", "", "Paste one stage per image. Generate and approve each stage before "
                 "the next.", ""]
        prev = []
        for st in line["stages"]:
            lines.append(f"## {st['name']}" + (f" (Stage {st['n']} of {st['of']})" if st["of"] > 1 else ""))
            lines.append("")
            if prev and line["file"] != "08-singles":
                lines.append(f"Attach the approved {' and '.join(prev)} sheet(s) first.")
                lines.append("")
            lines += ["````", build_prompt(line, st, prev if line["file"] != "08-singles" else []).rstrip(),
                      "````", ""]
            if line["file"] != "08-singles":
                prev.append(st["name"])
        lines.append(FIXES)
        (OUT / f"{line['file']}.md").write_text("\n".join(lines))
        index.append(f"- [{line['title']}]({line['file']}.md)")
    (OUT / "README.md").write_text("\n".join(index) + "\n")
    print("wrote", len(LINES), "files to", OUT)


if __name__ == "__main__":
    main()
