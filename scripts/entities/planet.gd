class_name SSPlanet
extends Node2D

## 行星：自绘球体（球面光照渐变 + 地貌带 + 立体陨石坑）+ 引力圈。无球外光晕。
## 碰撞：Area2D 检测引力圈内刚体；StaticBody2D 提供实体表面。绘制纯视觉，不碰物理。

var planet_center := Vector2.ZERO
var planet_radius := 90.0
var field_radius := 300.0
var strength := 520.0
var base_color := Color("3b4355")
var highlight_color := Color("68748a")
var ring_color := Color.WHITE
var craters: Array[Dictionary] = []
var terrain: Array[Dictionary] = []
var area: Area2D
enum Surface { ORIGINAL = -1, COBALT, SANDSTONE, AMETHYST }

var painted_surface := Surface.ORIGINAL

func set_painted_surface(surface: Surface) -> void:
	painted_surface = surface
	queue_redraw()

## 光源方向（左上），球面明暗、陨石坑高光、大气亮边都用它
const PLANET_PAINT := preload("res://assets/visual/first-orbit-planets.png")
const PLANET_REGIONS := [Rect2(84, 80, 725, 725), Rect2(952, 80, 729, 729)]
const AMETHYST_PAINT := preload("res://assets/visual/amethyst-planetoid.png")
const AMETHYST_REGION := Rect2(54, 62, 1144, 1160)
const FIELD_COLORS := [Color("83c8ff"), Color("7ff4dd"), Color("dfacff")]

const LIGHT_DIR := Vector2(-0.55, -0.62)

func setup(data: Dictionary) -> void:
	planet_center = data["center"]
	planet_radius = data["radius"]
	field_radius = data["field"]
	strength = data["strength"]
	base_color = data["base"]
	highlight_color = data["highlight"]
	ring_color = data["ring"]
	position = planet_center

	# 引力圈检测
	area = Area2D.new()
	var field_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = field_radius
	field_shape.shape = circle
	area.add_child(field_shape)
	add_child(area)

	# 实体表面
	var body := StaticBody2D.new()
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.9
	var surface := CollisionShape2D.new()
	var solid := CircleShape2D.new()
	solid.radius = planet_radius
	surface.shape = solid
	body.add_child(surface)
	add_child(body)

	# 固定随机：地貌斑块 + 陨石坑，按中心坐标种子，每次一致
	var rng := RandomNumberGenerator.new()
	rng.seed = int(planet_center.x) + int(planet_center.y) * 31 + 7

	terrain = []
	for i in 7:
		var angle: float = rng.randf() * TAU
		var depth: float = rng.randf_range(0.15, 0.72)
		terrain.append({
			"pos": Vector2(cos(angle), sin(angle)) * planet_radius * depth,
			"size": rng.randf_range(0.14, 0.30),
			"tone": rng.randf_range(-1.0, 1.0),
			"squash": rng.randf_range(0.35, 0.7),
		})

	craters = []
	for i in 4:
		var angle: float = rng.randf() * TAU
		var depth: float = rng.randf_range(0.18, 0.66)
		craters.append({
			"pos": Vector2(cos(angle), sin(angle)) * planet_radius * depth,
			"size": rng.randf_range(0.045, 0.075),
		})
	queue_redraw()

