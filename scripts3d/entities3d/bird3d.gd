class_name SSBird3D
extends RigidBody3D

## 3D 小鸟：红球 + 眼睛 + 怒眉 + 尾羽。XZ 平面飞行（Y 恒 0），
## 引力由 planet area 检测 + SSGravity 施加（真空无阻尼，与预览同构）。

signal spent

enum BirdState {LOADED, FLYING, DEAD}

## 小鸟种类：normal 红色普通 / split 蓝色分裂（飞行中点击一分为三）/ dash 黄色加速（点击冲刺）
var bird_kind := "normal"
var special_used := false

const KIND_COLORS := {
	"normal": Color("d9403f"),
	"split": Color("3f8fd9"),
	"dash": Color("f3b23a"),
}

var bird_state: int = BirdState.LOADED
var still_frames := 0
var life_time := 0.0
const PLAY_Y := 0.0

func can_special() -> bool:
	return bird_state == BirdState.FLYING and not special_used and bird_kind != "normal"

func dash() -> void:
	linear_velocity = (linear_velocity * 1.75).limit_length(SSConfig.MAX_FLIGHT_SPEED)

func _ready() -> void:
	gravity_scale = 0.0
	mass = 1.0
	linear_damp = 0.0
	angular_damp = 0.0
	freeze = true
	freeze_mode = FREEZE_MODE_STATIC
	contact_monitor = true
	max_contacts_reported = 6
	axis_lock_angular_x = true
	axis_lock_angular_z = true

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = SSConfig.BIRD_RADIUS
	collision.shape = shape
	add_child(collision)
	var material := PhysicsMaterial.new()
	material.bounce = 0.35
	material.friction = 0.6
	physics_material_override = material

	# 身体（颜色随种类：红=普通 蓝=分裂 黄=加速）
	var body_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = SSConfig.BIRD_RADIUS
	sphere.height = SSConfig.BIRD_RADIUS * 2.0
	body_mesh.mesh = sphere
	var body_color: Color = SSConfig.COLOR_BIRD_KINDS.get(bird_kind, Color("d9403f"))
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = body_color
	body_material.emission_enabled = true
	body_material.emission = body_color
	body_material.emission_energy_multiplier = 0.15
	body_mesh.material_override = body_material
	add_child(body_mesh)

	# 眼睛（朝 +X 飞行）
	for eye_x in [-4.0, 4.0]:
		var eye := MeshInstance3D.new()
		var eye_sphere := SphereMesh.new()
		eye_sphere.radius = 4.2
		eye_sphere.height = 8.4
		eye.mesh = eye_sphere
		eye.position = Vector3(eye_x, 4.0, SSConfig.BIRD_RADIUS * 0.78)
		var white := StandardMaterial3D.new()
		white.albedo_color = Color.WHITE
		eye.material_override = white
		add_child(eye)

	# 尾羽（-X 方向）
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(10, 3, 6)
	tail.mesh = tail_mesh
	tail.position = Vector3(-SSConfig.BIRD_RADIUS - 4.0, 0, 0)
	var tail_material := StandardMaterial3D.new()
	tail_material.albedo_color = body_color.darkened(0.35)
	tail_material.emission_enabled = true
	tail_material.emission = body_color
	tail_material.emission_energy_multiplier = 0.1
	tail.material_override = tail_material
	add_child(tail)

func launch(velocity3d: Vector3) -> void:
	if bird_state != BirdState.LOADED:
		return
	bird_state = BirdState.FLYING
	freeze = false
	linear_velocity = velocity3d

func _physics_process(delta: float) -> void:
	if bird_state != BirdState.FLYING:
		return
	life_time += delta
	if linear_velocity.length() < SSConfig.BIRD_SETTLE_SPEED:
		still_frames += 1
	else:
		still_frames = 0
	if still_frames >= SSConfig.BIRD_SETTLE_FRAMES or life_time >= SSConfig.BIRD_MAX_LIFE:
		_poof()

func poof() -> void:
	_poof()

func _poof() -> void:
	if bird_state == BirdState.DEAD:
		return
	bird_state = BirdState.DEAD
	spent.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.25)
	tween.tween_callback(queue_free)
