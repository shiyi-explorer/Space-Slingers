extends Node3D

## 3D 主编排：俯视 45° 相机（可缩放/旋转）、发射（XZ 平面）、
## 引力（SSGravity 平滑过渡）、回合与比分。
## 物理语义与 2D 版完全一致：圈内有效引力平滑增强、圈外零重力、碰到就死。

const MOUSE_TO_WORLD_Y := 0.0

enum Phase {AIMING, FLYING, SETTLING, RESULT}

static var current_level := 0

var level: SSLevelData
var planets: Array[SSPlanet3D] = []
var gravity_planets: Array[Dictionary] = []   ## 牛顿引力源：{planet_center, planet_radius, strength}
var gravity_bodies: Array[RigidBody3D] = []   ## 受引力体注册表：小鸟/方块/猪，无边界开关
var pigs: Array[SSPig3D] = []
var sling: SSSling3D
var bird: SSBird3D
var active_birds: Array[SSBird3D] = []   ## 空中所有活鸟（分裂后会大于 1）
var bird_queue: Array[String] = []       ## 待发射的鸟种队列（关卡数据下发）

var hud: SSHud
var login_screen: SSLoginScreen
var level_select: SSLevelSelect
var camera: Camera3D
var preview_node: Node3D
var trail_node: Node3D
var trail_points: Array[Vector3] = []
var trail_counter := 0

var phase: int = Phase.AIMING
var dragging := false
var camera_dragging := false
var camera_last_mouse := Vector2.ZERO
var aim_velocity := Vector3.ZERO        ## 本轮瞄准的发射速度（预览/发射共用）
var aim_elevation := 12.0               ## 发射仰角（世界系，度）：拉弓中滚轮调整，上限 60 可飞越行星顶
var shots_used := 0
var score := 0
var best_score := 0
var settle_timer := 0.0
var win_pending := 0.0
var zoom_factor := 0.58     ## 默认拉近：行星在画面里更大、建筑看得清
var level_start_msec := 0   ## 本关开始时刻；成绩提交的时长用（不能用引擎启动绝对时间）
var cam_yaw := -0.35
var shake_amount := 0.0
const CAM_DIST := 950.0
var cam_pitch := 0.45
const SAVE_PATH := "user://space_slingers.cfg"

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

## 登录后流程：进选关页（或直达目标关）→ 下发关卡 → 构建世界 → 读取最好分
func _start_session() -> void:
	if SSLevelSelect.skip_next:
		SSLevelSelect.skip_next = false
		await _enter_level()
	else:
		_show_level_select()

func _enter_level() -> void:
	await _fetch_level()
	_build_world()
	await _fetch_record()

func _show_level_select() -> void:
	if level_select == null:
		level_select = SSLevelSelect.new()
		add_child(level_select)
		level_select.level_selected.connect(_on_level_selected)
		level_select.close_requested.connect(_on_select_close)
	level_select.open()
	# 游戏中途呼出时暂停世界（选关页 PROCESS_MODE_ALWAYS 不受影响）；开局呼出无世界可暂停
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

func _restart() -> void:
	SSLevelSelect.skip_next = true   # 重试/下一关/R/选关直达：不绕选关页
	get_tree().paused = false
	get_tree().reload_current_scene()

func _fetch_level() -> void:
	if SSTransport.session_token.is_empty():
		level = SSLevels.build(current_level)
		return
	var result: Dictionary = await SSGetLevelDefinitionAPI.new(_level_id()).send()
	if result.ok:
		level = _level_from_server(result.data)
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

func _level_from_server(definition: Dictionary) -> SSLevelData:
	# 与离线加载共用同一解析器，线上线下天然一致（含 lat 等所有字段）
	return SSLevelCodec.from_dict(definition)

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
	zoom_factor = clampf(zoom_factor + delta, 0.35, 1.8)

