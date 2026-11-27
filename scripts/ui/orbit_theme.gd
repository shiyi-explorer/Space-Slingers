class_name SSOrbitTheme
extends RefCounted

const CREAM := Color("fff1d9")
const MUTED := Color("aebed1")
const MINT := Color("8beacf")
const BRASS := Color("e3aa68")
const NEBULA := preload("res://assets/visual/first-orbit-nebula.png")
const PLANETS := preload("res://assets/visual/first-orbit-planets.png")
const DESIGN_SIZE := Vector2(1152, 648)

const COMIC_FONT := preload("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf")
const FRAME := preload("res://scripts/ui/instrument_frame.gd")

static var comic_theme: Theme = _make_comic_theme()

static func _make_comic_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = COMIC_FONT
	return theme

static func instrument(parent: Control, accent: Color, compact := false) -> void:
	var frame := FRAME.new()
	frame.accent = accent
	frame.compact = compact
	parent.add_child(frame)

static func panel(fill: Color, edge: Color, radius: int, border := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	return style

static func plate(parent: Node, rect: Rect2, fill: Color, edge: Color, radius := 16) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", panel(fill, edge, radius))
	parent.add_child(node)
	if rect.size.x >= 100.0 and rect.size.y >= 70.0 and edge.a > 0.0:
		instrument(node, edge.lightened(0.13))
	return node

static func label(parent: Node, value: String, rect: Rect2, points: int, color := CREAM,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.theme = comic_theme
	node.position = rect.position
	node.size = rect.size
	node.text = value
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", points)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func button_style(button: Button, emphasis := false, radius := 12) -> void:
	var fill := Color("f2c487") if emphasis else Color("202a40")
	var ink := Color("251927") if emphasis else CREAM
	var edge := Color.TRANSPARENT if emphasis else Color("46516a")
	button.add_theme_stylebox_override("normal", panel(fill, edge, radius))
	button.add_theme_stylebox_override("hover", panel(fill.lightened(0.12), edge, radius))
	button.add_theme_stylebox_override("pressed", panel(fill.darkened(0.14), edge, radius))
	button.add_theme_stylebox_override("disabled", panel(Color("222434"), Color("42465b"), radius))
	button.add_theme_stylebox_override("focus", panel(Color.TRANSPARENT, MINT, radius, 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", Color("a2a9ba"))

static func button(parent: Node, caption: String, rect: Rect2, emphasis := false) -> Button:
	var node := Button.new()
	node.theme = comic_theme
	node.text = caption
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", 17)
	button_style(node, emphasis)
	parent.add_child(node)
	node.mouse_entered.connect(_button_glow.bind(node, 1.08))
	node.mouse_exited.connect(_button_glow.bind(node, 1.0))
	return node

static func _button_glow(node: Button, brightness: float) -> void:
	if node.has_meta("glow_tween"):
		var previous: Tween = node.get_meta("glow_tween")
		previous.kill()
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	node.set_meta("glow_tween", tween)
	tween.tween_property(node, "self_modulate", Color(brightness, brightness, brightness), 0.12)
	tween.tween_callback(func() -> void: node.remove_meta("glow_tween"))

static func field_style(input: LineEdit) -> void:
	input.theme = comic_theme
	var normal := panel(Color("101729"), Color("5e5360"), 10)
	var focus := panel(Color.TRANSPARENT, MINT, 10, 2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	input.add_theme_stylebox_override("normal", normal)
	input.add_theme_stylebox_override("focus", focus)
	input.add_theme_color_override("font_color", CREAM)
	input.add_theme_color_override("font_placeholder_color", MUTED)
	input.add_theme_color_override("caret_color", MINT)
	input.add_theme_font_size_override("font_size", 16)

static func backdrop(parent: Node) -> void:
	var sky := TextureRect.new()
	sky.texture = NEBULA
	sky.size = DESIGN_SIZE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.modulate = Color(0.66, 0.68, 0.83)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sky)

static func planet(parent: Node, rect: Rect2, warm: bool, tint := Color.WHITE) -> void:
	var image := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = PLANETS
	atlas.region = Rect2(952, 80, 729, 729) if warm else Rect2(84, 80, 725, 725)
	image.texture = atlas
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = rect.position
	image.size = rect.size
	image.modulate = tint
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

static func route(parent: Node, points: PackedVector2Array, color: Color) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = 2.0
	line.default_color = color
	line.antialiased = true
	parent.add_child(line)
