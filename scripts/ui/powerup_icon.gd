class_name PowerupIcon
extends RefCounted
## Drawn icons for the power-up table, one per kind.
##
## Letters told you nothing at a glance — a crate popping open in the middle of a fight has to
## read in the half second you can spare for it. These are flat silhouettes with a thick
## outline, built at 3x and downsampled, so they stay legible from a HUD chip up to a crate
## lid and above a dog's head.

const SUPERSAMPLE := 3
## The whole icon is drawn inside this margin so nothing clips when it is scaled down.
const PADDING := 0.09

static var _cache: Dictionary = {}


## A square icon for one kind. Cached: the HUD asks for these every time a belt changes.
static func texture(kind: StringName, size: int = 64, tint: Color = Color.WHITE) -> Texture2D:
	var key := "%s_%d_%s" % [kind, size, tint.to_html(false)]
	if _cache.has(key):
		return _cache[key]
	var big := size * SUPERSAMPLE
	# A flat RGBA buffer: set_pixel call overhead dominates at these sizes, and this is the
	# difference between an icon sheet rendering in a second and in minutes.
	var buffer := PackedByteArray()
	buffer.resize(big * big * 4)
	buffer.fill(0)
	_draw(buffer, kind, big, tint)
	var image := Image.create_from_data(big, big, false, Image.FORMAT_RGBA8, buffer)
	image.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var made := ImageTexture.create_from_image(image)
	_cache[key] = made
	return made


static func _draw(buf: PackedByteArray, kind: StringName, s: int, tint: Color) -> void:
	match kind:
		PowerupKinds.SHIELD:
			_shield(buf, s, tint)
		PowerupKinds.ZOOMIES:
			_bolt(buf, s, tint)
		PowerupKinds.BIG_CATCH:
			_paw(buf, s, tint)
		PowerupKinds.CANNON:
			_chevrons(buf, s, tint)
		PowerupKinds.SPRINGS:
			_coil(buf, s, tint)
		PowerupKinds.LITTLE_LEGS:
			_shrink(buf, s, tint)
		PowerupKinds.QUICK_PAWS:
			_clock(buf, s, tint)
		PowerupKinds.LONG_REACH:
			_reach(buf, s, tint)
		_:
			_question(buf, s, tint)


# ---------------------------------------------------------------- shapes

## A rounded shield: a flat top that tapers to a point.
static func _shield(buf: PackedByteArray, s: int, tint: Color) -> void:
	var m := s * PADDING
	var w := s - m * 2.0
	for y in s:
		for x in s:
			var u := (x - m) / w
			var v := (y - m) / w
			if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
				continue
			var cx := (u - 0.5) * 2.0
			# Shoulders are full width; below the waist the sides close toward a point.
			var half := 1.0 if v < 0.45 else 1.0 - pow((v - 0.45) / 0.55, 1.7)
			if absf(cx) <= half and v <= 1.0:
				_put(buf, s, x, y, tint)


static func _bolt(buf: PackedByteArray, s: int, tint: Color) -> void:
	var points := PackedVector2Array([
		Vector2(0.60, 0.04), Vector2(0.24, 0.55), Vector2(0.46, 0.55),
		Vector2(0.38, 0.96), Vector2(0.78, 0.42), Vector2(0.54, 0.42),
	])
	_polygon(buf, s, points, tint)


static func _paw(buf: PackedByteArray, s: int, tint: Color) -> void:
	_ellipse(buf, s, Vector2(0.5, 0.66), Vector2(0.28, 0.23), tint)
	for i in 4:
		var angle := PI * (0.18 + 0.215 * float(i))
		var at := Vector2(0.5 - cos(angle) * 0.31, 0.37 - sin(angle) * 0.17)
		_ellipse(buf, s, at, Vector2(0.105, 0.135), tint)


## Two stacked chevrons: speed lines pointing the way a throw goes.
static func _chevrons(buf: PackedByteArray, s: int, tint: Color) -> void:
	for i in 2:
		var shift := 0.26 * float(i)
		_polygon(buf, s, PackedVector2Array([
			Vector2(0.18 + shift, 0.14), Vector2(0.52 + shift, 0.5),
			Vector2(0.18 + shift, 0.86), Vector2(0.30 + shift, 0.86),
			Vector2(0.64 + shift, 0.5), Vector2(0.30 + shift, 0.14),
		]), tint)


## A side-on spring: stacked bars that step across as they rise.
static func _coil(buf: PackedByteArray, s: int, tint: Color) -> void:
	for i in 4:
		var v := 0.20 + 0.175 * float(i)
		var lean := 0.10 * (1.0 if i % 2 == 0 else -1.0)
		_polygon(buf, s, PackedVector2Array([
			Vector2(0.22 + lean, v), Vector2(0.78 + lean, v),
			Vector2(0.78 + lean, v + 0.085), Vector2(0.22 + lean, v + 0.085),
		]), tint)


