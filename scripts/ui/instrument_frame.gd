extends Control

## 装饰盖板独立于按钮和面板的输入区域。
var accent := Color("e3aa68")
var compact := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	var bounds := size
	if bounds.x < 75.0 or bounds.y < 27.0:
		return
	var inset := 4.0 if compact else 7.0
	var wing := 9.0 if compact else 19.0
	var chamfer := 4.0 if compact else 7.0
	var line_color := Color(accent, 0.84 if compact else 0.92)
	var faint := Color(accent, 0.22)
	var corner := PackedVector2Array([
		Vector2(inset, inset + wing), Vector2(inset, inset + chamfer),
		Vector2(inset + chamfer, inset), Vector2(inset + wing, inset),
	])
	for side in [Vector2.ONE, Vector2(-1, 1), Vector2(1, -1), -Vector2.ONE]:
		var origin := Vector2(0.0 if side.x > 0.0 else bounds.x, 0.0 if side.y > 0.0 else bounds.y)
		var points := PackedVector2Array()
		for point in corner:
			points.append(origin + point * side)
		draw_polyline(points, line_color, 1.4, true)
	if not compact:
		var center := bounds.x * 0.5
		var rail := PackedVector2Array([Vector2(center - 43, 0), Vector2(center - 34, 7),
			Vector2(center + 34, 7), Vector2(center + 43, 0)])
		draw_polyline(rail, line_color, 1.6, true)
		draw_line(Vector2(28, bounds.y - 6), Vector2(bounds.x - 28, bounds.y - 6), faint, 1.0, true)
		for i in range(-1, 2):
			var light := Vector2(center + i * 8.0, 4.0)
			draw_circle(light, 1.35, Color("8beacf"), true, -1.0, true)
