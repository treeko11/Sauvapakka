class_name App
extends Control
## Root of the game: owns the spell data and swaps one screen at a time.

var db: SpellDB
var current: Control
var flow: RunFlow
var profile: Profile


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	db = SpellDB.load_default()
	if profile == null:
		profile = Profile.load_or_new()
	show_menu()


func show_screen(screen: Control) -> void:
	if current != null:
		current.queue_free()
	current = screen
	add_child(screen)


func show_menu() -> void:
	show_screen(MainMenu.new(self))


func new_run(p_seed := -1) -> void:
	flow = RunFlow.new(self, p_seed if p_seed >= 0 else randi())
	flow.show_preview()
