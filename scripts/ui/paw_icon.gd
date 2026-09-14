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


## Rasterises a paw into an ImageTexture (for Button.icon).
static func texture(px: int = 40, col: Color = Color.WHITE) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var s := float(px)
	var c := Vector2(s / 2.0, s / 2.0)
	var blobs: Array = [[c + Vector2(0, s * 0.18), Vector2(s * 0.3, s * 0.25)]]
	for p in [Vector2(-0.34, -0.12), Vector2(-0.12, -0.34), Vector2(0.12, -0.34), Vector2(0.34, -0.12)]:
		blobs.append([c + p * s, Vector2(s * 0.13, s * 0.13)])
	for y in px:
		for x in px:
			var q := Vector2(x + 0.5, y + 0.5)
			var a := 0.0
			for b in blobs:
				var d: Vector2 = (q - b[0]) / b[1]
				var r := d.length()
				a = maxf(a, clampf((1.0 - r) * b[1].x * 0.9, 0.0, 1.0))
			if a > 0.0:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)
