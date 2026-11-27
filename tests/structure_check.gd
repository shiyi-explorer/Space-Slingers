extends SceneTree

## 掩体结构静置回归测试（headless 2D）：
##   Godot --headless --path . -s tests/structure_check.gd
## 逐关实例化 Main.tscn（离线模式），等结构沉降后验证：
##   1. 所有方块存活（未被沉降误碎）
##   2. 方块位移小于阈值（柱/梁/石板没有塌、滑、飞）
##   3. 所有猪存活（沉降没有压死猪——开局自爆的回归形态）
##   4. 结算面板没有自动弹出（胜负未被误触发）

const SETTLE_FRAMES := 150   # ≈2.5 秒物理帧，覆盖出生保护期(0.4s)后的沉降全程

func _initialize() -> void:
	var fails := 0
	var main_script: GDScript = load("res://scripts/main.gd")

	for level_index in SSLevels.count():
		var result := await _check_level(main_script, level_index)
		fails += result
		print("")

	if fails == 0:
		print("== 掩体结构静置 全部通过 ==")
	else:
		print("== 掩体结构静置 失败 %d 项 ==" % fails)
	quit(0 if fails == 0 else 1)

func _check_level(main_script: GDScript, level_index: int) -> int:
	SSLevelSelect.skip_next = true
	main_script.current_level = level_index
	var packed: PackedScene = load("res://Main.tscn")
	var main: Node2D = packed.instantiate()
	root.add_child(main)
	for i in 12:
		await process_frame
	if main.login_screen != null:
		main._on_offline_pressed()
		for i in 12:
			await process_frame
	var level = main.level
	if level == null:
		print("✗ 第 %d 关：关卡未能构建" % (level_index + 1))
		main.queue_free()
		return 1

	var label := "第 %d 关「%s」" % [level_index + 1, level.level_name]
	var fails := 0

	# 期望位置：与主逻辑同源的 SSPlace 几何
	var expected: Array[Vector2] = []
	for block_data in level.blocks:
		var planet: Dictionary = level.planets[block_data["planet"]]
		var lift: float = block_data["lift"]
		var size: Vector2 = block_data["size"]
		var transform_data: Dictionary = SSPlace.standing_transform(planet, block_data["angle"], lift, size) \
				if block_data["axis"] == "radial" \
				else SSPlace.lying_transform(planet, block_data["angle"], lift, size)
		expected.append(transform_data["position"])

	# 快照初始位姿（保护期后）
	for i in 30:
		await physics_frame
	var start_positions: Array[Vector2] = []
	for block in main.block_nodes:
		start_positions.append(block.global_position)

	# 沉降全程
	for i in SETTLE_FRAMES:
		await physics_frame

	# 1. 方块存活 + 2. 位移检查（沉降压实允许 ≤8px，倒塌会远超）
	var drifted := 0.0
	for i in main.block_nodes.size():
		var block: SSBlock = main.block_nodes[i]
		if not is_instance_valid(block) or block.hp <= 0:
			fails += 1
			print("✗ %s：方块#%d 沉降中损毁（结构自爆）" % [label, i])
			continue
		var move: float = block.global_position.distance_to(expected[i])
		var settle: float = block.global_position.distance_to(start_positions[i])
		drifted = maxf(drifted, settle)
		if move > 12.0 or settle > 8.0:
			fails += 1
			print("✗ %s：方块#%d 位移 %.1fpx（偏离期望 %.1fpx）——结构塌了" % [label, i, settle, move])
	if fails == 0:
		print("✓ %s：%d 个方块静置稳定（最大沉降 %.1fpx）" % [label, main.block_nodes.size(), drifted])

	# 3. 猪全部存活
	var dead_pigs := 0
	for pig in main.pigs:
		if not is_instance_valid(pig) or pig.pig_hp <= 0:
			dead_pigs += 1
	if dead_pigs == 0:
		print("✓ %s：%d 只猪存活，沉降未误杀" % [label, main.pigs.size()])
	else:
		fails += dead_pigs
		print("✗ %s：沉降误杀 %d 只猪（开局自爆回归）" % [label, dead_pigs])

	# 4. 未误触结算
	if main.phase == main.Phase.RESULT:
		fails += 1
		print("✗ %s：结算面板被自动触发" % label)
	else:
		print("✓ %s：胜负状态正常（phase=%d）" % [label, main.phase])

	main.queue_free()
	await process_frame
	return fails
