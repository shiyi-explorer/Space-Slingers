class_name SSLoadProgressAPI
extends RefCounted

## 对应后端 LoadProgressMessage：读取解锁/完成/最好分。

var level_id: String

func _init(p_level_id: String) -> void:
	level_id = p_level_id

func send() -> Dictionary:
	return await SSTransport.instance.send(
		SSApiName.derive("SSLoadProgressAPI"), {"levelId": level_id}, true)
