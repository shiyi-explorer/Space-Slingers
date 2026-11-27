class_name SSFxOverlay
extends Node2D

## 排队小鸟贴图（与场上小鸟同款 AI 角色图）
const QUEUE_TEXTURES := {
	"normal": preload("res://assets/characters/bird_normal.png"),
	"split": preload("res://assets/characters/bird_split.png"),
	"dash": preload("res://assets/characters/bird_dash.png"),
}

## 世界特效层：弹道预览（发光渐细带 + 落点准星 + 方向箭头）、飞行轨迹、排队小鸟。
## 星空背景已拆到 SSStarfield（最底层），本层只画玩法相关反馈。

var dotted_preview := false
var dotted_color := Color("b3ffeb")
var preview_points: Array[Vector2] = []
var preview_velocity := Vector2.ZERO
var preview_origin := Vector2.ZERO
var trail_points: Array[Vector2] = []
var queue_entries: Array[Dictionary] = []

func setup(_world_size: Vector2, _seed_value: int) -> void:
	z_index = 40

func set_preview(points: Array[Vector2], velocity := Vector2.ZERO, origin := Vector2.ZERO) -> void:
	preview_points = points
	preview_velocity = velocity
	preview_origin = origin
	queue_redraw()

func set_trail(points: Array[Vector2]) -> void:
	trail_points = points
	queue_redraw()

func set_queue(entries: Array[Dictionary]) -> void:
	queue_entries = entries
	queue_redraw()

func _draw() -> void:
	_draw_trail()
	_draw_preview()
	_draw_queue()

func _draw_trail() -> void:
	var size := trail_points.size()
	if size < 2:
		return
	var c := SSConfig.COLOR_TRAIL
	# 分段连线，由旧到新渐亮渐细
	for i in size - 1:
		var t: float = float(i) / float(size - 1)
		var col := Color(c.r, c.g, c.b, 0.08 + t * 0.62)
		draw_line(trail_points[i], trail_points[i + 1], col, 2.0 + t * 3.0)
	# 头部亮点
	var head: Vector2 = trail_points[size - 1]
	draw_circle(head, 4.5, Color(c.r, c.g, c.b, 0.9))
	draw_circle(head, 9.0, Color(c.r, c.g, c.b, 0.18))

func _draw_preview() -> void:
	var n := preview_points.size()
	if n < 2:
		return
	var c := dotted_color if dotted_preview else SSConfig.COLOR_PREVIEW
	if dotted_preview:
		_draw_preview_dots(c)
		return

	# 主体：从近到远渐细渐淡的连续发光带
	for i in n - 1:
		var t: float = float(i) / float(n - 1)
		var width: float = lerpf(6.0, 1.2, t)
		var alpha: float = lerpf(0.95, 0.28, t * t)
		draw_line(preview_points[i], preview_points[i + 1],
			Color(c.r, c.g, c.b, alpha), width)

	# 外层柔光（同一条带，更宽更淡）
	for i in n - 1:
		var t: float = float(i) / float(n - 1)
		var alpha: float = lerpf(0.20, 0.04, t)
		draw_line(preview_points[i], preview_points[i + 1],
			Color(c.r, c.g, c.b, alpha), lerpf(13.0, 3.0, t))

	# 方向箭头：从发射起点指向初速度方向
	if preview_velocity.length() > 1.0 and preview_origin != Vector2.ZERO:
		var dir: Vector2 = preview_velocity.normalized()
		var tip: Vector2 = preview_origin + dir * 62.0
		var wing: Vector2 = Vector2(-dir.y, dir.x)
		var arrow_c := Color("ffd166")
		draw_line(preview_origin, tip, Color(arrow_c.r, arrow_c.g, arrow_c.b, 0.9), 3.0)
		draw_line(tip, tip - dir * 14.0 + wing * 7.0, Color(arrow_c.r, arrow_c.g, arrow_c.b, 0.9), 3.0)
		draw_line(tip, tip - dir * 14.0 - wing * 7.0, Color(arrow_c.r, arrow_c.g, arrow_c.b, 0.9), 3.0)

	# 落点准星：双环 + 十字
	var end: Vector2 = preview_points[n - 1]
	var mark := Color("ffffff")
	draw_arc(end, 13.0, 0, TAU, 32, Color(mark.r, mark.g, mark.b, 0.85), 2.0)
	draw_arc(end, 21.0, 0, TAU, 32, Color(mark.r, mark.g, mark.b, 0.35), 1.5)
	draw_line(end - Vector2(9, 0), end + Vector2(9, 0), Color(mark.r, mark.g, mark.b, 0.85), 1.5)
	draw_line(end - Vector2(0, 9), end + Vector2(0, 9), Color(mark.r, mark.g, mark.b, 0.85), 1.5)
	draw_circle(end, 3.0, Color(mark.r, mark.g, mark.b, 0.95))

func _draw_preview_dots(color: Color) -> void:
	var distance_to_dot := 0.0
	for i in range(1, preview_points.size()):
		var start: Vector2 = preview_points[i - 1]
		var finish: Vector2 = preview_points[i]
		var length: float = start.distance_to(finish)
		if is_zero_approx(length):
			continue
		while distance_to_dot < length:
			var point := start.lerp(finish, distance_to_dot / length)
			draw_circle(point, 5.0, Color(color, 0.14), true, -1.0, true)
			draw_circle(point, 2.4, Color(color, 0.9), true, -1.0, true)
			distance_to_dot += 15.0
		distance_to_dot -= length
	var end: Vector2 = preview_points[-1]
	draw_circle(end, 9.0, Color(color, 0.8), false, 1.4, true)
	draw_circle(end, 2.2, color, true, -1.0, true)

func _draw_queue() -> void:
	for entry in queue_entries:
		var pos: Vector2 = entry["pos"]
		var kind: String = entry.get("kind", "normal")
		_draw_bird_at(pos, kind)

## 排队小鸟：直接绘制 AI 角色贴图，与场上小鸟同款。
func _draw_bird_at(pos: Vector2, kind: String) -> void:
	var tex: Texture2D = QUEUE_TEXTURES.get(kind, QUEUE_TEXTURES["normal"])
	if tex == null:
		return
	# 躯干直径对齐到 2×BIRD_RADIUS，贴图可能非正方形，按宽度等比缩放
	var body_ratio := 0.86
	var scale: float = (SSConfig.BIRD_RADIUS * 2.0) / maxf(float(tex.get_width()) * body_ratio, 1.0)
	var size := Vector2(float(tex.get_width()) * scale, float(tex.get_height()) * scale)
	# 贴图原生面朝左，排队时朝右（对着目标）：用负 X 变换镜像绘制
	draw_set_transform(pos, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