func _build_world() -> void:
	if level == null:
		level = SSLevels.build(current_level)
	best_score = _load_best(current_level)
	shots_used = 0
	score = 0
	zoom_factor = 0.58       # 重试/下一关卡重置为默认拉近视角，避免累积
	level_start_msec = Time.get_ticks_msec()

	# 环境（Bloom 辉光：行星/引力圈/星星全是自发光材质，免费提升画面档次）
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SSConfig.COLOR_SPACE
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.05
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.4
	add_child(light)

	# 相机（俯视 45°，鼠标拖拽旋转）
	camera = Camera3D.new()
	add_child(camera)
	var pose := _desired_transform()
	camera.position = pose[0]
	camera.look_at(pose[1])
	camera.make_current()

	# 星空
	_build_stars()

	# 行星（Vector3 中心）+ 引力源注册
	for planet_data in level.planets:
		var planet := SSPlanet3D.new()
		add_child(planet)
		planet.setup({
			"center": Vector3(planet_data["center"].x, 0, planet_data["center"].y),
			"radius": planet_data["radius"],
			"field": planet_data["field"],
			"strength": planet_data["strength"],
			"base": planet_data["base"],
			"highlight": planet_data["highlight"],
		})
		planets.append(planet)
		gravity_planets.append({
			"planet_center": Vector3(planet_data["center"].x, 0, planet_data["center"].y),
			"planet_radius": planet_data["radius"],
			"strength": planet_data["strength"],
			"field_radius": planet_data["field"],
		})

	# 方块与猪（3D 放置几何）
	# 塔楼支持两套坐标：优先用关卡的绝对世界坐标 pos（2D/3D 共用同一份关卡数据），
	# 平铺到 XZ 平面（2D 的 x→3D 的 x，2D 的 y→3D 的 z），法线取离它最近行星的径向；
	# 没有 pos 的旧关才回退到球面坐标 planet/angle/lat。
	for block_data in level.blocks:
		var block := SSBlock3D.new()
		var transform_data: Dictionary = _block_transform(block_data)
		block.setup({
			"material": block_data["material"],
			"size": block_data["size"],
			"position": transform_data["position"],
			"normal": transform_data["normal"],
		})
		add_child(block)
		block.destroyed.connect(_on_block_destroyed.bind(block.block_color))
		gravity_bodies.append(block)

	for pig_data in level.pigs:
		var pig := SSPig3D.new()
		pig.setup({
			"position": SSPlace3D.pig_position(_planet_dict(pig_data["planet"]),
				pig_data["angle"], pig_data.get("lat", 0.0), pig_data["radius"]),
			"radius": pig_data["radius"],
			"hp": pig_data["hp"],
		})
		add_child(pig)
		pig.died.connect(_on_pig_died)
		pigs.append(pig)
		gravity_bodies.append(pig)

	sling = SSSling3D.new()
	add_child(sling)
	sling.setup(Vector3(level.slingshot.x, 0, level.slingshot.y))

	hud = SSHud.new()
	add_child(hud)
	hud.set_hint(level.level_name, level.hint)
	hud.set_score(score, best_score)
	# HUD 每次构建世界时新建，信号连接必须在此处完成（不能放 _ready：登录流程下 HUD 创建晚于 _ready）
	hud.retry_pressed.connect(_on_retry_pressed)
	hud.next_pressed.connect(_on_next_pressed)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.resume_pressed.connect(_on_resume_pressed)
	hud.zoom_changed.connect(_on_zoom_changed)
	hud.levels_pressed.connect(_on_levels_pressed)

	# 预览/轨迹显示节点
	preview_node = SSAimPreview.new()
	add_child(preview_node)
	trail_node = Node3D.new()
	add_child(trail_node)

	bird_queue = level.bird_types.duplicate()
	if bird_queue.is_empty():
		for i in level.birds:
			bird_queue.append("normal")
	_spawn_bird()

func _planet_dict(index: int) -> Dictionary:
	var data: Dictionary = level.planets[index]
	return {
		"planet_center": planets[index].planet_center,
		"planet_radius": data["radius"],
		"field_radius": data["field"],
		"strength": data["strength"],
	}

