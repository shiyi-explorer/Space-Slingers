class_name SSTransport
extends Node

## 共享 API 传输层（规则 50/51：令牌存储、发送逻辑、错误处理集中于此，
## 不放进任何服务专用文件夹）。各服务 API 类通过 instance 调用 send。

const BASE_URL := "http://127.0.0.1:8091/api/"
const REQUEST_TIMEOUT := 5.0

static var instance: SSTransport
static var session_token := ""
static var researcher_name := ""

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

## 发送一个 API 请求。返回 {ok: bool, message: String, data: Dictionary}
func send(api_name: String, body: Dictionary, with_token: bool) -> Dictionary:
	var payload := body.duplicate(true)
	if with_token:
		if session_token.is_empty():
			return {"ok": false, "message": "尚未登录", "data": {}}
		payload["userToken"] = session_token
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	http.request(BASE_URL + api_name,
		["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "message": "无法连接研究站服务器", "data": {}}
	var payload_out: Dictionary = {}
	if not (result[3] as PackedByteArray).is_empty():
		var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
		if parsed is Dictionary:
			payload_out = parsed
	if result[1] >= 400:
		return {"ok": false, "message": str(payload_out.get("message", "请求失败")), "data": {}}
	return {"ok": true, "message": "", "data": payload_out}
