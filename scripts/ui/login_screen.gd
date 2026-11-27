class_name SSLoginScreen
extends CanvasLayer

## 登录界面：本地只做格式校验，真实认证由 main3d 调后端 /api/login。
## 提供离线游玩入口（后端不在时仍可玩，成绩不提交）。

signal login_requested(username: String, password: String)
signal offline_pressed

var username_input: LineEdit
var password_input: LineEdit
var message_label: Label

func _ready() -> void:
	layer = 10
	_build()

func _build() -> void:
	# 这一层挡住游戏点击，背景和插图自身不接收输入。
	var overlay := Control.new()
	overlay.size = SSOrbitTheme.DESIGN_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	SSOrbitTheme.backdrop(overlay)
	SSOrbitTheme.planet(overlay, Rect2(-64, 212, 535, 535), true)
	SSOrbitTheme.planet(overlay, Rect2(336, 125, 126, 126), false)
	SSOrbitTheme.label(overlay, "SPACE", Rect2(78, 83, 440, 78), 67)
	SSOrbitTheme.label(overlay, "SLINGERS", Rect2(78, 151, 440, 78), 67, SSOrbitTheme.BRASS)
	var panel := SSOrbitTheme.plate(overlay, Rect2(612, 63, 450, 522),
		Color("14182bf0"), Color("9d7356"), 21)
	SSOrbitTheme.label(panel, "飞行员登录", Rect2(36, 31, 378, 50), 33)
	SSOrbitTheme.label(panel, "登录后同步进度、成绩和排行榜。", Rect2(36, 90, 378, 28),
		16, SSOrbitTheme.MUTED)
	SSOrbitTheme.label(panel, "用户名", Rect2(36, 145, 378, 22), 14, SSOrbitTheme.MUTED)
	username_input = _make_input(panel, "输入用户名", 171)
	SSOrbitTheme.label(panel, "密码", Rect2(36, 233, 378, 22), 14, SSOrbitTheme.MUTED)
	password_input = _make_input(panel, "输入密码", 259)
	password_input.secret = true
	username_input.text_submitted.connect(func(_value: String) -> void: password_input.grab_focus())
	password_input.text_submitted.connect(func(_value: String) -> void: _do_login())
	var login_button := SSOrbitTheme.button(panel, "登录", Rect2(36, 330, 378, 47), true)
	login_button.pressed.connect(_do_login)
	message_label = SSOrbitTheme.label(panel, "", Rect2(36, 385, 378, 32), 14,
		SSOrbitTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var offline_button := SSOrbitTheme.button(panel, "离线游玩 →", Rect2(36, 444, 378, 42))
	offline_button.pressed.connect(func() -> void: offline_pressed.emit())

func _do_login() -> void:
	var username := username_input.text.strip_edges()
	var password := password_input.text
	if username.length() < 2:
		show_error("用户名至少 2 个字符")
		return
	if password.length() < 4:
		show_error("密码至少 4 位")
		return
	message_label.text = "正在登录…"
	message_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	login_requested.emit(username, password)

func show_error(text: String) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", Color("ff9ba5"))

func _make_input(parent: Control, placeholder: String, y: float) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.position = Vector2(36, y)
	input.size = Vector2(378, 46)
	SSOrbitTheme.field_style(input)
	parent.add_child(input)
	return input
