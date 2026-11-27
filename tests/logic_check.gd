extends SceneTree

## 逻辑自检（headless）：Godot --headless --path . -s tests/logic_check.gd
## 重点：关卡数据的放置不得与行星重叠（曾因重叠导致开局爆炸、结算面板连弹）。

func _initialize() -> void:
	var failures := 0

	for index in SSLevels.count():
		var level := SSLevels.build(index)
		var label := "第 %d 关「%s」" % [index + 1, level.level_name]

		# 1. 数据完整
		if level.pigs.is_empty() or level.planets.size() < 2:
			failures += 1
			print("✗ %s：数据不完整" % label)
		else:
			print("✓ %s：%d 猪 / %d 行星 / %d 方块" % [label, level.pigs.size(), level.planets.size(), level.blocks.size()])

		# 2. 猪不得嵌进行星表面
		for pig_data in level.pigs:
			var planet: Dictionary = level.planets[pig_data["planet"]]
			var pos: Vector2 = SSPlace.pig_position(planet, pig_data["angle"], pig_data["radius"])
			var distance: float = pos.distance_to(planet["center"])
			if distance < planet["radius"] + pig_data["radius"]:
				failures += 1
				print("✗ %s：猪(角度 %d°) 嵌入行星 %.1fpx" % [label, pig_data["angle"], planet["radius"] + pig_data["radius"] - distance])
			else:
				print("✓ %s：猪(角度 %d°) 离表面 %.1fpx 间隙" % [label, pig_data["angle"], distance - planet["radius"] - pig_data["radius"]])

		# 3. 方块底面不得低于行星表面
		for block_data in level.blocks:
			var planet: Dictionary = level.planets[block_data["planet"]]
			var lift: float = block_data.get("lift", 3.0)
			var size: Vector2 = block_data["size"]
			var transform_data: Dictionary = SSPlace.standing_transform(planet, block_data["angle"], lift, size) \
					if block_data.get("axis", "radial") == "radial" \
					else SSPlace.lying_transform(planet, block_data["angle"], lift, size)
			var distance: float = (transform_data["position"] as Vector2).distance_to(planet["center"])
			var clearance: float = distance - planet["radius"] - size.y * 0.5
			# -1.0 容差：lift 0 的柱子恰好贴地（clearance≈0），浮点噪声不得误报为嵌入
			if clearance < -1.0:
				failures += 1
				print("✗ %s：方块(角度 %d°) 嵌入行星 %.1fpx" % [label, block_data["angle"], -clearance])
			else:
				print("✓ %s：方块(角度 %d°) 底面离表面 %.1fpx" % [label, block_data["angle"], clearance])

	# 4. 伤害数学：碰到就死（仅静止接触除外）
	var bird_body := RigidBody2D.new()
	root.add_child(bird_body)
	bird_body.mass = 1.0
	var pig_body := RigidBody2D.new()
	root.add_child(pig_body)
	pig_body.mass = 1.5
	bird_body.linear_velocity = Vector2(900, 0)
	if SSImpact.magnitude(pig_body, bird_body) >= SSConfig.PIG_TOUCH_KILL:
		print("✓ 直击动量 %.0f ≥ 阈值 %.0f：必死" % [SSImpact.magnitude(pig_body, bird_body), SSConfig.PIG_TOUCH_KILL])
	else:
		failures += 1
		print("✗ 直击不足以致死")
	bird_body.linear_velocity = Vector2(450, 0)
	if SSImpact.magnitude(pig_body, bird_body) >= SSConfig.PIG_TOUCH_KILL:
		print("✓ 中速飞行动量 %.0f：击杀" % SSImpact.magnitude(pig_body, bird_body))
	else:
		failures += 1
		print("✗ 中速飞行打不死猪——阈值偏高")
	bird_body.linear_velocity = Vector2(120, 0)
	bird_body.mass = 1.2
	if SSImpact.magnitude(pig_body, bird_body) >= SSConfig.PIG_TOUCH_KILL:
		print("✓ 慢速滚动(120px/s)动量 %.0f：也能击杀（碰到就死）" % SSImpact.magnitude(pig_body, bird_body))
	else:
		failures += 1
		print("✗ 慢速滚动打不死——不符合碰到就死")
	bird_body.linear_velocity = Vector2.ZERO
	if SSImpact.magnitude(pig_body, bird_body) < SSConfig.PIG_TOUCH_KILL:
		print("✓ 静止接触不误杀")
	else:
		failures += 1
		print("✗ 静止接触会误杀")

	# 5. 拖拽约束：被拽进行星的小鸟位置必须被推到表面外（否则发射即暴力弹射）
	var test_planet := SSPlanet.new()
	test_planet.planet_center = Vector2(170, 470)
	test_planet.planet_radius = 55.0
	var buried: Vector2 = SSPlace.keep_out_of_planets(Vector2(170, 480), [test_planet])
	if buried.distance_to(test_planet.planet_center) >= test_planet.planet_radius + 18.0:
		print("✓ 拖入行星的位置被约束到表面外（距离 %.0f ≥ %.0f）" % [
			buried.distance_to(test_planet.planet_center), test_planet.planet_radius + 18.0])
	else:
		failures += 1
		print("✗ 拖入行星未被推出，发射路线会失控")

	test_planet.free()

	# 6. 发射速度：满拉 115 × 8.5 ≈ 978，力度充足且未触发上限
	var pull: Vector2 = Vector2(SSConfig.MAX_PULL, 0)
	var launch_speed: float = (pull * SSConfig.LAUNCH_POWER).length()
	if launch_speed >= 900.0 and launch_speed <= SSConfig.MAX_LAUNCH_SPEED:
		print("✓ 满拉速度 %.0f：力度充足且未触发上限截断" % launch_speed)
	else:
		failures += 1
		print("✗ 满拉速度 %.0f 异常（应在 900 ~ %d 之间）" % [launch_speed, SSConfig.MAX_LAUNCH_SPEED])

	if failures == 0:
		print("== 全部通过 ==")
	else:
		print("== 失败 %d 项 ==" % failures)
	quit(0 if failures == 0 else 1)
