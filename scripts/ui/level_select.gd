class_name SSLevelSelect
extends CanvasLayer

## 选关页：三张关卡卡片（锁定/可挑战/已通关 + 最好分）。
## 解锁状态读后端 progress 服务；离线模式全部开放（本地最好分）。
## skip_next：从选关页/下一关进入时跳过选关页直接进关（跨场景重载保留）。

signal level_selected(index: int)
signal close_requested

static var skip_next := false

var status_labels: Array[Label] = []
var best_labels: Array[Label] = []
var star_rows: Array[HBoxContainer] = []
var play_buttons: Array[Button] = []
var card_panels: Array[Control] = []
var subtitle_label: Label

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	var overlay := Control.new()
	overlay.size = SSOrbitTheme.DESIGN_SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	SSOrbitTheme.backdrop(overlay)
	SSOrbitTheme.planet(overlay, Rect2(846, -330, 550, 550), true, Color(0.67, 0.62, 0.68))
	SSOrbitTheme.planet(overlay, Rect2(-170, 431, 340, 340), false, Color(0.67, 0.72, 0.9))
	SSOrbitTheme.label(overlay, "选择轨道", Rect2(74, 54, 500, 67), 48)
	subtitle_label = SSOrbitTheme.label(overlay, "", Rect2(77, 131, 660, 26), 16, SSOrbitTheme.MUTED)
	var count := SSLevels.count()
	var rows := ceili(float(count) / 3.0)
	# 卡片区可滚动：关卡多于一行时（6 关两行）滚轮才能翻到下面，
	# 标题/副标题/返回按钮留在 overlay 上固定，不随滚动移动。
	var scroller := ScrollContainer.new()
	scroller.position = Vector2(0, 160)
	scroller.size = Vector2(SSOrbitTheme.DESIGN_SIZE.x, 410)
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var bar := scroller.get_v_scroll_bar()
	bar.add_theme_stylebox_override("normal", SSOrbitTheme.panel(Color("141b2ecc"), Color("46516a"), 6))
	bar.add_theme_stylebox_override("grabber", SSOrbitTheme.panel(Color("b9d94f"), Color.TRANSPARENT, 6))
	bar.add_theme_stylebox_override("grabber_highlight", SSOrbitTheme.panel(Color("d4f06a"), Color.TRANSPARENT, 6))
	bar.add_theme_stylebox_override("grabber_pressed", SSOrbitTheme.panel(Color("8beacf"), Color.TRANSPARENT, 6))
	overlay.add_child(scroller)
	var content := Control.new()
	content.custom_minimum_size = Vector2(SSOrbitTheme.DESIGN_SIZE.x, maxf(410.0, rows * 260.0 + 100.0))
	scroller.add_child(content)

	var count_on_map := mini(count, 3)
	var line := PackedVector2Array()
	for i in range(count_on_map * 28 + 1):
		var t := float(i) / 28.0 - 0.5
		var x := 223.0 + t * 353.0
		var y := 140.0 - 52.0 * sin(t * 1.4) - t * 13.0
		line.append(Vector2(x, y))
	SSOrbitTheme.route(content, line, Color(SSOrbitTheme.MINT, 0.30))

	for i in count:
		var level := SSLevels.build(i)
		var col := i % 3
		var x := 223.0 + float(col) * 353.0
		var y := 140.0 - 52.0 * sin(float(col) * 1.4) - float(col) * 13.0 + 260.0 * floori(float(i) / 3.0)
		var station := SSOrbitTheme.plate(content, Rect2(x - 130.0, y - 66.0, 260.0, 248.0),
			Color("141b2ee8"), Color("5a555d"), 18)
		card_panels.append(station)
		var badge := SSOrbitTheme.plate(station, Rect2(96, 16, 68, 68),
			Color("412c30"), SSOrbitTheme.BRASS, 34)
		SSOrbitTheme.label(badge, "%02d" % (i + 1), Rect2(0, 5, 68, 58), 32,
			SSOrbitTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		SSOrbitTheme.label(station, level.level_name, Rect2(0, 89, 260, 40), 24,
			SSOrbitTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		var stars := HBoxContainer.new()
		stars.position = Vector2(0, 130)
		stars.size = Vector2(260, 24)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		stars.add_theme_constant_override("separation", 7)
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for slot in 3:
			SSOrbitTheme.label(stars, "☆", Rect2(), 20, SSOrbitTheme.MUTED)
		station.add_child(stars)
		star_rows.append(stars)
		status_labels.append(SSOrbitTheme.label(station, "", Rect2(0, 157, 260, 21), 13,
			SSOrbitTheme.MINT, HORIZONTAL_ALIGNMENT_CENTER))
		best_labels.append(SSOrbitTheme.label(station, "", Rect2(0, 178, 260, 20), 12,
			SSOrbitTheme.BRASS, HORIZONTAL_ALIGNMENT_CENTER))
		var play := SSOrbitTheme.button(station, "出击", Rect2(41, 204, 178, 32), true)
		var index := i
		play.pressed.connect(func() -> void: level_selected.emit(index))
		play_buttons.append(play)

	var back := SSOrbitTheme.button(overlay, "← 返回", Rect2(62, 573, 112, 42))
	back.pressed.connect(func() -> void: close_requested.emit())

func open() -> void:
	visible = true
	_refresh()

func _refresh() -> void:
	var offline := SSTransport.session_token.is_empty()
	subtitle_label.text = "离线模式 · 全部开放（本地最好分）" if offline \
		else "通关上一关解锁下一关 · 数据来自星际指挥部"
	for i in SSLevels.count():
		if offline:
			_apply_local_card(i)
		else:
			_refresh_card_from_server(i)

func _refresh_card_from_server(i: int) -> void:
	_apply_card(i, true, false, -1, true)  # 先占位（加载中）
	var result: Dictionary = await SSLoadProgressAPI.new(_level_id(i)).send()
	if not result.ok:
		_apply_local_card(i)  # 后端不可达兜底
		return
	_apply_card(
		i,
		bool(result.data.get("unlocked", false)),
		bool(result.data.get("completed", false)),
		int(result.data.get("bestScore", 0)), false,
		int(result.data.get("minCompletedBirdsUsed") if result.data.get("minCompletedBirdsUsed") != null else 0))

func _apply_local_card(i: int) -> void:
	var config := ConfigFile.new()
	config.load("user://space_slingers.cfg")
	var best := int(config.get_value("best", str(i), 0))
	var fewest := int(config.get_value("min_shots", str(i), 0))
	_apply_card(i, true, best > 0 or fewest > 0, best, false, fewest)

func _apply_card(i: int, unlocked: bool, completed: bool, best: int, loading := false, fewest := 0) -> void:
	_display_stars(i, SSLevels.build(i).earned_stars(best, unlocked and completed and not loading, fewest))
	if loading:
		status_labels[i].text = "查询指挥部…"
		status_labels[i].add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		play_buttons[i].disabled = true
		return
	if not unlocked:
		status_labels[i].text = "未解锁"
		status_labels[i].add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		best_labels[i].text = "通关上一关后开放"
		best_labels[i].add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
		play_buttons[i].disabled = true
		play_buttons[i].text = "锁定"
		card_panels[i].modulate = Color(1, 1, 1, 0.45)
		return
	card_panels[i].modulate = Color.WHITE
	play_buttons[i].disabled = false
	play_buttons[i].text = "再挑战" if completed else "出击"
	if completed:
		status_labels[i].text = "✓ 已通关"
		status_labels[i].add_theme_color_override("font_color", Color("b9d94f"))
	else:
		status_labels[i].text = "可挑战"
		status_labels[i].add_theme_color_override("font_color", Color("55d8ff"))
	if completed and best >= 0:
		best_labels[i].text = "最好分 %d" % best
		if fewest > 0:
			best_labels[i].text += " · 最少 %d 发" % fewest
		best_labels[i].add_theme_color_override("font_color", SSConfig.COLOR_SCORE)
	else:
		best_labels[i].text = ""
func _display_stars(i: int, earned: int) -> void:
	for star: Label in star_rows[i].get_children():
		var lit := star.get_index() < earned
		star.text = "★" if lit else "☆"
		star.add_theme_color_override("font_color", SSOrbitTheme.BRASS if lit else SSOrbitTheme.MUTED)

func _level_id(i: int) -> String:
	return "level-%02d" % (i + 1)

