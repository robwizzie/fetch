class_name Mats
extends RefCounted
## Soft, matte materials for the toy-like world. Keep coat and prop colours readable in sunlight.


static var _grain: Texture2D


## Gentle tonal variation shared by every prop. Authored dog models carry texture detail; a
## perfectly flat colour beside them reads as untextured placeholder, so props get a soft
## grain that breaks up large faces without becoming visible noise.
static func grain() -> Texture2D:
	if _grain != null:
		return _grain
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.022
	noise.fractal_octaves = 3
	var size := 96
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			# Centred on 1.0 so it multiplies albedo without shifting the colour.
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var value := 0.88 + n * 0.24
			image.set_pixel(x, y, Color(value, value, value))
	_grain = ImageTexture.create_from_image(image)
	return _grain


static func flat(color: Color, roughness: float = 0.82) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = grain()
	# Triplanar: props are primitives with no meaningful UVs.
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.45, 0.45, 0.45)
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.metallic_specular = 0.28
	return m


## No grain. Large surfaces (the lawn, the surround) are wide enough that a tiling detail
## texture reads as a visible grid, which is worse than being plain.
static func plain(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.metallic_specular = 0.2
	return m


## A mesh on a large surface: same as [method mesh] but without the tiling grain.
static func mesh_plain(parent: Node3D, m: Mesh, color: Color, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = plain(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


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


## Cartoon outline: an inverted-hull copy of the mesh, grown along its normals and drawn back-face only.
static func outline(mi: MeshInstance3D, amount: float = 0.03, color: Color = Color(0.09, 0.07, 0.12)) -> MeshInstance3D:
	var h := MeshInstance3D.new()
	h.mesh = mi.mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = amount
	h.material_override = m
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(h)
	return h


static func cone(radius: float, height: float) -> CylinderMesh:
	return cylinder(radius, height, 0.0)
