class_name PawIcon
extends Control
## A paw print, drawn (for UI) or rasterised to a texture (for button icons).
##
## The classic print: a broad main pad with three soft lobes along its heel, and four oval toes
## fanned in an arc above it, the outer two tipped outwards. Optionally ringed with a dark
## outline so it reads on wood and on photographs alike, and lit from above so it looks like a
## pad rather than a stamp.

@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()

## The pads, in units of the icon's size, centred on its middle: offset, radii, tilt.
const PADS: Array = [
	# Main pad: a broad top and three lobes along the heel.
	[Vector2(0.0, 0.14), Vector2(0.255, 0.165), 0.0],
	[Vector2(-0.15, 0.27), Vector2(0.125, 0.12), 0.0],
	[Vector2(0.0, 0.305), Vector2(0.13, 0.115), 0.0],
	[Vector2(0.15, 0.27), Vector2(0.125, 0.12), 0.0],
	# Toes, fanned.
	[Vector2(-0.355, -0.085), Vector2(0.105, 0.14), -0.5],
	[Vector2(-0.13, -0.3), Vector2(0.11, 0.15), -0.16],
	[Vector2(0.13, -0.3), Vector2(0.11, 0.15), 0.16],
	[Vector2(0.355, -0.085), Vector2(0.105, 0.14), 0.5],
]


func _draw() -> void:
	var s := minf(size.x, size.y)
	_draw_paw(self, size * 0.5, s, color)


static func _draw_paw(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	for pad in PADS:
		ci.draw_colored_polygon(_ellipse(c + (pad[0] as Vector2) * s, (pad[1] as Vector2) * s, pad[2]), col)


static func _ellipse(centre: Vector2, radii: Vector2, tilt: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 28:
		var angle := TAU * float(i) / 28.0
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y).rotated(tilt))
	return points


## Rasterises a paw into an ImageTexture (for Button.icon). [param outline] is the dark ring's
## width as a share of the icon (0 for none). Drawn at 4x and filtered down, so the edges stay
## smooth instead of showing the stair-stepping of a direct rasterisation.
static func texture(px: int = 48, col: Color = Color.WHITE, outline_color: Color = Color(0, 0, 0, 0), outline: float = 0.0) -> ImageTexture:
	var super_sample := 4
	var big := px * super_sample
	var image := Image.create(big, big, false, Image.FORMAT_RGBA8)
	image.fill(Color(col.r, col.g, col.b, 0.0))
	var s := float(big)
	# Pads shrink a touch when outlined, so the ring fits inside the icon.
	var inset := 1.0 - outline * 1.6
	var centre := Vector2(s * 0.5, s * 0.5)
	var ring := outline * s
	var soft := s * 0.012
	for y in big:
		for x in big:
			var point := Vector2(x + 0.5, y + 0.5)
			# Approximate signed distance to the nearest pad, in pixels.
			var nearest := INF
			var shade := 0.0
			for pad in PADS:
				var radii: Vector2 = (pad[1] as Vector2) * s * inset
				var local := (point - (centre + (pad[0] as Vector2) * s * inset)).rotated(-float(pad[2]))
				var stretch := (local / radii).length()
				var distance := (stretch - 1.0) * minf(radii.x, radii.y)
				if distance < nearest:
					nearest = distance
					# Lit from above: the top of each pad is a shade lighter than its foot.
					shade = clampf(-local.y / radii.y, -1.0, 1.0)
			var fill := smoothstep(soft, -soft, nearest)
			var colour := col.lightened(0.18 * maxf(shade, 0.0)).darkened(0.1 * maxf(-shade, 0.0))
			if ring > 0.0 and outline_color.a > 0.0:
				var edge := smoothstep(ring + soft, ring - soft, nearest)
				if edge > 0.0:
					var mixed := outline_color.lerp(colour, fill)
					mixed.a = maxf(edge * outline_color.a, fill * col.a)
					image.set_pixel(x, y, mixed)
				continue
			if fill > 0.0:
				image.set_pixel(x, y, Color(colour, col.a * fill))
	image.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
