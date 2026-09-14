# FETCH — notes for Claude Code sessions

Top-down local-multiplayer party game (Boomerang Fu-style) built in **Godot 4.7.2 / GDScript**.
Read `docs/GAMEPLAN.md` for the why and the roadmap, `docs/ARCHITECTURE.md` for how the code fits together.

## Run / validate

```bash
# Download the matching Godot build once (Linux example; see README for other platforms)
curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip && unzip -q godot.zip
GODOT=./Godot_v4.7.2-stable_linux.x86_64

$GODOT --headless --path . --import                       # generate .godot/ + .uid files, surfaces parse errors
$GODOT --headless --path . res://tests/smoke_test.tscn     # plays a full match with scripted players; exit 0 = pass
# Visual check (needs Xvfb or a display): writes PNGs of every screen
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1920x1080x24" $GODOT --path . --rendering-driver opengl3 res://tests/screenshots.tscn -- --out=/tmp/shots
```

Always run `--import` then the smoke test before committing. Commit generated `*.uid` files; never commit `.godot/`.

## Conventions

- GDScript, tabs, static typing everywhere (`var x: Type` / `:=`). Godot 4.7 rejects `var f := array[i]` — type it explicitly.
- One responsibility per script. Gameplay talks to the rest of the game through `Events` (signal bus), never by reaching into UI nodes.
- Content is data: dogs/toys/arenas/modes are `.tres` files in `data/`, discovered by folder scan. Add content by adding a file, not by editing code.
- Menus are built in code with `UiKit` helpers for now. Keep them that way until the art direction is locked.
- Placeholder art is `_draw()`-based (`DogVisual`, `ToyVisual`, `Obstacle`). Real sprites replace those nodes, not the gameplay scripts.
- `match` is a GDScript keyword: the match scene's script uses `game_match` for references.
- Keep the smoke test passing and extend it when adding a mechanic (it uses `DeviceInput.VIRTUAL` scripted players).
