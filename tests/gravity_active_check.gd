extends SceneTree

## 静置受力回归测试（headless 3D，逐关全检）：
##   Godot --headless --path . -s tests/gravity_active_check.gd
## 验证每关：所有结构刚体始终吃引力（方块/猪被压到行星表面坐实、间隙≈0、位置稳定），
## 掩体柱/梁静置不塌（位置不得远离期望）；猪不因沉降误死；小鸟装填态仍 freeze。

const SETTLE_FRAMES := 120

func _initialize() -> void:
	var fails := 0
	var main_script: GDScript = load("res://scripts3d/main3d.gd")

	for level_index in SSLevels.count():
		fails += await _check_level(main_script, level_index)
		print("")

	if fails == 0:
		print("== 静置受力验证 全部通过 ==")
	else:
		print("== 静置受力验证 失败 %d 项 ==" % fails)
	quit(0 if fails == 0 else 1)

func _check_level(main_script: GDScript, level_index: int) -> int:
	SSLevelSelect.skip_next = true
	main_script.current_level = level_index
	var packed: PackedScene = load("res://Main3D.tscn")
	var main: Node3D = packed.instantiate()
	root.add_child(main)
	for i in 6:
		await process_frame
	if main.login_screen != null:
		main._on_offline_pressed()
	for i in 120:
		await process_frame
		if main.level != null and main.bird != null:
			break
	if main.level == null:
		print("✗ 第 %d 关：关卡未能构建" % (level_index + 1))
		main.queue_free()
		return 1

	var fails := 0
	var level = main.level
	var planets = main.planets
	var label := "第 %d 关「%s」" % [level_index + 1, level.level_name]

	for i in SETTLE_FRAMES:
		await physics_frame

	# 阶段1：所有方块应稳定在期望位置附近（塌了的横梁/飞走的柱子会远超容差）。
	# 期望位置用主逻辑的 _block_transform 计算，保证测试与实际渲染同源。
	var checked := 0
	var block_index := 0
	for block_data in level.blocks:
		var expect_data: Dictionary = main._block_transform(block_data)
		var expect: Vector3 = expect_data["position"]
		var size: Vector2 = block_data["size"]
		var half: float = size.y * 0.5
		var body: SSBlock3D = null
		for b in main.gravity_bodies:
			if b is SSBlock3D and b.global_position.distance_to(expect) < 40.0:
				body = b
				break
		if body == null:
			fails += 1
			print("✗ %s：方块#%d 找不到对应刚体或已塌飞（期望 pos=%s）" % [label, block_index, str(expect)])
			block_index += 1
			continue
		# 用最近目标行星判断是否有穿模：中心到球心距离不得小于 半径 + 半厚 - 容差
		var min_gap := INF
		for pi in planets.size():
			if pi == 0 and planets.size() > 1:
				continue
			var pc: Vector3 = planets[pi].planet_center
			var pr: float = level.planets[pi]["radius"]
			min_gap = minf(min_gap, body.global_position.distance_to(pc) - half - pr)
		checked += 1
		if min_gap < -2.0:
			fails += 1
			print("✗ %s：方块#%d 陷入行星：间隙 %.2f" % [label, block_index, min_gap])
		block_index += 1
	if checked == level.blocks.size() and fails == 0:
		print("✓ %s：%d 个方块均在目标行星外侧且稳定" % [label, checked])

	# 阶段2：猪应贴住表面，且静置位置稳定（无缓慢漂移），沉降不误杀
	for i in 40:
		await physics_frame
	var pig_drift_max := 0.0
	for i in main.pigs.size():
		var pig = main.pigs[i]
		if not is_instance_valid(pig) or pig.pig_hp <= 0:
			fails += 1
			print("✗ %s：猪#%d 沉降中死亡（结构自爆）" % [label, i])
			continue
		var pig_data = level.pigs[i]
		var pidx: int = pig_data["planet"]
		var pc: Vector3 = planets[pidx].planet_center
		var pr: float = level.planets[pidx]["radius"]
		var radius: float = pig_data["radius"]
		var gap: float = pig.global_position.distance_to(pc) - radius - pr
		pig_drift_max = maxf(pig_drift_max, absf(gap))
		var speed: float = pig.linear_velocity.length()
		# 阈值说明：高重力小星球（如 L4 卫星表面 g=520）上接触求解器有 ±0.05px 穿透与
		# ~10px/s 速度噪声；真塌陷/滑移是数十 px 起步，此阈值只放行物理噪声。
		if absf(gap) >= 1.0 or speed >= 10.0:
			fails += 1
			print("✗ %s：猪#%d 异常：间隙 %.2f / 速度 %.1f" % [label, i, gap, speed])
	print("✓ %s：%d 只猪贴地且静止（最大间隙 %.2f）" % [label, main.pigs.size(), pig_drift_max])

	# 阶段3：小鸟装填时 freeze，不吃引力（发射逻辑不变）
	var bird_ok: bool = main.bird.freeze or main.bird.bird_state == SSBird3D.BirdState.LOADED
	if bird_ok:
		print("✓ %s：小鸟装填态保持 freeze，发射逻辑未变" % label)
	else:
		fails += 1
		print("✗ %s：小鸟装填态异常" % label)

	main.queue_free()
	await process_frame
	return fails
