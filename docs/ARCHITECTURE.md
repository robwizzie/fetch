# Architecture

The current presentation and gameplay pass is described in [`ART_DIRECTION.md`](ART_DIRECTION.md).
Startup now begins with `scenes/ui/loading.tscn`. `Game.goto()` routes scene changes through this
cover screen and uses `ResourceLoader` threaded loading with actual progress. After the initial
ready prompt, subsequent transitions proceed automatically. The main menu uses `CoverStage` to
preserve the original cover image's aspect ratio beside the controls.

`Game.start_practice(device)` creates one human and three CPU slots and then goes to the dog
select, the same as party play: every route into a match passes through choosing a dog, and none
of them hides that choice behind a button of its own. `PlayerSlot.is_bot` explicitly
opts a dog into `BotBrain`, which drives `DeviceInput.VIRTUAL`; scripted-test virtual devices are
left alone. The lobby can add/remove CPUs, change their dogs, and retains their ready state.
Match setup offers only fully implemented modes/toys; galleries can still show prototypes.

The match has a 45-second round clock, no-score timeout draws, and real tree pause on Esc/Start.
Menus run on Godot's built-in focus navigation. Godot ships `ui_accept` and `ui_cancel` with
keyboard events only, so `Game._bind_menu_gamepad()` adds the pad buttons at runtime (A/X/Start
to confirm, B/Back to cancel, on device -1 so every connected pad works). They are added rather
than redefined in `project.godot` so the keyboard defaults stay exactly as Godot shipped them.
Without this the menus look frozen on a controller: the highlight moves and nothing else does.

A brand new session opens on a **practice round** (`Phase.TUTORIAL`), not a scored one. Each
player gets a walled `ReadyPen` with a toy to try and a pad to stand on; the walls are taller
than a toy flies, so nobody can be knocked out while they are still finding the buttons. The
real first round only begins once every pen has been stepped on — bots check themselves in after
a few seconds. Nothing is scored and `round_number` stays at 0, so the first scored round is
still round 1. Each human gets a `PracticeCard` beside their own pen: their own keys drawn as
keycaps (`UiKit.keycaps()`), ticking off as *that* player moves, picks up, throws, catches and
dashes. Nothing is compulsory, so a table that already knows the game just walks to the pads. In
the match, each human's HUD card shows the key for what they can do right now (catch or throw,
and dash), and the pause menu lists everyone's controls. Button names come from `DeviceInput`, which
words them for an arcade cabinet when one is detected (`DeviceInput.is_arcade()` reads the pad's
reported name; Settings can force it either way).

Arena thumbnails in `images/arenas/` are rendered by `tools/build_arena_thumbnails.gd` and shown
on the setup screen and in the gallery. Re-run it after changing an arena's layout.

Audio prefers recordings and falls back to synthesis: `Sfx` plays recorded takes where a folder
exists and builds the rest at startup, and `Music` loops `assets/audio/music/<track>.ogg` (menu,
match, victory), sequencing any missing track on a worker thread. Both mix on separate `SFX` and
`Music` buses. Screens ask
for a track by name and repeating the current one is a no-op, so the front end keeps one piece
playing across scene changes. A knockout ducks the music briefly.

