class_name DuelViewer
extends Control
## Pick two sample builds and watch them duel, for readability playtests.

const BUILD_DIR := "res://data/builds"

var app: App
var _builds: Array[WandBuild] = []
var _pick: Array[OptionButton] = []
var _seed: SpinBox
var _boss: CheckBox


func _init(p_app: App) -> void:
	app = p_app


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	for f in DirAccess.get_files_at(BUILD_DIR):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			_builds.append(load(BUILD_DIR.path_join(f)))
	var box := VBoxContainer.new()
	box.position = Vector2(60, 140)
	box.custom_minimum_size = Vector2(600, 0)
	box.add_theme_constant_override("separation", 20)
	add_child(box)
	box.add_child(UiKit.label("Duel viewer", 44))
	for side in ["Your wand", "Enemy wand"]:
		box.add_child(UiKit.label(side, 26, Palette.BIRCH))
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(0, 64)
		for b in _builds:
			ob.add_item("%s  (%s)" % [b.display_name, b.frame.display_name])
		box.add_child(ob)
		_pick.append(ob)
	_pick[1].select(mini(1, _builds.size() - 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(UiKit.label("Seed", 26, Palette.BIRCH, false))
	_seed = SpinBox.new()
	_seed.max_value = 9999
	_seed.custom_minimum_size = Vector2(160, 56)
	row.add_child(_seed)
	_boss = CheckBox.new()
	_boss.text = "60 s boss length"
	row.add_child(_boss)
	for c in row.get_children():
		c.size_flags_vertical = SIZE_SHRINK_CENTER
	box.add_child(row)
	box.add_child(UiKit.button("Watch duel", _watch.bind(false), Vector2(0, 80)))
	box.add_child(UiKit.button("Training dummy", _watch.bind(true), Vector2(0, 80)))
	box.add_child(UiKit.button("Back", app.show_menu, Vector2(0, 64)))


func _watch(dummy: bool) -> void:
	var enemy := _builds[_pick[1].selected]
	if dummy:
		enemy = WandBuild.new()
		enemy.display_name = "Training Dummy"
		enemy.frame = load("res://data/frames/apprentice_rod.tres")
	var screen := DuelScreen.new()
	screen.setup(_builds[_pick[0].selected], enemy, app.db, int(_seed.value), _boss.button_pressed, dummy)
	screen.continue_text = "Back"
	screen.finished.connect(func(_w: int) -> void: app.show_screen(DuelViewer.new(app)))
	app.show_screen(screen)
