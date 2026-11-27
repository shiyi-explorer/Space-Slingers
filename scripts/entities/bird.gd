class_name SSBird
extends RigidBody2D

## 小鸟：AI 生成的精致角色贴图（Sprite2D）+ 呼吸/眨眼/飞行速度线动画。
## 物理与碰撞完全保持原样：gravity_scale 恒 0，只有行星引力圈施力；预览与实际弹道同构。

signal spent

enum BirdState {LOADED, FLYING, DEAD}

## 种类：normal 红色普通 / split 蓝色分裂（飞行中点击一分为三）/ dash 黄色加速（点击冲刺）
var bird_kind := "normal"
var special_used := false
var bird_state: int = BirdState.LOADED
var still_frames := 0
var life_time := 0.0
var anim_time := 0.0

const TEXTURE_PATHS := {
	"normal": "res://assets/characters/bird_normal.png",
	"split": "res://assets/characters/bird_split.png",
	"dash": "res://assets/characters/bird_dash.png",
}
## 角色躯干在贴图宽度中约占的比例：据此把躯干直径对齐到碰撞直径
const BODY_WIDTH_RATIO := 0.86

var sprite: Sprite2D
var base_sprite_scale := 1.0

func _ready() -> void:
	gravity_scale = 0.0
	mass = 1.0
	linear_damp = 0.0   # 真空无阻力：预览与实际弹道必须同构，任何阻尼都会造成发散
	angular_damp = 1.0
	freeze = true
	freeze_mode = FREEZE_MODE_STATIC
	contact_monitor = true
	max_contacts_reported = 6
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = SSConfig.BIRD_RADIUS
	collision.shape = shape
	add_child(collision)
	var material := PhysicsMaterial.new()
	material.bounce = 0.35
	material.friction = 0.6
	physics_material_override = material
	sprite = Sprite2D.new()
	add_child(sprite)
	_apply_texture()
	queue_redraw()

func _apply_texture() -> void:
	if sprite == null:
		return
	var path: String = TEXTURE_PATHS.get(bird_kind, TEXTURE_PATHS["normal"])
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("小鸟贴图加载失败: " + path)
		return
	sprite.texture = tex
	base_sprite_scale = (SSConfig.BIRD_RADIUS * 2.0) / maxf(float(tex.get_width()) * BODY_WIDTH_RATIO, 1.0)
	sprite.scale = Vector2.ONE * base_sprite_scale

func can_special() -> bool:
	return bird_state == BirdState.FLYING and not special_used and bird_kind != "normal"

func dash() -> void:
	linear_velocity = (linear_velocity * 1.75).limit_length(SSConfig.MAX_FLIGHT_SPEED)

func launch(velocity: Vector2) -> void:
	if bird_state != BirdState.LOADED:
		return
	bird_state = BirdState.FLYING
	freeze = false
	linear_velocity = velocity
	queue_redraw()

func _physics_process(delta: float) -> void:
	if bird_state != BirdState.FLYING:
		return
	life_time += delta
	linear_velocity = linear_velocity.limit_length(SSConfig.MAX_FLIGHT_SPEED)
	if linear_velocity.length() < SSConfig.BIRD_SETTLE_SPEED:
		still_frames += 1
	else:
		still_frames = 0
	if still_frames >= SSConfig.BIRD_SETTLE_FRAMES or life_time >= SSConfig.BIRD_MAX_LIFE:
		_poof()

func _process(delta: float) -> void:
	if bird_state == BirdState.DEAD:
		return
	anim_time += delta
	if sprite != null and sprite.texture != null:
		# 待机呼吸；每 3.4 秒轻微纵向压缩模拟眨眼，飞行中绷紧不呼吸
		var flying: bool = bird_state == BirdState.FLYING
		var breath: float = 1.0 + sin(anim_time * 3.2) * (0.03 if not flying else 0.01)
		var blink: bool = not flying and fmod(anim_time + 0.7, 3.4) > 3.30
		var squash: float = 0.90 if blink else 1.0
		# 刚体飞行会自转，贴图层抵消它，让角色始终正立（速度线由速度方向算，不受影响）
		sprite.rotation = -rotation
		# 贴图原生面朝左：待机朝右（对着目标），飞行时按水平速度方向翻转
		var face_right: bool = true
		if bird_state == BirdState.FLYING:
			face_right = linear_velocity.x >= 0.0
		sprite.flip_h = face_right
		sprite.scale = Vector2(base_sprite_scale * breath, base_sprite_scale * breath * squash)
	queue_redraw()

func poof() -> void:
	_poof()

func _poof() -> void:
	if bird_state == BirdState.DEAD:
		return
	bird_state = BirdState.DEAD
	spent.emit()
	var body: Color = SSConfig.COLOR_BIRD_KINDS.get(bird_kind, Color("d9403f"))
	_burst(body)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.28)
	tween.tween_callback(queue_free)

## 消散碎片：挂在父节点上的临时容器，独立于小鸟本体 tween，飞散后自毁。
func _burst(tint: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var burst := Node2D.new()
	burst.global_position = global_position
	parent.add_child(burst)
	for i in 8:
		var bit := ColorRect.new()
		var size: float = randf_range(2.5, 5.0)
		bit.size = Vector2(size, size)
		bit.position = Vector2(-size * 0.5, -size * 0.5)
		bit.color = tint.lightened(randf_range(0.0, 0.35))
		burst.add_child(bit)
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 8.0 + randf_range(-0.25, 0.25))
		var distance: float = randf_range(16.0, 32.0)
		var tween := burst.create_tween()
		tween.set_parallel(true)
		tween.tween_property(bit, "position", bit.position + dir * distance, 0.38)
		tween.tween_property(bit, "modulate:a", 0.0, 0.38)
		tween.chain().tween_callback(burst.queue_free)

## 飞行速度线画在贴图后方（_draw 先于子节点绘制），无需再画身体。
func _draw() -> void:
	if bird_state != BirdState.FLYING or linear_velocity.length() <= 260.0:
		return
	var r := SSConfig.BIRD_RADIUS
	var local_dir := linear_velocity.rotated(-rotation).normalized()
	var side_axis := Vector2(-local_dir.y, local_dir.x)
	for i in 3:
		var offset := side_axis * (float(i) - 1.0) * 7.0
		var start := -local_dir * (r + 3.0) + offset
		var end := -local_dir * (r + 15.0 + float(i) * 4.0) + offset
		draw_line(start, end, Color(1, 1, 1, 0.26 - float(i) * 0.06), 2.0)
