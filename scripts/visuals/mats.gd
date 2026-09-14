class_name Mats
extends RefCounted
## Material helpers for the low-poly toon look. One place to change the whole game's shading.


static func flat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	return m


static func unlit(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func glass(color: Color) -> StandardMaterial3D:
	var m := flat(color, 0.2)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Convenience: a MeshInstance3D with a mesh, material and transform, added to parent.
static func mesh(parent: Node3D, m: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = flat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 6
	return c


static func cylinder(radius: float, height: float, top_radius: float = -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = radius
	c.top_radius = radius if top_radius < 0.0 else top_radius
	c.height = height
	c.radial_segments = 20
	return c


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 12
	return t


static func prism(size: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = size
	return p
