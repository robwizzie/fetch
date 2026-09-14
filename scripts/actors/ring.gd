extends Node2D
## Player-colour ring under a dog so everyone can tell who is who at a glance.

@export var radius := 30.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.05
	draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 4.0, true)
