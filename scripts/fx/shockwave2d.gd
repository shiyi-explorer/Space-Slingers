class_name SSShockwave2D
extends Node2D

## 2D 冲击波环：从撞击点扩散的发光圆环，放大淡出后自毁。

var ring_color := Color.WHITE
var scale_factor := 1.0
var radius := 12.0
var alpha := 0.9

func setup(p_color: Color, p_scale: float) -> void:
	ring_color = p_color
	scale_factor = p_scale

func _process(delta: float) -> void:
	radius = move_toward(radius, 110.0 * scale_factor, delta * 320.0 * scale_factor)
	alpha = maxf(alpha - delta * 2.2, 0.0)
	queue_redraw()
	if alpha <= 0.01:
		queue_free()

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48,
		Color(ring_color.r, ring_color.g, ring_color.b, alpha), 5.0, false)