## 方块放置：pos 绝对坐标优先（2D/3D 同源关卡），映射到 XZ 平面。
## 2D 屏幕 x→3D x，2D 屏幕 y→3D z；法线为方块指向最近行星球心的径向反方向，
## 这样塔楼"立"在球面外侧，与 2D 里立在球面上方的视觉一致。
func _block_transform(block_data: Dictionary) -> Dictionary:
	var pos_variant: Variant = block_data.get("pos")
	if pos_variant is Vector2:
		var xz := Vector3(pos_variant.x, 0.0, pos_variant.y)
		# 找球心最近的实体行星（跳过弹弓小行星：塔楼都建在目标行星上）
		var best_center: Vector3 = Vector3.ZERO
		var best_radius := 0.0
		var best_dist := INF
		for i in planets.size():
			if i == 0 and planets.size() > 1:
				continue   # 弹弓底座小行星不承载塔楼
			var c: Vector3 = planets[i].planet_center
			var d: float = xz.distance_to(c)
			if d < best_dist:
				best_dist = d
				best_center = c
				best_radius = level.planets[i]["radius"]
		var n: Vector3 = (xz - best_center).normalized() if xz.distance_to(best_center) > 0.001 else Vector3.UP
		# 若方块中心落在球面内，抬到球外避免穿模（保持与 2D 一致的堆叠高度语义）
		var min_dist: float = best_radius + block_data["size"].y * 0.5 + 2.0
		if best_dist < min_dist:
			xz = best_center + n * min_dist
		return {"position": xz, "normal": n}
	# 旧关回退：球面坐标 planet/angle/lat
	var planet: Dictionary = _planet_dict(block_data["planet"])
	var lift: float = block_data.get("lift", 3.0)
	var lat: float = block_data.get("lat", 0.0)
	return SSPlace3D.standing_transform(planet, block_data["angle"], lat, lift, block_data["size"]) \
			if block_data.get("axis", "radial") == "radial" \
			else SSPlace3D.lying_transform(planet, block_data["angle"], lat, lift, block_data["size"])

func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = level.seed_value
	for i in 130:
		var star := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var size := rng.randf_range(1.2, 2.8)
		mesh.radius = size
		mesh.height = size * 2.0
		star.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(SSConfig.COLOR_STAR.r, SSConfig.COLOR_STAR.g, SSConfig.COLOR_STAR.b, 0.8)
		material.emission_enabled = true
		material.emission = SSConfig.COLOR_STAR
		material.emission_energy_multiplier = 0.8
		material.no_depth_test = true
		star.material_override = material
		star.position = Vector3(
			rng.randf_range(-level.world_size.x * 0.2, level.world_size.x * 1.2),
			rng.randf_range(-60, 240),
			rng.randf_range(-level.world_size.y * 0.3, level.world_size.y * 1.1))
		star.scale = Vector3.ONE * rng.randf_range(0.5, 1.4)
		add_child(star)

## ---------- 引力 ----------

func _physics_process(delta: float) -> void:
	if level == null or camera == null:
		return
	_apply_gravity_fields()
	if phase == Phase.FLYING:
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

## 牛顿引力：所有注册刚体（小鸟/方块/猪）全程吃引力。
## 平方反比衰减下，远离行星后引力迅速减弱，塌方不会被"磁铁吸回"；
## 静置结构则被引力压在行星表面坐实，不会浮空。
func _apply_gravity_fields() -> void:
	var index := gravity_bodies.size() - 1
	while index >= 0:
		var body := gravity_bodies[index]
		if not is_instance_valid(body) or body.freeze:
			index -= 1
			continue
		var accel := SSGravity3D.total_acceleration(gravity_planets, body.global_position)
		body.apply_central_force(accel * body.mass)
		index -= 1

## ---------- 发射输入（鼠标 → XZ 平面投影） ----------

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or phase == Phase.RESULT or level == null or camera == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 飞行中点击 = 触发特殊鸟技能（优先于拉弓/转视角）
			if phase == Phase.FLYING and _try_special():
				return
			# 点中小鸟附近 = 经典拉弓；空白处按下 = 旋转视角
			if phase == Phase.AIMING and bird != null \
					and _mouse_world().distance_to(sling.position + sling.anchor) < SSConfig.AIM_GRAB_RADIUS:
				dragging = true
				aim_velocity = Vector3.ZERO
			else:
				camera_dragging = true
				camera_last_mouse = event.position
		elif dragging:
			dragging = false
			# 取消手势：几乎没拉开就松手，不耗鸟
			if aim_velocity.length() < SSConfig.MAX_LAUNCH_SPEED * 0.06:
				bird.position = sling.position + sling.anchor
				sling.set_pouch(null)
				_clear_preview()
				aim_velocity = Vector3.ZERO
				hud.set_aim_power(0.0)
			else:
				_launch()
		elif camera_dragging:
			camera_dragging = false
	elif event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE):
		camera_dragging = event.pressed
		camera_last_mouse = event.position
	elif event is InputEventMouseMotion and dragging:
		_update_pull(_mouse_world())
	elif event is InputEventMouseMotion and camera_dragging:
		var motion: Vector2 = event.position - camera_last_mouse
		camera_last_mouse = event.position
		cam_yaw -= motion.x * 0.008
		cam_pitch = clampf(cam_pitch - motion.y * 0.006, 0.2, 1.45)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if dragging:
			_adjust_elevation(SSConfig.AIM_ELEVATION_STEP)
		else:
			zoom_factor = clampf(zoom_factor - 0.08, 0.35, 1.8)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if dragging:
			_adjust_elevation(-SSConfig.AIM_ELEVATION_STEP)
		else:
			zoom_factor = clampf(zoom_factor + 0.08, 0.35, 1.8)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_restart()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if phase != Phase.RESULT:
				if get_tree().paused:
					_on_resume_pressed()
				else:
					_on_pause_pressed()
		elif event.keycode == KEY_Q:
			cam_yaw -= 0.35
		elif event.keycode == KEY_E:
			cam_yaw += 0.35

