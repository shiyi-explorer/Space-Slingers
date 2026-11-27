class_name SSLevels
extends RefCounted

## 关卡注册表：唯一数据源是 data/levels.json，离线与在线都由它派生。
## 加关/改关只需编辑那一个 JSON，无需再同步 GDScript 与 Scala 两份手写定义。

const LEVELS_PATH := "res://data/levels.json"

static var _definitions: Array[Dictionary] = []
static var _loaded := false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取关卡数据：%s" % LEVELS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("levels") is Array:
		push_error("关卡数据格式错误：%s" % LEVELS_PATH)
		return
	for item in parsed["levels"]:
		if item is Dictionary:
			_definitions.append(item)

static func count() -> int:
	_ensure_loaded()
	return _definitions.size()

## 返回关卡原始定义（含 id/chapter/name 等元数据）
static func definition(index: int) -> Dictionary:
	_ensure_loaded()
	if _definitions.is_empty():
		return {}
	return _definitions[clampi(index, 0, _definitions.size() - 1)]

static func build(index: int) -> SSLevelData:
	return SSLevelCodec.from_dict(definition(index))
