# FETCH — notes for Claude Code sessions

Top-down local-multiplayer party game (Boomerang Fu-style) built in **Godot 4.7.2 / GDScript, 3D** with a fixed tilted camera. Gameplay runs on the XZ plane (y pinned); +Z is toward the camera.
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
- Fonts: Luckiest Guy (logo/titles, Apache 2.0) and Fredoka (UI, OFL) in `assets/fonts`; use `UiKit.title()` / `UiKit.FONT_DISPLAY` rather than new font resources.
- Dogs are breed-specific: `DogData.breed` picks a body plan in `DogModel.breed_spec()`; colours/markings come from the `.tres`. Keep the five breeds recognisable (black Lab, grey pit bull, tri-colour corgi, black-and-tan dachshund, golden retriever).
- Menu palette lives in `UiKit` (NAVY, CREAM, YELLOW, WOOD). Dog cards use the dog's `card_color`; the player colour is only the border and P-tag.
- Placeholder art is primitive meshes built in code (`DogModel`, `ToyModel`, `Obstacle`) with toon materials from `Mats`. Real models replace those nodes, not the gameplay scripts.
- Units are metres. Arena is 26 x 14.6 centred on the origin. Speeds ~7 m/s, throws ~18 m/s.
- Nodes built before entering the tree can't call `look_at()`; use `look_at_from_position()`.
- `match` is a GDScript keyword: the match scene's script uses `game_match` for references.
- Keep the smoke test passing and extend it when adding a mechanic (it uses `DeviceInput.VIRTUAL` scripted players).
