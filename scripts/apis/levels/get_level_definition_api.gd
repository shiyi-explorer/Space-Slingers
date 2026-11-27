class_name SSGetLevelDefinitionAPI
extends RefCounted

## 对应后端 GetLevelDefinitionMessage：关卡几何由后端统一下发。

var level_id: String

func _init(p_level_id: String) -> void:
	level_id = p_level_id

func send() -> Dictionary:
	return await SSTransport.instance.send(
		SSApiName.derive("SSGetLevelDefinitionAPI"), {"levelId": level_id}, false)
