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

- **One Godot unit = one metre.** A dog is roughly 0.75–0.95 m tall including ears.
- **Feet at Y = 0.** The origin sits between the back paws on the ground, not at the hips.
- **Facing −Z.** The dog looks down negative Z with +X to its left.
- Apply all transforms before export (no baked-in object scale or rotation).
- Record the real height, ears included, in `DogData.model_height` — framing and the overhead
  name tag use it.

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

1. Drop the `.glb` in `assets/models/dogs/<dog_id>/`.
2. In the dog's `.tres` under `data/dogs/`, set **either** `model_scene` (drag the imported
   scene in) **or** `model_scene_path` (useful to wire up before the art lands).
3. Set `model_height`, and `model_import_scale` / `model_rotation_degrees` / `model_offset`
   only if the source file could not be corrected.
4. Leave `likeness_reviewed = false` until someone has compared it to the sheet.

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
| Clean topology that deforms well | Rarely — output is usually dense and needs retopology before it will bend |
| Skeleton + skin weights | Generally no for quadrupeds; most auto-riggers are humanoid-only |
| Seven named clips + a `MouthSocket` bone | No — this is hand animation against a named contract |

So the realistic pipeline is: **generate the mesh, then rig and animate it yourself** (or have
someone do that part). The generator saves you the sculpting, not the rigging.

Two things make that much cheaper:

- **Feed it the turnaround sheet, not the cover.** `images/models/*.png` are already orthographic
  multi-view references, which is exactly the input these tools want. Crop to a single clean
  pose. The cover is a dynamic action shot and will produce a worse mesh.
- **Generate one dog, not five.** If each dog is generated separately they will have different
  topology and different proportions, so you cannot share a rig or the animations — you would be
  paying the expensive part five times. Generate the base puppy, rig and animate it once, then
  reproportion and recolour it per breed as described below.

Expect to fix scale and orientation by hand after import: generated meshes rarely land with feet
at Y=0 facing −Z at one unit per metre. Correct it in Blender rather than compensating with
`model_import_scale` / `model_rotation_degrees` / `model_offset` — those exist for deliveries you
cannot re-export, not as a normal step.

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
