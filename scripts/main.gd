extends Node2D

## 主编排：关卡构建、引力施加、发射输入、镜头跟随、比分与胜负结算。
## 太空版引力语义：引力圈内恒定向心加速度，圈外零重力；
## 弹道预览与运行时使用同一套加速度计算，所见即所得。

const PLANET_ART_BY_LEVEL := [
	[SSPlanet.Surface.COBALT, SSPlanet.Surface.SANDSTONE],
	[SSPlanet.Surface.COBALT, SSPlanet.Surface.SANDSTONE, SSPlanet.Surface.AMETHYST],
	[SSPlanet.Surface.COBALT, SSPlanet.Surface.AMETHYST, SSPlanet.Surface.SANDSTONE],
	[SSPlanet.Surface.COBALT, SSPlanet.Surface.AMETHYST, SSPlanet.Surface.SANDSTONE],
	[SSPlanet.Surface.COBALT, SSPlanet.Surface.SANDSTONE],
	[SSPlanet.Surface.COBALT, SSPlanet.Surface.SANDSTONE, SSPlanet.Surface.AMETHYST],
]
const SKY_TINTS := [Color.WHITE, Color("edcddc"), Color("c4caff"), Color("cfeaff"), Color("ffe9cf"), Color("dcc8ff")]
const AIM_TINTS := [Color("b3ffeb"), Color("ffe0a7"), Color("e0c5ff"), Color("b3ecff"), Color("ffd9b3"), Color("e8c5ff")]

const SAVE_PATH := "user://space_slingers.cfg"

enum Phase {AIMING, FLYING, SETTLING, RESULT}

## 关卡索引跨场景重载保留（重试/下一关不丢进度）
static var current_level := 0

var level: SSLevelData
var planets: Array[SSPlanet] = []
var pigs: Array[SSPig] = []
var block_nodes: Array[SSBlock] = []   ## 预览遮挡判定用（弹道遇建筑应截断，而非穿过）
var sling: SSSling
var bird: SSBird
var fx: SSFxOverlay
var starfield: SSStarfield
var hud: SSHud
var login_screen: SSLoginScreen
var level_select: SSLevelSelect
var camera: Camera2D
var level_start_msec := 0

var phase: int = Phase.AIMING
var dragging := false
var bird_queue: Array[String] = []       ## 待发射的鸟种队列（关卡下发）
var active_birds: Array[SSBird] = []    ## 空中所有活鸟（分裂后 >1）
var shots_used := 0
var score := 0
var best_score := 0
var settle_timer := 0.0
var win_pending := 0.0
var zoom_factor := 1.0
var shake_amount := 0.0
var camera_pan := Vector2.ZERO
var pan_button := MOUSE_BUTTON_NONE
var trail: Array[Vector2] = []
var trail_counter := 0

func _ready() -> void:
	add_child(SSTransport.new())
	if SSTransport.session_token.is_empty() and not SSLevelSelect.skip_next:
		_show_login()
	else:
		_start_session()

func _show_login() -> void:
	login_screen = SSLoginScreen.new()
	add_child(login_screen)
	login_screen.login_requested.connect(_on_login_requested)
	login_screen.offline_pressed.connect(_on_offline_pressed)

func _on_login_requested(username: String, password: String) -> void:
	var result: Dictionary = await SSLoginAPI.new(username, password).send()
	if not result.ok:
		login_screen.show_error(str(result.message))
		return
	login_screen.queue_free()
	login_screen = null
	_start_session()

func _on_offline_pressed() -> void:
	login_screen.queue_free()
	login_screen = null
	_start_session()

## 登录后流程：进选关页（或直达目标关）→ 下发关卡（失败回退本地）→ 构建世界 → 读取最好分
func _start_session() -> void:
	if SSLevelSelect.skip_next:
		SSLevelSelect.skip_next = false
		await _enter_level()
	else:
		_show_level_select()

func _enter_level() -> void:
	await _fetch_level()
	_load_level()
	await _fetch_record()

func _show_level_select() -> void:
	if level_select == null:
		level_select = SSLevelSelect.new()
		add_child(level_select)
		level_select.level_selected.connect(_on_level_selected)
		level_select.close_requested.connect(_on_select_close)
	level_select.open()
	get_tree().paused = hud != null and phase != Phase.RESULT

