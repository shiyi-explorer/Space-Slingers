class_name SSPlace3D
extends RefCounted

## 3D 放置几何：球面坐标布置（angle 绕 Y 轴的经度，lat 纬度，0 = 赤道=旧关卡兼容）。
## 输入行星数据用 planet_center(Vector3)/planet_radius。
## 数据里的 lift=3 / 猪的 +2 是贴地预留量：静置结构始终吃引力，会被压到表面坐实。

static func normal(angle_deg: float, lat_deg: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	var b := deg_to_rad(lat_deg)
	return Vector3(cos(b) * cos(a), sin(b), cos(b) * sin(a))

## 把本地 Y 轴对齐到法线的正交基：Y=法线（径向）、X=水平切向、Z=X×Y。
## 关键：不能用 UP×n 当"旋转轴"去把 UP 旋到 n——那样赤道法线时本地 X（横梁长边）
## 会被转到世界竖直方向，tangent 屋顶变成竖插出轨道平面的墙，柱顶接不到。
## 这里显式构造三个正交轴，tangent 横梁长边恒定沿水平切线躺平，radial 立柱恒定径向立起。
static func normal_basis(n: Vector3) -> Basis:
	var east := Vector3.UP.cross(n)   # 水平切向（球面东向）
	if east.length_squared() < 0.000001:
		# 极点：法线竖直，东向退化，用世界 X 作切向
		var fallback := Vector3.RIGHT
		return Basis(fallback, n, fallback.cross(n))
	east = east.normalized()
	return Basis(east, n, east.cross(n))

static func standing_transform(planet: Dictionary, angle_deg: float, lat_deg: float,
		lift: float, size: Vector2) -> Dictionary:
	var n := normal(angle_deg, lat_deg)
	var base: Vector3 = planet["planet_center"] + n * planet["planet_radius"]
	return {
		"position": base + n * (lift + size.y * 0.5),
		"normal": n,
	}

static func lying_transform(planet: Dictionary, angle_deg: float, lat_deg: float,
		lift: float, size: Vector2) -> Dictionary:
	# 平放：薄边沿法线、长边沿切线——与立柱共用 normal_basis（尺寸已编码朝向差异）
	return standing_transform(planet, angle_deg, lat_deg, lift, size)

static func pig_position(planet: Dictionary, angle_deg: float, lat_deg: float,
		radius: float) -> Vector3:
	return planet["planet_center"] + normal(angle_deg, lat_deg) * (planet["planet_radius"] + radius + 2.0)

static func keep_out_of_planets(position: Vector3, planets: Array) -> Vector3:
	var result := position
	for planet in planets:
		var min_distance: float = planet.planet_radius + 18.0
		var offset: Vector3 = result - planet.planet_center
		if offset.length() < min_distance:
			var n: Vector3 = offset.normalized() if offset.length() > 0.001 else Vector3.UP
			result = planet.planet_center + n * min_distance
	return result