## Four arrows pointing inward: the dog gets smaller.
static func _shrink(buf: PackedByteArray, s: int, tint: Color) -> void:
	_ellipse(buf, s, Vector2(0.5, 0.5), Vector2(0.14, 0.14), tint)
	# Typed, because an untyped array literal yields Variant and := cannot infer from it.
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]
	for corner in corners:
		var dir := (Vector2(0.5, 0.5) - corner).normalized()
		var tip := corner + dir * 0.30
		var tail := corner + dir * 0.07
		var side := Vector2(-dir.y, dir.x) * 0.09
		_polygon(buf, s, PackedVector2Array([tip, tail + side, tail - side]), tint)


static func _clock(buf: PackedByteArray, s: int, tint: Color) -> void:
	_ring(buf, s, Vector2(0.5, 0.54), 0.36, 0.10, tint)
	# Hands at roughly ten-to-two, which reads as a clock at any size.
	_polygon(buf, s, PackedVector2Array([
		Vector2(0.46, 0.54), Vector2(0.54, 0.54), Vector2(0.54, 0.28), Vector2(0.46, 0.28)]), tint)
	_polygon(buf, s, PackedVector2Array([
		Vector2(0.48, 0.58), Vector2(0.48, 0.50), Vector2(0.72, 0.50), Vector2(0.72, 0.58)]), tint)


## An arrow with a paw at the far end: hitting things further away.
static func _reach(buf: PackedByteArray, s: int, tint: Color) -> void:
	_polygon(buf, s, PackedVector2Array([
		Vector2(0.12, 0.44), Vector2(0.58, 0.44), Vector2(0.58, 0.56), Vector2(0.12, 0.56)]), tint)
	_polygon(buf, s, PackedVector2Array([
		Vector2(0.54, 0.28), Vector2(0.90, 0.50), Vector2(0.54, 0.72)]), tint)
	_ellipse(buf, s, Vector2(0.20, 0.50), Vector2(0.13, 0.17), tint)


static func _question(buf: PackedByteArray, s: int, tint: Color) -> void:
	_ring(buf, s, Vector2(0.5, 0.40), 0.26, 0.11, tint)
	_polygon(buf, s, PackedVector2Array([
		Vector2(0.44, 0.52), Vector2(0.56, 0.52), Vector2(0.56, 0.70), Vector2(0.44, 0.70)]), tint)
	_ellipse(buf, s, Vector2(0.5, 0.84), Vector2(0.08, 0.08), tint)


# ---------------------------------------------------------------- primitives

static func _put(buf: PackedByteArray, s: int, x: int, y: int, tint: Color) -> void:
	if x < 0 or y < 0 or x >= s or y >= s:
		return
	var i := (y * s + x) * 4
	buf[i] = int(clampf(tint.r, 0.0, 1.0) * 255.0)
	buf[i + 1] = int(clampf(tint.g, 0.0, 1.0) * 255.0)
	buf[i + 2] = int(clampf(tint.b, 0.0, 1.0) * 255.0)
	buf[i + 3] = 255


static func _ellipse(buf: PackedByteArray, s: int, centre: Vector2, radii: Vector2, tint: Color) -> void:
	var c := centre * float(s)
	var r := radii * float(s)
	for y in range(maxi(0, int(c.y - r.y) - 1), mini(s, int(c.y + r.y) + 2)):
		for x in range(maxi(0, int(c.x - r.x) - 1), mini(s, int(c.x + r.x) + 2)):
			var dx := (float(x) + 0.5 - c.x) / maxf(r.x, 0.0001)
			var dy := (float(y) + 0.5 - c.y) / maxf(r.y, 0.0001)
			if dx * dx + dy * dy <= 1.0:
				_put(buf, s, x, y, tint)


static func _ring(buf: PackedByteArray, s: int, centre: Vector2, radius: float, thickness: float, tint: Color) -> void:
	var c := centre * float(s)
	var outer := radius * float(s)
	var inner := maxf(0.0, (radius - thickness)) * float(s)
	for y in range(maxi(0, int(c.y - outer) - 1), mini(s, int(c.y + outer) + 2)):
		for x in range(maxi(0, int(c.x - outer) - 1), mini(s, int(c.x + outer) + 2)):
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(c)
			if d <= outer and d >= inner:
				_put(buf, s, x, y, tint)


## Even-odd fill of a polygon given in 0..1 coordinates.
static func _polygon(buf: PackedByteArray, s: int, points: PackedVector2Array, tint: Color) -> void:
	var scaled := PackedVector2Array()
	var top := INF
	var bottom := -INF
	for p in points:
		var q := p * float(s)
		scaled.append(q)
		top = minf(top, q.y)
		bottom = maxf(bottom, q.y)
	for y in range(maxi(0, int(top)), mini(s, int(bottom) + 1)):
		var sample := float(y) + 0.5
		var crossings: Array[float] = []
		for i in scaled.size():
			var a := scaled[i]
			var b := scaled[(i + 1) % scaled.size()]
			if (a.y <= sample and b.y > sample) or (b.y <= sample and a.y > sample):
				crossings.append(a.x + (sample - a.y) / (b.y - a.y) * (b.x - a.x))
		crossings.sort()
		var i := 0
		while i + 1 < crossings.size():
			for x in range(maxi(0, int(crossings[i])), mini(s, int(crossings[i + 1]) + 1)):
				_put(buf, s, x, y, tint)
			i += 2
