# FETCH

**Throw. Dodge. Fetch. Repeat.** A top-down local-multiplayer party game where 2–4 dogs throw toys
at each other in small, chaotic arenas. Inspired by *Boomerang Fu*.

Built with **Godot 4.7.2 (GDScript)** in **3D** with a fixed tilted camera, like Boomerang Fu. Everything in
this repo is a working prototype you can play today: join with any mix of gamepads and keyboard, pick a dog,
pick an arena and toy, and play *Last Dog Standing* to 5 points. Art is placeholder low-poly built from
primitives, ready to be swapped for real models.

- Why Godot, why 2D, what's next: [`docs/GAMEPLAN.md`](docs/GAMEPLAN.md)
- How the code is organised and how to add dogs / toys / arenas / modes: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)

## Run it

1. Download **Godot 4.7.2** (standard build, not .NET) from https://godotengine.org/download or
   https://github.com/godotengine/godot/releases/tag/4.7.2-stable
2. Open Godot → **Import** → pick `project.godot` in this folder.
3. Press **F5** (Run Project).

You can also run a scene directly with **F6** while it's open (e.g. `scenes/match/match.tscn` auto-fills two keyboard players).

## Controls

| Action | Gamepad | Keyboard 1 | Keyboard 2 |
|---|---|---|---|
| Join (dog select) | A / Start | Space | Enter |
| Move | Left stick / D-pad | WASD | Arrow keys |
| Throw / Catch / Pick up | A or X | Space | Enter |
| Dash (invincible) | B, RB or RT | Left Shift or E | Right Ctrl, `/` or Numpad 0 |
| Back / leave | B / Back | Esc | Backspace |
| Menus | D-pad + A | Arrows + Enter | Arrows + Enter |

Walk over a toy on the ground to pick it up. Press throw with no toy in hand to **catch**: a toy that
reaches you within the next fraction of a second (per dog: `catch_window`) is caught instead of hitting you.
Mash it and you'll be locked out for a moment, so time it.

## Test it

```bash
godot --headless --path . --import                      # surfaces script errors
godot --headless --path . res://tests/smoke_test.tscn    # scripted 3-player match, exits 0 on pass
```

CI runs the same two commands on every push (`.github/workflows/ci.yml`).

## Status

- ✅ 2–4 local players, any mix of pads + keyboards
- ✅ Movement, dash with i-frames, throw, bounce, catch, one-hit elimination
- ✅ Main menu → dog select → match setup → match → results
- ✅ 5 dogs, 6 toys (4 fully playable, 2 stat-only prototypes), 2 arenas, Last Dog Standing to N points
- ✅ 3D: perspective arena camera, toon-shaded low-poly placeholder dogs/props, real-time shadows, 3D dog portraits in menus
- ✅ Placeholder "juice": screen shake, hit-stop, particles, floating text, synthesised sound
- ⏳ Other modes, real art and audio, pause menu, bots, online play: see the roadmap in `docs/GAMEPLAN.md`
