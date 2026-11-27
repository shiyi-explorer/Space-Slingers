class_name SSImpact
extends RefCounted

## 碰撞冲击度量：相对速度 × 折合质量。
## 等价于冲量估计，但 API 在所有 Godot 4.x 可用，且天然过滤静止接触。

## self_body 为受击方，other 为撞击方（刚体或静态体/行星）
static func magnitude(self_body: RigidBody2D, other: Node) -> float:
	var other_velocity := Vector2.ZERO
	var other_mass := 40.0
	var rigid := other as RigidBody2D
	if rigid != null:
		other_velocity = rigid.linear_velocity
		other_mass = rigid.mass
	var relative: Vector2 = self_body.linear_velocity - other_velocity
	var reduced: float = (self_body.mass * other_mass) / (self_body.mass + other_mass)
	return reduced * relative.length()
