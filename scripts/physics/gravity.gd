class_name SSGravity
extends RefCounted

## 引力模型（与 3D 版 SSGravity3D 同语义的 2D 版）：软化平方根衰减 + 圈边平滑归零。
## 表面处 ≈ strength，越远按软化平方根缓和衰减，到引力圈边缘平滑归零。
## 预览弹道、运行时施力共用此函数，改一处两处同步。

## 单个行星在指定位置产生的加速度
static func acceleration_at_body(planet_center: Vector2, planet_radius: float,
		field_radius: float, strength: float, position: Vector2) -> Vector2:
	var offset := planet_center - position
	var distance := offset.length()
	if distance < 0.001 or distance > field_radius:
		return Vector2.ZERO
	var surface := maxf(planet_radius, 1.0)
	var soften := surface * 0.3
	var inverse := sqrt((surface + soften) / (distance + soften))
	var t := clampf((field_radius - distance) / maxf(field_radius - surface, 1.0), 0.0, 1.0)
	var window := t * t * (3.0 - 2.0 * t)
	return offset / distance * (strength * inverse * window)

## 所有行星叠加的总加速度（planets 为 SSPlanet 节点数组）
static func total_acceleration(planets: Array, position: Vector2) -> Vector2:
	var total := Vector2.ZERO
	for planet in planets:
		total += acceleration_at_body(planet.planet_center, planet.planet_radius,
			planet.field_radius, planet.strength, position)
	return total
