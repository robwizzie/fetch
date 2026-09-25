# FETCH compared with Boomerang Fu

Research and runtime audit, September 23, 2026. Inspected the **working tree**, including existing uncommitted changes, on base commit `d1b14e6`. This is a research deliverable; it does not change gameplay.

**Recommendation: improve combat consistency and action animation first, then introduce a small set of powers that interact.** FETCH already has a suitable arcade physics foundation. Its largest gaps are inconsistent gameplay rules, animation that does not always line up with the action, and powers that mostly improve statistics instead of changing decisions.

## What is actually known about Boomerang Fu

The developer confirmed Unity, Rewired for controllers, and FMOD for audio in the [launch AMA](https://www.reddit.com/r/NintendoSwitch/comments/i9cb6l/were_cranky_watermelon_and_we_just_released/). I did **not** find a public technical breakdown establishing its movement solver, rigid-body configuration, collision geometry, animation graph, acceleration values, or hit timing. Those internals should not be presented as facts or copied from guesses.

The useful evidence is about design and production:

| Confirmed evidence | Implication for FETCH |
|---|---|
| A boomerang supports slashing, deflection, throwing, ricochets, curving, and returning; losing it changes the player's options. Powers persist and combine, with potential danger to their owner. | Give each existing action several understandable interactions. Preserve FETCH's one-way toy ownership unless deliberately redesigning that loop. |
| The developer deliberately chose distinct character colors and silhouettes for rapid identification, and character-specific comic deaths. | Readability and personality belong in the models and poses, not just overhead labels. |
| A favorite arena uses switch-controlled rotating obstacles that redirect projectiles. | Arena geometry should create plays, as FETCH's portals and switches already begin to do. |

These points come directly from [Paul Kopetko's design interview](https://www.mkaugaming.com/mkau-interviews-cranky-watermelon-boomerang-fu-best-gameplay-winners-2020-australian-game-developer-awards/).

The [official game page](https://www.boomerangfu.com/) lists explosive, multi, fire, ice, teleport, disguise, telekinesis, and decoy powers alongside movement and defensive powers. The important distinction is that several change **what happens**, rather than simply increasing speed or range. That is the model to learn from; the proposed FETCH powers below are our own designs, not claims about Boomerang Fu's implementation.

[Half Giant](https://www.halfgiant.com.au/work/boomerang-fu) says David Smith animated the in-game characters, and that the trailer used remodeled, more detailed versions. Trailer animation is therefore not a valid frame-by-frame benchmark for the shipped gameplay. [Kopetko's portfolio](https://paulkopetko.com/boomerang-fu) describes five years of development around other work, a dedicated art team, and bespoke action-inspired sound design. This level of finish is a sustained art, audio, and iteration effort.

Official [historical patch notes](https://store.steampowered.com/news/posts/?appgroupname=Boomerang+Fu&appids=965680&enddate=1621085686&feed=steam_community_announcements) also show the less glamorous work: moving-obstacle collision fixes, wall-dash restrictions, power-up-cap fixes, slower power acquisition as stacks accumulate, an adjustable spawn rate, and an option to disable slow motion. These are evidence of ongoing consistency and pacing work, not just more effects.

## FETCH today

Runtime loads **5 dogs, 4 toys, and 5 selectable arenas**. Seven mode resources exist; their presence does not mean all seven are playable. The round clock in code is **55 seconds**. First-session treats normally begin in round **3**; repeat matches can start them in round 1. The initial training arena also covers the first scored round. Several README/architecture descriptions are stale.

All five dogs passed the actual model validator. They load rigged scenes and seven required clips; they are not currently falling back to the primitive dog renderer. Technical validity does not establish likeness or animation quality. The repository's `tools/build_dog_clips.gd` explicitly supplies generated interim clips, and the loaded Shadow throw track matches its generated timing.

| System | Current implementation | Assessment |
|---|---|---|
| Movement | `CharacterBody3D`, floating mode, XZ movement, manually followed ramp height | Appropriate for precise arena combat. No evidence justifies changing engines or making dogs free rigid bodies. |
| Response | Acceleration 47 m/s²; one rate for acceleration, braking, and reversal | Shadow reaches 4.75 m/s in about 101 ms; reversing takes about 202 ms, ignoring collisions and tick rounding. Tune separately before assuming movement is simply too slow. |
| Dash | 220 ms burst; 140 ms invulnerability; breed-specific distance | The final 80 ms are vulnerable while the dash presentation remains active. This needs a legible recovery cue. |
| Throw | Release after charge; 620 ms to full; full charge slows movement to 55% | A meaningful commitment, but presentation and timing need alignment. |
| Projectiles | Swept movement against walls/toys; ordered XZ circle sweeps against dogs; friction and bounce loss | Strong existing foundation. Some collision paths disagree about effective sizes. |
| Toy ownership | Empty-handed starts, shared floor toys, no automatic return | A distinct FETCH identity. Keep contested pickups, catches, disarms, and caroms central. |
| Powers | Three persistent slots; eight kinds; oldest replaced; duplicate pickup reroll | Seven powers are stat/size modifiers. Shield is the primary discrete rule change. |
| Presentation | Rig clips, procedural lean/bank, charge gauge, particles, sound, hit-stop, slow motion, shared camera | Much is already implemented. Correct timing and a clearer visual hierarchy will help more than adding effects everywhere. |

Code references: [dog controller](../../scripts/actors/dog.gd), [toys](../../scripts/actors/toy.gd), [power table](../../scripts/data/powerup_kinds.gd), [renderer](../../scripts/visuals/dog_model.gd), [match rules](../../scripts/match/match.gd), [input](../../scripts/input/device_input.gd).

The [Backyard capture](boomerang-fu-evidence/backyard.png) and [wind-up capture](boomerang-fu-evidence/wind-up.png) show bright floor/prop colors, large player rings and labels, and comparatively small dog silhouettes. My visual assessment: these compete with the bodies and their action poses. Use a quieter arena palette, smaller persistent labels, and a stronger distinction between lethal flying toys and harmless floor toys. Verify from normal couch distance, with four players moving. These captures are visual inspection, not a human controller playtest or an input-latency measurement.

## Problems to address first

**P0 — Little Legs does not reliably deliver its advertised protection. Runtime reproduced.** In `Toy._trace_dogs()` (line 348), hit radius is `dog.data.body_radius + data.radius`, ignoring `_size_mult`. A Shadow with Little Legs has a physical radius of 0.64944 m. A tennis ball passing 1.04 m from its center should miss the combined 0.96944 m radius, but eliminated the dog in the probe. On a new dog with the power already in its belt, `setup()` applies stats before nodes exist; `_ready()` then creates the original 0.792 m capsule without reapplying the size. The visual scale is also replaced with 0.82 instead of multiplying the dog's authored base scale. Use one effective gameplay radius, reapply modifiers after initialization, and separate permanent model scale from temporary animation deformation.

**P0 — Melee can hit through solid cover. Runtime reproduced.** `Dog._whack_target()` checks distance and facing but no obstruction. With Long Reach, dogs 1.92 m apart on opposite sides of a 0.2 m wall still produced a 1.5-second dizzy hit. Apply the same cover policy used by projectiles and catching. Test thin walls, prop corners, ramps, and both power states.

**P0 — Bot rounds can stall. Existing suite failed twice, on different arenas.** The first `gameplay_test` run reached a Living Room draw with **zero eliminations**, failing both scored-round and elimination assertions. On repetition, Living Room completed in 6.2 seconds, but Warp Yard timed out with zero eliminations. Both runs exited 1. This is variable bot/test behavior, not a proven deterministic Living Room defect. Do not claim the root cause is known yet: instrument toy reachability, target selection, movement progress, and line-of-sight decisions. Current steering tries local ray-based detours, and `_nearest_rival()` does not exclude allies. Reliable solo play needs reachable goals and team-aware targeting before complex powers are introduced.

**P1 — Overlapping slow effects overwrite each other. Runtime reproduced at handler level.** Entering zones A and B, then exiting B, sets `speed_scale` to 1 even though A still applies. `SlowZone` directly assigns a scalar. Store active effects by source and recompute the chosen rule, such as strongest slow. This matters before adding mud, ice, or other persistent areas; the probe does not establish that existing maps contain overlapping zones.

**P1 — Throw presentation trails the actual action. Code-confirmed.** `Dog._throw()` launches the toy, then starts `play_throw()`. The current 420 ms clip first winds back to a key at 130 ms and snaps forward at 240 ms. Move anticipation into the held-charge state; on release, immediately show the release pose and follow-through. Do not fix this by silently adding 240 ms of input delay. The charge gauge and toy shiver are useful but do not replace a body pose.

**P1 — Action priorities are implicit. Code-confirmed.** `_one_shot` prevents `_update_animation()` from switching to dash until a throw/catch clip finishes, although gameplay can already be dashing. `squash()` selects the catch clip on authored models, including when receiving a whack. Give charge, release, catch attempt, catch success, whack, hit, dash, and recovery explicit presentation states and interruption rules. Keep KO highest priority.

**P1 — Comeback shields bypass the unique-belt rule. Code-confirmed; duplicate chips also appear in the screenshot sequence.** `_grant_comeback_shields()` appends a shield directly without checking for an existing one. An eligible player who retains a shield can receive another next round while a slot remains free. Route grants through the same uniqueness policy as pickups, and test repeated rounds. This conflicts with `PlayerSlot.take_powerup()` and the weapon suite's one-shield expectation.

**P1 — The catch button can become an unintended attack. Design issue.** Empty-handed input prioritizes `_whack_target()` before catching. A nearby rival therefore changes a defensive press into a swipe. The 200 ms action lock also rejects early presses instead of buffering them. Decide the interaction explicitly: prototype catch priority when a threat is inside a defensive cone, or a separate melee input. Measure accidental actions before choosing; extra buttons are a tradeoff.

**P2 — Charge/range descriptions do not match every toy. Calculated, not measured flight.** For Shadow, continuous linear-friction estimates of lethal tap travel are tennis ball **6.50 m**, frisbee **11.33 m**, bone **5.41 m**, and super ball **19.27 m**, before walls/caroms. Formula: `(initial_speed² - danger_speed²) / (2 × friction)`. The existing charged-throw test uses an incomplete distance formula and only checks the tennis ball. Decide whether long-range uncharged toys are intentional, then test all dog/toy combinations. Preserve variety while making the promise of charging accurate.

## Physics and animation direction

Keep the controlled movement model. Godot explicitly supports code-controlled character bodies for top-down actors and custom projectiles; its documentation demonstrates manual ricochet response. This fits FETCH's current architecture. [Godot movement documentation](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html)

Introduce a shared combat geometry/rules layer: effective radius, cover checks, attacker identity, self/team rules, and a hit result such as caught, shielded, deflected, or eliminated. Keep numeric movement modifiers separate from behavior-changing power effects. This reduces disagreement between body collision, swept hits, pickups, bot prediction, and rendering.

Further verification should cover crossing moving targets, simultaneous catches, high-speed corner bounces, and toy piles. Current dog sweeps use the dog's current position rather than sweeping relative dog/toy motion; carom transfer uses incoming speed rather than relative velocity/mass; three collision iterations and a global toy contact cooldown can affect dense collisions. These are **review risks**, not all demonstrated failures. Arcade responses are fine when consistent and understandable.

Prototype separate acceleration, braking, and reversal rates; a remapped radial stick deadzone; and a short action buffer. The present deadzone jumps from zero directly to roughly 25% stick magnitude. Try a **60–100 ms buffer** as a FETCH experiment, not a Boomerang Fu specification. Define what expires on stun, pickup, pause, or round end so stale presses cannot fire later.

Evaluate physics interpolation with fixed simulation timing and frame-rate captures. Godot requires consistent physics-tick transform updates and interpolation resets after teleports; simply enabling it without reviewing portal warps and held-toy transforms can add visual streaking. [Godot interpolation documentation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html)

Use explicit animation transitions, optionally an `AnimationTree` with action overlays and locomotion blending. That is an implementation proposal, not a discovered Boomerang Fu technique. [Godot animation documentation](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)

First author a complete movement/combat set for **one dog**: planted starts/stops, turn, charge hold, release, catch attempt/success, whack, stagger, dash/recovery, and KO. Adjust stride against actual travel; current speed normalization clamps boosted motion at 1.0, so faster movement does not continue increasing stride playback. Use character-specific ears, tails, facial poses, and landing reactions after the timings work. Keep cosmetic debris non-damaging and budget its cost.

## Powers that would change the game

Retain a few easy-to-read anchors such as Shield, Zoomies, and Soft Paws. Prototype these additions in a development arena before expanding the random pool:

| Proposed FETCH power | New decision | Combination and counterplay |
|---|---|---|
| **Squeaky Blast** | A thrown toy visibly arms a short-fuse radial squeak burst on its first valid impact. | Shield absorbs one resolved hit. Walls block the burst. Successful catches defuse it. Self/team rules remain consistent. |
| **Mud Track** | Throws leave short-lived slowing patches along their traveled path. | Combines with ricochets for temporary route control; opponents can choose another route or dash. Cap active patches and avoid unavoidable stun chains. |
| **Scatter Fetch** | Throw a central toy plus two short-lived side projectiles. | Side projectiles inherit approved behavior effects, expire without creating permanent pickup clutter, and share a damage-event identity to prevent one volley immediately consuming Shield and killing its owner. |
| **Dig Dash** | Burrow through designated low obstacles along a committed dash. | Changes escape routes; validates the entire exit footprint. No attacks while inside cover, no crossing outer bounds, and a clear surface trail for opponents. |
| **Good Decoy** | A dash leaves a brief dog decoy that opponents can mistake for the player. | Distinct lifetime/reveal cue; only draws bot attention within their perception/reaction rules. Does not secretly change human targeting. |
| **Bank Shot** | The first wall bounce visibly energizes a throw for a controlled second threat. | Builds on existing ricochet skill and toy identity. Mud can mark the rebound route; cap speed/flight duration to keep the arena readable. |

Build **Squeaky Blast + Mud Track first**, with a shared hit/area policy. Add Scatter Fetch only after that pair works: multiplying projectiles amplifies every collision, attribution, performance, and readability flaw.

Represent effects as composed behavior on a throw: release → travel segment → impact → catch/deflect → settle. Snapshot the relevant powers at launch so a later belt swap cannot silently mutate a projectile in flight. Specify attribution transfer for caroms and catches. Use one hit resolver for direct and area damage. Author pair/triple interaction tables alongside each power; do not bury combinations in a growing `match` statement in `Dog`.

For example, Squeaky Blast + Mud Track can leave one bounded mud patch at the burst location; catching cancels that burst. Scatter + Blast can inherit the fuse while grouping overlapping blast damage. These are proposed contracts that require playtesting, not promises that every combination should multiply in strength.

Treat pacing deserves its own pass. FETCH delays powers for new sessions and then accelerates drops by round/session count. That can make the most distinctive feature arrive late, then flood experienced matches. Compare a small guaranteed introduction during training and a first contested early-round pickup against the current schedule. Add per-power toggles and spawn-rate options after the pool has enough behavioral variety.

## Order of work and acceptance gates

1. **Consistency pass.** Fix effective sizes and respawn application, cover checks, duplicate shields, slow-source composition, and bot stalls observed in Living Room/Warp Yard. Add behavioral regressions: shrunk grazing misses, powers after respawn, melee behind cover, repeated mercy grants, and seeded bot rounds. Existing stat-change assertions are insufficient.
2. **One polished combat slice.** One arena, two dogs, one toy. Align charge/release animation, formalize action priorities, tune braking and recovery, and test input buffering. At 60 fps the release pose should coincide with projectile launch within one rendered frame; gameplay timing remains authoritative. This is a proposed quality target.
3. **Two interacting powers.** Implement Squeaky Blast and Mud Track with recognizable shapes, sounds, counterplay, and bot awareness. Require pause/round-reset cleanup and self/team-rule coverage before adding them to normal matches.
4. **Production presentation.** Replace interim poses dog by dog, unify arena/character material treatment, tune motion and impact sound, and reduce HUD competition. Profile the busiest supported power combination on the intended cabinet/hardware; target stable 60 fps if that is the product target.
5. **Playtest and expand.** A/B against the current build with the same players and arena. Log time to first interaction, idle/unarmed time, unsuccessful catches, accidental swipes, timeout rate, and deaths players cannot explain. Ask players to identify the power and cause of each KO without reading a HUD explanation. Expand arenas/powers after this slice is clearly better.

Parity is a playtest outcome, not something a passing suite can certify. The next useful comparison with Boomerang Fu is a matched capture session from actual gameplay: movement/reversal, throw/recover, defense, dash, KO, and two-power interactions at normal playback speed. This audit does not claim measured frame timings from that game.

## Verification and reproducibility

Used installed Godot **4.7.2.stable.official.ed1daf0bf**. Imported the project, ran the existing weapon, smoke, asset-pipeline, and gameplay suites, ran targeted probes, and generated/render-inspected gameplay and model-studio screenshots. Weapon, smoke, and asset-pipeline suites passed. Both gameplay runs failed: first in Living Room, then in Warp Yard; other arenas completed in each run. The repeat and full output are stored in [verification.txt](boomerang-fu-evidence/verification.txt).

Headless startup logged a macOS certificate warning; editor import also could not save global editor settings inside the sandbox. Some test exits reported ObjectDB leaks. These are recorded, not described as clean logs. The rendered screenshot scene completed with exit 0 using display access. No manual multiplayer playtest was performed.

The targeted probe intentionally reports current behavior rather than changing it. Copy [audit-probe.gd.txt](boomerang-fu-evidence/audit-probe.gd.txt) to `/tmp/fetch-game-feel-audit.gd` and [audit-probe.tscn.txt](boomerang-fu-evidence/audit-probe.tscn.txt) to `/tmp/fetch-game-feel-audit.tscn`, then run:

```sh
/Users/robwiscount/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --path . --log-file /tmp/fetch-game-feel-audit.log \
  /tmp/fetch-game-feel-audit.tscn
```

Model evidence: [the actual loaded Shadow rig in the studio](boomerang-fu-evidence/model-studio.png). Presentation evidence: [Living Room](boomerang-fu-evidence/living-room.png). Screenshots and logs live in an ignored-by-Godot evidence folder so research material does not become game assets.