func _mouse_world() -> Vector3:
	var plane := Plane(Vector3.UP, Vector3(0, MOUSE_TO_WORLD_Y, 0))
	var result = plane.intersects_ray(
		camera.project_ray_origin(get_viewport().get_mouse_position()),
		camera.project_ray_normal(get_viewport().get_mouse_position()))
	if result is Vector3:
		return result
	return Vector3.ZERO

## 经典拉弓（所用即所见）：鼠标射线投到 XZ 平面，小鸟被拉到鼠标处，
## 松手沿「小鸟 → 锚点」的反方向弹射；拉得越远飞得越快，方向与弹道实时预览。
## 仰角不参与拖拽手势，改由滚轮单独调整（见 _adjust_elevation）。
func _update_pull(mouse_world: Vector3) -> void:
	var anchor: Vector3 = sling.position + sling.anchor
	var pull: Vector3 = mouse_world - anchor
	pull.y = 0.0
	pull = pull.limit_length(SSConfig.MAX_PULL)
	if pull.length() < 1.0:
		return
	var bird_position: Vector3 = SSPlace3D.keep_out_of_planets(anchor + pull, planets)
	bird.position = bird_position
	sling.set_pouch(bird_position)
	_apply_aim(pull)

## 由当前拉距 + 仰角重算发射速度与预览（拖拽、滚轮调仰角共用）。
func _apply_aim(pull: Vector3) -> void:
	var power_ratio: float = clampf(pull.length() / SSConfig.MAX_PULL, 0.0, 1.0)
	if power_ratio < 0.02:
		return
	var horiz: Vector3 = -pull.normalized()   # 小鸟→锚点 = 发射水平方向
	horiz.y = 0.0
	var el := deg_to_rad(aim_elevation)
	aim_velocity = (horiz * cos(el) + Vector3.UP * sin(el)) * power_ratio * SSConfig.MAX_LAUNCH_SPEED
	hud.set_aim_power(power_ratio, aim_elevation)
	_show_preview(bird.position)

## 拉弓中滚轮调仰角：按当前拉距重新计算速度，保持所见即所得的弹道预览。
func _adjust_elevation(delta: float) -> void:
	aim_elevation = clampf(aim_elevation + delta, SSConfig.AIM_ELEVATION_MIN, SSConfig.AIM_ELEVATION_MAX)
	var anchor: Vector3 = sling.position + sling.anchor
	var pull: Vector3 = bird.position - anchor
	pull.y = 0.0
	if pull.length() >= 1.0:
		_apply_aim(pull)
	else:
		hud.set_aim_power(0.0, aim_elevation)

func _launch() -> void:
	var velocity := aim_velocity.limit_length(SSConfig.MAX_LAUNCH_SPEED)
	sling.set_pouch(null)
	hud.set_aim_power(0.0)
	_clear_preview()
	aim_velocity = Vector3.ZERO
	shots_used += 1
	bird.launch(velocity)
	phase = Phase.FLYING
	trail_points = []
	_clear_trail()

## ---------- 弹道预览（与 SSGravity 同源） ----------

func _acceleration_at(position: Vector3) -> Vector3:
	return SSGravity3D.total_acceleration(gravity_planets, position)

