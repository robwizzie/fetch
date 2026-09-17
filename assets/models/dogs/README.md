# Delivering a dog

This is the contract for an authored dog. It is enforced in code by
`scripts/visuals/dog_asset_validator.gd` — if a delivery satisfies everything here, the game
uses it; if anything is missing, that one dog falls back to the procedural placeholder and the
rest of the pack is unaffected. **You can deliver one dog at a time.**

Reference artwork for the five characters is in `images/models/*.png` (full turnarounds) and
`images/fetch-cover.png`. Those sheets are the source of truth for likeness.

## Hard requirements

The validator rejects a model that fails any of these:

| # | Requirement | Why |
|---|---|---|
| 1 | Scene root is a **Node3D** | The renderer parents it directly |
| 2 | At least one **Skeleton3D** with bones | Gameplay poses are driven on the rig |
| 3 | At least one **skinned MeshInstance3D** bound to that skeleton | Deform weights must survive export |
| 4 | A **rig-bound mouth socket** (see below) | Toys attach to the animated jaw |
| 5 | An **AnimationPlayer** with all seven clips, each with tracks | The gameplay states |
| 6 | Positive import scale | Transforms must be applied in the source file |

Technical validity is **not** approval of likeness. `DogData.likeness_reviewed` is a separate
human sign-off after comparing front, side, back and the in-game camera angle to the sheet.

## Conventions

- **One Godot unit = one metre.** Heights run 0.95–1.35 m including ears — see the table
  below. These are cartoon proportions, not real breed heights.
- **Feet at Y = 0.** The origin sits between the back paws on the ground, not at the hips.
- **Facing −Z.** The dog looks down negative Z with +X to its left.
- Apply all transforms before export (no baked-in object scale or rotation).
- Record the real height, ears included, in `DogData.model_height` — framing and the overhead
  name tag use it. The rendered size is `model_height × model_scale`.

## How tall is each dog

A dog's height tracks its `body_radius`, which is its collision capsule and the radius a toy has
to reach to hit it. Keeping the two in step is what makes the size trade legible: Barkley is
genuinely harder to hit than Posey, and he looks it. Shadow at 1.20 m is the anchor.

| Dog | Breed | `body_radius` | `model_height` | `model_scale` | Rendered |
|---|---|---|---|---|---|
| Barkley | spaniel | 0.55 | 1.00 | 0.95 | 0.95 m |
| Luna | corgi | 0.58 | 1.05 | 0.95 | 1.00 m |
| Shadow | lab | 0.72 | 1.20 | 1.00 | 1.20 m |
| Goose | pit bull | 0.78 | 1.275 | 1.02 | 1.30 m |
| Posey | golden | 0.80 | 1.25 | 1.08 | 1.35 m |

Luna measures taller than Barkley despite being the shorter dog, because a corgi's upright ears
are the top of the silhouette while a spaniel's floppy ones are not. Goose is shorter than Posey
on purpose — a pit bull reads as bulky, not tall, and his bulk comes from `body_radius`.

## The mouth socket

Toys are held in the mouth and must follow it through every animation, so the attachment has to
be **rig-bound**, not a loose node. Either is accepted:

- Export a deform bone named `MouthSocket`, positioned at the front of the lower jaw with +Z
  pointing out of the mouth; the renderer creates the `BoneAttachment3D` itself. **Preferred.**
- Or place a `Marker3D` named `MouthSocket` under a `BoneAttachment3D` that is parented to a
  jaw or head bone.

The bone name is configurable per dog via `DogData.mouth_socket_bone`, and an explicit path via
`DogData.mouth_socket_path`, if your rig names things differently.

## Animation clips

Seven clips, all looping except `throw`, `catch` and `ko`:

| Clip | Length | Notes |
|---|---|---|
| `idle` | 1–2 s loop | Breathing, small tail motion |
| `run` | 0.5–0.8 s loop | The default movement cycle |
| `throw` | ~0.3 s | A head flick; the mouth socket must open away from the body |
| `catch` | ~0.3 s | A snap toward the incoming toy |
| `dash` | ~0.2 s loop | A stretched lunge pose |
| `ko` | ~0.8 s | Knocked over; ends resting on the ground |
| `win` | 1–2 s loop | Celebration for the results screen |

Names can differ from this table as long as `DogData.model_animations` maps each state to the
real clip name (including any library prefix Godot adds on import, e.g. `Library/run`).

