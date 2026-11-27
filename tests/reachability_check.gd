extends SceneTree

## 可通关性回归测试：枚举发射方向/仰角/力度，用与运行时同源的 SSGravity3D
## 积分弹道（dt=1/120），验证每只猪都存在「几何可达 + 动量足够」的直击弹道。
##
##   Godot --headless --path . -s tests/reachability_check.gd
##
## 先粗搜（6°/6°/5%），未命中则对该猪细搜（2°/2°/2%）。
## 说明：只验证直击可达性，忽略方块遮挡与撞击连锁（碰到就死，一发一猪）；
## 若某猪连直击弹道都没有，关卡布局就存在问题。

const DT := 1.0 / 120.0
const BIRD_R := 16.0
const MAX_LAUNCH := 1000.0
const MAX_FLIGHT := 1100.0
const KILL_MOMENTUM := 60.0
const MAX_PULL := SSConfig.MAX_PULL
const REDUCED_MASS := 0.6   # 鸟 1.0 / 猪 1.5 折合质量
const SETTLE_SPEED := 28.0
const ANCHOR_Z := -46.0     # SSSling3D.anchor
const MAX_STEPS := 900      # 7.5 秒上限

var level: SSLevelData
var planets: Array = []
var pigs: Array = []
var world_size: Vector2
var origin: Vector3
var total_sims := 0

## 命中返回解字典；否则返回空字典。撞行星/出界/停稳均终止该弹道。
func shoot(hdir: Vector3, elevation_deg: float, power: float, target_idx: int) -> Dictionary:
	var el := deg_to_rad(elevation_deg)
	var speed := power * MAX_LAUNCH
	# 拉弓偏移：pull_world = -hdir，鸟被拉向发射反方向（与 main3d._update_pull 同构）
	var world_len := power * MAX_PULL
	var pos: Vector3 = origin - hdir * world_len
	var vel: Vector3 = (hdir * cos(el) + Vector3.UP * sin(el)) * speed
	var target: Dictionary = pigs[target_idx]
	var still := 0
	for step in MAX_STEPS:
		var acc := SSGravity3D.total_acceleration(planets, pos)
		vel = (vel + acc * DT).limit_length(MAX_FLIGHT)
		pos += vel * DT
		var blocked := false
		for pl in planets:
			if pos.distance_to(pl["planet_center"]) < float(pl["planet_radius"]) + BIRD_R:
				blocked = true
				break
		if blocked:
			break
		if pos.x < -320.0 or pos.x > world_size.x + 320.0 \
				or pos.z < -320.0 or pos.z > world_size.y + 320.0 or absf(pos.y) > 700.0:
			break
		if pos.distance_to(target["pos"]) < float(target["r"]) + BIRD_R:
			if REDUCED_MASS * vel.length() >= KILL_MOMENTUM:
				return {"az": rad_to_deg(atan2(hdir.z, hdir.x)),
					"el": elevation_deg, "power": power, "speed": vel.length()}
		if vel.length() < SETTLE_SPEED:
			still += 1
			if still > 50:
				break
		else:
			still = 0
	return {}

## 搜索单只猪的命中弹道；step_az/step_el/step_power 为粗/细两档网格
func find_solution(target_idx: int, step_az: int, step_el: int, step_power: int) -> Dictionary:
	for az_deg in range(-180, 180, step_az):
		var az := deg_to_rad(az_deg)
		var hdir := Vector3(cos(az), 0, sin(az))
		for el_deg in range(int(SSConfig.AIM_ELEVATION_MIN), int(SSConfig.AIM_ELEVATION_MAX) + 1, step_el):
			for pp in range(20, 101, step_power):
				total_sims += 1
				var sol := shoot(hdir, float(el_deg), float(pp) / 100.0, target_idx)
				if not sol.is_empty():
					return sol
	return {}

func solve_level(index: int) -> int:
	level = SSLevels.build(index)
	planets = []
	for pd in level.planets:
		planets.append({
			"planet_center": Vector3(pd["center"].x, 0, pd["center"].y),
			"planet_radius": float(pd["radius"]),
			"field_radius": float(pd["field"]),
			"strength": float(pd["strength"]),
		})
	pigs = []
	for i in level.pigs.size():
		var p: Dictionary = level.pigs[i]
		var pd: Dictionary = planets[int(p["planet"])]
		var pos := SSPlace3D.pig_position(pd, float(p["angle"]),
			float(p.get("lat", 0.0)), float(p["radius"]))
		pigs.append({"idx": i, "pos": pos, "r": float(p["radius"])})
	world_size = level.world_size
	origin = Vector3(level.slingshot.x, 0, level.slingshot.y + ANCHOR_Z)

	var failures := 0
	print("── 第 %d 关「%s」 鸟 %d / 猪 %d" % [
		index + 1, level.level_name, level.bird_types.size(), pigs.size()])
	for i in pigs.size():
		var p: Dictionary = level.pigs[i]
		var sol := find_solution(i, 6, 6, 5)
		if sol.is_empty():
			sol = find_solution(i, 2, 2, 2)   # 细搜兜底：窄解（擦边弹道）
		if sol.is_empty():
			failures += 1
			print("  ✗ 猪#%d (planet%d ang%d lat%.0f) 无可达直击弹道" % [
				i, int(p["planet"]), int(p["angle"]), float(p.get("lat", 0.0))])
		else:
			print("  ✓ 猪#%d 可达：方位%.0f° 仰角%.0f° 力度%.0f%% 速度%.0f" % [
				i, sol["az"], sol["el"], sol["power"] * 100.0, sol["speed"]])
	if level.bird_types.size() < pigs.size():
		failures += 1
		print("  ✗ 鸟数 %d < 猪数 %d，一发一猪也不够" % [level.bird_types.size(), pigs.size()])
	return failures

func _initialize() -> void:
	var failures := 0
	for i in SSLevels.count():
		failures += solve_level(i)
	print("── 模拟 %d 条弹道" % total_sims)
	if failures == 0:
		print("== 所有关卡的目标均有直击弹道 ==")
	else:
		print("== 失败 %d 项 ==" % failures)
	quit(0 if failures == 0 else 1)
