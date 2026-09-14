class_name ToyModel
extends Node3D
## Low-poly placeholder toy meshes, picked by toy id. Real models replace this node.

var data: ToyData


func setup(p_data: ToyData) -> void:
	data = p_data
	for c in get_children():
		c.queue_free()
	var r := data.radius
	var c := data.color
	match data.id:
		&"frisbee":
			Mats.mesh(self, Mats.cylinder(r, r * 0.25, r * 0.8), c)
			Mats.mesh(self, Mats.torus(r * 0.45, r * 0.6), c.darkened(0.25), Vector3(0, r * 0.13, 0))
		&"bone":
			Mats.mesh(self, Mats.capsule(r * 0.3, r * 1.8), c, Vector3.ZERO, Vector3(0, 0, 90))
			for p in [Vector3(-r * 0.8, 0, r * 0.35), Vector3(-r * 0.8, 0, -r * 0.35), Vector3(r * 0.8, 0, r * 0.35), Vector3(r * 0.8, 0, -r * 0.35)]:
				Mats.mesh(self, Mats.sphere(r * 0.42), c, p)
		&"rope_toy":
			Mats.mesh(self, Mats.capsule(r * 0.35, r * 2.0), c, Vector3.ZERO, Vector3(0, 0, 90))
			Mats.mesh(self, Mats.torus(r * 0.2, r * 0.42), c.darkened(0.35), Vector3(-r * 0.4, 0, 0), Vector3(0, 0, 90))
			Mats.mesh(self, Mats.torus(r * 0.2, r * 0.42), c.darkened(0.35), Vector3(r * 0.4, 0, 0), Vector3(0, 0, 90))
		&"squeaky_chicken":
			Mats.mesh(self, Mats.sphere(r * 0.85), c, Vector3(0, 0, r * 0.15))
			Mats.mesh(self, Mats.sphere(r * 0.5), c, Vector3(0, r * 0.55, -r * 0.6))
			Mats.mesh(self, Mats.cylinder(r * 0.18, r * 0.4, 0.0), Color(1.0, 0.5, 0.1), Vector3(0, r * 0.5, -r * 1.05), Vector3(-90, 0, 0))
			Mats.mesh(self, Mats.box(Vector3(r * 0.15, r * 0.35, r * 0.3)), Color(0.9, 0.15, 0.15), Vector3(0, r * 1.0, -r * 0.6))
		_:
			Mats.mesh(self, Mats.sphere(r), c)
			Mats.mesh(self, Mats.torus(r * 0.92, r * 1.02), Color(1, 1, 1, 1), Vector3.ZERO, Vector3(35, 0, 20))
			if data.special == ToyData.Special.RICOCHET:
				var core := Mats.mesh(self, Mats.sphere(r * 0.5), Color(1, 1, 1))
				core.material_override = Mats.unlit(Color(1, 1, 1, 0.7))
