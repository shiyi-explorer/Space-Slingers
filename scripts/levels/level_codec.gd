class_name SSLevelCodec
extends RefCounted

## 关卡 JSON → SSLevelData 的唯一解析器。
## Godot 离线加载（SSLevels）和在线服务端下发（main3d）共用同一实现，
## 避免两条路径各写一份解析逻辑而产生字段遗漏（历史 lat 丢失 bug 的根因）。

## definition 两种形态都支持：
## - 离线：data/levels.json 里的关卡对象本身（直接含 planets/pigs/blocks）
## - 在线：{id, chapter, name, birds, data:{...}} 形式的服务端响应
static func from_dict(definition: Dictionary) -> SSLevelData:
	var data: Dictionary = definition.get("data", definition)
	var built := SSLevelData.new()
	built.level_name = str(data.get("levelName", definition.get("name", "")))
	built.hint = str(data.get("hint", ""))
	built.birds = int(definition.get("birds", data.get("birds", 3)))
	var slingshot: Dictionary = data.get("slingshot", {})
	built.slingshot = Vector2(float(slingshot.get("x", 170.0)), float(slingshot.get("y", 415.0)))
	built.camera_zoom = float(data.get("cameraZoom", 0.9))
	var anchor: Dictionary = data.get("cameraAnchor", {})
	built.camera_anchor = Vector2(float(anchor.get("x", 560.0)), float(anchor.get("y", 330.0)))
	var world: Dictionary = data.get("worldSize", {})
	built.world_size = Vector2(float(world.get("x", 1500.0)), float(world.get("y", 820.0)))
	built.seed_value = int(data.get("seedValue", 1))
	built.three_star_shots = clampi(int(data.get("threeStarShots", built.three_star_shots)), 1, maxi(1, built.birds))
	for threshold in data.get("starThresholds", []):
		built.star_thresholds.append(int(threshold))
	for kind in data.get("birdTypes", []):
		built.bird_types.append(str(kind))
	for planet in data.get("planets", []):
		var center: Dictionary = planet.get("center", {})
		built.planets.append({
			"center": Vector2(float(center.get("x", 0.0)), float(center.get("y", 0.0))),
			"radius": float(planet.get("radius", 90.0)),
			"field": float(planet.get("field", 300.0)),
			"strength": float(planet.get("strength", 500.0)),
			"base": Color(str(planet.get("base", "3b4355"))),
			"highlight": Color(str(planet.get("highlight", "68748a"))),
			"ring": _parse_rgb(str(planet.get("ring", "1.0,1.0,1.0"))),
		})
	for pig in data.get("pigs", []):
		built.pigs.append({
			"planet": int(pig.get("planet", 0)),
			"angle": int(pig.get("angle", -90)),
			"lat": float(pig.get("lat", 0.0)),
			"radius": float(pig.get("radius", 20.0)),
			"hp": int(pig.get("hp", 1)),
		})
	for block in data.get("blocks", []):
		var size: Dictionary = block.get("size", {})
		# 支持两种放置：abs（世界坐标 + 角度，用于精确堆叠结构）或 planet+angle（贴球面）
		var pos_variant: Variant = block.get("pos", null)
		var has_abs: bool = pos_variant is Dictionary and pos_variant.has("x") and pos_variant.has("y")
		built.blocks.append({
			"planet": int(block.get("planet", 0)),
			"angle": int(block.get("angle", -90)),
			"lat": float(block.get("lat", 0.0)),
			"material": str(block.get("material", "wood")),
			"size": Vector2(float(size.get("x", 20.0)), float(size.get("y", 78.0))),
			"axis": str(block.get("axis", "radial")),
			"lift": float(block.get("lift", 3.0)),
			"pos": Vector2(float(pos_variant.get("x", 0.0)), float(pos_variant.get("y", 0.0))) if has_abs else null,
			"rotation": deg_to_rad(float(block.get("rotation", 0.0))),
			"structural": bool(block.get("structural", false)),
		})
	return built

static func _parse_rgb(text: String) -> Color:
	var parts := text.split(",")
	if parts.size() == 3:
		return Color(float(parts[0]), float(parts[1]), float(parts[2]))
	return Color.WHITE