func _on_level_selected(index: int) -> void:
	current_level = index
	get_tree().paused = false
	_restart()

func _on_select_close() -> void:
	if hud == null:
		get_tree().change_scene_to_file(SSModeSelect.SCENE_MENU)
		return
	level_select.hide()
	get_tree().paused = false

func _on_levels_pressed() -> void:
	if get_tree().paused:
		return
	_show_level_select()

func _fetch_level() -> void:
	if SSTransport.session_token.is_empty():
		level = SSLevels.build(current_level)
		return
	var result: Dictionary = await SSGetLevelDefinitionAPI.new(_level_id()).send()
	if result.ok:
		level = SSLevelCodec.from_dict(result.data)   # 与离线共用同一解析器
	else:
		level = SSLevels.build(current_level)

func _level_id() -> String:
	return "level-%02d" % (current_level + 1)

func _fetch_record() -> void:
	if SSTransport.session_token.is_empty():
		return
	var result: Dictionary = await SSLoadProgressAPI.new(_level_id()).send()
	if result.ok and bool(result.data.get("completed", false)):
		hud.set_hint(level.level_name, "%s · 服务器最好分 %d" % [level.hint, int(result.data.get("bestScore", 0))])

func _submit_result(completed: bool, unused: int) -> void:
	if SSTransport.session_token.is_empty():
		hud.set_result_extra("离线模式 · 成绩未提交")
		return
	var used := level.birds - unused
	var submit: Dictionary = await SSSubmitLevelResultAPI.new(
		_level_id(), completed, score, used, elapsed_total()).send()
	if not submit.ok:
		hud.set_result_extra("⚠ 成绩未提交（%s）" % str(submit.message))
		return
	var board: Dictionary = await SSGetLeaderboardAPI.new(_level_id(), 3).send()
	var rank: Dictionary = await SSGetPlayerRankAPI.new(_level_id()).send()
	if board.ok and rank.ok:
		var lines: Array[String] = []
		for entry in board.data.get("entries", []):
			lines.append("%d. %s %d" % [int(entry.get("rank", 0)), str(entry.get("username", "")), int(entry.get("score", 0))])
		lines.append("我的名次：第 %d 名" % int(rank.data.get("rank", 0)))
		hud.set_result_extra("\n".join(lines))
	else:
		hud.set_result_extra("成绩已提交 · 排行榜暂不可用")

func elapsed_total() -> float:
	return maxf(float(Time.get_ticks_msec() - level_start_msec) / 1000.0, 0.001)

func _on_retry_pressed() -> void:
	_restart()

func _on_next_pressed() -> void:
	current_level = clampi(current_level + 1, 0, SSLevels.count() - 1)
	_restart()

func _on_pause_pressed() -> void:
	get_tree().paused = true
	hud.show_paused(true)

func _on_resume_pressed() -> void:
	get_tree().paused = false
	hud.show_paused(false)

func _on_zoom_changed(delta: float) -> void:
	zoom_factor = clampf(zoom_factor + delta, 0.55, 1.6)

func _restart() -> void:
	SSLevelSelect.skip_next = true   # 重试/下一关/R/选关直达：不绕选关页
	get_tree().paused = false
	get_tree().reload_current_scene()

