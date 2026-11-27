extends SceneTree

## 关卡单一数据源回归测试（headless）：
##   Godot --headless --path . -s tests/level_source_check.gd
## 验证 data/levels.json 能被加载，离线路径（SSLevels）与在线下发路径
## （SSLevelCodec 解析服务端响应）得到完全相同的关卡，且关键字段无遗漏。
func _initialize() -> void:
	var fails := 0
	var count := SSLevels.count()
	if count >= 3:
		print("✓ 从 data/levels.json 加载到 %d 关" % count)
	else:
		fails += 1
		print("✗ 关卡数异常：%d（应 ≥3）" % count)

	for i in count:
		var raw: Dictionary = SSLevels.definition(i)
		var offline := SSLevels.build(i)
		var online := SSLevelCodec.from_dict({
			"id": raw.get("id", ""),
			"chapter": raw.get("chapter", 0),
			"name": raw.get("name", ""),
			"birds": raw.get("birds", 0),
			"data": raw,
		})
		if _same_level(offline, online):
			print("✓ 第 %d 关离线/在线解析一致：%s" % [i + 1, offline.level_name])
		else:
			fails += 1
			print("✗ 第 %d 关离线/在线解析不一致" % (i + 1))
		if str(raw.get("id", "")) != "level-%02d" % (i + 1):
			fails += 1
			print("✗ 第 %d 关 id 异常：%s" % [i + 1, raw.get("id", "")])

	# 历史 bug 回归：第 2 关北极头盔猪的 lat=50 必须能从 JSON 解析出来
	var lat_found := false
	for pig in SSLevels.build(1).pigs:
		if absf(float(pig.get("lat", 0.0)) - 50.0) < 0.01:
			lat_found = true
	if lat_found:
		print("✓ 第 2 关北极猪 lat=50 从 JSON 正确解析")
	else:
		fails += 1
		print("✗ 第 2 关北极猪 lat 丢失")

	if fails == 0:
		print("== 全部通过 ==")
	else:
		print("== 失败 %d 项 ==" % fails)
	quit(1 if fails > 0 else 0)


func _same_level(a: SSLevelData, b: SSLevelData) -> bool:
	if a.level_name != b.level_name or a.hint != b.hint or a.birds != b.birds:
		return false
	if a.bird_types != b.bird_types or a.slingshot != b.slingshot:
		return false
	if a.camera_zoom != b.camera_zoom or a.camera_anchor != b.camera_anchor:
		return false
	if a.world_size != b.world_size or a.seed_value != b.seed_value:
		return false
	if a.planets.size() != b.planets.size() or a.pigs.size() != b.pigs.size() or a.blocks.size() != b.blocks.size():
		return false
	for i in a.planets.size():
		if a.planets[i] != b.planets[i]:
			return false
	for i in a.pigs.size():
		if a.pigs[i] != b.pigs[i]:
			return false
	for i in a.blocks.size():
		if a.blocks[i] != b.blocks[i]:
			return false
	return true
