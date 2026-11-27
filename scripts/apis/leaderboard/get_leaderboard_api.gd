class_name SSGetLeaderboardAPI
extends RefCounted

## 对应后端 GetLeaderboardMessage：关卡排行榜 TopN。

var level_id: String
var limit: int

func _init(p_level_id: String, p_limit: int = 20) -> void:
	level_id = p_level_id
	limit = p_limit

func send() -> Dictionary:
	return await SSTransport.instance.send(
		SSApiName.derive("SSGetLeaderboardAPI"), {"levelId": level_id, "limit": limit}, false)
