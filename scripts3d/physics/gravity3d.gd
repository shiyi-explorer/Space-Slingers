class_name SSGravity3D
extends RefCounted

## 引力模型（第二版手感）：软化平方根反比 + 圈边平滑归零。
## 表面处 ≈ strength，越远按 1/√r 缓和衰减，到引力圈边缘平滑归零——
## "靠近行星"在手感上有回报，但不会像纯平方反比那样衰减过陡、只剩贴边一窄条有效。
## 预览弹道、运行时积分、可通关性求解器共用此函数，改一处三处同步。

## 单个行星在指定位置产生的加速度
static func zone_at_body(planet_center: Vector3, planet_radius: float,
		strength: float, field_radius: float, position: Vector3) -> Vector3:
	var offset := planet_center - position
	var distance := offset.length()
	if distance < 0.001 or distance > field_radius:
		return Vector3.ZERO
	var surface := maxf(planet_radius, 1.0)
	var soften := surface * 0.3
	# 平方根反比：表面归一化到 strength，软化避免 r→0 奇点
	var inverse := sqrt((surface + soften) / (distance + soften))
	# 圈边平滑归零（smoothstep）：圈边 0 → 表面 1
	var t := clampf((field_radius - distance) / maxf(field_radius - surface, 1.0), 0.0, 1.0)
	var window := t * t * (3.0 - 2.0 * t)
	return offset / distance * (strength * inverse * window)

## 所有行星叠加的总加速度
static func total_acceleration(planets: Array, position: Vector3) -> Vector3:
	var total := Vector3.ZERO
	for planet in planets:
		total += zone_at_body(
			planet["planet_center"], planet["planet_radius"],
			planet["strength"], planet["field_radius"], position)
	return total
