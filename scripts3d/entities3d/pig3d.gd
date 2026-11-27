class_name SSPig3D
extends RigidBody3D

## 3D 太空野猪：视觉模型与圆形碰撞体独立。

signal died(score_value: int, at_position: Vector3)

var pig_radius := 20.0
var pig_hp := 1
var flash := 0.0
var is_dead := false
var spawn_grace := 0.4
var appearance: Node3D

func setup(data: Dictionary) -> void:
	pig_radius = data["radius"]
	pig_hp = data["hp"]
	position = data["position"]
	_build_appearance()

func _ready() -> void:
	gravity_scale = 0.0
	mass = 1.5
	linear_damp = 0.6
	angular_damp = 1.0
	contact_monitor = true
	max_contacts_reported = 6

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = pig_radius
	collision.shape = shape
	add_child(collision)
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.9
	physics_material.bounce = 0.2
	physics_material_override = physics_material
	body_shape_entered.connect(_on_body_shape_entered)

	if appearance == null:
		_build_appearance()

func _build_appearance() -> void:
	if is_instance_valid(appearance):
		appearance.hide()
		appearance.queue_free()
	appearance = Node3D.new()
	appearance.name = "SalvagerAppearance"
	add_child(appearance)
	appearance.scale = Vector3.ONE * pig_radius
	var hide := _paint(Color("b884cf"))
	var snout := _paint(Color("f29e9e"))
	var suit := _paint(Color("313253"))
	var amber := _paint(Color("ffc66c"))
	var dark := _paint(Color("291d39"))
	_oval(Vector3(0, 0.04, 0), Vector3(0.86, 0.91, 0.81), hide)
	_oval(Vector3(0, -0.56, 0.02), Vector3(0.84, 0.40, 0.74), suit)
	for side: float in [-1.0, 1.0]:
		var ear := _oval(Vector3(side * 0.57, 0.70, -0.03), Vector3(0.23, 0.37, 0.16), hide)
		ear.rotation.z = -side * 0.35
		_oval(Vector3(side * 0.43, -0.77, 0.42), Vector3(0.25, 0.17, 0.26), suit)
		_oval(Vector3(side * 0.33, 0.24, 0.76), Vector3(0.15, 0.19, 0.07), amber)
		_oval(Vector3(side * 0.31, 0.23, 0.82), Vector3(0.058, 0.093, 0.035), dark)
	_oval(Vector3(0, -0.04, 0.82), Vector3(0.36, 0.24, 0.21), snout)
	for side: float in [-1.0, 1.0]:
		_oval(Vector3(side * 0.14, -0.01, 1.008), Vector3(0.064, 0.077, 0.031), dark)
	_oval(Vector3(0, -0.66, 0.70), Vector3(0.14, 0.065, 0.044), _paint(Color("8beacf")))

	if pig_hp >= 2:
		var glass := _paint(Color("89e6f62e"))
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.24
		_oval(Vector3(0, 0.18, 0), Vector3(1.03, 1.06, 1.06), glass)
		var collar := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.76
		ring.outer_radius = 0.91
		collar.mesh = ring
		collar.position.y = -0.44
		collar.material_override = amber
		appearance.add_child(collar)

func _paint(color: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.emission_enabled = true
	paint.emission = color
	paint.emission_energy_multiplier = 0.14
	paint.roughness = 0.78
	return paint

func _oval(at: Vector3, radii: Vector3, paint: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 20
	sphere.rings = 12
	sphere.radius = 1.0
	sphere.height = 2.0
	part.mesh = sphere
	part.position = at
	part.scale = radii
	part.material_override = paint
	appearance.add_child(part)
	return part

func _on_body_shape_entered(_body_rid: RID, body: Node, _body_shape: int, _local_shape: int) -> void:
	if is_dead or spawn_grace > 0.0:
		return
	if SSImpact3D.magnitude(self, body) >= SSConfig.PIG_TOUCH_KILL:
		_die(false)

func kill(out_of_world := false) -> void:
	if not is_dead:
		_die(out_of_world)

func _die(out_of_world: bool) -> void:
	is_dead = true
	died.emit(SSConfig.PIG_SCORE, global_position)
	if not out_of_world:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _process(delta: float) -> void:
	spawn_grace = maxf(spawn_grace - delta, 0.0)
	if flash > 0.0 and not is_dead:
		flash = maxf(flash - delta * 4.0, 0.0)
