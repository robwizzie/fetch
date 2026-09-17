class_name DogData
extends Resource
## Gameplay and authored 3D asset contract for one playable dog.
## See assets/models/dogs/README.md before adding an imported character.
## Files are loaded in filename order, so prefix with a number to control menu order.

## Body plan used by DogModel. Each breed has its own proportions, ears, tail and markings.
enum Breed { LABRADOR, PITBULL, CORGI, DACHSHUND, GOLDEN, SPANIEL }

@export var id: StringName = &"shadow"
@export var display_name: String = "Shadow"
@export_multiline var description: String = "Balanced and reliable."
@export var breed: Breed = Breed.LABRADOR

@export_group("Look")
## Main coat colour.
@export var fur_color: Color = Color(0.1, 0.1, 0.13)
## White/cream/tan patches: chest, muzzle, blaze, socks (used per breed).
@export var markings_color: Color = Color(0.95, 0.95, 0.95)
## Second coat colour: tan points, brindle stripes and ear shading.
@export var secondary_color: Color = Color(0.16, 0.16, 0.2)
@export var bandana_color: Color = Color(0.2, 0.45, 1.0)
## Original character sheet and its front-view crop for faithful menu portraits.
@export_file("*.png") var reference_sheet: String = ""
@export var portrait_region: Rect2 = Rect2(30, 135, 300, 375)
## Card colours on the select screen (bright top, dark bottom).
@export var card_color: Color = Color(0.24, 0.5, 1.0)
@export var card_color_dark: Color = Color(0.1, 0.2, 0.5)
## Overall model scale (breed proportions are baked into DogModel).
@export var model_scale: float = 1.0

@export_group("Authored 3D model")
## Use a wrapper .tscn or an imported GLB. A missing/invalid asset uses the placeholder.
@export var model_scene: PackedScene
## Optional path permits preparing the pipeline before the GLB has been delivered.
@export_file("*.glb", "*.gltf", "*.tscn") var model_scene_path: String = ""
## Import correction only. Author feet at Y=0, face -Z, one Godot unit = one metre.
@export_range(0.001, 100.0) var model_import_scale: float = 1.0
@export var model_rotation_degrees := Vector3.ZERO
@export var model_offset := Vector3.ZERO
## Height including ears, before model_scale; used for framing and overhead UI.
@export_range(0.1, 10.0) var model_height: float = 1.45
## Optional explicit path within the imported root, to a socket below a BoneAttachment3D.
@export var mouth_socket_path: NodePath
## A dedicated exported rig bone also works; the renderer creates its BoneAttachment3D.
@export var mouth_socket_bone: StringName = &"MouthSocket"
## Map gameplay states to full AnimationPlayer clip names (including a library prefix).
@export var model_animations: Dictionary = {
	"idle": &"idle", "run": &"run", "throw": &"throw", "catch": &"catch",
	"dash": &"dash", "ko": &"ko", "win": &"win",
}
## Technical validity cannot certify likeness. Mark true only after visual reference review.
@export var likeness_reviewed: bool = false
@export_multiline var model_review_notes: String = "Awaiting authored mesh, textures, rig and animation."

@export_group("Ratings (1-5, shown on the select screen)")
@export_range(1, 5) var speed_rating: int = 3
@export_range(1, 5) var throw_rating: int = 3
@export_range(1, 5) var catch_rating: int = 3
@export_range(1, 5) var dash_rating: int = 3

@export_group("Gameplay numbers")
## Top speed in metres per second.
@export var move_speed: float = 4.8
## Multiplier applied to the toy's base throw speed.
@export var throw_power: float = 1.0
## Pressing catch while a dangerous toy is inside this radius catches it immediately.
@export var catch_radius: float = 2.0
## A catch press also stays "armed" for this many seconds: a toy that would hit the dog in that
## window is caught instead. This is the real skill window; bigger = more forgiving.
@export var catch_window: float = 0.22
## After a missed catch press the dog can't try again for this long (stops button mashing).
@export var catch_cooldown: float = 0.35
## Distance covered by one dash, in metres.
@export var dash_distance: float = 3.0
@export var dash_cooldown: float = 1.2
## Hitbox radius. Smaller dogs are harder to hit.
@export var body_radius: float = 0.72
