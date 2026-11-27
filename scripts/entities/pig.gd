class_name SSPig
extends RigidBody2D

## 太空猪：AI 生成的精致角色贴图（普通猪 / 头盔猪）+ 呼吸/眨眼动画。
## 被足够冲量的撞击（小鸟直击、石块坠落）压死，飞出世界也算消灭。物理逻辑保持原样。

signal died(score_value: int, at_position: Vector2)

var pig_radius := 20.0
var pig_hp := 1
var flash := 0.0
var is_dead := false
var spawn_grace := 0.4
var anim_time := 0.0

const SALVAGER_ART := preload("res://assets/characters/salvager-atlas.png")
const NORMAL_REGION := Rect2(140, 100, 597, 718)
const HELMET_REGION := Rect2(1044, 45, 590, 773)

var sprite: Sprite2D
var base_sprite_scale := 1.0

func setup(data: Dictionary) -> void:
	pig_radius = data["radius"]
	pig_hp = data["hp"]
	position = data["position"]
	_apply_texture()

func _ready() -> void:
	gravity_scale = 0.0
	mass = 1.5
	linear_damp = 0.6
	angular_damp = 1.0
	contact_monitor = true
	max_contacts_reported = 6
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = pig_radius
	collision.shape = shape
	add_child(collision)
	var physics_material := PhysicsMaterial.new()
	physics_material.friction = 0.7
	physics_material.bounce = 0.2
	physics_material_override = physics_material
	body_shape_entered.connect(_on_body_shape_entered)
	sprite = Sprite2D.new()
	add_child(sprite)
	_apply_texture()

func _apply_texture() -> void:
	if sprite == null:
		return
	var art := AtlasTexture.new()
	art.atlas = SALVAGER_ART
	art.region = HELMET_REGION if pig_hp >= 2 else NORMAL_REGION
	sprite.texture = art
	base_sprite_scale = pig_radius * 2.35 / art.get_height()
	sprite.scale = Vector2.ONE * base_sprite_scale
	sprite.position.y = pig_radius - art.get_height() * base_sprite_scale * 0.5

## 撞击结算：碰到就死（仅过滤静止接触，出生保护期内免伤）。
## hp>1 的大猪也不再翻倍耐打——一击即溃，头盔只作视觉区分。
func _on_body_shape_entered(_body_rid: RID, body: Node, _body_shape: int, _local_shape: int) -> void:
	if is_dead or spawn_grace > 0.0:
		return
	if SSImpact.magnitude(self, body) >= SSConfig.PIG_TOUCH_KILL:
		pig_hp = 0
		_die(false)

func kill(out_of_world := false) -> void:
	## 飞出世界的猪直接判死
	if not is_dead:
		_die(out_of_world)

func _process(delta: float) -> void:
	spawn_grace = maxf(spawn_grace - delta, 0.0)
	if is_dead:
		return
	anim_time += delta
	if flash > 0.0:
		flash = maxf(flash - delta * 4.0, 0.0)
	if sprite != null and sprite.texture != null:
		var breath: float = 1.0 + sin(anim_time * 2.6) * 0.03
		var blink: bool = fmod(anim_time + 1.3, 4.0) > 3.88
		var squash: float = 0.90 if blink else 1.0
		var shake := Vector2.ZERO
		if flash > 0.0:
			shake = Vector2(sin(anim_time * 62.0) * 1.4, 0.0)
			sprite.modulate = Color(1, 1, 1).lerp(Color(2, 2, 2), flash)
		else:
			sprite.modulate = Color.WHITE
		# 圆形碰撞体沿球面滚动会自转，贴图层抵消它，让角色始终正立
		sprite.rotation = -rotation
		sprite.scale = Vector2(base_sprite_scale * breath, base_sprite_scale * breath * squash)
		var foot_offset := pig_radius - sprite.texture.get_height() * sprite.scale.y * 0.5
		sprite.position = (shake + Vector2(0.0, foot_offset)).rotated(-rotation)

func take_damage() -> void:
	pig_hp -= 1
	flash = 1.0
	if pig_hp <= 0:
		_die(false)

func _die(out_of_world: bool) -> void:
	is_dead = true
	died.emit(SSConfig.PIG_SCORE, global_position)
	if not out_of_world:
		_burst(Color("dca0ea"))
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.22)
		tween.tween_callback(queue_free)
	else:
		queue_free()

## 消散碎片：挂在父节点上的临时容器，独立于猪本体 tween，飞散后自毁。
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
		bit.color = tint.lightened(randf_range(0.0, 0.30))
		burst.add_child(bit)
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 8.0 + randf_range(-0.25, 0.25))
		var distance: float = randf_range(14.0, 28.0)
		var tween := burst.create_tween()
		tween.set_parallel(true)
		tween.tween_property(bit, "position", bit.position + dir * distance, 0.34)
		tween.tween_property(bit, "modulate:a", 0.0, 0.34)
		tween.chain().tween_callback(burst.queue_free)
