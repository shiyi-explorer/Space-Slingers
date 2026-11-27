class_name SSPlanet3D
extends Node3D

## 3D 行星：SphereMesh 球体 + 程序化陨石坑 + 大气辉光。
## 引力范围是真正的球体：半透明发光球壳（引力泡泡）+ 赤道虚线环（瞄准参考）。

var planet_center := Vector3.ZERO
var planet_radius := 90.0
var field_radius := 300.0
var strength := 520.0
var base_color := Color("3b4355")
var highlight_color := Color("68748a")
var craters: Array[Vector3] = []
var area: Area3D

func setup(data: Dictionary) -> void:
	planet_center = data["center"]
	planet_radius = data["radius"]
	field_radius = data["field"]
	strength = data["strength"]
	base_color = data["base"]
	highlight_color = data["highlight"]
	position = planet_center

	area = Area3D.new()
	var field_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = field_radius
	field_shape.shape = sphere
	area.add_child(field_shape)
	add_child(area)

	var body := StaticBody3D.new()
	var surface := CollisionShape3D.new()
	var solid := SphereShape3D.new()
	solid.radius = planet_radius
	surface.shape = solid
	body.add_child(surface)
	add_child(body)

	# 球体（自转轴略倾斜，有立体感）
	var mesh_node := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = planet_radius
	sphere_mesh.height = planet_radius * 2.0
	sphere_mesh.radial_segments = 48
	sphere_mesh.rings = 32
	mesh_node.mesh = sphere_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	mesh_node.material_override = material
	mesh_node.rotation_degrees = Vector3(12, 0, -8)
	add_child(mesh_node)

	# 高光半球（照亮面）
	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = planet_radius * 0.97
	glow_mesh.height = planet_radius * 1.94
	glow_mesh.radial_segments = 48
	glow_mesh.rings = 32
	glow.mesh = glow_mesh
	var glow_material := StandardMaterial3D.new()
	glow_material.albedo_color = highlight_color
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color.a = 0.35
	glow_material.no_depth_test = true
	glow_material.emission_enabled = true
	glow_material.emission = highlight_color
	glow_material.emission_energy_multiplier = 0.25
	glow.material_override = glow_material
	glow.position = Vector3(-planet_radius * 0.08, planet_radius * 0.06, planet_radius * 0.12)
	add_child(glow)

	# 引力边界：半透明发光球壳（真正的球体范围）
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = field_radius
	shell_mesh.height = field_radius * 2.0
	shell_mesh.radial_segments = 48
	shell_mesh.rings = 32
	shell.mesh = shell_mesh
	var shell_material := StandardMaterial3D.new()
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.albedo_color = Color(1, 1, 1, 0.045)
	shell_material.emission_enabled = true
	shell_material.emission = Color(1, 1, 1)
	shell_material.emission_energy_multiplier = 0.18
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell_material.no_depth_test = false
	shell.material_override = shell_material
	add_child(shell)

	# 赤道虚线环：球壳与游戏平面（Y=0）的交线，供瞄准预判
	var ring_node := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = field_radius - 1.2
	ring_mesh.outer_radius = field_radius + 1.2
	ring_node.mesh = ring_mesh
	ring_node.rotation_degrees = Vector3(90, 0, 0) # 平躺
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1, 1, 1, 0.28)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1, 1, 1)
	ring_material.emission_energy_multiplier = 0.3
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.no_depth_test = true
	ring_node.material_override = ring_material
	add_child(ring_node)

	# 固定陨石坑（种子保证一致性）
	var rng := RandomNumberGenerator.new()
	rng.seed = int(planet_center.x) + int(planet_center.z) * 31 + 7
	for i in 7:
		var angle := rng.randf() * TAU
		var pitch := rng.randf_range(-0.9, 0.9)
		craters.append(Vector3(
			cos(angle) * cos(pitch),
			sin(pitch) * 0.9,
			sin(angle) * cos(pitch)))
	for crater in craters:
		var pit := MeshInstance3D.new()
		var pit_mesh := SphereMesh.new()
		pit_mesh.radius = planet_radius * 0.06
		pit_mesh.height = planet_radius * 0.12
		pit.mesh = pit_mesh
		var pit_material := StandardMaterial3D.new()
		pit_material.albedo_color = base_color.darkened(0.35)
		pit_material.emission_enabled = true
		pit_material.emission = base_color.darkened(0.5)
		pit_material.emission_energy_multiplier = 0.3
		pit.material_override = pit_material
		pit.position = crater * (planet_radius * 0.96)
		add_child(pit)
