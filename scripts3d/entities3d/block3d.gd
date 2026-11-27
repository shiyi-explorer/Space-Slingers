class_name SSBlock3D
extends RigidBody3D

## 3D 方块：分段砌块 + 深色砖缝 + 边缘高光，碰撞体尺寸不变。
## 视觉沿"长边"分段：立柱沿 Y、横板沿 X，保证任意尺寸都有砖纹立体感。

signal destroyed(score_value: int, at_position: Vector3)

const MATERIALS := {
	"wood": {"hp": 2, "threshold": 430.0, "score": 500, "mass": 1.2, "color": Color("d18a4d"), "edge": Color("f4ddaf"), "emission": 0.10},
	"stone": {"hp": 3, "threshold": 600.0, "score": 800, "mass": 3.0, "color": Color("8a97ab"), "edge": Color("dcecff"), "emission": 0.06},
	"glass": {"hp": 1, "threshold": 240.0, "score": 300, "mass": 0.7, "color": Color("70d5e8"), "edge": Color("e8fbff"), "emission": 0.22},
}

var material_kind := "wood"
var hp := 2
var damage_threshold := 430.0
var score_value := 500
var block_color: Color
var edge_color: Color
var rect_size := Vector2(20, 78)
var flash := 0.0
var spawn_grace := 0.4
var flash_mesh: MeshInstance3D
var visual_parts: Array[MeshInstance3D] = []
var base_emissions: Array[float] = []

func setup(data: Dictionary) -> void:
	material_kind = data["material"]
	rect_size = data["size"]
	var material: Dictionary = MATERIALS[material_kind]
	hp = material["hp"]
	damage_threshold = material["threshold"]
	score_value = material["score"]
	block_color = material["color"]
	edge_color = material["edge"]
	position = data["position"]
	# 姿态贴行星法线（真三维：任意纬度）：把本地 Y 从世界 UP 旋转到法线方向
	transform = Transform3D(SSPlace3D.normal_basis(data["normal"]), data["position"])

func _ready() -> void:
	gravity_scale = 0.0
	mass = MATERIALS[material_kind]["mass"]
	linear_damp = 0.6
	angular_damp = 1.0
	contact_monitor = true
	max_contacts_reported = 6

	# 碰撞体：薄盒（XZ 平面中的"矩形"，Y 留 3D 视觉厚度）——尺寸不变
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(rect_size.x, rect_size.y, 18.0)
	collision.shape = shape
	add_child(collision)
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 1.0
	physics_material.bounce = 0.1
	physics_material_override = physics_material
	body_shape_entered.connect(_on_body_shape_entered)

	_build_visual()

func _build_visual() -> void:
	var material: Dictionary = MATERIALS[material_kind]
	var long_axis_x: bool = rect_size.x >= rect_size.y
	var long_len: float = maxf(rect_size.x, rect_size.y)
	var short_len: float = minf(rect_size.x, rect_size.y)
	var seg_count: int = clampi(int(long_len / 24.0), 1, 6)
	var seg_len: float = long_len / float(seg_count)
	var gap: float = minf(2.2, seg_len * 0.10)
	var is_glass: bool = material_kind == "glass"

	# 深色底芯：砖缝填充，让分段之间的缝隙有真实深度
	_add_part(
		Vector3(rect_size.x * 0.96, rect_size.y * 0.98, 16.4),
		Vector3.ZERO,
		block_color.darkened(0.55),
		material["emission"] * 0.4,
		is_glass)

	# 分段砌块：每段亮度微差，形成砖纹
	for i in seg_count:
		var tint: float = 0.90 + 0.18 * (0.5 + 0.5 * sin(float(i) * 2.31 + rect_size.x))
		var brick_color: Color = block_color * tint
		var brick_size: Vector3
		var brick_pos: Vector3
		var along: float = -long_len * 0.5 + seg_len * (float(i) + 0.5)
		if long_axis_x:
			brick_size = Vector3(seg_len - gap, short_len * 0.94, 16.8)
			brick_pos = Vector3(along, 0.0, 0.0)
		else:
			brick_size = Vector3(short_len * 0.94, seg_len - gap, 16.8)
			brick_pos = Vector3(0.0, along, 0.0)
		_add_part(brick_size, brick_pos, brick_color, material["emission"], is_glass)

	# 四条长边高光：勾出立体轮廓，避免看起来像平面色块
	var z_edge: float = 8.4
	var s_edge: float = short_len * 0.5 - 0.6
	for sz in [-1.0, 1.0]:
		for ss in [-1.0, 1.0]:
			var edge_size: Vector3
			var edge_pos: Vector3
			if long_axis_x:
				edge_size = Vector3(long_len - 2.0, 1.6, 1.6)
				edge_pos = Vector3(0.0, ss * s_edge, sz * z_edge)
			else:
				edge_size = Vector3(1.6, long_len - 2.0, 1.6)
				edge_pos = Vector3(ss * s_edge, 0.0, sz * z_edge)
			_add_part(edge_size, edge_pos, edge_color, 0.35, false)

	# 两端端盖：金属箍质感，明确"柱子"的起止
	var cap_size: Vector3
	if long_axis_x:
		cap_size = Vector3(2.6, short_len + 2.0, 19.0)
	else:
		cap_size = Vector3(short_len + 2.0, 2.6, 19.0)
	for sign in [-1.0, 1.0]:
		var along: float = sign * (long_len * 0.5 - 1.2)
		var cap_pos: Vector3 = Vector3(along, 0.0, 0.0) if long_axis_x else Vector3(0.0, along, 0.0)
		_add_part(cap_size, cap_pos, edge_color, 0.28, false)

func _add_part(size: Vector3, pos: Vector3, color: Color, emission: float, transparent: bool) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = pos
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.emission_enabled = true
	surface.emission = color
	surface.emission_energy_multiplier = emission
	if transparent:
		surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		surface.albedo_color.a = 0.78
		surface.metallic = 0.1
		surface.roughness = 0.25
	add_child(node)
	visual_parts.append(node)
	base_emissions.append(emission)
	if flash_mesh == null:
		flash_mesh = node

func _set_flash(value: float) -> void:
	for i in visual_parts.size():
		var surface := visual_parts[i].material_override as StandardMaterial3D
		if surface != null:
			surface.emission_energy_multiplier = base_emissions[i] + value * 0.6

func _on_body_shape_entered(_body_rid: RID, body: Node, _body_shape: int, _local_shape: int) -> void:
	if hp <= 0 or spawn_grace > 0.0:
		return
	if SSImpact3D.magnitude(self, body) >= damage_threshold:
		take_damage()

func take_damage() -> void:
	hp -= 1
	flash = 1.0
	_set_flash(flash)
	if hp <= 0:
		destroyed.emit(score_value, global_position)
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
		tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	spawn_grace = maxf(spawn_grace - delta, 0.0)
	if flash > 0.0:
		flash = maxf(flash - delta * 4.0, 0.0)
		_set_flash(flash)