func _load_level() -> void:
	best_score = _load_best(current_level)
	score = 0
	shots_used = 0
	zoom_factor = 1.0
	level_start_msec = Time.get_ticks_msec()

	camera = Camera2D.new()
	camera.position = level.camera_anchor
	camera.zoom = Vector2.ONE * level.camera_zoom
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	add_child(camera)
	camera.make_current()

	starfield = SSStarfield.new()
	add_child(starfield)
	var art_index := clampi(current_level, 0, PLANET_ART_BY_LEVEL.size() - 1)
	var planet_art: Array = PLANET_ART_BY_LEVEL[art_index]
	starfield.setup(level.world_size, level.seed_value, true)
	starfield.paint_tint = SKY_TINTS[art_index]

	fx = SSFxOverlay.new()
	add_child(fx)
	fx.setup(level.world_size, level.seed_value)
	fx.dotted_preview = true
	fx.dotted_color = AIM_TINTS[art_index]

	for planet_index in level.planets.size():
		var planet := SSPlanet.new()
		add_child(planet)
		planet.setup(level.planets[planet_index])
		if planet_index < planet_art.size():
			planet.set_painted_surface(planet_art[planet_index])
		planets.append(planet)

	for block_data in level.blocks:
		var block := SSBlock.new()
		var transform_data: Dictionary
		if block_data.get("pos") != null:
			# 绝对坐标：精确堆叠结构（塔楼/横梁/斜撑）
			transform_data = {
				"position": block_data["pos"],
				"rotation": block_data.get("rotation", 0.0),
			}
		else:
			var planet: Dictionary = level.planets[block_data["planet"]]
			var lift: float = block_data.get("lift", 3.0)
			transform_data = SSPlace.standing_transform(planet, block_data["angle"], lift, block_data["size"]) \
					if block_data.get("axis", "radial") == "radial" \
					else SSPlace.lying_transform(planet, block_data["angle"], lift, block_data["size"])
		block.setup({
			"material": block_data["material"],
			"size": block_data["size"],
			"position": transform_data["position"],
			"rotation": transform_data["rotation"],
			"structural": block_data.get("structural", false),
		})
		add_child(block)
		block.destroyed.connect(_on_block_destroyed.bind(block.block_color))
		block_nodes.append(block)

	for pig_data in level.pigs:
		var pig := SSPig.new()
		pig.setup({
			"position": SSPlace.pig_position(level.planets[pig_data["planet"]], pig_data["angle"], pig_data["radius"]),
			"radius": pig_data["radius"],
			"hp": pig_data["hp"],
		})
		add_child(pig)
		pig.died.connect(_on_pig_died)
		pigs.append(pig)

	sling = SSSling.new()
	add_child(sling)
	sling.setup(level.slingshot)
	sling.industrial_art = true

	hud = SSHud.new()
	hud.brass_theme = true
	if current_level == 1:
		hud.brass_score_position = Vector2(490, 14)
	add_child(hud)
	hud.set_hint(level.level_name, level.hint)
	hud.set_score(score, best_score)
	# HUD 在此处创建，信号连接必须跟在创建后（不能放 _ready：登录流程下 HUD 更晚）
	hud.retry_pressed.connect(_on_retry_pressed)
	hud.next_pressed.connect(_on_next_pressed)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.resume_pressed.connect(_on_resume_pressed)
	hud.zoom_changed.connect(_on_zoom_changed)
	hud.levels_pressed.connect(_on_levels_pressed)

	bird_queue = level.bird_types.duplicate()
	if bird_queue.is_empty():
		for i in level.birds:
			bird_queue.append("normal")
	_spawn_bird()

## ---------- 引力与物理 ----------

func _physics_process(delta: float) -> void:
	_apply_gravity_fields()
	if is_instance_valid(bird) and bird.bird_state == SSBird.BirdState.FLYING:
		_record_trail()
		_check_bird_bounds()
	if phase == Phase.SETTLING:
		settle_timer -= delta
		if settle_timer <= 0.0:
			_after_settle()
	if win_pending > 0.0:
		win_pending -= delta
		if win_pending <= 0.0:
			_do_win()
	_check_pig_bounds()

## 引力施加：遍历场景所有刚体，用与预览完全相同的纯距离函数（SSGravity）计算——
## 不经 Area2D 重叠门禁（有一物理帧延迟），自由飞行段与预测严格全等。
## 圈外时函数本身返回零，门禁天然存在。
func _apply_gravity_fields() -> void:
	for child in get_children():
		var rigid := child as RigidBody2D
		if rigid == null or rigid.freeze:
			continue
		var accel := SSGravity.total_acceleration(planets, rigid.global_position)
		rigid.apply_central_force(accel * rigid.mass)

func _record_trail() -> void:
	trail_counter += 1
	if trail_counter % 2 == 0:
		trail.append(bird.global_position)
		if trail.size() > 90:
			trail.remove_at(0)
		fx.set_trail(trail)

func _check_bird_bounds() -> void:
	var margin := 320.0
	if bird.global_position.x < -margin or bird.global_position.x > level.world_size.x + margin \
			or bird.global_position.y < -margin or bird.global_position.y > level.world_size.y + margin:
		bird.poof()

