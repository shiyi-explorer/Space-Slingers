class_name SSPopup
extends Node2D

## 世界坐标内的分数飘字：上升淡出后自毁。

var popup_text := ""
var popup_color := Color.WHITE
var life := 0.0

func setup(text: String, world_position: Vector2, color: Color) -> void:
	popup_text = text
	popup_color = color
	position = world_position
	z_index = 50

func _process(delta: float) -> void:
	life += delta
	position.y -= delta * 46.0
	queue_redraw()
	if life >= 1.2:
		queue_free()

func _draw() -> void:
	var alpha: float = clampf(1.0 - life / 1.2, 0.0, 1.0)
	var font := SSOrbitTheme.COMIC_FONT
	draw_string(font, Vector2(-40, -20), popup_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 24,
		Color(0, 0, 0, alpha * 0.6))
	draw_string(font, Vector2(-42, -22), popup_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 24,
		Color(popup_color.r, popup_color.g, popup_color.b, alpha))
