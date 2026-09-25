# Fetch: visual and game-feel direction

The source of truth is the original `images/fetch-cover.png` and five turnaround sheets in
`images/models`. Startup/loading and the main menu display the actual cover without stretching.
Selection portraits use the supplied artwork. Gameplay stays fully 3D.

## Character quality: still awaiting authored art

All five dogs now use authored, rigged models; `ProceduralDogModel` survives only as the
per-dog fallback for an invalid or missing delivery. Six of the seven animation clips are
generated stand-ins from `tools/build_dog_clips.gd` and are the next thing to replace.

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
per-item scale/orientation and follow the animated mouth, including turns and victory poses. Holding the
throw button winds a shot up. The tell is a gauge on the floor: a dark empty track appears around the dog's
paws the moment the button goes down and fills clockwise from the nose in the player's colour, going
white-hot and swelling over the last stretch. It is a ring and nothing else - the existing ground aim
marker already shows the line - so a wind-up is legible across the table without adding anything to the
dog's silhouette.

| Toy | Role |
| --- | --- |
| Tennis ball | Balanced bounce and speed |
| Frisbee | Fast flat throw that barely bounces |
| Bone | Heavy throw that pierces dogs and stops at a wall |
| Super ball | Faster, more persistent ricochets |

Every toy eliminates on a clean hit. The rope toy and the squeaky chicken, which shoved and
disarmed instead, were removed: at the table nobody could tell why a hit that landed did nothing,
and neither toy was worth picking up once you knew.

Only sufficiently fast outbound toys can eliminate. Idle and held toys are harmless, and a throw
is one-way: a toy that leaves your mouth belongs to whoever picks it up next.
Swept hit checks stop at walls and process dogs in contact order. Blocked throws keep owner
protection until the toy has actually cleared its owner and spent enough time in flight.
Ordinary movement and dashing into scenery never cause an elimination. Later ricochets can still
hit their thrower after the protection expires.

Treats arrive in identical sealed plum, coral and cream tins. Their wrapper, sparkles and arrival
announcement never disclose the randomly rolled reward. A short drop and bounce introduces the tin;
collection lifts its lid, follows the recipient with a reward medallion, and shows the ability name
and effect below that player's score. The same icon and palette appear in the belt and field guide.
All ten powers persist between rounds, with up to three different powers per dog; a new pickup
replaces the oldest in its own socket when the belt is full (slot one first). A round drops two or
three tins in total, spread across the arena, however long it lasts. An already-held result is rerolled to a fresh power.
Shield is consumed by one hit. Uncollected tins expire, and setup can disable treats.
The first-treat round is configurable; automatic timing gives a new session a few rounds to learn.

## Toys and arena craftsmanship

The four toys use rounded silhouettes, smooth seams, restrained material highlights and small paw
stamps. The super ball has curved coloured panels. Loose toys have thin ground markers;
the mystery tin has its own gold double ring. Held and thrown toys retain their existing gameplay
sizes, grips, collision shapes and behavior.

Five arenas, each about one idea, share softly bevelled furniture, quieter playing surfaces and
deliberate perimeter detail. **Backyard** is a pool you cross the slow way or go round, with two
tables reaching out either side of it to split the yard into lanes. **Living Room** is the same
shape indoors: the rug is the tempting middle, couch and telly close off the end lanes, armchairs
are the only cover on the flanks. **Pup Beach** is wide open sand where the two rocks matter
because there is nothing else. **Agility Park** is about the route you take — the tunnel and the
A-frame are the two ways through, with weave poles screening each lane. **Warp Yard** is portals
and switch-gates. Decorative geometry does not add hidden collision.

Every layout follows the same rules, and `tests/arena_layout_test.tscn` holds all of them to it:
four safe starts, the same run to a toy from each, every start and pickup joined to the rest of
the map, open ground near the middle for a crate, and at least one start-to-start sightline
broken. That last one is what separates cover from decoration — props scattered in a flat box
pass every fairness check and still make a dull map. Three arenas that were not yet about anything
are shelved under `data/arenas/shelved/` rather than deleted.

Agility Park's tunnel and A-frame are routes rather than walls: the tube is open end to end and
turns translucent while anyone is inside it, and the A-frame is a deck dogs and toys run up and
over. Both keep solid sides, so the obstacle is a choice rather than a detour. Menu thumbnails are
rendered from the actual arenas using
`tools/build_arena_thumbnails.tscn`. The practice round runs on a sixth map, a bare training yard, which
exists as a scene only and is never offered in the picker: a first-timer is learning the buttons, not a map.

Every toy carries a dark rim on its main form and a dark ring under its ground marker. Several toys sit
within a shade of a floor colour somewhere in the set - a bone all but disappeared on kitchen lino and
courtyard stone - and a toy nobody can pick out of the ground is a toy nobody goes for.

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
- Props remain code-built meshes; bevels, upholstery, joinery and themed surface details provide
  their current finish. Large playing surfaces deliberately avoid tiled grain and random circles.
- Replace temporary props and the synthesised audio with art/sound matching the cover. The
  soundtrack is sequenced in `Music` (chord charts per track); swapping in real recordings means
  pointing the track names at streams, not rewriting the callers.
- Add persistent accessibility settings for shake and visual effects.
- Playtest the eight arena layouts, including portal and switch routes, with two to four players.
- Consider sudden death after the core match is playtested.

The engine can report retained RefCounted objects during rapid test-harness shutdown. This diagnostic
is distinct from script errors or failed assertions; physical controller testing remains outstanding.