A throw is one-way: once released, a toy belongs to whoever picks it up next. Holding the throw button
winds a shot up instead of firing it. A tap is a soft close-quarters lob (`Dog.TAP_POWER`) that drops under
`danger_speed` within a few metres; a full wind-up reaches `Dog.FULL_POWER`, and a gauge around the dog's
paws lets every rival see it coming. Opening toy placement is
mirror-symmetric about both arena axes and kept clear of every spawn, so each dog has the same run to the
nearest toy, and it is redrawn each round. With `Game.random_arena_each_round` (the setup screen's default)
the match swaps the whole arena between rounds. The HUD shows score, toy/dash status, round time, input hints, and pause controls.
The arena camera is a narrow (30°) perspective lens at a fixed 58° pitch, so the arena reads as a diorama. It keeps
the whole arena in frame, leans in only a little when the pack bunches up (`closest_share`), punches in on knockouts,
and keeps the top of the screen (`hud_top`) clear for the player cards. Match end is a 3D podium (`PodiumStage`) with
each dog's knockouts, catches and an award, counted on `PlayerSlot` during scored rounds.

Dog selection uses front-view crops from `images/models`; rotating 3D portraits and matches use
the procedural `DogModel`. Barkley retains the old `hattie` data ID for compatibility and uses the
new spaniel body plan. The section below describes the underlying structure inherited from the prototype.

```
project.godot                 Godot project (autoloads, 1920x1080 canvas, physics layers, theme)
autoload/
  events.gd   Events         Signal bus (player_joined, round_over, dog_eliminated, toy_caught, ...)
  game.gd     Game           Session state: joined PlayerSlots, selected arena/toy/mode, content registry, goto()
  juice.gd    Juice          shake(), hitstop(), pop(), squash(), float_text(), burst()
  sfx.gd      Sfx            play("bonk"), bark(breed) — recorded takes first, synthesised kit as fallback
  music.gd    Music          play("menu"), duck() — recorded loops first, sequenced render as fallback
scripts/
  player_slot.gd             One joined player: index, device, dog, score, ready, colour
  input/device_input.gd      Per-device polling: gamepad N, keyboard WASD, keyboard arrows, VIRTUAL (bots/tests)
  data/*.gd                  Resource classes: DogData, ToyData, ArenaData, GameModeData
  actors/dog.gd              CharacterBody3D on the XZ plane: move, dash, throw, catch, hit_by(), eliminate()
  actors/toy.gd              CharacterBody3D: IDLE / HELD / FLYING at fixed height, bounce, hit detection, pickup
  visuals/charge_meter.gd    The wind-up tell: a thin ground arc that sweeps round the dog's paws as it fills
  visuals/mats.gd            Toon StandardMaterial3D + primitive-mesh helpers (one place to restyle everything)
  visuals/dog_model.gd       Placeholder low-poly dog built from primitives; replace with a rigged model later
  visuals/toy_model.gd       Placeholder toy meshes by id
  arena/arena.gd             Base arena: ground, outer walls (fence/baseboard visuals), spawn points
  arena/arena_camera.gd      Fixed tilted perspective camera (pitch/height/fov per arena)
  arena/obstacle.gd          Solid prop by kind (crate, doghouse, table, couch, TV, ...) (@tool)
  arena/terrain.gd           Walkable elevation: props in the "ramps" group report the deck under a point
  arena/slow_zone.gd         Round area that slows dogs (pool, rug, mud)
  ui/dog_portrait.gd         SubViewport turntable showing a 3D dog inside 2D menus
  modes/game_mode.gd         Base rules class; last_dog_standing.gd implements the MVP mode
  match/match.gd             Round loop: spawn, countdown, detect round end, score, results
  ui/*.gd                    Screens (code-built with UiKit helpers), HUD, CarouselRow
scenes/
  actors/dog.tscn, toy.tscn  Collision shapes + child nodes; scripts above
  arenas/backyard.tscn, living_room.tscn   Each has its own Camera, DirectionalLight and WorldEnvironment
  arenas/training_yard.tscn  Bare ground for the practice round. Scene only, so it stays out of the arena picker
data/arenas/shelved/         Arenas kept in the repo but out of the picker: _load_dir lists files, not folders
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
`match` (rounds until someone reaches `Game.points_to_win`) → `results` (podium, play again / change / menu).

Scene changes go through `Game.goto(path)`. Scenes never reference each other directly.

## Key systems

**Input.** `DeviceInput` wraps one device. Gameplay asks it for `move_vector()`, `just_pressed(&"throw")`,
`just_pressed(&"dash")`. Menus poll the same object for `left/right/throw/back`. Joining is event-based
(`DeviceInput.join_device_from_event`). `VIRTUAL` devices are driven by code: bots and the smoke test set
`virtual_move` and `virtual_buttons`.

**World.** 3D, metres. The arena is centred on the origin on the XZ plane; +X is screen-right, +Z is toward
the camera (screen-down). Input `Vector2(x, y)` maps to `Vector3(x, 0, y)`. Dogs and toys use
`CharacterBody3D` in floating mode with `y` pinned, so the game plays like a 2D game with 3D visuals.

**Button prompts.** Never hard-code a button name. `DeviceInput.glyph(action, device)` returns what is
printed on that device (pads are mapped by position, so throw is X on Xbox, Square on PlayStation, Y on
Switch; `pad_family()` tells them apart by vendor id and name). `button_label(action, slots)` lists only
the joined humans' buttons, without repeats; `controls_line(device)` is the full one-line summary. Controls are shown in
How to Play, the practice pens (`PracticeCard`) and the pause menu - never on the play screen itself. Each
keyboard layout has exactly one dash key (Shift, either side / "/"). `tests/controls_test.tscn` covers it.

**Physics layers.** 1 walls · 2 dogs · 3 toys · 4 zones · 5 sight lines only. Dogs collide with walls and
dogs. Toys collide with walls and with each other, and detect dogs through their `HitArea`. Dogs detect
catchable toys through `CatchArea`. Toy releases are ray-checked so a dog pressed against a wall can't push
the toy through it. Layer 5 carries nothing but the occlusion bodies of props you can walk into, so the
sight-line test that fades a prop still works when its real collision is only two walls.

**Charged throws.** A press with something in the mouth starts a wind-up (`Dog._begin_charge`) and the
release throws it (`Dog._release_throw`); `DeviceInput.just_released` supplies the edge. The charge fills
over `CHARGE_TIME`, scales throw power from `TAP_POWER` to `FULL_POWER`, and slows the dog to
`CHARGE_MOVE_SCALE` at full, so range and punch are paid for in seconds spent planted. Being disarmed, going dizzy or going out all
cancel it. Bots wind up too, so the tell means the same thing whoever is holding the button.

**Crossable props.** `Obstacle` normally collides as one footprint box. `Kind.TUNNEL` keeps only its two
side walls, so the tube is a route end to end; `Kind.RAMP` keeps only its stepped side rails and joins the
`"ramps"` group, so `Terrain.ground_height()` reports a deck and dogs and toys ride over it. Play is still
strictly on the XZ plane — nothing jumps and nothing falls; the deck only moves `y`.

**Toy lifecycle.** `pick_up(dog)` → HELD (follows `dog.get_hold_position()`), `throw(dog, dir, power, charge)`
→ FLYING at `FLY_HEIGHT`, speed decays by `friction`; below `danger_speed` it's IDLE, settles to the ground
and is harmless; walking over it picks it up.
The thrower is immune until the first bounce (`_owner_immune`), so you can't hit yourself at point-blank but
ricochets can come back at you.

**Toy caroms.** Toys are solid to each other. A contact hands most of the incoming speed along the normal to
the toy that was struck (`_strike_toy` / `_receive_strike`); a loose toy shunted past its `danger_speed`
leaves as a live throw still credited to whoever started the chain, so a shot into a pile is a real play.
A graze keeps its line, a heavy toy ploughs on through, and a short contact lock keeps one contact from
resolving twice.

**Catch.** Pressing throw with empty paws either catches a dangerous toy already inside `catch_radius`, or
arms a `catch_window` timer; a toy that would hit the dog while armed is caught instead (`Dog.hit_by`).
A miss triggers `catch_cooldown`. These three numbers per `DogData` define each dog's defensive feel.

**Rounds.** `match.gd` spawns a `Dog` per `PlayerSlot` (each starts holding a toy) plus extra ground toys,
freezes actors during the HUD countdown, then listens to `Events.dog_eliminated` and asks the `GameMode`
`is_round_over()` / `round_winner()`. Points live on the `PlayerSlot`, so they survive scene changes.

**Combat rules.** `CombatRules` holds the rules every kind of hit shares: `clear_between()` for cover
(throws, swipes and blasts all use it) and `can_hurt()` for self/team fire. Hit tests use
`Dog.effective_radius()`. Slows are owned by
their source (`Dog.set_slow(source, factor)` / `clear_slow(source)`); the strongest active one wins, so
leaving one zone never cancels another. Ice works the same way through `Dog.set_traction` / `clear_traction`:
`traction` scales the dog's accel, brake and turn rates and how fast a push wears off, separately
from `speed_scale`, so ice and a slow zone stack.

**Power-ups.** Every kind changes how a dog plays (Boomerang Fu's rule), never just a stat. A belt holds
each kind once, capped at `PowerupKinds.MAX_SLOTS`. Every grant goes through `PlayerSlot.take_powerup()`,
which refuses duplicates; crates reroll to a kind the dog lacks, and `normalize_powerups()` repairs any belt on
spawn. A full belt replaces its longest-held kind *in place* (slot one first, then two, then three), so the
other sockets never shuffle. A round gets a fixed budget of crates (`match.treats_per_round()`: two, or three
with three or more dogs) however long it runs, and `_treat_position()` scores random open spots by distance
from every dog and every crate already dropped that round. Dog-side powers are read by
`Dog.apply_powerups()`: **Zoomies** (speed and dash recharge), **Ghost Pup** (the grass concealment, applied
everywhere, with paw prints on each step) and **Dig!** (a longer dash that goes underground, invincible for
its whole length, surfacing with a reveal). Behaviour powers live on the throw: `ToyPowerEffects` snapshots the belt at launch, so
a later swap never rewrites a toy in flight, and a pickup or catch resets it. **Squeaky Blast** arms a fuse on
the toy's first impact and stops it dead, then bursts in `BLAST_RADIUS`; cover blocks it, shields absorb it,
and grabbing the squeaking toy defuses it. **Mud Track** drops a `MudPatch` every `MUD_SPACING` metres of
flight; patches slow whoever stands in them, dry up after `LIFETIME` and are capped at `LIMIT`.
**Telepawthy** bends a flying toy toward the thrower's stick (`steer_toward`) at `STEER_RATE`, with a total
`STEER_BUDGET` short of a U-turn: it can curl round cover but can never come back to the thrower.

**Portals.** A `Portal` is a doggy door set into an arena wall: its origin sits on the wall's inner face
with local +Z pointing into the arena. A dog pushing into the doorway (`Dog.push_velocity`) or a thrown toy
that would bounce off that stretch of wall (`Portal.catch_toy`, called from `Toy._slide`) comes out of the
partner door. The exit is relative, so doors on opposite walls play like the yard wraps round. Bots follow
portal links in `BotNavigation` and walk straight into the door. Pairs share a colour; `monitoring` switches
a door off for the practice round.

**More power-ups.** Scatter Fetch fires two `Toy.ephemeral` side toys that vanish rather than become
pickups; every toy of one press shares `ToyPowerEffects.volley`, and `Dog` lets one volley land once.
Bank Shot speeds a throw up on its first wall bounce (`bank_bounce`); with Squeaky Blast the fuse arms on
the impact after the bank. Good Decoy leaves a `Decoy` on each dash that pops when a toy passes through it;
bots believe a given decoy `BotBrain.DECOY_BELIEF` of the time. A throw's trail takes the colours of the
powers it carries (`ToyPowerEffects.trail_colors`).

**Knockouts.** `DogModel._tumble` is one calm knockdown for every breed: a short hop back along the hit, a
tip onto the side with a slight twist (never a spin), one small bounce. A knocked-out dog is napping, not
gone: sleepy z's drift up in its colour (`_snooze`).

**Final-bonk replay.** `Replay` records the last 3 s of play: where every dog and toy was (toys by
instance id, with their whole transform, so a toy in a mouth stays in it), plus every call made on a
`DogModel` - throw, catch, dash, wind-up, bark, whack, hat, crown, knockdown - which the model announces on
its `acted` signal. Playback builds stand-ins, puts them in the state they were in when the replay starts,
and replays each call at its moment, at `Engine.time_scale = 0.4` so their animation slows too.
Everything else under `Match.actors` - shield bubbles, power-up halos, rings, name tags, crates, mud,
decoys and ghosts - is mirrored node by node from per-frame snapshots (bare copies, placed and shown as
recorded), charge meters are redrawn from their recorded fill, and every `Juice` word and burst
(`Juice.spawned`) is made again where and when it was. The crown
and victory calls the result makes on the deciding tick are left out. The camera stands side-on to the
throw, wide enough for thrower and victim, then pushes in on the knockdown.

**Dog select.** Roster grid across the top; a seat per player underneath. A seat is a character card for
whatever that player's cursor is on - the dog turning on a spotlight, its name and one line, and its four
ratings (`DogData.*_rating`) - so dogs are compared by moving across the grid.

**Behind walls.** Each dog checks the camera's line of sight to its body every 0.1 s (outer boundary
colliders are ignored because the visible fence is lower). When hidden, `DogModel.set_silhouette` fades
in a player-coloured pass (`assets/shaders/silhouette.gdshader`) that draws only where something is in
front, nudged toward the camera so a dog never shows through itself.

**Arena gimmicks.** One per arena, each a script in `scripts/arena/` placed under a `Gimmicks` node:
`Sprinkler` (Backyard, a sweeping jet that shoves via `Dog.shove`), `RobotMower` (Agility Park, crosses a
lane on a timer and knocks dogs dizzy with a null-attacker whack), `TallGrass` (Pup Beach, conceals dogs
via `Dog.set_cover`; moving rustles, throwing or dashing reveals), `DogBed` (Living Room, an
`AnimatableBody3D` that slides when a toy hits it). Warp Yard's gimmick is its doggy doors.
`IceSheet` (Frozen Pond, a rounded rectangle of ice: dogs on it keep only `traction` of their grip, so
they get going, stop and turn slowly and slide, and loose toys skid further). `Conveyor` (Kitchen, a
belt that carries dogs through their own collider with `move_and_collide` and tops idle toys up to belt
speed, so it can never push anyone through a wall). `ToyTrain` (Toy Room, an engine and wagons lapping a
stadium-shaped track; every car is an `AnimatableBody3D` on the world layer, so throws bounce off
whichever car is passing; it bumps dogs and toys off the rails to the side they are on, keeps
`TRACK_CLEARANCE` from anything solid so it cannot pin a dog, and goes back to the start each round).

**Arena mechanics.** `Pit` (Backyard's dug holes): walking in stops at the rim, but a dog moved by
anything else - a whack, sprinkler, mower, or dizziness - falls in and is out, credited through
`Dog.knocked_out_by()` to whoever whacked it there in the last two seconds (Frozen Pond's open
water is the same node with `look = WATER`); a dash hops over, toys that
roll in pop out, and spawns, toy placement and bot routes all avoid holes. `Obstacle.breakable` props
(Backyard's crates) lose a hit per toy (two for a wound-up throw), splinter at `toughness`, and are rebuilt
by `reset_for_round()`. `SwingBoard` (Agility Park) is a pivoting wall a `SwitchPad` swings a quarter turn,
changing which way throws bounce; a switch drives anything with `toggle()`/`set_open()`. Every arena node
with `reset_for_round()` is reset when the next round starts on the same arena. As a backstop, the match
moves any settled toy no dog in play can reach back to open ground (`Match._rescue_stranded_toys`).

**Modes.** `GameMode` has `tick`, `timeout_winner`, `bot_goal`, `bot_keeps` and `bot_should_throw_now` hooks; the match
calls `tick` every frame and asks `is_round_over` after it. `HotPotato` marks one toy as the hot bone and
knocks out its holder (or last holder) when the fuse pops. `KingOfTheBed` banks time for a side alone on a
bed placed clear of other gimmicks; first to `CLAIM_TIME` wins, or most time at the whistle. `GoldenBall`
banks time for whichever side holds one golden toy (bots keep it and run). Unfinished mode ideas live in
`data/modes/shelved/`, out of every menu.

**Comfort.** `Game` keeps rumble, knockout slow motion, screen shake, a colour-blind player palette
(`PlayerSlot.palette()`, `Game.team_color()`) and the final-bonk replay, all saved to settings.
`Rumble` (autoload) buzzes pads from `Events`.

**Lighting.** `Arena._style_lighting()` sets one warm key with soft orthogonal shadows, a cool shadowless
fill, and linear tonemapping for every map. `ArenaCamera` keeps `far` at 80 m: the default 4 km far plane
stretched the directional shadow's depth range until nothing cast a shadow at all.

**Audio.** Recorded takes live in `assets/audio/sfx/<sound>/` (all CC0: Kenney packs plus Freesound and
OpenGameArt takes, each listed in `assets/audio/CREDITS.md`); `Sfx` picks one at random per play and falls
back to its synthesised kit for anything without a folder. Barks have a voice per breed:
`Sfx.bark(breed, ...)` plays `bark_<breed>/` takes, else the shared `bark/` (or the synthesised bark) pitched
to the dog's size, per `Sfx.BREED_VOICES`. Only add audio whose source page states CC0, and credit it. `Sfx.play_at(name, world_position)` pans by where the event sits on screen (capped at
`MAX_PAN`), using a small panner bus per voice. The arena calls `Sfx.set_room(indoor, hard_floor)` as it
loads, choosing padded or clicky footsteps and a touch of room reverb.

**Juice.** All feedback goes through `Juice` and `Sfx` so gameplay scripts stay readable and feedback can be
tuned or replaced centrally. Dogs never change size for feedback: `DogModel.pop_feedback()` is a
volume-preserving squash and stretch, and every pulse returns to `_base_scale()`.

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

## Scoring, teams and progress

- **Scoring** (`Game.scoring`): *Rounds won* pays the last dog or pack standing a point a round;
  *Bonks* (the Boomerang Fu way, offered for Last Dog Standing and Hot Potato) pays a point per
  rival bonked and ends the match the moment someone reaches the goal. In Bonks, a self-bonk (hit by
  your own toy) costs a bone (`Game.add_points`, never below nil) and `BoneBreak` snaps it off the
  player's card; in Rounds it costs nothing - the round is just won by whoever is standing. Whoever leads wears the crown in the match (`Match._update_crowns`, ties included),
  in place of their hat.
- **Teams**: any split of up to four dogs into two packs, chosen by pressing dogs on the setup
  screen; `Game.assign_teams` keeps that split while both packs have someone. A pack-mate's throw
  is a pass (`Dog._receive_pass`). A downed dog with a pack-mate standing leaves a `ReviveSpot`;
  standing in it for `REVIVE_TIME` brings the dog back (`Dog.revive`). Bots rescue unguarded mates.
- **Sudden death**: the last `SUDDEN_DEATH_AT` seconds drop `SkyDrop`s on rings aimed at the dogs;
  at zero the round goes to overtime instead of a draw (capped at `OVERTIME_LIMIT`).
- **Callouts**: `Highlights` classifies each knockout (double, return to sender, revenge, bank shot,
  into the hole, long shot, sky bonk); the HUD calls it out and `Progress` counts it.
- **Hats**: `data/hats/*.tres` (`HatData`), built by `HatModel`, worn on `DogModel.head_top_anchor()`
  with a per-style sink and each dog's `hat_offset`/`hat_scale`. `Progress` (autoload) keeps
  lifetime stats in `user://progress.cfg` (tests use a scratch file) and unlocks hats at their
  thresholds; new ones are shown on the results screen. Picked on the dog select seat (bark cycles).
- **CPU difficulty**: `PlayerSlot.cpu_level`, set on the CPU's seat; `BotBrain` scales reaction,
  pause between throws, aim error and pace by it.

