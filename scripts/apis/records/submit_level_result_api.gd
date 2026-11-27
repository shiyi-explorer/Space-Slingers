class_name SSSubmitLevelResultAPI
extends RefCounted

## 对应后端 SubmitLevelResultMessage：提交成绩（服务端做合理性校验）。

var level_id: String
var completed: bool
var score: int
var birds_used: int
var duration_seconds: float

func _init(p_level_id: String, p_completed: bool, p_score: int, p_birds_used: int, p_duration: float) -> void:
	level_id = p_level_id
	completed = p_completed
	score = p_score
	birds_used = p_birds_used
	duration_seconds = p_duration

func send() -> Dictionary:
	return await SSTransport.instance.send(
		SSApiName.derive("SSSubmitLevelResultAPI"), {
			"levelId": level_id,
			"completed": completed,
			"score": score,
			"birdsUsed": birds_used,
			"durationSeconds": duration_seconds,
		}, true)