Each clip must contain at least one track. A clip that exists but was never baked fails
validation — bake the action before exporting.

## Hooking it up

Working through a delivery, in order:

1. Keep the **animated** export (the one carrying the walk cycle) and delete the bind-pose-only
   one — both contain the same rig, but only one has a usable clip. Name it `<dog_id>.glb`.
2. Set `nodes/root_scale` in its `.import` so the dog stands about **1.2 m** tall. The number is
   `1.2 / (the glTF POSITION accessor's Y extent)`; Meshy exports at roughly 1/60th scale, so
   expect something in the 60–75 range. Getting this right matters — the arena, collision radii,
   throw distances and camera framing are all tuned around 1.2 m dogs.
3. Run the clip tool (below) and point `model_scene_path` at the generated `.tscn`.
4. Set `model_height = 1.2`, `mouth_socket_bone` and `model_animations`.

Re-run the clip tool after **any** change to the `.import`: `root_scale` bakes into the bone
rests, and those are serialised into the wrapper scene, so the `.tscn` does not follow along
on its own.

For the Meshy quadruped rigs specifically, the settled values are `model_rotation_degrees =
Vector3(0, 180, 0)` (they face +Z, the game wants −Z) and `mouth_socket_bone = &"headend"`
(that bone already sits at the muzzle, so no bone needs adding).

### Values in use

The whole pack is delivered. For reference, the `root_scale` each one needed — they vary a lot,
which is why the number is computed per dog rather than copied:

| Dog | root_scale | triangles |
|---|---|---|
| Shadow | 63.5 | 8.8K |
| Goose | 70.7 | ~9K |
| Luna | 93.3 | 18.8K |
| Barkley | 68.7 | ~9K |
| Posey | 123.7 | 7.6K |

All five share `model_height = 1.2`, `model_rotation_degrees = Vector3(0, 180, 0)` and
`mouth_socket_bone = &"headend"`.

A rig export must be **under 300K triangles** or Meshy refuses to rig it. Remesh first (10K,
quad topology) — a high-detail generation lands near 850K and is rejected. The giveaway that
you have the wrong export: the file is ~30 MB with no `quadruped` in its name and, when
inspected, has zero skins and zero joints.

### The fields

1. Drop the `.glb` in `assets/models/dogs/<dog_id>/`.
2. In the dog's `.tres` under `data/dogs/`, set **either** `model_scene` (drag the imported
   scene in) **or** `model_scene_path` (useful to wire up before the art lands).
3. Set `model_height`, and `model_import_scale` / `model_rotation_degrees` / `model_offset`
   only if the source file could not be corrected.
4. Leave `likeness_reviewed = false` until someone has compared it to the sheet.

## Filling in the missing clips

A generated rig usually arrives with one stock locomotion cycle and none of the seven the game
needs. `tools/build_dog_clips.gd` bakes a full set onto the rig and saves a wrapper scene, so an
authored dog is playable the day it lands:

```bash
godot --headless --path . res://tools/build_dog_clips.tscn -- --dog=shadow
```

It reads `assets/models/dogs/<dog>/<dog>.glb`, adds `idle`, `run`, `throw`, `catch`, `dash`,
`ko` and `win` to the model's animation library, and writes `<dog>.tscn` beside it. Point
`DogData.model_scene_path` at the `.tscn` rather than the `.glb`.

These are honest stand-ins, not hand animation — poses keyed a few degrees off each bone's rest.
They read correctly at the game camera and they are a long way better than one cycle playing for
every state, but they are meant to be replaced. Re-export a real clip from Blender under the same
name and it takes over; there is no need to redo the others, and nothing else in the data changes.

The poses are written in degrees relative to bone rest and target the quadruped bone names Meshy
produces (`Hips`, `chest`, `head`, `frontleg`, `backleg`, `tailstart`, …), so the same tool works
for the rest of the pack as they arrive.

## Validating

- **In game:** Main menu → Meet the Pack → 3D Dog Studio. It shows the original sheet beside
  the live model, directional views, pose selection, the mouth-grip marker, and lists any
  validation errors.
- **Headless:** `godot --headless --path . res://tests/asset_pipeline_test.tscn` checks the rig
  contract. `tests/fixtures/rig_contract.glb` is a minimal example that satisfies every
  requirement above — it is a technical fixture, not production art, and is worth opening if a
  delivery is being rejected and it is not obvious why.

