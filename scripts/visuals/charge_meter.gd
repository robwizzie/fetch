class_name ChargeMeter
extends Node3D
## The wind-up tell for a held throw: a gauge on the ground around the dog's paws. An empty
## track appears the moment the button goes down and fills clockwise from the nose, so the
## table can see who is winding up and how far along they are at a glance.
##
## It is a ring and nothing else — no beam, no arrow. The existing ground aim marker already
## shows the line, so the meter only has to answer "how long have they been holding it".

## Quads around a full circle. Enough that the growing edge never looks stepped.
const SEGMENTS := 48
const LIFT := 0.05
## Where the gauge sits, as an offset from the dog's body radius. The player ring ends at
## +0.28, so the gap keeps the two from reading as one thick band.
const INNER := 0.44
const OUTER := 0.58
## The empty part of the gauge. Dark, so the filled part has something to stand against on a
## pale floor as well as on grass.
const TRACK_COLOR := Color(0.06, 0.05, 0.1, 0.34)

var _fill: ImmediateMesh
var _fill_material: StandardMaterial3D
var _track: MeshInstance3D
var _inner := 1.0
var _outer := 1.0
var _base_color := Color.WHITE
var _drawn := -1.0
var _shown := false
var size_multiplier := 1.0


## Must be called before the first [method set_charge].
func setup(player_color: Color, body_radius: float) -> void:
	# Lifted towards cream so a dark coat's colour still reads on grass, but kept firmly the
	# player's hue: two dogs winding up at once have to be tellable apart.
	_base_color = player_color.lerp(Color("fff3d6"), 0.12)
	_inner = body_radius + INNER
	_outer = body_radius + OUTER
	var track_mesh := ImmediateMesh.new()
	_track = _ribbon(track_mesh, TRACK_COLOR, LIFT)
	_arc(track_mesh, 1.0)
	_fill = ImmediateMesh.new()
	var fill_holder := _ribbon(_fill, _base_color, LIFT + 0.006)
	_fill_material = fill_holder.material_override as StandardMaterial3D
	hide_meter()


## A flat unlit ribbon on the ground. Two-sided, so it never vanishes from a low angle.
func _ribbon(mesh: ImmediateMesh, tint: Color, height: float) -> MeshInstance3D:
	var holder := MeshInstance3D.new()
	holder.mesh = mesh
	holder.position.y = height
	var material := Mats.unlit(tint)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)
	return holder


## [param charge] runs 0 to 1; [param facing] is the flat direction the throw will take.
func set_charge(charge: float, facing: Vector3) -> void:
	if not _shown:
		_shown = true
		_drawn = -1.0
		visible = true
	rotation.y = atan2(-facing.x, -facing.z)
	# Holds the player's colour nearly all the way, then goes white-hot over the last stretch:
	# "there is no more to give" is the one state that needs to carry across the table.
	var heat := smoothstep(0.75, 1.0, charge)
	var tint := _base_color.lerp(Color(1.0, 0.98, 0.86), heat)
	var alpha := 0.78 + 0.22 * charge
	var swell := 1.0 + 0.06 * heat
	if charge >= 1.0:
		swell += 0.05 * sin(Time.get_ticks_msec() * 0.018)
	scale = Vector3(swell * size_multiplier, 1.0, swell * size_multiplier)
	_fill_material.albedo_color = Color(tint, alpha)
	if absf(charge - _drawn) > 0.003:
		_drawn = charge
		_arc(_fill, charge)


## One annulus sector from the nose round to wherever the wind-up has reached.
func _arc(mesh: ImmediateMesh, charge: float) -> void:
	mesh.clear_surfaces()
	if charge <= 0.002:
		return
	var quads := maxi(1, int(ceil(charge * float(SEGMENTS))))
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in quads:
		var from := (float(i) / float(SEGMENTS)) * TAU
		var to := minf(float(i + 1) / float(SEGMENTS), charge) * TAU
		var corners := [
			Vector3(sin(from) * _inner, 0.0, -cos(from) * _inner),
			Vector3(sin(from) * _outer, 0.0, -cos(from) * _outer),
			Vector3(sin(to) * _outer, 0.0, -cos(to) * _outer),
			Vector3(sin(to) * _inner, 0.0, -cos(to) * _inner),
		]
		for index in [0, 1, 2, 0, 2, 3]:
			mesh.surface_set_normal(Vector3.UP)
			mesh.surface_add_vertex(corners[index])
	mesh.surface_end()


func hide_meter() -> void:
	_shown = false
	visible = false
