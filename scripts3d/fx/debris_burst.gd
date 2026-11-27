class_name SSDebrisBurst
extends Node3D

## 碎片爆散：一簇小刚体碎块向外飞散、自旋，短暂存活后缩小消散并自毁。
## 碎片不进引力注册表（一次性道具），靠阻尼自然减速。

var color := Color.WHITE
var count := 8
var spread := 220.0
var size := 3.2

func setup(p_color: Color, p_count: int, p_spread: float, p_size: float) -> void:
	color = p_color
	count = p_count
	spread = p_spread
	size = p_size

func _ready() -> void:
	var meshes: Array[MeshInstance3D] = []
	for i in count:
		var piece := RigidBody3D.new()
		piece.gravity_scale = 0.0
		piece.mass = 0.2
		piece.linear_damp = 2.2
		piece.angular_damp = 1.5
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = size * 0.5
		collision.shape = shape
		piece.add_child(collision)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * size * randf_range(0.5, 1.1)
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.45
		mesh.material_override = material
		piece.add_child(mesh)
		add_child(piece)
		piece.global_position = global_position + Vector3(
			randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
		var direction := Vector3(
			randf_range(-1, 1), randf_range(-0.4, 0.4), randf_range(-1, 1)).normalized()
		piece.linear_velocity = direction * randf_range(spread * 0.4, spread)
		piece.angular_velocity = Vector3(
			randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		meshes.append(mesh)
	# 存活 0.9 秒后碎片缩小消散，1.6 秒整体自毁
	var tween := create_tween()
	tween.tween_interval(0.9)
	tween.tween_callback(func() -> void:
		for mesh in meshes:
			var shrink := create_tween()
			shrink.tween_property(mesh, "scale", Vector3.ONE * 0.05, 0.55)
			)
	tween.tween_interval(0.65)
	tween.tween_callback(queue_free)
