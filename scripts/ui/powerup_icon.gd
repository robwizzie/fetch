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


## Enamel reward medallion: a cream rim, dark keyline and one high-contrast symbol.
## Used by the world reveal and guide, so an award looks the same everywhere.
static func badge(kind: StringName, size: int = 128) -> Texture2D:
	var key := "badge_%s_%d" % [kind, size]
	if _cache.has(key):
		return _cache[key]
	var big := size * SUPERSAMPLE
	var buf := PackedByteArray()
	buf.resize(big * big * 4)
	buf.fill(0)
	_ellipse(buf, big, Vector2(0.5, 0.53), Vector2(0.48, 0.46), Color("453354"))
	_ellipse(buf, big, Vector2(0.5, 0.49), Vector2(0.46, 0.46), Color("fff0cb"))
	_ellipse(buf, big, Vector2(0.5, 0.49), Vector2(0.40, 0.40), PowerupKinds.color(kind))
	var glyph_size := int(big * 0.64)
	var glyph := PackedByteArray()
	glyph.resize(glyph_size * glyph_size * 4)
	glyph.fill(0)
	_draw(glyph, kind, glyph_size, Color("352b45"))
	var margin := (big - glyph_size) / 2
	for y in glyph_size:
		for x in glyph_size:
			var source := (y * glyph_size + x) * 4
			if glyph[source + 3] == 0:
				continue
			var target := ((y + margin) * big + x + margin) * 4
			for channel in 4:
				buf[target + channel] = glyph[source + channel]
	var artwork := Image.create_from_data(big, big, false, Image.FORMAT_RGBA8, buf)
	artwork.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var made := ImageTexture.create_from_image(artwork)
	_cache[key] = made
	return made


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
		PowerupKinds.TELEPAWTHY:
			_curve_arrow(buf, s, tint)
		PowerupKinds.GHOST_PUP:
			_ghost(buf, s, tint)
		PowerupKinds.DIG:
			_shovel(buf, s, tint)
		&"paw":
			_paw(buf, s, tint)
		PowerupKinds.SQUEAKY_BLAST:
			var points := PackedVector2Array()
			for i in 16:
				var angle := TAU * float(i) / 16.0
				points.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * (0.44 if i % 2 == 0 else 0.24))
			_polygon(buf, s, points, tint)
		PowerupKinds.HOT_DOG:
			# A flame: a teardrop licking up, a smaller tongue beside it.
			var flame := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0
				var angle := lerpf(0.0, TAU, t)
				var r := 0.3 * (1.0 - 0.55 * pow(maxf(0.0, -sin(angle)), 0.6))
				var point := Vector2(0.5 + cos(angle) * r, 0.62 + sin(angle) * r * 1.1)
				if sin(angle) < 0.0:
					point.y -= pow(-sin(angle), 3.0) * 0.36
				flame.append(point)
			_polygon(buf, s, flame, tint)
			_ellipse(buf, s, Vector2(0.79, 0.62), Vector2(0.09, 0.15), tint)
		PowerupKinds.SCATTER_FETCH:
			# Three balls fanning out.
			_ellipse(buf, s, Vector2(0.5, 0.28), Vector2(0.15, 0.15), tint)
			_ellipse(buf, s, Vector2(0.24, 0.62), Vector2(0.15, 0.15), tint)
			_ellipse(buf, s, Vector2(0.76, 0.62), Vector2(0.15, 0.15), tint)
			_polygon(buf, s, PackedVector2Array([Vector2(0.44, 0.92), Vector2(0.56, 0.92), Vector2(0.53, 0.5), Vector2(0.47, 0.5)]), tint)
		PowerupKinds.HERE_BOY:
			# A zap: dots trailing up to a bold arrow - from here to there in a blink.
			for i in 3:
				_ellipse(buf, s, Vector2(0.1 + i * 0.1, 0.9 - i * 0.1), Vector2(0.045 + i * 0.01, 0.045 + i * 0.01), tint)
			var from := Vector2(0.4, 0.62)
			var to := Vector2(0.7, 0.32)
			var side := (to - from).orthogonal().normalized() * 0.075
			_polygon(buf, s, PackedVector2Array([from + side, to + side, to - side, from - side]), tint)
			_polygon(buf, s, PackedVector2Array([Vector2(0.92, 0.1), Vector2(0.9, 0.5), Vector2(0.52, 0.12)]), tint)
		PowerupKinds.GOOD_DECOY:
			# A dog head and its ghost: two overlapping heads with ears.
			for offset in [Vector2(-0.12, 0.06), Vector2(0.12, -0.02)]:
				_ellipse(buf, s, Vector2(0.5, 0.56) + offset, Vector2(0.24, 0.22), tint)
				_ellipse(buf, s, Vector2(0.33, 0.36) + offset, Vector2(0.08, 0.14), tint)
				_ellipse(buf, s, Vector2(0.67, 0.36) + offset, Vector2(0.08, 0.14), tint)
		_:
			_question(buf, s, tint)


# ---------------------------------------------------------------- shapes

## A heater shield: flat top, straight sides, curving in to a point at the foot.
static func _shield(buf: PackedByteArray, s: int, tint: Color) -> void:
	var points := PackedVector2Array([Vector2(0.16, 0.12), Vector2(0.5, 0.06), Vector2(0.84, 0.12), Vector2(0.84, 0.46)])
	for i in 9:
		var t := float(i + 1) / 10.0
		points.append(Vector2(0.84, 0.46).lerp(Vector2(0.5, 0.94), t) + Vector2(sin(t * PI) * 0.06, 0.0))
	points.append(Vector2(0.5, 0.94))
	for i in 9:
		var t := float(i + 1) / 10.0
		points.append(Vector2(0.5, 0.94).lerp(Vector2(0.16, 0.46), t) + Vector2(-sin(t * PI) * 0.06, 0.0))
	points.append(Vector2(0.16, 0.46))
	_polygon(buf, s, points, tint)


