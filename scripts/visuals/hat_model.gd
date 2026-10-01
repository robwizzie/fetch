class_name HatModel
extends Node3D
## A hat, built from the same soft primitives as the props. Sized for a dog's head with its brim
## at this node's origin, so it can sit on DogModel.head_top_anchor() as it is.

var data: HatData

## How far each style settles below the top of the skull, in metres at hat scale. A cone or a
## chef's toque balances on the crown of the head; a cap, a helmet or a beanie pulls down over
## it; a ring of daisies or a brim settles into the fur around it; a halo floats.
const SINK := {
	HatData.Style.PARTY: 0.02, HatData.Style.CAP: 0.05, HatData.Style.FLOWERS: 0.03,
	HatData.Style.PROPELLER: 0.05, HatData.Style.CHEF: 0.03, HatData.Style.COWBOY: 0.04,
	HatData.Style.VIKING: 0.06, HatData.Style.TOP_HAT: 0.02, HatData.Style.HALO: -0.06, HatData.Style.CROWN: 0.04,
}


static func sink(style: HatData.Style) -> float:
	return SINK.get(style, 0.04)


func build(p_data: HatData) -> void:
	data = p_data
	for child in get_children():
		child.queue_free()
	var c := data.color
	var a := data.accent
	match data.style:
		HatData.Style.PARTY:
			Mats.mesh(self, Mats.cylinder(0.17, 0.42, 0.0), c, Vector3(0, 0.21, 0))
			for i in 3:
				Mats.mesh(self, Mats.torus(0.17 - i * 0.05 - 0.02, 0.17 - i * 0.05 + 0.005), a, Vector3(0, 0.05 + i * 0.12, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
			Mats.mesh(self, Mats.sphere(0.06), a, Vector3(0, 0.45, 0))
		HatData.Style.CAP:
			Mats.mesh(self, Mats.sphere(0.2), c, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 0.62, 1))
			# The peak sticks out over the brow and tips up a touch, clear of the eyes.
			var brim := Mats.mesh(self, Mats.cylinder(0.15, 0.025), c.darkened(0.15), Vector3(0, 0.05, -0.19), Vector3(-10, 0, 0))
			brim.scale = Vector3(1.1, 1, 0.8)
			Mats.mesh(self, Mats.sphere(0.03), a, Vector3(0, 0.17, 0))
		HatData.Style.FLOWERS:
			for i in 7:
				var angle := TAU * float(i) / 7.0
				ArenaArt.flower(self, Vector3(cos(angle), 0, sin(angle)) * 0.17 + Vector3(0, 0.03, 0), c if i % 2 == 0 else a.lightened(0.3), 0.055)
			Mats.mesh(self, Mats.torus(0.15, 0.18), Color("5c9a3c"), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
		HatData.Style.PROPELLER:
			for i in 4:
				Mats.mesh(self, Mats.sphere(0.19), c if i % 2 == 0 else a, Vector3.ZERO, Vector3(0, i * 90.0, 0), Vector3(1, 0.6, 1))
			Mats.mesh(self, Mats.cylinder(0.015, 0.12), Color("f2c84b"), Vector3(0, 0.16, 0))
			var blades := Node3D.new()
			blades.name = "Blades"
			blades.position = Vector3(0, 0.23, 0)
			add_child(blades)
			for side in [-1.0, 1.0]:
				Mats.mesh(blades, Mats.box(Vector3(0.2, 0.012, 0.05)), Color("f2c84b"), Vector3(side * 0.1, 0, 0), Vector3(side * 12.0, 0, 0))
			var spin := blades.create_tween().set_loops()
			spin.tween_property(blades, "rotation:y", TAU, 0.35).from(0.0)
		HatData.Style.CHEF:
			Mats.mesh(self, Mats.cylinder(0.15, 0.16), c, Vector3(0, 0.08, 0))
			for i in 5:
				var angle := TAU * float(i) / 5.0
				Mats.mesh(self, Mats.sphere(0.1), c, Vector3(cos(angle) * 0.09, 0.24, sin(angle) * 0.09))
			Mats.mesh(self, Mats.sphere(0.12), c, Vector3(0, 0.3, 0))
			Mats.mesh(self, Mats.torus(0.14, 0.165), a, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
		HatData.Style.COWBOY:
			var brim := Mats.mesh(self, Mats.cylinder(0.32, 0.03), c, Vector3(0, 0.01, 0))
			brim.scale = Vector3(1, 1, 0.82)
			Mats.mesh(self, Mats.cylinder(0.15, 0.2, 0.13), c, Vector3(0, 0.12, 0))
			Mats.mesh(self, Mats.torus(0.14, 0.165), a, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
		HatData.Style.VIKING:
			Mats.mesh(self, Mats.sphere(0.2), c, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1, 0.75, 1))
			Mats.mesh(self, Mats.torus(0.18, 0.21), c.darkened(0.25), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
			for side in [-1.0, 1.0]:
				var horn := Mats.mesh(self, Mats.cone(0.05, 0.26), a, Vector3(side * 0.22, 0.12, 0))
				horn.rotation_degrees = Vector3(0, 0, -side * 40.0)
		HatData.Style.TOP_HAT:
			Mats.mesh(self, Mats.cylinder(0.24, 0.025), c, Vector3(0, 0.01, 0))
			Mats.mesh(self, Mats.cylinder(0.14, 0.3), c, Vector3(0, 0.16, 0))
			Mats.mesh(self, Mats.cylinder(0.145, 0.06), a, Vector3(0, 0.06, 0))
		HatData.Style.CROWN:
			Mats.mesh(self, Mats.cylinder(0.2, 0.12, 0.21), c, Vector3(0, 0.06, 0))
			for i in 5:
				var angle := TAU * float(i) / 5.0
				var tip := Vector3(cos(angle) * 0.18, 0.2, sin(angle) * 0.18)
				Mats.mesh(self, Mats.cone(0.06, 0.17), c, tip)
				Mats.mesh(self, Mats.sphere(0.035), a if i % 2 == 0 else Color("4fb3e8"), tip + Vector3(0, 0.1, 0))
		HatData.Style.HALO:
			var ring := Mats.mesh(self, Mats.torus(0.15, 0.2), c, Vector3(0, 0.22, 0))
			ring.material_override = Mats.unlit(c)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var bob := ring.create_tween().set_loops()
			bob.tween_property(ring, "position:y", 0.27, 0.8).set_trans(Tween.TRANS_SINE)
			bob.tween_property(ring, "position:y", 0.22, 0.8).set_trans(Tween.TRANS_SINE)
