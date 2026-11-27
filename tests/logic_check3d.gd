extends SceneTree

## 3D 逻辑自检（headless）：
##   Godot --headless --path . -s tests/logic_check3d.gd
## 验证 3D 场景的放置几何与引力语义（数据来自同一份关卡文件，语义在 XZ 平面）。

func _initialize() -> void:
	var failures := 0

	for index in SSLevels.count():
		var level := SSLevels.build(index)
		var label := "第 %d 关「%s」" % [index + 1, level.level_name]
		var planets3d: Array[Dictionary] = []
		for pd in level.planets:
			planets3d.append({
				"planet_center": Vector3(pd["center"].x, 0, pd["center"].y),
				"planet_radius": pd["radius"],
				"field_radius": pd["field"],
				"strength": pd["strength"],
			})

		for pig_data in level.pigs:
			var planet: Dictionary = planets3d[pig_data["planet"]]
			var pos: Vector3 = SSPlace3D.pig_position(planet, pig_data["angle"],
					pig_data.get("lat", 0.0), pig_data["radius"])
			var distance: float = pos.distance_to(planet["planet_center"])
			if distance < planet["planet_radius"] + pig_data["radius"]:
				failures += 1
				print("✗ %s：3D 猪(角度 %d°) 嵌入行星" % [label, pig_data["angle"]])

		for block_data in level.blocks:
			var size: Vector2 = block_data["size"]
			var block_pos: Vector3
			if block_data.get("pos") != null:
				# 绝对坐标（塔楼）：2D 的 x→3D x、2D 的 y→3D z。
				# 必须落在某颗非弹弓行星外侧合理范围，防止像本次 bug 那样全挤到弹弓行星。
				var p: Vector2 = block_data["pos"]
				block_pos = Vector3(p.x, 0.0, p.y)
				var nearest_dist := INF
				for pi in planets3d.size():
					if pi == 0 and planets3d.size() > 1:
						continue
					nearest_dist = minf(nearest_dist,
						block_pos.distance_to(planets3d[pi]["planet_center"]))
				if nearest_dist > 900.0:
					failures += 1
					print("✗ %s：3D 方块(pos=%s) 远离所有目标行星" % [label, str(p)])
			else:
				var planet: Dictionary = planets3d[block_data["planet"]]
				var lift: float = block_data.get("lift", 3.0)
				var transform_data: Dictionary = SSPlace3D.standing_transform(planet, block_data["angle"],
						block_data.get("lat", 0.0), lift, size) \
						if block_data.get("axis", "radial") == "radial" \
						else SSPlace3D.lying_transform(planet, block_data["angle"],
						block_data.get("lat", 0.0), lift, size)
				block_pos = transform_data["position"]
				var distance: float = block_pos.distance_to(planet["planet_center"])
				# 1.0 容差：lift 0 的柱子恰好贴地（间距≈0），浮点噪声不得误报为嵌入
				if distance < planet["planet_radius"] + size.y * 0.5 - 1.0:
					failures += 1
					print("✗ %s：3D 方块(角度 %d°) 嵌入行星" % [label, block_data["angle"]])
		if failures == 0:
			print("✓ %s：3D 放置全部合法" % label)

	# 纬度布置：北极的猪应落在行星正上方（Y 正向），赤道纬度=旧平面语义
	var pole_planet := {"planet_center": Vector3.ZERO, "planet_radius": 50.0}
	var pole_pig: Vector3 = SSPlace3D.pig_position(pole_planet, 0.0, 90.0, 20.0)
	if absf(pole_pig.y - 72.0) < 0.5 and absf(pole_pig.x) < 0.01 and absf(pole_pig.z) < 0.01:
		print("✓ 北纬 90° 的猪落在行星正上方（真三维布置）")
	else:
		failures += 1
		print("✗ 极地布置错误：", pole_pig)

	# 引力语义（第二版软化平方根反比）：表面归一到 strength，越远越弱，圈边平滑归零
	var planet := {
		"planet_center": Vector3(760, 0, 300),
		"planet_radius": 95.0,
		"field_radius": 240.0,
		"strength": 530.0,
	}
	var surface: float = SSGravity3D.zone_at_body(
		planet["planet_center"], planet["planet_radius"],
		planet["strength"], planet["field_radius"], planet["planet_center"] + Vector3(95, 0, 0)).length()
	var mid: float = SSGravity3D.zone_at_body(
		planet["planet_center"], planet["planet_radius"],
		planet["strength"], planet["field_radius"], planet["planet_center"] + Vector3(190, 0, 0)).length()
	if absf(surface - 530.0) < 2.0 and mid > surface * 0.15 and mid < surface * 0.30:
		print("✓ 平方根反比衰减：表面 %.0f → 2R %.0f（越近越强、过渡平缓）" % [surface, mid])
	else:
		failures += 1
		print("✗ 衰减异常：表面 %.0f / 2R %.0f" % [surface, mid])
	var near_edge: float = SSGravity3D.zone_at_body(
		planet["planet_center"], planet["planet_radius"],
		planet["strength"], planet["field_radius"], planet["planet_center"] + Vector3(228, 0, 0)).length()
	var edge: float = SSGravity3D.zone_at_body(
		planet["planet_center"], planet["planet_radius"],
		planet["strength"], planet["field_radius"], planet["planet_center"] + Vector3(240, 0, 0)).length()
	if near_edge > 0.0 and near_edge < mid and edge == 0.0:
		print("✓ 圈边平滑归零：0.95F %.1f → F %.1f（无硬跳变）" % [near_edge, edge])
	else:
		failures += 1
		print("✗ 边界归零异常：0.95F %.2f / F %.2f" % [near_edge, edge])
	var far: float = SSGravity3D.zone_at_body(
		planet["planet_center"], planet["planet_radius"],
		planet["strength"], planet["field_radius"], planet["planet_center"] + Vector3(300, 0, 0)).length()
	if far == 0.0:
		print("✓ 圈外精确归零（多行星混战消除）")
	else:
		failures += 1
		print("✗ 圈外未归零：%.2f" % far)

	if failures == 0:
		print("== 全部通过 ==")
	else:
		print("== 失败 %d 项 ==" % failures)
	quit(0 if failures == 0 else 1)
