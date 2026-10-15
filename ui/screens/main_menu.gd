class_name MainMenu
extends Control

var app: App


func _init(p_app: App) -> void:
	app = p_app


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	var box := VBoxContainer.new()
	box.position = Vector2(110, 360)
	box.custom_minimum_size = Vector2(500, 0)
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	var title := UiKit.label("Sauvapakka", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiKit.label("The wand building card game", 24, Palette.BIRCH)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	box.add_child(UiKit.button("New run", app.new_run, Vector2(0, 80)))
	box.add_child(UiKit.button("Duel viewer", func() -> void: app.show_screen(DuelViewer.new(app)), Vector2(0, 80)))