## A throw bending round a corner: a thick arc ending in an arrowhead.
static func _curve_arrow(buf: PackedByteArray, s: int, tint: Color) -> void:
	var centre := Vector2(0.46, 0.58)
	var points := PackedVector2Array()
	var from := PI * 0.95
	var to := PI * 2.05
	for i in 17:
		var angle := lerpf(from, to, i / 16.0)
		points.append(centre + Vector2(cos(angle), sin(angle)) * 0.36)
	for i in 17:
		var angle := lerpf(to, from, i / 16.0)
		points.append(centre + Vector2(cos(angle), sin(angle)) * 0.22)
	_polygon(buf, s, points, tint)
	var tip := centre + Vector2(cos(to), sin(to)) * 0.29
	_polygon(buf, s, PackedVector2Array([tip + Vector2(-0.17, -0.02), tip + Vector2(0.17, -0.02), tip + Vector2(0.0, 0.24)]), tint)


## A sheet-ghost with floppy dog ears and two empty eyes.
static func _ghost(buf: PackedByteArray, s: int, tint: Color) -> void:
	_ellipse(buf, s, Vector2(0.5, 0.44), Vector2(0.30, 0.30), tint)
	_polygon(buf, s, PackedVector2Array([Vector2(0.2, 0.44), Vector2(0.8, 0.44), Vector2(0.8, 0.82), Vector2(0.2, 0.82)]), tint)
	for x: float in [0.3, 0.5, 0.7]:
		_ellipse(buf, s, Vector2(x, 0.83), Vector2(0.1, 0.09), tint)
	_ellipse(buf, s, Vector2(0.2, 0.36), Vector2(0.09, 0.19), tint)
	_ellipse(buf, s, Vector2(0.8, 0.36), Vector2(0.09, 0.19), tint)
	_ellipse(buf, s, Vector2(0.4, 0.44), Vector2(0.06, 0.08), Color(0, 0, 0, 0), true)
	_ellipse(buf, s, Vector2(0.6, 0.44), Vector2(0.06, 0.08), Color(0, 0, 0, 0), true)


## A spade stuck in a molehill.
static func _shovel(buf: PackedByteArray, s: int, tint: Color) -> void:
	_polygon(buf, s, PackedVector2Array([Vector2(0.66, 0.08), Vector2(0.76, 0.12), Vector2(0.56, 0.56), Vector2(0.46, 0.52)]), tint)
	_polygon(buf, s, PackedVector2Array([Vector2(0.58, 0.06), Vector2(0.86, 0.18), Vector2(0.82, 0.25), Vector2(0.55, 0.13)]), tint)
	_polygon(buf, s, PackedVector2Array([Vector2(0.38, 0.46), Vector2(0.64, 0.58), Vector2(0.50, 0.80), Vector2(0.30, 0.72)]), tint)
	_ellipse(buf, s, Vector2(0.5, 0.95), Vector2(0.42, 0.16), tint)


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


static func _question(buf: PackedByteArray, s: int, tint: Color) -> void:
	# An open hook, not a ring on a stick (which reads as a key).
	var hook := PackedVector2Array()
	for i in 25:
		var angle := lerpf(PI, -PI * 0.5, i / 24.0)
		hook.append(Vector2(0.5 + cos(angle) * 0.28, 0.34 + sin(angle) * 0.25))
	for i in 25:
		var angle := lerpf(-PI * 0.5, PI, i / 24.0)
		hook.append(Vector2(0.5 + cos(angle) * 0.12, 0.34 + sin(angle) * 0.10))
	# The hook goes clockwise over the top, round the right and into the stem.
	for i in hook.size():
		hook[i].y = 0.68 - hook[i].y
	_polygon(buf, s, hook, tint)
	_polygon(buf, s, PackedVector2Array([
		Vector2(0.43, 0.51), Vector2(0.58, 0.46), Vector2(0.58, 0.70), Vector2(0.43, 0.70)]), tint)
	_ellipse(buf, s, Vector2(0.505, 0.86), Vector2(0.087, 0.087), tint)


# ---------------------------------------------------------------- primitives

static func _put(buf: PackedByteArray, s: int, x: int, y: int, tint: Color) -> void:
	if x < 0 or y < 0 or x >= s or y >= s:
		return
	var i := (y * s + x) * 4
	buf[i] = int(clampf(tint.r, 0.0, 1.0) * 255.0)
	buf[i + 1] = int(clampf(tint.g, 0.0, 1.0) * 255.0)
	buf[i + 2] = int(clampf(tint.b, 0.0, 1.0) * 255.0)
	buf[i + 3] = 255


## [param erase] punches a hole instead of painting (a ghost's eyes).
static func _ellipse(buf: PackedByteArray, s: int, centre: Vector2, radii: Vector2, tint: Color, erase: bool = false) -> void:
	var c := centre * float(s)
	var r := radii * float(s)
	for y in range(maxi(0, int(c.y - r.y) - 1), mini(s, int(c.y + r.y) + 2)):
		for x in range(maxi(0, int(c.x - r.x) - 1), mini(s, int(c.x + r.x) + 2)):
			var dx := (float(x) + 0.5 - c.x) / maxf(r.x, 0.0001)
			var dy := (float(y) + 0.5 - c.y) / maxf(r.y, 0.0001)
			if dx * dx + dy * dy <= 1.0:
				if erase:
					buf[(y * s + x) * 4 + 3] = 0
				else:
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
