# FETCH

**Throw. Dodge. Catch.** A top-down local-multiplayer party game where 2–4 dogs throw toys
at each other in small, chaotic arenas. Inspired by *Boomerang Fu*.

Built with **Godot 4.7.2 (GDScript)** in **3D** with a shared, dynamically framed orthographic camera. Play solo against
three CPU dogs, or join with any mix of gamepads and two keyboard layouts. Pick a dog, arena, and toy,
then play *Last Dog Standing*. Startup and menus use the supplied Fetch cover; selection portraits use
the reference artwork. Gameplay dogs remain temporary procedural placeholders. The fully 3D import pipeline, animated mouth sockets,
asset validator, and reference studio are ready; matching authored meshes and textures are still needed.

- Current art direction and remaining production work: [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md)
- Original engine decisions and roadmap: [`docs/GAMEPLAN.md`](docs/GAMEPLAN.md)
- How the code is organised and how to add dogs / toys / arenas / modes: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Run it

1. Download **Godot 4.7.2** (standard build, not .NET) from https://godotengine.org/download or
   https://github.com/godotengine/godot/releases/tag/4.7.2-stable
2. Open Godot → **Import** → pick `project.godot` in this folder.
3. Press **F5** (Run Project).

You can also run a scene directly with **F6** while it's open (e.g. `scenes/match/match.tscn` auto-fills two keyboard players).

Godot **4.7.2** specifically — the project declares the `4.7` feature and will not open on 4.6 or
earlier. Nothing else is needed: no export templates, no Git LFS, no asset downloads. Everything
the game uses (dog models, textures, fonts, arena thumbnails) is in the repo.

On a **fresh clone the first import reports a handful of font/theme errors**. They are an ordering
artefact — the theme loads before the font has been imported — and a second pass clears them. The
editor does this for you; from the command line, run `--import` twice:

```bash
godot --headless --path . --import   # first pass: expect font/theme errors
godot --headless --path . --import   # second pass: clean
```

## Controls

| Action | Gamepad | Keyboard 1 | Keyboard 2 |
|---|---|---|---|
| Join (dog select) | A / Start | Space | Enter |
| Move | Left stick / D-pad | WASD | Arrow keys |
| Throw / Catch / Pick up | X (or Y, RT) · LT also catches | Space | Enter |
| Wind up a harder throw | Hold the throw button | Hold Space | Hold Enter |
| Dash (invincible) | A or RB | Left Shift or E | Right Ctrl, `/` or Numpad 0 |
| Pause / resume | Start | Esc | Esc |
| Confirm (menus) | A / X | Space | Enter |
| Back / leave | B / Back | Esc | Backspace |

Every dog starts empty-handed. Six toys are laid out symmetrically around the middle of the arena,
never within reach of a starting dog, and redrawn every round so nobody learns the spots — the opening
move is a decision, not a free pickup. Walk over a toy on the ground to pick it up. Press throw with no toy in hand to **catch**: a toy that
reaches you within the next fraction of a second (per dog: `catch_window`) is caught instead of hitting you.
Mash it and you'll be locked out for a moment, so time it. A tap is a soft lob that runs out of steam after a few metres. **Hold** the throw
button and the shot winds up: a gauge fills around your paws and at full charge the toy leaves three times
as fast, crossing the arena and ricocheting off the walls. It costs you — you walk at little more than half speed while you wind up, and
every rival can see the meter — so a charged throw is a bet, not a free upgrade. Throws are one-way: once a
toy leaves your mouth it belongs to whoever picks it up next.

Toys are solid to each other. Shoot one into a toy lying on the ground and you shove it; hit it hard enough
and it takes off as a live throw of its own, still counted as yours. A ball into a pile is a real play.

Not every prop is a wall. In Agility Park the tunnel is a route — run in one end and out the other, and the
fabric turns see-through while anyone is inside it — and the A-frame is a deck you run up and over, with the
toys riding the same slope. Both are still solid from the side, so taking the obstacle is a choice.

