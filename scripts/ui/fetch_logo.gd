class_name FetchLogo
extends Control
## The FETCH wordmark from the key art: chunky white brush letters with a dark outline and drop
## shadow, each letter tilted and gently bobbing, a paw print tucked into the C and a tennis ball
## streaking off the top-right.

const TEXT := "FETCH"
const TILTS := [-7.0, 4.0, -3.0, 5.0, -5.0]
const LIFTS := [0.0, -0.06, 0.03, -0.05, 0.02]
const FILL := Color(0.99, 0.97, 0.92)
const INK := Color(0.09, 0.08, 0.14)

var letter_size := 150
var _letters: Array[Label] = []
var _shadows: Array[Label] = []
var _paw: PawIcon
var _ball: Control
var _base_pos: Array[Vector2] = []


func build(p_size: int) -> void:
	letter_size = p_size
	for c in get_children():
		c.queue_free()
	_letters.clear()
	_shadows.clear()
	_base_pos.clear()
	var font: Font = UiKit.FONT_DISPLAY
	var x := 0.0
	var h := float(letter_size) * 1.05
	var paw_center := Vector2.ZERO
	for i in TEXT.length():
		var ch := TEXT[i]
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
		var lift: float = LIFTS[i]
		var pos := Vector2(x, lift * letter_size)
		var shadow := _make_letter(ch, INK, INK)
		shadow.position = pos + Vector2(letter_size * 0.05, letter_size * 0.07)
		shadow.size = Vector2(w, h)
		shadow.pivot_offset = shadow.size / 2.0
		shadow.rotation_degrees = float(TILTS[i])
		add_child(shadow)
		_shadows.append(shadow)
		var l := _make_letter(ch, FILL, INK)
		l.position = pos
		l.size = Vector2(w, h)
		l.pivot_offset = l.size / 2.0
		l.rotation_degrees = float(TILTS[i])
		add_child(l)
		_letters.append(l)
		_base_pos.append(pos)
		if ch == "C":
			paw_center = pos + Vector2(w * 0.62, h * 0.54)
		x += w - letter_size * 0.04
	custom_minimum_size = Vector2(x + letter_size * 0.3, h * 1.1)
	size = custom_minimum_size

	_paw = PawIcon.new()
	_paw.color = INK
	_paw.size = Vector2.ONE * letter_size * 0.36
	_paw.position = paw_center - _paw.size / 2.0
	_paw.rotation_degrees = 12.0
	_paw.pivot_offset = _paw.size / 2.0
	add_child(_paw)

	_ball = BallStreak.new()
	_ball.size = Vector2(letter_size * 1.1, letter_size * 0.7)
	_ball.position = Vector2(x - letter_size * 0.75, -letter_size * 0.42)
	add_child(_ball)


func _make_letter(ch: String, fill: Color, ink: Color) -> Label:
	var l := Label.new()
	l.text = ch
	l.add_theme_font_override("font", UiKit.FONT_DISPLAY)
	l.add_theme_font_size_override("font_size", letter_size)
	l.add_theme_color_override("font_color", fill)
	l.add_theme_color_override("font_outline_color", ink)
	l.add_theme_constant_override("outline_size", int(letter_size * 0.13))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _letters.size():
		var bob := sin(t * 2.4 + i * 0.9) * letter_size * 0.02
		var tilt: float = TILTS[i] + sin(t * 1.6 + i) * 1.2
		_letters[i].position.y = _base_pos[i].y + bob
		_letters[i].rotation_degrees = tilt
		_shadows[i].position.y = _base_pos[i].y + bob + letter_size * 0.07
		_shadows[i].rotation_degrees = tilt
	if _paw:
		_paw.rotation_degrees = 12.0 + sin(t * 2.0) * 3.0


## Tennis ball with a motion streak, drawn in code.
class BallStreak extends Control:
	const BALL := Color(0.86, 0.96, 0.32)
	const STREAK := Color(0.75, 0.95, 0.35)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := size.y * 0.3
		var t := Time.get_ticks_msec() * 0.001
		var c := Vector2(size.x - r * 1.2, r * 1.3 + sin(t * 3.0) * r * 0.15)
		# streak: fading tapered arc behind the ball
		var segs := 14
		for i in segs:
			var f0 := float(i) / segs
			var f1 := float(i + 1) / segs
			var a0 := PI * 0.95 + f0 * PI * 0.55
			var a1 := PI * 0.95 + f1 * PI * 0.55
			var rad := r * 3.2
			var p0 := c + Vector2(cos(a0), sin(a0)) * rad + Vector2(rad * 0.9, rad * 0.35)
			var p1 := c + Vector2(cos(a1), sin(a1)) * rad + Vector2(rad * 0.9, rad * 0.35)
			draw_line(p0, p1, Color(STREAK, f1 * 0.9), r * 0.55 * f1 + 1.0, true)
		draw_circle(c, r + size.y * 0.04, FetchLogo.INK)
		draw_circle(c, r, BALL)
		draw_arc(c + Vector2(-r * 0.95, 0), r * 0.9, -0.95, 0.95, 14, Color.WHITE, r * 0.14, true)
		draw_arc(c + Vector2(r * 0.95, 0), r * 0.9, PI - 0.95, PI + 0.95, 14, Color.WHITE, r * 0.14, true)
