class_name SSLevelData
extends RefCounted

## 关卡数据与成绩换算。
## 行星：center/radius/field（引力圈半径）/strength（圈内恒定向心加速度）
## 猪：position/radius/hp；方块：rect（世界坐标矩形，底部贴行星表面）/material

var level_name := ""
var hint := ""
var slingshot := Vector2.ZERO
var birds := 3
var bird_types: Array[String] = []   ## 鸟种队列：normal/split/dash，空则视为全普通
var camera_zoom := 0.9
var camera_anchor := Vector2(576, 330)
var world_size := Vector2(1500, 820)
var seed_value := 1
var planets: Array[Dictionary] = []
var pigs: Array[Dictionary] = []
var blocks: Array[Dictionary] = []
var three_star_shots := 2
var star_thresholds: Array[int] = []   ## 旧版一星分数、二星分数、三星分数（升序）

## 一星代表成功通关，二星和三星按本关分数门槛。
func earned_stars(score: int, completed: bool, shots := 0) -> int:
	if not completed:
		return 0
	if shots > 0 and shots <= three_star_shots:
		return 3
	var rating := 1
	for i in range(1, mini(star_thresholds.size(), 3)):
		if score >= star_thresholds[i]:
			rating = i + 1
	return rating
