class_name SSBlock
extends RigidBody2D

## 方块：所有砖块性质完全一致——同样受引力、同样可碎、无锚定无特例。
## 塔楼稳不稳只取决于摆放（横竖放对、不穿模、有支撑），不靠特殊物理性质。
## 视觉为框架艺术：木梁榫卯抱箍/节疤、玻璃窗棂反光、横梁角码铆钉——纯绘制，不碰物理。

signal destroyed(score_value: int, at_position: Vector2)

const MATERIALS := {
	"wood": {"hp": 1, "threshold": 180.0, "score": 500, "mass": 1.2, "color": Color("d18a4d"), "edge": Color("f4ddaf")},
	"stone": {"hp": 2, "threshold": 320.0, "score": 800, "mass": 3.0, "color": Color("8a97ab"), "edge": Color("dcecff")},
	"glass": {"hp": 1, "threshold": 90.0, "score": 300, "mass": 0.7, "color": Color("70d5e8"), "edge": Color("e8fbff")},
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

func setup(data: Dictionary) -> void:
	material_kind = data["material"]
	rect_size = data["size"]
	position = data["position"]
	rotation = data["rotation"]
	var material: Dictionary = MATERIALS[material_kind]
	hp = material["hp"]
	damage_threshold = material["threshold"]
	score_value = material["score"]
	block_color = material["color"]
	edge_color = material["edge"]

func _ready() -> void:
	gravity_scale = 0.0
	mass = MATERIALS[material_kind]["mass"]
	linear_damp = 0.6
	angular_damp = 1.0
	contact_monitor = true
	max_contacts_reported = 6
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect_size
	collision.shape = shape
	add_child(collision)
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.8
	physics_material.bounce = 0.1
	physics_material_override = physics_material
	body_shape_entered.connect(_on_body_shape_entered)
	queue_redraw()

## 撞击结算：相对动量超过材质阈值才掉血（出生保护期内免伤，等初始沉降）
func _on_body_shape_entered(_body_rid: RID, body: Node, _body_shape: int, _local_shape: int) -> void:
	if hp <= 0 or spawn_grace > 0.0:
		return
	if SSImpact.magnitude(self, body) >= damage_threshold:
		take_damage()

func take_damage() -> void:
	hp -= 1
	flash = 1.0
	queue_redraw()
	if hp <= 0:
		destroyed.emit(score_value, global_position)
		set_physics_process(false)
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
		tween.tween_callback(queue_free)

func _process(delta: float) -> void:
	spawn_grace = maxf(spawn_grace - delta, 0.0)
	if flash > 0.0:
		flash = maxf(flash - delta * 4.0, 0.0)
		queue_redraw()

func _draw() -> void:
	var half := rect_size * 0.5
	var rect := Rect2(-half, rect_size)
	var w := rect_size.x
	var h := rect_size.y
	# 纵向梁柱（h>w）与横向梁（w>h）用不同纹理走向
	var vertical: bool = h >= w

	# 柔和投影（纯视觉，略超碰撞体 2.5px）
	draw_rect(Rect2(-half.x + 2.5, -half.y + 3.0, w, h), Color(0, 0, 0, 0.20))

	if material_kind == "wood":
		_draw_wood(half, w, h, vertical)
	elif material_kind == "glass":
		_draw_glass(half, w, h, vertical)
	else:
		_draw_stone(half, w, h, vertical)

	# 外描边 + 高光/暗棱（立体厚度）
	draw_rect(rect, Color(0.10, 0.09, 0.10, 0.85), false, 2.0)
	draw_line(Vector2(-half.x + 1.5, -half.y + 1.5), Vector2(half.x - 1.5, -half.y + 1.5),
		Color(1, 1, 1, 0.42), 1.6)
	draw_line(Vector2(-half.x + 1.5, -half.y + 1.5), Vector2(-half.x + 1.5, half.y - 1.5),
		Color(1, 1, 1, 0.22), 1.2)
	draw_line(Vector2(-half.x + 1.5, half.y - 1.5), Vector2(half.x - 1.5, half.y - 1.5),
		Color(0, 0, 0, 0.30), 1.5)

	# 裂纹随受损加深
	if hp <= 1 and material_kind != "glass":
		draw_line(Vector2(-2, -half.y + 3), Vector2(3, -h * 0.1), Color(0, 0, 0, 0.4), 1.8)
		draw_line(Vector2(3, -h * 0.1), Vector2(-1, h * 0.2), Color(0, 0, 0, 0.4), 1.8)
	if flash > 0.0:
		draw_rect(rect, Color(1, 1, 1, flash * 0.55), true)

func _draw_wood(half: Vector2, w: float, h: float, vertical: bool) -> void:
	# 木质渐变底（中间亮、边缘暗）
	for i in 6:
		var t: float = float(i) / 5.0
		var inset: float = lerpf(0.0, minf(half.x, half.y) * 0.55, t)
		var shade := block_color.darkened(0.32).lerp(block_color.lightened(0.22), t)
		draw_rect(Rect2(-half.x + inset, -half.y + inset, w - inset * 2, h - inset * 2),
			Color(shade.r, shade.g, shade.b, 0.78))

	# 木纹（顺长边）
	if vertical:
		for i in 3:
			var x: float = -half.x + w * (0.24 + i * 0.26)
			draw_line(Vector2(x, -half.y + 5), Vector2(x + 1.5, half.y - 5),
				Color(0, 0, 0, 0.16), 1.3)
	else:
		for i in 3:
			var y: float = -half.y + h * (0.26 + i * 0.26)
			draw_line(Vector2(-half.x + 5, y), Vector2(half.x - 5, y + 1.0),
				Color(0, 0, 0, 0.16), 1.3)

	# 木节疤：两端各一个深色椭圆环
	if vertical and h > 40:
		for ky in [-h * 0.22, h * 0.20]:
			draw_ellipse(Vector2(0, ky), 3.0, 1.53, Color(0, 0, 0, 0.14))
			draw_ellipse(Vector2(0, ky), 1.5, 1.60, Color(0, 0, 0, 0.18))
	elif not vertical and w > 60:
		for kx in [-w * 0.22, w * 0.20]:
			draw_ellipse(Vector2(kx, 0), 4.6, 0.65, Color(0, 0, 0, 0.14))
			draw_ellipse(Vector2(kx, 0), 2.4, 0.63, Color(0, 0, 0, 0.18))

	# 端头金属抱箍（榫卯加固）
	var band := Color("6b5440")
	var band_hi := Color("e6cf9e", 0.55)
	if vertical:
		for by in [-half.y + 8.0, half.y - 8.0]:
			draw_rect(Rect2(-half.x + 1, by - 2.5, w - 2, 5.0), band)
			draw_line(Vector2(-half.x + 1.5, by - 2.0), Vector2(half.x - 1.5, by - 2.0), band_hi, 1.0)
	else:
		for bx in [-half.x + 8.0, half.x - 8.0]:
			draw_rect(Rect2(bx - 2.5, -half.y + 1, 5.0, h - 2), band)
			draw_line(Vector2(bx - 2.0, -half.y + 1.5), Vector2(bx - 2.0, half.y - 1.5), band_hi, 1.0)

	# 横梁角码 + 铆钉排；立柱端头铆钉
	if not vertical and w > 60:
		for cx in [-half.x + 8.0, half.x - 8.0]:
			draw_rect(Rect2(cx - 5.0, -half.y + 2, 10.0, h - 4), Color("7a6249"), false, 1.4)
			for cy in [-half.y + 6.0, half.y - 6.0]:
				draw_circle(Vector2(cx, cy), 2.0, Color("d9c9a8"))
				draw_circle(Vector2(cx - 0.5, cy - 0.5), 0.9, Color("7a6a52"))
	elif vertical and h > 40:
		for cy in [-half.y + 8.0, half.y - 8.0]:
			draw_circle(Vector2(0, cy), 1.8, Color("d9c9a8"))
			draw_circle(Vector2(-0.4, cy - 0.4), 0.8, Color("7a6a52"))

func _draw_glass(half: Vector2, w: float, h: float, vertical: bool) -> void:
	# 半透明玻璃底
	draw_rect(Rect2(-half.x, -half.y, w, h), Color(block_color.r, block_color.g, block_color.b, 0.55))
	# 双层内格框
	draw_rect(Rect2(-half.x + 3, -half.y + 3, w - 6, h - 6),
		Color(block_color.r, block_color.g, block_color.b, 0.85), false, 2.0)
	draw_rect(Rect2(-half.x + 5, -half.y + 5, w - 10, h - 10),
		Color(edge_color.r, edge_color.g, edge_color.b, 0.30), false, 1.0)
	# 窗棂：中间一根分隔条
	if vertical and h > 40:
		draw_line(Vector2(0, -half.y + 4), Vector2(0, half.y - 4),
			Color(edge_color.r, edge_color.g, edge_color.b, 0.50), 1.8)
	elif not vertical and w > 60:
		draw_line(Vector2(-half.x + 4, 0), Vector2(half.x - 4, 0),
			Color(edge_color.r, edge_color.g, edge_color.b, 0.50), 1.8)
	# 斜向反光条
	var len: float = minf(w, h) * 0.9
	draw_line(Vector2(-half.x + 4, -half.y + 4), Vector2(-half.x + 4 + len * 0.4, -half.y + 4 + len),
		Color(1, 1, 1, 0.34), 3.0)
	draw_line(Vector2(-half.x + 4 + len * 0.35, -half.y + 4), Vector2(-half.x + 4 + len * 0.7, -half.y + 4 + len * 0.8),
		Color(1, 1, 1, 0.18), 2.0)
	# 上下金属压条
	if vertical:
		for cy in [-half.y + 3.5, half.y - 3.5]:
			draw_rect(Rect2(-half.x + 1, cy - 1.5, w - 2, 3.0), Color("9fbcc8", 0.75))
	else:
		for cx in [-half.x + 3.5, half.x - 3.5]:
			draw_rect(Rect2(cx - 1.5, -half.y + 1, 3.0, h - 2), Color("9fbcc8", 0.75))
	draw_rect(Rect2(-half.x, -half.y, w, h), edge_color, false, 1.8)

func _draw_stone(half: Vector2, w: float, h: float, vertical: bool) -> void:
	for i in 5:
		var t: float = float(i) / 4.0
		var inset: float = lerpf(0.0, minf(half.x, half.y) * 0.5, t)
		var shade := block_color.darkened(0.28).lerp(block_color.lightened(0.14), t)
		draw_rect(Rect2(-half.x + inset, -half.y + inset, w - inset * 2, h - inset * 2),
			Color(shade.r, shade.g, shade.b, 0.7))
	# 凿痕 + 裂纹
	draw_line(Vector2(-half.x + 5, -half.y + 6), Vector2(half.x - 7, half.y - 10),
		Color(0, 0, 0, 0.16), 1.6)
	draw_line(Vector2(-half.x + 7, half.y - 7), Vector2(half.x - 5, -half.y + 8),
		Color(1, 1, 1, 0.10), 1.2)
	for i in 3:
		var y: float = -half.y + h * (0.25 + i * 0.25)
		draw_line(Vector2(-half.x + 4, y), Vector2(-half.x + w * 0.32, y + 1.5),
			Color(0, 0, 0, 0.10), 1.0)
