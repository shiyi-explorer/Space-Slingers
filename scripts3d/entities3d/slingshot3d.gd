class_name SSSling3D
extends Node3D

## 3D 弹弓：Y 形叉架 + 皮筋（圆柱段，轴向对齐线段方向）。
## pouch 以世界坐标传入；圆柱轴是本地 Y，用 Basis(axis, angle) 把 Y 转到线段方向。

const FORK_HEIGHT := 46.0

var anchor: Vector3
var pouch: Variant = null
var band_left: MeshInstance3D
var band_right: MeshInstance3D
var band_left_tip: Vector3
var band_right_tip: Vector3

func setup(base_position: Vector3) -> void:
	position = base_position
	anchor = Vector3(0, 0, -FORK_HEIGHT)
	_build()
	set_pouch(null)

func _build() -> void:
	# Y 形叉架：主干 + 两条叉臂
	_add_segment(Vector3(0, 0, 12), Vector3(0, 0, -16), 4.5, Color("6e3d1f"))
	_add_segment(Vector3(0, 0, -16), Vector3(-10, 0, -FORK_HEIGHT), 3.5, Color("c58142"))
	_add_segment(Vector3(0, 0, -16), Vector3(10, 0, -FORK_HEIGHT), 3.5, Color("c58142"))
	band_left_tip = Vector3(-10, 0, -FORK_HEIGHT)
	band_right_tip = Vector3(10, 0, -FORK_HEIGHT)
	band_left = _new_band()
	band_right = _new_band()

func _new_band() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.2
	mesh.bottom_radius = 2.2
	mesh.height = 1.0
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f1bd59")
	material.emission_enabled = true
	material.emission = Color("f1bd59")
	material.emission_energy_multiplier = 0.4
	node.material_override = material
	add_child(node)
	return node

func set_pouch(world_pouch: Variant) -> void:
	pouch = world_pouch
	var target: Vector3
	if pouch is Vector3:
		target = to_local(pouch)
	else:
		target = Vector3(0, 0, -FORK_HEIGHT + 12)  # 松弛下垂
	_update_band(band_left, band_left_tip, target)
	_update_band(band_right, band_right_tip, target)

func _update_band(node: MeshInstance3D, tip: Vector3, target: Vector3) -> void:
	var mesh := node.mesh as CylinderMesh
	mesh.height = maxf((target - tip).length(), 1.0)
	_align_segment(node, tip, target)

func _add_segment(from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = thickness
	mesh.bottom_radius = thickness
	mesh.height = (to - from).length()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	add_child(node)
	_align_segment(node, from, to)

## 圆柱网格的轴是本地 Y：把 UP 轴旋转到线段方向，圆柱即沿线段贴合
func _align_segment(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var segment := to - from
	var length := segment.length()
	if length < 0.001:
		return
	var dir := segment / length
	node.position = (from + to) * 0.5
	var axis := Vector3.UP.cross(dir)
	if axis.length_squared() < 0.0001:
		node.basis = Basis.IDENTITY if dir.y > 0.0 else Basis(Vector3.RIGHT, PI)
	else:
		node.basis = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(dir), -1.0, 1.0)))