## Can an AI model generate these?

Partly, and it is worth being precise about which part, because the contract above is four
jobs and image-to-3D tools do one of them.

| Step | Can a generator do it? |
|---|---|
| Mesh + texture from the turnaround sheets | **Yes** — this is what they are good at, and a stylised puppy is a favourable subject |
| Clean topology that deforms well | **Usually** — via a remesh/retopology pass in the same tool |
| Skeleton + skin weights | **Yes** — Meshy added quadruped auto-rigging (it has a "Quadruped Dog" type) |
| A `MouthSocket` bone at the jaw | No — one bone, added by hand |
| The seven named clips | Mostly no — quadruped motion libraries are thin, and `throw` / `catch` / `ko` are specific to this game |

So the realistic pipeline is: **generate and rig in the tool, then finish the animation by
hand.** That is a much smaller job than it used to be — the sculpting, retopology and skinning
are all automatable now; what is left is one extra bone and seven short actions.

Two things make that much cheaper:

- **Feed it the turnaround sheet, not the cover.** `images/models/*.png` are already orthographic
  multi-view references, which is exactly the input these tools want — use the FRONT, SIDE and
  BACK panels together in a multi-image generation. Shadow's three are already cut out in
  `images/models/crops/` as a worked example. The cover is a dynamic action shot and will produce
  a worse mesh.
- **Generate one dog, not five.** If each dog is generated separately they will have different
  topology and different proportions, so you cannot share a rig or the animations — you would be
  paying the expensive part five times. Generate the base puppy, rig and animate it once, then
  reproportion and recolour it per breed as described below.

### Scale, measured rather than guessed

Meshy's rig step has a Height field. **It does not affect the exported geometry** — every dog
comes back normalised to roughly the same 0.017–0.019 unit bounding box no matter what you type.
Shadow, Goose and Barkley were rigged at different heights and landed within 10% of each other.

So the field is only a gate: the rigger refuses anything under 1 m, and beyond clearing that the
value is irrelevant. Set it to 2 for every dog and do the sizing in Godot.

Measure the export, then set `nodes/root_scale` in the `.import` to match:

```bash
python3 tools/measure_dog_glb.py assets/models/dogs/goose/goose.glb 1.275
#   height, ears included = 0.016967 glb units
#   nodes/root_scale = 75.1   for model_height = 1.275
#   feet will sit +0.021 m off the ground
```

It reads the skinned vertex bounds, not the joints — paw pads sit below the lowest bone and ear
tips above the highest, so measuring the rig alone overstates `root_scale` by about 3%. It also
fails loudly if a delivery came back without a skin. The current values are `shadow` 63.5,
`goose` 75.1, `barkley` 57.3.

Orientation still needs a hand correction: Meshy's "face your character to the screen left side"
produces a dog facing +Z, so every delivery so far wants
`model_rotation_degrees = Vector3(0, 180, 0)`. Correct genuine mesh problems in Blender rather
than compensating with `model_import_scale` / `model_offset` — those exist for deliveries you
cannot re-export, not as a normal step.

### One rig for the whole pack

Meshy's quadruped rig is deterministic: Shadow, Goose and Barkley came back with **identical
27-bone skeletons**, bone for bone. That is the "one base puppy" outcome above, arrived at for
free — `tools/build_dog_clips.gd` bakes the same seven clips onto all of them, `headend` serves
as the mouth socket on all of them, and a hand-added `MouthSocket` bone transfers to all of them.

Nothing about the wiring changes: whatever produced the GLB, you still set `model_scene` (or
`model_scene_path`), `model_height` and the socket/animation fields on the dog's `.tres`, then
validate in the 3D Dog Studio.

## Suggested production approach

The five dogs are different breeds but the same character style and the same skeleton. Modelling
and animating five characters from scratch is roughly five times the work for no benefit.

Build **one base puppy**: one mesh, one rig, one set of seven clips. Then produce each breed as
a variant of that base — reproportion the body, swap the ears and tail, change the coat colours
and markings. The animations are authored once and shared, and the mouth socket stays in the same
place on every dog.

This mirrors how the placeholder already works: `ProceduralDogModel.breed_spec()` varies
proportions and features over one shared body plan, and it is worth reading as a description of
what distinguishes each breed.