func _check_pig_bounds() -> void:
	var margin := 260.0
	for pig in pigs.duplicate():
		if pig.is_dead:
			pigs.erase(pig)
			continue
		if pig.global_position.x < -margin or pig.global_position.x > level.world_size.x + margin \
				or pig.global_position.y < -margin or pig.global_position.y > level.world_size.y + margin:
			pigs.erase(pig)
			pig.kill(true)

## ---------- 发射输入 ----------

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or phase == Phase.RESULT or level == null or sling == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == pan_button and not event.pressed:
			pan_button = MOUSE_BUTTON_NONE
			return
		if pan_button != MOUSE_BUTTON_NONE:
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed and not dragging:
			pan_button = MOUSE_BUTTON_MIDDLE
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if phase == Phase.FLYING and _try_special():
					return
				if phase == Phase.AIMING and is_instance_valid(bird) \
						and _world_mouse(event.position).distance_to(bird.global_position) < 72.0:
					dragging = true
				else:
					pan_button = MOUSE_BUTTON_LEFT
			elif dragging:
				dragging = false
				if _launch_velocity(bird.position).length() < SSConfig.MAX_LAUNCH_SPEED * 0.06:
					bird.position = sling.position + sling.anchor
					sling.set_pouch(null)
					fx.set_preview([])
				else:
					_launch()
			return
	if event is InputEventMouseMotion:
		if dragging:
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_update_pull(_world_mouse(event.position))
			else:
				dragging = false
				bird.position = sling.position + sling.anchor
				sling.set_pouch(null)
				fx.set_preview([])
		elif pan_button != MOUSE_BUTTON_NONE:
			var button_mask := MOUSE_BUTTON_MASK_LEFT if pan_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
			if event.button_mask & button_mask:
				_pan_camera(event.relative)
			else:
				pan_button = MOUSE_BUTTON_NONE
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_factor = clampf(zoom_factor - 0.08, 0.55, 1.6)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_factor = clampf(zoom_factor + 0.08, 0.55, 1.6)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_restart()

