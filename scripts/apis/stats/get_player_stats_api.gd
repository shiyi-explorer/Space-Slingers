class_name SSGetPlayerStatsAPI
extends RefCounted

## 对应后端 GetPlayerStatsMessage：整体统计聚合。

func send() -> Dictionary:
	return await SSTransport.instance.send(
		SSApiName.derive("SSGetPlayerStatsAPI"), {}, true)
