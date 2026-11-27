class_name SSDebrisBurst2D
extends Node2D

## 2D 碎片爆散：一簇小刚体方块向外飞散自旋，短暂存活后缩小消散并自毁。
## 碎片不在行星 Area2D 白名单外也能吃到引力（运行时施力遍历所有重叠刚体）。

var color := Color.WHITE
var count := 8
var spread := 200.0
var size := 7.0

func setup(p_color: Color, p_count: int, p_spread: float, p_size: float) -> void:
	color = p_color
	count = p_count
	spread = p_spread
	size = p_size

func _ready() -> void:
	var visuals: Array[Node2D] = []
	for i in count:
		var piece := RigidBody2D.new()
		piece.gravity_scale = 0.0
		piece.mass = 0.2
		piece.linear_damp = 2.2
		piece.angular_damp = 1.5
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = size * 0.5
		collision.shape = shape
		piece.add_child(collision)
		var poly := Polygon2D.new()
		var half: float = size * randf_range(0.4, 1.0)
		poly.polygon = PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half),
			Vector2(half, half), Vector2(-half, half)])
		poly.color = color
		piece.add_child(poly)
		add_child(piece)
		piece.global_position = global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		var direction := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		piece.linear_velocity = direction * randf_range(spread * 0.4, spread)
		piece.angular_velocity = randf_range(-9.0, 9.0)
		visuals.append(poly)
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_callback(func() -> void:
		for visual in visuals:
			var shrink := create_tween()
			shrink.tween_property(visual, "scale", Vector2.ONE * 0.05, 0.55))
	tween.tween_interval(0.65)
	tween.tween_callback(queue_free)