func _world_mouse(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _pan_camera(relative: Vector2) -> void:
	var limits: Vector2 = level.world_size * 0.25
	var next_position := (camera.position - relative / camera.zoom).clamp(limits, limits * 3.0)
	camera_pan += next_position - camera.position
	camera.position = next_position
	camera.reset_smoothing()

func _update_pull(mouse_world: Vector2) -> void:
	var pull: Vector2 = (mouse_world - (sling.position + sling.anchor)).limit_length(SSConfig.MAX_PULL)
	var bird_position: Vector2 = SSPlace.keep_out_of_planets(sling.position + sling.anchor + pull, planets)
	bird.position = bird_position
	sling.set_pouch(bird_position)
	fx.set_preview(_simulate_preview(bird_position), _launch_velocity(bird_position), sling.position + sling.anchor)

func _launch() -> void:
	var bird_position: Vector2 = bird.position
	var velocity := _launch_velocity(bird_position)
	sling.set_pouch(null)
	fx.set_preview([])
	shots_used += 1
	bird.launch(velocity)
	phase = Phase.FLYING
	trail = []
	fx.set_trail(trail)

func _launch_velocity(bird_position: Vector2) -> Vector2:
	var pull: Vector2 = (sling.position + sling.anchor) - bird_position
	return (pull * SSConfig.LAUNCH_POWER).limit_length(SSConfig.MAX_LAUNCH_SPEED)

## 弹道预览：与运行时同一套加速度语义（SSGravity 同源）
func _acceleration_at(position: Vector2) -> Vector2:
	var accel := Vector2.ZERO
	for planet in planets:
		accel += SSGravity.acceleration_at_body(planet.planet_center,
			planet.planet_radius, planet.field_radius, planet.strength, position)
	return accel

func _simulate_preview(bird_position: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var position: Vector2 = bird_position
	var velocity: Vector2 = _launch_velocity(bird_position)
	for i in SSConfig.PREVIEW_STEPS:
		velocity = (velocity + _acceleration_at(position) * SSConfig.PHYSICS_DT).limit_length(SSConfig.MAX_FLIGHT_SPEED)
		position += velocity * SSConfig.PHYSICS_DT
		if _hits_planet(position):
			points.append(position)
			break
		if _hits_obstacle(position):
			points.append(position)
			break
		if i % 5 == 0:
			points.append(position)
	return points

## 弹道撞到建筑或猪就截断预测（预览不能假装能穿过结构）
func _hits_obstacle(position: Vector2) -> bool:
	for block in block_nodes:
		if not is_instance_valid(block) or block.hp <= 0:
			continue
		var half: float = maxf(block.rect_size.x, block.rect_size.y) * 0.5
		if position.distance_to(block.global_position) < half + SSConfig.BIRD_RADIUS:
			return true
	for pig in pigs:
		if pig.is_dead:
			continue
		if position.distance_to(pig.global_position) < pig.pig_radius + SSConfig.BIRD_RADIUS:
			return true
	return false

func _hits_planet(position: Vector2) -> bool:
	for planet in planets:
		if position.distance_to(planet.planet_center) < planet.planet_radius + SSConfig.BIRD_RADIUS:
			return true
	return false

## ---------- 回合流转 ----------

const KIND_NAMES := {
	"normal": "红色普通鸟",
	"split": "蓝色分裂鸟 · 飞行中点击 = 一分为三",
	"dash": "黄色加速鸟 · 飞行中点击 = 瞬间冲刺",
}

func _spawn_bird() -> void:
	if bird_queue.is_empty():
		return
	var kind: String = bird_queue.pop_front()
	bird = SSBird.new()
	bird.bird_kind = kind
	add_child(bird)
	bird.position = sling.position + sling.anchor
	bird.spent.connect(_on_bird_spent.bind(bird))
	active_birds.append(bird)
	var queue: Array[Dictionary] = []
	for i in bird_queue.size():
		queue.append({
			"pos": sling.position + Vector2(-58 - i * 34, -16),
			"kind": bird_queue[i],
		})
	fx.set_queue(queue)
	hud.set_birds(bird_queue.size() + 1, KIND_NAMES.get(kind, "红色普通鸟"))
	phase = Phase.AIMING

func _on_bird_spent(spent_bird: SSBird) -> void:
	active_birds.erase(spent_bird)
	if active_birds.is_empty():
		phase = Phase.SETTLING
		settle_timer = 1.5
	elif bird == spent_bird and is_instance_valid(active_birds[0]):
		bird = active_birds[0]

func _try_special() -> bool:
	for b in active_birds:
		if is_instance_valid(b) and b.can_special():
			if b.bird_kind == "dash":
				b.special_used = true
				b.dash()
				add_shake(6.0)
				_spawn_shockwave(b.global_position, Color("f3b23a"), 0.7)
				return true
			if b.bird_kind == "split":
				_split_bird(b)
				return true
	return false

## 分裂：原鸟继续飞行，沿速度方向 ±12.6° 各生成一只克隆鸟
func _split_bird(source: SSBird) -> void:
	source.special_used = true
	var v := source.linear_velocity
	if v.length() < 10.0:
		return
	_spawn_shockwave(source.global_position, Color("3f8fd9"), 0.8)
	add_shake(4.0)
	for angle in [-0.22, 0.22]:
		var clone := SSBird.new()
		clone.bird_kind = source.bird_kind
		clone.special_used = true
		add_child(clone)
		clone.global_position = source.global_position
		clone.launch(v.rotated(angle))
		clone.spent.connect(_on_bird_spent.bind(clone))
		active_birds.append(clone)

func _after_settle() -> void:
	if pigs.is_empty():
		return # 胜利流程由 win_pending 接管
	if not bird_queue.is_empty():
		_spawn_bird()
	else:
		_do_lose()

func _on_block_destroyed(score_value: int, at_position: Vector2, block_color: Color) -> void:
	_add_score(score_value, at_position)
	_spawn_debris(at_position, block_color, 7, 200.0, 7.0)
	_spawn_shockwave(at_position, block_color, 1.0)
	add_shake(5.0)

func _on_pig_died(score_value: int, at_position: Vector2) -> void:
	for pig in pigs.duplicate():
		if pig.is_dead:
			pigs.erase(pig)
	_add_score(score_value, at_position)
	_spawn_debris(at_position, Color("dca0ea"), 10, 260.0, 8.0)
	_spawn_shockwave(at_position, Color("dca0ea"), 1.6)
	add_shake(11.0)
	_spawn_popup("+%d" % score_value, at_position, Color("dca0ea"))
	if pigs.is_empty() and phase != Phase.RESULT and win_pending <= 0.0:
		win_pending = 1.0

func _add_score(value: int, at_position: Vector2) -> void:
	score += value
	hud.set_score(score, maxf(best_score, score))
	_spawn_popup("+%d" % value, at_position, Color.WHITE)

func _spawn_popup(text: String, world_position: Vector2, color: Color) -> void:
	var popup := SSPopup.new()
	add_child(popup)
	popup.setup(text, world_position, color)

## ---------- 表现层：碎片 / 冲击波 / 镜头震动 ----------

func _spawn_debris(at: Vector2, color: Color, count: int, spread: float, size: float) -> void:
	var burst := SSDebrisBurst2D.new()
	burst.position = to_local(at)
	burst.setup(color, count, spread, size)
	add_child.call_deferred(burst)

func _spawn_shockwave(at: Vector2, color: Color, scale_factor: float) -> void:
	var wave := SSShockwave2D.new()
	add_child(wave)
	wave.global_position = at
	wave.setup(color, scale_factor)

func add_shake(strength: float) -> void:
	shake_amount = minf(shake_amount + strength, 26.0)

func _do_win() -> void:
	if phase == Phase.RESULT:
		return
	phase = Phase.RESULT
	var unused: int = level.birds - shots_used
	var bonus: int = unused * SSConfig.BLOCK_BONUS_PER_BIRD
	if bonus > 0:
		score += bonus
		hud.set_score(score, maxf(best_score, score))
		if bird != null:
			_spawn_popup("+%d" % bonus, bird.global_position, SSConfig.COLOR_SCORE)
	if score > best_score:
		best_score = score
	_save_clear(current_level, best_score, shots_used)
	var stars := level.earned_stars(score, true, shots_used)
	var is_final: bool = current_level >= SSLevels.count() - 1
	var detail := "总分 %d · 发射 %d 次 · 余鸟奖励 +%d · 最高分 %d" % [score, shots_used, bonus, best_score]
	hud.set_score(score, best_score)
	hud.show_result(true, detail, is_final, stars)
	_submit_result(true, unused)

func _do_lose() -> void:
	if phase == Phase.RESULT:
		return
	phase = Phase.RESULT
	var alive := pigs.size()
	hud.show_result(false, "还剩 %d 只太空猪 · 总分 %d · 最高分 %d" % [alive, score, best_score], false)
	_submit_result(false, 0)

## ---------- 镜头 ----------

func _process(delta: float) -> void:
	if level == null or camera == null:
		return
	var target: Vector2 = level.camera_anchor + camera_pan
	if is_instance_valid(bird) and bird.bird_state == SSBird.BirdState.FLYING:
		target = bird.global_position + camera_pan
	if pan_button == MOUSE_BUTTON_NONE and not dragging:
		camera.position = camera.position.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	var view: Vector2 = level.world_size
	camera.position.x = clampf(camera.position.x, view.x * 0.25, view.x * 0.75)
	camera.position.y = clampf(camera.position.y, view.y * 0.25, view.y * 0.75)
	var target_zoom: Vector2 = Vector2.ONE * (level.camera_zoom * zoom_factor)
	camera.zoom = camera.zoom.lerp(target_zoom, clampf(delta * 6.0, 0.0, 1.0))
	shake_amount = maxf(shake_amount - delta * 70.0, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount if shake_amount > 0.05 \
		else Vector2.ZERO

## ---------- 最高分存档 ----------

func _load_best(index: int) -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value("best", str(index), 0))

func _save_clear(index: int, value: int, shots: int) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	var key := str(index)
	config.set_value("best", key, value)
	var previous := int(config.get_value("min_shots", key, 0))
	if shots > 0 and (previous <= 0 or shots < previous):
		config.set_value("min_shots", key, shots)
	config.save(SAVE_PATH)