func _simulate_preview(bird_position: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var position: Vector3 = bird_position
	var velocity: Vector3 = aim_velocity.limit_length(SSConfig.MAX_LAUNCH_SPEED)
	for i in SSConfig.PREVIEW_STEPS:
		velocity = (velocity + _acceleration_at(position) * SSConfig.PHYSICS_DT).limit_length(SSConfig.MAX_FLIGHT_SPEED)
		position += velocity * SSConfig.PHYSICS_DT
		# 每 2 步采一个点：连续带够密，又不至于 ImmediateMesh 顶点过多
		if _hits_planet(position):
			points.append(position)
			break
		if i % 2 == 0:
			points.append(position)
	return points

func _hits_planet(position: Vector3) -> bool:
	for planet in planets:
		if position.distance_to(planet.planet_center) < planet.planet_radius + SSConfig.BIRD_RADIUS:
			return true
	return false

func _show_preview(bird_position: Vector3) -> void:
	var points: Array[Vector3] = _simulate_preview(bird_position)
	if points.is_empty():
		_clear_preview()
		return
	preview_node.draw(points, points[points.size() - 1], aim_velocity)

func _clear_preview() -> void:
	preview_node.clear()

func _record_trail() -> void:
	trail_counter += 1
	if trail_counter % 2 == 0:
		trail_points.append(bird.global_position)
		if trail_points.size() > 90:
			trail_points.remove_at(0)
		_refresh_trail()

func _refresh_trail() -> void:
	_clear_trail()
	for i in trail_points.size():
		var alpha := (float(i) + 1.0) / float(trail_points.size()) * 0.75
		var dot := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 3.2
		mesh.height = 6.4
		dot.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1, 1, 1, alpha)
		material.emission_enabled = true
		material.emission = Color.WHITE
		material.emission_energy_multiplier = alpha
		material.no_depth_test = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot.material_override = material
		dot.position = trail_points[i]
		trail_node.add_child(dot)

func _clear_trail() -> void:
	for child in trail_node.get_children():
		child.queue_free()

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
	bird = SSBird3D.new()
	bird.bird_kind = kind
	add_child(bird)
	bird.position = sling.position + sling.anchor
	bird.spent.connect(_on_bird_spent.bind(bird))
	gravity_bodies.append(bird)
	active_birds.append(bird)
	hud.set_birds(bird_queue.size() + 1, KIND_NAMES.get(kind, "红色普通鸟"))
	hud.set_aim_power(0.0)
	phase = Phase.AIMING

func _on_bird_spent(spent_bird: SSBird3D) -> void:
	active_birds.erase(spent_bird)
	if active_birds.is_empty():
		phase = Phase.SETTLING
		settle_timer = 1.5
	elif bird == spent_bird and is_instance_valid(active_birds[0]):
		bird = active_birds[0]   # 主鸟消散后镜头跟随剩余鸟

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

## 分裂：原鸟继续飞行，沿速度方向的垂直轴 ±12.6° 各生成一只克隆鸟
func _split_bird(source: SSBird3D) -> void:
	source.special_used = true
	var v := source.linear_velocity
	if v.length() < 10.0:
		return
	var side := Vector3.UP.cross(v)
	if side.length() < 0.01:
		side = Vector3.RIGHT.cross(v)
	side = side.normalized()
	_spawn_shockwave(source.global_position, Color("3f8fd9"), 0.8)
	add_shake(4.0)
	for angle in [-0.22, 0.22]:
		var clone := SSBird3D.new()
		clone.bird_kind = source.bird_kind
		clone.special_used = true
		add_child(clone)
		clone.global_position = source.global_position
		clone.launch(v.rotated(side, angle))
		clone.spent.connect(_on_bird_spent.bind(clone))
		active_birds.append(clone)
		gravity_bodies.append(clone)

func _after_settle() -> void:
	if pigs.is_empty():
		return
	if not bird_queue.is_empty():
		_spawn_bird()
	else:
		_do_lose()

func _on_block_destroyed(score_value: int, at_position: Vector3, block_color: Color) -> void:
	score += score_value
	hud.set_score(score, maxf(best_score, score))
	_spawn_debris(at_position, block_color, 7, 200.0, 3.2)
	_spawn_shockwave(at_position, block_color, 1.0)
	add_shake(5.0)

func _on_pig_died(score_value: int, at_position: Vector3) -> void:
	for pig in pigs.duplicate():
		if pig.is_dead:
			pigs.erase(pig)
	score += score_value
	hud.set_score(score, maxf(best_score, score))
	_spawn_debris(at_position, Color("dca0ea"), 10, 260.0, 3.8)
	_spawn_shockwave(at_position, Color("dca0ea"), 1.6)
	add_shake(11.0)
	if pigs.is_empty() and phase != Phase.RESULT and win_pending <= 0.0:
		win_pending = 1.0

