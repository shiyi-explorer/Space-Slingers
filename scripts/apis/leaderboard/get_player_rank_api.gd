class_name SSGetPlayerRankAPI
extends RefCounted

## 对应后端 GetPlayerRankMessage：我的名次与最好分。

var level_id: String

func _init(p_level_id: String) -> void:
	level_id = p_level_id

func send() -> Dictionary:
	return await SSTransport.instance.send(
		SSApiName.derive("SSGetPlayerRankAPI"), {"levelId": level_id}, true)
