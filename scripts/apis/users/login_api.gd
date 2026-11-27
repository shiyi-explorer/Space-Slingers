class_name SSLoginAPI
extends RefCounted

## 对应后端 LoginMessage：用户名不存在则注册并登录，签发 24h 令牌（规则 52：字段 + send）。

var username: String
var password: String

func _init(p_username: String, p_password: String) -> void:
	username = p_username
	password = p_password

func send() -> Dictionary:
	var result: Dictionary = await SSTransport.instance.send(
		SSApiName.derive("LoginAPI"), {"username": username, "password": password}, false)
	if result.ok:
		SSTransport.session_token = str(result.data.get("userToken", ""))
		SSTransport.researcher_name = str(result.data.get("username", ""))
	return result
