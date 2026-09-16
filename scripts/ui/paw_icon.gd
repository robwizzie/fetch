class_name PawIcon
extends Control
## A paw print, drawn (for UI) or rasterised to a texture (for button icons).

@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(size.x / 2.0, size.y / 2.0)
	_draw_paw(self, c, s, color)


static func _draw_paw(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_set_transform(c + Vector2(0, s * 0.18), 0.0, Vector2(1.0, 0.82))
	ci.draw_circle(Vector2.ZERO, s * 0.3, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in [Vector2(-0.34, -0.12), Vector2(-0.12, -0.34), Vector2(0.12, -0.34), Vector2(0.34, -0.12)]:
		ci.draw_circle(c + p * s, s * 0.13, col)


## Rasterises a paw into an ImageTexture (for Button.icon). Drawn at 4x and filtered down,
## so the edges stay smooth instead of showing the stair-stepping of a direct rasterisation.
static func texture(px: int = 48, col: Color = Color.WHITE) -> ImageTexture:
	var super_sample := 4
	var big := px * super_sample
	var image := Image.create(big, big, false, Image.FORMAT_RGBA8)
	image.fill(Color(col.r, col.g, col.b, 0.0))
	var s := float(big)
	var centre := Vector2(s * 0.5, s * 0.5)
	# Each pad is an ellipse in its own rotated frame: offset, radii, rotation.
	var pads: Array = [
		[Vector2(0.0, 0.20), Vector2(0.33, 0.27), 0.0],
		[Vector2(-0.345, -0.055), Vector2(0.135, 0.175), -0.62],
		[Vector2(-0.135, -0.30), Vector2(0.135, 0.180), -0.20],
		[Vector2(0.135, -0.30), Vector2(0.135, 0.180), 0.20],
		[Vector2(0.345, -0.055), Vector2(0.135, 0.175), 0.62],
	]
	for y in big:
		for x in big:
			var point := Vector2(x + 0.5, y + 0.5)
			var alpha := 0.0
			for pad in pads:
				var offset: Vector2 = pad[0]
				var radii: Vector2 = pad[1]
				var spin: float = pad[2]
				var local := (point - (centre + offset * s)).rotated(-spin) / (radii * s)
				# A short soft band at the rim; the 4x downsample does the rest.
				alpha = maxf(alpha, smoothstep(1.0, 0.88, local.length()))
			if alpha > 0.0:
				image.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * alpha))
	image.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)
