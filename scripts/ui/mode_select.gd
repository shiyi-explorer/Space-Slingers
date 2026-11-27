class_name SSModeSelect
extends Control

const SCENE_MENU := "res://ModeSelect.tscn"
const SCENE_2D := "res://Main.tscn"
const SCENE_3D := "res://Main3D.tscn"

func _ready() -> void:
	SSOrbitTheme.backdrop(self)
	SSOrbitTheme.planet(self, Rect2(-220, -300, 730, 730), true, Color(0.64, 0.66, 0.79))
	SSOrbitTheme.planet(self, Rect2(870, 437, 410, 410), false, Color(0.70, 0.76, 0.91))
	SSOrbitTheme.label(self, "SPACE SLINGERS", Rect2(0, 69, 1152, 87), 70,
		SSOrbitTheme.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	SSOrbitTheme.label(self, "星际弹弓　·　选择游戏模式", Rect2(0, 158, 1152, 30), 20,
		SSOrbitTheme.MINT, HORIZONTAL_ALIGNMENT_CENTER)
	_mode_card(Vector2(220, 245), "2D 经典", "在平面上读弹道，借引力击倒塔楼。","进入 2D →", SCENE_2D, true)
	_mode_card(Vector2(600, 245), "3D 立体", "旋转视角、调整仰角，绕到行星背面。","进入 3D →", SCENE_3D, false)
	SSOrbitTheme.label(self, "两种模式均可离线游玩", Rect2(0, 564, 1152, 24), 15,
		SSOrbitTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _mode_card(origin: Vector2, title: String, description: String, caption: String,
		scene: String, warm: bool) -> void:
	var accent := SSOrbitTheme.BRASS if warm else SSOrbitTheme.MINT
	var card := SSOrbitTheme.button(self, "", Rect2(origin, Vector2(332, 242)))
	card.add_theme_stylebox_override("normal", SSOrbitTheme.panel(Color("14192fe8"), accent, 19))
	card.add_theme_stylebox_override("hover", SSOrbitTheme.panel(Color("253049"), accent, 19, 2))
	SSOrbitTheme.instrument(card, accent)
	card.pressed.connect(func() -> void: get_tree().change_scene_to_file(scene))
	SSOrbitTheme.label(card, title, Rect2(26, 30, 280, 48), 32)
	SSOrbitTheme.label(card, description, Rect2(26, 91, 280, 32), 15, SSOrbitTheme.MUTED)
	SSOrbitTheme.plate(card, Rect2(26, 146, 280, 1), Color(accent, 0.50), Color.TRANSPARENT, 0)
	SSOrbitTheme.label(card, caption, Rect2(26, 171, 280, 26), 18, accent)