func _draw() -> void:
	var r := planet_radius
	var light := LIGHT_DIR.normalized()
	var ring_c := ring_color
	if painted_surface != Surface.ORIGINAL:
		_draw_painted_planet()
		return

	# ---- 引力圈：内晕 + 柔虚线 ----
	for layer in 4:
		var w: float = 2.0 + layer * 4.0
		draw_arc(Vector2.ZERO, field_radius - layer * 2.0, 0, TAU, 128,
			Color(ring_c.r, ring_c.g, ring_c.b, 0.030 + (3 - layer) * 0.006), w)
	var segments := 96
	for i in segments:
		var a0: float = TAU * i / segments
		var a1: float = a0 + TAU / segments * 0.6
		draw_arc(Vector2.ZERO, field_radius, a0, a1, 3,
			Color(ring_c.r, ring_c.g, ring_c.b, 0.42), 2.0)

	# 注意：按用户要求不做球外大气光晕，球体轮廓止于 r。

	# ---- 球体基础：暗底圆 ----
	draw_circle(Vector2.ZERO, r, base_color.darkened(0.42))

	# ---- 球面径向渐变：同心圆，圆心固定在球心 ----
	# 关键：所有层圆心必须一致，否则偏移的大圆边界会落在球内形成一条清晰的「平移光晕」弧线。
	var steps := 48
	for i in steps:
		var t: float = float(i) / float(steps - 1)      # 0 外缘 → 1 中心
		var rr: float = r * (1.0 - t * 0.99)
		var shade := base_color.darkened(0.32).lerp(highlight_color, 0.10 + t * 0.82)
		draw_circle(Vector2.ZERO, rr, Color(shade.r, shade.g, shade.b, 0.13))

	# ---- 地表地貌：柔和椭圆斑块，随球面弯曲裁剪在圆内 ----
	for t in terrain:
		var p: Vector2 = t["pos"]
		var cs: float = r * t["size"]
		var tone: float = t["tone"]
		var patch_col: Color = base_color.lerp(highlight_color, 0.35)
		if tone > 0:
			patch_col = patch_col.lightened(tone * 0.16)
		else:
			patch_col = patch_col.darkened(-tone * 0.18)
		# 只画落在球内的部分（用大圆遮罩近似：斑块中心距+半径 < r）
		if p.length() + cs < r * 0.94:
			draw_ellipse(p, cs * 1.7, cs * t["squash"] * 1.7,
				Color(patch_col.r, patch_col.g, patch_col.b, 0.20), 0.0)

	# ---- 明暗交界：背光侧（右下）压暗，用羽化圆避免硬边 ----
	# 同样圆心固定（球心），只把圆心整体挪到背光侧作为阴影中心，半径递减自然淡出。
	var dark_center := -light * r * 0.30
	for i in 9:
		var t: float = float(i) / 8.0
		var rr: float = r * (0.90 - t * 0.55)
		draw_circle(dark_center, rr, Color(0.02, 0.04, 0.10, 0.035))

	# ---- 陨石坑：暗坑 + 环形唇 + 受光侧高光 ----
	for crater in craters:
		var p: Vector2 = crater["pos"]
		var cs: float = r * crater["size"]
		# 坑底（柔化，不再是大黑斑）
		draw_circle(p, cs, base_color.darkened(0.30))
		# 坑唇（暗环）
		draw_arc(p, cs * 1.02, 0, TAU, 18, Color(0, 0, 0, 0.16), 2.0)
		# 受光侧高光弧
		var lit := p.direction_to(light * r)
		draw_arc(p, cs, lit.angle() - 1.0, lit.angle() + 1.0, 12,
			Color(1, 1, 1, 0.26), 1.8)

	# ---- 球面高光（柔和大光斑） ----
	var hl := light * r * 0.42
	draw_circle(hl, r * 0.13, Color(1, 1, 1, 0.10))
	draw_circle(hl, r * 0.07, Color(1, 1, 1, 0.10))

	# ---- 球的轮廓光 ----
	draw_arc(Vector2.ZERO, r - 0.5, 0, TAU, 96, Color(1, 1, 1, 0.26), 1.6)
	# 受光侧亮边
	draw_arc(Vector2.ZERO, r - 1.0, light.angle() - 1.1, light.angle() + 1.1, 40,
		Color(1, 1, 1, 0.42), 2.2)

## 引力边界和地表从关卡物理半径绘制。
func _draw_painted_planet() -> void:
	var field_color: Color = FIELD_COLORS[painted_surface]
	draw_circle(Vector2.ZERO, field_radius, Color(field_color, 0.040), true, -1.0, true)
	for layer in range(9, 0, -1):
		draw_arc(Vector2.ZERO, field_radius - float(layer) * 2.0, 0.0, TAU, 192,
			Color(field_color, lerpf(0.008, 0.075, 1.0 - float(layer) / 9.0)), 5.0, true)
	draw_arc(Vector2.ZERO, field_radius, 0.0, TAU, 192, Color(field_color, 0.62), 1.7, true)
	draw_circle(Vector2.ZERO, planet_radius, base_color.darkened(0.35), true, -1.0, true)
	var surface_rect := Rect2(Vector2.ONE * -planet_radius, Vector2.ONE * planet_radius * 2.0)
	if painted_surface == Surface.AMETHYST:
		draw_texture_rect_region(AMETHYST_PAINT, surface_rect, AMETHYST_REGION)
	else:
		draw_texture_rect_region(PLANET_PAINT, surface_rect, PLANET_REGIONS[painted_surface])
	draw_arc(Vector2.ZERO, planet_radius, -2.9, -0.55, 72, Color(field_color, 0.50), 1.5, true)
