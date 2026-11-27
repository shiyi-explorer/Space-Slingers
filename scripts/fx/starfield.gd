class_name SSStarfield
extends Node2D

## 深空背景层：底色渐变 + 星云团 + 三层星点 + 亮星十字光芒。
## z_index 压到最底，永远在星球/单位之下，不遮挡玩法元素。

var stars: Array[Dictionary] = []
var nebulae: Array[Dictionary] = []
var bright_stars: Array[Dictionary] = []
var bounds := Rect2()
var painted := false
var paint_tint := Color.WHITE
const NEBULA_PAINT := preload("res://assets/visual/first-orbit-nebula.png")

func setup(world_size: Vector2, seed_value: int, use_painted := false) -> void:
	z_index = -100
	painted = use_painted
	# 留出相机平移余量，避免边缘露底
	bounds = Rect2(-400, -400, world_size.x + 800, world_size.y + 800)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# 星云团：几团柔和的大色斑，颜色偏冷紫/蓝/青
	var nebula_colors := [
		Color("2b3f7a"), Color("3d2c6b"), Color("1f5673"), Color("4a2f63"), Color("244a6b")
	]
	for i in 6:
		nebulae.append({
			"pos": Vector2(rng.randf_range(0, world_size.x), rng.randf_range(0, world_size.y)),
			"radius": rng.randf_range(180, 340),
			"color": nebula_colors[i % nebula_colors.size()],
			"alpha": rng.randf_range(0.10, 0.18),
		})

	# 三层星点：远景密而暗、中景、近景亮
	for i in 150:
		stars.append({
			"pos": Vector2(rng.randf_range(-300, world_size.x + 300), rng.randf_range(-300, world_size.y + 300)),
			"radius": rng.randf_range(0.6, 2.2),
			"alpha": rng.randf_range(0.20, 0.85),
			"tint": rng.randf(),
		})
	# 亮星：带十字光芒，数量少
	for i in 12:
		bright_stars.append({
			"pos": Vector2(rng.randf_range(0, world_size.x), rng.randf_range(0, world_size.y)),
			"radius": rng.randf_range(1.8, 2.8),
			"alpha": rng.randf_range(0.7, 1.0),
			"warm": rng.randf() > 0.5,
		})
	queue_redraw()

func _draw() -> void:
	if painted:
		var image_size := NEBULA_PAINT.get_size()
		var fill_scale: float = maxf(bounds.size.x / image_size.x, bounds.size.y / image_size.y)
		var paint_size := image_size * fill_scale
		draw_texture_rect(NEBULA_PAINT, Rect2(bounds.get_center() - paint_size * 0.5, paint_size), false, paint_tint)
		return
	# 底色：深蓝到近黑的柔和渐变（多条横向带，上亮下暗）
	var bands := 12
	var band_h: float = bounds.size.y / float(bands)
	for i in bands:
		var t: float = float(i) / float(bands - 1)
		var col := Color("0c1830").lerp(Color("050a16"), t)
		draw_rect(Rect2(bounds.position.x, bounds.position.y + band_h * i, bounds.size.x, band_h + 1), col)

	# 星云：多层半透明同心圆叠加出柔和边缘
	for neb in nebulae:
		var c: Color = neb["color"]
		for layer in 5:
			var f: float = 1.0 - float(layer) / 5.0
			draw_circle(neb["pos"], neb["radius"] * f,
				Color(c.r, c.g, c.b, neb["alpha"] * (1.0 - f) * 0.9))

	# 星点
	for s in stars:
		var c := Color(0.86, 0.92, 1.0)
		if s["tint"] > 0.72:
			c = Color(1.0, 0.88, 0.72)
		elif s["tint"] < 0.22:
			c = Color(0.70, 0.84, 1.0)
		draw_circle(s["pos"], s["radius"], Color(c.r, c.g, c.b, s["alpha"]))

	# 亮星十字光芒
	for s in bright_stars:
		var c := Color(1.0, 0.93, 0.78) if s["warm"] else Color(0.82, 0.91, 1.0)
		var p: Vector2 = s["pos"]
		var a: float = s["alpha"]
		draw_circle(p, s["radius"], Color(c.r, c.g, c.b, a))
		draw_circle(p, s["radius"] * 2.6, Color(c.r, c.g, c.b, a * 0.10))
		var arm: float = s["radius"] * 5.0
		draw_line(p - Vector2(arm, 0), p + Vector2(arm, 0), Color(c.r, c.g, c.b, a * 0.45), 1.2)
		draw_line(p - Vector2(0, arm), p + Vector2(0, arm), Color(c.r, c.g, c.b, a * 0.45), 1.2)
