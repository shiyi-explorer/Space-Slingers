class_name SSShockwave
extends Node3D

## 冲击波环：在游戏平面（XZ）上扩散一圈发光圆环，放大 + 淡出后自毁。
## TorusMesh 默认就躺在 XZ 平面，正对俯视镜头。

var ring_color := Color.WHITE
var scale_factor := 1.0

func setup(p_color: Color, p_scale: float) -> void:
	ring_color = p_color
	scale_factor = p_scale

func _ready() -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 5.0
	mesh.outer_radius = 5.8
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(ring_color.r, ring_color.g, ring_color.b, 0.9)
	material.emission_enabled = true
	material.emission = ring_color
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	ring.material_override = material
	ring.position = Vector3(0, 1.5, 0)
	add_child(ring)
	ring.scale = Vector3.ONE * 0.2 * scale_factor
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 3.2 * scale_factor, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(queue_free)
