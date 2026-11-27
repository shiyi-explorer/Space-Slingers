class_name SSGetCurrentUserAPI
extends RefCounted

## 对应后端 GetCurrentUserMessage：令牌换当前用户。

func send() -> Dictionary:
	return await SSTransport.instance.send(
		SSApiName.derive("SSGetCurrentUserAPI"), {}, true)
