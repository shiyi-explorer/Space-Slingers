extends SceneTree

## 2D 可通关性扫描：枚举发射角/力度，用与运行时同源的 SSGravity 积分，
## 验证每只猪存在「几何可达 + 动量足够」的直击弹道。

const DT := SSConfig.PHYSICS_DT
const BIRD_R := SSConfig.BIRD_RADIUS
const MAX_FLIGHT := SSConfig.MAX_FLIGHT_SPEED
const KILL_MOMENTUM := SSConfig.PIG_TOUCH_KILL
const REDUCED_MASS := 0.6
const MAX_STEPS := 900

var world_size: Vector2
var sling: Vector2
var planet_data: Array = []
var pig_pos: Array = []
var pig_radii: Array = []
var total_sims := 0

func shoot(angle_deg: float, power: float, target: Vector2, target_radius: float) -> bool:
	var a := deg_to_rad(angle_deg)
	var speed := minf(power * SSConfig.MAX_PULL * SSConfig.LAUNCH_POWER, SSConfig.MAX_LAUNCH_SPEED)
	var dir := Vector2(cos(a), sin(a))
	var pull := -dir * power * SSConfig.MAX_PULL
	var pos: Vector2 = sling + Vector2(0, -46.0) + pull
	var vel: Vector2 = dir * speed
	var still := 0
	for step in MAX_STEPS:
		total_sims += 1
		var acc := Vector2.ZERO
		for pl in planet_data:
			acc += SSGravity.acceleration_at_body(pl["center"], pl["radius"], pl["field"], pl["strength"], pos)
		vel = (vel + acc * DT).limit_length(MAX_FLIGHT)
		pos += vel * DT
		var blocked := false
		for pl in planet_data:
			if pos.distance_to(pl["center"]) < float(pl["radius"]) + BIRD_R:
				blocked = true
				break
		if blocked:
			return false
		if pos.x < -320 or pos.x > world_size.x + 320 or pos.y < -320 or pos.y > world_size.y + 320:
			return false
		if pos.distance_to(target) < target_radius + BIRD_R:
			if REDUCED_MASS * vel.length() >= KILL_MOMENTUM:
				return true
		if vel.length() < 28.0:
			still += 1
			if still > 50:
				return false
	return false

func _initialize() -> void:
	var failures := 0
	for li in SSLevels.count():
		var def: Dictionary = SSLevels.definition(li)
		var lv: SSLevelData = SSLevelCodec.from_dict(def)
		world_size = lv.world_size
		sling = lv.slingshot
		planet_data = lv.planets
		pig_pos = []
		pig_radii = []
		for p in lv.pigs:
			var center: Vector2 = lv.planets[p["planet"]]["center"]
			var angle: float = deg_to_rad(p["angle"])
			pig_pos.append(center + Vector2(cos(angle), sin(angle)) * (lv.planets[p["planet"]]["radius"] + p["radius"] + 2.0))
			pig_radii.append(float(p["radius"]))
		print("== 第%d关 %s：%d猪 ==" % [li + 1, lv.level_name, pig_pos.size()])
		var all_ok := true
		for pi in pig_pos.size():
			var hits := 0
			for adeg in range(0, 360, 2):
				for percent in range(30, 101, 5):
					if shoot(float(adeg), float(percent) / 100.0, pig_pos[pi], pig_radii[pi]):
						hits += 1
			if hits == 0:
				all_ok = false
				failures += 1
				print("  ✗ 猪%d 无直击解" % (pi + 1))
			else:
				print("  ✓ 猪%d 命中解 %d" % [pi + 1, hits])
		print("  → %s" % ("所有目标均有直击弹道" if all_ok else "存在死角"))
	print("总模拟次数: %d" % total_sims)
	quit(0 if failures == 0 else 1)
