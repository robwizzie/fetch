# Architecture

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
  actors/dog.gd              CharacterBody2D: move, dash, throw, catch, hit_by(), eliminate()
  actors/dog_visual.gd       Placeholder _draw() art; replace with AnimatedSprite2D later
  actors/toy.gd              CharacterBody2D: IDLE / HELD / FLYING, bounce, hit detection, pickup
  actors/toy_visual.gd       Placeholder toy art
  arena/arena.gd             Base arena: draws ground, builds outer walls, spawn points
  arena/obstacle.gd          Solid prop (@tool, resizable in editor)
  arena/slow_zone.gd         Area that slows dogs (pool, rug)
  modes/game_mode.gd         Base rules class; last_dog_standing.gd implements the MVP mode
  match/match.gd             Round loop: spawn, countdown, detect round end, score, results
  ui/*.gd                    Screens (code-built with UiKit helpers), HUD, CarouselRow
scenes/
  actors/dog.tscn, toy.tscn  Collision shapes + child nodes; scripts above
  arenas/backyard.tscn, living_room.tscn
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

**Physics layers.** 1 walls · 2 dogs · 3 toys · 4 zones. Dogs collide with walls and dogs. Toys collide with
walls only and detect dogs through their `HitArea`. Dogs detect catchable toys through `CatchArea`.

**Toy lifecycle.** `pick_up(dog)` → HELD (follows `dog.get_hold_position()`), `throw(dog, dir, power)` →
FLYING, speed decays by `friction`; below `danger_speed` it's IDLE and harmless; walking over it picks it up.
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
- **Arena:** duplicate `scenes/arenas/backyard.tscn`, move props (Obstacle/SlowZone nodes, spawn markers), then
  add `data/arenas/03_name.tres` pointing at it.
- **Mode:** subclass `GameMode` in `scripts/modes/`, override `is_round_over` / `round_winner` (and
  `on_round_start` for setup like spawning a golden ball), then set `mode_script` and `fully_implemented = true`
  in its `data/modes/*.tres`.
- **Real art:** replace `DogVisual`/`ToyVisual` nodes with sprites that expose the same four methods, or
  keep the scripts and draw sprites inside `_draw()` — the gameplay code doesn't care.
