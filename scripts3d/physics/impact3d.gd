class_name SSImpact3D
extends RefCounted

## 3D 碰撞冲击度量：相对速度 × 折合质量（与 2D 版同语义，基于 Vector3）。

static func magnitude(self_body: RigidBody3D, other: Node) -> float:
	var other_velocity := Vector3.ZERO
	var other_mass := 40.0
	var rigid := other as RigidBody3D
	if rigid != null:
		other_velocity = rigid.linear_velocity
		other_mass = rigid.mass
	var relative := self_body.linear_velocity - other_velocity
	var reduced := (self_body.mass * other_mass) / (self_body.mass + other_mass)
	return reduced * relative.length()