func _check_bird_bounds() -> void:
	var margin := 320.0
	for b in active_birds.duplicate():
		if not is_instance_valid(b):
			active_birds.erase(b)
			continue
		if b.global_position.x < -margin or b.global_position.x > level.world_size.x + margin \
				or b.global_position.z < -margin or b.global_position.z > level.world_size.y + margin \
				or absf(b.global_position.y) > 700.0:
			b.poof()

func _check_pig_bounds() -> void:
	var margin := 260.0
	for pig in pigs.duplicate():
		if pig.is_dead:
			pigs.erase(pig)
			continue
		if pig.global_position.x < -margin or pig.global_position.x > level.world_size.x + margin \
				or pig.global_position.z < -margin or pig.global_position.z > level.world_size.y + margin:
			pigs.erase(pig)
			pig.kill(true)

func _do_win() -> void:
	if phase == Phase.RESULT:
		return
	phase = Phase.RESULT
	var unused: int = level.birds - shots_used
	var bonus: int = unused * SSConfig.BLOCK_BONUS_PER_BIRD
	score += bonus
	if score > best_score:
		best_score = score
	_save_clear(current_level, best_score, shots_used)
	var is_final: bool = current_level >= SSLevels.count() - 1
	hud.set_score(score, best_score)
	hud.show_result(true, "总分 %d · 发射 %d 次 · 余鸟奖励 +%d · 最高分 %d" % [score, shots_used, bonus, best_score], is_final, level.earned_stars(score, true, shots_used))
	_submit_result(true, unused)

func _do_lose() -> void:
	if phase == Phase.RESULT:
		return
	phase = Phase.RESULT
	hud.show_result(false, "还剩 %d 只太空猪 · 总分 %d · 最高分 %d" % [pigs.size(), score, best_score], false)
	_submit_result(false, 0)

## 成绩提交到后端（未登录离线模式跳过），成功后拉排行榜与本关名次
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
	# 本关耗时（毫秒差），而非引擎启动至今的绝对时间；后端校验 0 < duration ≤ 3600
	return maxf(float(Time.get_ticks_msec() - level_start_msec) / 1000.0, 0.001)

## ---------- 相机：单一写入点 ----------
## _process 每帧根据 cam_yaw/cam_pitch/zoom_factor 计算唯一期望位姿，
## 输入只改这三个值，不再有 Tween 与跟随互相覆盖的抖动。

func _desired_transform() -> Array:
	var target: Vector3 = Vector3(level.camera_anchor.x, 0, level.camera_anchor.y)
	if bird != null and bird.bird_state == SSBird3D.BirdState.FLYING and not dragging:
		target = target.lerp(bird.global_position, 0.45)
	# 关卡取景：2D 用 camera.zoom = level.camera_zoom * zoom_factor；
	# 3D 相机距离与视野成反比，故除以 level.camera_zoom 保持"数值越小看得越广"的同义
	var desired: Vector3 = target + Vector3(
		sin(cam_yaw) * cos(cam_pitch),
		sin(cam_pitch),
		cos(cam_yaw) * cos(cam_pitch)) * CAM_DIST * zoom_factor / maxf(level.camera_zoom, 0.1)
	return [desired, target]

## ---------- 表现层：碎片 / 冲击波 / 镜头震动 ----------

func _spawn_debris(at: Vector3, color: Color, count: int, spread: float, size: float) -> void:
	var burst := SSDebrisBurst.new()
	burst.position = to_local(at)
	burst.setup(color, count, spread, size)
	add_child.call_deferred(burst)

func _spawn_shockwave(at: Vector3, color: Color, scale_factor: float) -> void:
	var wave := SSShockwave.new()
	add_child(wave)
	wave.global_position = at
	wave.setup(color, scale_factor)

func add_shake(strength: float) -> void:
	shake_amount = minf(shake_amount + strength, 26.0)

func _process(delta: float) -> void:
	if level == null or camera == null:
		return
	var pose := _desired_transform()
	var weight := clampf(delta * 7.0, 0.0, 1.0)
	camera.position = camera.position.lerp(pose[0], weight)
	camera.look_at(pose[1])
	# 震屏：look_at 之后叠加随机偏移（纯位移抖动，不破坏朝向），随时间衰减
	shake_amount = maxf(shake_amount - delta * 70.0, 0.0)
	if shake_amount > 0.05:
		camera.position += Vector3(
			randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake_amount

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
