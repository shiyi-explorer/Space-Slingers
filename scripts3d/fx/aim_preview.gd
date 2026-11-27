class_name SSAimPreview
extends Node3D

## 弹道预览表现层：连续发光带 + 落点准星 + XZ 平面投影线 + 发射方向箭头。
## 只负责"画"，弹道点由 main 用同一套引力积分算好后喂进来。

var _ribbon: ImmediateMesh
var _ribbon_mesh: MeshInstance3D
var _projection: ImmediateMesh
var _projection_mesh: MeshInstance3D
var _arrow: ImmediateMesh
var _arrow_mesh: MeshInstance3D
var _marker: MeshInstance3D
var _marker_ring: MeshInstance3D

const TRAIL_COLOR := Color(1.0, 0.85, 0.35)
const PROJ_COLOR := Color(0.45, 0.85, 1.0)
const ARROW_COLOR := Color(1.0, 0.4, 0.35)

func _ready() -> void:
	_ribbon = ImmediateMesh.new()
	_ribbon_mesh = MeshInstance3D.new()
	_ribbon_mesh.mesh = _ribbon
	_ribbon_mesh.material_override = _unlit(TRAIL_COLOR, 0.9, false)
	_ribbon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbon_mesh)

	_projection = ImmediateMesh.new()
	_projection_mesh = MeshInstance3D.new()
	_projection_mesh.mesh = _projection
	_projection_mesh.material_override = _unlit(PROJ_COLOR, 0.4, true)
	_projection_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_projection_mesh)

	_arrow = ImmediateMesh.new()
	_arrow_mesh = MeshInstance3D.new()
	_arrow_mesh.mesh = _arrow
	_arrow_mesh.material_override = _unlit(ARROW_COLOR, 0.95, true)
	_arrow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrow_mesh)

	# 落点准星：中心球 + 圆环，画在最上层
	_marker = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 6.0
	sphere.height = 12.0
	_marker.mesh = sphere
	_marker.material_override = _unlit(Color.WHITE, 1.0, true)
	add_child(_marker)
	_marker_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 13.0
	torus.outer_radius = 15.0
	_marker_ring.mesh = torus
	_marker_ring.material_override = _unlit(Color.WHITE, 0.7, true)
	add_child(_marker_ring)

func _unlit(color: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.75
	return material

## points: 弹道采样点；impact: 末点（命中或终点）；velocity: 发射速度（画箭头）
func draw(points: Array[Vector3], impact: Vector3, velocity: Vector3) -> void:
	_clear_all()
	if points.is_empty():
		return
	_draw_ribbon(points)
	_draw_projection(points)
	_draw_arrow(points[0], velocity)
	_marker.position = impact
	_marker_ring.position = impact
	_marker_ring.look_at(impact + Vector3.UP)

func clear() -> void:
	_clear_all()

func _clear_all() -> void:
	_ribbon.clear_surfaces()
	_projection.clear_surfaces()
	_arrow.clear_surfaces()
	_marker.visible = false
	_marker_ring.visible = false

func _draw_ribbon(points: Array[Vector3]) -> void:
	# 相机朝向上方做 billboard 带：用世界 UP 与段方向叉乘得到带宽方向
	_ribbon.clear_surfaces()
	_ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		var p: Vector3 = points[i]
		var tangent: Vector3 = Vector3.FORWARD
		if i + 1 < points.size():
			tangent = (points[i + 1] - p).normalized()
		elif i > 0:
			tangent = (p - points[i - 1]).normalized()
		var side: Vector3 = tangent.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = tangent.cross(Vector3.FORWARD)
		# 近端粗、远端细：朝落点收窄，强化"往哪飞"的方向感
		var taper: float = 1.0 - 0.65 * float(i) / float(maxi(points.size() - 1, 1))
		side = side.normalized() * (3.8 * taper)
		_ribbon.surface_add_vertex(p + side)
		_ribbon.surface_add_vertex(p - side)
	_ribbon.surface_end()

func _draw_projection(points: Array[Vector3]) -> void:
	# XZ 平面投影虚线：帮助判断落点在地面上的位置
	_projection.clear_surfaces()
	_projection.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		_projection.surface_add_vertex(Vector3(p.x, 1.5, p.z))
	_projection.surface_end()

func _draw_arrow(origin: Vector3, velocity: Vector3) -> void:
	if velocity.length_squared() < 0.001:
		return
	var dir: Vector3 = velocity.normalized()
	# 箭头放在起点前方 30 单位，避免与弹道起点重叠
	var base: Vector3 = origin + dir * 30.0
	var tip: Vector3 = base + dir * 40.0
	# 宽度方向：水平面内垂直于 dir，从俯视相机看得见
	var side: Vector3 = dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	_arrow.clear_surfaces()
	_arrow.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# 箭杆（加宽到 5，明显压在弹道线上）
	var shaft_end: Vector3 = base + dir * 25.0
	var w: float = 4.5
	_tri(_arrow, base + side * w, shaft_end + side * w, shaft_end - side * w)
	_tri(_arrow, base + side * w, shaft_end - side * w, base - side * w)
	# 箭头（三角形，宽 16）
	_tri(_arrow, tip, shaft_end + side * 16.0, shaft_end - side * 16.0)
	_arrow.surface_end()

func _tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
