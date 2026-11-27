class_name SSPlace
extends RefCounted

## 放置几何：把"行星 + 角度"换算成世界坐标。纯函数，无状态。
## 约定：angle_deg 为行星表面角度（-90 = 正顶部，0 = 右侧，90 = 底部），
## lift 为结构底面沿法线抬离表面的间隙像素。

## 站立方块（高沿半径方向，如立柱）
static func standing_transform(planet: Dictionary, angle_deg: float, lift: float, size: Vector2) -> Dictionary:
	var a := deg_to_rad(angle_deg)
	var normal := Vector2(cos(a), sin(a))
	var base: Vector2 = planet["center"] + normal * planet["radius"]
	return {
		"position": base + normal * (lift + size.y * 0.5),
		"rotation": a - PI * 0.5,
	}

## 平放方块（长边沿切线方向，如横梁）
static func lying_transform(planet: Dictionary, angle_deg: float, lift: float, size: Vector2) -> Dictionary:
	var a := deg_to_rad(angle_deg)
	var normal := Vector2(cos(a), sin(a))
	var base: Vector2 = planet["center"] + normal * planet["radius"]
	return {
		"position": base + normal * (lift + size.y * 0.5),
		"rotation": a + PI * 0.5,
	}

## 猪：坐在表面上
static func pig_position(planet: Dictionary, angle_deg: float, radius: float) -> Vector2:
	var a := deg_to_rad(angle_deg)
	return planet["center"] + Vector2(cos(a), sin(a)) * (planet["radius"] + radius + 2.0)

## 拖拽位置约束：小鸟不得被拽进行星体内。
## 否则松手瞬间被物理引擎暴力弹出，实际路线与预览完全不符。
static func keep_out_of_planets(position: Vector2, planets: Array) -> Vector2:
	var result := position
	for planet in planets:
		var min_distance: float = planet.planet_radius + 18.0
		var offset: Vector2 = result - planet.planet_center
		if offset.length() < min_distance:
			var normal := offset.normalized() if offset.length() > 0.001 else Vector2.UP
			result = planet.planet_center + normal * min_distance
	return result
