class_name SSHud
extends CanvasLayer

## HUD：太空玻璃质感——左上圆钮、右上分数、底部提示条、结算/暂停面板。

signal retry_pressed
signal next_pressed
signal pause_pressed
signal resume_pressed
signal zoom_changed(delta: float)
signal levels_pressed


const GLASS := Color("121d33")           # 面板玻璃底
const ACCENT := Color("55d8ff")           # 主强调色（青）
const TEXT := Color("e5edf9")
const TEXT_DIM := Color("93a8c8")

var brass_theme := false
var brass_score_position := Vector2(857, 14)
var score_label: Label
var best_label: Label
var birds_label: Label
var bird_skill_label: Label
var hint_label: Label
var aim_label: Label
var result_extra: Label
var result_panel: ColorRect
var result_title: Label
var result_detail: Label
var stars_box: HBoxContainer
var result_animation: Tween
var pause_animation: Tween
var star_labels: Array[Label] = []
var result_success_art: Control
var result_failure_art: Control
var result_mark: Label
var result_actions: HBoxContainer
var retry_button: Button
var next_button: Button
var paused_panel: ColorRect

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	# 左侧控制台把操作与剩余弹药收在同一个屏幕区块。
	var console := SSOrbitTheme.plate(self, Rect2(20, 14, 220, 101),
		Color("11192ef2"), Color("6e665d"), 13)
	var pause_button := _console_button(console, "❚❚", "暂停", 14.0)
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	var retry_top := _console_button(console, "↻", "重开关卡", 83.0)
	retry_top.pressed.connect(func() -> void: retry_pressed.emit())
	var levels_button := _console_button(console, "☰", "选择关卡", 152.0)
	levels_button.pressed.connect(func() -> void: levels_pressed.emit())
	SSOrbitTheme.plate(console, Rect2(14, 61, 192, 1), Color("6e665d"), Color.TRANSPARENT, 0)
	birds_label = SSOrbitTheme.label(console, "", Rect2(14, 67, 192, 22), 14, SSOrbitTheme.CREAM)
	aim_label = _label("", Vector2(34, 123), 13, SSOrbitTheme.MINT, HORIZONTAL_ALIGNMENT_LEFT, 320)

	var zoom_console := SSOrbitTheme.plate(self, Rect2(1022, 14, 110, 58),
		Color("11192ef2"), Color("6e665d"), 13)
	var zoom_out := _console_button(zoom_console, "−", "缩小", 10.0, 39.0, 8.0)
	zoom_out.pressed.connect(func() -> void: zoom_changed.emit(0.12))
	var zoom_in := _console_button(zoom_console, "+", "放大", 61.0, 39.0, 8.0)
	zoom_in.pressed.connect(func() -> void: zoom_changed.emit(-0.12))

	# 分数读数内缩，边角装饰不会压到数字。
	var score_position := brass_score_position if brass_theme else Vector2(850, 14)
	var score_card := SSOrbitTheme.plate(self, Rect2(score_position, Vector2(156, 92)),
		Color("171927f4"), Color("a77f55"), 13)
	SSOrbitTheme.label(score_card, "分数", Rect2(15, 11, 126, 18), 12, SSOrbitTheme.MUTED)
	score_label = SSOrbitTheme.label(score_card, "000000", Rect2(15, 29, 128, 35), 27, SSOrbitTheme.BRASS)
	SSOrbitTheme.plate(score_card, Rect2(15, 65, 126, 1), Color("6e665d"), Color.TRANSPARENT, 0)
	best_label = SSOrbitTheme.label(score_card, "最高分 000000", Rect2(15, 68, 126, 16), 11, SSOrbitTheme.MUTED)

	# 底部：关卡提示条（玻璃底）
	var hint_bar := PanelContainer.new()
	hint_bar.position = Vector2(20, 606)
	hint_bar.size = Vector2(1110, 42)
	var hint_style := _glass_style(12, 0.66)
	hint_style.content_margin_left = 22
	hint_bar.add_theme_stylebox_override("panel", hint_style)
	add_child(hint_bar)
	hint_label = _label_in(hint_bar, "", 14, TEXT_DIM)
	hint_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 左下：当前鸟种技能说明（长文本单独放，避免挤爆左上控制台 220px 面板）
	bird_skill_label = _label("", Vector2(24, 576), 13, SSOrbitTheme.MINT, HORIZONTAL_ALIGNMENT_LEFT, 366)

	# 右下：2D 真实操作说明（去掉 3D 残留的 Q/E 旋转）
	var controls := _label("", Vector2(400, 576), 12, Color(1, 1, 1, 0.68), HORIZONTAL_ALIGNMENT_RIGHT, 726)
	controls.text = "拖拽小鸟发射 · 空白处拖拽平移 · 滚轮缩放 · R 重开"

	# 结算面板
	result_panel = ColorRect.new()
	result_panel.color = Color(0.02, 0.04, 0.09, 0.88)
	result_panel.size = Vector2(1152, 648)
	result_panel.visible = false
	add_child(result_panel)
	var result_card := Panel.new()
	result_card.position = Vector2(200, 126)
	result_card.size = Vector2(752, 396)
	result_card.clip_contents = true
	result_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_style := SSOrbitTheme.panel(Color("11192d"), Color("46546c"), 21)
	card_style.shadow_color = Color("070915")
	card_style.shadow_size = 14
	result_card.add_theme_stylebox_override("panel", card_style)
	result_panel.add_child(result_card)
	result_success_art = _result_art(result_card, true)
	result_failure_art = _result_art(result_card, false)
	SSOrbitTheme.instrument(result_card, SSOrbitTheme.BRASS)
	SSOrbitTheme.plate(result_card, Rect2(300, 32, 1, 332), Color("46546c"), Color.TRANSPARENT, 0)
	result_mark = _panel_label("", 165, 14, SSOrbitTheme.MINT)
	result_title = _panel_label("", 200, 49, SSOrbitTheme.CREAM)
	result_title.add_theme_color_override("font_outline_color", Color("39263e"))
	result_title.add_theme_constant_override("outline_size", 7)
	result_title.add_theme_color_override("font_shadow_color", Color("070c18"))
	result_title.add_theme_constant_override("shadow_offset_x", 1)
	result_title.add_theme_constant_override("shadow_offset_y", 4)
	result_title.rotation_degrees = -1.5
	# 三颗星（结算时按获得数点亮）
	stars_box = HBoxContainer.new()
	stars_box.position = Vector2(534, 270)
	stars_box.size = Vector2(354, 51)
	stars_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	stars_box.add_theme_constant_override("separation", 16)
	for i in 3:
		var star := Label.new()
		star.theme = SSOrbitTheme.comic_theme
		star.text = "☆"
		star.add_theme_font_size_override("font_size", 38)
		star.add_theme_color_override("font_color", Color(1, 1, 1, 0.18))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_box.add_child(star)
		star_labels.append(star)
	result_panel.add_child(stars_box)
	result_detail = _panel_label("", 338, 16, TEXT)
	result_extra = _panel_label("", 377, 12, TEXT_DIM)
	result_actions = HBoxContainer.new()
	result_actions.position = Vector2(534, 456)
	result_actions.size = Vector2(384, 50)
	result_actions.alignment = BoxContainer.ALIGNMENT_BEGIN
	result_actions.add_theme_constant_override("separation", 14)
	result_panel.add_child(result_actions)
	retry_button = SSOrbitTheme.button(result_actions, "再试一次", Rect2())
	retry_button.custom_minimum_size = Vector2(177, 50)
	_set_comic_button_font(retry_button)
	retry_button.pressed.connect(func() -> void: retry_pressed.emit())
	next_button = SSOrbitTheme.button(result_actions, "下一关  →", Rect2(), true)
	next_button.custom_minimum_size = Vector2(177, 50)
	_set_comic_button_font(next_button)
	next_button.pressed.connect(func() -> void: next_pressed.emit())

	# 暂停面板
	paused_panel = ColorRect.new()
	paused_panel.color = Color(0.02, 0.04, 0.09, 0.82)
	paused_panel.size = Vector2(1152, 648)
	paused_panel.visible = false
	add_child(paused_panel)
	var pause_card := SSOrbitTheme.plate(paused_panel, Rect2(360, 148, 432, 346),
		Color("141a2df6"), SSOrbitTheme.BRASS, 22)
	SSOrbitTheme.label(pause_card, "已暂停", Rect2(0, 50, 432, 72), 44,
		SSOrbitTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	SSOrbitTheme.label(pause_card, "继续当前关卡，或重新开始。", Rect2(0, 124, 432, 30), 17,
		SSOrbitTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var resume := SSOrbitTheme.button(pause_card, "继续游戏", Rect2(48, 190, 336, 52), true)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	var restart := SSOrbitTheme.button(pause_card, "重开关卡", Rect2(48, 260, 336, 43))
	restart.pressed.connect(func() -> void: retry_pressed.emit())

func _set_comic_button_font(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 22)

func _result_art(parent: Control, won: bool) -> Control:
	var art := Control.new()
	art.size = Vector2(300, 396)
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	var ground := SSOrbitTheme.plate(art, Rect2(1, 1, 299, 394),
		Color("342535") if won else Color("111f38"), Color.TRANSPARENT, 0)
	var ground_style := ground.get_theme_stylebox("panel") as StyleBoxFlat
	ground_style.corner_radius_top_left = 20
	ground_style.corner_radius_bottom_left = 20
	var accents := Color("ffcc8b") if won else Color("8addee")
	for band in 3:
		var orbit := PackedVector2Array()
		for step in 49:
			var turn := TAU * float(step) / 48.0
			var ellipse := Vector2(cos(turn) * (144.0 + band * 15.0), sin(turn) * (57.0 + band * 11.0))
			orbit.append(Vector2(135, 200) + ellipse.rotated(-0.60))
		SSOrbitTheme.route(art, orbit, Color(accents, 0.18 - band * 0.04))
	SSOrbitTheme.planet(art, Rect2(24, 116, 215, 215), won, Color.WHITE)
	SSOrbitTheme.planet(art, Rect2(211, 62, 43, 43), not won, Color(0.78, 0.82, 0.90))
	var bird_art := TextureRect.new()
	bird_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bird_art.texture = preload("res://assets/characters/bird_normal.png")
	bird_art.position = Vector2(162, 94) if won else Vector2(163, 103)
	bird_art.size = Vector2(106, 106)
	bird_art.rotation = -0.20 if won else 0.12
	bird_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bird_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(bird_art)
	SSOrbitTheme.label(art, "SPACE SLINGERS", Rect2(27, 349, 244, 25), 19, accents)
	return art

func _glass_style(radius: int, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GLASS.r, GLASS.g, GLASS.b, alpha)
	style.set_corner_radius_all(radius)
	style.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _console_button(parent: Control, caption: String, tooltip: String, x: float,
		width := 53.0, y := 12.0) -> Button:
	var button := SSOrbitTheme.button(parent, caption, Rect2(x, y, width, 40))
	button.tooltip_text = tooltip
	button.add_theme_font_size_override("font_size", 20)
	SSOrbitTheme.button_style(button, false, 7)
	return button

func _label(text: String, pos: Vector2, font_size: int, color: Color, align: int, width: int) -> Label:
	var label := Label.new()
	label.theme = SSOrbitTheme.comic_theme
	label.text = text
	label.position = pos
	label.size = Vector2(width, 0)
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _label_in(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.theme = SSOrbitTheme.comic_theme
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _panel_label(text: String, y: float, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.theme = SSOrbitTheme.comic_theme
	label.text = text
	label.position = Vector2(534, y)
	label.size = Vector2(384, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_child(label)
	return label

func set_score(score: int, best: int) -> void:
	score_label.text = "%06d" % score
	best_label.text = "最高分  %06d" % best

func set_birds(remaining: int, kind_text := "红色普通鸟") -> void:
	# kind_text 形如「黄色加速鸟 · 飞行中点击 = 瞬间冲刺」：
	# 鸟种名留在窄控制台，技能说明挪到底部左侧宽位，避免文字溢出面板边框。
	var parts := kind_text.split(" · ", false, 2)
	birds_label.text = "小鸟 ×%d  ·  %s" % [remaining, parts[0]]
	bird_skill_label.text = parts[1] if parts.size() > 1 else ""

func set_aim_power(power: float, elevation := 0.0) -> void:
	if power <= 0.01:
		aim_label.text = ""
		return
	aim_label.text = "力度 %d%%" % roundi(clampf(power, 0.0, 1.0) * 100.0)

func set_hint(level_name: String, hint: String) -> void:
	hint_label.text = "%s  ·  %s" % [level_name, hint]

func show_result(won: bool, detail: String, is_final: bool, stars := 0) -> void:
	result_title.text = "全部通关" if is_final else ("关卡完成" if won else "弹药耗尽")
	result_title.add_theme_color_override("font_color", SSOrbitTheme.BRASS if won else SSOrbitTheme.CREAM)
	result_title.position.y = 200.0 if won else 229.0
	result_mark.text = "✓  航行成功" if won else "↻  等待重新出发"
	result_mark.position.y = 165.0 if won else 192.0
	result_success_art.visible = won
	result_failure_art.visible = not won
	result_detail.position.y = 333.0 if won else 310.0
	if result_animation != null:
		result_animation.kill()
	var earned := clampi(stars, 1, star_labels.size()) if won else 0
	for star in star_labels:
		star.text = "☆"
		star.scale = Vector2.ONE
		star.add_theme_color_override("font_color", Color("aebed16b"))
	stars_box.visible = won
	result_detail.text = detail
	var show_next := won and not is_final
	next_button.visible = show_next
	retry_button.text = "再玩一次" if won else "再试一次"
	retry_button.custom_minimum_size.x = 177.0 if show_next else 322.0
	SSOrbitTheme.button_style(retry_button, not show_next, 12)
	if not result_panel.visible:
		result_extra.text = ""
	result_panel.show()
	result_panel.modulate.a = 0.0
	result_animation = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	result_animation.tween_property(result_panel, "modulate:a", 1.0, 0.16)
	for i in earned:
		var star := star_labels[i]
		result_animation.tween_callback(_light_star.bind(star))
		result_animation.tween_property(star, "scale", Vector2.ONE, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _light_star(star: Label) -> void:
	star.text = "★"
	star.add_theme_color_override("font_color", SSOrbitTheme.BRASS)
	star.pivot_offset = star.size * 0.5
	star.scale = Vector2.ONE * 0.68

func show_paused(paused: bool) -> void:
	if pause_animation != null:
		pause_animation.kill()
	paused_panel.visible = paused
	if paused:
		paused_panel.modulate.a = 0.0
		pause_animation = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		pause_animation.tween_property(paused_panel, "modulate:a", 1.0, 0.16)

func set_result_extra(text: String) -> void:
	result_extra.text = text

func hide_result() -> void:
	if result_animation != null:
		result_animation.kill()
	result_panel.visible = false
