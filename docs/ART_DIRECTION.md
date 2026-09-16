# Fetch: visual and game-feel direction

The source of truth is the original `images/fetch-cover.png` and five turnaround sheets in
`images/models`. Startup/loading and the main menu display the actual cover without stretching.
Selection portraits use the supplied artwork. Gameplay stays fully 3D.

## Character quality: still awaiting authored art

The current procedural dogs do **not** match the sheets closely enough. They remain temporary
placeholders, isolated in `ProceduralDogModel`. They now carry an inverted-hull ink outline on the
silhouette masses (body, head, ears, legs, paws, tail, muzzle) so they read as cartoon characters
and separate a dark dog from a dark arena; tails are built from stacked, overlapping segments that
arc back over the rump instead of standing up as a single spike. No final dog mesh, coat texture or animation rig
has been delivered. The small GLB under `tests/fixtures` is a technical test, never production art.

The production path is implemented: `DogModel` loads each dog's configured GLB/wrapper, validates
skinning, seven animation clips and a rig-bound mouth socket, and blends gameplay poses. Invalid
or missing models fall back safely and remain explicitly marked in the review tool.

Open **Meet the Pack → 3D Dog Studio** for the full original sheet beside the actual runtime
model, directional views, pose selection, rotation, mouth-grip marker and readiness errors.
Technical readiness and approved likeness are separate. Follow the
[asset delivery guide](../assets/models/dogs/README.md) for authoring and validation.

Review each dog for silhouette, eye size and spacing, muzzle shape, ears, coat boundaries, fur
clumps, paws, tail and bandana pattern. Shadow is a black Lab with blue; Goose is brindle with red;
Luna is a black tricolor corgi with lavender daisies; Barkley is a fluffy black-and-tan spaniel with
green; Posey is golden with purple. Barkley retains the old `hattie` ID for save/content compatibility.
Check front, side, back and the actual game-camera angle, then check the animations in motion.
A passing validator cannot certify that an asset matches the drawing.

## Fetch's combat identity

Dogs begin every round empty-handed. Six ground toys are laid out symmetrically about both arena
axes — a quad plus an axis pair — so every corner spawn has an identical opening run, and nothing
starts within five metres of a dog: reaching the pile is a decision, not a free pickup. The layout is
redrawn every round, and the toy assignment rotates, so the spots are never memorised. Pickups are checked
against arena collision shapes. Colored ground rings identify loose toys; held toys use smaller
per-item scale/orientation and follow the animated mouth, including turns and victory poses.

| Toy | Role |
| --- | --- |
| Tennis ball | Balanced bounce and speed |
| Frisbee | Fast flat throw that barely bounces |
| Rope toy | Nonlethal shove and disarm |
| Bone | Heavy throw that pierces dogs and stops at a wall |
| Squeaky chicken | Direct bonk; squeak disarms/slows nearby rivals |
| Super ball | Faster, more persistent ricochets |

Only sufficiently fast outbound toys can eliminate. Idle and held toys are harmless, and a throw
is one-way: a toy that leaves your mouth belongs to whoever picks it up next.
Swept hit checks stop at walls and process dogs in contact order. Blocked throws keep owner
protection until the toy has actually cleared its owner and spent enough time in flight.
Ordinary movement and dashing into scenery never cause an elimination. Later ricochets can still
hit their thrower after the protection expires.

From round 2, Shield and Zoomies treats arrive after 10 and 22 seconds of active play.
Shield absorbs one hit; Zoomies raises running speed and shortens dash recovery. Effects last
10 seconds, refresh instead of stack, and reset between rounds. Uncollected treats expire.
The setup screen can disable treats or select a single toy instead of the mixed box.

## Shared camera and eliminations

The camera keeps a fixed tilted heading while smoothly following the group and moving closer as
the pack converges. Living dogs, their overhead labels and airborne toys influence framing.
Fast separation expands the frame immediately enough to retain the action; zooming inward is slower.
Bounds and fit adapt to portrait, standard and ultrawide viewports.

An elimination adds a brief focus on the victim and hit-stop followed by slow motion. The final
elimination gets a stronger, longer emphasis; the result banner waits so the knockout remains visible.
Dogs and scores lock immediately, toy physics stops, and animation continues. Pause, round restart
and scene exit clear timing effects.

This is informed by visible behavior in [official Boomerang Fu footage](https://www.boomerangfu.com/images/marketplace-compressed-smaller.gif)
and its [official overview](https://www.boomerangfu.com/). Fetch uses its own implementation and tuning;
Boomerang Fu's internal camera parameters are not available for an exact implementation match.

## Remaining production work

- Author and review the five matching 3D dogs; the import pipeline is ready to receive them.
- Playtest movement, catching, weapon balance and camera comfort with two to four people on controllers.
  Automated matches establish function, not couch-play balance.
- Replace temporary props and the synthesised audio with art/sound matching the cover. The
  soundtrack is sequenced in `Music` (chord charts per track); swapping in real recordings means
  pointing the track names at streams, not rewriting the callers.
- Add persistent accessibility settings for shake and visual effects.
- Bigger arenas with interactive furniture (portals, switches, moving hazards) — not started.
- Consider sudden death after the core match is playtested.

The engine can report retained RefCounted objects during rapid test-harness shutdown. This diagnostic
is distinct from script errors or failed assertions; physical controller testing remains outstanding.
