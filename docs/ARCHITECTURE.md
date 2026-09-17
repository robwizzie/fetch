# Architecture

The current presentation and gameplay pass is described in [`ART_DIRECTION.md`](ART_DIRECTION.md).
Startup now begins with `scenes/ui/loading.tscn`. `Game.goto()` routes scene changes through this
cover screen and uses `ResourceLoader` threaded loading with actual progress. After the initial
ready prompt, subsequent transitions proceed automatically. The main menu uses `CoverStage` to
preserve the original cover image's aspect ratio beside the controls.

`Game.start_practice(device)` creates one human and three CPU slots. `PlayerSlot.is_bot` explicitly
opts a dog into `BotBrain`, which drives `DeviceInput.VIRTUAL`; scripted-test virtual devices are
left alone. The lobby can add/remove CPUs, change their dogs, and retains their ready state.
Match setup offers only fully implemented modes/toys; galleries can still show prototypes.

The match has a 45-second round clock, no-score timeout draws, and real tree pause on Esc/Start.
A brand new session opens on a **practice round** (`Phase.TUTORIAL`), not a scored one. Each
player gets a walled `ReadyPen` with a toy to try and a pad to stand on; the walls are taller
than a toy flies, so nobody can be knocked out while they are still finding the buttons. The
real first round only begins once every pen has been stepped on — bots check themselves in after
a few seconds. Nothing is scored and `round_number` stays at 0, so the first scored round is
still round 1. `TutorialCoach` rides on top showing the controls, ticking each step off as
someone performs it, with a timeout on every step so a table that already knows the game is
never held up. Button names come from `DeviceInput.button_label()`, which
words them for an arcade cabinet when one is detected (`DeviceInput.is_arcade()` reads the pad's
reported name; Settings can force it either way).

Arena thumbnails in `images/arenas/` are rendered by `tools/build_arena_thumbnails.gd` and shown
on the setup screen and in the gallery. Re-run it after changing an arena's layout.

Audio is synthesised, not loaded: `Sfx` builds its one-shots at startup and `Music` sequences
three looping tracks on a worker thread, mixed on separate `SFX` and `Music` buses. Screens ask
for a track by name and repeating the current one is a no-op, so the front end keeps one piece
playing across scene changes. A knockout ducks the music briefly.

