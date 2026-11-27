class_name SSSling
extends Node2D

## 弹弓：Y 形叉架 + 皮筋。pouch 以世界坐标传入，绘制时转为本地。

const FORK_HEIGHT := 46.0
const TIP_LEFT := Vector2(-10, -FORK_HEIGHT)
const TIP_RIGHT := Vector2(10, -FORK_HEIGHT)

var industrial_art := false
var anchor: Vector2
var pouch: Variant = null  # null = 松弛；Vector2 = 世界坐标皮兜位

func setup(base_position: Vector2) -> void:
	position = base_position
	anchor = Vector2(0, -FORK_HEIGHT)

func set_pouch(world_pouch: Variant) -> void:
	pouch = world_pouch
	queue_redraw()

func _draw() -> void:
	if industrial_art:
		_draw_industrial_mount()
	else:
		# Y 形叉架：主干 + 两条向上张开的叉臂
		draw_line(Vector2(0, 12), Vector2(0, -16), Color("8a4f2a"), 9.0)
		draw_line(Vector2(0, -16), TIP_LEFT, Color("c58142"), 7.0)
		draw_line(Vector2(0, -16), TIP_RIGHT, Color("c58142"), 7.0)
		# 握把装饰
		draw_line(Vector2(0, 12), Vector2(0, 4), Color("6e3d1f"), 11.0)
	# 皮筋：世界坐标 → 本地
	var pouch_point: Vector2
	if pouch is Vector2:
		pouch_point = to_local(pouch)
	else:
		pouch_point = Vector2(0, -FORK_HEIGHT + 12)  # 松弛下垂
	draw_line(TIP_LEFT, pouch_point, Color("f1bd59"), 5.0)
	draw_line(TIP_RIGHT, pouch_point, Color("d9a347"), 5.0)
	# 皮兜
	draw_circle(pouch_point, 4.0, Color("8a4f2a"))

func _draw_industrial_mount() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-26, 2), Vector2(-17, -12),
		Vector2(15, -12), Vector2(26, 2), Vector2(20, 8), Vector2(-20, 8)]), Color("3c445a"))
	draw_line(Vector2(-16, -11), Vector2(15, -11), Color("a5b8ba"), 2.0, true)
	var hinge := Vector2(0, -15)
	draw_line(Vector2(0, 1), hinge, Color("172233"), 18.0, true)
	draw_line(Vector2(0, 1), hinge, Color("bb673e"), 13.0, true)
	for tip in [TIP_LEFT, TIP_RIGHT]:
		var arm := PackedVector2Array([hinge, Vector2(tip.x * 1.28, -31), tip])
		draw_polyline(arm, Color("201d29"), 13.0, true)
		draw_polyline(arm, Color("cf7948"), 9.0, true)
		draw_circle(tip, 5.3, Color("f7ca76"), true, -1.0, true)
	draw_circle(hinge, 7.0, Color("363c53"), true, -1.0, true)
	draw_circle(hinge, 3.3, Color("8cf6db"), true, -1.0, true)
	for x in [-16.0, 16.0]:
		draw_circle(Vector2(x, -2), 2.4, Color("edb266"), true, -1.0, true)