A brand new session opens on a practice round in a bare training yard — no props, nothing to learn but the
buttons — and the arena you picked arrives with round one. Rounds time out after 45 seconds as no-score draws. The lobby also supports clicking to join, change dogs, ready up, and add CPU players.

Mixed dog toys is the default; the setup screen also allows a single toy. Tennis balls bounce,
frisbees fly fast and flat without bouncing around, heavy bones pierce dogs but stop at walls, and
super balls retain more bounce. Every toy in the box bonks: a clean hit from any of them puts a dog
out, so what you are holding never changes whether a throw counts. Only dangerous outbound throws can eliminate; walking into props is harmless.
Mystery treats arrive in sealed tins and reveal one of eight powers when collected, with a reward
badge above the dog and a short explanation beside its HUD belt. Up to three powers carry between
rounds; Shield absorbs one hit, and a full belt swaps its oldest power for a new one. Treat timing
adapts as the match progresses, and treats can be disabled in setup.

## 3D dog assets

Open **Meet the Pack → 3D Dog Studio** to compare each dog with its original full turnaround sheet.
The studio reports missing assets, shows directional/arena views, and previews animation and toy grips.
See [the asset contract](assets/models/dogs/README.md) for GLB delivery, rig/socket naming, authoring
setup, and validation. Technical validation does not establish visual likeness.

## Test it

```bash
godot --headless --path . --import                      # surfaces script errors
godot --headless --path . res://tests/smoke_test.tscn    # scripted 3-player match, exits 0 on pass
godot --headless --path . res://tests/gameplay_test.tscn # pause, one-way throws, bots, round timeout
godot --headless --path . res://tests/ui_flow_test.tscn  # loading, menu, solo setup, lobby
godot --headless --path . res://tests/weapon_test.tscn   # projectile collision, specials, buffs
godot --headless --path . res://tests/match_rules_test.tscn # placement and treat lifecycle
godot --headless --path . res://tests/camera_test.tscn   # framing and KO timing
godot --headless --path . res://tests/mixed_match_test.tscn # mixed-toy CPU rounds
godot --headless --path . res://tests/asset_pipeline_test.tscn # imported rig contract
```

CI imports the project and runs the regression suites on every push (`.github/workflows/ci.yml`).

## Status

- ✅ 1 human + CPU practice, or 2–4 local players using pads + keyboards
- ✅ Movement, dash with i-frames, throw, bounce, catch, one-hit elimination
- ✅ Main menu → dog select → match setup → match → results
- ✅ 5 dogs, 4 playable toy behaviors, 8 arenas (shuffled every round by default), Last Dog Standing to N points
- ✅ MindGoblin studio bumper on boot, then one home screen built on the supplied home-screen art
- ✅ Reference-art dog portraits; wooden-plank menu buttons; matching wood/cream/forest UI
- ✅ 3D: shared camera with smooth pan/zoom and KO emphasis, placeholder dogs/props, real-time shadows, garden scenery
- ✅ Pause/resume, round timer, CPU opponents, action status in HUD
- ✅ Practice round on a new session (walled pens, ready pads, nothing scored), arcade-cabinet control wording, map previews and a power-up guide
- ✅ Ten Boomerang Fu-style mystery power-ups (Telepawthy, Ghost Pup, Dig!, Squeaky Kaboom, Triple Fetch and more) with persistent belts and animated reveals, animated mouth grips, safe wall ricochets and swept projectile hits
- ✅ Refined toy models and themed arena props, plus Sunflower Courtyard and Moonlit Rooftop
- ✅ Hit-stop followed by KO slow motion, particles, floating text
- ✅ Procedural soundtrack (menu / match / victory) and a synthesised effects kit, on separate mixable buses
- ✅ Fully 3D asset import/animation contract, validator and reference comparison studio
- ⏳ Authored furred dog meshes/rigs, real audio, advanced power-ups, other modes, online play: see `docs/ART_DIRECTION.md`
