class_name SSApiName
extends RefCounted

## 路由名统一推导（规则 53）：剥 SS 前缀、去 API 后缀、转小写。
## SSGetCurrentUserAPI -> getcurrentuser；LoginAPI -> login。
## 与后端规则 31 同一条规则，防止前后端命名偏差。
## 注意：class_name 是 GDScript 保留字，参数名不可使用。

static func derive(message_class: String) -> String:
	return message_class.trim_prefix("SS").trim_suffix("API").to_lower()