A throw is one-way: once released, a toy belongs to whoever picks it up next. Opening toy placement is
mirror-symmetric about both arena axes and kept clear of every spawn, so each dog has the same run to the
nearest toy, and it is redrawn each round. With `Game.random_arena_each_round` (the setup screen's default)
the match swaps the whole arena between rounds. The HUD shows score, toy/dash status, round time, input hints, and pause controls.
The arena camera is orthographic and adjusts framing to keep the full arena visible.

Dog selection uses front-view crops from `images/models`; rotating 3D portraits and matches use
the procedural `DogModel`. Barkley retains the old `hattie` data ID for compatibility and uses the
new spaniel body plan. The section below describes the underlying structure inherited from the prototype.

```
project.godot                 Godot project (autoloads, 1920x1080 canvas, physics layers, theme)
autoload/
  events.gd   Events         Signal bus (player_joined, round_over, dog_eliminated, toy_caught, ...)
  game.gd     Game           Session state: joined PlayerSlots, selected arena/toy/mode, content registry, goto()
  juice.gd    Juice          shake(), hitstop(), pop(), squash(), float_text(), burst()
  sfx.gd      Sfx            play("bonk") — synthesised placeholder sounds; swap streams for real files
scripts/
  player_slot.gd             One joined player: index, device, dog, score, ready, colour
  input/device_input.gd      Per-device polling: gamepad N, keyboard WASD, keyboard arrows, VIRTUAL (bots/tests)
  data/*.gd                  Resource classes: DogData, ToyData, ArenaData, GameModeData
  actors/dog.gd              CharacterBody3D on the XZ plane: move, dash, throw, catch, hit_by(), eliminate()
  actors/toy.gd              CharacterBody3D: IDLE / HELD / FLYING at fixed height, bounce, hit detection, pickup
  visuals/mats.gd            Toon StandardMaterial3D + primitive-mesh helpers (one place to restyle everything)
  visuals/dog_model.gd       Placeholder low-poly dog built from primitives; replace with a rigged model later
  visuals/toy_model.gd       Placeholder toy meshes by id
  arena/arena.gd             Base arena: ground, outer walls (fence/baseboard visuals), spawn points
  arena/arena_camera.gd      Fixed tilted perspective camera (pitch/height/fov per arena)
  arena/obstacle.gd          Solid prop by kind (crate, doghouse, table, couch, TV, ...) (@tool)
  arena/slow_zone.gd         Round area that slows dogs (pool, rug, mud)
  ui/dog_portrait.gd         SubViewport turntable showing a 3D dog inside 2D menus
  modes/game_mode.gd         Base rules class; last_dog_standing.gd implements the MVP mode
  match/match.gd             Round loop: spawn, countdown, detect round end, score, results
  ui/*.gd                    Screens (code-built with UiKit helpers), HUD, CarouselRow
scenes/
  actors/dog.tscn, toy.tscn  Collision shapes + child nodes; scripts above
  arenas/backyard.tscn, living_room.tscn   Each has its own Camera, DirectionalLight and WorldEnvironment
  match/match.tscn           ArenaHolder + Actors + HUD
  ui/*.tscn                  One Control root per screen
data/
  dogs/ toys/ arenas/ modes/ .tres content files (loaded in filename order)
tests/
  smoke_test.tscn            Headless full-match test with scripted players
  screenshots.tscn           Renders every screen to PNG (needs a display/Xvfb)
```

## Flow

`main_menu` → `dog_select` (press-to-join, pick dog, ready) → `match_setup` (mode/arena/toy/points) →
`match` (rounds until someone reaches `Game.points_to_win`) → `results` (play again / change / menu).

Scene changes go through `Game.goto(path)`. Scenes never reference each other directly.

## Key systems

**Input.** `DeviceInput` wraps one device. Gameplay asks it for `move_vector()`, `just_pressed(&"throw")`,
`just_pressed(&"dash")`. Menus poll the same object for `left/right/throw/back`. Joining is event-based
(`DeviceInput.join_device_from_event`). `VIRTUAL` devices are driven by code: bots and the smoke test set
`virtual_move` and `virtual_buttons`.

**World.** 3D, metres. The arena is centred on the origin on the XZ plane; +X is screen-right, +Z is toward
the camera (screen-down). Input `Vector2(x, y)` maps to `Vector3(x, 0, y)`. Dogs and toys use
`CharacterBody3D` in floating mode with `y` pinned, so the game plays like a 2D game with 3D visuals.

**Physics layers.** 1 walls · 2 dogs · 3 toys · 4 zones. Dogs collide with walls and dogs. Toys collide with
walls only and detect dogs through their `HitArea`. Dogs detect catchable toys through `CatchArea`.
Toy releases are ray-checked so a dog pressed against a wall can't push the toy through it.

**Toy lifecycle.** `pick_up(dog)` → HELD (follows `dog.get_hold_position()`), `throw(dog, dir, power)` →
FLYING at `FLY_HEIGHT`, speed decays by `friction`; below `danger_speed` it's IDLE, settles to the ground and
is harmless; walking over it picks it up.
The thrower is immune until the first bounce (`_owner_immune`), so you can't hit yourself at point-blank but
ricochets can come back at you.

**Catch.** Pressing throw with empty paws either catches a dangerous toy already inside `catch_radius`, or
arms a `catch_window` timer; a toy that would hit the dog while armed is caught instead (`Dog.hit_by`).
A miss triggers `catch_cooldown`. These three numbers per `DogData` define each dog's defensive feel.

**Rounds.** `match.gd` spawns a `Dog` per `PlayerSlot` (each starts holding a toy) plus extra ground toys,
freezes actors during the HUD countdown, then listens to `Events.dog_eliminated` and asks the `GameMode`
`is_round_over()` / `round_winner()`. Points live on the `PlayerSlot`, so they survive scene changes.

**Juice.** All feedback goes through `Juice` and `Sfx` so gameplay scripts stay readable and feedback can be
tuned or replaced centrally.

## Adding content

- **Dog:** copy `data/dogs/05_posey.tres`, change values. It appears in dog select, gallery and the title parade.
- **Toy:** copy a `data/toys/*.tres`. New special behaviour: add an enum value in `ToyData.Special` and a
  `match` branch in `Toy._try_hit` (or a new method) — keep it in `toy.gd`.
- **Arena:** duplicate `scenes/arenas/backyard.tscn`, move props (Obstacle/SlowZone nodes, Marker3D spawns),
  tweak the camera/light/environment nodes, then add `data/arenas/03_name.tres` pointing at it.
- **Prop:** pick an `Obstacle.Kind` and a footprint; or set kind = CUSTOM and add your own mesh as a child.
- **Mode:** subclass `GameMode` in `scripts/modes/`, override `is_round_over` / `round_winner` (and
  `on_round_start` for setup like spawning a golden ball), then set `mode_script` and `fully_implemented = true`
  in its `data/modes/*.tres`.
- **Real art:** replace the `Model` child of `dog.tscn`/`toy.tscn` with a glTF scene whose script exposes the
  same methods (`setup`, `update_motion`, `set_dashing`, `set_catching`, `squash`, `play_knocked_out`);
  the gameplay code doesn't care what it looks like. Restyle all materials in `Mats`.
